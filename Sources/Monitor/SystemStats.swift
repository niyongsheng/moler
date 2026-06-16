import Foundation

// MARK: - System Stats

struct SystemStats: Codable {
    let collectedAt: Date
    let cpu: CPUStats
    let memory: MemoryStats
    let network: [NetworkStats]
    let disks: [DiskStats]
    let diskIO: DiskIOStats
    let hardware: HardwareInfo
    let uptimeSeconds: Int
    let healthScore: Int
    let healthScoreMsg: String

    enum CodingKeys: String, CodingKey {
        case collectedAt = "collected_at"
        case cpu, memory, network, disks
        case diskIO = "disk_io"
        case hardware
        case uptimeSeconds = "uptime_seconds"
        case healthScore = "health_score"
        case healthScoreMsg = "health_score_msg"
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let dateStr = try c.decode(String.self, forKey: .collectedAt)
        guard let date = ISO8601DateFormatter.punk.date(from: dateStr) else {
            throw DecodingError.dataCorruptedError(forKey: .collectedAt, in: c,
                debugDescription: "Bad ISO8601: '\(dateStr)'")
        }
        collectedAt = date
        cpu = try c.decode(CPUStats.self, forKey: .cpu)
        memory = try c.decode(MemoryStats.self, forKey: .memory)
        network = try c.decodeIfPresent([NetworkStats].self, forKey: .network) ?? []
        disks = try c.decodeIfPresent([DiskStats].self, forKey: .disks) ?? []
        diskIO = try c.decodeIfPresent(DiskIOStats.self, forKey: .diskIO) ?? DiskIOStats()
        hardware = try c.decode(HardwareInfo.self, forKey: .hardware)
        uptimeSeconds = try c.decode(Int.self, forKey: .uptimeSeconds)
        healthScore = try c.decode(Int.self, forKey: .healthScore)
        healthScoreMsg = try c.decodeIfPresent(String.self, forKey: .healthScoreMsg) ?? ""
    }
}

// MARK: - CPU

struct CPUStats: Codable {
    let usage: Double
    let load1: Double
    let load5: Double
    let load15: Double
    let coreCount: Int

    enum CodingKeys: String, CodingKey {
        case usage, load1, load5, load15
        case coreCount = "core_count"
    }
}

// MARK: - Memory

struct MemoryStats: Codable {
    let used: UInt64
    let total: UInt64
    let usedPercent: Double
    let swapUsed: UInt64
    let swapTotal: UInt64
    let pressure: String

    enum CodingKeys: String, CodingKey {
        case used, total
        case usedPercent = "used_percent"
        case swapUsed = "swap_used"
        case swapTotal = "swap_total"
        case pressure
    }
}

// MARK: - Network

struct NetworkStats: Codable {
    let name: String
    let rxRateMbs: Double?
    let txRateMbs: Double?

    enum CodingKeys: String, CodingKey {
        case name
        case rxRateMbs = "rx_rate_mbs"
        case txRateMbs = "tx_rate_mbs"
    }
}

// MARK: - Disk I/O

struct DiskIOStats: Codable {
    let readRate: Double
    let writeRate: Double

    enum CodingKeys: String, CodingKey {
        case readRate = "read_rate"
        case writeRate = "write_rate"
    }

    init() { readRate = 0; writeRate = 0 }
}

// MARK: - Disk

struct DiskStats: Codable {
    let mount: String
    let used: UInt64
    let total: UInt64
    let usedPercent: Double

    enum CodingKeys: String, CodingKey {
        case mount, used, total
        case usedPercent = "used_percent"
    }
}

// MARK: - Hardware

struct HardwareInfo: Codable {
    let cpuModel: String
    let totalRam: String

    enum CodingKeys: String, CodingKey {
        case cpuModel = "cpu_model"
        case totalRam = "total_ram"
    }
}

// MARK: - Date Formatter

extension ISO8601DateFormatter {
    static let punk: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()
}
