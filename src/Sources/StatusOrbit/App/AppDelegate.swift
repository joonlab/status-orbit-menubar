import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private let store = StatusStore()
    private var cancellables = Set<AnyCancellable>()
    private var preferencesWindow: NSWindow?
    private var historyWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        configureStatusItem()
        configurePopover()
        subscribeToStore()

        // 권한 요청 + 첫 fetch + 60초 polling
        Task { @MainActor in
            await NotificationController.shared.requestAuthorizationIfNeeded()
            await store.refresh()
            store.startAutoRefresh(intervalSeconds: PreferencesStore.shared.pollIntervalSeconds)
        }
    }

    // MARK: - Status Item (메뉴바 아이콘)

    private func configureStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = item.button {
            button.image = StatusIconRenderer.makeDotIcon(level: .unknown)
            button.image?.isTemplate = false
            button.toolTip = "Status Orbit (loading…)"
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        self.statusItem = item
    }

    private func configurePopover() {
        let pop = NSPopover()
        pop.behavior = .transient
        pop.contentSize = NSSize(width: 340, height: 480)
        pop.contentViewController = NSHostingController(
            rootView: MenuBarView(
                store: store,
                onOpenSettings: { [weak self] in self?.showPreferences() },
                onOpenHistory: { [weak self] in self?.showHistory() }
            )
        )
        self.popover = pop
    }

    // MARK: - Windows

    @objc func showPreferences() {
        popover?.performClose(nil)
        if preferencesWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 520, height: 460),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered, defer: false
            )
            window.title = "환경설정"
            window.contentViewController = NSHostingController(rootView: PreferencesView(store: store))
            window.center()
            window.isReleasedWhenClosed = false
            self.preferencesWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        preferencesWindow?.makeKeyAndOrderFront(nil)
    }

    @objc func showHistory() {
        popover?.performClose(nil)
        if historyWindow == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 520),
                styleMask: [.titled, .closable, .miniaturizable, .resizable],
                backing: .buffered, defer: false
            )
            window.title = "Status Orbit — 이력"
            window.contentViewController = NSHostingController(rootView: HistoryView(store: store))
            window.center()
            window.isReleasedWhenClosed = false
            self.historyWindow = window
        }
        NSApp.activate(ignoringOtherApps: true)
        historyWindow?.makeKeyAndOrderFront(nil)
    }

    private func subscribeToStore() {
        store.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.refreshIconAndTooltip()
            }
            .store(in: &cancellables)
    }

    private func refreshIconAndTooltip() {
        guard let button = statusItem?.button else { return }
        let level = store.aggregateLevel
        button.image = StatusIconRenderer.makeDotIcon(level: level)
        button.image?.isTemplate = false

        let count = store.services.filter(\.enabled).count
        let ok = store.statuses.values.filter { $0.level == .operational }.count
        button.toolTip = "Status Orbit · \(ok)/\(count) 정상 · 종합: \(level.koreanLabel)"
    }

    // MARK: - Popover toggle

    @objc private func togglePopover(_ sender: Any?) {
        guard let button = statusItem?.button, let pop = popover else { return }

        if pop.isShown {
            pop.performClose(sender)
        } else {
            pop.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            pop.contentViewController?.view.window?.becomeKey()
        }
    }
}

