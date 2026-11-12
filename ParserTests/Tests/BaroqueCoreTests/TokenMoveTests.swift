import Foundation
import XCTest
@testable import BaroqueCore

/// F33: a token an older version left in plain defaults moves into the Keychain (a fake one here: the tests never
/// touch the Mac's Keychain).
final class TokenMoveTests: XCTestCase {
    private let suite = "BaroqueParserTests.TokenMove"
    private let key = "baroque.githubToken"
    private var defaults: UserDefaults!

    private final class FakeVault: TokenVault {
        var stored: String?
        var result: Keychain.WriteResult = .shared
        var readsBack = true
        var writes = 0
        func read() -> String? { stored }
        func write(_ value: String) -> Keychain.WriteResult {
            writes += 1
            if result == .shared, readsBack { stored = value }
            return result
        }
    }

    override func setUp() {
        UserDefaults().removePersistentDomain(forName: suite)
        defaults = UserDefaults(suiteName: suite)!
    }

    override func tearDown() { defaults.removePersistentDomain(forName: suite) }

    func testMovesTheTokenAndRemovesTheCopy() {
        defaults.set("test-token", forKey: key)
        let vault = FakeVault()
        XCTAssertNil(Store.moveToken(defaults: defaults, key: key, vault: vault))
        XCTAssertEqual(vault.stored, "test-token")
        XCTAssertNil(defaults.string(forKey: key))
    }

    func testKeepsTheCopyWhenTheKeychainRefuses() {
        defaults.set("test-token", forKey: key)
        let vault = FakeVault()
        vault.result = .failed(-34018)
        XCTAssertEqual(Store.moveToken(defaults: defaults, key: key, vault: vault), "Couldn't save the token to the Keychain (-34018)")
        XCTAssertEqual(defaults.string(forKey: key), "test-token")
    }

    func testKeepsTheCopyWhenItDoesntReadBack() {
        defaults.set("test-token", forKey: key)
        let vault = FakeVault()
        vault.readsBack = false
        XCTAssertNotNil(Store.moveToken(defaults: defaults, key: key, vault: vault))
        XCTAssertEqual(defaults.string(forKey: key), "test-token")
    }

    func testAKeychainTokenWins() {
        defaults.set("old-token", forKey: key)
        let vault = FakeVault()
        vault.stored = "new-token"
        XCTAssertNil(Store.moveToken(defaults: defaults, key: key, vault: vault))
        XCTAssertEqual(vault.stored, "new-token")
        XCTAssertEqual(vault.writes, 0)
        XCTAssertNil(defaults.string(forKey: key))
    }

    func testNothingToMove() {
        let vault = FakeVault()
        XCTAssertNil(Store.moveToken(defaults: defaults, key: key, vault: vault))
        XCTAssertEqual(vault.writes, 0)
    }
}
