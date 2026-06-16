import SwiftUI

/// The Overview dashboard — landing page when clicking the Moler logo.
struct OverviewView: View {
    let onNavigate: (Pane) -> Void

    @StateObject private var monitor = SystemMonitor()
    @State private var diskCapacity: Int64 = 0
    @State private var diskFree: Int64 = 0

    var body: some View {
        ScrollView([.vertical], showsIndicators: false) {
            VStack(spacing: 24) {
                headerSection
                statsCard
                liveSystemCards
                diskCard
                quickActions
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 28)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task { loadDiskInfo() }
        .onAppear { monitor.start() }
        .onDisappear { monitor.stop() }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 16) {
            ZStack {
                Reticle(strokeColor: Brand.accentOrange.opacity(0.5), lineWidth: 0.5, armLength: 18)
                    .frame(width: 100, height: 100)
                Image(systemName: "gauge.with.dots.needle.33percent")
                    .font(.system(size: 42))
                    .foregroundColor(Brand.accentOrange)
            }
            VStack(spacing: 6) {
                Text(L10n.overviewTitle)
                    .titleFont(28).kerning(8)
                    .foregroundColor(Brand.accentOrange)
                Text(L10n.overviewSubtitle)
                    .monoFont(10)
                    .foregroundColor(Brand.textDim)
            }
        }
        .padding(.top, 20)
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        GlassCard {
            VStack(spacing: Brand.unit * 2) {
                DataRow(label: L10n.overviewTotalFreed, value: formatBytes(Store.shared.totalFreedBytes))
                DataRow(label: L10n.overviewCleanCount, value: "\(Store.shared.totalCleanCount)")
                DataRow(label: L10n.overviewLastClean, value: Store.shared.lastCleanDate?.formatted() ?? L10n.cleanNever)
                DataRow(label: L10n.overviewLastScan, value: Store.shared.lastScanPath)
            }
        }
        .frame(maxWidth: 500)
    }

    // MARK: - Live System Cards

    private var liveSystemCards: some View {
        VStack(spacing: 12) {
            if let s = monitor.stats {
                HStack(spacing: 12) {
                    cpuCard(s)
                    memoryCard(s)
                }
                networkCard(s)
            } else if monitor.isLoading {
                loadingIndicator
            }
        }
        .frame(maxWidth: 600)
    }

    private var loadingIndicator: some View {
        HStack(spacing: 8) {
            PulseGlow()
            Text("Loading system data…")
                .monoFont(10)
                .foregroundColor(Brand.textDim)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - CPU Card

    private func cpuCard(_ s: SystemStats) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("CPU").titleFont(12).kerning(3).foregroundColor(Brand.accentOrange)
                    Spacer()
                    Text(s.hardware.cpuModel).monoFont(8).foregroundColor(Brand.textDim)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(s.cpu.usage))").titleFont(32).foregroundColor(cpuColor(s.cpu.usage))
                    Text("%").monoFont(12).foregroundColor(Brand.textDim)
                    Spacer()
                    Text("\(s.cpu.coreCount) cores").monoFont(9).foregroundColor(Brand.textDim)
                }
                ProgressGlow(progress: s.cpu.usage / 100).frame(height: 4)
                HStack(spacing: 12) {
                    loadChip("1m", s.cpu.load1)
                    loadChip("5m", s.cpu.load5)
                    loadChip("15m", s.cpu.load15)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func loadChip(_ label: String, _ value: Double) -> some View {
        HStack(spacing: 2) {
            Text(label).monoFont(8).foregroundColor(Brand.textDim)
            Text(String(format: "%.1f", value)).monoFont(9).foregroundColor(Brand.accentGold)
        }
        .padding(.horizontal, 6).padding(.vertical, 2)
        .background(Brand.bgCard.opacity(0.5)).cornerRadius(3)
    }

    private func cpuColor(_ usage: Double) -> Color {
        usage > 80 ? Brand.accentRed : usage > 50 ? Brand.accentGold : Brand.accentOrange
    }

    // MARK: - Memory Card

    private func memoryCard(_ s: SystemStats) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("MEM").titleFont(12).kerning(3).foregroundColor(Brand.accentBlue)
                    Spacer()
                    Text(Format.bytes(Int64(s.memory.total))).monoFont(8).foregroundColor(Brand.textDim)
                }
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(Int(s.memory.usedPercent))").titleFont(32).foregroundColor(memColor(s.memory.usedPercent))
                    Text("%").monoFont(12).foregroundColor(Brand.textDim)
                    Spacer()
                    Text("\(Format.bytes(Int64(s.memory.used))) / \(Format.bytes(Int64(s.memory.total)))")
                        .monoFont(9).foregroundColor(Brand.textDim)
                }
                ProgressGlow(progress: s.memory.usedPercent / 100).frame(height: 4)
                if s.memory.swapUsed > 0 {
                    HStack(spacing: 4) {
                        Text("SWAP").monoFont(8).foregroundColor(Brand.textDim)
                        Text(Format.bytes(Int64(s.memory.swapUsed))).monoFont(9).foregroundColor(Brand.accentGold)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func memColor(_ pct: Double) -> Color {
        pct > 85 ? Brand.accentRed : pct > 65 ? Brand.accentGold : Brand.accentBlue
    }

    // MARK: - Network Card

    private func networkCard(_ s: SystemStats) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("NET").titleFont(12).kerning(3).foregroundColor(Brand.accentGold)
                    Spacer()
                    if let net = s.network.first {
                        Text(net.name).monoFont(8).foregroundColor(Brand.textDim)
                    }
                }
                if let net = s.network.first {
                    HStack(spacing: 16) {
                        // Left: rates + disk IO
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 24) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("↓ DOWN").monoFont(8).foregroundColor(Brand.textDim)
                                    Text(net.rxRateMbs.map { "\(String(format: "%.1f", $0)) MB/s" } ?? "—")
                                        .monoFont(14).foregroundColor(Brand.accentOrange)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("↑ UP").monoFont(8).foregroundColor(Brand.textDim)
                                    Text(net.txRateMbs.map { "\(String(format: "%.1f", $0)) MB/s" } ?? "—")
                                        .monoFont(14).foregroundColor(Brand.accentBlue)
                                }
                            }
                            HStack(spacing: 16) {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("READ").monoFont(7).foregroundColor(Brand.textDim)
                                    Text("\(String(format: "%.1f", s.diskIO.readRate)) MB/s")
                                        .monoFont(10).foregroundColor(Brand.accentOrange)
                                }
                                VStack(alignment: .leading, spacing: 2) {
                                    Text("WRITE").monoFont(7).foregroundColor(Brand.textDim)
                                    Text("\(String(format: "%.1f", s.diskIO.writeRate)) MB/s")
                                        .monoFont(10).foregroundColor(Brand.accentBlue)
                                }
                            }
                        }
                        Spacer()
                        // Right: sparklines
                        if !monitor.rxHistory.isEmpty {
                            VStack(spacing: 4) {
                                Sparkline(values: monitor.rxHistory, color: Brand.accentOrange, lineWidth: 1.2)
                                    .frame(width: 80, height: 28)
                                Sparkline(values: monitor.txHistory, color: Brand.accentBlue, lineWidth: 1.2)
                                    .frame(width: 80, height: 28)
                            }
                        }
                    }
                } else {
                    Text("No network data").monoFont(10).foregroundColor(Brand.textDim)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Disk Info

    private var diskCard: some View {
        GlassCard {
            VStack(spacing: Brand.unit * 2) {
                if let disk = monitor.stats?.disks.first {
                    DataRow(label: L10n.overviewDiskCapacity, value: Format.bytes(Int64(disk.total)))
                    DataRow(label: L10n.overviewDiskFree, value: Format.bytes(Int64(disk.total - disk.used)))
                    diskUsageBar(disk.usedPercent / 100)
                } else {
                    DataRow(label: L10n.overviewDiskCapacity, value: formatBytes(diskCapacity))
                    DataRow(label: L10n.overviewDiskFree, value: formatBytes(diskFree))
                    if diskCapacity > 0 {
                        diskUsageBar(Double(diskCapacity - diskFree) / Double(diskCapacity))
                    }
                }
            }
        }
        .frame(maxWidth: 500)
    }

    private func diskUsageBar(_ pct: Double) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 0) {
                Text("> " + L10n.overviewDiskUsage + ":").monoFont(11).foregroundColor(Brand.textPrimary)
                Spacer()
                Text("\(Int(pct * 100))%")
                    .monoFont(11)
                    .foregroundColor(pct > 0.9 ? Brand.accentRed : pct > 0.75 ? Brand.accentGold : Brand.accentOrange)
            }
            ProgressGlow(progress: pct).frame(height: 6)
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        HStack(spacing: 16) {
            Button {
                onNavigate(.clean)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "play.fill").font(.system(size: 11))
                    Text(L10n.overviewQuickScan).titleFont(12).kerning(4)
                }
                .padding(.horizontal, 24).padding(.vertical, 10)
                .background(Brand.accentOrange.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Brand.accentOrange, lineWidth: 1))
                .foregroundColor(Brand.accentOrange)
            }
            .buttonStyle(.plain)

            Button {
                onNavigate(.settings)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "gearshape.fill").font(.system(size: 11))
                    Text(L10n.overviewQuickSettings).titleFont(12).kerning(4)
                }
                .padding(.horizontal, 24).padding(.vertical, 10)
                .background(Brand.accentBlue.opacity(0.15))
                .overlay(RoundedRectangle(cornerRadius: 4).stroke(Brand.accentBlue, lineWidth: 1))
                .foregroundColor(Brand.accentBlue)
            }
            .buttonStyle(.plain)
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

#Preview {
    OverviewView(onNavigate: { _ in })
        .frame(width: 900, height: 640)
        .background(Brand.bgNavy)
        .environment(\.colorScheme, .dark)
}
