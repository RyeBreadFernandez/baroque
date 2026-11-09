import SwiftUI
import AppKit

// Renders the small widget ideas (Ideas.swift) to MockLab/out/smalls/: each at scale 3, and a board of all of them on
// The Bathing Pool with their names and what each would read.
// Run: swift run --scratch-path .build-smalls RSmalls        README=1 renders the README's widgets (Readme.swift) instead.

@main
struct Main {
    @MainActor static func main() {
        PaintAssets.install()
        if ProcessInfo.processInfo.environment["THEMES"] == "1" {
            ReadmeRenders.renderThemes(to: Mock.root.appendingPathComponent("out/themes", isDirectory: true))
            print("Rendered the theme options to out/themes")
            return
        }
        if ProcessInfo.processInfo.environment["HEROES"] == "1" {
            ReadmeRenders.renderHeroChecks(to: Mock.root.appendingPathComponent("out/heroes", isDirectory: true))
            print("Rendered the hero checks to out/heroes")
            return
        }
        if ProcessInfo.processInfo.environment["README"] == "1" {
            ReadmeRenders.render(to: Mock.root.appendingPathComponent("out/readme", isDirectory: true))
            return
        }
        let dir = Mock.root.appendingPathComponent("out/smalls", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for idea in SmallIdea.all {
            MockRunner.write(idea.view.clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous)),
                             scale: 3, to: dir.appendingPathComponent("\(idea.slug).png"))
        }
        MockRunner.write(SmallsBoard(), scale: 2, to: dir.appendingPathComponent("board.png"))
        print("Rendered \(SmallIdea.all.count) small widget ideas to \(dir.path)")
    }
}

struct SmallsBoard: View {
    let columns = 5
    let gap: CGFloat = 26

    var body: some View {
        let rows = (SmallIdea.all.count + columns - 1) / columns
        let width = CGFloat(columns) * small.width + CGFloat(columns + 1) * gap
        VStack(alignment: .leading, spacing: gap) {
            ForEach(0..<rows, id: \.self) { r in
                HStack(alignment: .top, spacing: gap) {
                    ForEach(SmallIdea.all[(r * columns)..<min(SmallIdea.all.count, (r + 1) * columns)]) { idea in
                        VStack(spacing: 7) {
                            idea.view
                                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                                .shadow(color: .black.opacity(0.35), radius: 6, y: 3)
                            Text(idea.name).font(RococoType.serif(15)).foregroundStyle(RococoInk.cream)
                            Text(idea.source).font(RococoType.italic(10.5)).foregroundStyle(RococoInk.cream.opacity(0.85))
                                .multilineTextAlignment(.center).frame(width: small.width + 10)
                        }
                        .shadow(color: .black.opacity(0.6), radius: 2)
                    }
                }
            }
        }
        .padding(gap)
        .frame(width: width)
        .background {
            Group {
                let url = Mock.root.deletingLastPathComponent().appendingPathComponent("Baroque/Assets.xcassets/Wallpaper.imageset/Wallpaper.jpg")
                if let img = NSImage(contentsOf: url) {
                    Image(nsImage: img).resizable().scaledToFill()
                } else {
                    RococoInk.umber
                }
            }
            .overlay(Color.black.opacity(0.18))
            .clipped()
        }
    }
}
