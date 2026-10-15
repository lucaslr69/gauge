import Foundation

/// The skills reachable to Claude Code from this Mac, read fresh off the
/// filesystem on every `load`. Two sources contribute: the user's own
/// skills in `~/.claude/skills` and every plugin install listed in
/// `~/.claude/plugins/installed_plugins.json`.
///
/// Nothing is cached across calls — the Settings pane calls `load` whenever
/// it opens, which keeps a freshly installed skill from needing an app
/// restart to show up.
struct SkillCatalog {
    var skills: [SkillInfo]

    static func load(fileManager: FileManager = .default,
                     home: URL = FileManager.default.homeDirectoryForCurrentUser) -> SkillCatalog {
        var found: [SkillInfo] = []
        let userRoot = home.appendingPathComponent(".claude/skills", isDirectory: true)
        found.append(contentsOf: scan(userRoot, source: .user, fileManager: fileManager))

        let manifest = home.appendingPathComponent(".claude/plugins/installed_plugins.json")
        for root in pluginSkillRoots(fromManifest: manifest, fileManager: fileManager) {
            found.append(contentsOf: scan(root.url, source: .plugin(name: root.pluginName),
                                         fileManager: fileManager))
        }

        // User skills take precedence over a plugin skill of the same name.
        // Already in that order because user is scanned first.
        var seen = Set<String>()
        let unique = found.filter { seen.insert($0.id).inserted }
        return SkillCatalog(skills: unique.sorted { $0.id.localizedCaseInsensitiveCompare($1.id) == .orderedAscending })
    }

    private struct PluginRoot {
        let url: URL
        let pluginName: String
    }

    private static func pluginSkillRoots(fromManifest manifest: URL,
                                         fileManager: FileManager) -> [PluginRoot] {
        guard let data = try? Data(contentsOf: manifest),
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let plugins = obj["plugins"] as? [String: Any] else {
            return []
        }
        var roots: [PluginRoot] = []
        for (pluginKey, raw) in plugins {
            guard let installs = raw as? [[String: Any]] else { continue }
            let pluginName = pluginKey.split(separator: "@").first.map(String.init) ?? pluginKey
            for install in installs {
                guard let path = install["installPath"] as? String else { continue }
                let base = URL(fileURLWithPath: path)
                for sub in ["skills", ".claude/skills"] {
                    roots.append(PluginRoot(url: base.appendingPathComponent(sub, isDirectory: true),
                                           pluginName: pluginName))
                }
            }
        }
        return roots
    }

    private static func scan(_ dir: URL, source: SkillSource,
                             fileManager: FileManager) -> [SkillInfo] {
        guard let contents = try? fileManager.contentsOfDirectory(at: dir,
                                                                 includingPropertiesForKeys: [.isDirectoryKey],
                                                                 options: [.skipsHiddenFiles]) else {
            return []
        }
        var items: [SkillInfo] = []
        for entry in contents {
            var isDir: ObjCBool = false
            guard fileManager.fileExists(atPath: entry.path, isDirectory: &isDir), isDir.boolValue else { continue }
            let skillFile = entry.appendingPathComponent("SKILL.md")
            guard fileManager.fileExists(atPath: skillFile.path) else { continue }
            let text = (try? String(contentsOf: skillFile, encoding: .utf8)) ?? ""
            let (name, description) = SkillFrontmatter.parse(text)
            let id = name ?? entry.lastPathComponent
            items.append(SkillInfo(
                id: id,
                displayName: name ?? entry.lastPathComponent,
                description: description,
                source: source,
                skillMarkdownURL: skillFile
            ))
        }
        return items
    }
}
