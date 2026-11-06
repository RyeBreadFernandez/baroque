// swift-tools-version:5.9
import PackageDescription

// One executable per mock. Aesthetics link Kit/ (Sources/<T>/Kit -> ../../Kit); painted layouts link PaintKit/
// (Sources/<T>/PaintKit -> ../../PaintKit), which compiles the app's own Theme, Landscape and Views.
let aesthetics = ["FieldJournal", "Topo", "Woodblock", "StainedGlass", "PaperDiorama", "PixelQuest"]
let layouts = ["Current", "LPanorama", "LFocus", "LBento", "LMedallion", "LTrail", "LPlate"]
// Film looks: two after Wong Kar-wai and two after Wes Anderson (Kit/), then GrandHotel, the Wes Anderson hotel
// look in the app's painted style (PaintKit/), and GrandHotelCalm, two simpler versions of it sharing its materials.
// OldMaster is a sepia old-master oil-painting look from the user's reference image (PaintKit/); OMInscribed,
// OMFolio and OMCover are more inventive compositions of it that share its OMStyle.swift.
let films = ["NeonRain", "CrimsonHours", "AlpineHotel", "Expedition", "GrandHotel", "GrandHotelCalm", "OldMaster",
             "OMInscribed", "OMFolio", "OMCover"]

// Weather-first widget set (Weather widget + separate To-do widget, Kit/WeatherMockKit.swift), from the Pinterest
// research of 2026-11-04. All link PaintKit/.
let weather = ["WSunArc", "WAlmanac", "WGiltFrame", "WStorybook", "WCelestial", "WPoster", "WNumeral"]

// Small widget ideas in the shipped rococo look (2026-11-05), on the app's own Shared/RococoStyle.swift. Links PaintKit/.
let smalls = ["RSmalls"]

let package = Package(
    name: "MockLab",
    platforms: [.macOS(.v14)],
    targets: (aesthetics + layouts + films + weather + smalls).map { .executableTarget(name: $0, path: "Sources/\($0)") }
)
