import XCTest

@testable import Reminder2CalCore

final class SyncServiceTests: XCTestCase {
    var mockConfig: AppConfig!

    override func setUp() {
        super.setUp()
        mockConfig = AppConfig()
    }

    override func tearDown() {
        mockConfig = nil
        super.tearDown()
    }

    // Note: Full SyncService initialization tests are skipped in CI environments
    // because they require EventKit permissions and show modal alerts.
    // The SyncService is tested manually during development.

    func testAppConfigIsAvailable() {
        // Verify that AppConfig can be created for SyncService
        XCTAssertNotNil(mockConfig)
        XCTAssertEqual(mockConfig.timerInterval, 1800)  // Default 30 minutes
    }

    func testDefaultSyncSettings() {
        // Verify default sync configuration values
        XCTAssertEqual(mockConfig.numberOfDaysForSearch, 14)
        XCTAssertEqual(mockConfig.maxDeletionsWithoutConfirmation, 5)
        XCTAssertEqual(mockConfig.eventDurationMinutes, 15)
        XCTAssertEqual(mockConfig.alarmOffsetMinutes, 0)
    }
}
