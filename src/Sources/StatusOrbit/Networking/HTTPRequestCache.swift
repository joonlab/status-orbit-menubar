import Foundation

/// URL 별 마지막 응답 메타데이터 + 본문을 캐싱.
/// 동시에 같은 URL 로 들어온 요청은 단일 Task 로 dedupe.
actor HTTPRequestCache {
    struct Entry: Sendable {
        let response: HTTPResponse
    }

    private var entries: [URL: Entry] = [:]
    private var inFlight: [URL: Task<HTTPResponse, Error>] = [:]

    /// 캐시된 ETag/Last-Modified 를 다음 요청 헤더에 실어 보내기 위한 lookup.
    func entry(for url: URL) -> Entry? {
        entries[url]
    }

    /// 같은 URL 동시 요청을 하나로 합친다.
    func taskOrCreate(
        for url: URL,
        create: @Sendable @escaping () async throws -> HTTPResponse
    ) -> Task<HTTPResponse, Error> {
        if let existing = inFlight[url] { return existing }

        let task = Task<HTTPResponse, Error> {
            defer {
                Task { await self.clearInFlight(for: url) }
            }
            return try await create()
        }
        inFlight[url] = task
        return task
    }

    func update(_ entry: Entry, for url: URL) {
        entries[url] = entry
    }

    private func clearInFlight(for url: URL) {
        inFlight.removeValue(forKey: url)
    }
}
