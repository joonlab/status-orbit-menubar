import SwiftUI
import AppKit

@main
struct StatusOrbitApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // LSUIElement=true (Info.plist) 이므로 윈도우 없음 — 메뉴바 + popover 만 사용.
        // 빈 Settings Scene 은 macOS 14+ 의 자동 메뉴 항목 제거를 위해 의도적으로 둔다.
        Settings {
            EmptyView()
        }
    }
}
