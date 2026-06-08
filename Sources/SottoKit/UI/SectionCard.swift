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
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)

                    Text(subtitle)
                        .foregroundStyle(.secondary)
                }

                Divider()

                content
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}
