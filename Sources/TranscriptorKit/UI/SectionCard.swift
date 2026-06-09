import SwiftUI

public struct SectionCard<Content: View>: View {
    private let title: String
    private let subtitle: String
    private let content: Content

    public init(
        title: String,
        subtitle: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content()
    }

    public var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 14) {
                content
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .groupBoxStyle(.automatic)
        .overlay(alignment: .topLeading) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)

                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 14)
            .padding(.top, 10)
            .background(Color(nsColor: .controlBackgroundColor))
            .offset(x: 12, y: -12)
        }
        .padding(.top, 8)
    }
}
