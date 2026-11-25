import SwiftUI
import WebKit

public struct StreamingSource: Identifiable {
    public let id: String
    public let name: String
    public let url: String
    public let iconSystemName: String
    public let tileColor: Color
    public let badgeLetter: String

    public init(id: String, name: String, url: String, iconSystemName: String, tileColor: Color, badgeLetter: String) {
        self.id = id
        self.name = name
        self.url = url
        self.iconSystemName = iconSystemName
        self.tileColor = tileColor
        self.badgeLetter = badgeLetter
    }
}

public struct WebVideoBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var urlString: String = ""
    @State private var isShowingHomeGrid: Bool = true
    @StateObject private var extractor = WebVideoExtractor()
    @StateObject private var bookmarkStore = WebBookmarkStore.shared
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var currentTitle: String = "Browser"
    @State private var showingSendToCarAlert: Bool = false
    @State private var sendToCarAlertTitle: String = ""
    @State private var sendToCarAlertMessage: String = ""
    @State private var isExtracting: Bool = false
    @State private var showingBookmarksSheet: Bool = false

    private var webView: WKWebView { extractor.webView }

    /// Neutral, trademark-free quick-access destinations (App Review 4.1 / 5.2 compliant).
    public static let preaddedSources: [StreamingSource] = [
        StreamingSource(
            id: "web_search",
            name: "Web Search",
            url: "https://duckduckgo.com",
            iconSystemName: "magnifyingglass",
            tileColor: Color(red: 0.16, green: 0.36, blue: 0.62),
            badgeLetter: "WEB"
        ),
        StreamingSource(
            id: "public_archive",
            name: "Open Archive",
            url: "https://archive.org/details/movies",
            iconSystemName: "film.stack",
            tileColor: Color(red: 0.22, green: 0.24, blue: 0.30),
            badgeLetter: "OPEN"
        ),
        StreamingSource(
            id: "local_media_server",
            name: "Media Server",
            url: "http://localhost:8096",
            iconSystemName: "server.rack",
            tileColor: Color(red: 0.15, green: 0.42, blue: 0.34),
            badgeLetter: "LAN"
        )
    ]

    public init(initialURL: String = "") {
        self._urlString = State(initialValue: initialURL)
        self._isShowingHomeGrid = State(initialValue: initialURL.isEmpty)
    }

    private var activeNavigableURL: URL? {
        guard !isShowingHomeGrid else { return nil }
        return webView.url ?? WebBookmarkStore.normalizedHTTPURLString(from: urlString).flatMap(URL.init(string:))
    }

    private var isCurrentPageBookmarked: Bool {
        guard let activeURL = activeNavigableURL?.absoluteString else { return false }
        return bookmarkStore.isBookmarked(urlString: activeURL)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Search / Address Bar
                topAddressBar

                // Content Area: Grid of Sources OR Active WebView
                if isShowingHomeGrid {
                    sourcesHomeGridView
                } else {
                    WebViewRepresentable(
                        webView: webView,
                        urlString: $urlString,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward,
                        title: $currentTitle,
                        customUserAgent: bookmarkStore.userAgentMode.customUserAgent,
                        onNavigationCommitted: { extractor.resetReports() }
                    )
                    .ignoresSafeArea(edges: .bottom)
                }

                // Bottom Browser Toolbar (<, >, ⌂, 🔖, 🚗 Send to car)
                bottomBrowserToolbar
            }
            .background(Color.dashBackground)
            .navigationBarHidden(true)
            .alert(sendToCarAlertTitle, isPresented: $showingSendToCarAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(sendToCarAlertMessage)
            }
            .sheet(isPresented: $showingBookmarksSheet) {
                bookmarksSheet
            }
        }
    }

    // MARK: - Top Address Bar

    private var topAddressBar: some View {
        HStack(spacing: 10) {
            Button("Exit") {
                dismiss()
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(Color.dashYellow)

            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(Color.dashTextMuted)

                TextField("Search or website", text: $urlString)
                    .font(.system(size: 14))
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .onSubmit {
                        navigateToInput()
                    }

                if !urlString.isEmpty {
                    Button {
                        navigateToInput()
                    } label: {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.dashYellow)
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(Color.dashSurface)
            .clipShape(RoundedRectangle(cornerRadius: 12))

            Button {
                bookmarkStore.toggleUserAgentMode()
                webView.customUserAgent = bookmarkStore.userAgentMode.customUserAgent
                if !isShowingHomeGrid {
                    webView.reload()
                }
            } label: {
                Image(systemName: bookmarkStore.userAgentMode.iconSystemName)
                    .font(.system(size: 15))
                    .foregroundStyle(bookmarkStore.userAgentMode == .desktop ? Color.dashGreen : Color.dashYellow)
            }
            .accessibilityLabel(bookmarkStore.userAgentMode.label)
            .accessibilityIdentifier("Browser_UserAgentToggle")

            Menu {
                if let activeURL = activeNavigableURL {
                    Button {
                        let pageTitle = currentTitle.isEmpty || currentTitle == "Browser"
                            ? (activeURL.host ?? activeURL.absoluteString)
                            : currentTitle
                        bookmarkStore.toggleBookmark(title: pageTitle, urlString: activeURL.absoluteString)
                    } label: {
                        Label(
                            isCurrentPageBookmarked ? "Remove Bookmark" : "Add Bookmark",
                            systemImage: isCurrentPageBookmarked ? "bookmark.slash" : "bookmark.fill"
                        )
                    }

                    Button {
                        webView.reload()
                    } label: {
                        Label("Reload Page", systemImage: "arrow.clockwise")
                    }

                    Button {
                        openURL(activeURL)
                    } label: {
                        Label("Open in Safari", systemImage: "safari")
                    }

                    Divider()
                }

                Button {
                    showingBookmarksSheet = true
                } label: {
                    Label("Bookmarks", systemImage: "book")
                }

                Button(role: .destructive) {
                    Task { @MainActor in
                        await clearBrowserData()
                    }
                } label: {
                    Label("Clear Website Data", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.dashYellow)
            }
            .accessibilityLabel("Browser options")
            .accessibilityIdentifier("Browser_OptionsMenu")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.dashSurface.opacity(0.8))
    }

    // MARK: - Sources Grid View

    private var sourcesHomeGridView: some View {
        ScrollView {
            VStack(spacing: 20) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 3), spacing: 16) {
                    ForEach(Self.preaddedSources) { source in
                        Button {
                            if let url = URL(string: source.url) {
                                loadURL(url)
                            }
                        } label: {
                            VStack(spacing: 6) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(source.tileColor)
                                        .frame(width: 66, height: 66)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                        )
                                        .shadow(color: Color.black.opacity(0.4), radius: 6, y: 3)

                                    VStack(spacing: 2) {
                                        Image(systemName: source.iconSystemName)
                                            .font(.system(size: 24))
                                            .foregroundStyle(Color.white)

                                        Text(source.badgeLetter)
                                            .font(.system(size: 9, weight: .heavy))
                                            .foregroundStyle(Color.white.opacity(0.85))
                                    }
                                }

                                Text(LocalizedStringKey(source.name))
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(Color.dashTextPrimary)
                                    .lineLimit(1)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                // Bookmarks Card at bottom of grid
                Button {
                    showingBookmarksSheet = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "bookmark.fill")
                            .font(.system(size: 16))
                            .foregroundStyle(Color.dashYellow)

                        Text("Bookmarks")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundStyle(Color.dashTextPrimary)

                        Spacer()

                        if !bookmarkStore.bookmarks.isEmpty {
                            Text("\(bookmarkStore.bookmarks.count)")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.dashTextSecondary)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color.dashTextMuted)
                    }
                    .padding(16)
                    .background(Color.dashSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("Browser_BookmarksCard")
                .padding(.horizontal, 16)

                if !bookmarkStore.bookmarks.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Saved Bookmarks")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(Color.dashYellow)
                            .padding(.horizontal, 20)

                        VStack(spacing: 1) {
                            ForEach(bookmarkStore.bookmarks.prefix(5)) { bookmark in
                                Button {
                                    if let url = bookmark.url {
                                        loadURL(url)
                                    }
                                } label: {
                                    HStack(spacing: 12) {
                                        Image(systemName: "globe")
                                            .font(.system(size: 14))
                                            .foregroundStyle(Color.dashYellow)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(bookmark.title)
                                                .font(.system(size: 14, weight: .semibold))
                                                .foregroundStyle(Color.dashTextPrimary)
                                                .lineLimit(1)
                                            Text(bookmark.hostDisplay)
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color.dashTextSecondary)
                                                .lineLimit(1)
                                        }
                                        Spacer()
                                        Image(systemName: "arrow.up.right")
                                            .font(.system(size: 12))
                                            .foregroundStyle(Color.dashTextMuted)
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                    .background(Color.dashSurface)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .padding(.horizontal, 16)
                    }
                    .padding(.bottom, 20)
                } else {
                    Spacer().frame(height: 10)
                }
            }
        }
    }

    // MARK: - Bookmarks Sheet

    private var bookmarksSheet: some View {
        NavigationStack {
            ZStack {
                Color.dashBackground.ignoresSafeArea()

                if bookmarkStore.bookmarks.isEmpty {
                    VStack(spacing: 14) {
                        Image(systemName: "bookmark")
                            .font(.system(size: 38))
                            .foregroundStyle(Color.dashYellow)
                        Text("No Bookmarks Yet")
                            .font(.system(size: 17, weight: .bold))
                            .foregroundStyle(Color.dashTextPrimary)
                        Text("Open any website and use Add Bookmark from the options menu to save it here.")
                            .font(.system(size: 13))
                            .foregroundStyle(Color.dashTextSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        ForEach(bookmarkStore.bookmarks) { bookmark in
                            Button {
                                if let url = bookmark.url {
                                    showingBookmarksSheet = false
                                    loadURL(url)
                                }
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(bookmark.title)
                                        .font(.system(size: 15, weight: .semibold))
                                        .foregroundStyle(Color.dashTextPrimary)
                                    Text(bookmark.urlString)
                                        .font(.system(size: 12))
                                        .foregroundStyle(Color.dashTextSecondary)
                                        .lineLimit(1)
                                }
                                .padding(.vertical, 4)
                            }
                            .listRowBackground(Color.dashSurface)
                        }
                        .onDelete { offsets in
                            bookmarkStore.removeBookmarks(at: offsets)
                        }
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .navigationTitle("Bookmarks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        showingBookmarksSheet = false
                    }
                    .foregroundStyle(Color.dashYellow)
                }

                if let activeURL = activeNavigableURL {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            let pageTitle = currentTitle.isEmpty || currentTitle == "Browser"
                                ? (activeURL.host ?? activeURL.absoluteString)
                                : currentTitle
                            bookmarkStore.toggleBookmark(title: pageTitle, urlString: activeURL.absoluteString)
                        } label: {
                            Image(systemName: isCurrentPageBookmarked ? "bookmark.fill" : "plus")
                                .foregroundStyle(Color.dashYellow)
                        }
                        .accessibilityLabel(isCurrentPageBookmarked ? "Remove Bookmark" : "Add Bookmark")
                    }
                }
            }
        }
    }

    // MARK: - Bottom Toolbar

    private var bottomBrowserToolbar: some View {
        HStack(spacing: 0) {
            Button {
                webView.goBack()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(canGoBack ? Color.dashYellow : Color.dashTextMuted)
                    .frame(maxWidth: .infinity)
            }
            .disabled(!canGoBack)

            Button {
                webView.goForward()
            } label: {
                Image(systemName: "chevron.right")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(canGoForward ? Color.dashYellow : Color.dashTextMuted)
                    .frame(maxWidth: .infinity)
            }
            .disabled(!canGoForward)

            Button {
                isShowingHomeGrid = true
                urlString = ""
            } label: {
                Image(systemName: "house.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(isShowingHomeGrid ? Color.dashYellow : Color.dashTextSecondary)
                    .frame(maxWidth: .infinity)
            }

            Button {
                showingBookmarksSheet = true
            } label: {
                Image(systemName: isCurrentPageBookmarked ? "bookmark.fill" : "bookmark")
                    .font(.system(size: 16))
                    .foregroundStyle(isCurrentPageBookmarked ? Color.dashYellow : Color.dashTextSecondary)
                    .frame(maxWidth: .infinity)
            }
            .accessibilityLabel("Bookmarks")
            .accessibilityIdentifier("Browser_BookmarksButton")

            Button {
                sendCurrentVideoToCar()
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "car.side.fill")
                        .font(.system(size: 14))
                    Text("Send to car")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(Color.dashYellow)
                .frame(maxWidth: .infinity)
            }
            .disabled(isExtracting)
        }
        .padding(.vertical, 12)
        .background(Color.dashSurface)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(Color.dashBorder),
            alignment: .top
        )
    }

    // MARK: - Send to car & Navigation

    private func sendCurrentVideoToCar() {
        guard !isShowingHomeGrid else {
            presentSendResult(.noVideo)
            return
        }
        isExtracting = true
        extractor.requestCurrentVideo { result in
            isExtracting = false
            if case let .found(url, title) = result {
                VideoPlayerService.shared.playWebVideo(url: url, title: title)
            }
            presentSendResult(result)
        }
    }

    private func presentSendResult(_ result: WebVideoExtractionResult) {
        switch result {
        case .found:
            sendToCarAlertTitle = "Sent to DashCast"
            sendToCarAlertMessage = "Playing on DashCast player — use AirPlay to send it to your car display."
        case .drmProtected:
            sendToCarAlertTitle = "Protected Video"
            sendToCarAlertMessage = "This video is DRM-protected and can't be sent to the car."
        case .unsupportedStream:
            sendToCarAlertTitle = "Can't Hand Off"
            sendToCarAlertMessage = "This site streams in a way that can't be handed off."
        case .noVideo:
            sendToCarAlertTitle = "No Video Found"
            sendToCarAlertMessage = "Start playing a video on the page, then tap Send to car again."
        }
        showingSendToCarAlert = true
    }

    private func navigateToInput() {
        guard let url = WebBookmarkStore.resolveNavigationURL(from: urlString) else { return }
        loadURL(url)
    }

    private func loadURL(_ url: URL) {
        urlString = url.absoluteString
        isShowingHomeGrid = false
        extractor.resetReports()
        webView.customUserAgent = bookmarkStore.userAgentMode.customUserAgent
        webView.load(URLRequest(url: url))
    }

    private func clearBrowserData() async {
        await WKWebsiteDataStore.default().removeData(
            ofTypes: WKWebsiteDataStore.allWebsiteDataTypes(),
            modifiedSince: .distantPast
        )
        sendToCarAlertTitle = "Browser Data Cleared"
        sendToCarAlertMessage = "Cookies, cache, and website data have been cleared."
        showingSendToCarAlert = true
    }
}

public struct WebViewRepresentable: UIViewRepresentable {
    public let webView: WKWebView
    @Binding public var urlString: String
    @Binding public var canGoBack: Bool
    @Binding public var canGoForward: Bool
    @Binding public var title: String
    public var customUserAgent: String?
    /// Called when a new main-frame navigation commits (link taps included),
    /// so stale video reports from the previous page are discarded.
    public var onNavigationCommitted: (() -> Void)? = nil

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = customUserAgent
        // Media configuration (inline playback, AirPlay, autoplay) and the
        // video-detection user scripts are set up by WebVideoExtractor at init.
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.customUserAgent != customUserAgent {
            uiView.customUserAgent = customUserAgent
        }
    }

    public class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable

        init(_ parent: WebViewRepresentable) {
            self.parent = parent
        }

        public func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
            parent.onNavigationCommitted?()
        }

        public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.canGoBack = webView.canGoBack
            parent.canGoForward = webView.canGoForward
            if let current = webView.url?.absoluteString {
                parent.urlString = current
            }
            if let pageTitle = webView.title, !pageTitle.isEmpty {
                parent.title = pageTitle
            }
        }
    }
}
