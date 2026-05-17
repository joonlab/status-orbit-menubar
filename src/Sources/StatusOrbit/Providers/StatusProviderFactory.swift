import Foundation

enum StatusProviderFactory {
    static func makeProvider(for service: ServiceDefinition) -> StatusProvider {
        switch service.kind {
        case .statuspageV2:
            // AI(OpenAI/Anthropic) 는 incidents 도 가져오면 좋아서 summary 사용.
            // Infra 6개는 가벼운 status.json 만.
            let useSummary = (service.category == .ai)
            return StatuspageV2Provider(service: service, useSummary: useSummary)
        case .customStatuspageV2:
            return StatuspageV2Provider(service: service, useSummary: false)
        case .googleCloudIncident:
            return GoogleCloudIncidentProvider(service: service)
        case .xaiRSS:
            return XAIRSSProvider(service: service)
        }
    }
}
