import Foundation

/// Reads and writes `skillOverrides` inside a project's
/// `.claude/settings.local.json` while leaving every other key the file
/// carries — `permissions`, `hooks` and anything else Claude Code or an
/// adjacent tool stored there — untouched.
///
/// The I/O goes through `JSONSerialization` on purpose: a strongly-typed
/// `Codable` struct would silently drop any key it did not declare, which
/// is exactly the kind of damage this type exists to prevent.
struct ProjectSkillStore {
    let projectRoot: URL
    private let fileManager: FileManager

    init(projectRoot: URL, fileManager: FileManager = .default) {
        self.projectRoot = projectRoot
        self.fileManager = fileManager
    }

    var settingsFile: URL {
        projectRoot
            .appendingPathComponent(".claude", isDirectory: true)
            .appendingPathComponent("settings.local.json")
    }

    /// The overrides currently stored. A missing file, an absent key, an
    /// unknown value or the literal `"on"` are all treated as "no override"
    /// — a skill without an entry is already on by default.
    func overrides() -> [String: SkillState] {
        guard let root = readRoot(),
              let raw = root["skillOverrides"] as? [String: Any] else {
            return [:]
        }
        var out: [String: SkillState] = [:]
        for (key, value) in raw {
            guard let string = value as? String,
                  let state = SkillState(rawValue: string),
                  state != .on else { continue }
            out[key] = state
        }
        return out
    }

    /// Set a single skill's state. `.on` removes the entry; `skillOverrides`
    /// itself goes away when its last entry does, and the file is deleted
    /// when it would otherwise become empty.
    func setState(_ state: SkillState, for skillID: String) throws {
        var root = readRoot() ?? [:]
        var overrides = root["skillOverrides"] as? [String: Any] ?? [:]
        if state == .on {
            overrides.removeValue(forKey: skillID)
        } else {
            overrides[skillID] = state.rawValue
        }
        if overrides.isEmpty {
            root.removeValue(forKey: "skillOverrides")
        } else {
            root["skillOverrides"] = overrides
        }
        try write(root: root)
    }

    /// Replace every override at once. Entries equal to `.on` are stripped
    /// before the write, so a preset describing "turn everything back on"
    /// doesn't persist a wall of redundant `"on"` entries.
    func replaceAll(with newOverrides: [String: SkillState]) throws {
        var root = readRoot() ?? [:]
        let effective = newOverrides.filter { $0.value != .on }
        if effective.isEmpty {
            root.removeValue(forKey: "skillOverrides")
        } else {
            root["skillOverrides"] = effective.mapValues { $0.rawValue }
        }
        try write(root: root)
    }

    private func readRoot() -> [String: Any]? {
        guard fileManager.fileExists(atPath: settingsFile.path),
              let data = try? Data(contentsOf: settingsFile),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return obj
    }

    private func write(root: [String: Any]) throws {
        if root.isEmpty {
            if fileManager.fileExists(atPath: settingsFile.path) {
                try fileManager.removeItem(at: settingsFile)
            }
            return
        }
        try fileManager.createDirectory(at: settingsFile.deletingLastPathComponent(),
                                        withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: root,
                                             options: [.prettyPrinted, .sortedKeys])
        try data.write(to: settingsFile, options: .atomic)
    }
}
