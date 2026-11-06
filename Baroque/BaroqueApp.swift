import SwiftUI

@main
struct BaroqueApp: App {
    init() {
        #if DEBUG
        DebugLaunch.apply()
        #endif
        DispatchQueue.global(qos: .utility).async { IconFiles.export() }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
