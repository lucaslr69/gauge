import XCTest
@testable import Codenotch

final class SkillPresetStoreTests: XCTestCase {
    private var tempStoreURL: URL!

    override func setUpWithError() throws {
        tempStoreURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkillPresetStoreTests-\(UUID().uuidString)")
            .appendingPathComponent("skill-presets.json")
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempStoreURL.deletingLastPathComponent())
    }

    func testRoundTripsPresets() {
        let store = SkillPresetStore(storeURL: tempStoreURL)
        let preset = SkillPreset(name: "stack-flutter",
                                 overrides: ["arka-brand": .off, "arka-dev": .on])
        XCTAssertTrue(store.save([preset]))
        XCTAssertEqual(store.load(), [preset])
    }

    func testLoadReturnsEmptyWhenFileMissing() {
        let store = SkillPresetStore(storeURL: tempStoreURL)
        XCTAssertTrue(store.load().isEmpty)
    }
}
