import SwiftUI

// MARK: - Running State View

/// Displays live streaming output from `mo optimize` with a terminal-log style.
struct OptimizeRunView: View {
    let progress: OptimizeProgress
    let onCancel: () -> Void

    @State private var scrollProxy: ScrollViewProxy?

    var body: some View {
        VStack(spacing: 16) {
            statusHeader
            terminalLog
            ProgressGlow(progress: progressFraction)
                .frame(width: 300)
            footerActions
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Text(progress.isDryRun ? L10n.optimizeDryRun : L10n.optimizeRunTitle)
                    .titleFont(18)
                    .kerning(6)
                    .foregroundColor(Brand.accentOrange)

                Spacer()

                Text("\(progress.elapsedSeconds)s")
                    .monoFont(12)
                    .foregroundColor(Brand.textDim)
            }

            HStack(spacing: 8) {
                PulseGlow()
                    .frame(width: 8, height: 8)

                Text("\(L10n.optimizeRunStatus): \(L10n.optimizeRunExecuting)")
                    .monoFont(10)
                    .foregroundColor(Brand.textDim)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Terminal Log

    private var terminalLog: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(displayLines, id: \.id) { line in
                        logLineView(line)
                            .id(line.id)
                    }
                }
                .padding(12)
                .font(.custom("RobotoMono-Regular", size: 10))
            }
            .background(Brand.bgCard.opacity(0.4))
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(Brand.lineColor, lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .onChange(of: displayLines.count) { _, _ in
                if let last = displayLines.last {
                    proxy.scrollTo(last.id, anchor: .bottom)
                }
            }
        }
    }

    // MARK: - Log Line Model

    private struct LogLine: Identifiable {
        let id: Int
        let text: String
        let isCategory: Bool
        let isCompleted: Bool
        let isDiagnosis: Bool
        let isCurrent: Bool
    }

    private var displayLines: [LogLine] {
        var lines: [LogLine] = []
        var idx = 0

        // Diagnosis items
        for item in progress.diagnosisItems {
            lines.append(LogLine(id: idx, text: "  \(item)", isCategory: false, isCompleted: false, isDiagnosis: true, isCurrent: false))
            idx += 1
        }

        // Categories and their tasks
        for category in progress.categories {
            lines.append(LogLine(id: idx, text: "➤ \(category.name)", isCategory: true, isCompleted: false, isDiagnosis: false, isCurrent: false))
            idx += 1

            for task in category.tasks {
                let prefix = task.isCompleted ? "✓" : "→"
                lines.append(LogLine(id: idx, text: "  \(prefix) \(task.description)", isCategory: false, isCompleted: task.isCompleted, isDiagnosis: false, isCurrent: false))
                idx += 1
            }
        }

        // Current task (pulsing indicator)
        if !progress.currentTask.isEmpty {
            let hasCurrentCategory = progress.categories.last?.name == progress.currentCategory
            if !hasCurrentCategory && !progress.currentCategory.isEmpty {
                lines.append(LogLine(id: idx, text: "➤ \(progress.currentCategory)", isCategory: true, isCompleted: false, isDiagnosis: false, isCurrent: false))
                idx += 1
            }
            lines.append(LogLine(id: idx, text: progress.currentTask, isCategory: false, isCompleted: false, isDiagnosis: false, isCurrent: true))
            idx += 1
        }

        return lines
    }

    @ViewBuilder
    private func logLineView(_ line: LogLine) -> some View {
        if line.isCurrent {
            // Current task with pulsing glow indicator
            HStack(spacing: 6) {
                PulseGlow()
                    .frame(width: 6, height: 6)
                Text(line.text)
                    .foregroundColor(Brand.textPrimary)
            }
        } else if line.isCategory {
            Text(line.text)
                .foregroundColor(Brand.accentOrange)
                .fontWeight(.medium)
                .padding(.top, 4)
        } else if line.isCompleted {
            Text(line.text)
                .foregroundColor(Brand.accentGold)
        } else if line.isDiagnosis {
            Text(line.text)
                .foregroundColor(Brand.textDim.opacity(0.8))
        } else {
            Text(line.text)
                .foregroundColor(Brand.textPrimary)
        }
    }

    // MARK: - Footer

    private var footerActions: some View {
        HStack(spacing: 12) {
            Button(action: onCancel) {
                HStack(spacing: 6) {
                    Image(systemName: "stop.fill")
                        .font(.system(size: 10))
                    Text(L10n.optimizeCancel)
                        .monoFont(10)
                }
                .foregroundColor(Brand.accentOrange)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(Brand.accentOrange, lineWidth: 1)
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private var progressFraction: Double {
        guard progress.totalCategories > 0 else { return 0.1 }
        return min(Double(progress.completedCategories) / Double(progress.totalCategories), 1.0)
    }
}
