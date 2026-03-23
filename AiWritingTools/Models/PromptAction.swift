import Foundation

enum ContentType: Hashable {
    case text
    case image
}

struct PromptAction: Identifiable {
    let id = UUID()
    let name: String
    let template: String
    let model: String?

    init(name: String, template: String, model: String? = nil) {
        self.name = name
        self.template = template
        self.model = model
    }

    var requiredContentTypes: Set<ContentType> {
        var types = Set<ContentType>()
        if template.contains("{{text}}") { types.insert(.text) }
        if template.contains("{{image}}") { types.insert(.image) }
        return types
    }

    func composePrompt(text: String?, imagePath: String?) -> String? {
        var result = template
        if template.contains("{{text}}") {
            guard let text else { return nil }
            result = result.replacingOccurrences(of: "{{text}}", with: text)
        }
        if template.contains("{{image}}") {
            guard let imagePath else { return nil }
            result = result.replacingOccurrences(of: "{{image}}", with: imagePath)
        }
        return result
    }

    static func composeFreeformPrompt(instruction: String, text: String?, imagePath: String?) -> String {
        var parts = [instruction, "Geef alleen het resultaat terug, zonder uitleg."]
        if let text { parts.append(text) }
        if let imagePath { parts.append(imagePath) }
        return parts.joined(separator: "\n\n")
    }
}
