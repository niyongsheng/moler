import XCTest
@testable import Moler

final class SoftwareUninstallParserTests: XCTestCase {

    // MARK: - parseAppListJSON

    func testParseAppListValid() {
        let json = """
        [
            {"name": "Slack", "path": "/Applications/Slack.app", "bundle_id": "com.slack.Slack",
             "source": "App Store", "uninstall_name": "Slack", "size": "239.6MB"},
            {"name": "Firefox", "path": "/Applications/Firefox.app", "bundle_id": "org.mozilla.firefox",
             "source": "Web", "uninstall_name": "firefox", "size": "1.08GB"}
        ]
        """.data(using: .utf8)!

        let apps = SoftwareUninstallParser.parseAppListJSON(json)
        XCTAssertEqual(apps.count, 2)

        XCTAssertEqual(apps[0].name, "Slack")
        XCTAssertEqual(apps[0].bundleId, "com.slack.Slack")
        XCTAssertEqual(apps[0].source, "App Store")
        XCTAssertEqual(apps[0].uninstallName, "Slack")
        XCTAssertEqual(apps[0].sizeStr, "239.6MB")
        // Double(239.6) * 1_048_576 → Int64 → 251_238_809
        XCTAssertEqual(apps[0].sizeBytes, 251_238_809)

        XCTAssertEqual(apps[1].name, "Firefox")
        // Double(1.08) * 1_073_741_824 → Int64 truncates → 1_159_641_169
        XCTAssertEqual(apps[1].sizeBytes, 1_159_641_169)
    }

    func testParseAppListEmptyArray() {
        let data = "[]".data(using: .utf8)!
        let apps = SoftwareUninstallParser.parseAppListJSON(data)
        XCTAssertTrue(apps.isEmpty)
    }

    func testParseAppListNotArray() {
        let data = "{}".data(using: .utf8)!
        let apps = SoftwareUninstallParser.parseAppListJSON(data)
        XCTAssertTrue(apps.isEmpty)
    }

    func testParseAppListMissingRequiredFields() {
        let json = """
        [
            {"name": "App1", "path": "/App1.app"},
            {"path": "/NoName.app"},
            {"name": "NoPath"}
        ]
        """.data(using: .utf8)!

        let apps = SoftwareUninstallParser.parseAppListJSON(json)
        XCTAssertEqual(apps.count, 1) // Only the first entry has both name+path
        XCTAssertEqual(apps[0].name, "App1")
    }

    func testParseAppListEmptySize() {
        let json = """
        [
            {"name": "App", "path": "/App.app", "size": "--"}
        ]
        """.data(using: .utf8)!

        let apps = SoftwareUninstallParser.parseAppListJSON(json)
        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps[0].sizeStr, "--")
        XCTAssertEqual(apps[0].sizeBytes, 0)
    }

    func testParseAppListMissingOptionalFields() {
        let json = """
        [
            {"name": "App", "path": "/App.app"}
        ]
        """.data(using: .utf8)!

        let apps = SoftwareUninstallParser.parseAppListJSON(json)
        XCTAssertEqual(apps.count, 1)
        XCTAssertEqual(apps[0].bundleId, "")
        XCTAssertEqual(apps[0].sizeStr, "--")
        XCTAssertEqual(apps[0].sizeBytes, 0)
    }

    // MARK: - parseDryRunOutput

    func testParseDryRunSimple() {
        let text = """
        Files to be removed:

        ◎ Slack , 239.6MB
          ✓ /Applications/Slack.app
          ✓ ~/Library/Containers/com.slack.Slack/
        """

        let preview = SoftwareUninstallParser.parseDryRunOutput(text)
        XCTAssertEqual(preview.entries.count, 2)
        XCTAssertEqual(preview.entries[0].path, "/Applications/Slack.app")
        XCTAssertEqual(preview.entries[1].path, "~/Library/Containers/com.slack.Slack/")
    }

    func testParseDryRunIgnoresNoFileLines() {
        let text = """
        Some header text

        Files to be removed:

        ◎ App , 100MB
          ✓ /Applications/App.app
        Some trailing text
        """

        let preview = SoftwareUninstallParser.parseDryRunOutput(text)
        XCTAssertEqual(preview.entries.count, 1)
    }

    func testParseDryRunEmpty() {
        let text = ""
        let preview = SoftwareUninstallParser.parseDryRunOutput(text)
        XCTAssertTrue(preview.isEmpty)
    }

    func testParseDryRunNoFileList() {
        let text = "Just some random output without file list"
        let preview = SoftwareUninstallParser.parseDryRunOutput(text)
        XCTAssertTrue(preview.isEmpty)
    }

    // MARK: - classify

    func testClassifyApplication() {
        let kind = SoftwareUninstallParser.classify("/Applications/Slack.app")
        XCTAssertEqual(kind, .application)
    }

    func testClassifyContainer() {
        let kind = SoftwareUninstallParser.classify("/Users/test/Library/Containers/com.slack.Slack/")
        XCTAssertEqual(kind, .container)
    }

    func testClassifyGroupContainer() {
        let kind = SoftwareUninstallParser.classify("/Users/test/Library/Group Containers/ABCDE.com.slack/")
        XCTAssertEqual(kind, .groupContainer)
    }

    func testClassifyAppSupport() {
        let kind = SoftwareUninstallParser.classify("/Users/test/Library/Application Support/Slack/")
        XCTAssertEqual(kind, .appSupport)
    }

    func testClassifyPreferences() {
        let kind = SoftwareUninstallParser.classify("/Users/test/Library/Preferences/com.slack.Slack.plist")
        XCTAssertEqual(kind, .preferences)
    }

    func testClassifyLoginItem() {
        let kind = SoftwareUninstallParser.classify("/Users/test/Library/LaunchAgents/com.slack.helper.plist")
        XCTAssertEqual(kind, .loginItem)
    }

    func testClassifyCache() {
        let kind = SoftwareUninstallParser.classify("/Users/test/Library/Caches/com.slack.Slack/")
        XCTAssertEqual(kind, .cache)
    }

    func testClassifyCacheVar() {
        let kind = SoftwareUninstallParser.classify("/private/var/folders/abc/com.slack.cache/")
        XCTAssertEqual(kind, .cache)
    }

    func testClassifyLog() {
        let kind = SoftwareUninstallParser.classify("/Users/test/Library/Logs/Slack/")
        XCTAssertEqual(kind, .log)
    }

    func testClassifyHelper() {
        let kind = SoftwareUninstallParser.classify("/Users/test/Library/Application Scripts/com.slack.Slack/")
        XCTAssertEqual(kind, .helper)
    }

    func testClassifyOther() {
        let kind = SoftwareUninstallParser.classify("/Users/test/Downloads/some_file.txt")
        XCTAssertEqual(kind, .other)
    }

    func testClassifyTildePath() {
        let kind = SoftwareUninstallParser.classify("~/Library/Containers/com.slack.Slack/")
        XCTAssertEqual(kind, .container)
    }

    // MARK: - autoSelected property

    func testAutoSelectedApplication() {
        XCTAssertTrue(UninstallPreview.Kind.application.autoSelected)
        XCTAssertTrue(UninstallPreview.Kind.appSupport.autoSelected)
        XCTAssertTrue(UninstallPreview.Kind.preferences.autoSelected)
        XCTAssertTrue(UninstallPreview.Kind.container.autoSelected)
        XCTAssertTrue(UninstallPreview.Kind.helper.autoSelected)
        XCTAssertTrue(UninstallPreview.Kind.loginItem.autoSelected)
    }

    func testNotAutoSelected() {
        XCTAssertFalse(UninstallPreview.Kind.cache.autoSelected)
        XCTAssertFalse(UninstallPreview.Kind.log.autoSelected)
        XCTAssertFalse(UninstallPreview.Kind.groupContainer.autoSelected)
        XCTAssertFalse(UninstallPreview.Kind.other.autoSelected)
    }

    // MARK: - Kind labels

    func testKindLabels() {
        XCTAssertEqual(UninstallPreview.Kind.application.label, "App Bundle")
        XCTAssertEqual(UninstallPreview.Kind.cache.label, "Cache")
        XCTAssertEqual(UninstallPreview.Kind.log.label, "Logs")
        XCTAssertEqual(UninstallPreview.Kind.other.label, "Other Files")
    }
}
