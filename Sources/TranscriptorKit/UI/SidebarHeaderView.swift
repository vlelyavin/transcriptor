import SwiftUI

public struct SidebarHeaderView: View {
    public init() {}

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "mic.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.regularMaterial)
                )

            VStack(alignment: .leading, spacing: 2) {
                Text("Transcriptor")
                    .font(.headline)

                Text("Free local-first speech to text")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 10)
    }
}
