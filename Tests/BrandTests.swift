import XCTest
@testable import Moler
import SwiftUI
import AppKit

final class BrandTests: XCTestCase {

    // MARK: - Color hex parsing

    func testHexColor6Digit() {
        let color = Color(hex: "#e06236")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)

        XCTAssertEqual(r, 0.878, accuracy: 0.01)  // 0xe0 / 255
        XCTAssertEqual(g, 0.384, accuracy: 0.01)  // 0x62 / 255
        XCTAssertEqual(b, 0.212, accuracy: 0.01)  // 0x36 / 255
        XCTAssertEqual(a, 1.0)
    }

    func testHexColor8Digit() {
        // Code uses RRGGBBAA order (not ARGB). #e0623680 → R=0xe0, G=0x62, B=0x36, A=0x80
        let color = Color(hex: "#e0623680")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)

        XCTAssertEqual(r, 0.878, accuracy: 0.01)  // 0xe0 / 255
        XCTAssertEqual(g, 0.384, accuracy: 0.01)  // 0x62 / 255
        XCTAssertEqual(b, 0.212, accuracy: 0.01)  // 0x36 / 255
        XCTAssertEqual(a, 0.502, accuracy: 0.01)  // 0x80 / 255 ≈ 0.5
    }

    func testHexColorBlack() {
        let color = Color(hex: "#000000")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)

        XCTAssertEqual(r, 0)
        XCTAssertEqual(g, 0)
        XCTAssertEqual(b, 0)
    }

    func testHexColorWhite() {
        let color = Color(hex: "#ffffff")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)

        XCTAssertEqual(r, 1.0, accuracy: 0.01)
        XCTAssertEqual(g, 1.0, accuracy: 0.01)
        XCTAssertEqual(b, 1.0, accuracy: 0.01)
    }

    func testHexColorNoHash() {
        let color = Color(hex: "e06236")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)

        XCTAssertEqual(r, 0.878, accuracy: 0.01)
        XCTAssertEqual(g, 0.384, accuracy: 0.01)
        XCTAssertEqual(b, 0.212, accuracy: 0.01)
    }

    func testHexColorInvalid() {
        let color = Color(hex: "xyz")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)

        // Invalid hex falls back to black
        XCTAssertEqual(r, 0)
        XCTAssertEqual(g, 0)
        XCTAssertEqual(b, 0)
    }

    func testHexColorShort() {
        // 3-char hex is not handled → falls to default (black)
        let color = Color(hex: "#fff")
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        NSColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)

        XCTAssertEqual(r, 0)
        XCTAssertEqual(g, 0)
        XCTAssertEqual(b, 0)
    }

    // MARK: - Brand constants (compile-time verification)

    func testBrandBackgroundColorsExist() {
        // Simply verifying these don't crash on init
        _ = Brand.bgNavy
        _ = Brand.bgCard
        _ = Brand.bgElevated
    }

    func testBrandAccentColorsExist() {
        _ = Brand.accentOrange
        _ = Brand.accentGold
        _ = Brand.accentRed
        _ = Brand.accentBlue
    }

    func testBrandTextColorsExist() {
        _ = Brand.lineColor
        _ = Brand.textPrimary
        _ = Brand.textDim
    }

    func testBrandFontNames() {
        XCTAssertEqual(Brand.titleFont, "Jura-Bold")
        XCTAssertEqual(Brand.bodyFont, "Jura-Medium")
        XCTAssertEqual(Brand.lightFont, "Jura-Light")
        XCTAssertEqual(Brand.monoFont, "RobotoMono-Regular")
        XCTAssertEqual(Brand.monoLight, "RobotoMono-Light")
    }

    func testBrandSpacing() {
        XCTAssertEqual(Brand.unit, 4)
        XCTAssertEqual(Brand.margin, 16)
        XCTAssertEqual(Brand.marginTight, 8)
        XCTAssertEqual(Brand.serifWidth, 4)
    }
}
