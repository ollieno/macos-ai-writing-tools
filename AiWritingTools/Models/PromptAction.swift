import Foundation

struct PromptAction: Identifiable {
    let id = UUID()
    let name: String
    let template: String

    func composePrompt(with text: String) -> String? {
        guard template.contains("{{text}}") else { return nil }
        return template.replacingOccurrences(of: "{{text}}", with: text)
    }

    static func composeFreeformPrompt(instruction: String, text: String) -> String {
        "\(instruction)\nGeef alleen het resultaat terug, zonder uitleg.\n\n\(text)"
    }
}
