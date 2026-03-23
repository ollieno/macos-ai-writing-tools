import Foundation
import os

struct PromptLibrary {
    static var promptsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AiWritingTools/prompts")
    }

    private let directory: URL
    private let logger = Logger(subsystem: "ai.amihuman.macos.AiWritingTools", category: "PromptLibrary")

    init(directory: URL? = nil) {
        self.directory = directory ?? Self.promptsDirectory
    }

    func loadSystemPrompt() -> String? {
        let file = directory.appendingPathComponent("_system.md")
        guard let content = try? String(contentsOf: file, encoding: .utf8),
              !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func loadCategories() -> [PromptCategory] {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents
            .filter { (try? $0.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { loadCategory(from: $0) }
            .filter { !$0.actions.isEmpty }
    }

    func loadCategories(availableContent: Set<ContentType>) -> [PromptCategory] {
        return loadCategories().compactMap { category in
            let filtered = category.actions.filter { action in
                action.requiredContentTypes.isSubset(of: availableContent)
            }
            guard !filtered.isEmpty else { return nil }
            return PromptCategory(name: category.name, actions: filtered)
        }
    }

    private func loadCategory(from url: URL) -> PromptCategory? {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(
            at: url,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else {
            return nil
        }

        let actions = files
            .filter { $0.pathExtension == "md" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { loadAction(from: $0) }

        return PromptCategory(
            name: url.lastPathComponent,
            actions: actions
        )
    }

    private func loadAction(from url: URL) -> PromptAction? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            logger.warning("Could not read: \(url.path)")
            return nil
        }
        guard !content.isEmpty else {
            logger.warning("Empty file: \(url.path)")
            return nil
        }

        let (template, model) = parseFrontmatter(content)

        guard template.contains("{{text}}") || template.contains("{{image}}") else {
            logger.warning("Missing {{text}} or {{image}} placeholder: \(url.path)")
            return nil
        }

        let name = url.deletingPathExtension().lastPathComponent
        return PromptAction(name: name, template: template, model: model)
    }

    private func parseFrontmatter(_ content: String) -> (template: String, model: String?) {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else {
            return (content, nil)
        }

        let lines = content.components(separatedBy: .newlines)
        guard let closingIndex = lines.dropFirst().firstIndex(where: { $0.trimmingCharacters(in: .whitespaces) == "---" }) else {
            return (content, nil)
        }

        var model: String?
        for line in lines[1..<closingIndex] {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2,
               parts[0].trimmingCharacters(in: .whitespaces) == "model" {
                let value = parts[1].trimmingCharacters(in: .whitespaces)
                if !value.isEmpty { model = value }
            }
        }

        let templateLines = Array(lines[(closingIndex + 1)...])
        let template = templateLines.joined(separator: "\n")
        return (template, model)
    }
}
