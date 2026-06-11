import AppKit
import SwiftUI

/// The genuine macOS sidebar vibrancy material. We render the real
/// `NSVisualEffectView` so surfaces match System Settings exactly instead of
/// approximating it with a tinted scrim.
struct NativeSidebarMaterial: View {
    /// `.behindWindow` for the sidebar surface itself; `.withinWindow` for
    /// bars that must occlude sidebar rows scrolling beneath them.
    var blending: NSVisualEffectView.BlendingMode = .behindWindow

    var body: some View {
        SidebarVisualEffectView(blending: blending)
    }
}

private struct SidebarVisualEffectView: NSViewRepresentable {
    let blending: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = blending
        view.material = .sidebar
        view.state = .followsWindowActiveState
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.blendingMode = blending
        nsView.material = .sidebar
        nsView.state = .followsWindowActiveState
    }
}
