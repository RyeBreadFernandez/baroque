import SwiftUI
import WidgetKit

struct ContentView: View {
    @State private var settings = Store.shared.settings
    @State private var token = Store.shared.githubToken
    @State private var latText = ""
    @State private var lonText = ""
    @State private var daySnapshot: DaySnapshot? = Store.shared.daySnapshot
    @State private var quoteSnapshot: QuoteSnapshot? = Store.shared.quoteSnapshot
    @State private var isRefreshing = false
    @State private var statusMessage = ""
    @StateObject private var location = LocationHelper()
    @State private var wallpaperStatus = ""
    /// The Daily Brief page, opened by the Today widget (baroque://brief).
    @State private var showBrief = false
    @Environment(\.scenePhase) private var scenePhase

    init() {
        Self.applyStoneNavigationBar()
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                Form {
                    previewSection.id("preview")
                    setupSection.id("setup")
                    Group {
                        githubSection.id("github")
                        tasksSection.id("tasks")
                        quotesSection.id("quotes")
                        locationSection.id("location")
                        iconsSection.id("icons")
                        aboutSection.id("about")
                    }
                    .listRowBackground(StoneRow())
                }
                #if DEBUG
                .onAppear { WidgetRenders.scrollIfRequested(proxy) }
                #endif
            }
            // The painted scene behind espresso rows instead of the stock grouped background.
            .scrollContentBackground(.hidden)
            .background(AppGround().ignoresSafeArea())
            .navigationTitle("Baroque")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: saveAndRefresh) {
                        if isRefreshing { ProgressView() } else { Text("Save & Refresh") }
                    }
                    .disabled(isRefreshing)
                }
            }
            .onAppear { showCoordinates(settings) }
            .task { await refresh() }
            // Ticks that couldn't be saved (offline, or tapped on the widget) are tried again whenever the app opens.
            .onChange(of: scenePhase) { _, phase in
                if phase == .active { Task { await TaskSync.retryPending() } }
            }
            .onOpenURL { url in
                if url.scheme == Brief.url.scheme, url.host == Brief.url.host { showBrief = true }
            }
            .sheet(isPresented: $showBrief) { BriefView() }
            #if DEBUG
            .onAppear { if ProcessInfo.processInfo.arguments.contains("-openBrief") { showBrief = true } }
            #endif
        }
        #if DEBUG
        .onAppear { WidgetRenders.runIfRequested() }
        #endif
        .tint(Stone.copperLight)
        .foregroundStyle(Stone.parchment)
        // The palette is dark-only; system controls follow it even when the phone is in light mode.
        .preferredColorScheme(.dark)
    }

    // MARK: Sections

    private var previewSection: some View {
        Section {
            // The widgets themselves, laid out at their iPhone 17 design sizes and scaled to the row. A view of its own
            // that compares its inputs, so typing in the settings below doesn't redraw them.
            WidgetPreviews(day: daySnapshot ?? emptyDay, heroQuote: heroQuote, quote: currentQuote, quoteError: quoteSnapshot?.error)
                .equatable()
            .padding(14)
            .background(PreviewTray())
            .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 10, trailing: 0))
            .listRowBackground(Color.clear)
            Group {
                if !statusMessage.isEmpty {
                    Text(statusMessage).font(.footnote).foregroundStyle(Stone.goldMuted)
                }
                if let e = daySnapshot?.taskError { Label(e, systemImage: "exclamationmark.triangle").font(.footnote).foregroundStyle(Stone.copperInk) }
                if let e = daySnapshot?.weatherError { Label(e, systemImage: "cloud.slash").font(.footnote).foregroundStyle(Stone.copperInk) }
                if let e = quoteSnapshot?.error, e != daySnapshot?.taskError { Label(e, systemImage: "quote.bubble").font(.footnote).foregroundStyle(Stone.copperInk) }
            }
            .listRowBackground(StoneRow())
        } header: {
            StoneHeader("Preview")
        } footer: {
            StoneFooter("Widgets refresh on their own about every 30 minutes. Tap Save & Refresh after changing anything here.")
        }
    }

    private var githubSection: some View {
        Section {
            field("Owner", $settings.githubOwner)
            field("Repository", $settings.githubRepo)
            field("Branch", $settings.githubBranch)
            SecureField("Personal access token", text: $token)
            field("Obsidian vault", $settings.obsidianVault)
        } header: {
            StoneHeader("GitHub (Obsidian vault)")
        } footer: {
            VStack(alignment: .leading, spacing: 6) {
                if let problem = Store.shared.tokenProblem {
                    StoneFooter(problem)
                }
                StoneFooter("Create a fine-grained token at github.com → Settings → Developer settings → Personal access tokens, scoped to this repository with Contents: Read and write, so ticked tasks can be saved to the vault. It is stored in the Keychain. The vault name is the one Obsidian shows, for Open in Obsidian.")
            }
        }
    }

    private var tasksSection: some View {
        Section {
            TextEditor(text: $settings.taskPaths)
                .scrollContentBackground(.hidden)
                .font(.system(.footnote, design: .monospaced))
                .frame(minHeight: 70)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
            field("Daily note folder", $settings.dailyNoteFolder)
            field("Daily note format", $settings.dailyNoteFormat)
            Toggle("Include undated tasks", isOn: $settings.includeUndatedTasks)
            LabeledContent("Today's daily note", value: DataLoader.dailyNotePath(settings: settings))
                .font(.footnote)
        } header: {
            StoneHeader("Tasks")
        } footer: {
            StoneFooter("One vault path per line. {daily} expands to today's daily note. Tasks are lines like \"- [ ] #todo Do thing 📅 2026-11-02\". Overdue and due-today tasks are shown first.")
        }
    }

    private var quotesSection: some View {
        Section {
            field("Quotes file", $settings.quotesPath)
            Stepper("Rotate every \(settings.quoteRotationMinutes) min", value: $settings.quoteRotationMinutes, in: 5...720, step: 5)
            if let q = quoteSnapshot, !q.quotes.isEmpty {
                LabeledContent("Quotes loaded", value: "\(q.quotes.count)")
            }
        } header: {
            StoneHeader("Quotes")
        } footer: {
            StoneFooter("Write quotes as blockquotes:\n> The quote text\n> — Author\n\nor bullets: - \"Quote\" — Author")
        }
    }

    private var locationSection: some View {
        Section {
            Button {
                // Fills in the fields; Save & Refresh keeps it (LocationHelper's status line says so).
                location.requestOnce { lat, lon, city in
                    settings.latitude = lat
                    settings.longitude = lon
                    settings.cityName = city
                    settings.locationSet = true
                    showCoordinates(settings)
                }
            } label: {
                HStack {
                    Label("Use current location", systemImage: "location.fill")
                    Spacer()
                    if location.isWorking { ProgressView() }
                }
            }
            if !location.status.isEmpty {
                Text(location.status).font(.footnote).foregroundStyle(Stone.goldMuted)
            }
            HStack {
                TextField("Latitude", text: $latText).keyboardType(.numbersAndPunctuation)
                TextField("Longitude", text: $lonText).keyboardType(.numbersAndPunctuation)
            }
            Toggle("Fahrenheit", isOn: $settings.useFahrenheit)
        } header: {
            StoneHeader("Weather location")
        } footer: {
            StoneFooter("Weather comes from Open-Meteo, no account needed. Use your current location or type a latitude and longitude, then tap Save & Refresh; until then the widgets ask for one. The location is stored once; the widgets don't track you.")
        }
    }

    // Setting up the home screen: what an app may do (hand over the icon profile, save the wallpaper), then the plan for
    // what only the user can do (place the widgets, arrange the icons). See HomeSetup.swift.
    private var setupSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Label("Make the icons", systemImage: "square.grid.3x3.fill")
                Text("For each app, in Shortcuts: tap +, add Open App and choose the app. Tap the shortcut's name, then Add to Home Screen, Image, Choose File, and pick its icon from On My iPhone › Baroque › Home screen icons. The icon opens the app directly.")
                    .font(.footnote).foregroundStyle(Stone.goldMuted)
                if let url = IconFiles.filesURL {
                    Button { UIApplication.shared.open(url) } label: {
                        Label("Show the icons in Files", systemImage: "folder")
                    }
                    .font(.footnote)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    WallpaperSaver.shared.save { ok in
                        wallpaperStatus = ok ? "Saved to Photos." : "Couldn't save it. Allow Baroque to add photos in Settings."
                    }
                } label: {
                    Label("Save the wallpaper", systemImage: "photo.on.rectangle.angled")
                }
                Text("The Bathing Pool goes to Photos. Open it there, tap Share, Use as Wallpaper, then Add and Set as Wallpaper Pair.")
                    .font(.footnote).foregroundStyle(Stone.goldMuted)
                if !wallpaperStatus.isEmpty { Text(wallpaperStatus).font(.footnote).foregroundStyle(Stone.gold) }
            }
            VStack(alignment: .leading, spacing: 8) {
                Label("Place the widgets and icons", systemImage: "square.on.square")
                Text("Long-press the home screen, tap Edit, then Add Widget and search for Baroque. Page 1: Day, large, over eight icons. Page 2: Day, Today and Quote, small, among the other twelve. Then drag the icons into place as below.")
                    .font(.footnote).foregroundStyle(Stone.goldMuted)
                HomePlan()
            }
        } header: {
            StoneHeader("Set up your home screen")
        } footer: {
            StoneFooter("iOS lets no app move icons, set the wallpaper or place widgets, so Baroque hands you the pieces and shows where they go.")
        }
    }

    // The home screen icons in the rococo style. iOS lets only Shortcuts give another app a new icon, so Baroque hands
    // them over as images to save to Photos.
    private var iconsSection: some View {
        Section {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 14) {
                ForEach(HomeIcons.apps, id: \.self) { app in
                    let image = Image(HomeIcons.asset(app))
                    ShareLink(item: image, preview: SharePreview(app, image: image)) {
                        VStack(spacing: 5) {
                            IconThumbnail.image(HomeIcons.asset(app), points: 84).resizable().aspectRatio(1, contentMode: .fit)
                                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))
                            Text(app).font(.caption2).lineLimit(1).foregroundStyle(Stone.parchment)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 6)
            ShareLink(items: HomeIcons.apps.map { Image(HomeIcons.asset($0)) }) { image in
                SharePreview("Baroque icon", image: image)
            } label: {
                Label("Save all 24 icons", systemImage: "square.and.arrow.down")
            }
        } header: {
            StoneHeader("Home screen icons")
        } footer: {
            StoneFooter("The same icons are in Files (On My iPhone › Baroque). Tap one, or Save all, to put them in Photos instead.")
        }
    }

    private var aboutSection: some View {
        Section {
            // Fetches with the saved settings, then reloads every widget (refresh), and says how it went above.
            Button("Reload all widgets now") {
                Task { await refresh() }
            }
            .disabled(isRefreshing)
            Button("Reset to defaults", role: .destructive) {
                settings = .default
                showCoordinates(settings)
            }
        } footer: {
            StoneFooter("Baroque: painted widgets for your home screen. Add them from the widget gallery under \"Baroque\".")
        }
    }

    // MARK: Helpers

    // A labeled text row, so a filled-in field still says what it is.
    private func field(_ label: String, _ text: Binding<String>) -> some View {
        LabeledContent(label) {
            TextField(label, text: text)
                .multilineTextAlignment(.trailing)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        }
    }

    private var emptyDay: DaySnapshot {
        DaySnapshot(date: Date(), weather: nil, tasks: [], taskError: nil, weatherError: nil)
    }

    /// The large Day widget's line: one past the Quote widget's, as in the widget.
    private var heroQuote: Quote {
        let pool = DataLoader.quotePool(quoteSnapshot)
        return pool[DataLoader.dayQuoteIndex(count: pool.count, offset: Store.shared.quoteOffset, at: Date(), settings: settings)]
    }

    private var currentQuote: Quote {
        let pool = DataLoader.quotePool(quoteSnapshot)
        return pool[DataLoader.quoteIndex(count: pool.count, offset: Store.shared.quoteOffset, at: Date(), settings: settings)]
    }

    /// The coordinate fields for `s`: empty until a location is set.
    private func showCoordinates(_ s: BaroqueSettings) {
        latText = SettingsInput.text(s.latitude, set: s.locationSet)
        lonText = SettingsInput.text(s.longitude, set: s.locationSet)
    }

    // Saves only input that makes sense. Otherwise nothing is saved: the status line says why and the field that was
    // wrong goes back to its saved value.
    private func saveAndRefresh() {
        let saved = Store.shared.settings
        switch SettingsInput.apply(latitude: latText, longitude: lonText, to: settings) {
        case .failure(let problem):
            statusMessage = problem.message
            switch problem {
            case .latitude: latText = SettingsInput.text(saved.latitude, set: saved.locationSet)
            case .longitude: lonText = SettingsInput.text(saved.longitude, set: saved.locationSet)
            case .repository:
                settings.githubOwner = saved.githubOwner
                settings.githubRepo = saved.githubRepo
            }
        case .success(let checked):
            settings = checked
            showCoordinates(checked)
            Store.shared.settings = checked
            // On a device the token goes only into the Keychain; if it refuses, say so rather than refresh with the old one.
            if let problem = Store.shared.saveGitHubToken(token) {
                statusMessage = problem
            } else {
                Task { await refresh() }
            }
        }
    }

    // Fetches with the stored settings, updates the previews, then asks the widgets to follow.
    @MainActor
    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        statusMessage = "Fetching..."
        async let d = DataLoader.loadDay(maxAge: 0)      // always fetch: the widgets then reuse this
        async let q = DataLoader.loadQuotes(maxAge: 0)
        let (day, quotes) = await (d, q)
        daySnapshot = day
        quoteSnapshot = quotes
        isRefreshing = false
        statusMessage = SettingsInput.refreshLine(day: day, quotes: quotes, weatherAsked: Store.shared.settings.locationSet)
        WidgetCenter.shared.reloadAllTimelines()
    }
}

#Preview {
    ContentView()
}

// MARK: - Painted styling for the settings form

private struct StoneHeader: View {
    var text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(Serif.font(13, weight: .semibold))
            .tracking(0.8)
            .foregroundStyle(Stone.gold)
            .legible()
    }
}

private struct StoneFooter: View {
    var text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.footnote)
            .foregroundStyle(Stone.goldMuted)
    }
}

// The painted sky behind the form, following the time of day, with a mountain range behind the title.
private struct AppGround: View {
    var body: some View {
        let clock = SkyClock(now: Date(), weather: nil)
        PaintedSky(palette: SkyPalette(clock: clock, condition: .clear), horizon: 0.19, reliefName: "AppSky")
            .overlay {
                if !clock.isDay { Stars(region: CGRect(x: 0.04, y: 0.03, width: 0.92, height: 0.1), count: 26, sparkles: 5) }
            }
            .overlay {
                GeometryReader { geo in
                    Group {
                        if clock.isDay { SunDisc(radius: 11) } else { MoonDisc(radius: 11, phase: MoonPhase(date: Date())) }
                    }
                    .position(x: geo.size.width * 0.44, y: geo.size.height * 0.088)
                }
            }
            .overlay(MountainRange(layers: Ridges.app, night: !clock.isDay, fade: 0.19...0.26))
            .drawingGroup()
    }
}

// Espresso row fill with a lit top edge, so form rows read as painted slabs on the scene.
private struct StoneRow: View {
    var body: some View {
        StoneSurface(material: .panel)
            .overlay(StoneMaterial.panel.lighting)
            .overlay(alignment: .top) {
                LinearGradient(colors: [Stone.goldBright.opacity(0.14), Color.clear], startPoint: .top, endPoint: .bottom)
                    .frame(height: 5)
            }
            .drawingGroup()
    }
}

// A basin cut into a dark painted board behind the previews, so the widgets stand off the page.
private struct PreviewTray: View {
    var body: some View {
        let shape = RoundedRectangle(cornerRadius: 32, style: .continuous)
        StoneSurface(material: .appPanel)
            .overlay(Color.black.opacity(0.25))
            .clipShape(shape)
            .overlay(CarvedRecess(shape: shape))
            .overlay(shape.inset(by: 5).stroke(Stone.gold.opacity(0.3), lineWidth: 0.7))
    }
}

// A widget at its design shape, as wide as the row: the rococo views scale themselves from their iPhone 17 layout,
// so this only gives them the widget's proportions, its rounded corners and a shadow on the tray.
/// The four previews. Equatable, so they're drawn again only when the data they show changes.
private struct WidgetPreviews: View, Equatable {
    let day: DaySnapshot
    let heroQuote: Quote
    let quote: Quote
    let quoteError: String?

    var body: some View {
        VStack(spacing: 16) {
            WidgetPreview(size: .large) { RococoDayView(snapshot: day, quote: heroQuote, size: .large) }
            WidgetPreview(size: .medium) { RococoDayView(snapshot: day, quote: nil, size: .medium) }
            WidgetPreview(size: .medium) { RococoTodayView(snapshot: day, size: .medium) }
            WidgetPreview(size: .medium) { RococoQuoteView(quote: quote, size: .medium, date: day.date, error: quoteError) }
        }
    }
}

private struct WidgetPreview<Content: View>: View {
    var size: BaroqueSize
    @ViewBuilder var content: Content

    var body: some View {
        let design = size.designSize
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        content
            .aspectRatio(design.width / design.height, contentMode: .fit)
            .clipShape(shape)
            .containerShape(shape)
            // One flat layer: its blurs, reliefs and gradients are composited once, not again on every scrolled frame.
            .drawingGroup()
            // The shadow from a plain shape behind it, which is cheap to draw.
            .background(shape.fill(Stone.shadow).shadow(color: Stone.shadow.opacity(0.6), radius: 10, x: 0, y: 5))
    }
}

extension ContentView {
    // Gold serif titles; a dark blurred bar once content scrolls under it.
    static func applyStoneNavigationBar() {
        func serif(_ size: CGFloat, _ weight: UIFont.Weight) -> UIFont {
            let base = UIFont.systemFont(ofSize: size, weight: weight)
            guard let descriptor = base.fontDescriptor.withDesign(.serif) else { return base }
            return UIFont(descriptor: descriptor, size: size)
        }
        let gold = UIColor(Stone.gold)
        let halo = NSShadow()
        halo.shadowColor = UIColor(Stone.night).withAlphaComponent(0.85)
        halo.shadowBlurRadius = 6
        halo.shadowOffset = .zero
        let scrolled = UINavigationBarAppearance()
        scrolled.configureWithDefaultBackground()
        scrolled.backgroundEffect = UIBlurEffect(style: .systemUltraThinMaterialDark)
        scrolled.backgroundColor = UIColor(Stone.night).withAlphaComponent(0.7)
        let edge = UINavigationBarAppearance()
        edge.configureWithTransparentBackground()
        for appearance in [scrolled, edge] {
            appearance.largeTitleTextAttributes = [.font: serif(34, .bold), .foregroundColor: gold, .shadow: halo]
            appearance.titleTextAttributes = [.font: serif(17, .semibold), .foregroundColor: gold]
        }
        let bar = UINavigationBar.appearance()
        bar.standardAppearance = scrolled
        bar.compactAppearance = scrolled
        bar.scrollEdgeAppearance = edge
    }
}
