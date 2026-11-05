import Foundation

// Shared between the DashCast app and the DashCastBroadcast upload extension.
// Keep this file free of UIKit/app-only types: it is compiled into both targets.

enum CarCastShared {
    /// App group used by the app and the broadcast extension to exchange state.
    static let appGroupID = "group.com.xanderco.dashcast"
    /// Suffix appended to the host app bundle id to get the broadcast extension id.
    static let broadcastExtensionSuffix = ".broadcast"
    /// TCP port the broadcast extension serves the car-browser mirror on.
    static let mirrorPort: UInt16 = 8088

    static let broadcastStatusKey = "carCast.broadcastStatus"
    static let vehicleMovingKey = "carCast.vehicleMoving"

    enum DarwinNotification {
        static let broadcastStatusChanged = "com.xanderco.dashcast.broadcastStatusChanged"
        static let vehicleMotionChanged = "com.xanderco.dashcast.vehicleMotionChanged"
    }

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    static func broadcastExtensionBundleID(hostBundleID: String?) -> String {
        (hostBundleID ?? "com.xanderco.dashcast") + broadcastExtensionSuffix
    }

    static func postDarwinNotification(_ name: String) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            CFNotificationName(name as CFString),
            nil,
            nil,
            true
        )
    }

    /// Written by the app's parked guard, read by the broadcast extension.
    static func isVehicleMoving(in defaults: UserDefaults? = sharedDefaults) -> Bool {
        defaults?.bool(forKey: vehicleMovingKey) ?? false
    }

    static func setVehicleMoving(_ moving: Bool, in defaults: UserDefaults? = sharedDefaults) {
        guard let defaults else { return }
        if defaults.bool(forKey: vehicleMovingKey) != moving {
            defaults.set(moving, forKey: vehicleMovingKey)
            postDarwinNotification(DarwinNotification.vehicleMotionChanged)
        }
    }
}

// MARK: - Broadcast status (extension -> app)

struct BroadcastStatus: Codable, Equatable {
    enum State: String, Codable {
        case idle
        case live
        case stoppedForMotion
        case failed
    }

    var state: State
    var startedAt: Date?
    var viewerURL: String?
    var viewerCount: Int
    var message: String?
    var updatedAt: Date

    static let idle = BroadcastStatus(state: .idle, startedAt: nil, viewerURL: nil, viewerCount: 0, message: nil, updatedAt: .distantPast)

    var isLive: Bool { state == .live }

    static func load(from defaults: UserDefaults? = CarCastShared.sharedDefaults) -> BroadcastStatus {
        guard let data = defaults?.data(forKey: CarCastShared.broadcastStatusKey),
              let status = try? JSONDecoder().decode(BroadcastStatus.self, from: data) else {
            return .idle
        }
        return status
    }

    func save(to defaults: UserDefaults? = CarCastShared.sharedDefaults) {
        guard let defaults, let data = try? JSONEncoder().encode(self) else { return }
        defaults.set(data, forKey: CarCastShared.broadcastStatusKey)
    }
}

// MARK: - Local network address (for the car-browser viewer URL)

enum LocalNetworkAddress {
    /// Interface priority: Personal Hotspot bridge, then Wi-Fi, then any other en* interface.
    static func pick(from candidates: [(name: String, address: String)]) -> String? {
        let usable = candidates.filter { !$0.address.hasPrefix("169.254.") && $0.address != "127.0.0.1" }
        if let hotspot = usable.first(where: { $0.name.hasPrefix("bridge") }) { return hotspot.address }
        if let wifi = usable.first(where: { $0.name == "en0" }) { return wifi.address }
        return usable.first(where: { $0.name.hasPrefix("en") })?.address
    }

    static func preferredIPv4() -> String? {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let first = ifaddr else { return nil }
        defer { freeifaddrs(ifaddr) }

        var candidates: [(name: String, address: String)] = []
        var cursor: UnsafeMutablePointer<ifaddrs>? = first
        while let ptr = cursor {
            defer { cursor = ptr.pointee.ifa_next }
            let flags = Int32(ptr.pointee.ifa_flags)
            guard (flags & IFF_UP) != 0, (flags & IFF_RUNNING) != 0, (flags & IFF_LOOPBACK) == 0 else { continue }
            guard let addr = ptr.pointee.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) else { continue }
            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            if getnameinfo(addr, socklen_t(addr.pointee.sa_len), &host, socklen_t(host.count), nil, 0, NI_NUMERICHOST) == 0 {
                candidates.append((name: String(cString: ptr.pointee.ifa_name), address: String(cString: host)))
            }
        }
        return pick(from: candidates)
    }

    static func viewerURL(address: String?, port: UInt16 = CarCastShared.mirrorPort) -> String? {
        guard let address else { return nil }
        return "http://\(address):\(port)"
    }
}

// MARK: - MJPEG over HTTP (car-browser mirror)

enum MJPEGStream {
    static let boundary = "dashcastframe"

    enum Route: Equatable {
        case page
        case stream
        case notFound
    }

    /// Parses the request line ("GET /path HTTP/1.1") of an HTTP request.
    static func route(forRequest data: Data) -> Route {
        guard let text = String(data: data.prefix(2048), encoding: .utf8),
              let requestLine = text.components(separatedBy: "\r\n").first else { return .notFound }
        let parts = requestLine.split(separator: " ")
        guard parts.count >= 2, parts[0] == "GET" else { return .notFound }
        let path = parts[1].split(separator: "?").first.map(String.init) ?? "/"
        switch path {
        case "/", "/index.html": return .page
        case "/stream", "/stream.mjpg": return .stream
        default: return .notFound
        }
    }

    static func streamResponseHeader() -> Data {
        Data((
            "HTTP/1.1 200 OK\r\n" +
            "Content-Type: multipart/x-mixed-replace; boundary=\(boundary)\r\n" +
            "Cache-Control: no-cache, no-store, must-revalidate\r\n" +
            "Pragma: no-cache\r\n" +
            "Connection: close\r\n\r\n"
        ).utf8)
    }

    static func framePart(jpeg: Data) -> Data {
        var part = Data("--\(boundary)\r\nContent-Type: image/jpeg\r\nContent-Length: \(jpeg.count)\r\n\r\n".utf8)
        part.append(jpeg)
        part.append(Data("\r\n".utf8))
        return part
    }

    static func httpResponse(status: String, contentType: String, body: Data) -> Data {
        var response = Data((
            "HTTP/1.1 \(status)\r\n" +
            "Content-Type: \(contentType)\r\n" +
            "Content-Length: \(body.count)\r\n" +
            "Cache-Control: no-cache\r\n" +
            "Connection: close\r\n\r\n"
        ).utf8)
        response.append(body)
        return response
    }

    static func viewerPage() -> Data {
        Data("""
        <!doctype html>
        <html><head><meta charset="utf-8">
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <title>DashCast</title>
        <style>
        html,body{margin:0;height:100%;background:#000;overflow:hidden}
        img{width:100%;height:100%;object-fit:contain;display:block}
        #s{position:fixed;bottom:12px;left:12px;color:#FFE600;font:600 14px -apple-system,sans-serif;background:rgba(0,0,0,.6);padding:6px 12px;border-radius:14px}
        </style></head>
        <body><img id="v" alt=""><div id="s">DashCast · Parked mirroring</div>
        <script>
        var v=document.getElementById('v');
        function go(){v.src='/stream?t='+Date.now();}
        v.onerror=function(){setTimeout(go,1500);};
        go();
        </script></body></html>
        """.utf8)
    }
}
