import Foundation
import Combine

@MainActor
final class PreferencesStore: ObservableObject {

    static let shared = PreferencesStore()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let notif      = "aiStatus.notifications.enabled"
        static let recov      = "aiStatus.notifications.recoveryEnabled"
        static let email      = "aiStatus.notifications.emailEnabled"
        static let recipient  = "aiStatus.notifications.emailRecipient"
        static let poll       = "aiStatus.polling.normalIntervalSeconds"
        static let disabledIds = "aiStatus.services.disabledIds"
    }

    @Published var notificationsEnabled: Bool {
        didSet { defaults.set(notificationsEnabled, forKey: Key.notif) }
    }
    @Published var recoveryNotificationsEnabled: Bool {
        didSet { defaults.set(recoveryNotificationsEnabled, forKey: Key.recov) }
    }
    @Published var emailNotificationsEnabled: Bool {
        didSet { defaults.set(emailNotificationsEnabled, forKey: Key.email) }
    }
    @Published var emailRecipient: String {
        didSet { defaults.set(emailRecipient, forKey: Key.recipient) }
    }
    @Published var pollIntervalSeconds: Int {
        didSet { defaults.set(pollIntervalSeconds, forKey: Key.poll) }
    }
    @Published var disabledServiceIds: Set<String> {
        didSet { defaults.set(Array(disabledServiceIds), forKey: Key.disabledIds) }
    }

    private init() {
        defaults.register(defaults: [
            Key.notif:      true,
            Key.recov:      false,
            Key.email:      false,
            Key.recipient:  "wns9133@gmail.com",
            Key.poll:       60,
            Key.disabledIds: [] as [String]
        ])
        self.notificationsEnabled         = defaults.bool(forKey: Key.notif)
        self.recoveryNotificationsEnabled = defaults.bool(forKey: Key.recov)
        self.emailNotificationsEnabled    = defaults.bool(forKey: Key.email)
        self.emailRecipient               = defaults.string(forKey: Key.recipient) ?? "wns9133@gmail.com"
        self.pollIntervalSeconds          = defaults.integer(forKey: Key.poll)
        let arr = defaults.array(forKey: Key.disabledIds) as? [String] ?? []
        self.disabledServiceIds           = Set(arr)
    }

    func isEnabled(_ serviceId: String) -> Bool {
        !disabledServiceIds.contains(serviceId)
    }

    func setEnabled(_ enabled: Bool, for serviceId: String) {
        if enabled {
            disabledServiceIds.remove(serviceId)
        } else {
            disabledServiceIds.insert(serviceId)
        }
    }
}
