import SwiftUI

/// Shared header for every main pane.
///
/// A fixed-height reticle icon + title block keeps the top of the content area
/// identical across tabs, so switching panes never shifts the page's vertical
/// rhythm. The trailing slot holds pane-specific accessories (e.g. the health
/// ring on the Overview).
struct PageHeader<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    let statusColor: Color?
    let accent: Color
    @ViewBuilder let trailing: () -> Trailing

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        statusColor: Color? = nil,
        accent: Color = Brand.accentOrange,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.statusColor = statusColor
        self.accent = accent
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Reticle(
                    strokeColor: accent.opacity(0.45),
                    lineWidth: 0.5,
                    armLength: 7
                )
                .frame(width: 46, height: 46)

                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(accent)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .titleFont(19)
                    .kerning(4)
                    .foregroundColor(accent)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

                if let subtitle, !subtitle.isEmpty {
                    HStack(spacing: 5) {
                        if let statusColor {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 4, height: 4)
                                .shadow(color: statusColor.opacity(0.6), radius: 2)
                        }

                        Text(subtitle)
                            .monoFont(9)
                            .foregroundColor(Brand.textDim)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }
            }

            Spacer(minLength: 12)

            trailing()
        }
        .frame(height: 56)
    }
}

extension PageHeader where Trailing == EmptyView {
    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        statusColor: Color? = nil,
        accent: Color = Brand.accentOrange
    ) {
        self.init(
            icon: icon,
            title: title,
            subtitle: subtitle,
            statusColor: statusColor,
            accent: accent,
            trailing: { EmptyView() }
        )
    }
}

/// Header + the hairline that separates it from the page body. Use this when
/// the pane manages its own scroll view (Overview, Settings); use
/// `PageChrome` for the feature panes.
struct PageHeaderBand<Trailing: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    let statusColor: Color?
    let accent: Color
    @ViewBuilder let trailing: () -> Trailing

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        statusColor: Color? = nil,
        accent: Color = Brand.accentOrange,
        @ViewBuilder trailing: @escaping () -> Trailing
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.statusColor = statusColor
        self.accent = accent
        self.trailing = trailing
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeader(
                icon: icon,
                title: title,
                subtitle: subtitle,
                statusColor: statusColor,
                accent: accent,
                trailing: trailing
            )
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 12)

            Rectangle()
                .fill(Brand.lineColor.opacity(0.22))
                .frame(height: 1)
        }
    }
}

extension PageHeaderBand where Trailing == EmptyView {
    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        statusColor: Color? = nil,
        accent: Color = Brand.accentOrange
    ) {
        self.init(
            icon: icon,
            title: title,
            subtitle: subtitle,
            statusColor: statusColor,
            accent: accent,
            trailing: { EmptyView() }
        )
    }
}

/// Standard feature-pane frame: shared header, hairline, and a top-aligned
/// content area with the same insets on every tab.
struct PageChrome<Content: View>: View {
    let icon: String
    let title: String
    let subtitle: String?
    let statusColor: Color?
    let accent: Color
    @ViewBuilder let content: () -> Content

    init(
        icon: String,
        title: String,
        subtitle: String? = nil,
        statusColor: Color? = nil,
        accent: Color = Brand.accentOrange,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.statusColor = statusColor
        self.accent = accent
        self.content = content
    }

    var body: some View {
        VStack(spacing: 0) {
            PageHeaderBand(
                icon: icon,
                title: title,
                subtitle: subtitle,
                statusColor: statusColor,
                accent: accent
            )

            content()
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }
}

/// Shared layout for an idle feature page: a centered column of cards and
/// actions. Keeping the column identical across panes makes the content start
/// at the same place on every tab. It only becomes a scroll view when the
/// window is too short, so empty space keeps passing events to the scene
/// behind the page.
struct PageContentColumn<Content: View>: View {
    @ViewBuilder let content: () -> Content

    init(@ViewBuilder content: @escaping () -> Content) {
        self.content = content
    }

    var body: some View {
        // Prefer a plain column: unlike a ScrollView it does not swallow
        // scroll-wheel and drag events, so the SceneKit planet behind the
        // page stays zoomable and rotatable. Fall back to a scroll view only
        // when the window is too short to show the whole column.
        ViewThatFits(in: .vertical) {
            column
            ScrollView(.vertical, showsIndicators: false) {
                column
            }
        }
    }

    private var column: some View {
        VStack(alignment: .leading, spacing: 16) {
            content()
        }
        .frame(maxWidth: 560, alignment: .leading)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.bottom, 16)
    }
}
