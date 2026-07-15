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
