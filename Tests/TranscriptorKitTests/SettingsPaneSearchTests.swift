import XCTest
@testable import TranscriptorKit

final class SettingsPaneSearchTests: XCTestCase {
    func testEmptyQueryReturnsVisiblePanes() {
        XCTAssertEqual(SettingsPane.matching(query: ""), SettingsPane.sidebarVisiblePanes)
        XCTAssertEqual(SettingsPane.matching(query: "   "), SettingsPane.sidebarVisiblePanes)
    }

    func testHiddenOverlayPaneIsNotSearchable() {
        // The Overlay pane is hidden for now (see `sidebarVisiblePanes`); it must
        // not surface in the sidebar list or via search, even on its own keyword.
        XCTAssertFalse(SettingsPane.sidebarVisiblePanes.contains(.overlay))
        XCTAssertFalse(SettingsPane.matching(query: "overlay").contains(.overlay))
        XCTAssertFalse(SettingsPane.searchResults(matching: "overlay").map(\.pane).contains(.overlay))
    }

    func testTitleMatchIsCaseInsensitive() {
        XCTAssertTrue(SettingsPane.matching(query: "storage").contains(.storage))
        XCTAssertEqual(SettingsPane.matching(query: "storage"), SettingsPane.matching(query: "STORAGE"))
    }

    func testHiddenPrivacyPaneIsNotSearchable() {
        XCTAssertFalse(SettingsPane.sidebarVisiblePanes.contains(.privacy))
        XCTAssertFalse(SettingsPane.matching(query: "privacy").contains(.privacy))
    }

    func testSearchTokensMatch() {
        XCTAssertTrue(SettingsPane.matching(query: "hotkey").contains(.keyboardShortcut))
        XCTAssertTrue(SettingsPane.matching(query: "login").contains(.general))
        XCTAssertTrue(SettingsPane.matching(query: "microphone").contains(.recording))
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

    func testSearchResultsMatchSettingsAcrossPanes() {
        let results = SettingsPane.searchResults(matching: "auto")
        let panes = results.map(\.pane)
        XCTAssertTrue(panes.contains(.storage))
        XCTAssertTrue(
            results.first(where: { $0.pane == .storage })?
                .matchedSettingTitles
                .contains("Auto-delete oldest history when over limit") == true
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
