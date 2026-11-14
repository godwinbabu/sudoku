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

    /// Values are not pinned: a release raises the build number (README, Release).
    func testInfoPlistVersionsResolveAndEncryptionIsDeclared() throws {
        let info = appBundle.infoDictionary ?? [:]
        let version = try XCTUnwrap(info["CFBundleShortVersionString"] as? String)
        let build = try XCTUnwrap(info["CFBundleVersion"] as? String)
        XCTAssertNotNil(version.range(of: #"^\d+(\.\d+){0,2}$"#, options: .regularExpression), version)
        XCTAssertNotNil(build.range(of: #"^\d+(\.\d+){0,2}$"#, options: .regularExpression), build)
        XCTAssertEqual(info["ITSAppUsesNonExemptEncryption"] as? Bool, false)
    }

    /// The source plist must read the build settings, or `agvtool next-version` would not change the upload.
    func testInfoPlistReadsVersionBuildSettings() throws {
        let plist = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("PureSudoku/Supporting/Info.plist")
        // The checkout is only reachable from the simulator, not from a device.
        try XCTSkipUnless(FileManager.default.fileExists(atPath: plist.path), "source Info.plist not reachable")
        let source = try XCTUnwrap(
            PropertyListSerialization.propertyList(from: Data(contentsOf: plist), format: nil) as? [String: Any]
        )
        XCTAssertEqual(source["CFBundleShortVersionString"] as? String, "$(MARKETING_VERSION)")
        XCTAssertEqual(source["CFBundleVersion"] as? String, "$(CURRENT_PROJECT_VERSION)")
    }
}
