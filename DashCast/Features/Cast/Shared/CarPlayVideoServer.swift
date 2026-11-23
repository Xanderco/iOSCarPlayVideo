import Foundation
import Network
import QuartzCore

/// High-performance video streaming server for CarPlay display casting (ADR-002 §7.5).
///
/// Handles TCP socket transmission of video stream data to CarPlay head units and local
/// browser clients, continuously monitoring frame delivery round-trip time (RTT) and socket
/// write queue depth to drive GhostCast Adaptive Bitrate scaling.
public final class CarPlayVideoServer: @unchecked Sendable {
    public static let shared = CarPlayVideoServer(port: CarCastShared.mirrorPort)

    public final class Client {
        public let id = UUID()
        public let connection: NWConnection?
        public var pendingSends: Int = 0
        public var lastSendTime: CFTimeInterval = 0
        public var measuredRTT: TimeInterval = 0

        public init(connection: NWConnection?) {
            self.connection = connection
        }
    }

    public let port: UInt16
    public let ghostCastController: GhostCastAdaptiveBitrateController
    private let queue = DispatchQueue(label: "com.xanderco.dashcast.carplay.videoserver", qos: .userInteractive)

    private let stateLock = NSLock()
    private var listener: NWListener?
    private var clients: [UUID: Client] = [:]
    private var frameSequence: UInt64 = 0

    private var _lastMeasuredRTT: TimeInterval = 0
    private var _averageRTT: TimeInterval = 0
    private var _rttSampleCount: Int = 0
    private var _currentQueueDepth: Int = 0

    public var hlsStore: HLSSegmentStore?
    public var onViewerCountChange: ((Int) -> Void)?
    public var onProfileChange: ((GhostCastProfile) -> Void)? {
        didSet {
            ghostCastController.onProfileChanged = onProfileChange
        }
    }

    public var lastMeasuredRTT: TimeInterval {
        stateLock.lock(); defer { stateLock.unlock() }
        return _lastMeasuredRTT
    }

    public var averageRTT: TimeInterval {
        stateLock.lock(); defer { stateLock.unlock() }
        return _averageRTT
    }

    public var currentQueueDepth: Int {
        stateLock.lock(); defer { stateLock.unlock() }
        return _currentQueueDepth
    }

    public var connectedClientCount: Int {
        stateLock.lock(); defer { stateLock.unlock() }
        return clients.count
    }

    public var hasViewers: Bool {
        stateLock.lock(); defer { stateLock.unlock() }
        return !clients.isEmpty
    }

    public var activeProfile: GhostCastProfile {
        ghostCastController.activeProfile
    }

    public init(
        port: UInt16 = CarCastShared.mirrorPort,
        controller: GhostCastAdaptiveBitrateController = GhostCastAdaptiveBitrateController()
    ) {
        self.port = port
        self.ghostCastController = controller
    }

    // MARK: - Lifecycle

    public func start() {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        guard let nwPort = NWEndpoint.Port(rawValue: port),
              let listener = try? NWListener(using: parameters, on: nwPort) else {
            return
        }

        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    public func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.listener?.cancel()
            self.listener = nil
            self.stateLock.lock()
            for client in self.clients.values {
                client.connection?.cancel()
            }
            self.clients.removeAll()
            self._currentQueueDepth = 0
            self.stateLock.unlock()
            self.publishViewerCount()
        }
    }

    // MARK: - Frame Broadcasting & Latency Monitoring

    /// Broadcasts a video frame to all connected clients, tracking socket write latency
    /// and evaluating GhostCast adaptive bitrate rules.
    public func broadcast(frame data: Data) {
        let now = CACurrentMediaTime()
        let part = MJPEGStream.framePart(jpeg: data)

        queue.async { [weak self] in
            guard let self else { return }
            self.stateLock.lock()
            self.frameSequence &+= 1
            let clientList = Array(self.clients.values)
            var maxQueue = 0

            for client in clientList {
                maxQueue = max(maxQueue, client.pendingSends)
                // Drop if client buffer is severely backed up (> 6 frames)
                guard client.pendingSends < 8 else { continue }

                client.pendingSends += 1
                client.lastSendTime = now
                let clientID = client.id

                client.connection?.send(content: part, completion: .contentProcessed { [weak self] error in
                    guard let self else { return }
                    let deliveryTime = CACurrentMediaTime()
                    let rtt = max(0.001, deliveryTime - now)
                    self.handleFrameDelivered(clientId: clientID, rtt: rtt, error: error)
                })
            }

            self._currentQueueDepth = maxQueue
            self.stateLock.unlock()

            // Evaluate adaptive bitrate against current queue depth
            self.ghostCastController.recordSample(queueDepth: maxQueue, rtt: self._lastMeasuredRTT)
        }
    }

    private func handleFrameDelivered(clientId: UUID, rtt: TimeInterval, error: NWError?) {
        stateLock.lock()
        guard let client = clients[clientId] else {
            stateLock.unlock()
            return
        }

        client.pendingSends = max(0, client.pendingSends - 1)
        client.measuredRTT = rtt

        if error != nil {
            clients.removeValue(forKey: clientId)
            stateLock.unlock()
            publishViewerCount()
            return
        }

        _lastMeasuredRTT = rtt
        _rttSampleCount += 1
        // Exponential moving average for smooth RTT tracking
        if _averageRTT <= 0 {
            _averageRTT = rtt
        } else {
            _averageRTT = (_averageRTT * 0.8) + (rtt * 0.2)
        }

        var maxQueue = 0
        for c in clients.values {
            maxQueue = max(maxQueue, c.pendingSends)
        }
        _currentQueueDepth = maxQueue
        stateLock.unlock()

        // Feed delivered frame metrics to GhostCast ABR
        ghostCastController.recordSample(queueDepth: maxQueue, rtt: rtt)
    }

    // MARK: - Connections

    private func accept(_ connection: NWConnection) {
        let client = Client(connection: connection)
        let clientID = client.id

        stateLock.lock()
        clients[clientID] = client
        stateLock.unlock()
        publishViewerCount()

        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.removeClient(clientID)
            default:
                break
            }
        }
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, error in
            guard let self, let data, error == nil else {
                connection.cancel()
                self?.removeClient(clientID)
                return
            }
            if let store = self.hlsStore, let response = MirrorHLS.response(for: MirrorHLS.route(forRequest: data), store: store) {
                self.respondAndClose(connection, response)
                return
            }
            switch MJPEGStream.route(forRequest: data) {
            case .viewerPage:
                let host = LocalNetworkAddress.preferredIPv4()
                let html = MJPEGStream.viewerHTML(title: "DashCast CarPlay", streamPath: "/stream", host: host, port: self.port)
                self.respondAndClose(connection, MJPEGStream.httpResponse(status: "200 OK", contentType: "text/html; charset=utf-8", body: Data(html.utf8)))
            case .stream:
                let header = MJPEGStream.multipartHeader()
                connection.send(content: header, completion: .contentProcessed { [weak self] error in
                    if error != nil { self?.removeClient(clientID) }
                })
            case .notStream:
                self.respondAndClose(connection, MJPEGStream.httpResponse(status: "404 Not Found", contentType: "text/plain", body: Data("Not found".utf8)))
            }
        }
    }

    private func respondAndClose(_ connection: NWConnection, _ data: Data) {
        connection.send(content: data, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func removeClient(_ clientID: UUID) {
        stateLock.lock()
        clients.removeValue(forKey: clientID)
        stateLock.unlock()
        publishViewerCount()
    }

    private func publishViewerCount() {
        let count = connectedClientCount
        DispatchQueue.main.async { [weak self] in
            self?.onViewerCountChange?(count)
        }
    }

    // MARK: - Simulation Support for Testing

    /// Simulates a connected client delivery event to verify RTT tracking and ABR transitions under test.
    public func simulateDelivery(queueDepth: Int, latency: TimeInterval) {
        stateLock.lock()
        _currentQueueDepth = queueDepth
        _lastMeasuredRTT = latency
        if _averageRTT <= 0 {
            _averageRTT = latency
        } else {
            _averageRTT = (_averageRTT * 0.8) + (latency * 0.2)
        }
        stateLock.unlock()

        ghostCastController.recordSample(queueDepth: queueDepth, rtt: latency)
    }

    /// Registers a mock client for queue depth simulation in unit tests.
    @discardableResult
    public func registerMockClient() -> Client {
        let client = Client(connection: nil)
        stateLock.lock()
        clients[client.id] = client
        stateLock.unlock()
        return client
    }
}
