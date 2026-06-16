import SwiftUI

/// A NASA-Punk style instrument panel container.
/// Orange left border, uppercase title with wide kerning, data rows below.
struct InstrumentPanel<Content: View>: View {
    let title: String
    let subtitle: String?
    let badge: String?
    @ViewBuilder let content: () -> Content

    init(
        title: String,
        subtitle: String? = nil,
        badge: String? = nil,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self.badge = badge
        self.content = content
    }

    var body: some View {
        HStack(spacing: 0) {
            // Orange left border bar
            Rectangle()
                .fill(Brand.accentOrange)
                .frame(width: 3)

            // Panel body
            VStack(alignment: .leading, spacing: Brand.unit) {
                // Header
                header

                // Content area
                content()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(.horizontal, Brand.margin)
            .padding(.vertical, Brand.marginTight)
        }
        .background(Brand.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Brand.lineColor, lineWidth: 0.5)
        )
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: Brand.unit * 2) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .titleFont(14)
                    .kerning(4)
                    .foregroundColor(Brand.accentOrange)

                if let subtitle {
                    Text(subtitle)
                        .monoFont(9)
                        .foregroundColor(Brand.textDim)
                }
            }

            Spacer()

            if let badge {
                Text(badge)
                    .monoFont(10)
                    .foregroundColor(Brand.accentGold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .overlay(
                        RoundedRectangle(cornerRadius: 2)
                            .stroke(Brand.accentGold, lineWidth: 0.5)
                    )
            }
        }
    }
}

#Preview {
    InstrumentPanel(
        title: "SYSTEM_STATUS",
        subtitle: "CLEAN_TARGET_DISK",
        badge: "ACTIVE"
    ) {
        VStack(alignment: .leading, spacing: 4) {
            DataRow(label: "SCAN_PATH", value: "/Users/nico")
            DataRow(label: "EST_SIZE", value: "2.4GB")
        }
    }
    .frame(width: 400, height: 200)
    .padding()
    .background(Brand.bgNavy)
    .environment(\.colorScheme, .dark)
}
