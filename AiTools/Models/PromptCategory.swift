import Foundation

struct PromptCategory: Identifiable {
    let id = UUID()
    let name: String
    let actions: [PromptAction]
}
