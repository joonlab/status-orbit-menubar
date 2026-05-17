import Foundation

struct ComponentStatus: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let groupId: String?
    let indicator: String?
    let description: String?
    let level: StatusLevel
}
