import Foundation

struct PromptLibrary {
    static var promptsDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("AiTools/prompts")
    }
}
