import Foundation

/// Deterministic, offline network layer used by UI tests (`-stubNetwork`) and unit tests.
///
/// All fixtures live under `https://stub.dashcast.test`. Playlist fixtures point at videos
/// bundled in the app, so playback works with no internet and no flaky live streams.
/// Any other host fails immediately with `URLError(.notConnectedToInternet)`.
public final class StubNetwork: URLProtocol {
    public static let host = "stub.dashcast.test"

    public struct Response {
        public var status: Int
        public var headers: [String: String]
        public var body: Data

        public init(status: Int = 200, headers: [String: String] = [:], body: Data) {
            self.status = status
            self.headers = headers
            self.body = body
        }

        public init(status: Int = 200, contentType: String = "text/plain", text: String) {
            self.init(status: status, headers: ["Content-Type": contentType], body: Data(text.utf8))
        }
    }

    private static let lock = NSLock()
    private static var overrides: [String: Response] = [:]
    private static var _requestLog: [URLRequest] = []

    /// Requests seen since the last `reset()` (thread-safe copy).
    public static var requestLog: [URLRequest] {
        lock.lock(); defer { lock.unlock() }
        return _requestLog
    }

    /// Registers the protocol for `URLSession.shared` and every `URLSessionConfiguration.default`.
    public static func install() {
        URLProtocol.registerClass(StubNetwork.self)
    }

    /// A session that always goes through the stub (for unit tests that inject sessions).
    public static func makeSession() -> URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [StubNetwork.self]
        return URLSession(configuration: config)
    }

    /// Overrides (or adds) the response for an absolute URL string.
    public static func stub(_ urlString: String, _ response: Response) {
        lock.lock(); defer { lock.unlock() }
        overrides[urlString] = response
    }

    public static func reset() {
        lock.lock(); defer { lock.unlock() }
        overrides.removeAll()
        _requestLog.removeAll()
    }

    // MARK: Built-in fixtures

    public static func url(_ path: String) -> URL {
        URL(string: "https://\(host)\(path.hasPrefix("/") ? path : "/" + path)")!
    }

    /// Three-channel playlist whose streams are bundled local videos.
    public static var demoPlaylistM3U: String {
        let night = Bundle.main.url(forResource: "night_drive", withExtension: "mp4")?.absoluteString
            ?? url("/media/night_drive.mp4").absoluteString
        let lap = Bundle.main.url(forResource: "track_lap", withExtension: "mp4")?.absoluteString
            ?? url("/media/track_lap.mp4").absoluteString
        return """
        #EXTM3U
        #EXTINF:-1 tvg-id="stub1" group-title="Stub News",Stub Channel 1
        \(night)
        #EXTINF:-1 tvg-id="stub2" group-title="Stub News",Stub Channel 2
        \(lap)
        #EXTINF:-1 tvg-id="stub3" group-title="Stub Sports",Stub Channel 3
        https://\(host)/media/clip.mp4
        """
    }

    static func builtInResponse(for url: URL) -> Response? {
        guard url.host == host else { return nil }
        switch url.path {
        case "/playlist.m3u", "/playlist.m3u8":
            return Response(contentType: "audio/x-mpegurl", text: demoPlaylistM3U)
        case "/empty.m3u":
            return Response(contentType: "audio/x-mpegurl", text: "#EXTM3U\n")
        case "/missing.m3u":
            return Response(status: 404, text: "Not Found")
        case "/server-error.m3u":
            return Response(status: 500, text: "Internal Server Error")
        case "/page.html":
            return Response(contentType: "text/html", text: """
            <html><head><title>Stub Video Page</title></head>
            <body><video src="https://\(host)/media/clip.mp4"></video></body></html>
            """)
        default:
            return nil
        }
    }

    // MARK: URLProtocol

    public override class func canInit(with request: URLRequest) -> Bool {
        guard let scheme = request.url?.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    public override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    public override func startLoading() {
        guard let url = request.url else {
            client?.urlProtocol(self, didFailWithError: URLError(.badURL))
            return
        }
        Self.lock.lock()
        Self._requestLog.append(request)
        let override = Self.overrides[url.absoluteString]
        Self.lock.unlock()

        guard let response = override ?? Self.builtInResponse(for: url) else {
            client?.urlProtocol(self, didFailWithError: URLError(.notConnectedToInternet))
            return
        }
        let http = HTTPURLResponse(url: url, statusCode: response.status,
                                   httpVersion: "HTTP/1.1", headerFields: response.headers)!
        client?.urlProtocol(self, didReceive: http, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: response.body)
        client?.urlProtocolDidFinishLoading(self)
    }

    public override func stopLoading() {}
}
