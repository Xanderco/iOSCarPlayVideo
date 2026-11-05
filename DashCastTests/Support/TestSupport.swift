import XCTest
@testable import DashCast

/// Shared helpers for unit tests. Keep tests hermetic: isolated UserDefaults,
/// stubbed network, bundled fixtures, no sleeps.
enum TestSupport {
    /// The unit-test bundle (fixtures live here, not in the app).
    static var bundle: Bundle { Bundle(for: BundleToken.self) }

    /// URL of a fixture file shipped in DashCastTests/Fixtures.
    static func fixtureURL(_ name: String, ext: String, file: StaticString = #filePath, line: UInt = #line) throws -> URL {
        try XCTUnwrap(bundle.url(forResource: name, withExtension: ext),
                      "Missing test fixture \(name).\(ext) in DashCastTests bundle", file: file, line: line)
    }

    /// 1-second, 64x48 H.264/AAC clip (≈8 KB) for playback tests with no network.
    static func tinyClipURL() throws -> URL { try fixtureURL("tiny_test_clip", ext: "mp4") }
}

private final class BundleToken {}

extension XCTestCase {
    /// A fresh UserDefaults suite that is deleted after the test.
    func makeIsolatedDefaults(_ name: String = #function) -> UserDefaults {
        let suite = "DashCastTests.\(type(of: self)).\(name).\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        addTeardownBlock { UserDefaults().removePersistentDomain(forName: suite) }
        return defaults
    }

    /// Waits until `condition` is true, polling the run loop (no fixed sleeps).
    @MainActor
    func waitUntil(timeout: TimeInterval = 10,
                   _ description: String,
                   file: StaticString = #filePath, line: UInt = #line,
                   _ condition: @escaping @MainActor () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() && Date() < deadline {
            RunLoop.main.run(mode: .default, before: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(condition(), "Timed out after \(timeout)s waiting for: \(description)", file: file, line: line)
    }
}
