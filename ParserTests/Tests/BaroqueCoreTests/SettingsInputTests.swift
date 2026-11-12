import Foundation
import XCTest
@testable import BaroqueCore

/// The settings form's typed text (F22) and the location setting (F23).
final class SettingsInputTests: XCTestCase {
    private func latitude(_ text: String) -> Double? { SettingsInput.coordinate(text, range: SettingsInput.latitudes) }
    private func longitude(_ text: String) -> Double? { SettingsInput.coordinate(text, range: SettingsInput.longitudes) }

    private func repo(_ owner: String, _ repo: String) -> String? {
        SettingsInput.repository(owner: owner, repo: repo).map { "\($0.owner)/\($0.repo)" }
    }

    // MARK: Coordinates

    func testCommaDecimal() {
        XCTAssertEqual(latitude("48,8566"), 48.8566)
    }

    func testOutOfRange() {
        XCTAssertNil(latitude("95"))
        XCTAssertNil(latitude("-90.5"))
        XCTAssertNil(longitude("181"))
        XCTAssertEqual(longitude("95"), 95)
    }

    func testNotANumber() {
        XCTAssertNil(latitude("abc"))
        XCTAssertNil(latitude(""))
        XCTAssertNil(latitude("1,234.5"))
        XCTAssertNil(latitude("nan"))
    }

    func testOrdinaryCoordinates() {
        XCTAssertEqual(longitude(" -118.2437 "), -118.2437)
        XCTAssertEqual(latitude("\u{2212}33.9"), -33.9)   // a typographic minus
        XCTAssertEqual(latitude("34.05°"), 34.05)
        XCTAssertEqual(latitude("90"), 90)
    }

    // MARK: Repository

    func testGitHubLink() {
        XCTAssertEqual(repo("", "https://github.com/someone/vault"), "someone/vault")
        XCTAssertEqual(repo("someone", "https://github.com/someone/vault.git"), "someone/vault")
        XCTAssertEqual(repo("", "github.com/someone/vault/tree/main"), "someone/vault")
        XCTAssertEqual(repo("", "https://www.github.com/someone/vault/"), "someone/vault")
        XCTAssertEqual(repo("", "git@github.com:someone/vault.git"), "someone/vault")
        XCTAssertEqual(repo("https://github.com/someone", "vault"), "someone/vault")
    }

    func testOwnerSlashRepo() {
        XCTAssertEqual(repo("", "someone/vault"), "someone/vault")
        XCTAssertEqual(repo("someone/vault", ""), "someone/vault")
        XCTAssertEqual(repo("someone", "someone/vault"), "someone/vault")
    }

    func testPlainNamesStayAsTheyAre() {
        XCTAssertEqual(repo(" someone ", "my-vault.backup"), "someone/my-vault.backup")
        XCTAssertEqual(repo("someone", "vault.git"), "someone/vault")
        XCTAssertEqual(repo("", ""), "/", "empty fields stay empty")
    }

    func testNotARepository() {
        XCTAssertNil(repo("some one", "vault"))
        XCTAssertNil(repo("someone", "my vault"))
        XCTAssertNil(repo("someone", ".."))
    }

    // MARK: The whole form

    func testValidInputIsCleanedAndSetsTheLocation() throws {
        var s = BaroqueSettings.default
        s.githubRepo = "https://github.com/someone/vault"
        let out = try SettingsInput.apply(latitude: "48,8566", longitude: "2,3522", to: s).get()
        XCTAssertEqual(out.latitude, 48.8566)
        XCTAssertEqual(out.longitude, 2.3522)
        XCTAssertTrue(out.locationSet)
        XCTAssertEqual(out.githubOwner, "someone")
        XCTAssertEqual(out.githubRepo, "vault")
    }

    func testBadInputIsNotSaved() {
        let s = BaroqueSettings.default
        XCTAssertEqual(failure(SettingsInput.apply(latitude: "95", longitude: "0", to: s)), .latitude)
        XCTAssertEqual(failure(SettingsInput.apply(latitude: "abc", longitude: "0", to: s)), .latitude)
        XCTAssertEqual(failure(SettingsInput.apply(latitude: "10", longitude: "200", to: s)), .longitude)
        XCTAssertEqual(failure(SettingsInput.apply(latitude: "10", longitude: "", to: s)), .longitude, "both or neither")
        var bad = s
        bad.githubOwner = "some one"
        XCTAssertEqual(failure(SettingsInput.apply(latitude: "", longitude: "", to: bad)), .repository)
    }

    func testEmptyCoordinatesMeanNoLocation() throws {
        var s = BaroqueSettings.default
        s.locationSet = true
        let out = try SettingsInput.apply(latitude: " ", longitude: "", to: s).get()
        XCTAssertFalse(out.locationSet)
    }

    func testFieldsAreEmptyUntilALocationIsSet() {
        XCTAssertEqual(SettingsInput.text(34.0522, set: false), "")
        XCTAssertEqual(SettingsInput.text(34.0522, set: true), "34.0522")
    }

    private func failure(_ result: Result<BaroqueSettings, SettingsInput.Problem>) -> SettingsInput.Problem? {
        if case .failure(let p) = result { return p }
        return nil
    }

    // MARK: The status line after a refresh

    private func day(taskError: String? = nil, weatherError: String? = nil) -> DaySnapshot {
        DaySnapshot(date: Date(), weather: nil, tasks: [], taskError: taskError, weatherError: weatherError)
    }

    private func quotes(error: String? = nil) -> QuoteSnapshot {
        QuoteSnapshot(quotes: [], fetchedAt: Date(), error: error)
    }

    func testNothingFetchedDoesNotSayUpdated() {
        let offline = "The Internet connection appears to be offline."
        let line = SettingsInput.refreshLine(day: day(taskError: offline, weatherError: offline), quotes: quotes(error: offline),
                                             weatherAsked: true)
        XCTAssertEqual(line, "Couldn't refresh; showing saved data.")
        // With no location set, no weather was asked for: the two fetches that ran both failed.
        let noLocation = SettingsInput.refreshLine(day: day(taskError: offline, weatherError: DataLoader.noLocation),
                                                   quotes: quotes(error: offline), weatherAsked: false)
        XCTAssertEqual(noLocation, "Couldn't refresh; showing saved data.")
    }

    func testSomeFetchesFailed() {
        let line = SettingsInput.refreshLine(day: day(taskError: "GitHub denied access (403)"), quotes: quotes(), weatherAsked: true)
        XCTAssertEqual(line, "Updated, with errors: 0 task(s), 0 quote(s)")
    }

    func testAllFetched() {
        XCTAssertEqual(SettingsInput.refreshLine(day: day(), quotes: quotes(), weatherAsked: true), "Updated: 0 task(s), 0 quote(s)")
        // The "set a location" line isn't a failed fetch.
        XCTAssertEqual(SettingsInput.refreshLine(day: day(weatherError: DataLoader.noLocation), quotes: quotes(), weatherAsked: false),
                       "Updated: 0 task(s), 0 quote(s)")
    }

    // MARK: locationSet in saved settings (F23)

    func testOldSavedSettingsWithCoordinatesDecodeAsSet() throws {
        let saved = #"{"githubOwner":"someone","latitude":37.5,"longitude":-122.25}"#
        let s = try JSONDecoder().decode(BaroqueSettings.self, from: Data(saved.utf8))
        XCTAssertTrue(s.locationSet, "the author's saved location keeps working")
    }

    func testFreshSettingsHaveNoLocation() throws {
        XCTAssertFalse(BaroqueSettings.default.locationSet)
        let saved = #"{"githubOwner":"someone"}"#
        XCTAssertFalse(try JSONDecoder().decode(BaroqueSettings.self, from: Data(saved.utf8)).locationSet)
        var unset = BaroqueSettings.default
        unset.locationSet = false
        let back = try JSONDecoder().decode(BaroqueSettings.self, from: JSONEncoder().encode(unset))
        XCTAssertFalse(back.locationSet, "a saved false stays false")
    }
}
