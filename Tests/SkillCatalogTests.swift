import XCTest
@testable import Codenotch

final class SkillCatalogTests: XCTestCase {
    private var tempHome: URL!

    override func setUpWithError() throws {
        tempHome = FileManager.default.temporaryDirectory
            .appendingPathComponent("SkillCatalogTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: tempHome, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        try? FileManager.default.removeItem(at: tempHome)
    }

    func testFindsUserSkills() throws {
        try writeSkill(at: tempHome.appendingPathComponent(".claude/skills/alpha"),
                       body: "---\nname: alpha\ndescription: alpha skill\n---\n")
        try writeSkill(at: tempHome.appendingPathComponent(".claude/skills/beta"),
                       body: "---\nname: beta\n---\n")

        let catalog = SkillCatalog.load(home: tempHome)
        XCTAssertEqual(catalog.skills.map(\.id), ["alpha", "beta"])
        XCTAssertEqual(catalog.skills.first?.description, "alpha skill")
    }

    func testFallsBackToFolderNameWhenFrontmatterIsMissing() throws {
        try writeSkill(at: tempHome.appendingPathComponent(".claude/skills/no-fm"),
                       body: "# just prose")
        let catalog = SkillCatalog.load(home: tempHome)
        XCTAssertEqual(catalog.skills.map(\.id), ["no-fm"])
        XCTAssertNil(catalog.skills.first?.description)
    }

    func testIncludesPluginSkillsFromManifest() throws {
        try writeSkill(at: tempHome.appendingPathComponent(".claude/plugins/cache/foo/1.0/skills/plug-one"),
                       body: "---\nname: plug-one\n---\n")
        let manifest = tempHome.appendingPathComponent(".claude/plugins/installed_plugins.json")
        try FileManager.default.createDirectory(at: manifest.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let manifestJSON: [String: Any] = [
            "version": 2,
            "plugins": [
                "foo@store": [[
                    "installPath": tempHome.appendingPathComponent(".claude/plugins/cache/foo/1.0").path
                ]]
            ]
        ]
        let data = try JSONSerialization.data(withJSONObject: manifestJSON)
        try data.write(to: manifest)

        let catalog = SkillCatalog.load(home: tempHome)
        XCTAssertEqual(catalog.skills.map(\.id), ["plug-one"])
        if case let .plugin(name) = catalog.skills.first?.source {
            XCTAssertEqual(name, "foo")
        } else {
            XCTFail("Expected plugin source")
        }
    }

    func testUserSkillWinsOverPluginWithSameName() throws {
        try writeSkill(at: tempHome.appendingPathComponent(".claude/skills/shared"),
                       body: "---\nname: shared\ndescription: user\n---\n")
        try writeSkill(at: tempHome.appendingPathComponent(".claude/plugins/cache/x/1/skills/shared"),
                       body: "---\nname: shared\ndescription: plugin\n---\n")
        let manifest = tempHome.appendingPathComponent(".claude/plugins/installed_plugins.json")
        try FileManager.default.createDirectory(at: manifest.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        let manifestJSON: [String: Any] = [
            "plugins": [
                "x@store": [[
                    "installPath": tempHome.appendingPathComponent(".claude/plugins/cache/x/1").path
                ]]
            ]
        ]
        try JSONSerialization.data(withJSONObject: manifestJSON).write(to: manifest)

        let catalog = SkillCatalog.load(home: tempHome)
        XCTAssertEqual(catalog.skills.count, 1)
        XCTAssertEqual(catalog.skills.first?.description, "user")
        if case .user = catalog.skills.first?.source {} else {
            XCTFail("Expected user source to win")
        }
    }

    private func writeSkill(at dir: URL, body: String) throws {
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try body.write(to: dir.appendingPathComponent("SKILL.md"), atomically: true, encoding: .utf8)
    }
}
