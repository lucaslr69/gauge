import Foundation

/// A reusable set of skill overrides that can be applied to any registered
/// project. "stack-flutter" or "arka-dev only" is the sort of thing a user
/// keeps as a preset so they don't rebuild the same selection from scratch
/// in each project.
struct SkillPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var overrides: [String: SkillState]

    init(id: UUID = UUID(), name: String, overrides: [String: SkillState]) {
        self.id = id
        self.name = name
        self.overrides = overrides
    }
}

final class SkillPresetStore {
    let storeURL: URL
    private let fileManager: FileManager

    init(storeURL: URL = SkillPresetStore.defaultStoreURL(),
         fileManager: FileManager = .default) {
        self.storeURL = storeURL
        self.fileManager = fileManager
    }

    static func defaultStoreURL() -> URL {
        let base = try? FileManager.default.url(for: .applicationSupportDirectory,
                                                in: .userDomainMask,
                                                appropriateFor: nil,
                                                create: true)
        let dir = (base ?? FileManager.default.homeDirectoryForCurrentUser)
            .appendingPathComponent("Codenotch", isDirectory: true)
        return dir.appendingPathComponent("skill-presets.json")
    }

    func load() -> [SkillPreset] {
        guard let data = try? Data(contentsOf: storeURL),
              let presets = try? JSONDecoder().decode([SkillPreset].self, from: data) else {
            return []
        }
        return presets
    }

    @discardableResult
    func save(_ presets: [SkillPreset]) -> Bool {
        do {
            try fileManager.createDirectory(at: storeURL.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(presets)
            try data.write(to: storeURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }
}
