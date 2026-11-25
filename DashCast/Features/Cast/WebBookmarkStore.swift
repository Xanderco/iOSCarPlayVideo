import Foundation

/// A user-saved web bookmark inside DashCast's in-app browser.
public struct WebBookmark: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public var title: String
    public var urlString: String
    public let createdAt: Date

    public init(id: UUID = UUID(), title: String, urlString: String, createdAt: Date = Date()) {
        self.id = id
        self.title = title
        self.urlString = urlString
        self.createdAt = createdAt
    }

    public var url: URL? {
        URL(string: urlString)
    }

    public var hostDisplay: String {
        URL(string: urlString)?.host ?? urlString
    }
}

/// Persists user web bookmarks and browser user-agent mode in UserDefaults.
@MainActor
public final class WebBookmarkStore: ObservableObject {
    public static let shared = WebBookmarkStore()

    public enum UserAgentMode: String, CaseIterable, Codable, Sendable {
        case mobile
        case desktop

        public var label: String {
            switch self {
            case .mobile: return "Mobile View"
            case .desktop: return "Desktop View"
            }
        }

        public var iconSystemName: String {
            switch self {
            case .mobile: return "iphone"
            case .desktop: return "desktopcomputer"
            }
        }

        public var customUserAgent: String? {
            switch self {
            case .mobile:
                return nil
            case .desktop:
                return "Mozilla/5.0 (Macintosh; Intel Mac OS X 14_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15"
            }
        }
    }

    @Published public private(set) var bookmarks: [WebBookmark] = []
    @Published public var userAgentMode: UserAgentMode {
        didSet {
            defaults.set(userAgentMode.rawValue, forKey: userAgentKey)
        }
    }

    private let defaults: UserDefaults
    private let storageKey: String
    private let userAgentKey: String

    public init(
        defaults: UserDefaults = .standard,
        storageKey: String = "dashcast_web_bookmarks_v1",
        userAgentKey: String = "dashcast_web_user_agent_mode_v1"
    ) {
        self.defaults = defaults
        self.storageKey = storageKey
        self.userAgentKey = userAgentKey

        if let rawMode = defaults.string(forKey: userAgentKey),
           let mode = UserAgentMode(rawValue: rawMode) {
            self.userAgentMode = mode
        } else {
            self.userAgentMode = .mobile
        }

        load()
    }

    /// Validates an HTTP/HTTPS URL string for bookmark storage.
    nonisolated public static func normalizedHTTPURLString(from rawInput: String) -> String? {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              let url = URL(string: trimmed),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host?.isEmpty == false else {
            return nil
        }
        return url.absoluteString
    }

    /// Resolves address-bar input into a navigable URL (full URL, bare domain, or search query).
    nonisolated public static func resolveNavigationURL(from rawInput: String) -> URL? {
        let trimmed = rawInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let lower = trimmed.lowercased()
        if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
            return URL(string: trimmed)
        }
        if trimmed.contains(".") && !trimmed.contains(" ") {
            return URL(string: "https://" + trimmed)
        }
        let encoded = trimmed.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? trimmed
        return URL(string: "https://duckduckgo.com/?q=\(encoded)")
    }

    @discardableResult
    public func addBookmark(title: String, urlString: String) -> WebBookmark? {
        guard let normalized = Self.normalizedHTTPURLString(from: urlString) else { return nil }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedTitle = cleanTitle.isEmpty
            ? (URL(string: normalized)?.host ?? normalized)
            : cleanTitle

        if let index = bookmarks.firstIndex(where: { $0.urlString.caseInsensitiveCompare(normalized) == .orderedSame }) {
            bookmarks[index].title = resolvedTitle
            save()
            return bookmarks[index]
        }

        let bookmark = WebBookmark(title: resolvedTitle, urlString: normalized)
        bookmarks.insert(bookmark, at: 0)
        save()
        return bookmark
    }

    public func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        save()
    }

    public func removeBookmarks(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        save()
    }

    public func isBookmarked(urlString: String) -> Bool {
        guard let normalized = Self.normalizedHTTPURLString(from: urlString) else { return false }
        return bookmarks.contains { $0.urlString.caseInsensitiveCompare(normalized) == .orderedSame }
    }

    @discardableResult
    public func toggleBookmark(title: String, urlString: String) -> Bool {
        guard let normalized = Self.normalizedHTTPURLString(from: urlString) else { return false }
        if let existing = bookmarks.first(where: { $0.urlString.caseInsensitiveCompare(normalized) == .orderedSame }) {
            removeBookmark(id: existing.id)
            return false
        } else {
            addBookmark(title: title, urlString: normalized)
            return true
        }
    }

    public func clearAllBookmarks() {
        bookmarks.removeAll()
        save()
    }

    public func toggleUserAgentMode() {
        userAgentMode = (userAgentMode == .mobile) ? .desktop : .mobile
    }

    private func save() {
        if let data = try? JSONEncoder().encode(bookmarks) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([WebBookmark].self, from: data) else {
            bookmarks = []
            return
        }
        bookmarks = decoded
    }
}
