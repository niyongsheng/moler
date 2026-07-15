import XCTest
@testable import Moler
import SwiftUI
import AppKit

final class AnalyzeDataModelsTests: XCTestCase {

    // MARK: - treemapColor - Directories

    func testTreemapColorForDirectory() {
        let entry = DiskScanEntry(id: "/test/folder", name: "folder", path: "/test/folder", size: 100, isDir: true)
        let color = treemapColor(for: entry)

        // Directories should produce a warm/orange color
        var h: CGFloat = 0, s: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(color).getHue(&h, saturation: &s, brightness: &b, alpha: &a)

        // Warm hues are in the orange range (~0.03-0.12)
        XCTAssertGreaterThan(s, 0.3, "Directory color should be saturated")
        XCTAssertGreaterThan(b, 0.3, "Directory color should be bright")
    }

    func testTreemapColorForDirectoryDeterministic() {
        let entry = DiskScanEntry(id: "/test/folder", name: "MyFolder", path: "/test/folder", size: 100, isDir: true)
        let color1 = treemapColor(for: entry)
        let color2 = treemapColor(for: entry)
        XCTAssertEqual(NSColor(color1), NSColor(color2))
    }

    // MARK: - treemapColor - Archive Extensions

    func testTreemapColorForZip() {
        let entry = DiskScanEntry(id: "/a.zip", name: "a.zip", path: "/a.zip", size: 100, isDir: false)
        let color = treemapColor(for: entry)
        // Zip should get accentGold
        XCTAssertEqual(NSColor(color), NSColor(Brand.accentGold))
    }

    func testTreemapColorForTar() {
        let entry = DiskScanEntry(id: "/a.tar.gz", name: "a.tar.gz", path: "/a.tar.gz", size: 100, isDir: false)
        let color = treemapColor(for: entry)
        XCTAssertEqual(NSColor(color), NSColor(Brand.accentGold))
    }

    // MARK: - treemapColor - Media Extensions

    func testTreemapColorForVideo() {
        let entry = DiskScanEntry(id: "/v.mp4", name: "v.mp4", path: "/v.mp4", size: 100, isDir: false)
        let color = treemapColor(for: entry)
        // Should be purple-ish
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertGreaterThan(b, r) // Blue-dominant
        XCTAssertGreaterThan(b, g)
    }

    func testTreemapColorForAudio() {
        let entry = DiskScanEntry(id: "/s.mp3", name: "s.mp3", path: "/s.mp3", size: 100, isDir: false)
        let color = treemapColor(for: entry)
        // Should be pink → red-dominant
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertGreaterThan(r, g)
        XCTAssertGreaterThan(b, g)
    }

    func testTreemapColorForImage() {
        let entry = DiskScanEntry(id: "/i.png", name: "i.png", path: "/i.png", size: 100, isDir: false)
        let color = treemapColor(for: entry)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertGreaterThan(g, r) // Green-dominant (emerald)
    }

    func testTreemapColorForImageJPG() {
        let entry = DiskScanEntry(id: "/i.jpg", name: "i.jpg", path: "/i.jpg", size: 100, isDir: false)
        let color = treemapColor(for: entry)
        let color2 = treemapColor(for: DiskScanEntry(id: "/i.jpeg", name: "i.jpeg", path: "/i.jpeg", size: 100, isDir: false))
        XCTAssertEqual(NSColor(color), NSColor(color2))
    }

    // MARK: - treemapColor - Document Extensions

    func testTreemapColorForPDF() {
        let entry = DiskScanEntry(id: "/d.pdf", name: "d.pdf", path: "/d.pdf", size: 100, isDir: false)
        let color = treemapColor(for: entry)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertGreaterThan(b, r) // Blue-dominant (sky blue)
        XCTAssertGreaterThan(b, g)
    }

    func testTreemapColorForCode() {
        let entry = DiskScanEntry(id: "/main.swift", name: "main.swift", path: "/main.swift", size: 100, isDir: false)
        let color = treemapColor(for: entry)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        XCTAssertGreaterThan(b, r) // Blue-dominant (light blue)
        XCTAssertGreaterThan(b, g)
    }

    // MARK: - treemapColor - Fallback

    func testTreemapColorForUnknownExtension() {
        let entry = DiskScanEntry(id: "/f.xyz", name: "f.xyz", path: "/f.xyz", size: 100, isDir: false)
        let color = treemapColor(for: entry)
        // Should not crash and produce a non-clear color
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        let isNonZero = r > 0 || g > 0 || b > 0
        XCTAssertTrue(isNonZero, "Fallback color should not be black")
    }

    func testTreemapColorDeterministicForUnknown() {
        let entry1 = DiskScanEntry(id: "/f1.xyz", name: "file1", path: "/f1.xyz", size: 100, isDir: false)
        let entry2 = DiskScanEntry(id: "/f1.xyz", name: "file1", path: "/f1.xyz", size: 100, isDir: false)
        // Same entry should produce same color
        XCTAssertEqual(NSColor(treemapColor(for: entry1)), NSColor(treemapColor(for: entry2)))
    }

    // MARK: - ScanPreset & BreadcrumbItem

    func testScanPresetIdentity() {
        let preset = ScanPreset(id: "house", label: "Home", path: "/Users/test")
        XCTAssertEqual(preset.id, "house")
        XCTAssertEqual(preset.label, "Home")
        XCTAssertEqual(preset.path, "/Users/test")
    }

    func testBreadcrumbItemEquality() {
        let a = BreadcrumbItem(id: "/a", name: "A")
        let b = BreadcrumbItem(id: "/a", name: "A")
        XCTAssertEqual(a, b)
    }

    // MARK: - AnalyzeProgress

    func testAnalyzeProgress() {
        let p = AnalyzeProgress(currentPath: "/test", elapsedSeconds: 42)
        XCTAssertEqual(p.currentPath, "/test")
        XCTAssertEqual(p.elapsedSeconds, 42)
    }

    // MARK: - MoEngine availability

    func testMoleAvailabilityEquality() {
        XCTAssertEqual(MoleAvailability.installed(path: "/a"), MoleAvailability.installed(path: "/a"))
        XCTAssertNotEqual(MoleAvailability.installed(path: "/a"), MoleAvailability.installed(path: "/b"))
        XCTAssertEqual(MoleAvailability.missing, MoleAvailability.missing)
    }
}
