import AppKit
import SwiftUI

/// Sidebar background: the native sidebar material with a subtle darkening
/// scrim so the sidebar always reads darker than the content area, matching
/// System Settings.
struct NativeSidebarMaterial: View {
    @Environment(\.colorScheme) private var colorScheme

    /// `.behindWindow` for the sidebar surface itself; `.withinWindow` for
    /// bars that must occlude sidebar rows scrolling beneath them.
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    var body: some View {
        SidebarVisualEffectView(blending: blending)
            .overlay(Color.black.opacity(colorScheme == .dark ? 0.28 : 0.05))
    }
}

private struct SidebarVisualEffectView: NSViewRepresentable {
    let blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = blending
        view.material = .sidebar
        view.state = .active
        view.isEmphasized = true
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.blendingMode = blending
        nsView.material = .sidebar
        nsView.state = .active
    }
}
