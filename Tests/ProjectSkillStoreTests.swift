import XCTest
@testable import Codenotch

final class ProjectSkillStoreTests: XCTestCase {
    private var tempRoot: URL!

    override func setUpWithError() throws {
        tempRoot = FileManager.default.temporaryDirectory
            .appendingPathComponent("ProjectSkillStoreTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempRoot)
    }

    func testWritesOverrideAndReadsItBack() throws {
        let store = ProjectSkillStore(projectRoot: tempRoot)
        try store.setState(.off, for: "arka-brand")
        XCTAssertEqual(store.overrides(), ["arka-brand": .off])

        let raw = try readJSON()
        XCTAssertEqual((raw["skillOverrides"] as? [String: String])?["arka-brand"], "off")
    }

    func testOnStateRemovesTheEntry() throws {
        let store = ProjectSkillStore(projectRoot: tempRoot)
        try store.setState(.off, for: "arka-brand")
        try store.setState(.on, for: "arka-brand")
        XCTAssertTrue(store.overrides().isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.settingsFile.path),
                      "Empty settings file should be removed.")
    }

    func testPreservesOtherKeysWhenWriting() throws {
        try writeInitialSettings([
            "permissions": ["allow": ["Bash(ls:*)"]],
            "hooks": ["CwdChanged": ["dummy"]]
        ])
        let store = ProjectSkillStore(projectRoot: tempRoot)
        try store.setState(.off, for: "arka-brand")

        let raw = try readJSON()
        XCTAssertNotNil(raw["permissions"])
        XCTAssertNotNil(raw["hooks"])
        XCTAssertEqual((raw["skillOverrides"] as? [String: String])?["arka-brand"], "off")
    }

    func testRemovingLastOverrideKeepsOtherKeys() throws {
        try writeInitialSettings([
            "permissions": ["allow": ["Bash(ls:*)"]],
            "skillOverrides": ["arka-brand": "off"]
        ])
        let store = ProjectSkillStore(projectRoot: tempRoot)
        try store.setState(.on, for: "arka-brand")

        let raw = try readJSON()
        XCTAssertNotNil(raw["permissions"])
        XCTAssertNil(raw["skillOverrides"])
    }

    func testUnknownValuesAreTreatedAsOn() throws {
        try writeInitialSettings([
            "skillOverrides": ["weird": "banana", "normal": "off"]
        ])
        let store = ProjectSkillStore(projectRoot: tempRoot)
        XCTAssertEqual(store.overrides(), ["normal": .off])
    }

    func testReplaceAllStripsOnEntries() throws {
        let store = ProjectSkillStore(projectRoot: tempRoot)
        try store.replaceAll(with: [
            "a": .off,
            "b": .on,
            "c": .nameOnly
        ])
        XCTAssertEqual(store.overrides(), ["a": .off, "c": .nameOnly])
    }

    func testReplaceAllWithEmptyRemovesKey() throws {
        try writeInitialSettings([
            "permissions": ["allow": ["Bash(ls:*)"]],
            "skillOverrides": ["x": "off"]
        ])
        let store = ProjectSkillStore(projectRoot: tempRoot)
        try store.replaceAll(with: [:])
        let raw = try readJSON()
        XCTAssertNil(raw["skillOverrides"])
        XCTAssertNotNil(raw["permissions"])
    }

    private func writeInitialSettings(_ dict: [String: Any]) throws {
        let dir = tempRoot.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: dict,
                                             options: [.prettyPrinted, .sortedKeys])
        try data.write(to: dir.appendingPathComponent("settings.local.json"))
    }

    private func readJSON() throws -> [String: Any] {
        let data = try Data(contentsOf: tempRoot.appendingPathComponent(".claude/settings.local.json"))
        return try JSONSerialization.jsonObject(with: data) as? [String: Any] ?? [:]
    }
}
