import Foundation

enum ProcessingState: Equatable {
    case idle
    case processing
    case success(result: String, model: String?)
    case error(String)
}
