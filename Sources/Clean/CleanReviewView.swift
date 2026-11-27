import SwiftUI
import AppKit

/// Review Mole's real `mo clean --dry-run` plan before executing.
///
/// The plan is informational — `mo clean` has no path arguments — so this
/// screen shows what Mole would remove, what it deliberately skips, and what
/// is review-only, instead of offering checkboxes that cannot affect the run.
struct CleanReviewView: View {
    @ObservedObject var vm: CleanViewModel
    let plan: CleanPlan

    var body: some View {
        VStack(spacing: 0) {
            header.frame(maxHeight: 100).padding(.bottom, Brand.margin)

            notices

            planList

            Color.clear.frame(height: 56) // room for the floating footer
        }
        .overlay(alignment: .bottom) { pillFooter }
    }

    // MARK: - Header

    private var header: some View {
        InstrumentPanel(
            title: L10n.cleanReviewTitle,
            subtitle: L10n.cleanReviewSubtitle,
            badge: "\(plan.displayItemCount)"
        ) {
            HStack(spacing: 24) {
                DataRow(label: L10n.cleanReviewTotalSize, value: Format.bytes(plan.potentialBytes))
                DataRow(label: L10n.cleanReviewTotalFiles, value: Format.count(plan.displayItemCount))
                DataRow(label: L10n.cleanReviewCategories, value: "\(plan.categories.count)")
                DataRow(label: L10n.cleanReviewCleanable, value: "\(plan.cleanableCount)")
            }
        }
    }

    // MARK: - Notices

    @ViewBuilder
    private var notices: some View {
        VStack(spacing: 6) {
            if plan.requiresAdminForSystemCaches {
                NoticeRow(
                    icon: "lock.fill",
                    text: L10n.cleanReviewSudoHint,
                    color: Brand.accentGold
                )
            }

            if !plan.skippedFamilies.isEmpty {
                NoticeRow(
                    icon: "pause.circle",
                    text: "\(L10n.cleanReviewSkippedNote) · \(plan.skippedFamilies.joined(separator: ", "))",
                    color: Brand.accentOrange
                )
            }

            if let path = plan.detailedListPath {
                HStack(spacing: 6) {
                    Image(systemName: "doc.text").font(.system(size: 9))
                    Text("\(L10n.cleanReviewDetailedList): \(path)")
                        .monoFont(9)
                        .lineLimit(1)
                        .truncationMode(.middle)
                    Spacer()
                    Button(L10n.cleanReviewReveal) {
                        NSWorkspace.shared.activateFileViewerSelecting([
                            URL(fileURLWithPath: path)
                        ])
                    }
                    .monoFont(9)
                    .foregroundColor(Brand.accentOrange)
                    .buttonStyle(.plain)
                }
                .foregroundColor(Brand.textDim)
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Brand.bgCard.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
        }
        .padding(.bottom, Brand.marginTight)
    }

    // MARK: - Plan List

    private var planList: some View {
        ScrollView {
            LazyVStack(spacing: 4) {
                if plan.categories.isEmpty {
                    Text(L10n.cleanReviewNoFiles)
                        .monoFont(12)
                        .foregroundColor(Brand.textDim)
                        .padding(.vertical, 32)
                } else {
                    ForEach(plan.categories) { category in
                        categoryCard(category)
                    }
                }
            }
        }
        .background(Brand.bgCard.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Brand.lineColor, lineWidth: 0.5))
    }

    private func categoryCard(_ category: CleanPlanCategory) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Text(category.name.uppercased())
                    .titleFont(11).kerning(2).foregroundColor(Brand.textPrimary)
                Spacer()
                Text("\(category.items.count)")
                    .monoFont(9).foregroundColor(Brand.textDim)
            }
            .padding(.horizontal, 10).padding(.vertical, 8)
            .background(Brand.bgElevated.opacity(0.5))

            ForEach(category.items) { item in
                itemRow(item)
                Divider().background(Brand.lineColor.opacity(0.15))
            }
        }
        .background(Brand.bgCard.opacity(0.3))
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .overlay(RoundedRectangle(cornerRadius: 4).stroke(Brand.lineColor.opacity(0.2), lineWidth: 0.5))
    }

    private func itemRow(_ item: CleanPlanItem) -> some View {
        let marker: String
        let color: Color
        switch item.kind {
        case .cleanable:
            marker = "○"
            color = Brand.textPrimary
        case .skipped:
            marker = "◎"
            color = Brand.accentGold
        case .note:
            marker = "⊙"
            color = Brand.textDim
        }

        return HStack(alignment: .top, spacing: 8) {
            Text(marker)
                .monoFont(10)
                .foregroundColor(color)
                .frame(width: 12, alignment: .leading)
            Text(item.name)
                .monoFont(10)
                .foregroundColor(color)
                .lineLimit(2)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12).padding(.vertical, 5)
    }

    // MARK: - Floating Pill Footer

    private var pillFooter: some View {
        HStack(spacing: 12) {
            Button(action: { vm.reset() }) {
                Image(systemName: "arrow.left").font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.plain).foregroundColor(Brand.textDim)

            Divider().frame(height: 20).overlay(Brand.lineColor)

            Text(Format.bytes(plan.potentialBytes))
                .monoFont(12).foregroundColor(Brand.accentOrange)
            Text("· \(plan.displayItemCount) \(L10n.cleanReviewItems)")
                .monoFont(9).foregroundColor(Brand.textDim)

            Spacer()

            Button(action: { vm.startClean() }) {
                HStack(spacing: 6) {
                    Image(systemName: "trash").font(.system(size: 11))
                    Text(L10n.cleanReviewExecute).titleFont(11).kerning(3)
                }
                .padding(.horizontal, 16).padding(.vertical, 8)
                .background(plan.hasCleanableItems ? Brand.accentOrange : Brand.lineColor.opacity(0.3))
                .foregroundColor(plan.hasCleanableItems ? .white : Brand.textDim)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain).disabled(!plan.hasCleanableItems)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .background(Brand.bgElevated.opacity(0.95))
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Brand.lineColor, lineWidth: 0.5))
        .shadow(color: .black.opacity(0.3), radius: 8, y: -2)
        .padding(.horizontal, 40).padding(.bottom, 16)
    }
}

#Preview {
    CleanReviewView(
        vm: CleanViewModel(),
        plan: CleanPlan(
            categories: [
                CleanPlanCategory(id: "User essentials", name: "User essentials", items: [
                    CleanPlanItem(id: "1", name: "User app cache · 56 items, 2.54GB", kind: .cleanable),
                    CleanPlanItem(id: "2", name: "Xcode XCTestDevices · skipped (process state unknown)", kind: .skipped),
                ]),
                CleanPlanCategory(id: "Large files", name: "Large files", items: [
                    CleanPlanItem(id: "3", name: "Docker storage · Images 2.787GB, 983.1MB reclaimable", kind: .note),
                ]),
            ],
            potentialBytes: 5_970_000_000,
            itemCount: 601,
            skippedFamilies: ["Chrome", "WeChat"],
            detailedListPath: "/Users/me/.config/mole/clean-list.txt"
        )
    )
    .frame(width: 900, height: 600)
    .background(Brand.bgNavy)
    .environment(\.colorScheme, .dark)
}
