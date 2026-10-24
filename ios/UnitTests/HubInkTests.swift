import XCTest
import SwiftUI
import UIKit
@testable import AkshatOS

/// The retired copper/sage pair was found to be nearly the same ink on a dark ground: both far
/// brighter than a mark should be, almost no chroma, and only 8.9 apart in OKLab — within the range
/// a reader cannot reliably separate, and closer still for red-green colour blindness. The chart was
/// readable only because every series carries a word beside it.
///
/// These assertions are that finding written down. They are not style preferences: changing a series
/// colour without re-validating it should fail here rather than ship a chart whose categories blur
/// together. `testRetiredPairIsRejected` is the negative fixture that proves the checks have teeth.
final class HubInkTests: XCTestCase {
    /// Marks on a dark surface need to sit in this lightness band. Above it they glare and wash out;
    /// below it they sink into the ground.
    private static let markLightness = 0.48...0.67
    /// Below this chroma a colour reads as grey, whatever its hue.
    private static let chromaFloor = 0.10
    /// OKLab distance (scaled by 100) two categories need in normal vision to be told apart.
    private static let separationFloor = 15.0

    private struct Lab {
        let lightness, a, b: Double
        var chroma: Double { (a * a + b * b).squareRoot() }
    }

    private func lab(_ color: Color) -> Lab {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, alpha: CGFloat = 0
        let readable = UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &alpha)
        XCTAssertTrue(readable, "Hub ink must be defined in sRGB so it can be validated")
        let linear = [r, g, b].map { component -> Double in
            let value = Double(component)
            return value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        let long = cbrt(0.4122214708 * linear[0] + 0.5363325363 * linear[1] + 0.0514459929 * linear[2])
        let medium = cbrt(0.2119034982 * linear[0] + 0.6806995451 * linear[1] + 0.1073969566 * linear[2])
        let short = cbrt(0.0883024619 * linear[0] + 0.2817188376 * linear[1] + 0.6299787005 * linear[2])
        return Lab(lightness: 0.2104542553 * long + 0.7936177850 * medium - 0.0040720468 * short,
                   a: 1.9779984951 * long - 2.4285922050 * medium + 0.4505937099 * short,
                   b: 0.0259040371 * long + 0.7827717662 * medium - 0.8086757660 * short)
    }

    private func separation(_ one: Color, _ other: Color) -> Double {
        let first = lab(one), second = lab(other)
        return 100 * ((first.lightness - second.lightness) * (first.lightness - second.lightness)
                      + (first.a - second.a) * (first.a - second.a)
                      + (first.b - second.b) * (first.b - second.b)).squareRoot()
    }

    private let series: [(name: String, color: Color)] = [
        ("recorded", HubInk.seriesRecorded),
        ("above usual", HubInk.seriesAboveUsual),
        ("best", HubInk.seriesBest)
    ]

    func testSeriesSitInTheDarkMarkBand() {
        for entry in series {
            let lightness = lab(entry.color).lightness
            XCTAssertTrue(Self.markLightness.contains(lightness),
                          "\(entry.name) lightness \(lightness) is outside \(Self.markLightness)")
        }
    }

    func testSeriesCarryEnoughChromaToReadAsColour() {
        for entry in series {
            let chroma = lab(entry.color).chroma
            XCTAssertGreaterThanOrEqual(chroma, Self.chromaFloor,
                                        "\(entry.name) chroma \(chroma) reads as grey")
        }
    }

    func testSeriesArePairwiseDistinguishable() {
        for first in series.indices {
            for second in series.indices where second > first {
                let apart = separation(series[first].color, series[second].color)
                XCTAssertGreaterThanOrEqual(apart, Self.separationFloor,
                                            "\(series[first].name) and \(series[second].name) are only \(apart) apart")
            }
        }
    }

    /// The accent is never a chart category, so it is deliberately brighter than the mark band. It
    /// still has to be distinct from every series, or a lone accent mark would read as a category.
    func testAccentIsOutsideTheSeriesBandAndDistinctFromEachSeries() {
        XCTAssertGreaterThan(lab(HubInk.accent).lightness, Self.markLightness.upperBound)
        for entry in series {
            XCTAssertGreaterThanOrEqual(separation(HubInk.accent, entry.color), Self.separationFloor,
                                        "accent is too close to \(entry.name)")
        }
    }

    /// Completion and the accent must stay different colours, so "done" never reads as "in progress".
    func testSupportIsDistinctFromTheAccent() {
        XCTAssertGreaterThanOrEqual(separation(HubInk.support, HubInk.accent), Self.separationFloor)
    }

    /// The pair this palette replaced, kept only as a fixture. If this ever passes, the checks above
    /// have stopped measuring anything.
    func testRetiredPairIsRejected() {
        let copper = Color(red: 0.898, green: 0.678, blue: 0.525)
        let sage = Color(red: 0.663, green: 0.714, blue: 0.631)
        XCTAssertLessThan(separation(copper, sage), Self.separationFloor)
        XCTAssertLessThan(lab(sage).chroma, Self.chromaFloor)
        XCTAssertFalse(Self.markLightness.contains(lab(copper).lightness))
    }
}
