import Foundation

/// A folder Gauge has been pointed at so the user can manage its Claude Code
/// `skillOverrides`. Only the path and a display name are kept; everything
/// else lives in the project's own `.claude/settings.local.json`.
struct GaugeProjectEntry: Identifiable, Codable, Hashable {
    let id: UUID
    var path: URL
    var name: String

    init(id: UUID = UUID(), path: URL, name: String? = nil) {
        self.id = id
        self.path = path
        self.name = name ?? path.lastPathComponent
    }
}

/// Where Gauge keeps the list of projects whose Claude Code skills it
/// manages. A plain JSON file in Application Support rather than
/// `UserDefaults`, so a corrupted write never takes the app's other
/// preferences with it.
final class GaugeProjectsStore {
    let storeURL: URL
    private let fileManager: FileManager

    init(storeURL: URL = GaugeProjectsStore.defaultStoreURL(),
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
        return dir.appendingPathComponent("projects.json")
    }

    func load() -> [GaugeProjectEntry] {
        guard let data = try? Data(contentsOf: storeURL),
              let entries = try? JSONDecoder().decode([GaugeProjectEntry].self, from: data) else {
            return []
        }
        return entries
    }

    @discardableResult
    func save(_ entries: [GaugeProjectEntry]) -> Bool {
        do {
            try fileManager.createDirectory(at: storeURL.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(entries)
            try data.write(to: storeURL, options: .atomic)
            return true
        } catch {
            return false
        }
    }

    /// Add an entry if no project with the same resolved path is already
    /// listed. Symlinks and non-standard forms of the same path are treated
    /// as duplicates — a user adding `/Users/me/code/foo` after already
    /// having added `/Users/me/code/foo/` gets one entry, not two.
    func add(_ entry: GaugeProjectEntry, to list: [GaugeProjectEntry]) -> [GaugeProjectEntry] {
        let target = canonical(entry.path)
        if list.contains(where: { canonical($0.path) == target }) {
            return list
        }
        return list + [entry]
    }

    func remove(id: UUID, from list: [GaugeProjectEntry]) -> [GaugeProjectEntry] {
        list.filter { $0.id != id }
    }

    private func canonical(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }
}
