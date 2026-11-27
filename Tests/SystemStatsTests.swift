import XCTest
@testable import Moler

final class SystemStatsTests: XCTestCase {

    func testDecodeFullSystemStats() throws {
        let json = """
        {
            "collected_at": "2026-07-15T10:30:00.123Z",
            "cpu": {"usage": 45.2, "load1": 2.5, "load5": 2.1, "load15": 1.8, "core_count": 8},
            "memory": {"used": 8589934592, "total": 17179869184, "used_percent": 50.0, "swap_used": 0, "swap_total": 0, "pressure": "OK"},
            "network": [{"name": "en0", "rx_rate_mbs": 12.5, "tx_rate_mbs": 3.2}],
            "disks": [{"mount": "/", "used": 500000000000, "total": 1000000000000, "used_percent": 50.0}],
            "disk_io": {"read_rate": 150.0, "write_rate": 80.0},
            "hardware": {"cpu_model": "Apple M3 Pro", "total_ram": "16 GB"},
            "uptime_seconds": 86400,
            "health_score": 85,
            "health_score_msg": "Good"
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let stats = try decoder.decode(SystemStats.self, from: json)

        XCTAssertEqual(stats.cpu.usage, 45.2, accuracy: 0.01)
        XCTAssertEqual(stats.cpu.coreCount, 8)
        XCTAssertEqual(stats.memory.used, 8589934592)
        XCTAssertEqual(stats.memory.total, 17179869184)
        XCTAssertEqual(stats.network.count, 1)
        XCTAssertEqual(stats.network[0].name, "en0")
        XCTAssertEqual(stats.network[0].rxRateMbs, 12.5)
        XCTAssertEqual(stats.disks.count, 1)
        XCTAssertEqual(stats.disks[0].mount, "/")
        XCTAssertEqual(stats.diskIO.readRate, 150.0)
        XCTAssertEqual(stats.hardware.cpuModel, "Apple M3 Pro")
        XCTAssertEqual(stats.uptimeSeconds, 86400)
        XCTAssertEqual(stats.healthScore, 85)
        XCTAssertEqual(stats.healthScoreMsg, "Good")
    }

    func testDecodeMinimalStats() throws {
        let json = """
        {
            "collected_at": "2026-07-15T10:30:00.123Z",
            "cpu": {"usage": 10.0, "load1": 0.5, "load5": 0.4, "load15": 0.3, "core_count": 4},
            "memory": {"used": 0, "total": 0, "used_percent": 0, "swap_used": 0, "swap_total": 0, "pressure": ""},
            "hardware": {"cpu_model": "?", "total_ram": "?"},
            "uptime_seconds": 0,
            "health_score": 0
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        let stats = try decoder.decode(SystemStats.self, from: json)

        XCTAssertEqual(stats.network.count, 0) // missing → empty array
        XCTAssertEqual(stats.disks.count, 0)   // missing → empty array
        XCTAssertEqual(stats.diskIO.readRate, 0) // missing → default init()
        XCTAssertEqual(stats.healthScoreMsg, "")
    }

    func testDecodeBadDate() {
        let json = """
        {
            "collected_at": "not-a-date",
            "cpu": {"usage": 0, "load1": 0, "load5": 0, "load15": 0, "core_count": 0},
            "memory": {"used": 0, "total": 0, "used_percent": 0, "swap_used": 0, "swap_total": 0, "pressure": ""},
            "hardware": {"cpu_model": "?", "total_ram": "?"},
            "uptime_seconds": 0,
            "health_score": 0
        }
        """.data(using: .utf8)!

        let decoder = JSONDecoder()
        XCTAssertThrowsError(try decoder.decode(SystemStats.self, from: json))
    }

    func testDiskIOInitDefault() {
        let io = DiskIOStats()
        XCTAssertEqual(io.readRate, 0)
        XCTAssertEqual(io.writeRate, 0)
    }

    // MARK: - Mole 1.74 watch fields

    func testDecodeWatchSnapshotFields() throws {
        let json = """
        {
            "collected_at": "2026-11-27T10:38:19.333539+08:00",
            "cpu": {"usage": 17.8, "load1": 7.9, "load5": 7.8, "load15": 7.8, "core_count": 8},
            "memory": {"used": 13851525120, "total": 17179869184, "used_percent": 80.6, "swap_used": 10749345792, "swap_total": 11811160064, "pressure": "warn"},
            "hardware": {"model": "MacBook Pro", "cpu_model": "Apple M2", "total_ram": "16.0 GB", "disk_size": "460.4 GB", "os_version": "macOS 27.2.1", "refresh_rate": "60Hz"},
            "uptime_seconds": 164519,
            "health_score": 90,
            "health_score_msg": "Excellent",
            "top_processes": [
                {"pid": 456, "ppid": 1, "name": "WindowServer", "command": "WindowServer", "cpu": 44.3, "memory": 0.6, "memory_bytes": 97124352}
            ],
            "bluetooth": [
                {"name": "AirPods", "connected": true, "battery": "Right Battery Level: 1%"}
            ],
            "trash_size": 12345,
            "trash_approx": false,
            "proxy": {"enabled": true, "type": "SOCKS", "host": "127.0.0.1:7890"},
            "zombie_count": 1,
            "disks": [
                {"mount": "/", "used": 376372564134, "total": 494384795648, "used_percent": 76.1, "purgeable": 8080236378, "smart_status": "verified", "external": false, "fstype": "apfs"}
            ]
        }
        """.data(using: .utf8)!

        let stats = try JSONDecoder().decode(SystemStats.self, from: json)

        XCTAssertEqual(stats.topProcesses.count, 1)
        XCTAssertEqual(stats.topProcesses[0].name, "WindowServer")
        XCTAssertEqual(stats.topProcesses[0].cpu, 44.3, accuracy: 0.01)
        XCTAssertEqual(stats.topProcesses[0].memoryBytes, 97_124_352)

        XCTAssertEqual(stats.bluetooth.count, 1)
        XCTAssertTrue(stats.bluetooth[0].connected)
        XCTAssertEqual(stats.bluetooth[0].batteryPercentLabel, "1%")

        XCTAssertEqual(stats.trashSize, 12345)
        XCTAssertEqual(stats.proxy?.host, "127.0.0.1:7890")
        XCTAssertEqual(stats.zombieCount, 1)

        XCTAssertEqual(stats.disks[0].purgeable, 8_080_236_378)
        XCTAssertEqual(stats.disks[0].smartStatus, "verified")
        XCTAssertEqual(stats.disks[0].external, false)
        XCTAssertEqual(stats.disks[0].fstype, "apfs")

        XCTAssertTrue(stats.isComplete)
    }

    func testWarmupSnapshotIsIncomplete() throws {
        let json = """
        {
            "collected_at": "2026-11-27T10:38:19.333539+08:00",
            "cpu": {"usage": 0, "load1": 0, "load5": 0, "load15": 0, "core_count": 8},
            "memory": {"used": 0, "total": 0, "used_percent": 0, "swap_used": 0, "swap_total": 0, "pressure": ""},
            "hardware": {"model": "", "cpu_model": "", "total_ram": "", "disk_size": "", "os_version": "", "refresh_rate": ""},
            "uptime_seconds": 0,
            "health_score": 0,
            "top_processes": null
        }
        """.data(using: .utf8)!

        let stats = try JSONDecoder().decode(SystemStats.self, from: json)
        XCTAssertFalse(stats.isComplete)
        XCTAssertTrue(stats.topProcesses.isEmpty)
        XCTAssertEqual(stats.trashSize, 0)
        XCTAssertNil(stats.proxy)
    }

    func testCPUStatsEquality() {
        let a = CPUStats(usage: 50, load1: 1, load5: 0.8, load15: 0.6, coreCount: 8)
        let b = CPUStats(usage: 50, load1: 1, load5: 0.8, load15: 0.6, coreCount: 8)
        XCTAssertEqual(a.usage, b.usage)
        XCTAssertEqual(a.coreCount, b.coreCount)
    }

    func testISO8601Formatter() {
        let formatter = ISO8601DateFormatter.punk
        let date = formatter.date(from: "2026-07-15T10:30:00.123Z")
        XCTAssertNotNil(date)
    }
}
