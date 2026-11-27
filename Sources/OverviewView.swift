import SwiftUI

/// The Overview dashboard — landing page when clicking the Moler logo.
///
/// Deliberately minimal: one live vitals strip, the two most useful detail
/// panels, and a slim status readout. Navigation lives in the sidebar, so the
/// old tool-shortcut grid and duplicate quick-action bar are gone.
struct OverviewView: View {
    let isVisible: Bool

    init(isVisible: Bool = true) {
        self.isVisible = isVisible
    }

    @StateObject private var monitor = SystemMonitor()
    @ObservedObject private var activity = AppActivityMonitor.shared
    @State private var diskCapacity: Int64 = 0
    @State private var diskFree: Int64 = 0
    @State private var history: [MoleHistorySession] = []
    @State private var lastHistoryLoad = Date.distantPast

    // Popover state
    @State private var showHealthTip = false

    var body: some View {
        VStack(spacing: 0) {
            PageHeaderBand(
                icon: Pane.overview.iconName,
                title: L10n.overviewTitle,
                subtitle: overviewSubtitle,
                statusColor: monitor.stats == nil
                    ? Brand.accentOrange.opacity(0.65)
                    : Brand.accentGreen
            ) {
                if let stats = monitor.stats {
                    healthButton(stats)
                }
            }

            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 20) {
                        vitalsCard

                        HStack(alignment: .top, spacing: 12) {
                            processesPanel
                            activityPanel
                        }

                        Spacer(minLength: 20)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 16)
                    .padding(.bottom, 20)
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: geo.size.height, alignment: .top)
                }
            }

            // Pinned footer readout, so the dashboard never ends in dead space.
            if let stats = monitor.stats {
                statusStripContent(stats)
                    .padding(.horizontal, 24)
                    .padding(.top, 2)
                    .padding(.bottom, 16)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            loadDiskInfo()
            loadHistory(force: true)
        }
        .onAppear { updatePolling() }
        .onDisappear { monitor.stop() }
        .onChange(of: isVisible) { _, visible in
            updatePolling()
            if visible { loadHistory() }
        }
        .onChange(of: activity.isWindowVisible) { _, visible in
            updatePolling()
            if visible { loadHistory() }
        }
        .onChange(of: activity.isAppActive) { _, active in
            updatePolling()
            if active { loadHistory() }
        }
    }

    /// Poll system stats only while this pane is on screen. The dashboard is
    /// kept alive when other tabs are active, so `onDisappear` never fires —
    /// visibility must be observed explicitly.
    private func updatePolling() {
        monitor.setPolling(
            enabled: isVisible && activity.isWindowVisible,
            appActive: activity.isAppActive
        )
    }

    // MARK: - Header

    private var overviewSubtitle: String {
        "\(L10n.overviewSubtitle) · \(monitor.stats == nil ? L10n.overviewLoading : L10n.overviewLive)"
    }

    // MARK: - Health Ring

    private func healthButton(_ stats: SystemStats) -> some View {
        let color = healthColor(stats.healthScore)
        let band = healthBand(stats.healthScore)

        return Button {
            showHealthTip.toggle()
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .trailing, spacing: 2) {
                    Text(L10n.overviewHealth)
                        .monoFont(7).kerning(2)
                        .foregroundColor(Brand.textDim)
                    Text(band)
                        .monoFont(9)
                        .foregroundColor(color)
                }

                ZStack {
                    Circle()
                        .stroke(Brand.lineColor.opacity(0.3), lineWidth: 3)

                    Circle()
                        .trim(from: 0, to: CGFloat(max(0, min(100, stats.healthScore))) / 100)
                        .stroke(
                            color,
                            style: StrokeStyle(lineWidth: 3, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.5), value: stats.healthScore)

                    Text("\(stats.healthScore)")
                        .titleFont(16)
                        .foregroundColor(color)
                        .contentTransition(.numericText())
                        .animation(.easeOut(duration: 0.3), value: stats.healthScore)
                }
                .frame(width: 44, height: 44)
            }
            .padding(.leading, 12)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
        .help(L10n.overviewHealth)
        .popover(isPresented: $showHealthTip, arrowEdge: .bottom) {
            healthTip(stats)
        }
    }

    private func healthTip(_ stats: SystemStats) -> some View {
        let color = healthColor(stats.healthScore)
        let band = healthBand(stats.healthScore)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.overviewHealth)
                        .monoFont(8).kerning(2)
                        .foregroundColor(Brand.textDim)
                    Text(band)
                        .monoFont(10)
                        .foregroundColor(color)
                }
                Spacer()
                Text("\(stats.healthScore)")
                    .titleFont(24)
                    .foregroundColor(color)
            }

            if !stats.healthScoreMsg.isEmpty {
                Text(stats.healthScoreMsg)
                    .monoFont(9)
                    .foregroundColor(Brand.textDim)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Rectangle()
                .fill(Brand.lineColor.opacity(0.3))
                .frame(height: 1)

            let gaugeRings = healthGaugeRings(stats)

            HStack(alignment: .center, spacing: 16) {
                ConcentricGauge(rings: gaugeRings)
                    .frame(width: 128, height: 128)

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(gaugeRings) { ring in
                        HStack(spacing: 6) {
                            Circle()
                                .fill(ring.color)
                                .frame(width: 5, height: 5)

                            Text(ring.label)
                                .monoFont(9)
                                .foregroundColor(Brand.textDim)

                            Spacer(minLength: 8)

                            Text(ring.displayValue)
                                .monoFont(10)
                                .foregroundColor(ring.color)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            if stats.memory.swapUsed > 0 {
                HStack {
                    Text(L10n.overviewSwap)
                        .monoFont(8)
                        .foregroundColor(Brand.textDim)
                    Spacer()
                    Text("\(Format.bytes(stats.memory.swapUsed)) / \(Format.bytes(stats.memory.swapTotal))")
                        .monoFont(8)
                        .foregroundColor(Brand.textDim)
                }
            }
        }
        .padding(16)
        .frame(width: 288)
        .background(Brand.bgElevated)
    }

    private func healthGaugeRings(_ stats: SystemStats) -> [ConcentricGaugeRing] {
        var rings = [
            ConcentricGaugeRing(
                id: "cpu",
                label: L10n.overviewPanelCpu,
                value: stats.cpu.usage / 100,
                displayValue: "\(Int(stats.cpu.usage))%",
                color: Brand.accentOrange
            ),
            ConcentricGaugeRing(
                id: "memory",
                label: L10n.overviewPanelMemory,
                value: stats.memory.usedPercent / 100,
                displayValue: "\(Int(stats.memory.usedPercent))%",
                color: Brand.accentSky
            ),
        ]

        if let disk = systemDisk(stats) {
            rings.append(
                ConcentricGaugeRing(
                    id: "disk",
                    label: L10n.overviewDisk,
                    value: disk.usedPercent / 100,
                    displayValue: "\(Int(disk.usedPercent))%",
                    color: Brand.accentGold
                )
            )
        }

        return rings
    }

    private func healthColor(_ score: Int) -> Color {
        if score >= 85 { return Brand.accentGreen }
        if score >= 65 { return Brand.accentGold }
        if score >= 45 { return Brand.accentOrange }
        return Brand.accentRed
    }

    private func healthBand(_ score: Int) -> String {
        if score >= 85      { return L10n.overviewHealthExcellent }
        else if score >= 65 { return L10n.overviewHealthGood }
        else if score >= 45 { return L10n.overviewHealthFair }
        else                { return L10n.overviewHealthAttention }
    }

    // MARK: - Vitals

    private var vitalsCard: some View {
        OverviewCard(padding: EdgeInsets(top: 16, leading: 2, bottom: 14, trailing: 2)) {
            if let stats = monitor.stats {
                HStack(alignment: .top, spacing: 0) {
                    cpuVital(stats)
                    vitalDivider
                    memoryVital(stats)
                    vitalDivider
                    diskVital(stats)
                    vitalDivider
                    networkVital(stats)

                    if let battery = stats.batteries.first {
                        vitalDivider
                        batteryVital(battery)
                    }
                }
            } else {
                HStack(spacing: 10) {
                    PulseGlow()
                    Text(L10n.overviewLoading)
                        .monoFont(10)
                        .foregroundColor(Brand.textDim)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .frame(height: 92)
            }
        }
    }

    private var vitalDivider: some View {
        Rectangle()
            .fill(Brand.lineColor.opacity(0.22))
            .frame(width: 1, height: 74)
    }

    private func vitalHeader(_ title: String) -> some View {
        Text(title)
            .monoFont(8).kerning(2)
            .foregroundColor(Brand.textDim)
    }

    private func vitalValue(_ value: String, unit: String, color: Color, size: CGFloat = 26) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(value)
                .titleFont(size)
                .foregroundColor(color)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .contentTransition(.numericText())
                .animation(.easeOut(duration: 0.3), value: value)

            Text(unit)
                .monoFont(9)
                .foregroundColor(Brand.textDim)

            Spacer(minLength: 0)
        }
        .frame(height: 30, alignment: .leading)
    }

    private func vitalVisual<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .frame(height: 12, alignment: .topLeading)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func vitalFootnote(_ text: String, color: Color = Brand.textDim) -> some View {
        Text(text)
            .monoFont(8)
            .foregroundColor(color)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .frame(height: 10, alignment: .leading)
    }

    private func cpuVital(_ stats: SystemStats) -> some View {
        let color = cpuColor(stats.cpu.usage)
        let cores = String(format: L10n.overviewCpuCores, stats.cpu.coreCount)
        let load = String(format: "%.1f", stats.cpu.load1)

        return VStack(alignment: .leading, spacing: 6) {
            vitalHeader(L10n.overviewPanelCpu)
            vitalValue("\(Int(stats.cpu.usage))", unit: "%", color: color)
            vitalVisual {
                MetricBar(progress: stats.cpu.usage / 100, color: color)
            }
            vitalFootnote("\(cores) · \(L10n.overviewLoad) \(load)")
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func memoryVital(_ stats: SystemStats) -> some View {
        let color = memColor(stats.memory.usedPercent)

        return VStack(alignment: .leading, spacing: 6) {
            vitalHeader(L10n.overviewPanelMemory)
            vitalValue("\(Int(stats.memory.usedPercent))", unit: "%", color: color)
            vitalVisual {
                MetricBar(progress: stats.memory.usedPercent / 100, color: color)
            }
            vitalFootnote("\(Format.bytes(stats.memory.used)) / \(Format.bytes(stats.memory.total))")
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func diskVital(_ stats: SystemStats) -> some View {
        let disk = systemDisk(stats)
        let total = disk?.total ?? UInt64(max(0, diskCapacity))
        let used = disk?.used ?? UInt64(max(0, diskCapacity - diskFree))
        let free = total > used ? total - used : 0
        let percent = disk?.usedPercent ?? (total > 0 ? Double(used) / Double(total) * 100 : 0)
        let color = diskColor(percent / 100)

        return VStack(alignment: .leading, spacing: 6) {
            vitalHeader(L10n.overviewDisk)
            vitalValue("\(Int(percent))", unit: "%", color: color)
            vitalVisual {
                MetricBar(progress: percent / 100, color: color)
            }
            vitalFootnote(String(format: L10n.overviewFreeFormat, Format.bytes(free)))
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func networkVital(_ stats: SystemStats) -> some View {
        let net = stats.network.first
        let proxy = (stats.proxy?.enabled ?? false) ? stats.proxy : nil

        return VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                vitalHeader(L10n.overviewPanelNetwork)
                Spacer(minLength: 0)
                if proxy != nil {
                    Circle()
                        .fill(Brand.accentGreen)
                        .frame(width: 3, height: 3)
                    Text(L10n.overviewProxy)
                        .monoFont(6).kerning(1)
                        .foregroundColor(Brand.accentGreen.opacity(0.85))
                }
            }
            .help(proxy.map { "\($0.type.uppercased()) · \($0.host)" } ?? "")

            HStack(alignment: .firstTextBaseline, spacing: 3) {
                Image(systemName: "arrow.down")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundColor(Brand.accentOrange)

                Text(net?.rxRateMbs.map { String(format: "%.1f", $0) } ?? "—")
                    .titleFont(22)
                    .foregroundColor(Brand.accentOrange)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .contentTransition(.numericText())

                Text("MB/s")
                    .monoFont(8)
                    .foregroundColor(Brand.textDim)

                Spacer(minLength: 0)
            }
            .frame(height: 30, alignment: .leading)

            vitalVisual {
                Sparkline(
                    values: Array(monitor.rxHistory.suffix(24)),
                    color: Brand.accentOrange,
                    lineWidth: 1
                )
            }

            let tx = net?.txRateMbs.map { String(format: "%.1f", $0) } ?? "—"
            vitalFootnote("↑ \(tx) MB/s\(net.map { " · \($0.name)" } ?? "")")
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func batteryVital(_ battery: BatteryStats) -> some View {
        let color = batteryColor(battery.percent)

        return VStack(alignment: .leading, spacing: 6) {
            vitalHeader(L10n.overviewPanelBattery)
            vitalValue("\(battery.percent)", unit: "%", color: color)
            vitalVisual {
                MetricBar(progress: Double(battery.percent) / 100, color: color)
            }
            vitalFootnote(batteryFootnote(battery), color: batteryStatusColor(battery))
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func batteryFootnote(_ battery: BatteryStats) -> String {
        if battery.isCharged { return L10n.overviewBatteryCharged }

        let status: String
        if battery.isCharging {
            status = L10n.overviewBatteryCharging
        } else if battery.isDischarging {
            status = L10n.overviewBatteryDischarging
        } else if battery.status.uppercased() == "AC" {
            status = L10n.overviewBatteryAC
        } else {
            status = battery.status.uppercased()
        }

        return battery.timeLeft.isEmpty ? status : "\(status) · \(battery.timeLeft)"
    }

    private func cpuColor(_ usage: Double) -> Color {
        usage > 80 ? Brand.accentRed : usage > 50 ? Brand.accentGold : Brand.accentOrange
    }

    private func memColor(_ percent: Double) -> Color {
        percent > 85 ? Brand.accentRed : percent > 65 ? Brand.accentGold : Brand.accentSky
    }

    private func diskColor(_ fraction: Double) -> Color {
        fraction > 0.9 ? Brand.accentRed : fraction > 0.75 ? Brand.accentOrange : Brand.accentGold
    }

    /// The boot volume. `mo status` also reports simulator volumes and other
    /// mounts; the dashboard should read the system disk's health, capacity,
    /// and purgeable space, not whichever mount happens to be listed first.
    private func systemDisk(_ stats: SystemStats) -> DiskStats? {
        stats.disks.first(where: { $0.mount == "/" }) ?? stats.disks.first
    }

    private func batteryColor(_ percent: Int) -> Color {
        percent > 60 ? Brand.accentBlue : percent > 20 ? Brand.accentGold : Brand.accentRed
    }

    private func batteryStatusColor(_ battery: BatteryStats) -> Color {
        if battery.isCharging || battery.status.uppercased() == "AC" {
            return Brand.accentGold
        }
        return battery.isCharged ? Brand.accentBlue : Brand.accentOrange
    }

    // MARK: - Top Processes

    private var processesPanel: some View {
        OverviewCard {
            VStack(alignment: .leading, spacing: 12) {
                panelHeader(L10n.overviewPanelProcesses, trailing: "TOP 5")

                if let processes = monitor.stats?.topProcesses, !processes.isEmpty {
                    VStack(spacing: 7) {
                        ForEach(processes.prefix(5)) { process in
                            processRow(process)
                        }
                    }
                } else {
                    panelPlaceholder
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 152, alignment: .top)
    }

    private func processRow(_ process: ProcessStats) -> some View {
        HStack(spacing: 8) {
            Text(process.name)
                .monoFont(9)
                .foregroundColor(Brand.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 4)

            Text(String(format: "%.1f%%", process.cpu))
                .monoFont(9)
                .foregroundColor(cpuColor(process.cpu))
                .frame(width: 44, alignment: .trailing)

            Text(Format.bytes(process.memoryBytes))
                .monoFont(8)
                .foregroundColor(Brand.textDim)
                .frame(width: 60, alignment: .trailing)
        }
    }

    // MARK: - Recent Activity

    private var activityPanel: some View {
        OverviewCard {
            VStack(alignment: .leading, spacing: 12) {
                panelHeader(L10n.overviewActivity)

                if history.isEmpty {
                    Text(L10n.overviewActivityEmpty)
                        .monoFont(9)
                        .foregroundColor(Brand.textDim.opacity(0.8))
                } else {
                    VStack(spacing: 7) {
                        ForEach(history.prefix(5)) { session in
                            activityRow(session)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 152, alignment: .top)
    }

    private func activityRow(_ session: MoleHistorySession) -> some View {
        HStack(spacing: 8) {
            Text(session.displayCommand)
                .monoFont(8).kerning(1)
                .foregroundColor(Brand.accentGold)
                .lineLimit(1)
                .frame(width: 64, alignment: .leading)

            Text(session.startedDate.map { Format.relativeDate($0) } ?? session.startedAt)
                .monoFont(8)
                .foregroundColor(Brand.textDim)
                .lineLimit(1)

            Spacer(minLength: 4)

            if let failed = session.failedTasks, failed > 0 {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 7))
                    .foregroundColor(Brand.accentRed)
                    .help("\(failed)")
            }

            Text(session.size)
                .monoFont(9)
                .foregroundColor(Brand.accentOrange)
        }
    }

    private func panelHeader(_ title: String, trailing: String? = nil) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Brand.accentOrange)
                .frame(width: 3, height: 10)

            Text(title)
                .titleFont(10).kerning(2)
                .foregroundColor(Brand.textPrimary)

            Spacer()

            if let trailing {
                Text(trailing)
                    .monoFont(8)
                    .foregroundColor(Brand.textDim.opacity(0.65))
            }
        }
    }

    private var panelPlaceholder: some View {
        HStack {
            Text(monitor.stats == nil ? L10n.overviewLoading : "—")
                .monoFont(9)
                .foregroundColor(Brand.textDim.opacity(0.75))
            Spacer()
        }
    }

    // MARK: - Status Strip

    private func statusStripContent(_ stats: SystemStats) -> some View {
        let totalFreed = Store.shared.totalFreedBytes
            + Store.shared.totalPurgeFreedBytes
            + Store.shared.totalSoftwareBytesFreed
        let disk = systemDisk(stats)
        let purgeable = disk?.purgeable ?? 0
        let smart = disk?.smartStatus?.lowercased() ?? ""
        let smartFailing = smart.contains("fail")

        return OverviewCard(padding: EdgeInsets(top: 10, leading: 0, bottom: 10, trailing: 0)) {
            HStack(spacing: 0) {
                statusCell(
                    icon: "sparkles",
                    label: L10n.overviewTotalFreed,
                    value: Format.bytes(totalFreed),
                    color: Brand.accentGold
                )

                statusDivider

                statusCell(
                    icon: "clock",
                    label: L10n.overviewUptime,
                    value: Format.uptime(stats.uptimeSeconds)
                )

                if purgeable > 0 {
                    statusDivider
                    statusCell(
                        icon: "arrow.down.circle",
                        label: L10n.overviewDiskPurgeable,
                        value: Format.bytes(purgeable),
                        color: Brand.accentGold
                    )
                }

                if stats.trashSize > 0 {
                    statusDivider
                    statusCell(
                        icon: "trash",
                        label: L10n.overviewDiskTrash,
                        value: Format.bytes(stats.trashSize)
                    )
                }

                if smartFailing {
                    statusDivider
                    statusCell(
                        icon: "exclamationmark.triangle.fill",
                        label: L10n.overviewDiskSmart,
                        value: smart.uppercased(),
                        color: Brand.accentRed,
                        iconColor: Brand.accentRed
                    )
                }
            }
        }
    }

    private func statusCell(
        icon: String,
        label: String,
        value: String,
        color: Color = Brand.textPrimary,
        iconColor: Color = Brand.textDim
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 14)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .monoFont(7).kerning(1.5)
                    .foregroundColor(Brand.textDim)
                    .lineLimit(1)

                Text(value)
                    .monoFont(9)
                    .foregroundColor(color)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusDivider: some View {
        Rectangle()
            .fill(Brand.lineColor.opacity(0.25))
            .frame(width: 1, height: 26)
    }

    // MARK: - History Loading

    private func loadHistory(force: Bool = false) {
        let now = Date()
        guard force || now.timeIntervalSince(lastHistoryLoad) > 20 else { return }
        lastHistoryLoad = now

        Task { @MainActor in
            let sessions = await Task.detached(priority: .utility) {
                (try? MoleHistoryLoader.load(limit: 20)) ?? []
            }.value
            history = Array(sessions.prefix(5))
        }
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

// MARK: - Card Container

/// A quiet, rounded panel used only by the Overview. Slightly translucent so
/// the topographic background shows through, with a hairline border and a
/// faint top sheen.
private struct OverviewCard<Content: View>: View {
    var padding: EdgeInsets
    let content: () -> Content

    init(
        padding: EdgeInsets = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Brand.bgCard.opacity(0.92),
                                Brand.bgCard.opacity(0.64),
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Brand.lineColor.opacity(0.28), lineWidth: 0.5)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Color.white.opacity(0.06), .clear],
                            startPoint: .top,
                            endPoint: .center
                        ),
                        lineWidth: 0.5
                    )
                    .allowsHitTesting(false)
            )
    }
}

// MARK: - Metric Bar

/// A thin, colored meter. Replaces the shared `ProgressGlow` here so each
/// vital can keep its own semantic color.
private struct MetricBar: View {
    let progress: Double
    var color: Color = Brand.accentOrange

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Brand.lineColor.opacity(0.35))

                Capsule()
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.7), color],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: max(0, geo.size.width * min(max(progress, 0), 1)))
                    .shadow(color: color.opacity(0.45), radius: 4)
            }
        }
        .frame(height: 3)
        .animation(.easeOut(duration: 0.5), value: progress)
    }
}

#Preview {
    OverviewView()
        .frame(width: 900, height: 640)
        .background(Brand.bgNavy)
        .environment(\.colorScheme, .dark)
}
