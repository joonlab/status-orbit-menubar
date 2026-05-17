import Foundation

struct ServiceDefinition: Codable, Hashable, Identifiable, Sendable {
    let id: String
    let name: String
    let category: ServiceCategory
    let kind: ServiceKind
    let baseURL: URL
    let homepageURL: URL
    var enabled: Bool
    var pollIntervalSeconds: Int

    /// Google Cloud Incident provider 가 필터링할 product id 목록
    /// (예: Gemini → ["Gemini API", "Gemini App"], NotebookLM → ["NotebookLM"])
    let productIds: [String]
    let keywords: [String]

    init(
        id: String,
        name: String,
        category: ServiceCategory,
        kind: ServiceKind,
        baseURL: URL,
        homepageURL: URL,
        enabled: Bool = true,
        pollIntervalSeconds: Int = 60,
        productIds: [String] = [],
        keywords: [String] = []
    ) {
        self.id = id
        self.name = name
        self.category = category
        self.kind = kind
        self.baseURL = baseURL
        self.homepageURL = homepageURL
        self.enabled = enabled
        self.pollIntervalSeconds = pollIntervalSeconds
        self.productIds = productIds
        self.keywords = keywords
    }
}
