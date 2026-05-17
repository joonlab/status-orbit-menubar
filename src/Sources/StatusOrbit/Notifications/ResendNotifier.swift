import Foundation
import os

/// Resend HTTP API 로 이메일 발송.
/// API 키는 Keychain (account="resend") 에서 read.
/// 실패해도 silent — UI 흐름을 막지 않는다.
struct ResendNotifier: Sendable {

    static let endpoint = URL(string: "https://api.resend.com/emails")!
    // 발송 도메인은 본인 Resend 계정에서 인증한 도메인으로 변경 (DKIM/SPF 필수).
    // 환경설정 UI 에서 변경 가능하게 PreferencesStore.emailRecipient 도 함께 사용.
    static let from = "Status Orbit <alerts@example.com>"
    static let defaultTo = "you@example.com"  // 첫 실행 후 환경설정에서 본인 이메일로 변경

    let logger = Logger(subsystem: "com.joon.statusorbit", category: "ResendNotifier")

    func send(subject: String, html: String, to recipient: String = ResendNotifier.defaultTo) async -> Bool {
        guard let key = KeychainHelper.get("resend"), !key.isEmpty else {
            logger.warning("Resend key missing in keychain — skip")
            return false
        }

        let payload: [String: Any] = [
            "from": Self.from,
            "to":   [recipient],
            "subject": subject,
            "html": html
        ]
        guard let body = try? JSONSerialization.data(withJSONObject: payload) else {
            return false
        }

        var req = URLRequest(url: Self.endpoint)
        req.httpMethod = "POST"
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = body
        req.timeoutInterval = 10

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse else { return false }
            if (200..<300).contains(http.statusCode) {
                logger.info("Resend OK (\(http.statusCode))")
                return true
            } else {
                let snippet = String(data: data, encoding: .utf8)?.prefix(200) ?? ""
                logger.error("Resend FAIL \(http.statusCode): \(snippet, privacy: .public)")
                return false
            }
        } catch {
            logger.error("Resend network error: \(String(describing: error))")
            return false
        }
    }

    static func formatHTML(serviceName: String, fromLevel: StatusLevel?, toLevel: StatusLevel,
                           message: String?, at: Date = Date()) -> String {
        let dateStr = ISO8601DateFormatter().string(from: at)
        let color: String
        switch toLevel {
        case .operational:        color = "#22c55e"
        case .degradedPerformance:color = "#eab308"
        case .degraded:           color = "#f97316"
        case .major, .critical:   color = "#ef4444"
        case .maintenance:        color = "#3b82f6"
        case .unknown:            color = "#9ca3af"
        }
        let fromTxt = fromLevel.map { "<code>\($0.koreanLabel)</code> → " } ?? ""
        let msgRow  = message.map { "<p style=\"color:#555\">\($0)</p>" } ?? ""
        return """
        <!doctype html>
        <html><body style="font-family:-apple-system,BlinkMacSystemFont,sans-serif;max-width:520px;margin:24px auto;color:#222">
          <h2 style="margin:0 0 4px 0">🛰️ Status Orbit</h2>
          <p style="color:#666;margin:0 0 16px 0">\(dateStr)</p>
          <div style="padding:14px;border-radius:8px;background:#f7f7f8;border-left:4px solid \(color)">
            <p style="margin:0;font-size:16px"><b>\(serviceName)</b></p>
            <p style="margin:6px 0 0 0;font-size:14px">상태: \(fromTxt)<code style="background:\(color);color:white;padding:2px 6px;border-radius:4px">\(toLevel.koreanLabel)</code></p>
            \(msgRow)
          </div>
          <p style="color:#888;font-size:12px;margin-top:16px">Status Orbit v0.1.0 · 본 메일은 자동 발송됨</p>
        </body></html>
        """
    }
}
