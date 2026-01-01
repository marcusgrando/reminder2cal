import XCTest

@testable import Reminder2CalCore

final class AppConfigTests: XCTestCase {
    var sut: AppConfig!

    override func setUp() {
        super.setUp()
        sut = AppConfig()
    }

    override func tearDown() {
        sut = nil
        super.tearDown()
    }

    func testDefaultValues() {
        // Then
        XCTAssertEqual(sut.numberOfDaysForSearch, 14)
        XCTAssertEqual(sut.maxDeletionsWithoutConfirmation, 5)
        XCTAssertEqual(sut.timerInterval, 1800)
        XCTAssertEqual(sut.eventDurationMinutes, 15)
        XCTAssertEqual(sut.alarmOffsetMinutes, 0)
        XCTAssertEqual(sut.defaultHour, 9)
        XCTAssertEqual(sut.defaultMinute, 0)
    }

    func testLegacyAccountNameProperty() {
        // Given
        sut.accountName = "Test Account"

        // Then
        XCTAssertEqual(sut.calendarAccountName, "Test Account")
        XCTAssertEqual(sut.accountName, sut.calendarAccountName)
    }
}
