import Foundation

struct SeedPrompts {
    static func installIfNeeded(to directory: URL) throws {
        let fm = FileManager.default

        if !fm.fileExists(atPath: directory.path) {
            if let bundledURL = Bundle.main.url(forResource: "DefaultPrompts", withExtension: nil) {
                try fm.copyItem(at: bundledURL, to: directory)
            } else {
                try installFromCode(to: directory, fileManager: fm)
            }
        }

        seedSystemPrompt(to: directory, fileManager: fm)
    }

    private static func installFromCode(to directory: URL, fileManager fm: FileManager) throws {
        let prompts: [(category: String, name: String, content: String)] = [
            ("Correction", "Fix spelling",
             "---\nmodel: haiku\n---\nFix all spelling and grammar errors in the following text.\nPreserve the original tone, style, formatting and language. Return only the corrected text.\n\n{{text}}"),
            ("Translation", "Translate to English",
             "---\nmodel: haiku\n---\nTranslate the following text to English.\nPreserve the tone, style and formatting. Return only the translation.\n\n{{text}}"),
            ("Translation", "Translate to Dutch",
             "---\nmodel: haiku\n---\nTranslate the following text to Dutch.\nPreserve the tone, style and formatting. Return only the translation.\n\n{{text}}"),
            ("Style", "Make shorter",
             "---\nmodel: sonnet\n---\nMake the following text shorter and more concise.\nPreserve the key message and important details. Return only the shortened text.\n\n{{text}}"),
            ("Style", "Make formal",
             "---\nmodel: sonnet\n---\nRewrite the following text in a more formal, professional tone.\nPreserve the meaning, formatting and language. Return only the rewritten text.\n\n{{text}}"),
            ("Style", "Make informal",
             "---\nmodel: sonnet\n---\nRewrite the following text in a more informal, friendly tone.\nPreserve the meaning, formatting and language. Return only the rewritten text.\n\n{{text}}"),
            ("Style", "Summarize",
             "---\nmodel: sonnet\n---\nSummarize the following text in a few sentences.\nFocus on the main points and conclusions. Return only the summary.\n\n{{text}}"),
            ("Image", "Describe image",
             "---\nmodel: sonnet\n---\nDescribe the following image in Dutch.\nBe concise but complete. Mention the key elements, colors and composition. Return only the description.\n\n{{image}}"),
            ("Image", "Read text from image",
             "---\nmodel: haiku\n---\nRead all visible text in the following image.\nPreserve the original formatting where possible. Return only the extracted text.\n\n{{image}}")
        ]

        for prompt in prompts {
            let catDir = directory.appendingPathComponent(prompt.category)
            try fm.createDirectory(at: catDir, withIntermediateDirectories: true)
            let file = catDir.appendingPathComponent("\(prompt.name).md")
            try prompt.content.write(to: file, atomically: true, encoding: .utf8)
        }
    }

    private static let systemPromptContent = """
        You are a text processing tool. Return ONLY the requested result.
        No introduction, no conclusion, no explanation, no accompanying text.
        Do not start with phrases like "Here is..." or "This is the...".
        Only the direct answer to the instruction, nothing more.
        """

    static func seedPluginDirectory(to directory: URL) throws {
        let fm = FileManager.default
        guard !fm.fileExists(atPath: directory.path) else { return }

        try fm.createDirectory(at: directory, withIntermediateDirectories: true)
        for subdir in ["skills", "agents", "hooks", "commands"] {
            try fm.createDirectory(at: directory.appendingPathComponent(subdir), withIntermediateDirectories: true)
        }

        let manifest = """
            {
              "name": "ai-writing-tools",
              "description": "Custom plugins for AI Writing Tools",
              "version": "1.0.0"
            }
            """
        try manifest.write(to: directory.appendingPathComponent("plugin.json"), atomically: true, encoding: .utf8)
    }

    private static func seedSystemPrompt(to directory: URL, fileManager fm: FileManager) {
        let file = directory.appendingPathComponent("_system.md")
        guard !fm.fileExists(atPath: file.path) else { return }
        try? systemPromptContent.write(to: file, atomically: true, encoding: .utf8)
    }
}
