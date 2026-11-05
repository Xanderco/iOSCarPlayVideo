import Foundation
import Network

/// Minimal HTTP server: "/" serves a full-screen viewer page, "/stream" serves
/// multipart MJPEG. Slow clients drop frames instead of buffering them, which
/// keeps the extension well under its memory limit.
final class MirrorStreamServer {
    private final class Client {
        let connection: NWConnection
        var pendingSends = 0
        init(connection: NWConnection) { self.connection = connection }
    }

    var onViewerCountChange: ((Int) -> Void)?

    private let port: NWEndpoint.Port
    private let queue = DispatchQueue(label: "com.xanderco.dashcast.broadcast.server")
    private var listener: NWListener?
    private var streamClients: [ObjectIdentifier: Client] = [:]

    private let countLock = NSLock()
    private var viewerCount = 0

    var hasViewers: Bool {
        countLock.lock()
        defer { countLock.unlock() }
        return viewerCount > 0
    }

    init(port: UInt16) {
        self.port = NWEndpoint.Port(rawValue: port) ?? 8088
    }

    func start() {
        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        guard let listener = try? NWListener(using: parameters, on: port) else { return }
        listener.newConnectionHandler = { [weak self] connection in
            self?.accept(connection)
        }
        listener.start(queue: queue)
        self.listener = listener
    }

    func stop() {
        queue.async { [weak self] in
            guard let self else { return }
            self.listener?.cancel()
            self.listener = nil
            for client in self.streamClients.values {
                client.connection.cancel()
            }
            self.streamClients.removeAll()
            self.publishViewerCount()
        }
    }

    /// Sends a JPEG frame to every connected stream viewer.
    func broadcast(frame jpeg: Data) {
        let part = MJPEGStream.framePart(jpeg: jpeg)
        queue.async { [weak self] in
            guard let self else { return }
            for (id, client) in self.streamClients where client.pendingSends < 2 {
                client.pendingSends += 1
                client.connection.send(content: part, completion: .contentProcessed { [weak self] error in
                    guard let self else { return }
                    client.pendingSends -= 1
                    if error != nil {
                        self.remove(id)
                    }
                })
            }
        }
    }

    // MARK: - Connections (all on `queue`)

    private func accept(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            switch state {
            case .failed, .cancelled:
                self?.remove(ObjectIdentifier(connection))
            default:
                break
            }
        }
        connection.start(queue: queue)
        connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { [weak self] data, _, _, error in
            guard let self, let data, error == nil else {
                connection.cancel()
                return
            }
            switch MJPEGStream.route(forRequest: data) {
            case .page:
                self.respondAndClose(connection, MJPEGStream.httpResponse(
                    status: "200 OK",
                    contentType: "text/html; charset=utf-8",
                    body: MJPEGStream.viewerPage()
                ))
            case .stream:
                let client = Client(connection: connection)
                self.streamClients[ObjectIdentifier(connection)] = client
                self.publishViewerCount()
                connection.send(content: MJPEGStream.streamResponseHeader(), completion: .contentProcessed { _ in })
            case .notFound:
                self.respondAndClose(connection, MJPEGStream.httpResponse(
                    status: "404 Not Found",
                    contentType: "text/plain",
                    body: Data("Not found".utf8)
                ))
            }
        }
    }

    private func respondAndClose(_ connection: NWConnection, _ response: Data) {
        connection.send(content: response, isComplete: true, completion: .contentProcessed { _ in
            connection.cancel()
        })
    }

    private func remove(_ id: ObjectIdentifier) {
        queue.async { [weak self] in
            guard let self, let client = self.streamClients.removeValue(forKey: id) else { return }
            client.connection.cancel()
            self.publishViewerCount()
        }
    }

    private func publishViewerCount() {
        let count = streamClients.count
        countLock.lock()
        let changed = count != viewerCount
        viewerCount = count
        countLock.unlock()
        if changed {
            onViewerCountChange?(count)
        }
    }
}
