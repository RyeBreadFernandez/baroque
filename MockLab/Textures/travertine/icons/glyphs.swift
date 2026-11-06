// Renders the flat outlines the Blender icons are extruded from: SF Symbols and type, black on clear, 1024 px,
// to masks/<name>.png. Run: swift glyphs.swift   (from this folder; trace.py turns the masks into contours)
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct Glyph {
    var name: String; var symbol: String?; var text: String?; var font: String?; var weight: Font.Weight
    var size: CGFloat = 760; var tracking: CGFloat = 0; var lineSpacing: CGFloat = 0
}

let glyphs: [Glyph] = [
    Glyph(name: "phone", symbol: "phone.fill", text: nil, font: nil, weight: .regular),
    Glyph(name: "bubble", symbol: "message.fill", text: nil, font: nil, weight: .regular),
    Glyph(name: "envelope", symbol: "envelope.fill", text: nil, font: nil, weight: .regular),
    Glyph(name: "envelope-lines", symbol: "envelope", text: nil, font: nil, weight: .regular),
    Glyph(name: "music", symbol: nil, text: "♫", font: nil, weight: .regular),
    Glyph(name: "heart", symbol: "heart.fill", text: nil, font: nil, weight: .regular),
    Glyph(name: "play", symbol: "play.rectangle.fill", text: nil, font: nil, weight: .regular),
    Glyph(name: "mic", symbol: "mic.fill", text: nil, font: nil, weight: .regular),
    Glyph(name: "folder", symbol: "folder.fill", text: nil, font: nil, weight: .regular),
    Glyph(name: "wallet", symbol: "wallet.pass.fill", text: nil, font: nil, weight: .regular),
    Glyph(name: "appstore", symbol: "arrow.down.app.fill", text: nil, font: nil, weight: .regular),
    Glyph(name: "pinterest", symbol: nil, text: "p", font: "ArialRoundedMTBold", weight: .regular),
    Glyph(name: "notion-n", symbol: nil, text: "N", font: "Georgia-Bold", weight: .regular),
    Glyph(name: "mountain", symbol: "mountain.2.fill", text: nil, font: nil, weight: .regular),
    Glyph(name: "cloud", symbol: "cloud.fill", text: nil, font: nil, weight: .regular),
    // Two words at one size; trace.py stacks them, "Uber" over "Eats", so each can take its own material.
    Glyph(name: "uber", symbol: nil, text: "Uber", font: "AvenirNext-Bold", weight: .regular, size: 330),
    Glyph(name: "eats", symbol: nil, text: "Eats", font: "AvenirNext-Bold", weight: .regular, size: 330),
    Glyph(name: "eqx", symbol: nil, text: "EQX", font: "AvenirNext-DemiBold", weight: .regular, size: 330, tracking: 40),
]

@MainActor func render(_ g: Glyph, to url: URL) {
    let view: AnyView
    if let s = g.symbol {
        view = AnyView(Image(systemName: s).font(.system(size: 640, weight: g.weight)).foregroundStyle(.black))
    } else if let f = g.font {
        view = AnyView(Text(g.text ?? "").font(.custom(f, size: g.size)).tracking(g.tracking).lineSpacing(g.lineSpacing)
            .multilineTextAlignment(.leading).foregroundStyle(.black))
    } else {
        view = AnyView(Text(g.text ?? "").font(.system(size: g.size, weight: g.weight)).foregroundStyle(.black))
    }
    let framed = view.frame(width: 1024, height: 1024)
    let r = ImageRenderer(content: framed)
    r.scale = 1
    guard let cg = r.cgImage, let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        print("failed \(g.name)"); return
    }
    CGImageDestinationAddImage(dest, cg, nil)
    CGImageDestinationFinalize(dest)
}

let dir = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("masks")
try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
MainActor.assumeIsolated {
    for g in glyphs { render(g, to: dir.appendingPathComponent("\(g.name).png")) }
}
print("rendered \(glyphs.count) masks")
