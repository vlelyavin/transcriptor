import ServiceManagement
import XCTest
@testable import TranscriptorKit

@MainActor
final class LaunchAtLoginServiceTests: XCTestCase {
    func testPackagedAppRequirementIsReportedForExecutableRuns() {
        let controller = MockLaunchAtLoginController(status: .notRegistered)
        let service = LaunchAtLoginService(
            controller: controller,
            bundleURL: URL(fileURLWithPath: "/tmp/Transcriptor")
        )

        XCTAssertEqual(service.status, .needsPackagedApp)
        XCTAssertEqual(service.refreshStatus(), .needsPackagedApp)
    }

    func testRegisteringPackagedAppUpdatesStatusToEnabled() {
        let controller = MockLaunchAtLoginController(status: .notRegistered)
        let service = LaunchAtLoginService(
            controller: controller,
            bundleURL: URL(fileURLWithPath: "/Applications/Transcriptor.app")
        )

        let status = service.setEnabled(true)

        XCTAssertEqual(status, .enabled)
        XCTAssertEqual(controller.registerCallCount, 1)
    }

    func testRefreshMapsRequiresApprovalState() {
        let controller = MockLaunchAtLoginController(status: .requiresApproval)
        let service = LaunchAtLoginService(
            controller: controller,
            bundleURL: URL(fileURLWithPath: "/Applications/Transcriptor.app")
        )

        XCTAssertEqual(service.refreshStatus(), .requiresApproval)
    }

    func testOpenSystemSettingsDelegatesToController() {
        let controller = MockLaunchAtLoginController(status: .notRegistered)
        let service = LaunchAtLoginService(
            controller: controller,
            bundleURL: URL(fileURLWithPath: "/Applications/Transcriptor.app")
        )

        service.openSystemSettings()

        XCTAssertEqual(controller.openSystemSettingsCallCount, 1)
    }
}

@MainActor
private final class MockLaunchAtLoginController: LaunchAtLoginControlling {
    var status: SMAppService.Status
    var registerCallCount = 0
    var unregisterCallCount = 0
    var openSystemSettingsCallCount = 0
    var registerError: Error?
    var unregisterError: Error?

    init(status: SMAppService.Status) {
        self.status = status
    }

    func register() throws {
        registerCallCount += 1
        if let registerError {
            throw registerError
        }
        status = .enabled
    }

    func unregister() throws {
        unregisterCallCount += 1
        if let unregisterError {
            throw unregisterError
        }
        status = .notRegistered
    }

    func openSystemSettings() {
        openSystemSettingsCallCount += 1
    }
}
