import Foundation

/// Provider 종류. Seed v1 ontology 에서는 11개 서비스별로 case를 가질 수도 있다고
/// 정의했으나, 구현 효율을 위해 *형식(format) 기준으로* 4 가지로 압축한다.
/// 동일 형식 (statuspageV2) 의 서비스 6 개(GitHub/Vercel/Cloudflare/Supabase/Netlify/Railway)
/// 는 모두 `.statuspageV2` 를 공유하고 `ServiceDefinition.baseURL` 로 구분한다.
/// 이 단순화는 Stage 4 Evaluate 에서 ontology drift 후보로 평가될 수 있다.
enum ServiceKind: String, Codable, CaseIterable, Sendable, Hashable {
    case statuspageV2          // OpenAI, Anthropic, GitHub, Vercel, Cloudflare, Supabase, Netlify, Railway
    case customStatuspageV2    // 원본 형식 변종 보존용 (예비)
    case googleCloudIncident   // Gemini, NotebookLM
    case xaiRSS                // Grok
}
