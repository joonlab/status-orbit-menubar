import SwiftUI
import AppKit
import ServiceManagement
import UserNotifications

struct PreferencesView: View {
    @ObservedObject var store: StatusStore
    @ObservedObject var prefs: PreferencesStore = .shared

    @State private var resendKeyInput: String = ""
    @State private var hasKey: Bool = KeychainHelper.get("resend") != nil
    @State private var launchAtLogin: Bool = false
    @State private var notifAuthStatus: UNAuthorizationStatus = .notDetermined
    @State private var testStatus: String = ""

    var body: some View {
        TabView {
            servicesTab.tabItem { Label("서비스", systemImage: "globe") }
            notificationsTab.tabItem { Label("알림", systemImage: "bell") }
            generalTab.tabItem { Label("일반", systemImage: "gear") }
        }
        .frame(width: 520, height: 460)
        .task { await refreshStates() }
    }

    // MARK: - Services Tab

    private var servicesTab: some View {
        Form {
            Section(header: Text("AI")) {
                ForEach(ServiceCatalog.defaults.filter { $0.category == .ai }) { svc in
                    Toggle(svc.name, isOn: bindingFor(svc))
                }
            }
            Section(header: Text("Infrastructure")) {
                ForEach(ServiceCatalog.defaults.filter { $0.category == .infrastructure }) { svc in
                    Toggle(svc.name, isOn: bindingFor(svc))
                }
            }
        }
        .formStyle(.grouped)
    }

    private func bindingFor(_ svc: ServiceDefinition) -> Binding<Bool> {
        Binding(
            get: { prefs.isEnabled(svc.id) },
            set: { prefs.setEnabled($0, for: svc.id) }
        )
    }

    // MARK: - Notifications Tab

    private var notificationsTab: some View {
        Form {
            Section(header: Text("macOS 알림")) {
                Toggle("상태 변경 시 알림", isOn: $prefs.notificationsEnabled)
                Toggle("회복(→정상) 알림도 받기", isOn: $prefs.recoveryNotificationsEnabled)
                HStack {
                    Text("권한:")
                    Text(authStatusLabel)
                        .foregroundStyle(notifAuthStatus == .authorized ? .green : .orange)
                    Spacer()
                    Button("테스트 알림") {
                        Task {
                            await NotificationController.shared.sendTestMacNotification()
                            testStatus = "✅ macOS 알림 발송"
                        }
                    }
                }
            }
            Section(header: Text("이메일 알림 (Resend)")) {
                Toggle("이메일 알림 보내기", isOn: $prefs.emailNotificationsEnabled)
                TextField("수신 이메일", text: $prefs.emailRecipient)
                    .textFieldStyle(.roundedBorder)
                HStack {
                    SecureField(hasKey ? "•••••••• (저장됨)" : "Resend API 키 입력 (re_...)",
                                text: $resendKeyInput)
                        .textFieldStyle(.roundedBorder)
                    Button("저장") {
                        let trimmed = resendKeyInput.trimmingCharacters(in: .whitespaces)
                        guard !trimmed.isEmpty else { return }
                        KeychainHelper.set(trimmed, for: "resend")
                        resendKeyInput = ""
                        hasKey = true
                        testStatus = "🔐 Keychain 저장 완료"
                    }
                    if hasKey {
                        Button("삭제") {
                            KeychainHelper.delete("resend")
                            hasKey = false
                            testStatus = "키 삭제됨"
                        }
                        .foregroundStyle(.red)
                    }
                }
                HStack {
                    Spacer()
                    Button("테스트 이메일 발송") {
                        Task {
                            let ok = await NotificationController.shared.sendTestEmail(to: prefs.emailRecipient)
                            testStatus = ok ? "✉️ 발송 성공" : "❌ 발송 실패 (콘솔 확인)"
                        }
                    }
                    .disabled(!hasKey || prefs.emailRecipient.isEmpty)
                }
            }
            if !testStatus.isEmpty {
                Text(testStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section(header: Text("폴링")) {
                Picker("주기", selection: $prefs.pollIntervalSeconds) {
                    Text("30초").tag(30)
                    Text("60초").tag(60)
                    Text("2분").tag(120)
                    Text("5분").tag(300)
                }
                .pickerStyle(.segmented)
                Text("변경은 앱 재시작 후 적용됩니다.")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Section(header: Text("자동 시작")) {
                Toggle("로그인 시 자동 시작", isOn: Binding(
                    get: { launchAtLogin },
                    set: { setLaunchAtLogin($0) }
                ))
            }
            Section(header: Text("데이터")) {
                Button("이력 DB 파일 위치 열기") {
                    if let url = try? IncidentDatabase.databaseURL() {
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    }
                }
            }
            Section(header: Text("정보")) {
                LabeledContent("버전", value: "0.1.0")
                LabeledContent("종합 상태", value: store.aggregateLevel.koreanLabel)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Helpers

    private var authStatusLabel: String {
        switch notifAuthStatus {
        case .authorized:     return "허용됨"
        case .denied:         return "거부됨 (시스템 설정에서 변경)"
        case .notDetermined:  return "미결정"
        case .provisional:    return "임시 허용"
        case .ephemeral:      return "일시적"
        @unknown default:     return "—"
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
            launchAtLogin = enabled
        } catch {
            testStatus = "자동시작 변경 실패: \(error.localizedDescription)"
        }
    }

    private func refreshStates() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        await MainActor.run {
            notifAuthStatus = settings.authorizationStatus
            launchAtLogin = SMAppService.mainApp.status == .enabled
        }
    }
}
