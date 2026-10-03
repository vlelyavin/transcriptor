import XCTest
@testable import TranscriptorKit

final class SettingsPaneSearchTests: XCTestCase {
    func testEmptyQueryReturnsVisiblePanes() {
        XCTAssertEqual(SettingsPane.matching(query: ""), SettingsPane.sidebarVisiblePanes)
        XCTAssertEqual(SettingsPane.matching(query: "   "), SettingsPane.sidebarVisiblePanes)
    }

    func testOnlyGeneralAndStoragePanesExist() {
        // Recording, Privacy, Advanced, Keyboard Shortcut, and Overlay panes
        // were merged into General or removed outright.
        XCTAssertEqual(SettingsPane.allCases, [.general, .storage])
        XCTAssertEqual(SettingsPane.sidebarVisiblePanes, [.general, .storage])
    }

    func testTitleMatchIsCaseInsensitive() {
        XCTAssertEqual(SettingsPane.matching(query: "general"), [.general])
        XCTAssertEqual(SettingsPane.matching(query: "STORAGE"), [.storage])
    }

    func testSearchTokensMatch() {
        XCTAssertTrue(SettingsPane.matching(query: "hotkey").contains(.general))
        XCTAssertTrue(SettingsPane.matching(query: "login").contains(.general))
        XCTAssertTrue(SettingsPane.matching(query: "microphone").contains(.general))
        XCTAssertTrue(SettingsPane.matching(query: "history").contains(.storage))
    }

    func testCloudProviderSearchResolvesToModelsScreen() {
        // OpenAI/Groq are configured on the Models screen now, so cloud-provider
        // searches surface that screen rather than a settings pane.
        XCTAssertFalse(SettingsPane.allCases.map(\.title).contains("Cloud Providers"))
        XCTAssertTrue(NavigationScreen.models.matches(query: "openai"))
        XCTAssertTrue(NavigationScreen.models.matches(query: "groq"))
        XCTAssertTrue(NavigationScreen.models.matches(query: "api key"))
    }

    func testNoMatchesReturnsEmpty() {
        XCTAssertTrue(SettingsPane.matching(query: "zzz-no-such-setting").isEmpty)
    }

    func testSearchResultsIncludeIndividualSettings() {
        let results = SettingsPane.searchResults(matching: "launch at login")
        XCTAssertEqual(results.map(\.pane), [.general])
        XCTAssertEqual(results.first?.matchedSettingTitles, ["Launch at login"])
    }

    func testSearchResultsMatchShortcutSettings() {
        // The standalone shortcut pane is gone; the recorder lives in General.
        let results = SettingsPane.searchResults(matching: "shortcut")
        XCTAssertEqual(results.map(\.pane), [.general])
        XCTAssertTrue(
            results.first?.matchedSettingTitles.contains("Global voice input shortcut") == true
        )
    }

    func testAutoTranscribeSearchResolvesToModelsScreen() {
        // The dedicated Models settings pane was removed; auto-transcribe is now
        // configured on the Models screen, so the screen search surfaces it.
        XCTAssertFalse(SettingsPane.allCases.map(\.title).contains("Models"))
        XCTAssertTrue(NavigationScreen.models.matches(query: "auto-transcribe"))
        XCTAssertTrue(NavigationScreen.models.matches(query: "automation"))
    }

    func testSearchResultsEmptyQueryReturnsNothing() {
        XCTAssertTrue(SettingsPane.searchResults(matching: "").isEmpty)
        XCTAssertTrue(SettingsPane.searchResults(matching: "  ").isEmpty)
    }

    func testEveryPaneDeclaresSettingTitles() {
        for pane in SettingsPane.allCases {
            XCTAssertFalse(pane.settingTitles.isEmpty, "\(pane) has no searchable settings")
        }
    }
}
