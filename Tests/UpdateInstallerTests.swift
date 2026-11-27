import XCTest
@testable import Moler

final class UpdateInstallerTests: XCTestCase {

    private var root: URL!

    override func setUpWithError() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("MolerInstallerTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: root)
    }

    // MARK: - Fixtures

    /// Build and ad-hoc sign a minimal app bundle that codesign can verify.
    @discardableResult
    private func makeApp(at url: URL, version: String, identifier: String) throws -> URL {
        let contents = url.appendingPathComponent("Contents", isDirectory: true)
        let macOS = contents.appendingPathComponent("MacOS", isDirectory: true)
        let resources = contents.appendingPathComponent("Resources", isDirectory: true)
        try FileManager.default.createDirectory(at: macOS, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: resources, withIntermediateDirectories: true)

        let plist: [String: Any] = [
            "CFBundleIdentifier": identifier,
            "CFBundleShortVersionString": version,
            "CFBundleExecutable": "Moler",
            "CFBundlePackageType": "APPL",
            "CFBundleName": "Moler",
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist, format: .xml, options: 0
        )
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        try FileManager.default.copyItem(
            at: URL(fileURLWithPath: "/usr/bin/true"),
            to: macOS.appendingPathComponent("Moler")
        )
        try Data("ok".utf8).write(to: resources.appendingPathComponent("marker.txt"))

        try run("/usr/bin/codesign", ["--force", "--sign", "-", url.path])
        return url
    }

    /// Mirror CI: run ditto from `base` with a relative source path.
    private func zip(_ app: URL, from base: URL, relativePath: String, to zipURL: URL) throws {
        try run(
            "/usr/bin/ditto",
            ["-c", "-k", "--sequesterRsrc", "--keepParent", relativePath, zipURL.path],
            currentDirectory: base
        )
    }

    private func makeWorkDirectory() throws -> URL {
        let work = root.appendingPathComponent("work-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
        return work
    }

    @discardableResult
    private func run(
        _ tool: String,
        _ arguments: [String],
        currentDirectory: URL? = nil
    ) throws -> String {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: tool)
        process.arguments = arguments
        if let currentDirectory { process.currentDirectoryURL = currentDirectory }
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        process.waitUntilExit()
        let out = String(
            data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8
        ) ?? ""
        guard process.terminationStatus == 0 else {
            XCTFail("\(tool) failed: \(out)")
            throw NSError(domain: "UpdateInstallerTests", code: Int(process.terminationStatus))
        }
        return out
    }

    // MARK: - Stage

    func testStageAcceptsAppAtArchiveRoot() throws {
        let app = try makeApp(
            at: root.appendingPathComponent("Moler.app"),
            version: "1.2.3",
            identifier: "test.moler.app"
        )
        let zipURL = root.appendingPathComponent("root.zip")
        try zip(app, from: root, relativePath: "Moler.app", to: zipURL)

        let staged = try UpdateInstaller.stage(
            zip: zipURL,
            in: try makeWorkDirectory(),
            expectedVersion: "1.2.3",
            expectedBundleIdentifier: "test.moler.app"
        )
        XCTAssertEqual(staged.lastPathComponent, "Moler.app")
        XCTAssertEqual(Bundle(url: staged)?.bundleIdentifier, "test.moler.app")
    }

    func testStageFindsAppNestedUnderLegacyBuildPath() throws {
        let releaseDir = root
            .appendingPathComponent(".build")
            .appendingPathComponent("Build")
            .appendingPathComponent("Products")
            .appendingPathComponent("Release")
        let app = try makeApp(
            at: releaseDir.appendingPathComponent("Moler.app"),
            version: "2.0.0",
            identifier: "test.moler.app"
        )
        let relative = ".build/Build/Products/Release/Moler.app"
        let zipURL = root.appendingPathComponent("legacy.zip")
        try zip(app, from: root, relativePath: relative, to: zipURL)

        let staged = try UpdateInstaller.stage(
            zip: zipURL,
            in: try makeWorkDirectory(),
            expectedVersion: "2.0.0",
            expectedBundleIdentifier: "test.moler.app"
        )
        XCTAssertEqual(Bundle(url: staged)?.bundleIdentifier, "test.moler.app")
        XCTAssertEqual(
            Bundle(url: staged)?.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            "2.0.0"
        )
    }

    func testStageRejectsWrongVersion() throws {
        let app = try makeApp(
            at: root.appendingPathComponent("Moler.app"),
            version: "1.2.3",
            identifier: "test.moler.app"
        )
        let zipURL = root.appendingPathComponent("wrong-version.zip")
        try zip(app, from: root, relativePath: "Moler.app", to: zipURL)

        XCTAssertThrowsError(
            try UpdateInstaller.stage(
                zip: zipURL,
                in: try makeWorkDirectory(),
                expectedVersion: "9.9.9",
                expectedBundleIdentifier: "test.moler.app"
            )
        ) { error in
            guard case UpdateInstaller.InstallError.versionMismatch = error else {
                return XCTFail("Expected versionMismatch, got \(error)")
            }
        }
    }

    func testStageRejectsWrongBundleIdentifier() throws {
        let app = try makeApp(
            at: root.appendingPathComponent("Moler.app"),
            version: "1.2.3",
            identifier: "com.example.malware"
        )
        let zipURL = root.appendingPathComponent("wrong-id.zip")
        try zip(app, from: root, relativePath: "Moler.app", to: zipURL)

        XCTAssertThrowsError(
            try UpdateInstaller.stage(
                zip: zipURL,
                in: try makeWorkDirectory(),
                expectedVersion: "1.2.3",
                expectedBundleIdentifier: "test.moler.app"
            )
        ) { error in
            guard case UpdateInstaller.InstallError.archiveInvalid = error else {
                return XCTFail("Expected archiveInvalid, got \(error)")
            }
        }
    }

    func testStageRejectsBrokenArchive() throws {
        let zipURL = root.appendingPathComponent("garbage.zip")
        try Data("not a zip".utf8).write(to: zipURL)

        XCTAssertThrowsError(
            try UpdateInstaller.stage(
                zip: zipURL,
                in: try makeWorkDirectory(),
                expectedVersion: "1.0.0",
                expectedBundleIdentifier: "test.moler.app"
            )
        )
    }
}
