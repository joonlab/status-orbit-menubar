import Foundation
import SwiftUI

enum StatusLevel: String, Codable, CaseIterable, Sendable, Hashable {
    case operational
    case degradedPerformance = "degraded_performance"
    case degraded
    case major
    case critical
    case maintenance
    case unknown

    var severityRank: Int {
        switch self {
        case .operational:        return 0
        case .maintenance:        return 1
        case .unknown:            return 2
        case .degradedPerformance:return 3
        case .degraded:           return 4
        case .major:              return 5
        case .critical:           return 6
        }
    }

    var displayColor: Color {
        switch self {
        case .operational:        return .green
        case .degradedPerformance:return .yellow
        case .degraded:           return .orange
        case .major, .critical:   return .red
        case .maintenance:        return .blue
        case .unknown:            return .gray
        }
    }

    var koreanLabel: String {
        switch self {
        case .operational:        return "정상"
        case .degradedPerformance:return "느려짐"
        case .degraded:           return "일부 장애"
        case .major:              return "주요 장애"
        case .critical:           return "전면 장애"
        case .maintenance:        return "점검 중"
        case .unknown:            return "확인 불가"
        }
    }

    static func worst(_ levels: [StatusLevel]) -> StatusLevel {
        levels.max(by: { $0.severityRank < $1.severityRank }) ?? .unknown
    }
}
