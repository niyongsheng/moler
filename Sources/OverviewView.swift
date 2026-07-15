import SwiftUI

/// The Overview dashboard — landing page when clicking the Moler logo.
struct OverviewView: View {
    let onNavigate: (Pane) -> Void

    @StateObject private var monitor = SystemMonitor()
    @State private var diskCapacity: Int64 = 0
    @State private var diskFree: Int64 = 0

    // Popover state
    @State private var showHealthTip = false

    var body: some View {
        ScrollView([.vertical], showsIndicators: false) {
            VStack(spacing: 20) {
                headerBar
                toolGrid
                systemRow
                batterySection
                networkSection
                diskSection
                quickBar
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { loadDiskInfo() }
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            // Title
            HStack(spacing: 10) {
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(Brand.accentOrange)
                Text(L10n.overviewTitle)
                    .titleFont(20).kerning(6)
                    .foregroundColor(Brand.accentOrange)
            }

            Spacer()

            // Health score — click for detail
            if let s = monitor.stats {
                Button {
                    showHealthTip.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 10))
                            .foregroundColor(healthColor(s.healthScore))
                        Text("\(s.healthScore)")
                            .titleFont(16)
                            .foregroundColor(healthColor(s.healthScore))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Material.ultraThin)
                    .cornerRadius(4)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showHealthTip, arrowEdge: .bottom) {
                    healthScoreTip(s)
                }
            }
        }
        .padding(.bottom, 4)
    }

    private func healthColor(_ score: Int) -> Color {
        score > 90 ? Brand.accentGold : score > 70 ? Brand.accentOrange : Brand.accentRed
    }

    // MARK: - Header Tips (Instrument Panel Style)

    private func boxLabel(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 8) {
            Text(label)
                .titleFont(10).kerning(4)
                .foregroundColor(color)
            Spacer()
            Text(value)
                .titleFont(20)
                .foregroundColor(color)
        }
    }

    private func line(_ label: String, _ value: String, _ color: Color) -> some View {
        HStack(spacing: 0) {
            Text("> \(label):")
                .monoFont(8)
                .foregroundColor(Brand.textDim)
            Spacer()
            Text(value)
                .monoFont(10)
                .foregroundColor(color)
        }
    }

    private func bar(_ label: String, _ value: String, _ pct: Double, _ color: Color) -> some View {
        VStack(spacing: 3) {
            line(label, value, color)
            ProgressGlow(progress: pct)
                .frame(height: 2)
        }
    }

    // MARK: - Health Score Popover

    private func healthScoreTip(_ s: SystemStats) -> some View {
        let band = healthScoreBand(s.healthScore)
        let edge = Brand.lineColor.opacity(0.3)

        return VStack(spacing: 0) {
            // Left accent bar + content
            HStack(spacing: 0) {
                Rectangle()
                    .fill(band.color)
                    .frame(width: 3)

                VStack(alignment: .leading, spacing: 0) {
                    boxLabel("HEALTH", "\(s.healthScore)", band.color)
                        .padding(.horizontal, 14)
                        .padding(.top, 12)
                        .padding(.bottom, 6)

                    if !s.healthScoreMsg.isEmpty {
                        HStack(spacing: 0) {
                            Text("> \(s.healthScoreMsg)")
                                .monoFont(9)
                                .foregroundColor(band.color.opacity(0.85))
                            Spacer()
                        }
                        .padding(.horizontal, 14)
                        .padding(.bottom, 8)
                    }

                    edge.frame(height: 1)

                    VStack(spacing: 8) {
                        bar("CPU",  "\(Int(s.cpu.usage))%",   s.cpu.usage / 100,             Brand.accentOrange)
                        if let disk = s.disks.first {
                            bar("DISK", "\(Int(disk.usedPercent))%", disk.usedPercent / 100,  Brand.accentGold)
                        }
                        bar("MEM",  "\(Int(s.memory.usedPercent))%", s.memory.usedPercent / 100, Brand.accentBlue)
                    }
                    .padding(14)
                }
            }
            .frame(width: 210)
            .background(Brand.bgElevated)
        }
    }

    private func healthScoreBand(_ score: Int) -> (color: Color, label: String) {
        let label: String
        if score > 90       { label = "Excellent" }
        else if score > 70  { label = "Good" }
        else if score > 45  { label = "Fair" }
        else                { label = "Needs Attention" }
        return (healthColor(score), label)
    }

    // MARK: - Tool Stats Grid

    private var toolGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
            toolCard(icon: Pane.clean.iconName,    label: L10n.navClean,     color: Brand.accentOrange, stats: [
                (L10n.overviewStatFreed, formatBytes(Store.shared.totalFreedBytes)),
                (L10n.overviewStatCount, "\(Store.shared.totalCleanCount)"),
                (L10n.overviewStatLast,  Format.relativeDate(Store.shared.lastCleanDate)),
            ])
            toolCard(icon: Pane.purge.iconName,    label: L10n.navPurge,     color: Brand.accentOrange, stats: [
                (L10n.overviewStatFreed, formatBytes(Store.shared.totalPurgeFreedBytes)),
                (L10n.overviewStatCount, "\(Store.shared.totalPurgeCount)"),
                (L10n.overviewStatLast,  Format.relativeDate(Store.shared.lastPurgeDate)),
            ])
            toolCard(icon: Pane.optimize.iconName, label: L10n.navOptimize, color: Brand.accentOrange, stats: [
                (L10n.overviewStatOps,   "\(Store.shared.totalOptimizeCount)"),
                (L10n.overviewStatLast,  "\(Store.shared.lastOptimizeOptimizations)"),
                (L10n.overviewStatDate,  Format.relativeDate(Store.shared.lastOptimizeDate)),
            ])
            toolCard(icon: Pane.analyze.iconName,  label: L10n.navAnalyze,   color: Brand.accentOrange, stats: [
                (L10n.overviewStatCount, "\(Store.shared.totalAnalyzeCount)"),
                (L10n.overviewStatLast,  Format.relativeDate(Store.shared.lastAnalyzeDate)),
                (L10n.overviewStatPath,  Format.abbreviatePath(Store.shared.lastAnalyzePath, maxLen: 18)),
            ])
            toolCard(icon: Pane.software.iconName, label: L10n.navSoftware,  color: Brand.accentOrange, stats: [
                (L10n.overviewStatRemoved, "\(Store.shared.totalSoftwareRemoved)"),
                (L10n.overviewStatFreed,   formatBytes(Store.shared.totalSoftwareBytesFreed)),
                (L10n.overviewStatLast,    Format.relativeDate(Store.shared.lastSoftwareDate)),
            ])
        }
    }

    private func toolCard(icon: String, label: String, color: Color, stats: [(String, String)]) -> some View {
        InstrumentPanel(title: "", badge: nil) {
            VStack(alignment: .leading, spacing: 6) {
                // Icon + label (InstrumentPanel header hidden; this is the heading)
                HStack(spacing: 6) {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundColor(color)
                    Text(label)
                        .titleFont(11).kerning(3)
                        .foregroundColor(color)
                }
                .padding(.top, 4)

                ForEach(stats.indices, id: \.self) { i in
                    let (l, v) = stats[i]
                    HStack(spacing: 4) {
                        Text("> \(l):")
                            .monoFont(8)
                            .foregroundColor(Brand.textDim)
                        Text(v)
                            .monoFont(9)
                            .foregroundColor(Brand.accentGold)
                            .lineLimit(1)
                        Spacer()
                    }
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    // MARK: - System Row (CPU + Memory)

    private var systemRow: some View {
        HStack(spacing: 12) {
            if let s = monitor.stats {
                cpuCard(s)
                memoryCard(s)
            } else if monitor.isLoading {
                loadingIndicator
            }
        }
    }

    private var loadingIndicator: some View {
        HStack(spacing: 8) {
            PulseGlow()
            Text(L10n.overviewLoading)
                .monoFont(10)
                .foregroundColor(Brand.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - CPU Card

    private func cpuCard(_ s: SystemStats) -> some View {
        InstrumentPanel(title: L10n.overviewPanelCpu, badge: s.hardware.cpuModel) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(s.cpu.usage))").titleFont(36).foregroundColor(cpuColor(s.cpu.usage))
                    Text("%").monoFont(12).foregroundColor(Brand.textDim)
                    Spacer()
                    Text(String(format: L10n.overviewCpuCores, s.cpu.coreCount)).monoFont(9).foregroundColor(Brand.textDim)
                }
                ProgressGlow(progress: s.cpu.usage / 100).frame(height: 4)

                HStack(spacing: 8) {
                    loadChip("1m", s.cpu.load1)
                    loadChip("5m", s.cpu.load5)
                    loadChip("15m", s.cpu.load15)
                }

                // Network RX sparkline (mini preview)
                if !monitor.rxHistory.isEmpty {
                    Sparkline(values: Array(monitor.rxHistory.suffix(15)), color: Brand.accentOrange, lineWidth: 1)
                        .frame(height: 24)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    private func loadChip(_ label: String, _ value: Double) -> some View {
        InfoChip(label: label, value: String(format: "%.1f", value))
    }

    private func cpuColor(_ usage: Double) -> Color {
        usage > 80 ? Brand.accentRed : usage > 50 ? Brand.accentGold : Brand.accentOrange
    }

    // MARK: - Memory Card

    private func memoryCard(_ s: SystemStats) -> some View {
        InstrumentPanel(title: L10n.overviewPanelMemory, badge: Format.bytes(Int64(s.memory.total))) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(s.memory.usedPercent))").titleFont(36).foregroundColor(memColor(s.memory.usedPercent))
                    Text("%").monoFont(12).foregroundColor(Brand.textDim)
                    Spacer()
                    Text("\(Format.bytes(Int64(s.memory.used))) / \(Format.bytes(Int64(s.memory.total)))")
                        .monoFont(9).foregroundColor(Brand.textDim)
                }
                ProgressGlow(progress: s.memory.usedPercent / 100).frame(height: 4)

                if s.memory.swapUsed > 0 {
                    HStack(spacing: 4) {
                        Text(L10n.overviewSwap).monoFont(8).foregroundColor(Brand.textDim)
                        Text("\(Format.bytes(Int64(s.memory.swapUsed))) / \(Format.bytes(Int64(s.memory.swapTotal)))")
                            .monoFont(9).foregroundColor(Brand.accentGold)
                    }
                }
                if !s.memory.pressure.isEmpty {
                    Text(s.memory.pressure).monoFont(8).foregroundColor(Brand.textDim.opacity(0.7))
                }

                // Network TX sparkline (mini preview)
                if !monitor.txHistory.isEmpty {
                    Sparkline(values: Array(monitor.txHistory.suffix(15)), color: Brand.accentBlue, lineWidth: 1)
                        .frame(height: 24)
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
        }
    }

    private func memColor(_ pct: Double) -> Color {
        pct > 85 ? Brand.accentRed : pct > 65 ? Brand.accentGold : Brand.accentBlue
    }

    // MARK: - Battery Section

    @ViewBuilder private var batterySection: some View {
        if let s = monitor.stats, let b = s.batteries.first {
            let temp = s.thermal?.batteryTemp ?? 0
            InstrumentPanel(title: L10n.overviewPanelBattery, badge: nil) {
                VStack(alignment: .leading, spacing: 8) {
                    // Charge percentage + status
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        if b.isCharging {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 16))
                                .foregroundColor(Brand.accentGold)
                        }
                        Text("\(b.percent)")
                            .titleFont(36)
                            .foregroundColor(batteryColor(b.percent))
                        Text("%")
                            .monoFont(12)
                            .foregroundColor(Brand.textDim)
                        Spacer()
                        Text(b.status.uppercased())
                            .monoFont(9)
                            .foregroundColor(batteryStatusColor(b))
                    }

                    // Stats row: cycles, health, temp
                    HStack(spacing: 12) {
                        InfoChip(label: L10n.overviewBatteryCycle, value: "\(b.cycleCount)")
                        if b.capacity > 0 {
                            InfoChip(label: L10n.overviewBatteryHealth, value: "\(b.capacity)%")
                        }
                        if temp > 0 {
                            InfoChip(label: L10n.overviewBatteryTemp, value: "\(Int(temp))°C")
                        }
                    }

                    // Time remaining
                    HStack(spacing: 4) {
                        Text("> \(L10n.overviewBatteryTime):")
                            .monoFont(8)
                            .foregroundColor(Brand.textDim)
                        Text(timeDisplay(b))
                            .monoFont(9)
                            .foregroundColor(Brand.accentGold)
                        Spacer()
                    }
                }
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
            }
        }
    }

    private func batteryColor(_ pct: Int) -> Color {
        pct > 60 ? Brand.accentBlue : pct > 20 ? Brand.accentGold : Brand.accentRed
    }

    private func batteryStatusColor(_ b: BatteryStats) -> Color {
        b.isCharging ? Brand.accentGold : b.isCharged ? Brand.accentBlue : Brand.accentOrange
    }

    private func timeDisplay(_ b: BatteryStats) -> String {
        if b.isCharged { return L10n.overviewBatteryCharged }
        if b.isCharging { return "\(b.timeLeft) to full" }
        return "\(b.timeLeft) remaining"
    }

    // MARK: - Network Section (full width)

    private var networkSection: some View {
        Group {
            if let s = monitor.stats, let net = s.network.first {
                InstrumentPanel(title: L10n.overviewPanelNetwork, badge: net.name) {
                    HStack(spacing: 16) {
                        // Rates
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 24) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.overviewDown).monoFont(8).foregroundColor(Brand.textDim)
                                    Text(net.rxRateMbs.map { "\(String(format: "%.1f", $0)) MB/s" } ?? "—")
                                        .monoFont(16).foregroundColor(Brand.accentOrange)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(L10n.overviewUp).monoFont(8).foregroundColor(Brand.textDim)
                                    Text(net.txRateMbs.map { "\(String(format: "%.1f", $0)) MB/s" } ?? "—")
                                        .monoFont(16).foregroundColor(Brand.accentBlue)
                                }
                            }
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(L10n.overviewDiskRead).monoFont(7).foregroundColor(Brand.textDim)
                                    Text("\(String(format: "%.1f", s.diskIO.readRate)) MB/s")
                                        .monoFont(10).foregroundColor(Brand.accentOrange)
                                }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(L10n.overviewDiskWrite).monoFont(7).foregroundColor(Brand.textDim)
                                    Text("\(String(format: "%.1f", s.diskIO.writeRate)) MB/s")
                                        .monoFont(10).foregroundColor(Brand.accentBlue)
                                }
                            }
                        }

                        Spacer()

                        // Sparklines
                        if !monitor.rxHistory.isEmpty {
                            VStack(spacing: 6) {
                                Sparkline(values: monitor.rxHistory, color: Brand.accentOrange, lineWidth: 1.2)
                                    .frame(width: 120, height: 36)
                                Sparkline(values: monitor.txHistory, color: Brand.accentBlue, lineWidth: 1.2)
                                    .frame(width: 120, height: 36)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
            }
        }
    }

    // MARK: - Disk Section (full width)

    private var diskSection: some View {
        GlassCard {
            VStack(spacing: 8) {
                HStack {
                    Text(L10n.overviewDisk).titleFont(12).kerning(3).foregroundColor(Brand.accentOrange)
                    Spacer()
                    if let disk = monitor.stats?.disks.first {
                        Text(disk.mount).monoFont(8).foregroundColor(Brand.textDim)
                    }
                }

                if let disk = monitor.stats?.disks.first {
                    let pct = disk.usedPercent / 100
                    let free = disk.total - disk.used
                    HStack(spacing: 0) {
                        Text("> " + L10n.overviewDiskUsage + ":")
                            .monoFont(11).foregroundColor(Brand.textPrimary)
                        Spacer()
                        Text("\(Format.bytes(Int64(disk.used))) / \(Format.bytes(Int64(disk.total)))")
                            .monoFont(10).foregroundColor(Brand.textDim)
                    }
                    ProgressGlow(progress: pct).frame(height: 6)
                    HStack {
                        Text(String(format: L10n.overviewFreeFormat, Format.bytes(Int64(free))))
                            .monoFont(9).foregroundColor(pct > 0.9 ? Brand.accentRed : Brand.accentGold)
                        Spacer()
                        Text(String(format: L10n.overviewUsedFormat, Int(pct * 100)))
                            .monoFont(9).foregroundColor(pct > 0.9 ? Brand.accentRed : pct > 0.75 ? Brand.accentGold : Brand.textDim)
                    }
                } else {
                    DataRow(label: L10n.overviewDiskCapacity, value: formatBytes(diskCapacity))
                    DataRow(label: L10n.overviewDiskFree, value: formatBytes(diskFree))
                    if diskCapacity > 0 {
                        let pct = Double(diskCapacity - diskFree) / Double(diskCapacity)
                        ProgressGlow(progress: pct).frame(height: 6)
                    }
                }
            }
        }
    }

    // MARK: - Quick Actions

    private var quickBar: some View {
        HStack(spacing: 12) {
            quickBtn(icon: Pane.clean.iconName, label: L10n.overviewQuickScan, color: Brand.accentOrange) { onNavigate(.clean) }
            quickBtn(icon: Pane.purge.iconName, label: L10n.navPurge, color: Brand.accentOrange) { onNavigate(.purge) }
            quickBtn(icon: Pane.optimize.iconName, label: L10n.navOptimize, color: Brand.accentOrange) { onNavigate(.optimize) }
            quickBtn(icon: Pane.analyze.iconName, label: L10n.navAnalyze, color: Brand.accentOrange) { onNavigate(.analyze) }
            quickBtn(icon: Pane.software.iconName, label: L10n.navSoftware, color: Brand.accentOrange) { onNavigate(.software) }
            Spacer()
            quickBtn(icon: "gearshape.fill", label: L10n.overviewQuickSettings, color: Brand.accentBlue) { onNavigate(.settings) }
        }
        .padding(.top, 8)
    }

    private func quickBtn(icon: String, label: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon).font(.system(size: 10))
                Text(label).monoFont(10).lineLimit(1)
            }
            .foregroundColor(color)
            .padding(.horizontal, 10).padding(.vertical, 6)
            .background(color.opacity(0.1))
            .overlay(RoundedRectangle(cornerRadius: 4).stroke(color, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Disk Info Loading

    private func loadDiskInfo() {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        guard let path = paths.first else { return }
        do {
            let attrs = try FileManager.default.attributesOfFileSystem(forPath: path)
            diskCapacity = (attrs[.systemSize] as? NSNumber)?.int64Value ?? 0
            diskFree = (attrs[.systemFreeSize] as? NSNumber)?.int64Value ?? 0
        } catch {}
    }
}

#Preview {
    OverviewView(onNavigate: { _ in })
        .frame(width: 900, height: 640)
        .background(Brand.bgNavy)
        .environment(\.colorScheme, .dark)
}
