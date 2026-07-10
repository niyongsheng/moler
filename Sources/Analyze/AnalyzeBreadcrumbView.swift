import SwiftUI

/// Clickable breadcrumb navigation path for the Analyze treemap.
struct AnalyzeBreadcrumbView: View {
    let crumbs: [BreadcrumbItem]
    let onNavigate: (BreadcrumbItem) -> Void
    let onGoBack: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            // Back button (if more than one level)
            if crumbs.count > 1 {
                Button(action: onGoBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(Brand.accentOrange)
                }
                .buttonStyle(.plain)
            }

            // Clickable path segments
            ForEach(Array(crumbs.enumerated()), id: \.element.id) { index, crumb in
                if index > 0 {
                    Text("/")
                        .monoFont(10)
                        .foregroundColor(Brand.textDim)
                }

                Button(action: { onNavigate(crumb) }) {
                    Text(index == crumbs.count - 1 ? "> \(crumb.name)" : crumb.name)
                        .monoFont(index == crumbs.count - 1 ? 11 : 10)
                        .foregroundColor(
                            index == crumbs.count - 1
                                ? Brand.accentGold
                                : Brand.textDim
                        )
                }
                .buttonStyle(.plain)
                .help(crumb.id)
            }
        }
    }
}

#Preview {
    AnalyzeBreadcrumbView(
        crumbs: [
            BreadcrumbItem(id: "/Users/nigang", name: "~"),
            BreadcrumbItem(id: "/Users/nigang/Documents", name: "Documents"),
        ],
        onNavigate: { _ in },
        onGoBack: {}
    )
    .padding()
    .background(Brand.bgNavy)
}
