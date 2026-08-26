import XCTest
@testable import GymTracker

final class BodyMetricsTests: XCTestCase {
    func testCentimetersFromFeetAndInches() {
        XCTAssertEqual(BodyMetrics.centimeters(feet: 5, inches: 7), 170.18, accuracy: 0.01)
    }

    func testFeetAndInchesFromCentimeters() {
        let parts = BodyMetrics.feetAndInches(fromCentimeters: 170.18)
        XCTAssertEqual(parts.feet, 5)
        XCTAssertEqual(parts.inches, 7, accuracy: 0.05)
    }

    func testFormatHeightUsesCentimetersForMetric() {
        XCTAssertEqual(BodyMetrics.formatHeight(170, unit: .metric), "170 cm")
    }

    func testFormatHeightUsesFeetAndInchesForImperial() {
        XCTAssertEqual(BodyMetrics.formatHeight(170.18, unit: .imperial), "5 ft 7 in")
    }
}
