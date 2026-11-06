import Foundation
import Security

// Shared storage between the app and the widget extension via an App Group.
final class Store {
    static let shared = Store()
    static let appGroup = "group.com.ryanfernandez.terra"

    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private enum Key {
        static let settings = "baroque.settings"
        static let daySnapshot = "baroque.daySnapshot"
        static let quoteSnapshot = "baroque.quoteSnapshot"
        static let quoteOffset = "baroque.quoteOffset"
        static let token = "baroque.githubToken"
        static let movedToDailyBrief = "baroque.movedToDailyBrief"
        static let brief = "baroque.brief"
    }

    private init() {
        defaults = UserDefaults(suiteName: Store.appGroup) ?? .standard
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    // MARK: Settings

    var settings: BaroqueSettings {
        get {
            guard let data = defaults.data(forKey: Key.settings),
                  var s = try? decoder.decode(BaroqueSettings.self, from: data) else { return .default }
            // Once: tasks still on the old default list move to the Daily Brief; a list the user chose stays.
            if !defaults.bool(forKey: Key.movedToDailyBrief) {
                defaults.set(true, forKey: Key.movedToDailyBrief)
                if s.taskPaths == BaroqueSettings.masterListTaskPaths {
                    s.taskPaths = BaroqueSettings.default.taskPaths
                    if let data = try? encoder.encode(s) { defaults.set(data, forKey: Key.settings) }
                }
            }
            return s
        }
        set {
            if let data = try? encoder.encode(newValue) {
                defaults.set(data, forKey: Key.settings)
            }
        }
    }

    // MARK: Snapshots (cache for offline widgets)

    var daySnapshot: DaySnapshot? {
        get { load(Key.daySnapshot) }
        set { save(newValue, Key.daySnapshot) }
    }

    var quoteSnapshot: QuoteSnapshot? {
        get { load(Key.quoteSnapshot) }
        set { save(newValue, Key.quoteSnapshot) }
    }

    /// The last Daily Brief the app fetched in full, for its Brief page when offline.
    var brief: BriefSnapshot? {
        get { load(Key.brief) }
        set { save(newValue, Key.brief) }
    }

    var quoteOffset: Int {
        get { defaults.integer(forKey: Key.quoteOffset) }
        set { defaults.set(newValue, forKey: Key.quoteOffset) }
    }

    func bumpQuoteOffset() {
        quoteOffset += 1
    }

    private func load<T: Decodable>(_ key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? decoder.decode(T.self, from: data)
    }

    private func save<T: Encodable>(_ value: T?, _ key: String) {
        guard let value, let data = try? encoder.encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }

    // MARK: GitHub token (Keychain, shared through the app group; falls back to defaults)

    var githubToken: String {
        get {
            if let t = Keychain.read(account: Key.token, group: Store.appGroup), !t.isEmpty { return t }
            return defaults.string(forKey: Key.token) ?? ""
        }
        set {
            let value = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else {
                Keychain.delete(account: Key.token, group: Store.appGroup)
                defaults.removeObject(forKey: Key.token)
                return
            }
            switch Keychain.write(value, account: Key.token, group: Store.appGroup) {
            case .shared:
                defaults.removeObject(forKey: Key.token)
            case .local, .failed:
                // The widget can't read an item outside the shared access group (this happens in the
                // simulator or with an unsigned build), so keep a copy in the App Group defaults.
                defaults.set(value, forKey: Key.token)
            }
        }
    }

    #if DEBUG
    // Back to a fresh-install state: default settings, no caches, no token.
    func resetAll() {
        for key in [Key.settings, Key.daySnapshot, Key.quoteSnapshot, Key.quoteOffset] {
            defaults.removeObject(forKey: key)
        }
        githubToken = ""
    }
    #endif
}

enum Keychain {
    private static let service = "com.ryanfernandez.terra"

    static func read(account: String, group: String) -> String? {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: group,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        var status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecMissingEntitlement || status == errSecParam {
            query.removeValue(forKey: kSecAttrAccessGroup as String)
            status = SecItemCopyMatching(query as CFDictionary, &item)
        }
        guard status == errSecSuccess, let data = item as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    enum WriteResult { case shared, local, failed }

    // .shared means the widget extension can read the item too.
    @discardableResult
    static func write(_ value: String, account: String, group: String) -> WriteResult {
        let data = Data(value.utf8)
        var base: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: group
        ]
        delete(account: account, group: group)
        base[kSecValueData as String] = data
        base[kSecAttrAccessible as String] = kSecAttrAccessibleAfterFirstUnlock
        if SecItemAdd(base as CFDictionary, nil) == errSecSuccess { return .shared }
        base.removeValue(forKey: kSecAttrAccessGroup as String)
        return SecItemAdd(base as CFDictionary, nil) == errSecSuccess ? .local : .failed
    }

    // Removes the item from the shared group and from the app's default group.
    static func delete(account: String, group: String) {
        var query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecAttrAccessGroup as String: group
        ]
        SecItemDelete(query as CFDictionary)
        query.removeValue(forKey: kSecAttrAccessGroup as String)
        SecItemDelete(query as CFDictionary)
    }
}
