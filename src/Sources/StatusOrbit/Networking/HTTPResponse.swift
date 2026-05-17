import Foundation

struct HTTPResponse: Sendable {
    let data: Data
    let etag: String?
    let lastModified: String?
    let statusCode: Int
    let fetchedAt: Date

    var isNotModified: Bool { statusCode == 304 }
}
