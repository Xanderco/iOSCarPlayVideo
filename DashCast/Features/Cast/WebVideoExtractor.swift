import Foundation
import WebKit

/// What the injected script found on the page.
public struct WebVideoReport: Equatable {
    public var url: URL?
    public var title: String
    public var isBlob: Bool
    public var hasEME: Bool
    public var hasVideo: Bool
    public var isMainFrame: Bool

    public init(url: URL?, title: String, isBlob: Bool, hasEME: Bool, hasVideo: Bool, isMainFrame: Bool) {
        self.url = url
        self.title = title
        self.isBlob = isBlob
        self.hasEME = hasEME
        self.hasVideo = hasVideo
        self.isMainFrame = isMainFrame
    }

    /// Parses the dictionary posted by / returned from the injected script.
    public init?(dictionary raw: Any?) {
        guard let dict = raw as? [String: Any] else { return nil }
        var parsedURL: URL?
        if let s = dict["url"] as? String,
           let u = URL(string: s),
           let scheme = u.scheme?.lowercased(),
           scheme == "http" || scheme == "https" {
            parsedURL = u
        }
        self.url = parsedURL
        self.title = (dict["title"] as? String) ?? ""
        self.isBlob = (dict["isBlob"] as? Bool) ?? false
        self.hasEME = (dict["hasEME"] as? Bool) ?? false
        self.hasVideo = (dict["hasVideo"] as? Bool) ?? false
        self.isMainFrame = (dict["isMainFrame"] as? Bool) ?? true
    }
}

/// Outcome of a "Send to car" request.
public enum WebVideoExtractionResult: Equatable {
    case found(url: URL, title: String)
    case drmProtected
    case unsupportedStream
    case noVideo
}

/// Owns the browser's WKWebView, injects the video-detection script and
/// collects reports posted through the `dashcast` script message handler.
@MainActor
public final class WebVideoExtractor: NSObject, ObservableObject, WKScriptMessageHandler {
    public static let messageHandlerName = "dashcast"

    public let webView: WKWebView
    /// Most recent report posted by any frame (iframes included).
    @Published public private(set) var lastFrameReport: WebVideoReport?

    public override init() {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.allowsAirPlayForMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []

        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(source: Self.emeHookScript,
                                              injectionTime: .atDocumentStart,
                                              forMainFrameOnly: false))
        controller.addUserScript(WKUserScript(source: Self.detectionScript,
                                              injectionTime: .atDocumentEnd,
                                              forMainFrameOnly: false))
        config.userContentController = controller

        self.webView = WKWebView(frame: .zero, configuration: config)
        super.init()
        // Weak proxy: the content controller retains its handlers strongly.
        controller.add(WeakScriptMessageHandler(self), name: Self.messageHandlerName)
        webView.allowsBackForwardNavigationGestures = true
    }

    public func userContentController(_ userContentController: WKUserContentController,
                                      didReceive message: WKScriptMessage) {
        guard message.name == Self.messageHandlerName,
              let report = WebVideoReport(dictionary: message.body) else { return }
        // Keep the most useful report: prefer one that actually has a video.
        if report.hasVideo || report.url != nil || lastFrameReport == nil {
            lastFrameReport = report
        }
    }

    /// Asks the main frame for its current video and merges it with the
    /// latest report from any iframe.
    public func requestCurrentVideo(completion: @escaping @MainActor (WebVideoExtractionResult) -> Void) {
        webView.evaluateJavaScript("window.__dashcast ? window.__dashcast.scan(true) : null") { [weak self] value, _ in
            guard let self else { return }
            let mainReport = WebVideoReport(dictionary: value)
            let pageTitle = self.webView.title ?? ""
            completion(Self.resolve(main: mainReport, frame: self.lastFrameReport, pageTitle: pageTitle))
        }
    }

    public func resetReports() {
        lastFrameReport = nil
    }

    /// Decides what to do based on the main-frame and iframe reports.
    nonisolated public static func resolve(main: WebVideoReport?, frame: WebVideoReport?, pageTitle: String) -> WebVideoExtractionResult {
        let reports = [main, frame].compactMap { $0 }
        if reports.contains(where: { $0.hasEME }) {
            return .drmProtected
        }
        if let withURL = reports.first(where: { $0.url != nil }), let url = withURL.url {
            let title = !pageTitle.isEmpty ? pageTitle : (withURL.title.isEmpty ? "Web video" : withURL.title)
            return .found(url: url, title: title)
        }
        if reports.contains(where: { $0.isBlob || $0.hasVideo }) {
            return .unsupportedStream
        }
        return .noVideo
    }

    // MARK: - Scripts

    /// Injected at document start so DRM negotiation done early by players is noticed.
    static let emeHookScript = """
    (function () {
      if (window.__dashcastEMEHooked) { return; }
      window.__dashcastEMEHooked = true;
      window.__dashcastEME = false;
      try {
        if (navigator.requestMediaKeySystemAccess) {
          var orig = navigator.requestMediaKeySystemAccess.bind(navigator);
          navigator.requestMediaKeySystemAccess = function () {
            window.__dashcastEME = true;
            return orig.apply(null, arguments);
          };
        }
      } catch (e) {}
      try {
        if (window.HTMLMediaElement && HTMLMediaElement.prototype.webkitSetMediaKeys) {
          var origSet = HTMLMediaElement.prototype.webkitSetMediaKeys;
          HTMLMediaElement.prototype.webkitSetMediaKeys = function () {
            window.__dashcastEME = true;
            return origSet.apply(this, arguments);
          };
        }
      } catch (e) {}
    })();
    """

    /// Injected at document end in every frame; finds the current/largest video.
    static let detectionScript = """
    (function () {
      if (window.__dashcast) { return; }
      var hls = [];
      function isHttp(u) { return typeof u === 'string' && /^https?:\\/\\//i.test(u); }
      function collectHls() {
        try {
          var entries = performance.getEntriesByType('resource') || [];
          for (var i = 0; i < entries.length; i++) {
            var n = entries[i].name;
            if (/\\.m3u8(\\?|#|$)/i.test(n) && isHttp(n) && hls.indexOf(n) < 0) { hls.push(n); }
          }
        } catch (e) {}
      }
      function pickVideo() {
        var vids = Array.prototype.slice.call(document.querySelectorAll('video'));
        if (!vids.length) { return null; }
        var playing = vids.filter(function (v) { return !v.paused && !v.ended && v.readyState > 2; });
        var pool = playing.length ? playing : vids;
        pool.sort(function (a, b) {
          return (b.clientWidth * b.clientHeight) - (a.clientWidth * a.clientHeight);
        });
        return pool[0];
      }
      function scan() {
        collectHls();
        var v = pickVideo();
        var src = null, isBlob = false, hasEME = !!window.__dashcastEME;
        if (v) {
          src = v.currentSrc || v.src || null;
          if (!isHttp(src)) {
            var sources = v.querySelectorAll('source[src]');
            for (var i = 0; i < sources.length; i++) {
              if (isHttp(sources[i].src)) { src = sources[i].src; break; }
            }
          }
          if (src && /^(blob:|mediasource:)/i.test(src)) { isBlob = true; }
          if (v.mediaKeys || v.webkitKeys) { hasEME = true; }
        }
        var url = isHttp(src) ? src : null;
        if (!url && hls.length) { url = hls[hls.length - 1]; }
        var isMain = true;
        try { isMain = (window.top === window); } catch (e) { isMain = false; }
        return {
          url: url,
          title: document.title || '',
          isBlob: isBlob,
          hasEME: hasEME,
          hasVideo: !!v,
          isMainFrame: isMain
        };
      }
      function post(r) {
        try { window.webkit.messageHandlers.dashcast.postMessage(r); } catch (e) {}
      }
      window.__dashcast = {
        scan: function (shouldPost) {
          var r = scan();
          if (shouldPost) { post(r); }
          return r;
        }
      };
      var report = function () { var r = scan(); if (r.hasVideo || r.url) { post(r); } };
      document.addEventListener('playing', report, true);
      document.addEventListener('loadedmetadata', report, true);
      report();
    })();
    """
}

/// Breaks the WKUserContentController -> handler retain cycle.
private final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    weak var target: WebVideoExtractor?

    init(_ target: WebVideoExtractor) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController,
                               didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
