import XCTest
@testable import Moler

final class DataModelsTests: XCTestCase {

    // MARK: - ByteUnit

    func testByteUnitTableOrder() {
        let table = ByteUnit.table
        XCTAssertGreaterThan(table[0].multiplier, table[1].multiplier) // TB > GB
        XCTAssertGreaterThan(table[1].multiplier, table[2].multiplier) // GB > MB
        XCTAssertGreaterThan(table[2].multiplier, table[3].multiplier) // MB > KB
        XCTAssertGreaterThan(table[3].multiplier, table[4].multiplier) // KB > B
        XCTAssertEqual(table[4].multiplier, 1)
    }

    func testByteUnitMultipliers() {
        XCTAssertEqual(ByteUnit.table[0].suffix, "TB")
        XCTAssertEqual(ByteUnit.table[0].multiplier, 1_099_511_627_776)
        XCTAssertEqual(ByteUnit.table[1].multiplier, 1_073_741_824)
        XCTAssertEqual(ByteUnit.table[2].multiplier, 1_048_576)
        XCTAssertEqual(ByteUnit.table[3].multiplier, 1024)
    }

    // MARK: - OptimizeDataModels

    func testOptimizeCategoryInit() {
        let cat = OptimizeCategory(name: "DNS Check", tasks: [
            OptimizeTask(description: "Flush cache", categoryName: "DNS Check", isCompleted: true)
        ])
        XCTAssertEqual(cat.name, "DNS Check")
        XCTAssertEqual(cat.tasks.count, 1)
        XCTAssertEqual(cat.id, "DNS Check")
    }

    func testOptimizeCategoryEmptyTasks() {
        let cat = OptimizeCategory(name: "Empty")
        XCTAssertTrue(cat.tasks.isEmpty)
    }

    func testOptimizeTaskInit() {
        let task = OptimizeTask(description: "Flush DNS cache", categoryName: "DNS", isCompleted: false)
        XCTAssertEqual(task.description, "Flush DNS cache")
        XCTAssertEqual(task.categoryName, "DNS")
        XCTAssertFalse(task.isCompleted)
        XCTAssertFalse(task.id.isEmpty)
    }

    func testOptimizeTaskIDStability() {
        let a = OptimizeTask(description: "Task", categoryName: "Cat", isCompleted: false)
        let b = OptimizeTask(description: "Task", categoryName: "Cat", isCompleted: true)
        XCTAssertEqual(a.id, b.id) // ID based on description::categoryName
    }

    func testOptimizeProgressInit() {
        let p = OptimizeProgress(
            categories: [],
            currentCategory: "DNS",
            currentTask: "Flush",
            completedCategories: 0,
            totalCategories: 5,
            isDryRun: true,
            elapsedSeconds: 30,
            diagnosisItems: ["Bottleneck"]
        )
        XCTAssertEqual(p.currentCategory, "DNS")
        XCTAssertEqual(p.totalCategories, 5)
        XCTAssertTrue(p.isDryRun)
        XCTAssertEqual(p.diagnosisItems.count, 1)
    }

    func testOptimizeResultInit() {
        let r = OptimizeResult(
            categories: [],
            totalOptimizations: 10,
            isDryRun: true,
            durationSeconds: 45,
            timestamp: Date()
        )
        XCTAssertEqual(r.totalOptimizations, 10)
        XCTAssertTrue(r.isDryRun)
        XCTAssertEqual(r.durationSeconds, 45)
    }

    // MARK: - OptimizeState

    func testOptimizeStateEqualityIdle() {
        XCTAssertEqual(OptimizeState.idle, OptimizeState.idle)
    }

    func testOptimizeStateEqualityError() {
        XCTAssertEqual(OptimizeState.error("a"), OptimizeState.error("a"))
        XCTAssertNotEqual(OptimizeState.error("a"), OptimizeState.error("b"))
    }

    // MARK: - SoftwareDataModels

    func testInstalledAppInit() {
        let app = InstalledApp(
            id: "com.test|/App.app",
            name: "TestApp",
            bundleId: "com.test",
            source: "App Store",
            uninstallName: "testapp",
            path: "/Applications/TestApp.app",
            sizeStr: "100MB",
            sizeBytes: 104_857_600
        )
        XCTAssertEqual(app.name, "TestApp")
        XCTAssertEqual(app.bundleId, "com.test")
        XCTAssertEqual(app.sizeBytes, 104_857_600)
    }

    func testUninstallPreviewEmpty() {
        let preview = UninstallPreview(entries: [])
        XCTAssertTrue(preview.isEmpty)
    }

    func testUninstallPreviewNotEmpty() {
        let preview = UninstallPreview(entries: [
            UninstallPreview.Entry(path: "/test.app", kind: .application)
        ])
        XCTAssertFalse(preview.isEmpty)
    }

    func testUninstallResultInit() {
        let r = UninstallResult(
            appNames: ["App1"],
            filesRemoved: 1,
            bytesFreed: 1024,
            failedAppNames: [],
            durationSeconds: 10,
            timestamp: Date()
        )
        XCTAssertEqual(r.filesRemoved, 1)
        XCTAssertEqual(r.bytesFreed, 1024)
        XCTAssertTrue(r.failedAppNames.isEmpty)
    }

    // MARK: - CleanState

    func testCleanStateEqualityIdle() {
        XCTAssertEqual(CleanState.idle, CleanState.idle)
    }

    func testCleanStateEqualityDone() {
        XCTAssertEqual(CleanState.done(freedBytes: 100, filesRemoved: 5),
                       CleanState.done(freedBytes: 100, filesRemoved: 5))
        XCTAssertNotEqual(CleanState.done(freedBytes: 100, filesRemoved: 5),
                          CleanState.done(freedBytes: 200, filesRemoved: 5))
    }

    func testScanProgressInit() {
        let p = ScanProgress(currentItem: 5, totalItems: 100, currentPath: "/test", elapsedSeconds: 30, scannedBytes: 1024)
        XCTAssertEqual(p.currentItem, 5)
        XCTAssertEqual(p.totalItems, 100)
        XCTAssertEqual(p.scannedBytes, 1024)
    }

    // MARK: - PurgeEntry

    func testPurgeEntryInit() {
        let e = PurgeEntry(id: "xcode", name: "DerivedData", path: "~/Library/Developer/Xcode/DerivedData", size: 1_000_000, category: "Project Artifacts")
        XCTAssertEqual(e.name, "DerivedData")
        XCTAssertEqual(e.size, 1_000_000)
        XCTAssertEqual(e.category, "Project Artifacts")
    }

    // MARK: - PurgeState

    func testPurgeStateEquality() {
        XCTAssertEqual(PurgeState.idle, PurgeState.idle)
        XCTAssertEqual(PurgeState.done(freedBytes: 100, itemsRemoved: 5, itemsFailed: 0),
                       PurgeState.done(freedBytes: 100, itemsRemoved: 5, itemsFailed: 0))
    }

    // MARK: - SoftwareState

    func testSoftwareStateEquality() {
        XCTAssertEqual(SoftwareState.idle, SoftwareState.idle)
        XCTAssertEqual(SoftwareState.loaded, SoftwareState.loaded)
        XCTAssertNotEqual(SoftwareState.loading, SoftwareState.loaded)
    }
}
