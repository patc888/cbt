import XCTest
@testable import CBT

final class CBTTests: XCTestCase {
    func testAppConfigurationUsesExpectedCloudContainer() {
        XCTAssertEqual(AppConfiguration.cloudKitContainerIdentifier, "iCloud.com.melichan.CBT")
        XCTAssertEqual(AppConfiguration.appGroupIdentifier, "group.com.melichan.CBT")
    }
}
