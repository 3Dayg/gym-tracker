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

    func testFormatHeightUsesCentimetersForKilograms() {
        XCTAssertEqual(BodyMetrics.formatHeight(170, weightUnit: .kilograms), "170 cm")
    }
}
