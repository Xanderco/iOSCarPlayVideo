import XCTest
import SwiftUI
@testable import DashCast

final class SoundCatalogTests: XCTestCase {

    func testSoundPickerCategoryFiltering() {
        let sounds = SoundCatalogService.shared.sounds

        let recommend = SoundPickerCategory.filterSounds(sounds, category: .recommend, searchText: "")
        let all = SoundPickerCategory.filterSounds(sounds, category: .all, searchText: "")
        XCTAssertEqual(recommend.count, sounds.count)
        XCTAssertEqual(all.count, sounds.count)

        let engines = SoundPickerCategory.filterSounds(sounds, category: .engine, searchText: "")
        XCTAssertFalse(engines.isEmpty)
        XCTAssertTrue(engines.allSatisfy { $0.category == .engine })

        let voices = SoundPickerCategory.filterSounds(sounds, category: .voices, searchText: "")
        XCTAssertFalse(voices.isEmpty)
        XCTAssertTrue(voices.allSatisfy { $0.category == .voices })

        let futuristic = SoundPickerCategory.filterSounds(sounds, category: .futuristic, searchText: "")
        XCTAssertFalse(futuristic.isEmpty)
        XCTAssertTrue(futuristic.allSatisfy { $0.category == .futuristic })

        let brands = SoundPickerCategory.filterSounds(sounds, category: .brands, searchText: "")
        XCTAssertTrue(brands.isEmpty)

        let searchMatch = SoundPickerCategory.filterSounds(sounds, category: .all, searchText: "V8")
        XCTAssertEqual(searchMatch.map(\.id), ["v8_supercharged"])
    }

    @MainActor
    func testSoundsHomeCopyFormattingAndSlotTitles() {
        XCTAssertEqual(SoundsHomeCopy.selectedSoundText(title: "Jet Startup"), "Selected: Jet Startup")
        XCTAssertEqual(
            SoundsHomeCopy.pickerTitleKey(forSlot: "disconnection"),
            LocalizedStringKey(SoundsHomeCopy.selectDisconnectionTitleString)
        )
        XCTAssertEqual(
            SoundsHomeCopy.pickerTitleKey(forSlot: "arrival"),
            LocalizedStringKey(SoundsHomeCopy.selectConnectionTitleString)
        )
        XCTAssertEqual(SoundsHomeCopy.navigationTitleKey, LocalizedStringKey(SoundsHomeCopy.navigationTitleString))
        XCTAssertEqual(SoundsHomeCopy.proBadgeKey, LocalizedStringKey(SoundsHomeCopy.proBadgeString))
        XCTAssertEqual(SoundsHomeCopy.disconnectionTitleKey, LocalizedStringKey(SoundsHomeCopy.disconnectionTitleString))
        XCTAssertEqual(SoundsHomeCopy.disconnectionSubtitleKey, LocalizedStringKey(SoundsHomeCopy.disconnectionSubtitleString))
        XCTAssertEqual(SoundsHomeCopy.homeArrivalTitleKey, LocalizedStringKey(SoundsHomeCopy.homeArrivalTitleString))
        XCTAssertEqual(SoundsHomeCopy.homeArrivalSubtitleKey, LocalizedStringKey(SoundsHomeCopy.homeArrivalSubtitleString))
        XCTAssertEqual(SoundsHomeCopy.topTrendingKey, LocalizedStringKey(SoundsHomeCopy.topTrendingString))
        XCTAssertEqual(SoundsHomeCopy.setAsConnectionKey, LocalizedStringKey(SoundsHomeCopy.setAsConnectionString))
        XCTAssertEqual(SoundsHomeCopy.setAsDisconnectionKey, LocalizedStringKey(SoundsHomeCopy.setAsDisconnectionString))
        XCTAssertEqual(SoundsHomeCopy.setAsArrivalKey, LocalizedStringKey(SoundsHomeCopy.setAsArrivalString))
        XCTAssertEqual(SoundsHomeCopy.howToActivateKey, LocalizedStringKey(SoundsHomeCopy.howToActivateString))
        XCTAssertEqual(SoundsHomeCopy.searchPlaceholderKey, LocalizedStringKey(SoundsHomeCopy.searchPlaceholderString))
        XCTAssertEqual(SoundsHomeCopy.pickerGuidanceKey, LocalizedStringKey(SoundsHomeCopy.pickerGuidanceString))
        XCTAssertEqual(SoundsHomeCopy.selectSoundButtonKey, LocalizedStringKey(SoundsHomeCopy.selectSoundButtonString))
        for category in SoundPickerCategory.allCases {
            XCTAssertEqual(category.localizedKey, LocalizedStringKey(category.rawValue))
        }
    }

    func testSoundsHomeCopyLocalizationKeysComplete() throws {
        let projectDir = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let catalogURL = projectDir
            .appendingPathComponent("DashCast")
            .appendingPathComponent("Resources")
            .appendingPathComponent("Localizable.xcstrings")

        let data = try Data(contentsOf: catalogURL)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let strings = try XCTUnwrap(json["strings"] as? [String: [String: Any]])

        for key in SoundsHomeCopy.allLocalizationKeys {
            let entry = try XCTUnwrap(strings[key], "Missing Localizable.xcstrings entry for: \(key)")
            let localizations = try XCTUnwrap(entry["localizations"] as? [String: [String: Any]], "Missing localizations for: \(key)")
            for lang in ["en", "es"] {
                let unit = try XCTUnwrap(localizations[lang]?["stringUnit"] as? [String: Any], "Missing \(lang) stringUnit for: \(key)")
                let value = try XCTUnwrap(unit["value"] as? String)
                XCTAssertFalse(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty \(lang) translation for: \(key)")
            }
        }
    }
}
