import Foundation
import Security

// Shared storage between the app and the widget extension via an App Group.
final class Store {
    static let shared: Store = {
        let store = Store(defaults: UserDefaults(suiteName: Store.appGroup) ?? .standard)
        #if os(iOS) && !targetEnvironment(simulator)
        // A token an older version kept in the App Group defaults moves into the Keychain.
        store.tokenProblem = Store.moveToken(defaults: store.defaults, key: Key.token,
                                             vault: SharedKeychain(account: Key.token, group: Store.appGroup))
        #endif
        return store
    }()
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

    /// `Store.shared` everywhere; tests make their own on a throwaway suite.
    init(defaults: UserDefaults) {
        self.defaults = defaults
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

    // MARK: GitHub token (the Keychain, shared with the widget through the app group)

    /// Why the token isn't kept safely (the Keychain refused it), for the app to say; nil when all is well.
    private(set) var tokenProblem: String?

    var githubToken: String {
        get {
            if let t = Keychain.read(account: Key.token, group: Store.appGroup), !t.isEmpty { return t }
            // The simulator's copy, or one an older version left on a device that couldn't be moved yet.
            return defaults.string(forKey: Key.token) ?? ""
        }
        set { saveGitHubToken(newValue) }
    }

    /// Saves (or, when empty, removes) the token and returns `tokenProblem`. On a device the token goes only into
    /// the Keychain: if the Keychain refuses it, nothing is kept in plain defaults and the problem says why.
    @discardableResult
    func saveGitHubToken(_ token: String) -> String? {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            Keychain.delete(account: Key.token, group: Store.appGroup)
            defaults.removeObject(forKey: Key.token)
            tokenProblem = nil
            return nil
        }
        let result = Keychain.write(value, account: Key.token, group: Store.appGroup)
        if result == .shared {
            defaults.removeObject(forKey: Key.token)
            tokenProblem = nil
        } else {
            #if targetEnvironment(simulator)
            // The widget can't read an item outside the shared access group (this happens in the simulator), so
            // keep a copy in the App Group defaults there.
            defaults.set(value, forKey: Key.token)
            tokenProblem = nil
            #else
            // Never in plain defaults on a device; an older copy there would be the wrong token now.
            defaults.removeObject(forKey: Key.token)
            tokenProblem = Store.keychainProblem(result)
            #endif
        }
        return tokenProblem
    }

    static func keychainProblem(_ result: Keychain.WriteResult) -> String {
        if case .failed(let status) = result { return "Couldn't save the token to the Keychain (\(status))" }
        return "Couldn't save the token to the Keychain"
    }

    /// A token left in plain defaults (by an older version) moves into the Keychain. The defaults copy is removed
    /// only once the Keychain holds a token that reads back. Returns the problem to show when the Keychain refused it.
    @discardableResult
    static func moveToken(defaults: UserDefaults, key: String, vault: TokenVault) -> String? {
        guard let old = defaults.string(forKey: key)?.trimmingCharacters(in: .whitespacesAndNewlines), !old.isEmpty else {
            return nil
        }
        // The Keychain already has one: it's read first, so the defaults copy was never used.
        if let current = vault.read(), !current.isEmpty {
            defaults.removeObject(forKey: key)
            return nil
        }
        let result = vault.write(old)
        guard result == .shared, vault.read() == old else { return keychainProblem(result) }
        defaults.removeObject(forKey: key)
        return nil
    }

    #if DEBUG
    // Back to a fresh-install state: default settings, no caches, no token.
    func resetAll() {
        for key in [Key.settings, Key.daySnapshot, Key.quoteSnapshot, Key.quoteOffset, Key.brief, Key.movedToDailyBrief] {
            defaults.removeObject(forKey: key)
        }
        githubToken = ""
    }
    #endif
}

/// Where the token is kept, as the move out of defaults sees it (tests pass a fake rather than touch the Keychain).
protocol TokenVault {
    func read() -> String?
    func write(_ value: String) -> Keychain.WriteResult
}

struct SharedKeychain: TokenVault {
    var account: String
    var group: String
    func read() -> String? { Keychain.read(account: account, group: group) }
    func write(_ value: String) -> Keychain.WriteResult { Keychain.write(value, account: account, group: group) }
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

    /// .shared means the widget extension can read the item too; .local (simulator only) that only the app can;
    /// .failed carries the shared write's status.
    enum WriteResult: Equatable { case shared, local, failed(OSStatus) }

    // Outside the simulator there's no second try without the group: on a device such an item is never read back
    // (the group query finds nothing rather than failing), so it would only hide the failure.
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
        let status = SecItemAdd(base as CFDictionary, nil)
        if status == errSecSuccess { return .shared }
        #if targetEnvironment(simulator)
        base.removeValue(forKey: kSecAttrAccessGroup as String)
        if SecItemAdd(base as CFDictionary, nil) == errSecSuccess { return .local }
        #endif
        return .failed(status)
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
