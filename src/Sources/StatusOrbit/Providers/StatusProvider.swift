import Foundation

protocol StatusProvider: Sendable {
    func fetchStatus(using client: HTTPClient) async throws -> ServiceStatus
}
