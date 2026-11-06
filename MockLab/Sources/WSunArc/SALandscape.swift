import SwiftUI

// Other landscapes in the Sun Arc layout (2026-11-04, after "doesnt just have to be matterhorn"):
//   SA_SCENE=<name> swift run --scratch-path .build-weather-sun-arc WSunArc
// reads the Weather canvases from Textures/weather-sun-arc/scenes/<name>/ instead of the Matterhorn's, takes any arc
// listed in that folder's scene.json, and writes weather-<size>.png and weather-<size>-night.png (scale 3) for each
// size the scene has painted to out/weather-sun-arc-scenes/<name>/. Without SA_SCENE nothing changes.
//
// scene.json (optional): {"large": [centerX, horizon, radiusX, radiusY], "medium": [...], "small": [...]}, in
// fractions of the widget like SACanvas.arc; a size it leaves out keeps the Matterhorn's arc.

enum SALandscape {
    static let name: String? = {
        let value = ProcessInfo.processInfo.environment["SA_SCENE"] ?? ""
        return value.isEmpty ? nil : value
    }()

    /// The texture folder under MockLab/Textures/.
    static var folder: String { name.map { "weather-sun-arc/scenes/\($0)" } ?? "weather-sun-arc" }

    static let arcs: [String: SkyArc] = {
        guard name != nil,
              let data = try? Data(contentsOf: Mock.root.appendingPathComponent("Textures/\(folder)/scene.json")),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: [Double]] else { return [:] }
        return json.compactMapValues { v in
            v.count == 4 ? SkyArc(centerX: v[0], horizon: v[1], radiusX: v[2], radiusY: v[3]) : nil
        }
    }()

    @MainActor
    static func render(_ scene: String) {
        let dir = Mock.root.appendingPathComponent("out/weather-sun-arc-scenes/\(scene)", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        for f in Family.allCases {
            let lower = Mock.root.appendingPathComponent("Textures/\(folder)/\(SACanvas(f).rawValue)-lo.png")
            guard FileManager.default.fileExists(atPath: lower.path) else { continue }
            MockRunner.write(WidgetTile(family: f) { SAWeather(snap: Mock.day, family: f) }, scale: 3,
                             to: dir.appendingPathComponent("weather-\(f.rawValue).png"))
            MockRunner.write(WidgetTile(family: f) { SAWeather(snap: Mock.night, family: f) }, scale: 3,
                             to: dir.appendingPathComponent("weather-\(f.rawValue)-night.png"))
        }
        print("Rendered Sun Arc scene \(scene) to \(dir.path)")
    }
}
