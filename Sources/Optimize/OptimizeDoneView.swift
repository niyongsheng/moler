import SwiftUI

// MARK: - Done State View

/// Shows optimization completion summary with category breakdown.
struct OptimizeDoneView: View {
    let result: OptimizeResult
    let onReset: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Completion icon
            ZStack {
                Reticle(strokeColor: Brand.accentGold.opacity(0.5), lineWidth: 0.5, armLength: 20)
                    .frame(width: 100, height: 100)

                Image(systemName: "checkmark")
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(Brand.accentGold)
            }

            // Title block
            VStack(spacing: 6) {
                Text(result.isDryRun ? L10n.optimizeDonePreviewTitle : L10n.optimizeDoneTitle)
                    .titleFont(28)
                    .kerning(8)
                    .foregroundColor(Brand.accentGold)

                Text(result.isDryRun ? L10n.optimizeDonePreviewSubtitle : L10n.optimizeDoneSubtitle)
                    .monoFont(10)
                    .foregroundColor(Brand.textDim)
            }

            // Summary InstrumentPanel
            GlassCard {
                VStack(spacing: Brand.unit * 2) {
                    DataRow(
                        label: L10n.optimizeDoneAllAreas,
                        value: "\(result.totalOptimizations > 0 ? "\(result.totalOptimizations)" : "0")"
                    )
                    DataRow(
                        label: L10n.optimizeDoneDuration,
                        value: formattedDuration(result.durationSeconds)
                    )
                }
            }
            .frame(maxWidth: 360)

            // Category breakdown list
            if !result.categories.isEmpty {
                categoryList
            } else {
                Text("→ \(L10n.optimizeDoneNoCategories)")
                    .monoFont(10)
                    .foregroundColor(Brand.textDim)
            }

            Spacer()

            // New Optimize button
            Button(action: onReset) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.counterclockwise")
                    Text(L10n.optimizeDoneNewRun)
                        .titleFont(14)
                        .kerning(6)
                }
                .padding(.horizontal, 32)
                .padding(.vertical, 12)
                .background(Brand.accentOrange.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Brand.accentOrange, lineWidth: 1)
                )
                .foregroundColor(Brand.accentOrange)
            }
            .buttonStyle(.plain)

            Spacer().frame(height: 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Category List

    private var categoryList: some View {
        ScrollView {
            VStack(spacing: 4) {
                ForEach(result.categories) { category in
                    categoryRow(category)
                }
            }
            .padding(.horizontal, 8)
        }
        .frame(maxHeight: 200)
        .background(Brand.bgCard.opacity(0.3))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(Brand.lineColor, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
        .padding(.horizontal, 24)
    }

    private func categoryRow(_ category: OptimizeCategory) -> some View {
        let completed = category.tasks.filter(\.isCompleted).count
        let total = category.tasks.count
        let allDone = completed == total && total > 0

        return HStack(spacing: 8) {
            Image(systemName: allDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 10))
                .foregroundColor(allDone ? Brand.accentGold : Brand.textDim)

            Text(category.name)
                .monoFont(10)
                .foregroundColor(Brand.textPrimary)

            Spacer()

            Text("\(completed)/\(total)")
                .monoFont(10)
                .foregroundColor(allDone ? Brand.accentGold : Brand.textDim)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            allDone
                ? Brand.accentGold.opacity(0.05)
                : Color.clear
        )
        .cornerRadius(3)
    }

    // MARK: - Helpers

    private func formattedDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        if m > 0 {
            return "\(m)m \(s)s"
        }
        return "\(s)s"
    }
}
