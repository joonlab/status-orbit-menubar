import Foundation

/// Google Apps/Cloud Status Dashboard 의 incidents.json 을 polling.
/// productIds 에 매칭되는 product 의 ongoing(end=null) incident 만 카운트.
struct GoogleCloudIncidentProvider: StatusProvider {
    let service: ServiceDefinition
    let incidentsURL = URL(string: "https://www.google.com/appsstatus/dashboard/incidents.json")!

    func fetchStatus(using client: HTTPClient) async throws -> ServiceStatus {
        let resp = try await client.get(incidentsURL)

        let decoder = JSONDecoder()
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { dec in
            let str = try dec.singleValueContainer().decode(String.self)
            if let d = isoFormatter.date(from: str) { return d }
            isoFormatter.formatOptions = [.withInternetDateTime]
            if let d = isoFormatter.date(from: str) { return d }
            return Date(timeIntervalSince1970: 0)
        }

        let incidents = try decoder.decode([GCIncident].self, from: resp.data)

        // 1) productIds 매칭 + ongoing 필터
        let matching = incidents.filter { inc in
            inc.end == nil && inc.affectedProducts?.contains(where: { ap in
                service.productIds.contains(where: { ap.title.localizedCaseInsensitiveContains($0) })
            }) == true
        }

        guard !matching.isEmpty else {
            return ServiceStatus(
                serviceId: service.id,
                level: .operational,
                message: "All systems operational",
                fetchedAt: resp.fetchedAt
            )
        }

        // 2) severity 중 최악
        let level = matching
            .map { Self.mapLevel(severity: $0.severity, impact: $0.statusImpact) }
            .max(by: { $0.severityRank < $1.severityRank }) ?? .unknown

        let summaries = matching.prefix(5).map { inc -> IncidentSummary in
            IncidentSummary(
                id: inc.id,
                title: inc.externalDesc ?? "Incident",
                impact: inc.statusImpact,
                status: inc.severity,
                url: inc.uri.flatMap { URL(string: "https://www.google.com/appsstatus" + $0) },
                updatedAt: inc.modified ?? inc.begin ?? Date()
            )
        }

        return ServiceStatus(
            serviceId: service.id,
            level: level,
            message: matching.first?.externalDesc,
            fetchedAt: resp.fetchedAt,
            incidents: Array(summaries)
        )
    }

    private static func mapLevel(severity: String?, impact: String?) -> StatusLevel {
        switch (severity?.lowercased() ?? "", impact?.uppercased() ?? "") {
        case (_, "SERVICE_OUTAGE"):     return .critical
        case (_, "SERVICE_DISRUPTION"): return .major
        case ("high", _):               return .major
        case ("medium", _):             return .degraded
        case ("low", _):                return .degradedPerformance
        default:                        return .degradedPerformance
        }
    }
}

// MARK: - Google Cloud Incident DTOs

private struct GCAffectedProduct: Decodable {
    let title: String
    let id: String?
}

private struct GCIncident: Decodable {
    let id: String
    let externalDesc: String?
    let begin: Date?
    let end: Date?
    let modified: Date?
    let severity: String?
    let statusImpact: String?
    let affectedProducts: [GCAffectedProduct]?
    let uri: String?

    enum CodingKeys: String, CodingKey {
        case id
        case externalDesc = "external_desc"
        case begin, end, modified, severity
        case statusImpact = "status_impact"
        case affectedProducts = "affected_products"
        case uri
    }
}
