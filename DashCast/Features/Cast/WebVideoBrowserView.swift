import SwiftUI
import WebKit

public struct WebVideoBrowserView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var urlString: String = "https://m.youtube.com"
    @State private var webView = WKWebView()
    @State private var canGoBack: Bool = false
    @State private var canGoForward: Bool = false
    @State private var currentTitle: String = "Web Browser"

    public init(initialURL: String = "https://m.youtube.com") {
        self._urlString = State(initialValue: initialURL)
    }

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Address Bar & Controls
                HStack(spacing: 12) {
                    Button {
                        webView.goBack()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(canGoBack ? Color.dashCyan : Color.dashTextMuted)
                    }
                    .disabled(!canGoBack)

                    Button {
                        webView.goForward()
                    } label: {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(canGoForward ? Color.dashCyan : Color.dashTextMuted)
                    }
                    .disabled(!canGoForward)

                    HStack {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.dashGreen)

                        TextField("Enter web address or search", text: $urlString)
                            .font(.system(size: 14))
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .onSubmit {
                                loadURL()
                            }

                        Button {
                            loadURL()
                        } label: {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 14))
                                .foregroundStyle(Color.dashTextSecondary)
                        }
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color.dashSurface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.dashBackground)

                // Quick Launch Bookmarks
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        quickBookmark(title: "YouTube", url: "https://m.youtube.com")
                        quickBookmark(title: "Vimeo", url: "https://vimeo.com/watch")
                        quickBookmark(title: "Twitch", url: "https://m.twitch.tv")
                        quickBookmark(title: "Red Bull TV", url: "https://www.redbull.com/tv")
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
                .background(Color.dashBackground)

                // WebView Representable
                WebViewRepresentable(
                    webView: webView,
                    urlString: $urlString,
                    canGoBack: $canGoBack,
                    canGoForward: $canGoForward,
                    title: $currentTitle
                )
                .ignoresSafeArea(edges: .bottom)
            }
            .background(Color.dashBackground)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundStyle(Color.dashCyan)
                }
                ToolbarItem(placement: .principal) {
                    Text(currentTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.dashTextPrimary)
                        .lineLimit(1)
                }
            }
            .onAppear {
                loadURL()
            }
        }
    }

    private func quickBookmark(title: String, url: String) -> some View {
        Button {
            urlString = url
            loadURL()
        } label: {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Color.dashTextPrimary)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.dashSurfaceHighlight)
                .clipShape(Capsule())
        }
    }

    private func loadURL() {
        var formatted = urlString.trimmingCharacters(in: .whitespacesAndNewlines)
        if !formatted.lowercased().hasPrefix("http://") && !formatted.lowercased().hasPrefix("https://") {
            if formatted.contains(".") && !formatted.contains(" ") {
                formatted = "https://" + formatted
            } else {
                formatted = "https://www.google.com/search?q=" + formatted.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed)!
            }
        }
        urlString = formatted
        if let targetURL = URL(string: formatted) {
            webView.load(URLRequest(url: targetURL))
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
