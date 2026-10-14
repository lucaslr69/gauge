import Foundation

/// A deliberately small reader for the fences at the top of a SKILL.md. Only
/// the keys the catalog actually uses — `name` and `description` — are
/// recognised; folded descriptions (`description: >`) collapse to a single
/// line, matching how Claude Code reads them. Anything else in the YAML is
/// ignored.
enum SkillFrontmatter {
    static func parse(_ markdown: String) -> (name: String?, description: String?) {
        var lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        while let first = lines.first, first.trimmingCharacters(in: .whitespaces).isEmpty {
            lines.removeFirst()
        }
        guard lines.first?.trimmingCharacters(in: .whitespaces) == "---" else {
            return (nil, nil)
        }
        lines.removeFirst()

        var yaml: [String] = []
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces) == "---" { break }
            yaml.append(line)
        }

        var name: String?
        var description: String?
        var collectingFolded = false
        var folded: [String] = []

        for line in yaml {
            if collectingFolded {
                if line.hasPrefix(" ") || line.hasPrefix("\t") {
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    if !trimmed.isEmpty { folded.append(trimmed) }
                    continue
                }
                description = folded.joined(separator: " ")
                collectingFolded = false
                folded.removeAll()
            }
            if let value = scalar(forKey: "name", in: line) {
                name = value
                continue
            }
            if let value = scalar(forKey: "description", in: line) {
                if value == ">" || value == "|" || value.isEmpty {
                    collectingFolded = true
                } else {
                    description = value
                }
                continue
            }
        }
        if collectingFolded && !folded.isEmpty {
            description = folded.joined(separator: " ")
        }
        return (name, description)
    }

    private static func scalar(forKey key: String, in line: String) -> String? {
        let prefix = "\(key):"
        guard line.hasPrefix(prefix) else { return nil }
        var value = String(line.dropFirst(prefix.count)).trimmingCharacters(in: .whitespaces)
        if value.count >= 2 {
            let first = value.first!
            let last = value.last!
            if (first == "\"" && last == "\"") || (first == "'" && last == "'") {
                value = String(value.dropFirst().dropLast())
            }
        }
        return value
    }
}
