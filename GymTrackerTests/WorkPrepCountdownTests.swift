import XCTest
@testable import GymTracker

@MainActor
final class WorkPrepCountdownTests: XCTestCase {
    func testCountsDownThenPerforms() async throws {
        let prep = WorkPrepCountdown(stepNanoseconds: 20_000_000)
        let performed = expectation(description: "prep finished")
        prep.start { performed.fulfill() }
        XCTAssertEqual(prep.remaining, 3)
        await fulfillment(of: [performed], timeout: 1)
        XCTAssertNil(prep.remaining)
        XCTAssertFalse(prep.isActive)
    }

    func testCancelDropsPrepWithoutPerforming() async throws {
        let prep = WorkPrepCountdown(stepNanoseconds: 50_000_000)
        var performed = false
        prep.start { performed = true }
        XCTAssertTrue(prep.isActive)
        prep.cancel()
        XCTAssertNil(prep.remaining)
        try await Task.sleep(nanoseconds: 120_000_000)
        XCTAssertFalse(performed)
    }
}
