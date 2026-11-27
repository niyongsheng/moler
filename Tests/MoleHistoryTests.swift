import XCTest
@testable import Moler

final class MoleHistoryTests: XCTestCase {

    private let sample = """
    {
        "logs": {"operations": "/tmp/operations.log", "deletions": "/tmp/deletions.log"},
        "limit": 20,
        "sessions": [
            {
                "command": "clean-dry-run",
                "run_id": "20261127103412-7989",
                "started_at": "2026-11-27 10:34:12",
                "ended_at": "2026-11-27 10:35:11",
                "items": 601,
                "size": "5.97GB",
                "operation_count": 106,
                "failed_tasks": 0,
                "actions": {"removed": 0, "trashed": 0, "skipped": 106, "failed": 0, "rebuilt": 0, "other": 0}
            },
            {
                "command": "clean",
                "run_id": "20261126120000-1234",
                "started_at": "2026-11-26 12:00:00",
                "ended_at": "2026-11-26 12:00:30",
                "items": 42,
                "size": "1.5GB",
                "operation_count": 10,
                "failed_tasks": 1,
                "actions": {"removed": 40, "trashed": 0, "skipped": 1, "failed": 1, "rebuilt": 0, "other": 0}
            },
            {
                "command": "purge",
                "run_id": "",
                "started_at": "2026-11-25 09:00:00",
                "ended_at": "2026-11-25 09:00:00",
                "items": 0,
                "size": "0B",
                "operation_count": 0,
                "failed_tasks": 0,
                "actions": {"removed": 0, "trashed": 0, "skipped": 0, "failed": 0, "rebuilt": 0, "other": 0}
            },
            {
                "command": "uninstall",
                "run_id": "20261125130151-4447",
                "started_at": "2026-11-25 13:01:51",
                "ended_at": "2026-11-25 13:02:24",
                "items": 1,
                "size": "1.7MB",
                "operation_count": 1,
                "failed_tasks": 0,
                "actions": {"removed": 0, "trashed": 1, "skipped": 0, "failed": 0, "rebuilt": 0, "other": 0}
            }
        ],
        "deletions": []
    }
    """.data(using: .utf8)!

    func testParseFiltersDryRunsAndNoOps() throws {
        let sessions = try MoleHistoryLoader.parse(sample)
        XCTAssertEqual(sessions.count, 2)
        XCTAssertEqual(sessions.map(\.command), ["clean", "uninstall"])
    }

    func testDisplayCommand() throws {
        let sessions = try MoleHistoryLoader.parse(sample)
        XCTAssertEqual(sessions[0].displayCommand, "CLEAN")
        XCTAssertEqual(sessions[1].displayCommand, "UNINSTALL")
    }

    func testFieldsAndDate() throws {
        let sessions = try MoleHistoryLoader.parse(sample)
        let clean = sessions[0]

        XCTAssertEqual(clean.items, 42)
        XCTAssertEqual(clean.size, "1.5GB")
        XCTAssertEqual(clean.operationCount, 10)
        XCTAssertEqual(clean.failedTasks, 1)
        XCTAssertNotNil(clean.startedDate)
        XCTAssertFalse(clean.isDryRun)
    }

    func testMissingOptionalFieldsStillDecode() throws {
        let json = """
        {
            "sessions": [
                {
                    "command": "optimize",
                    "run_id": "r1",
                    "started_at": "2026-11-27 10:00:00",
                    "ended_at": "2026-11-27 10:00:04",
                    "items": 2,
                    "size": "0B"
                }
            ]
        }
        """.data(using: .utf8)!

        let sessions = try MoleHistoryLoader.parse(json)
        XCTAssertEqual(sessions.count, 1)
        XCTAssertNil(sessions[0].operationCount)
        XCTAssertNil(sessions[0].failedTasks)
        XCTAssertNil(sessions[0].actions)
    }
}
