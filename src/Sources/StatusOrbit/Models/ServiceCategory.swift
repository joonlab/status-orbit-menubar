import Foundation

enum ServiceCategory: String, Codable, CaseIterable, Sendable, Hashable {
    case ai = "AI"
    case infrastructure = "Infrastructure"

    var koreanLabel: String {
        switch self {
        case .ai:             return "AI"
        case .infrastructure: return "인프라"
        }
    }
}
