import Foundation
import os

enum HTTPClientError: Error {
    case invalidResponse
    case httpError(status: Int)
    case timeout
}

final class HTTPClient: @unchecked Sendable {

    private let session: URLSession
    private let cache: HTTPRequestCache
    private let logger = Logger(subsystem: "com.joon.statusorbit", category: "HTTPClient")

    init(timeout: TimeInterval = 15) {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = timeout
        cfg.timeoutIntervalForResource = timeout * 2
        cfg.httpAdditionalHeaders = [
            "User-Agent": "StatusOrbit/0.1.0 (+https://github.com/joonlab)",
            "Accept": "application/json,text/html,application/rss+xml;q=0.9,*/*;q=0.8"
        ]
        self.session = URLSession(configuration: cfg)
        self.cache = HTTPRequestCache()
    }

    func get(_ url: URL, headers: [String: String] = [:]) async throws -> HTTPResponse {
        let task = await cache.taskOrCreate(for: url) { [weak self] in
            guard let self else { throw HTTPClientError.invalidResponse }
            return try await self.performFetch(url: url, headers: headers)
        }
        return try await task.value
    }

    // MARK: - Private

    private func performFetch(url: URL, headers: [String: String]) async throws -> HTTPResponse {
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        for (k, v) in headers { req.setValue(v, forHTTPHeaderField: k) }

        // ETag/Last-Modified replay (조건부 요청)
        if let cached = await cache.entry(for: url) {
            if let etag = cached.response.etag {
                req.setValue(etag, forHTTPHeaderField: "If-None-Match")
            }
            if let lm = cached.response.lastModified {
                req.setValue(lm, forHTTPHeaderField: "If-Modified-Since")
            }
        }

        let (data, response) = try await session.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }

        // 304 Not Modified — 캐시된 body 재사용
        if http.statusCode == 304, let cached = await cache.entry(for: url) {
            logger.debug("304 \(url.absoluteString, privacy: .public) — reusing \(cached.response.data.count) bytes")
            let fresh = HTTPResponse(
                data: cached.response.data,
                etag: cached.response.etag,
                lastModified: cached.response.lastModified,
                statusCode: 304,
                fetchedAt: Date()
            )
            return fresh
        }

        guard (200..<300).contains(http.statusCode) else {
            throw HTTPClientError.httpError(status: http.statusCode)
        }

        let etag = http.value(forHTTPHeaderField: "Etag") ?? http.value(forHTTPHeaderField: "ETag")
        let lastMod = http.value(forHTTPHeaderField: "Last-Modified")

        let resp = HTTPResponse(
            data: data,
            etag: etag,
            lastModified: lastMod,
            statusCode: http.statusCode,
            fetchedAt: Date()
        )
        await cache.update(.init(response: resp), for: url)
        return resp
    }
}
