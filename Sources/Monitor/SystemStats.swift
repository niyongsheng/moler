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
    let thermal: ThermalStats?
    let batteries: [BatteryStats]

    enum CodingKeys: String, CodingKey {
        case collectedAt = "collected_at"
        case cpu, memory, network, disks
        case diskIO = "disk_io"
        case hardware
        case uptimeSeconds = "uptime_seconds"
        case healthScore = "health_score"
        case healthScoreMsg = "health_score_msg"
        case thermal
        case batteries
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
        thermal = try c.decodeIfPresent(ThermalStats.self, forKey: .thermal)
        batteries = try c.decodeIfPresent([BatteryStats].self, forKey: .batteries) ?? []
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

// MARK: - Thermal

struct ThermalStats: Codable {
    let cpuTemp: Double
    let gpuTemp: Double
    let batteryTemp: Double
    let fanSpeed: Double
    let fanCount: Int
    let systemPower: Double
    let adapterPower: Double
    let batteryPower: Double

    enum CodingKeys: String, CodingKey {
        case cpuTemp = "cpu_temp"
        case gpuTemp = "gpu_temp"
        case batteryTemp = "battery_temp"
        case fanSpeed = "fan_speed"
        case fanCount = "fan_count"
        case systemPower = "system_power"
        case adapterPower = "adapter_power"
        case batteryPower = "battery_power"
    }
}

// MARK: - Battery

struct BatteryStats: Codable {
    let percent: Int
    let status: String
    let timeLeft: String
    let health: String
    let cycleCount: Int
    let capacity: Int

    enum CodingKeys: String, CodingKey {
        case percent, status, health, capacity
        case timeLeft = "time_left"
        case cycleCount = "cycle_count"
    }
}

extension BatteryStats {
    /// Whether the battery is currently being charged.
    var isCharging: Bool { status == "charging" || status == "finishing charge" }
    /// Whether the battery is fully charged.
    var isCharged: Bool { status == "charged" }
    /// Whether the battery is discharging (on battery power).
    var isDischarging: Bool { status == "discharging" }
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
