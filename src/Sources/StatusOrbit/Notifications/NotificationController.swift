import Foundation
import UserNotifications
import os

@MainActor
final class NotificationController {

    static let shared = NotificationController()

    private let logger = Logger(subsystem: "com.joon.statusorbit", category: "Notify")
    private let center = UNUserNotificationCenter.current()
    private let dedupKey = "aiStatus.notifications.lastNotifiedByServiceAndLevel"
    private let dedupWindow: TimeInterval = 60 * 60  // 1 시간
    private let resend = ResendNotifier()

    /// 첫 실행 시 권한 요청.
    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        do {
            _ = try await center.requestAuthorization(options: [.alert, .sound])
        } catch {
            logger.warning("auth request failed: \(String(describing: error))")
        }
    }

    /// level 변화 알림 + 이메일 발송. dedup + preferences 반영.
    func notifyStatusChange(
        service: ServiceDefinition,
        previous: StatusLevel?,
        current: StatusLevel,
        message: String?
    ) async {
        let prefs = PreferencesStore.shared

        // 회복(→operational) 은 recoveryEnabled 옵션에 따름
        if current == .operational {
            guard prefs.recoveryNotificationsEnabled else { return }
        } else {
            // 단순 operational → unknown 같이 nuisance한 케이스 일부 차단
            if previous == .operational && current == .unknown { return }
        }

        // dedup
        let dedupId = "\(service.id):\(current.rawValue)"
        if !shouldFire(dedupId: dedupId) { return }
        recordFired(dedupId: dedupId)

        let title = "\(service.name): \(current.koreanLabel)"
        let body = message ?? "상태가 \(previous?.koreanLabel ?? "?") → \(current.koreanLabel) 로 변경됨"

        // 1) macOS UserNotification
        if prefs.notificationsEnabled {
            await sendMac(title: title, body: body)
        }

        // 2) Resend 이메일
        if prefs.emailNotificationsEnabled {
            let html = ResendNotifier.formatHTML(
                serviceName: service.name,
                fromLevel: previous,
                toLevel: current,
                message: message
            )
            _ = await resend.send(
                subject: "[Status Orbit] \(service.name) → \(current.koreanLabel)",
                html: html,
                to: prefs.emailRecipient
            )
        }
    }

    /// 테스트 알림 (환경설정 버튼에서 호출)
    func sendTestEmail(to recipient: String) async -> Bool {
        let html = ResendNotifier.formatHTML(
            serviceName: "Status Orbit",
            fromLevel: nil,
            toLevel: .operational,
            message: "이 메일이 보이면 Resend 설정이 정상입니다."
        )
        return await resend.send(subject: "[Status Orbit] 테스트 알림", html: html, to: recipient)
    }

    /// 테스트 macOS 알림 (권한 검증용)
    func sendTestMacNotification() async {
        await sendMac(title: "Status Orbit", body: "macOS 알림이 정상 동작합니다.")
    }

    // MARK: - Private

    private func sendMac(title: String, body: String) async {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        do { try await center.add(request) }
        catch { logger.error("notification failed: \(String(describing: error))") }
    }

    private func shouldFire(dedupId: String) -> Bool {
        let store = UserDefaults.standard
        let map = store.dictionary(forKey: dedupKey) as? [String: Double] ?? [:]
        let last = map[dedupId] ?? 0
        return Date().timeIntervalSince1970 - last > dedupWindow
    }

    private func recordFired(dedupId: String) {
        let store = UserDefaults.standard
        var map = store.dictionary(forKey: dedupKey) as? [String: Double] ?? [:]
        map[dedupId] = Date().timeIntervalSince1970
        store.set(map, forKey: dedupKey)
    }
}
