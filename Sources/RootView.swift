import SwiftUI

/// Navigation pane for the main content area.
enum Pane: Equatable {
    case clean
    case purge
    case optimize
    case analyze
    case settings
}

/// The root content view for the single-window app.
struct RootView: View {
    @State private var activePane: Pane = .clean

    private let sidebarTabs: [(pane: Pane, icon: String, title: String)] = [
        (.clean,    "trash",                       L10n.navClean),
        (.purge,    "xmark.bin",                   L10n.navPurge),
        (.optimize, "arrow.triangle.2.circlepath", L10n.navOptimize),
        (.analyze,  "chart.pie",                   L10n.navAnalyze),
    ]

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar
            sidebar
                .frame(width: 200)

            // Divider
            Rectangle()
                .fill(Brand.lineColor.opacity(0.3))
                .frame(width: 1)

            // Content
            mainContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Brand.bgNavy)
        .environment(\.colorScheme, .dark)
        .onReceive(NotificationCenter.default.publisher(for: .showSettingsPane)) { _ in
            activePane = .settings
        }
    }

    // MARK: - Sidebar

    private var sidebar: some View {
        VStack(spacing: 0) {
            // App branding
            VStack(spacing: 6) {
                Image("Logo")
                    .resizable()
                    .renderingMode(.template)
                    .foregroundColor(Brand.accentOrange)
                    .frame(width: 48, height: 48)
                Text("Moler")
                    .font(.custom("Jura-Medium", size: 16))
                    .foregroundColor(Brand.textPrimary)
            }
            .padding(.top, 24)
            .padding(.bottom, 28)

            // Nav items
            VStack(spacing: 2) {
                ForEach(sidebarTabs, id: \.pane) { tab in
                    navItem(
                        icon: tab.icon,
                        title: tab.title,
                        isSelected: activePane == tab.pane,
                        action: { activePane = tab.pane }
                    )
                }
            }

            Spacer()

            // Settings + version footer
            VStack(spacing: 8) {
                Button {
                    activePane = .settings
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 10))
                        Text(L10n.settingsWindowTitle)
                            .font(.system(size: 12))
                    }
                    .foregroundColor(activePane == .settings ? Brand.accentOrange : Brand.textDim)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 12)
                    .background(
                        activePane == .settings
                            ? Brand.accentOrange.opacity(0.1)
                            : Brand.bgCard.opacity(0.5)
                    )
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Text("v0.1.0")
                    .font(.system(size: 10))
                    .foregroundColor(Brand.textDim.opacity(0.5))
            }
            .padding(.bottom, 16)
        }
        .background(Brand.bgCard.opacity(0.3))
    }

    // MARK: - Nav Item

    private func navItem(icon: String, title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .frame(width: 20)
                Text(title)
                    .font(.system(size: 13, weight: isSelected ? .medium : .regular))
                Spacer()
            }
            .foregroundColor(isSelected ? Brand.accentOrange : Brand.textDim)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                isSelected
                    ? Brand.accentOrange.opacity(0.1)
                    : Color.clear,
                in: RoundedRectangle(cornerRadius: 6)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Main Content

    @ViewBuilder
    private var mainContent: some View {
        switch activePane {
        case .clean:    CleanView()
        case .purge:    placeholderView(for: L10n.navPurge)
        case .optimize: placeholderView(for: L10n.navOptimize)
        case .analyze:  placeholderView(for: L10n.navAnalyze)
        case .settings: SettingsView()
        }
    }

    private func placeholderView(for feature: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "wrench.and.screwdriver")
                .font(.system(size: 32))
                .foregroundColor(Brand.textDim.opacity(0.5))
            Text("\(feature)")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(Brand.textDim)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

#Preview {
    RootView()
}
