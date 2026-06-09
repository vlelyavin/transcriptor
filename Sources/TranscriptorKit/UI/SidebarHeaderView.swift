import SwiftUI

public struct SidebarHeaderView: View {
    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "waveform.badge.mic")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 30, height: 30)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 9, style: .continuous))

                Text("Transcriptor")
                    .font(.title3.weight(.semibold))
            }

            Text("Free local speech to text")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
    }
}
