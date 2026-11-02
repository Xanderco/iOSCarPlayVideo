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
    @State private var urlString: String = ""
    @State private var isShowingHomeGrid: Bool = true
    @State private var webView = WKWebView()
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var currentTitle: String = "Browser"
    @State private var showingSendToCarAlert: Bool = false

    public static let preaddedSources: [StreamingSource] = [
        StreamingSource(id: "tiktok", name: "TikTok", url: "https://www.tiktok.com", iconSystemName: "music.note", tileColor: Color.black, badgeLetter: "TT"),
        StreamingSource(id: "youtube", name: "YouTube", url: "https://m.youtube.com", iconSystemName: "play.rectangle.fill", tileColor: Color(red: 0.85, green: 0.1, blue: 0.1), badgeLetter: "YT"),
        StreamingSource(id: "instagram", name: "Instagram", url: "https://www.instagram.com", iconSystemName: "camera.fill", tileColor: Color(red: 0.8, green: 0.15, blue: 0.5), badgeLetter: "IG"),
        StreamingSource(id: "google", name: "Google", url: "https://www.google.com", iconSystemName: "magnifyingglass", tileColor: Color(red: 0.2, green: 0.5, blue: 0.9), badgeLetter: "G"),
        StreamingSource(id: "netflix", name: "Netflix", url: "https://www.netflix.com", iconSystemName: "tv.fill", tileColor: Color(red: 0.12, green: 0.12, blue: 0.12), badgeLetter: "N"),
        StreamingSource(id: "prime", name: "Prime Video", url: "https://www.primevideo.com", iconSystemName: "play.tv.fill", tileColor: Color(red: 0.05, green: 0.45, blue: 0.75), badgeLetter: "PV"),
        StreamingSource(id: "hulu", name: "Hulu", url: "https://www.hulu.com", iconSystemName: "play.circle.fill", tileColor: Color(red: 0.1, green: 0.75, blue: 0.4), badgeLetter: "H"),
        StreamingSource(id: "disney", name: "Disney+", url: "https://www.disneyplus.com", iconSystemName: "sparkles.tv.fill", tileColor: Color(red: 0.08, green: 0.2, blue: 0.55), badgeLetter: "D+"),
        StreamingSource(id: "hbomax", name: "HBO Max", url: "https://www.max.com", iconSystemName: "tv.inset.filled", tileColor: Color(red: 0.35, green: 0.15, blue: 0.7), badgeLetter: "MAX"),
        StreamingSource(id: "appletv", name: "Apple TV", url: "https://tv.apple.com", iconSystemName: "apple.logo", tileColor: Color(red: 0.2, green: 0.2, blue: 0.22), badgeLetter: "TV"),
        StreamingSource(id: "peacock", name: "Peacock", url: "https://www.peacocktv.com", iconSystemName: "circle.grid.cross.fill", tileColor: Color(red: 0.1, green: 0.6, blue: 0.7), badgeLetter: "P"),
        StreamingSource(id: "paramount", name: "Paramount+", url: "https://www.paramountplus.com", iconSystemName: "mountain.2.fill", tileColor: Color(red: 0.0, green: 0.35, blue: 0.8), badgeLetter: "P+"),
        StreamingSource(id: "tubi", name: "Tubi", url: "https://tubitv.com", iconSystemName: "play.square.fill", tileColor: Color(red: 0.85, green: 0.35, blue: 0.1), badgeLetter: "Tubi"),
        StreamingSource(id: "plutotv", name: "Pluto TV", url: "https://pluto.tv", iconSystemName: "circle.circle.fill", tileColor: Color(red: 0.95, green: 0.75, blue: 0.0), badgeLetter: "Pluto"),
        StreamingSource(id: "twitch", name: "Twitch", url: "https://m.twitch.tv", iconSystemName: "gamecontroller.fill", tileColor: Color(red: 0.5, green: 0.2, blue: 0.85), badgeLetter: "Twitch"),
        StreamingSource(id: "crunchyroll", name: "Crunchyroll", url: "https://www.crunchyroll.com", iconSystemName: "circle.fill", tileColor: Color(red: 0.95, green: 0.45, blue: 0.05), badgeLetter: "CR"),
        StreamingSource(id: "plex", name: "Plex", url: "https://app.plex.tv", iconSystemName: "play.square.stack.fill", tileColor: Color(red: 0.85, green: 0.55, blue: 0.0), badgeLetter: "Plex"),
        StreamingSource(id: "roku", name: "Roku", url: "https://therokuchannel.roku.com", iconSystemName: "plus.square.fill", tileColor: Color(red: 0.45, green: 0.1, blue: 0.65), badgeLetter: "Roku"),
        StreamingSource(id: "vimeo", name: "Vimeo", url: "https://vimeo.com", iconSystemName: "v.circle.fill", tileColor: Color(red: 0.1, green: 0.65, blue: 0.85), badgeLetter: "Vimeo"),
        StreamingSource(id: "dailymotion", name: "Dailymotion", url: "https://www.dailymotion.com", iconSystemName: "d.circle.fill", tileColor: Color(red: 0.3, green: 0.15, blue: 0.6), badgeLetter: "DM")
    ]

    public init(initialURL: String = "") {
        self._urlString = State(initialValue: initialURL)
        self._isShowingHomeGrid = State(initialValue: initialURL.isEmpty)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Top Search / Address Bar
                topAddressBar

                // Content Area: Grid of 20 Sources OR Active WebView
                if isShowingHomeGrid {
                    sourcesHomeGridView
                } else {
                    WebViewRepresentable(
                        webView: webView,
                        urlString: $urlString,
                        canGoBack: $canGoBack,
                        canGoForward: $canGoForward,
                        title: $currentTitle
                    )
                    .ignoresSafeArea(edges: .bottom)
                }

                // Bottom Browser Bar matching CarDash 1:1 (<, >, ⌂, 🔖, 🚗 Send to car)
                bottomBrowserToolbar
            }
            .background(Color.dashBackground)
            .navigationBarHidden(true)
            .alert("Sent to Car Screen", isPresented: $showingSendToCarAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Video stream URL has been routed to your external car display.")
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
                // Device toggle
            } label: {
                Image(systemName: "iphone")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.dashYellow)
            }

            Button {
                // Options menu
            } label: {
                Image(systemName: "ellipsis.circle.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(Color.dashYellow)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.dashSurface.opacity(0.8))
    }

    // MARK: - 20 Sources Grid View

    private var sourcesHomeGridView: some View {
        ScrollView {
            VStack(spacing: 20) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 14), count: 4), spacing: 16) {
                    ForEach(Self.preaddedSources) { source in
                        Button {
                            urlString = source.url
                            isShowingHomeGrid = false
                            if let url = URL(string: source.url) {
                                webView.load(URLRequest(url: url))
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

                                Text(source.name)
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
                HStack(spacing: 12) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.dashYellow)

                    Text("Bookmarks")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.dashTextPrimary)

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.dashTextMuted)
                }
                .padding(16)
                .background(Color.dashSurface)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
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
                // Bookmarks
            } label: {
                Image(systemName: "bookmark")
                    .font(.system(size: 16))
                    .foregroundStyle(Color.dashTextSecondary)
                    .frame(maxWidth: .infinity)
            }

            Button {
                showingSendToCarAlert = true
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

    private func navigateToInput() {
        guard !urlString.isEmpty else { return }
        var fullURL = urlString
        if !fullURL.lowercased().hasPrefix("http://") && !fullURL.lowercased().hasPrefix("https://") {
            if fullURL.contains(".") && !fullURL.contains(" ") {
                fullURL = "https://" + fullURL
            } else {
                let encoded = fullURL.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? fullURL
                fullURL = "https://www.google.com/search?q=\(encoded)"
            }
        }
        isShowingHomeGrid = false
        if let url = URL(string: fullURL) {
            webView.load(URLRequest(url: url))
        }
    }
}

public struct WebViewRepresentable: UIViewRepresentable {
    public let webView: WKWebView
    @Binding public var urlString: String
    @Binding public var canGoBack: Bool
    @Binding public var canGoForward: Bool
    @Binding public var title: String

    public func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    public func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.configuration.allowsInlineMediaPlayback = true
        webView.configuration.mediaTypesRequiringUserActionForPlayback = []
        return webView
    }

    public func updateUIView(_ uiView: WKWebView, context: Context) {}

    public class Coordinator: NSObject, WKNavigationDelegate {
        var parent: WebViewRepresentable

        init(_ parent: WebViewRepresentable) {
            self.parent = parent
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
