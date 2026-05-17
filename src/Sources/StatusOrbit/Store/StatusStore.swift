import Foundation
import Combine
import os

@MainActor
final class StatusStore: ObservableObject {

    @Published private(set) var services: [ServiceDefinition]
    @Published private(set) var statuses: [String: ServiceStatus] = [:]
    @Published private(set) var isRefreshing: Bool = false
    @Published private(set) var lastRefreshAt: Date?

    private let client: HTTPClient
    private let logger = Logger(subsystem: "com.joon.statusorbit", category: "StatusStore")
    private var pollingTask: Task<Void, Never>?

    init(services: [ServiceDefinition] = ServiceCatalog.defaults,
         client: HTTPClient = HTTPClient()) {
        self.services = services
        self.client = client
    }

    /// 종합 색상 — 모든 enabled 서비스의 worst level
    var aggregateLevel: StatusLevel {
        let levels = services
            .filter(\.enabled)
            .compactMap { statuses[$0.id]?.level }
        guard !levels.isEmpty else { return .unknown }
        return StatusLevel.worst(levels)
    }

    /// 카테고리별 그룹 — PreferencesStore.disabledServiceIds 도 반영
    func services(in category: ServiceCategory) -> [ServiceDefinition] {
        let prefs = PreferencesStore.shared
        return services.filter {
            $0.category == category && $0.enabled && prefs.isEnabled($0.id)
        }
    }

    func startAutoRefresh(intervalSeconds: Int = 60) {
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                _ = await self.refresh()
                try? await Task.sleep(nanoseconds: UInt64(intervalSeconds) * 1_000_000_000)
            }
        }
    }

    func stopAutoRefresh() {
        pollingTask?.cancel()
        pollingTask = nil
    }

    @discardableResult
    func refresh() async -> Int {
        guard !isRefreshing else { return 0 }
        isRefreshing = true
        defer { isRefreshing = false }

        let prefs = PreferencesStore.shared
        let enabled = services.filter { $0.enabled && prefs.isEnabled($0.id) }
        let client = self.client

        let results = await withTaskGroup(of: (String, ServiceStatus?).self,
                                          returning: [(String, ServiceStatus?)].self) { group in
            for svc in enabled {
                group.addTask {
                    let provider = StatusProviderFactory.makeProvider(for: svc)
                    do {
                        let status = try await provider.fetchStatus(using: client)
                        return (svc.id, status)
                    } catch {
                        return (svc.id, ServiceStatus.unknown(serviceId: svc.id,
                                                              reason: "\(error)"))
                    }
                }
            }
            var collected: [(String, ServiceStatus?)] = []
            for await item in group { collected.append(item) }
            return collected
        }

        let db = IncidentDatabase.shared
        let notifier = NotificationController.shared
        var updated = statuses
        var changeCount = 0
        for (id, st) in results {
            guard let st else { continue }
            let prev = updated[id]?.level
            if prev != st.level {
                changeCount += 1
                if let svc = services.first(where: { $0.id == id }) {
                    db.recordLevelChange(
                        serviceId: id,
                        toLevel: st.level,
                        message: st.message,
                        category: svc.category,
                        at: st.fetchedAt
                    )
                    // 첫 polling (prev=nil) 은 알림 안 보냄 — 새 설치 시 11개 동시 알림 방지
                    if prev != nil {
                        await notifier.notifyStatusChange(
                            service: svc,
                            previous: prev,
                            current: st.level,
                            message: st.message
                        )
                    }
                }
            }
            updated[id] = st
        }
        statuses = updated
        lastRefreshAt = Date()

        logger.info("refresh complete: \(enabled.count) services, \(changeCount) changes")
        return changeCount
    }
}
