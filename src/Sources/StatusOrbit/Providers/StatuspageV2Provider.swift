import Foundation

/// Statuspage v2 표준 (Atlassian Statuspage). 8개 서비스가 같은 구조를 공유:
/// OpenAI, Anthropic, GitHub, Vercel, Cloudflare, Supabase, Netlify, Railway.
/// `baseURL` 뒤에 /api/v2/status.json (가벼움) 또는 /api/v2/summary.json (full).
struct StatuspageV2Provider: StatusProvider {
    let service: ServiceDefinition
    let useSummary: Bool  // true → summary.json (incidents 포함), false → status.json (가볍게)

    func fetchStatus(using client: HTTPClient) async throws -> ServiceStatus {
        let path = useSummary ? "api/v2/summary.json" : "api/v2/status.json"
        let url = service.baseURL.appendingPathComponent(path)
        let resp = try await client.get(url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if useSummary {
            let summary = try decoder.decode(StatuspageSummary.self, from: resp.data)
            return ServiceStatus(
                serviceId: service.id,
                level: Self.level(from: summary.status.indicator),
                message: summary.status.description,
                fetchedAt: resp.fetchedAt,
                incidents: summary.incidents?.prefix(5).map(IncidentSummary.init(from:)) ?? []
            )
        } else {
            let lite = try decoder.decode(StatuspageLite.self, from: resp.data)
            return ServiceStatus(
                serviceId: service.id,
                level: Self.level(from: lite.status.indicator),
                message: lite.status.description,
                fetchedAt: resp.fetchedAt
            )
        }
    }

    static func level(from indicator: String) -> StatusLevel {
        switch indicator.lowercased() {
        case "none":         return .operational
        case "minor":        return .degradedPerformance
        case "major":        return .major
        case "critical":     return .critical
        case "maintenance":  return .maintenance
        default:             return .unknown
        }
    }
}

// MARK: - Statuspage JSON DTOs

private struct StatuspageStatus: Decodable {
    let indicator: String
    let description: String
}

private struct StatuspageLite: Decodable {
    let status: StatuspageStatus
}

private struct StatuspageIncident: Decodable {
    let id: String
    let name: String
    let impact: String?
    let status: String?
    let shortlink: String?
    let updatedAt: Date?
    enum CodingKeys: String, CodingKey {
        case id, name, impact, status, shortlink
        case updatedAt = "updated_at"
    }
}

private struct StatuspageSummary: Decodable {
    let status: StatuspageStatus
    let incidents: [StatuspageIncident]?
}

private extension IncidentSummary {
    init(from sp: StatuspageIncident) {
        self.init(
            id: sp.id,
            title: sp.name,
            impact: sp.impact,
            status: sp.status,
            url: sp.shortlink.flatMap(URL.init(string:)),
            updatedAt: sp.updatedAt ?? Date()
        )
    }
}
