import Foundation

enum ProcessingState: Equatable {
    case idle
    case processing
    case success(String)
    case error(String)
}
