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
}
