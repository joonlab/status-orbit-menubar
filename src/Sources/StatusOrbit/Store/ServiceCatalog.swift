import Foundation

enum ServiceCatalog {

    static let defaults: [ServiceDefinition] = [
        // ============================================================
        // AI (5)
        // ============================================================
        ServiceDefinition(
            id: "openai", name: "ChatGPT",
            category: .ai, kind: .statuspageV2,
            baseURL: URL(string: "https://status.openai.com")!,
            homepageURL: URL(string: "https://status.openai.com")!
        ),
        ServiceDefinition(
            id: "anthropic", name: "Claude",
            category: .ai, kind: .statuspageV2,
            baseURL: URL(string: "https://status.claude.com")!,
            homepageURL: URL(string: "https://status.claude.com")!
        ),
        ServiceDefinition(
            id: "gemini", name: "Gemini",
            category: .ai, kind: .googleCloudIncident,
            baseURL: URL(string: "https://www.google.com/appsstatus/dashboard/")!,
            homepageURL: URL(string: "https://www.google.com/appsstatus/dashboard/")!,
            productIds: ["Gemini", "Gemini API", "Gemini App", "Google AI Studio"]
        ),
        ServiceDefinition(
            id: "notebooklm", name: "NotebookLM",
            category: .ai, kind: .googleCloudIncident,
            baseURL: URL(string: "https://www.google.com/appsstatus/dashboard/")!,
            homepageURL: URL(string: "https://www.google.com/appsstatus/dashboard/")!,
            productIds: ["NotebookLM"]
        ),
        ServiceDefinition(
            id: "grok", name: "Grok",
            category: .ai, kind: .xaiRSS,
            baseURL: URL(string: "https://status.x.ai/feed.xml")!,
            homepageURL: URL(string: "https://status.x.ai/")!
        ),

        // ============================================================
        // Infrastructure (6)
        // ============================================================
        ServiceDefinition(
            id: "github", name: "GitHub",
            category: .infrastructure, kind: .statuspageV2,
            baseURL: URL(string: "https://www.githubstatus.com")!,
            homepageURL: URL(string: "https://www.githubstatus.com")!
        ),
        ServiceDefinition(
            id: "vercel", name: "Vercel",
            category: .infrastructure, kind: .statuspageV2,
            baseURL: URL(string: "https://www.vercel-status.com")!,
            homepageURL: URL(string: "https://www.vercel-status.com")!
        ),
        ServiceDefinition(
            id: "cloudflare", name: "Cloudflare",
            category: .infrastructure, kind: .statuspageV2,
            baseURL: URL(string: "https://www.cloudflarestatus.com")!,
            homepageURL: URL(string: "https://www.cloudflarestatus.com")!
        ),
        ServiceDefinition(
            id: "supabase", name: "Supabase",
            category: .infrastructure, kind: .statuspageV2,
            baseURL: URL(string: "https://status.supabase.com")!,
            homepageURL: URL(string: "https://status.supabase.com")!
        ),
        ServiceDefinition(
            id: "netlify", name: "Netlify",
            category: .infrastructure, kind: .statuspageV2,
            baseURL: URL(string: "https://www.netlifystatus.com")!,
            homepageURL: URL(string: "https://www.netlifystatus.com")!
        )
        // Railway 는 공개 statuspage v2 endpoint 가 없는 자체 SPA 시스템이므로 제외.
        // 향후 전용 provider 작성 후 seed evolution 시 재포함 예정.
    ]
}
