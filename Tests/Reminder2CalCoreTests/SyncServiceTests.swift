import XCTest
@testable import Reminder2CalCore

final class SyncServiceTests: XCTestCase {
    var sut: SyncService!
    var mockConfig: AppConfig!
    
    override func setUp() {
        super.setUp()
        mockConfig = AppConfig()
    }
    
    override func tearDown() {
        sut = nil
        mockConfig = nil
        super.tearDown()
    }
    
    func testSyncServiceInitialization() {
        // Given/When
        let expectation = expectation(description: "SyncService initialization")
        
        sut = SyncService(appConfig: mockConfig) { granted in
            // Then
            expectation.fulfill()
        }
        
        wait(for: [expectation], timeout: 5.0)
        XCTAssertNotNil(sut)
    }
}