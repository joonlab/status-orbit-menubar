import Foundation

struct IncidentSummary: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let title: String
    let impact: String?
    let status: String?
    let url: URL?
    let updatedAt: Date
}
