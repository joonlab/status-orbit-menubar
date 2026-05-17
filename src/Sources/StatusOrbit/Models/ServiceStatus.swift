import Foundation

struct ServiceStatus: Codable, Hashable, Sendable {
    let serviceId: String
    let level: StatusLevel
    let message: String?
    let fetchedAt: Date
    let incidents: [IncidentSummary]
    let components: [ComponentStatus]
    let isStale: Bool

    init(
        serviceId: String,
        level: StatusLevel,
        message: String? = nil,
        fetchedAt: Date = Date(),
        incidents: [IncidentSummary] = [],
        components: [ComponentStatus] = [],
        isStale: Bool = false
    ) {
        self.serviceId = serviceId
        self.level = level
        self.message = message
        self.fetchedAt = fetchedAt
        self.incidents = incidents
        self.components = components
        self.isStale = isStale
    }

    static func unknown(serviceId: String, reason: String = "fetch failed") -> ServiceStatus {
        ServiceStatus(
            serviceId: serviceId,
            level: .unknown,
            message: reason,
            fetchedAt: Date()
        )
    }
}
