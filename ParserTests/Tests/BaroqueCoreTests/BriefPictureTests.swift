import CoreGraphics
import Foundation
import ImageIO
import XCTest
@testable import BaroqueCore

/// The Daily Brief's picture of the day: finding it in the note, where a vault picture may be, what's kept or cleared,
/// and the fetch, against a stubbed URLProtocol (never a real museum or repository). Made-up notes and URLs.
final class BriefPictureTests: XCTestCase {
    private let painting = "https://example.org/iiif/abc123/full/!1800,1800/0/default.jpg"

    /// Shaped like the brief: the picture in a callout, right after a fence that's in the callout too.
    private var brief: String {
        """
        ---
        generated: 2026-11-11 05:40 PT
        ---
        # November 11

        > [!quote] Picture of the day
        > ```text
        > ![Not this one](https://example.org/in-code.jpg)
        > ```
        > ![The Harvest, oil on canvas](\(painting))

        ## Needs attention
        - [ ] #todo Water the ferns
        """
    }

    // MARK: Finding it

    func testThePictureInACalloutAfterAFenceInTheCallout() {
        XCTAssertEqual(BriefPicture.find(in: brief), .init(source: painting, alt: "The Harvest, oil on canvas"))
    }

    func testAPictureOnlyInsideACodeBlockIsNone() {
        XCTAssertNil(BriefPicture.find(in: "Intro\n```\n![a](https://example.org/a.jpg)\n```\nThe end."))
        XCTAssertNil(BriefPicture.find(in: "> ~~~md\n> ![a](https://example.org/a.jpg)\n> ~~~\n> Caption."))
        XCTAssertNil(BriefPicture.find(in: "Inline `![a](https://example.org/a.jpg)` code."))
    }

    func testAFenceThatNeverCloses() {
        // At the top it runs to the end of the note.
        XCTAssertNil(BriefPicture.find(in: "```js\nlet x = 1\n![a](https://example.org/a.jpg)"))
        // In a callout it ends with the callout: what's after the callout shows.
        let callout = """
        > [!note] Prompt
        > ```
        > ![In the code](https://example.org/in-code.jpg)

        ![After the callout](https://example.org/after.jpg)
        """
        XCTAssertEqual(BriefPicture.find(in: callout), .init(source: "https://example.org/after.jpg", alt: "After the callout"))
    }

    func testATitleAfterTheURL() {
        XCTAssertEqual(BriefPicture.find(in: #"![a](https://example.org/y.jpg "t")"#), .init(source: "https://example.org/y.jpg", alt: "a"))
        XCTAssertEqual(BriefPicture.find(in: "![a](https://example.org/y.jpg 't')")?.source, "https://example.org/y.jpg")
        XCTAssertEqual(BriefPicture.find(in: "![a](<https://example.org/y.jpg> (t))")?.source, "https://example.org/y.jpg")
    }

    func testARelativePathInTheVault() {
        XCTAssertEqual(BriefPicture.find(in: "> ![Map](pictures/map%20one.png)"), .init(source: "pictures/map one.png", alt: "Map"))
        XCTAssertEqual(BriefPicture.find(in: "![Two](<pic two.jpg>)"), .init(source: "pic two.jpg", alt: "Two"))
    }

    func testAWikiEmbedWithASize() {
        XCTAssertEqual(BriefPicture.find(in: "> ![[Paintings/harvest.jpg|300]]"), .init(source: "Paintings/harvest.jpg", alt: ""))
        XCTAssertEqual(BriefPicture.find(in: "![[harvest.JPG|The harvest|300x200]]"), .init(source: "harvest.JPG", alt: "The harvest"))
    }

    func testNoPicture() {
        XCTAssertNil(BriefPicture.find(in: ""))
        XCTAssertNil(BriefPicture.find(in: "# November 11\n- [ ] #todo Water the ferns\n[A link](https://example.org/a.jpg)"))
    }

    func testWhatIsntAPictureToShowIsPassedOver() {
        let md = """
        ---
        cover: ![front](https://example.org/front.jpg)
        ---
        ![[Weekly review]] embeds a note.
        ![plain](http://example.org/insecure.jpg) and ![drawing](https://example.org/sketch.svg)
        \\![escaped](https://example.org/escaped.jpg) %% ![hidden](https://example.org/hidden.jpg) %%
        <!-- ![commented](https://example.org/commented.jpg) -->
        %% a comment over
        ![two lines](https://example.org/hidden-too.jpg) %% then ![This one|300](https://example.org/this.jpg)
        """
        XCTAssertEqual(BriefPicture.find(in: md), .init(source: "https://example.org/this.jpg", alt: "This one"))
    }

    func testTheFirstPictureWins() {
        let md = "Text ![[second.png]] then ![first](https://example.org/1.jpg)\n![third](https://example.org/3.jpg)"
        XCTAssertEqual(BriefPicture.find(in: md)?.source, "second.png")
        XCTAssertEqual(BriefPicture.find(in: "> > ![*Nested* **callout**](https://example.org/n.jpg)")?.alt, "Nested callout")
    }

    // MARK: A picture in the vault

    func testVaultPathsBesideTheNoteThenFromTheTop() {
        let note = BaroqueSettings.dailyBriefPath
        XCTAssertEqual(BriefPicture.vaultPaths("pic.jpg", notePath: note), ["Daily Brief/pic.jpg", "pic.jpg"])
        XCTAssertEqual(BriefPicture.vaultPaths("Art/pic.jpg", notePath: note), ["Daily Brief/Art/pic.jpg", "Art/pic.jpg"])
        XCTAssertEqual(BriefPicture.vaultPaths("./pic.jpg", notePath: note), ["Daily Brief/pic.jpg"])
        XCTAssertEqual(BriefPicture.vaultPaths("../Art/pic.jpg", notePath: note), ["Art/pic.jpg"])
        XCTAssertEqual(BriefPicture.vaultPaths("/Art/pic.jpg", notePath: note), ["Art/pic.jpg"])
        XCTAssertEqual(BriefPicture.vaultPaths("../../pic.jpg", notePath: note), [])
        XCTAssertEqual(BriefPicture.vaultPaths("pic.jpg", notePath: "Today.md"), ["pic.jpg"])
    }

    // MARK: Keeping it

    private let now = day(2026, 11, 11, hour: 9)
    private let yesterday = day(2026, 11, 10, hour: 18)
    private var found: BriefPicture.Found { .init(source: painting, alt: "The Harvest") }

    func testTheSamePictureIsNotDownloadedAgain() {
        let kept = BriefPicture.Kept(source: painting, alt: "Old words", day: yesterday)
        XCTAssertEqual(BriefPicture.step(found: found, kept: kept, fileExists: true, failed: nil, now: now),
                       .keep(.init(source: painting, alt: "The Harvest", day: now)))
        // Unless its file has gone (the system cleared the caches).
        XCTAssertEqual(BriefPicture.step(found: found, kept: kept, fileExists: false, failed: nil, now: now), .download(found))
    }

    func testANewPictureIsDownloaded() {
        let kept = BriefPicture.Kept(source: "https://example.org/old.jpg", day: now)
        XCTAssertEqual(BriefPicture.step(found: found, kept: kept, fileExists: true, failed: nil, now: now), .download(found))
        XCTAssertEqual(BriefPicture.step(found: found, kept: nil, fileExists: false, failed: nil, now: now), .download(found))
    }

    func testANewDayWithNoPictureMeansTheFlowers() {
        let kept = BriefPicture.Kept(source: painting, day: yesterday)
        XCTAssertEqual(BriefPicture.step(found: nil, kept: kept, fileExists: true, failed: nil, now: now), .keep(nil))
    }

    func testAFailedDownloadKeepsTodaysPictureButNotYesterdays() {
        let today = BriefPicture.Kept(source: "https://example.org/old.jpg", day: day(2026, 11, 11, hour: 6))
        XCTAssertEqual(BriefPicture.settle(found, saved: false, kept: today, now: now), today)
        XCTAssertNil(BriefPicture.settle(found, saved: false, kept: .init(source: "https://example.org/old.jpg", day: yesterday), now: now))
        XCTAssertEqual(BriefPicture.settle(found, saved: true, kept: today, now: now), .init(source: painting, alt: "The Harvest", day: now))
    }

    func testAPictureThatFailedWaitsAnHourBeforeAnotherTry() {
        let kept = BriefPicture.Kept(source: "https://example.org/old.jpg", day: day(2026, 11, 11, hour: 6))
        let lately = BriefPicture.Attempt(source: painting, at: now.addingTimeInterval(-10 * 60))
        XCTAssertEqual(BriefPicture.step(found: found, kept: kept, fileExists: true, failed: lately, now: now), .keep(kept))
        let earlier = BriefPicture.Attempt(source: painting, at: now.addingTimeInterval(-61 * 60))
        XCTAssertEqual(BriefPicture.step(found: found, kept: kept, fileExists: true, failed: earlier, now: now), .download(found))
        let another = BriefPicture.Attempt(source: "https://example.org/other.jpg", at: now)
        XCTAssertEqual(BriefPicture.step(found: found, kept: kept, fileExists: true, failed: another, now: now), .download(found))
    }

    func testTheBandShowsItOnlyOnItsDay() {
        let folder = URL(fileURLWithPath: "/pictures")
        let kept = BriefPicture.Kept(source: painting, alt: "The Harvest", day: day(2026, 11, 11, hour: 6))
        let shown = BriefPicture.shown(kept, in: folder, on: now, fileExists: { _ in true })
        XCTAssertEqual(shown?.file.path, "/pictures/picture.jpg")
        XCTAssertEqual(shown?.alt, "The Harvest")
        XCTAssertNil(BriefPicture.shown(kept, in: folder, on: day(2026, 11, 12, hour: 0, minute: 5), fileExists: { _ in true }))
        XCTAssertNil(BriefPicture.shown(kept, in: folder, on: now, fileExists: { _ in false }))
        XCTAssertNil(BriefPicture.shown(nil, in: folder, on: now, fileExists: { _ in true }))
    }

    func testAKeptPictureDecodesFieldByField() throws {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let kept = try decoder.decode(BriefPicture.Kept.self, from: Data(#"{"source":"pic.jpg","day":"2026-11-11T09:00:00Z"}"#.utf8))
        XCTAssertEqual(kept.source, "pic.jpg")
        XCTAssertEqual(kept.alt, "")
    }

    // MARK: Fetching it (stubbed)

    private let suite = "BaroqueParserTests.BriefPicture"
    private var defaults: UserDefaults!
    private var store: Store!
    private var folder: URL!

    override func setUp() {
        StubGitHub.reset()
        UserDefaults().removePersistentDomain(forName: suite)
        defaults = UserDefaults(suiteName: suite)!
        store = Store(defaults: defaults)
        folder = FileManager.default.temporaryDirectory.appendingPathComponent("BriefPictureTests-\(UUID().uuidString)", isDirectory: true)
    }

    override func tearDown() {
        StubGitHub.reset()
        defaults.removePersistentDomain(forName: suite)
        try? FileManager.default.removeItem(at: folder)
    }

    private var file: URL { folder.appendingPathComponent(BriefPicture.fileName) }

    private func update(_ markdown: String, at date: Date? = nil) async {
        await BriefPicture.update(brief: markdown, notePath: BaroqueSettings.dailyBriefPath, store: store, folder: folder,
                                  client: StubGitHub.client(), web: StubGitHub.session(), now: date ?? now)
    }

    func testAWebPictureIsDownloadedOnceAndWithoutTheToken() async throws {
        StubGitHub.replies = [.init(status: 200, body: png(width: 1800, height: 1200, stripes: [.red, .green, .blue]))]
        await update(brief)
        XCTAssertEqual(StubGitHub.seen.map(\.url.absoluteString), [painting])
        XCTAssertNil(StubGitHub.seen.first?.headers["Authorization"])
        XCTAssertEqual(store.briefPicture, .init(source: painting, alt: "The Harvest, oil on canvas", day: now))
        let image = try XCTUnwrap(decode(try Data(contentsOf: file)))
        XCTAssertEqual([image.width, image.height], [BandImage.width, BandImage.height])

        // The next fetch of the same brief, the next morning before the brief is written again: no download.
        let morning = day(2026, 11, 12, hour: 1)
        await update(brief, at: morning)
        XCTAssertEqual(StubGitHub.seen.count, 1)
        XCTAssertEqual(store.briefPicture?.day, morning)
    }

    func testAVaultPictureComesFromGitHubBesideTheNoteThenFromTheTop() async throws {
        StubGitHub.replies = [.status(404, message: "Not Found"), .init(status: 200, body: png(width: 800, height: 600, stripes: [.green]))]
        await update("# November 11\n> ![[pic.jpg|300]]")
        XCTAssertEqual(StubGitHub.seen.map(\.url.absoluteString), [
            "https://api.github.com/repos/someone/notes/contents/Daily%20Brief/pic.jpg?ref=main",
            "https://api.github.com/repos/someone/notes/contents/pic.jpg?ref=main"
        ])
        XCTAssertEqual(StubGitHub.seen.map { $0.headers["Accept"] }, ["application/vnd.github.raw+json", "application/vnd.github.raw+json"])
        XCTAssertEqual(StubGitHub.seen.last?.headers["Authorization"], "Bearer test-token")
        XCTAssertEqual(store.briefPicture?.source, "pic.jpg")
        XCTAssertTrue(FileManager.default.fileExists(atPath: file.path))
    }

    func testAFailedDownloadKeepsTodaysPictureOnFile() async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("kept".utf8).write(to: file)
        let kept = BriefPicture.Kept(source: "https://example.org/old.jpg", day: day(2026, 11, 11, hour: 6))
        store.briefPicture = kept
        StubGitHub.replies = [.status(500)]
        await update(brief)
        XCTAssertEqual(store.briefPicture, kept)
        XCTAssertEqual(try Data(contentsOf: file), Data("kept".utf8))
        XCTAssertEqual(store.briefPictureFailure, .init(source: painting, at: now))

        // Within the hour it isn't tried again.
        await update(brief, at: now.addingTimeInterval(20 * 60))
        XCTAssertEqual(StubGitHub.seen.count, 1)
    }

    func testAFailedDownloadOnANewDayMeansTheFlowers() async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: file)
        store.briefPicture = .init(source: "https://example.org/old.jpg", day: yesterday)
        StubGitHub.failure = URLError(.notConnectedToInternet)
        await update(brief)
        XCTAssertNil(store.briefPicture)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
    }

    func testABriefWithNoPictureClearsIt() async throws {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        try Data("old".utf8).write(to: file)
        store.briefPicture = .init(source: painting, day: now)
        await update("# November 12\n- [ ] #todo Water the ferns", at: day(2026, 11, 12, hour: 6))
        XCTAssertNil(store.briefPicture)
        XCTAssertFalse(FileManager.default.fileExists(atPath: file.path))
        XCTAssertTrue(StubGitHub.seen.isEmpty)
    }

    func testThePictureThatCantBeReadIsAFailedDownload() async {
        StubGitHub.replies = [.init(status: 200, body: Data("<html>not a picture</html>".utf8))]
        await update(brief)
        XCTAssertNil(store.briefPicture)
        XCTAssertEqual(store.briefPictureFailure?.source, painting)
    }

    func testTheTaskFetchHandsOverTheBriefsText() async {
        StubGitHub.replies = [.init(status: 200, body: Data(brief.utf8))]
        let fetched = await DataLoader.fetchTasks(client: StubGitHub.client(), settings: StubGitHub.settings)
        XCTAssertEqual(fetched.tasks?.map(\.text), ["Water the ferns"])
        XCTAssertEqual(fetched.brief, brief)
    }

    // MARK: Cut to the band

    func testATallPictureIsCutToItsMiddle() throws {
        // Red at the top, green across the middle, blue at the foot: the band's strip from the middle is all green.
        let jpeg = try XCTUnwrap(BandImage.jpeg(from: png(width: 400, height: 1600, stripes: [.red, .green, .blue], middle: 0.25)))
        let image = try XCTUnwrap(decode(jpeg))
        XCTAssertEqual([image.width, image.height], [656, 164])
        for (x, y) in [(328, 2), (328, 82), (328, 161), (2, 82), (653, 82)] {
            XCTAssertTrue(isGreen(pixel(image, x, y)), "(\(x), \(y)) is \(pixel(image, x, y))")
        }
    }

    func testAWidePictureIsCutToItsMiddle() throws {
        // Red at the left, green in the middle half, blue at the right.
        let jpeg = try XCTUnwrap(BandImage.jpeg(from: png(width: 2000, height: 200, stripes: [.red, .green, .blue], middle: 0.5, across: true)))
        let image = try XCTUnwrap(decode(jpeg))
        XCTAssertEqual([image.width, image.height], [656, 164])
        for (x, y) in [(2, 82), (328, 82), (653, 82), (328, 2), (328, 161)] {
            XCTAssertTrue(isGreen(pixel(image, x, y)), "(\(x), \(y)) is \(pixel(image, x, y))")
        }
    }

    func testABigPictureIsDownsampledToJustCoverTheBand() throws {
        let data = png(width: 3000, height: 2000, stripes: [.green])
        let source = try XCTUnwrap(CGImageSourceCreateWithData(data as CFData, nil))
        let small = try XCTUnwrap(BandImage.downsample(source, toCover: 656, 164))
        XCTAssertEqual(small.width, 656)
        XCTAssertTrue((437...438).contains(small.height), "\(small.height)")
        let jpeg = try XCTUnwrap(BandImage.jpeg(from: data))
        let image = try XCTUnwrap(decode(jpeg))
        XCTAssertEqual(Double(image.width) / Double(image.height), 4)
        XCTAssertLessThan(jpeg.count, 40_000)
    }

    func testWhatIsntAPictureGivesNothing() {
        XCTAssertNil(BandImage.jpeg(from: Data("not a picture".utf8)))
        XCTAssertNil(BandImage.jpeg(from: Data()))
    }

    // MARK: Pictures for the tests

    private enum Paint { case red, green, blue }

    /// A PNG in stripes from the top (or from the left, `across`): the first and last share what the middle one leaves.
    private func png(width: Int, height: Int, stripes: [Paint], middle: Double = 1, across: Bool = false) -> Data {
        let space = CGColorSpace(name: CGColorSpace.sRGB)!
        let ctx = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0, space: space,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        func colour(_ p: Paint) -> CGColor {
            switch p {
            case .red: return CGColor(srgbRed: 1, green: 0, blue: 0, alpha: 1)
            case .green: return CGColor(srgbRed: 0, green: 1, blue: 0, alpha: 1)
            case .blue: return CGColor(srgbRed: 0, green: 0, blue: 1, alpha: 1)
            }
        }
        let length = Double(across ? width : height)
        let mid = stripes.count == 3 ? middle * length : length
        let side = (length - mid) / 2
        let spans = stripes.count == 3 ? [(0.0, side), (side, mid), (side + mid, side)] : [(0.0, length)]
        for (paint, span) in zip(stripes, spans) {
            ctx.setFillColor(colour(paint))
            // CoreGraphics counts y from the foot, so the first stripe from the top is drawn highest.
            let rect = across ? CGRect(x: span.0, y: 0, width: span.1, height: Double(height))
                              : CGRect(x: 0, y: length - span.0 - span.1, width: Double(width), height: span.1)
            ctx.fill(rect)
        }
        let out = NSMutableData()
        let dest = CGImageDestinationCreateWithData(out, "public.png" as CFString, 1, nil)!
        CGImageDestinationAddImage(dest, ctx.makeImage()!, nil)
        CGImageDestinationFinalize(dest)
        return out as Data
    }

    private func decode(_ data: Data) -> CGImage? {
        CGImageSourceCreateWithData(data as CFData, nil).flatMap { CGImageSourceCreateImageAtIndex($0, 0, nil) }
    }

    /// The pixel at (x, y) from the top left, as 0-255 red, green and blue.
    private func pixel(_ image: CGImage, _ x: Int, _ y: Int) -> [Int] {
        var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
        let ctx = CGContext(data: &bytes, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        ctx.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
        let i = (y * image.width + x) * 4
        return [Int(bytes[i]), Int(bytes[i + 1]), Int(bytes[i + 2])]
    }

    private func isGreen(_ rgb: [Int]) -> Bool { rgb[0] < 70 && rgb[1] > 190 && rgb[2] < 70 }
}
