import Foundation

/// A skill's visibility to Claude Code, read verbatim from `skillOverrides`
/// in `.claude/settings.local.json`. The raw values are the ones the Claude
/// Code harness recognises; anything else is treated as `.on` (the default).
enum SkillState: String, Codable, CaseIterable, Hashable {
    case on
    case nameOnly = "name-only"
    case userInvocableOnly = "user-invocable-only"
    case off
}

/// Where a skill came from. The user's own skills in `~/.claude/skills` are
/// listed by themselves; plugin skills carry the plugin they came from so
/// the UI can group and badge them.
enum SkillSource: Hashable {
    case user
    case plugin(name: String)
}

/// A skill discovered on disk. The `id` is the exact key the Claude Code
/// settings file expects — it is the `name:` from the SKILL.md frontmatter
/// when present, otherwise the folder name.
struct SkillInfo: Identifiable, Hashable {
    let id: String
    let displayName: String
    let description: String?
    let source: SkillSource
    let skillMarkdownURL: URL
}
