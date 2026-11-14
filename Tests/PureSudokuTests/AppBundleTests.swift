import XCTest
@testable import PureSudoku

/// Checks App Store upload requirements on the built app bundle (the test host).
final class AppBundleTests: XCTestCase {
    private let appBundle = Bundle(for: AppController.self)

    func testPrivacyManifestDeclaresFileTimestampReason() throws {
        let url = try XCTUnwrap(appBundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
        let data = try Data(contentsOf: url)
        let manifest = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual((manifest["NSPrivacyTrackingDomains"] as? [Any])?.count, 0)
        XCTAssertEqual((manifest["NSPrivacyCollectedDataTypes"] as? [Any])?.count, 0)
        let apis = try XCTUnwrap(manifest["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let timestamp = try XCTUnwrap(apis.first {
            $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryFileTimestamp"
        })
        XCTAssertEqual(timestamp["NSPrivacyAccessedAPITypeReasons"] as? [String], ["C617.1"])
    }

    func testInfoPlistVersionsComeFromBuildSettings() {
        let info = appBundle.infoDictionary ?? [:]
        XCTAssertEqual(info["CFBundleShortVersionString"] as? String, "1.0")
        XCTAssertEqual(info["CFBundleVersion"] as? String, "1")
        XCTAssertEqual(info["ITSAppUsesNonExemptEncryption"] as? Bool, false)
    }
}
