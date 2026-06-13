import XCTest
@testable import TranscriptorKit

final class SettingsPaneSearchTests: XCTestCase {
    func testEmptyQueryReturnsAllPanes() {
        XCTAssertEqual(SettingsPane.matching(query: ""), SettingsPane.allCases)
        XCTAssertEqual(SettingsPane.matching(query: "   "), SettingsPane.allCases)
    }

    func testTitleMatchIsCaseInsensitive() {
        // The dedicated Cloud Providers pane was removed; cloud setup now lives
        // on the Models screen, so "cloud" only matches the Privacy pane here.
        XCTAssertEqual(SettingsPane.matching(query: "cloud"), [.privacy])
        XCTAssertEqual(SettingsPane.matching(query: "CLOUD"), [.privacy])
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
