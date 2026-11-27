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
    /// Present from Mole 1.71+; a `--watch` warm-up snapshot may omit these.
    let topProcesses: [ProcessStats]
    let bluetooth: [BluetoothDevice]
    let trashSize: UInt64
    let proxy: ProxyInfo?
    let zombieCount: Int

    /// The first `--watch` snapshot is a warm-up with empty hardware,
    /// pressure, and process fields. Do not publish it.
    var isComplete: Bool {
        // The warm-up snapshot has every hardware field empty. Do not also
        // require `memory.pressure`: it regressed to an empty string in some
        // Mole 1.68–1.70 releases, which would otherwise hide every snapshot.
        !hardware.cpuModel.isEmpty || !hardware.totalRam.isEmpty
    }

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
        case topProcesses = "top_processes"
        case bluetooth
        case trashSize = "trash_size"
        case proxy
        case zombieCount = "zombie_count"
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
        topProcesses = try c.decodeIfPresent([ProcessStats].self, forKey: .topProcesses) ?? []
        bluetooth = try c.decodeIfPresent([BluetoothDevice].self, forKey: .bluetooth) ?? []
        trashSize = try c.decodeIfPresent(UInt64.self, forKey: .trashSize) ?? 0
        proxy = try c.decodeIfPresent(ProxyInfo.self, forKey: .proxy)
        zombieCount = try c.decodeIfPresent(Int.self, forKey: .zombieCount) ?? 0
    }
}

// MARK: - Processes

struct ProcessStats: Codable, Identifiable, Equatable {
    let pid: Int
    let name: String
    let command: String
    let cpu: Double
    let memory: Double
    let memoryBytes: UInt64

    var id: Int { pid }

    enum CodingKeys: String, CodingKey {
        case pid, name, command, cpu, memory
        case memoryBytes = "memory_bytes"
    }
}

// MARK: - Bluetooth

struct BluetoothDevice: Codable, Identifiable, Equatable {
    let name: String
    let connected: Bool
    let battery: String

    var id: String { name }

    /// Mole reports strings like "Right Battery Level: 1%"; keep the percent.
    var batteryPercentLabel: String? {
        guard let range = battery.range(
            of: #"[0-9]{1,3}%"#, options: .regularExpression
        ) else { return nil }
        return String(battery[range])
    }
}

// MARK: - Proxy

struct ProxyInfo: Codable, Equatable {
    let enabled: Bool
    let type: String
    let host: String
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
    let purgeable: UInt64?
    let smartStatus: String?
    let external: Bool?
    let fstype: String?

    enum CodingKeys: String, CodingKey {
        case mount, used, total
        case usedPercent = "used_percent"
        case purgeable
        case smartStatus = "smart_status"
        case external, fstype
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
