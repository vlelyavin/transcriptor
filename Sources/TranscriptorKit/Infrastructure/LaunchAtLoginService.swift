import Foundation
import ServiceManagement

public enum LaunchAtLoginStatus: Equatable, Sendable {
    case enabled
    case disabled
    case requiresApproval
    case needsPackagedApp
    case failed(String)

    public var title: String {
        switch self {
        case .enabled:
            return "On"
        case .disabled:
            return "Off"
        case .requiresApproval:
            return "Pending Approval"
        case .needsPackagedApp:
            return "Needs Packaged App"
        case .failed:
            return "Failed"
        }
    }

    public var detail: String {
        switch self {
        case .enabled:
            return "Transcriptor is registered to launch when you sign in."
        case .disabled:
            return "Transcriptor will not launch automatically when you sign in."
        case .requiresApproval:
            return "macOS still needs you to approve Transcriptor in Login Items."
        case .needsPackagedApp:
            return "Launch at login only works from a packaged Transcriptor.app bundle. Development runs from swift or xcodebuild cannot register themselves."
        case let .failed(message):
            return message
        }
    }

    public var toggleValue: Bool {
        switch self {
        case .enabled, .requiresApproval:
            return true
        case .disabled, .needsPackagedApp, .failed:
            return false
        }
    }

    public var canRegisterFromCurrentRuntime: Bool {
        self != .needsPackagedApp
    }
}

@MainActor
public protocol LaunchAtLoginServing: AnyObject {
    var status: LaunchAtLoginStatus { get }

    func refreshStatus() -> LaunchAtLoginStatus
    func setEnabled(_ enabled: Bool) -> LaunchAtLoginStatus
    func openSystemSettings()
}

@MainActor
public final class LaunchAtLoginService: LaunchAtLoginServing {
    public private(set) var status: LaunchAtLoginStatus = .disabled

    public init() {
        status = refreshStatus()
    }

    public func refreshStatus() -> LaunchAtLoginStatus {
        guard isPackagedApp else {
            status = .needsPackagedApp
            return status
        }

        status = mapStatus(SMAppService.mainApp.status)
        return status
    }

    public func setEnabled(_ enabled: Bool) -> LaunchAtLoginStatus {
        guard isPackagedApp else {
            status = .needsPackagedApp
            return status
        }

        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            return refreshStatus()
        } catch {
            status = .failed(error.localizedDescription)
            return status
        }
    }

    public func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }

    private var isPackagedApp: Bool {
        Bundle.main.bundleURL.pathExtension.lowercased() == "app"
    }

    private func mapStatus(_ serviceStatus: SMAppService.Status) -> LaunchAtLoginStatus {
        switch serviceStatus {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .needsPackagedApp
        @unknown default:
            return .failed("Transcriptor encountered an unknown launch-at-login status.")
        }
    }
}
