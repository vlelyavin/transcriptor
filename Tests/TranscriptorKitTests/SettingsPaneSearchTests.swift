import XCTest
@testable import TranscriptorKit

final class SettingsPaneSearchTests: XCTestCase {
    func testEmptyQueryReturnsAllPanes() {
        XCTAssertEqual(SettingsPane.matching(query: ""), SettingsPane.allCases)
        XCTAssertEqual(SettingsPane.matching(query: "   "), SettingsPane.allCases)
    }

    func testTitleMatchIsCaseInsensitive() {
        XCTAssertEqual(SettingsPane.matching(query: "cloud"), [.cloudProviders, .privacy])
        XCTAssertEqual(SettingsPane.matching(query: "CLOUD"), [.cloudProviders, .privacy])
    }

    func testSearchTokensMatch() {
        XCTAssertTrue(SettingsPane.matching(query: "hotkey").contains(.keyboardShortcut))
        XCTAssertTrue(SettingsPane.matching(query: "openai").contains(.cloudProviders))
        XCTAssertTrue(SettingsPane.matching(query: "login").contains(.general))
        XCTAssertTrue(SettingsPane.matching(query: "microphone").contains(.recording))
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
        XCTAssertTrue(panes.contains(.models))
        XCTAssertTrue(panes.contains(.storage))
        XCTAssertTrue(
            results.first(where: { $0.pane == .models })?
                .matchedSettingTitles
                .contains("Auto-transcribe after recording or import") == true
        )
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
