import Foundation

/// xAI Grok 상태는 status.x.ai/feed.xml (RSS 2.0) 로만 노출.
/// 가장 최근 item 의 description 에서 "Status: investigating|identified|monitoring|resolved" 등을
/// 파싱해 level 결정. 모든 최근 24시간 item 이 resolved 면 operational.
struct XAIRSSProvider: StatusProvider {
    let service: ServiceDefinition

    func fetchStatus(using client: HTTPClient) async throws -> ServiceStatus {
        let resp = try await client.get(service.baseURL)
        return Self.parse(serviceId: service.id, data: resp.data, fetchedAt: resp.fetchedAt)
    }

    static func parse(serviceId: String, data: Data, fetchedAt: Date) -> ServiceStatus {
        let parser = XMLParser(data: data)
        let delegate = RSSItemCollector()
        parser.delegate = delegate
        let ok = parser.parse()

        guard ok else {
            return ServiceStatus(serviceId: serviceId, level: .unknown,
                                 message: "Unable to parse xAI RSS feed", fetchedAt: fetchedAt)
        }

        let now = fetchedAt
        let recent = delegate.items.filter { item in
            guard let date = item.pubDate else { return true }
            return now.timeIntervalSince(date) < 60 * 60 * 24  // 24h
        }

        guard !recent.isEmpty else {
            return ServiceStatus(serviceId: serviceId, level: .operational,
                                 message: "No recent incidents", fetchedAt: fetchedAt)
        }

        // 가장 최근 item 의 status 가 resolved 면 operational, 아니면 그 status 의 심각도.
        let sorted = recent.sorted { ($0.pubDate ?? .distantPast) > ($1.pubDate ?? .distantPast) }
        let latest = sorted.first!

        let lvl = level(from: latest.statusKeyword)
        let summaries = sorted.prefix(5).map { item in
            IncidentSummary(
                id: item.guid ?? item.title,
                title: item.title,
                impact: nil,
                status: item.statusKeyword,
                url: item.link.flatMap(URL.init(string:)),
                updatedAt: item.pubDate ?? fetchedAt
            )
        }

        return ServiceStatus(
            serviceId: serviceId,
            level: lvl,
            message: latest.title,
            fetchedAt: fetchedAt,
            incidents: Array(summaries)
        )
    }

    private static func level(from keyword: String?) -> StatusLevel {
        guard let kw = keyword?.lowercased() else { return .degradedPerformance }
        switch kw {
        case "resolved":     return .operational
        case "monitoring":   return .degradedPerformance
        case "identified":   return .degraded
        case "investigating":return .major
        default:             return .degradedPerformance
        }
    }
}

// MARK: - Minimal RSS parser

private final class RSSItemCollector: NSObject, XMLParserDelegate {
    struct Item {
        var title: String = ""
        var link: String?
        var guid: String?
        var description: String?
        var pubDate: Date?
        var statusKeyword: String?
    }

    private(set) var items: [Item] = []
    private var current: Item?
    private var buffer: String = ""

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return f
    }()

    private static let statusRegex = try! NSRegularExpression(
        pattern: "Status:\\s*([A-Za-z_]+)",
        options: [.caseInsensitive]
    )

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?,
                attributes attributeDict: [String : String] = [:]) {
        if elementName == "item" { current = Item() }
        buffer = ""
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        buffer += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        let trimmed = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
        guard current != nil else { return }
        switch elementName {
        case "title":       current?.title = trimmed
        case "link":        current?.link = trimmed
        case "guid":        current?.guid = trimmed
        case "description":
            current?.description = trimmed
            // status keyword extract
            if let match = Self.statusRegex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)),
               let range = Range(match.range(at: 1), in: trimmed) {
                current?.statusKeyword = String(trimmed[range])
            }
        case "pubDate":     current?.pubDate = Self.dateFormatter.date(from: trimmed)
        case "item":
            if let item = current { items.append(item) }
            current = nil
        default: break
        }
        buffer = ""
    }
}
