# Baroque handoff, 2026-11-02

## Where things stand

**Tomorrow (2026-11-05): `IPHONE_SETUP.md` has every step for putting Baroque on your iPhone.**

**Version 1.0.0 (2026-11-04): the rococo widgets.** Day, Today, Quote and Battery, in the painted rococo look built for your Bathing Pool wallpaper, plus your 24 home screen icons in the app. See "Rococo ships in the real widgets" below. It builds clean for the simulator, the 70 parser tests pass, and the 5 UI tests pass (the fake-token test was fixed to scroll back to the preview and re-run alone). On the iPhone 17 simulator:
- All four widgets were placed on the home screen and rendered by WidgetKit with live weather and the 5-day forecast.
- Tapping the quote changes it.
- A fake token's 401 reaches both the app and the widgets.
- Captures are in `screenshots/rococo-home/`.

The notes below are from the first build (the stone, then painted-night look).

The work ran overnight with four roles: a build lead (me), a parser tester, a runtime tester and a design reviewer.

- **Builds clean.** Every configuration has zero errors and zero warnings:
  - Debug for the simulator
  - Release for the simulator
  - an unsigned device build (`generic/platform=iOS`, `CODE_SIGNING_ALLOWED=NO`)
- **Parser tests pass:** 70 of 70 (`cd ParserTests && swift test`).
- **UI tests pass:** 5 of 5 on the iPhone 17 simulator (iOS 26.4), run on the final code after erasing the simulator. They put the widgets on the home screen and check five things:
  - the fresh state
  - the cached state
  - the next-quote arrow
  - a fake-token 401
  - the app preview
- **Verified in the simulator:**
  - Weather loads live from Open-Meteo with no key for Los Angeles: 55–56°F at night and 67°F in the morning, clear; 65–66°F and overcast in the evening run of the painted build. High 76 / low 52–53, sunrise 06:13 and sunset 16:59. The icon is a moon at night.
  - With no token, both widgets show a readable error rather than a blank card.
  - With cached data, they show the cached tasks and quotes plus a "Cached · No GitHub token." line.
  - The large Day widget shows 5 tasks and "+2 more". The medium shows 3.
  - The clay arrow advances the quote.
  - A fake token typed into the app reaches the widget extension: the widget shows "GitHub rejected the token (401)".
- **Not verified:** real vault data. No token exists, so tasks and quotes have only been tested on input shaped like your vault, never on the vault itself.

There's no iPhone 15 simulator with Xcode 26.4, so I used the iPhone 17 instead.

## The three things left for you

1. **Sign in and pick a team.**
   - Open `Baroque.xcodeproj`, then go to Xcode > Settings > Accounts and add your Apple ID.
   - Under Signing & Capabilities, pick that team for both the **Baroque** and **BaroqueWidgetExtension** targets. **BaroqueUITests** only needs a team if you ever run the UI tests on a phone.
   - Plug in the phone, choose it as the run destination and press Run. The first time, go to Settings > General > VPN & Device Management and trust the certificate.
   - If Xcode refuses the App Groups capability on a free personal team, see "Known gaps" below.
2. **Create a GitHub token** and paste it into the app:
   - Go to github.com > Settings > Developer settings > Personal access tokens > Fine-grained tokens > Generate new token.
   - Repository access: only the author's vault repository. Permissions: Contents, Read-only.
   - In Baroque, paste it into "Personal access token" and tap **Save & Refresh**.
   - Your tasks should replace the "No GitHub token" line.
3. **Quotes file:** yours is `main/Quotes/Quotes.md` in the vault (the app's default path since 2026-11-05). It reaches the widgets once the vault is pushed to GitHub.

Then long-press the home screen, tap Edit, then Add Widget, and choose Baroque.

## What changed and why

### Build and project
- **The original generated project built on the first try.** It wasn't broken.
- **I switched to xcodegen.** `project.yml` is now the source of truth for `Baroque.xcodeproj`, because I needed a UI-test target that can drive SpringBoard. Running `xcodegen generate` rebuilds the project. `gen_pbxproj.py` is now a small shim that calls xcodegen, so the old command still works. The original generator is not in the repo.
- **What stayed the same:**
  - App bundle ID `com.ryanfernandez.terra`
  - Extension bundle ID `com.ryanfernandez.terra.widgets`
  - App Group `group.com.ryanfernandez.terra` on both targets
  - `Shared/` compiled into both targets
  - iOS 17 minimum
  - `DEVELOPMENT_TEAM` left blank on purpose, so you choose it
  - No bundle ID was changed.
- **New target:** `BaroqueUITests` (`com.ryanfernandez.terra.uitests`).
- **Warnings fixed:**
  - The widget asset catalog had no `AccentColor`. I added it, plus a `WidgetBackground` color.
  - The device build complained about iPad orientations, so the iPad now allows all orientations.
  - A duplicate `UILaunchScreen` entry is gone.

### Data layer (`Shared/`)
- **No token used to look like "nothing due".** Your vault repo is private, so without a token GitHub answers 404. The old code read every 404 as "today's daily note doesn't exist yet" and showed "Nothing due. Nice." Now only a missing daily note is ignored. A missing master list is reported as an error, and no token shows as "No GitHub token. Add one in the Baroque app." Quote fetches do the same.
- **Readable GitHub errors:** for example "GitHub rejected the token (401)" and "GitHub denied access (403)".
- **Cached data on failure:**
  - A failed fetch keeps the cached tasks and records the error, and both widgets now show an error line even when they are displaying cached content.
  - Cached weather is only reused on the day it was fetched.
- **Token storage** (`Store.swift`): two fixes, and the UserDefaults fallback is kept.
  - If the Keychain item can't go into the shared access group, a copy now stays in the App Group UserDefaults. Before, the copy was deleted even when the widget couldn't read the Keychain item.
  - Saving an empty token now clears it.
- **Quote rotation:**
  - Every timeline reload used to restart at the same six quotes, so the rotation never reached quote 7 unless you tapped the arrow. It now advances on fixed time slots.
  - The app preview now uses the same calculation, so the preview and the widget show the same quote.
- **Smaller fixes:**
  - The midnight date flip is correct on daylight-saving days.
  - Task paths listed twice are fetched only once; before, they produced duplicate tasks and IDs.
  - The weather icon switches to night symbols using Open-Meteo's `is_day`.

### Parsers (`Shared/Parsers.swift`, parser tester)
Bugs fixed, each covered by a test:
- **Tasks:**
  - A priority written after the date (`📅 2026-06-05 ⏫`) was lost.
  - `- [ ]` lines inside code blocks, such as a `tasks` query block, were counted as tasks.
  - `+` and numbered checkboxes, and tasks inside callouts, were ignored.
  - Emoji followed by a variation selector were missed.
  - 🆔, ⛔ and 🏁 fields were left in the task text.
  - Windows line endings doubled the line numbers.
  - A byte order mark hid the first line.
  - Dates were wrong on daylight-saving days.
- **Task text cleanup:**
  - Embeds showed as `!img.png`.
  - `[[Note#Heading]]` now reads "Note > Heading".
  - `issue #3` lost its `#3`.
  - Italic, strikethrough, highlight and code markers stayed in the text.
  - `%% comments %%` were not removed.
- **Agenda order** (before, future tasks were dropped entirely). Inside each step, tasks sort by priority, then date, then file order:
  1. Overdue
  2. Due today
  3. Undated 🔺 / ⏫
  4. Due within 3 days
  5. Other undated
  6. Due later
- **Quotes:**
  - `> [!quote] Title` now uses the title as the author.
  - `[!quote]-` and `[!quote]+` no longer leak a `-` or `+` into the text.
  - `[!note]` callouts are no longer treated as quotes.
  - A bare `>` line no longer splits one quote into two.
  - `- [ ]` tasks are no longer read as quotes.
  - Paired “curly quotes” are stripped correctly.
  - The repo's `Quotes.md` parses into exactly its 4 quotes.

### Design (design reviewer)
- **Measured widget sizes** on the iPhone 17 home screen: small 164×164, medium 348×164, large 348×365 points.
- **Fit problems fixed:**
  - Medium Day: the left column needed 169pt but had 138pt.
  - Large Day: up to 386pt of content in 350pt.
  - Quote widget: the author ran under the arrow, and long quotes overflowed.
  - Small Day: it hid the error and said "No tasks today" instead.
- **Contrast:** raised to about WCAG AA. Light text on the sage tile went from 2.2:1 to 4.4:1, and the secondary text on cream from 3.6:1 to 5.6:1. New solid ink colors live in `Theme.swift`.
- **Stone look:**
  - A fine speckle grain on the paper and olive backgrounds, so they read as mottled stone.
  - The quote text size picks the largest size that fits.
  - The quote mark and the author rule are clay.
- **Settings app:**
  - It sits on stone paper with cream rows instead of the stock white form.
  - It is forced to light mode, because the palette has no dark version.
  - Previews are drawn at true widget size.
  - Text fields are labeled.
- **App behavior:**
  - It refreshes on launch, so the preview is live without tapping Save.
  - The duplicate error row is gone.

### Stone redesign (follow-up, after "too plain and flat and simple")
The first pass was clean but flat: smooth gradients with a faint speckle. The widgets now look like cut stone:
- **Real stone textures,** generated by `scripts/make_textures.py` into `Shared/StoneTextures.xcassets`:
  - travertine for the Day ground, with layered strata and small voids
  - honed limestone for the task slab
  - flecked sage stone for the weather tile
  - dark olive serpentine with pale veins for the quote ground
  - terracotta for the clay pieces
  The app gets full-screen travertine and a walnut stone tray in `Baroque/Assets.xcassets`. Fine grain is drawn on top in SwiftUI, so the textures stay small (about 1 pixel per point) and well under WidgetKit's image size limit.
- **Depth:**
  - Tiles are raised slabs with a visible darker cut edge, a lit chamfered rim and a warm cast shadow.
  - The widget itself gets a rim light on top and shade along the bottom, following its real corner shape.
  - The week strip is a channel cut into the ground.
- **Carved and engraved type:**
  - The date numeral is cut in, with an inner shadow and a lit lip.
  - Labels on light stone are engraved. Text on sage, olive and clay is embossed.
- **Clay pebbles** for today's day, the task count, the "1d late" mark and the next arrow. Each is polished, with a highlight and a contact shadow.
- **More detail:**
  - The week strip shows dates under the weekday letters; past days are dimmed.
  - Task priorities are small polished stones set in carved sockets.
  - Rows are separated by engraved hairlines.
  - Due dates are serif italics.
  - Sunrise and sunset times sit under the date on the large widget. They come from Open-Meteo, cached snapshots without them still load, and the times drop out on 6.1" phones to keep room for five tasks.
  - The weather has warm sun and moon glyphs, an engraved rule and ↑/↓ highs and lows.
  - On the quote widget, an oversized quote mark is carved into the stone behind the text, inside a carved panel line.
- **Fit:** still five tasks on large and three on medium, checked at all three phone sizes by the render harness (`fit.txt`).

### Mountain landscape (follow-up, after "more mountain aesthetic, use the space well")
The open space in each widget is now a mountain scene carved in stone (`Shared/Landscape.swift`):
- **Ridges:** three layers of seeded, hand-placed ridgelines (far, mid, near), each lifted off the one behind by a soft shadow. They have lit crests, snowcaps and stone grain, and they dissolve into valley mist where the week strip and task slab begin.
- **Large Day:**
  - The middle of the header, which used to be empty, holds the mountain and a sky.
  - The sun travels a dotted arc from today's real sunrise to sunset, from Open-Meteo. At night a crescent moon and stars take over, and the sky dims. A warm glow appears around sunrise and sunset.
  - The sky draws stone clouds, rain, snow, a lightning bolt or fog banks from the current weather code.
  - The weather moved out of its tile into the sky on the right: temperature, condition, high and low, and the next sunrise or sunset.
- **Medium Day:** the ridges rise under the date, and the weather stands in cream on the dark near ridge.
- **Small Day:** the ridges fill the band between the date and the task slab, and the temperature sits in the sky.
- **Quote:** dark evening ridges with a warm glow behind them fill the bottom. Short quotes no longer leave a hole, and the author line and arrow sit on the nearest ridge. Snow is left off here so long quotes never run over bright patches.
- **App:** a mountain range sits behind the "Baroque" title, and the form scrolls over it.
- **Weather states:** the render harness has new ones (`sky-partly`, `sky-snow`, `sky-storm-dusk`, `sky-clear-night`), so every sky can be checked at a glance.

### Painted look (follow-up, after the storybook reference image)
The widgets keep the same 3D construction but are now painted, in the reference's moody palette: night-sky and forest greens, espresso panels, copper pebbles and gold lettering.
- **Brushwork, not stone.** `scripts/make_textures.py` now paints every texture with brush strokes. Each surface is covered with opaque strokes that follow a direction field, coarse to fine. Bristle marks and lit paint ridges (impasto) go on top, so the paint has relief. `Shared/PaintTextures.xcassets` replaces `StoneTextures.xcassets`:
  - an espresso panel for the task slabs and the app's rows
  - copper for the pebbles
  - a moon surface
  - two relief overlays, light and dark brushwork with transparency, that go over colors chosen at run time: soft cloud wisps for the sky, and strokes down the slopes for the ridges
  A faint canvas weave is drawn on top in SwiftUI. Widget textures stay near 1 pixel per point.
- **Live painted sky** (`Shared/Landscape.swift`):
  - The sky's colors follow the time of day: deep teal by day, blue-black at night, copper at sunrise and sunset. They turn gray in overcast, rain, snow and fog.
  - The moon shows tonight's real phase, computed from the date, with a soft halo. The sun is a painted disc in a wide glow, and both light up the sky around them.
  - Clouds are brushed, with rims lit gold by the sun or pale by the moon.
  - Stars at night are four-pointed sparkles among small points, kept in open sky away from the text.
- **Ridges:** far, mid and near layers in atmospheric color, brushed along the slopes, with spruce silhouettes along the nearer crests. Snow is cream by day and gray-blue at night.
- **The same 3D effect, repainted:**
  - The task slabs are raised espresso boards with a cut edge, a lit chamfer, a dark cast shadow and an inlaid gold hairline.
  - The week strip is still a channel cut into the scene.
  - Today, the count, "1d late" and the next arrow are copper pebbles.
  - Task priorities are glowing gems in carved sockets.
  - The date numeral and the temperature are gold leaf: a gradient with an inner shade and a shadow beneath. Other text is raised parchment or gold with a soft dark halo, so it reads over the ridges.
- **Ornament:** every widget has a gold hairline frame with a sparkle set into its top edge, like the frame round a storybook plate. The quote mark is faint gold leaf.
- **Medium Day** gets a small sun or moon beside the numeral. **Quote** shows tonight's moon rising behind the far ridge, under an evening sky with a copper glow.
- **App:** it now runs in dark mode, on the painted sky with the moon or sun, stars and mountains behind the gold "Baroque" title. Rows are espresso and controls are copper.
- **App icon:** a crescent over a snowy peak and spruce ridges, in a gold frame. `-renderWidgets` renders it from the same SwiftUI scene pieces, and it is copied into `AppIcon.appiconset` as an opaque PNG.
- **Fit:** unchanged. Five tasks fit on large and three on medium at all three phone sizes, and all 117 renders report "ok".
- **UI test fix:** the next-arrow test used to find the quote widget as the darker of the two mediums. Both are dark now, so the test picked the Day widget and its tap opened the app. It now picks the cooler one: the Day widget's right side is the warm espresso slab, the Quote's is night sky.
- **Catalog colors:** the widget's `WidgetBackground`, shown while a widget loads, is now forest green instead of cream, and the accent colors are copper.

### Alternative looks (MockLab, 2026-11-03, after "make different mocks with widely different aesthetics")

The shipped widgets are unchanged. These are six mock directions to choose from, built by six design agents in parallel. Each one shows the same demo day and quotes at iPhone 17 widget sizes, next to the current painted look:

- **Field Journal:** a naturalist's sketchbook in daylight, with:
  - watercolor mountains
  - a washi-taped weather card
  - the week on grid tape
  - an inked checklist with a red-pencil ring around overdue tasks
  - handwritten quotes on ruled paper
- **Topo Survey:** a survey map, with:
  - contours over hillshade, drawn from one heightfield per widget
  - the week as a scale bar
  - tasks as numbered waypoints on a route
  - the quote in a cartouche, with an elevation profile on the large size
- **Woodblock:** an original ukiyo-e print on washi, with:
  - a graded indigo sky
  - colour-block ranges with wood grain
  - layered mist bands
  - a vermilion date seal and a weekday tanzaku
  - tasks on a handscroll
- **Stained Glass:** backlit Art Nouveau glass, with:
  - jewel panes in lead
  - a rose-window sun and faceted mountains
  - arched windows for the week
  - tasks lettered on pale glass
- **Paper Diorama:** a cut-paper shadowbox, with:
  - five to eight cardstock layers with real shadows
  - bunting for the week
  - tasks on an index card held by a paper clip
  - luggage-tag due dates
- **Pixel Quest:** a 16-bit overworld on a 2 pt pixel grid, with:
  - a hand-drawn pixel font
  - a Quest Log window with a pointing-glove cursor
  - an owl who reads the quote

How they are built:

- **`MockLab/`** is a macOS SwiftPM package with one executable target per look, so the looks build independently and never touch the simulator.
- **`Kit/`** is linked into every target. It renders the six widgets (scale 3) and a board (scale 2) with SwiftUI's `ImageRenderer`. It uses the app's real `Models`, `Parsers` and `DemoData` through symlinks.
- **Views are pure SwiftUI** (Canvas, Path, gradients), so the chosen look ports into `Shared/` as is. It needs `Image(nsImage:)` in `Mock.texture` swapped for asset-catalog images. Fonts are limited to families that ship on iOS.
- **Textures** come from `MockLab/Textures/<look>/make.py`. Widget textures are about 1 px per point.
- **Build:** all six targets build from clean with no warnings.

Per-look caveats:

- **Not checked against WidgetKit's render budget:**
  - Stained Glass draws 100–200 blurred panes per widget.
  - Paper Diorama and Field Journal stack many shadowed or washed layers.
  - Pixel Quest uses no textures and is the lightest.
- **Weather:** in Paper Diorama only the weather glyph changes with conditions; its sky stays sunny.
- **Layout flaws:**
  - Topo leaves "us." alone on the last line of the medium quote.
  - The Pixel Quest small Day widget runs 4 pt past the margin with a two-digit date and a three-digit temperature.
  - The Field Journal medium Day widget's left page is crowded.

### Layout experiments (MockLab, 2026-11-03, after "still not the correct look I want experiment with different layouts on the widget")

The shipped widgets are unchanged. This round keeps the painted look exactly (same paint textures, `Stone` palette, slabs, pebbles, gilt and mountains) and changes only the arrangement. Six design agents built one layout each, in parallel. Gallery: https://claude.ai/artifact/M3vzJCPFjA8fdaYrVd18eb (private).

- **Panorama:** the landscape fills every widget.
  - The sun's arc spans the full width, with sunrise and sunset at its feet.
  - Tasks are written straight onto the dark valley floor, with no slab.
  - The quote is a caption under a tall moonlit range.
- **Next Up:** the first task is set at 21–30 pt on its own raised card.
  - The other tasks are cards stacked behind it, and date and weather shrink to one line.
  - The quote is the top card of a deck, with the arrow on its corner.
- **Bento:** each widget is a set of separate tiles and carved wells.
  - The tiles hold a framed sky window, a gilt date page, weather, the week and a task slab.
  - The mountains show in the gutters.
- **Medallion:** symmetrical about the centre line.
  - The date is a coin-lettered disc inside a sunrise-to-sunset dial, with a pebble at the current time.
  - Quotes are centred under the moon in an arch.
- **Trail:** tasks are grouped Late, Today, Soon and Someday as copper stops on a gold thread.
  - The week strip starts today and counts what is due each day.
  - Medium is a path along a ridge; quotes are margin notes.
- **Storybook Plate:** figure and ground are swapped.
  - The brushed board is the widget and the scene is a recessed, gold-framed plate.
  - The weather is its caption, tasks are a ruled ledger beside a date column, and quotes have a gilt drop cap.

How they are built:

- **`MockLab/PaintKit/`** compiles the app's own sources through symlinks: `Shared/Theme.swift`, `Landscape.swift`, `Views.swift`, `Models.swift`, `Parsers.swift` and `DemoData.swift`, plus the harness `Kit/MockKit.swift`.
- **Textures:** `PaintAssets.install()` compiles `Shared/PaintTextures.xcassets` with `xcrun actool` into the executable's folder, so `Image("PaintPanel")` resolves on macOS exactly as on iOS.
- **The `Current` target** renders the shipped `DayView`/`QuoteView` through the same path as a baseline. It matched the iOS `-renderWidgets` output apart from the sky's time of day.
- **Layout targets** are `LPanorama`, `LFocus` (Next Up), `LBento`, `LMedallion`, `LTrail` and `LPlate`, one per layout. Each only adds its own prefixed views (`PN`, `NU`, `BN`, `MD`, `TR`, `PL`). Nothing in `Shared/` was edited.
- **Kit split:** `Kit/MockExtras.swift` now holds the aesthetic mocks' `SeededRandom` and `Color(hex:)`, which `Kit/MockKit.swift` used to define. They moved because `PaintKit` compiles the app's own versions of both.
- **Build:** all 13 MockLab targets build from clean with no warnings.
- **Other states:** each layout except Panorama has a `*States.swift` file, and Panorama has a hook in `PNDay.swift`. These render empty, error, no-weather, night, weather and quote-length states when an environment variable is set: `PN_STATES`, `NU_STATES_DIR`, `BN_STATES_DIR`, `MD_STATES_DIR`, `TRAIL_STATES` or `PLATE_STATES_DIR`. The agents checked those renders; I reviewed the demo renders. Drop these hooks when porting.

Porting notes:

- **Content margins:** Panorama, Bento and Storybook Plate place content against the whole widget, so the widget would use `.contentMarginsDisabled()`.
- **Fixed positions:** Next Up and Medallion use fixed point positions tuned to iPhone 17. Check them on the 158 pt and Pro Max widget sizes.
- **Fewer tasks than shipped:**
  - Next Up small shows only the hero.
  - Medallion medium shows 2 tasks and its small shows only the count.
  - Panorama large shows 4.
  - Trail medium shows one task per group.
- **Render cost:** about the shipped level for each. Bento, with the most tiles, and Next Up, with one shadow per stacked card, are the ones to watch.

### Film looks (MockLab, 2026-11-03, after "try using a wong kar wai or wes anderson aethetic. experiement with making it in those ideas")

The shipped widgets are unchanged. Four design agents built one new look each, in parallel: two after Wong Kar-wai and two after Wes Anderson. Every widget keeps mountain scenery, and none copies film stills, titles, names or logos. Gallery, with the current design for comparison: https://claude.ai/artifact/SBAQyKVC1rt1Z5sgApJ68a (private).

- **Neon Rain** (`NeonRain`, prefix `NR`, Wong Kar-wai): the night city at the foot of the mountains, seen through fogged, rain-beaded glass.
  - The date is a red neon tube numeral beside a sign with the weekday in Chinese (星期二 for Tuesday; it is the only Chinese text).
  - Tasks sit on a smoked-glass panel with dot-matrix due stamps.
  - Quotes are yellow film subtitles over neon bokeh, with light trails smeared as if shot at a slow shutter.
- **Crimson Hours** (`CrimsonHours`, `CH`, Wong Kar-wai): a 1960s room at evening.
  - The date is on a tear-off calendar against crimson flock wallpaper.
  - A lacquered window shows misty ridges with a lamp-lit stair road.
  - Tasks are numbered lines in a folded letter.
  - Quotes are intertitles beside a door left open on a lamp-lit jade room.
- **Alpine Hotel** (`AlpineHotel`, `AH`, Wes Anderson): a symmetrical pastel miniature set, with an invented pink Hotel Baroque on an alpine ledge under a velvet valance.
  - The date is on a postage stamp and the weather on a brass barometer.
  - The week is a row of pigeonholes, and tasks are numbered room keys in the register.
  - Quotes are chapter cards, a framed notice and a postage stamp, with a brass desk bell as the next-quote button.
- **Expedition** (`Expedition`, `EX`, Wes Anderson): a felt-and-Kodachrome field station.
  - On the large Day widget the mountain is cut away into five numbered rooms, one task each.
  - The date and weather are embroidered patches, and the medium widget's tasks are a mission log on a clipboard.
  - Quotes are typed on library catalogue cards.

How they are built:

- **Harness:** these are aesthetic mocks on `Kit/`, like the first round, not `PaintKit/`.
- **Textures:** each look generates its own from `MockLab/Textures/<slug>/make.py`, at about 1 px per point.
- **States:** each has a states hook that renders empty, error, no-weather, rain, snow and long-quote states outside `out/`: `NR_STATES_DIR`, `CH_STATES_DIR`, `AH_STATES_DIR` and `EX_STATES_DIR`. The agents checked those renders, and I spot-checked Neon Rain's.
- **Sunrise and sunset times:** the agents reported that `Mock.time` printed 24-hour times under this Mac's region setting. Crimson Hours and Alpine Hotel format the times themselves, and I switched Neon Rain and Expedition to a 12-hour format so they agree with their "9:41 A.M." lines.
- **Build:** all 17 MockLab targets build from clean with no warnings.

Porting notes:

- **Time of day:** each look picks its own. Neon Rain is always night, and Crimson Hours always evening with a fixed crescent moon. Alpine Hotel and Expedition are always daytime. The weather code still changes each scene. The quote widgets have no weather data, so they show a fixed sky; Neon Rain's quotes always show heavy rain.
- **Layout:** all four place things at fixed points for the iPhone 17 widget sizes and run their art to the edges, so a port needs proportional placement and `.contentMarginsDisabled()`.
- **Render cost:** all four are heavier than the shipped widgets. Neon Rain is the heaviest, with about 1,000 rain strokes and up to 200 glass beads in the quote widgets, and Canvas blur filters. Profile the chosen one on a device.
- **Small type:** Alpine Hotel's stamp labels are 7 pt, and Crimson Hours' calendar week letters are 6.5 pt.

### Grand Hotel (MockLab, 2026-11-03, after "Remove the day of the week and keep going on the grand budapest hotel aesthetic. I want the look of it but brign the art style back to what we were doing before.")

The shipped widgets are unchanged. One design agent built **Grand Hotel** (target `GrandHotel`, prefix `GH`). It's in the same gallery, listed first: https://claude.ai/artifact/SBAQyKVC1rt1Z5sgApJ68a.

- **What it keeps from Alpine Hotel:**
  - the invented pink Hotel Baroque on its ledge with a funicular, under a velvet valance
  - symmetry
  - the postage-stamp date and brass barometer
  - the pigeonhole week and the room-key register
  - the chapter card, lobby notice and airmail stamp for quotes
  - the desk bell for the next quote
- **What changed:** the flat vector gouache is gone. It's drawn in the shipped painted style:
  - brush-painted materials made with the same stroke painter as `scripts/make_textures.py` (velvet, cream, lilac, mint, plum, brass, raspberry, wall, facade)
  - raised slabs built like `StoneSlabModifier`, and domed pebbles
  - gilt serif numerals
  - the shipped `RidgeProfile`/`MountainRange` ridges and painted sky, recoloured
- **No weekday anywhere:**
  - The stamp shows only the day and month, and the week row only dates.
  - "a thought for Tuesday" became "with the compliments of the house", and "TUESDAY'S THOUGHT" became "NOTICE TO GUESTS".
  - The pigeonhole week row is still on the large Day widget.
- **Time of day:** like the shipped sky, it follows the clock and weather. It is pastel by day and rose at dusk, and lilac at night with the hotel windows lit.
- **Type:** nothing is under 8 pt.
- **How it's built:** it links `PaintKit/`, so it uses the app's own `ChamferRim`, `CarvedRecess`, `Gilt`, `Sparkle`, `CanvasWeave`, `Serif` and the Landscape types.
  - Its textures come from `MockLab/Textures/grand-hotel/make.py`, which imports `scripts/make_textures.py` and adapts two of its functions. The script itself is not edited.
  - States render with `GH_STATES_DIR` (empty, errors, no weather, rain, snow, partly cloudy, dusk, night, long and authorless quotes).
- **Porting notes:**
  - Move the textures into an asset catalog and replace `GHTex`/`Mock.texture` with `Image("GH…")`.
  - Use `.contentMarginsDisabled()`.
  - Make the fixed iPhone 17 prop positions proportional.
  - The tower clock shows the timeline entry's time, so freeze it or refresh often.
  - The large Day's sun arc passes close to the postmark mid-morning.

### Grand Hotel Quiet and Spare (MockLab, 2026-11-03, after "still too crowded and busy. need to find how to simplify but keep the widget information dense.")

One design agent built two calmer versions of Grand Hotel in the target `GrandHotelCalm`, with prefix `GC`. Both show exactly the same information:
- the date, with no weekday;
- temperature, condition, high/low, and the next sunrise or sunset;
- the week's dates;
- 5, 3 or 1 tasks with due labels, the count and "+N more";
- quotes with their authors and a next-quote button.

They are first in the same gallery: https://claude.ai/artifact/SBAQyKVC1rt1Z5sgApJ68a.

- **Grand Hotel Quiet:** Grand Hotel's arrangement with the props removed.
  - It keeps a slim valance as the one frame.
  - The date and weather are gilt numerals and spaced Futura capitals on the sky.
  - The week is one carved channel (today raised, dots on due days), and the tasks are on one quiet slab.
  - On the large Day widget, decorative groups go from about 15 to 8 and materials from 7 to 4.
- **Grand Hotel Spare:** each widget is only the painted scene and one raised slab.
  - The date and weather sit in two centred columns either side of the hotel.
  - The week is a row of dates on the slab.
  - It uses at most three text sizes and one accent (raspberry).
  - Large Day goes to 4 elements and 1 material.
- **What was removed in both:** the stamp, postmark, barometer, plaques, pigeonholes, wax seals, room keys, priority sparkles, funicular, cable cars, curtains, chapter and notice headings, and the airmail envelope. The hotel is simpler, with 36 windows instead of 62. Weather particles are at 42% density.
- **Texture:** a quiet card texture, `MockLab/Textures/grand-hotel-calm/make.py` → `vellum.jpg` (340×270). The brushwork shows only in a feathered band at each slab's edge.
- **Shared code:** both share Grand Hotel's materials and scene through symlinks to `GHStyle.swift`, `GHScene.swift` and `GHProps.swift`.
  - `GHScene.swift` gained `GHHotelSpec.simple`, `GHSceneSpec.weatherDensity` and `GHValance(tassels:crest:braid:)`.
  - The defaults leave Grand Hotel unchanged. I checked that its renders are byte-identical.
- **States:** with `GC_STATES_DIR`, they render to `MockLab/out/grand-hotel-calm-states/`, including contact sheets. The agent checked these.
- **Side-by-side sheet:** `screenshots/films/grand-hotel-calm-compare.jpg`.
- **Decisions left to the user:**
  - Priority marks are gone, since the task order already follows priority.
  - Only the next sunrise or sunset shows.
  - On the large widgets the hotel draws the eye before the date.

### Old Master (MockLab, 2026-11-03, after the user sent a sepia classical-painting home-screen reference: "try this aesthetic")

The user sent a Pinterest image of a sepia "classical painting" home screen. Its palette is umber, taupe, cream and peach. The art is old-master oil paintings with dramatic clouds, and the data sits on a calm dark-umber calendar card with thin serif type and today circled in cream. The image is not stored in the project.

One design agent built **Old Master** (target `OldMaster`, prefix `OM`, PaintKit). It's first in the same gallery: https://claude.ai/artifact/SBAQyKVC1rt1Z5sgApJ68a.

- **The painting:** each widget is an original sepia oil painting of a sublime mountain landscape. Billowing cumulus lit from above, snowy peaks, mist between the ridges, dark firs in front, varnish, and fine craquelure and weave.
- **The panel:** the data sits on one dark-umber panel. Text is in Baskerville and Avenir Next: cream, with peach for today and late tasks. There are no frames or chips.
- **Information:** the same as the other looks. The large Day widget shows the date with the year as MMXXVI, the weather with high/low and sunset, the week as bare dates with today circled, 5 tasks, the count and "+N more". There is no weekday anywhere.
- **Textures:** `MockLab/Textures/old-master/make.py` paints them with `scripts/make_textures.py`'s brush functions, imported without bytecode. They are grey value studies at 1 px per point (`lo`, `hi` and `glow` layers per widget size), a quiet `panel.jpg`, a rain `veil.png`, and a board-only wallpaper.
- **Time of day:** the value studies are tinted at run time from `SkyClock`/`SkyCondition`. Day is umber and peach-cream, dusk amber, night a moonlit nocturne with tonight's phase, and grey weather drains to taupe. Rain is painted streaks, snow is up to 40 flakes, and fog is mist bands. The quote widgets follow the clock only.
- **Sun times:** I switched them to a 12-hour POSIX format ("sunset 4:58").
- **States:** with `OM_STATES_DIR` (no tasks, errors, no weather, rain, snow, dusk, night, one task, long and authorless quotes). The agent checked them. I re-rendered them after the time fix and checked dusk and night.
- **Porting notes:**
  - The alpha PNGs go into the asset catalog, drawn with `.renderingMode(.template)` and a gradient fill, plus one `.blendMode(.screen)` glow. Both need confirming in WidgetKit.
  - Panels sit at fixed positions for the iPhone 17 sizes, and each painting is composed around its panel, so other sizes need `make.py` reruns or adjustment.
  - Use `.contentMarginsDisabled()`.
  - At 1 px per point the brushwork reads soft up close.
  - The light on the peaks is fixed from the upper left.

### Old Master Inscribed, Folio and Cover (MockLab, 2026-11-03, after "I like the aesthetic but we need to make the widget itself more creative. Utilize more space")

Three design agents, working in parallel, each built a more inventive composition of Old Master.
- **Shared with Old Master:** the same paint, palette and type, and the same information with no weekday.
- **What changes:** each fills the whole widget instead of putting a card on a picture.
- **Code and textures:** all three link `../OldMaster/OMStyle.swift` and paint their own textures by importing `Textures/old-master/make.py`, with no bytecode. Old Master's renders are unchanged.
- **Gallery:** they lead the same page: https://claude.ai/artifact/SBAQyKVC1rt1Z5sgApJ68a.
- **Side-by-side sheet:** `screenshots/films/old-master-family.jpg`.

- **Inscribed** (target `OMInscribed`, prefix `OI`): no panel.
  - Each painting is planned as a dark cloud ceiling, then light, then a dark umber ground, and each piece of information sits in its band.
  - **Sky:** the date and weather sit in the clouds, and the sky is an engraved sundial arc from sunrise to sunset. It has Roman-numeral hours, is solid for daylight gone and beaded for daylight left, and the sun or moon sits at its place.
  - **Week and tasks:** the week runs along the treeline, and the tasks are written on a dark lake.
  - **Quotes:** set in the sky, with the author signing the dark bank.
  - **Porting:** needs timeline entries every 15 to 30 minutes so the dial moves.
- **Folio** (target `OMFolio`, prefix `OF`): each widget is an antique book lying open.
  - **The spread:** a tall plate with the weather as its caption ("Plate III" = the day of the month) faces a page with the month as the running head and the date as a red initial. The count is the opening sentence, tasks are numbered lines with due dates in the margin, "N more overleaf" covers the rest, the week is the page numbers, and errors show as a footnote.
  - **Quotes:** a commonplace book, with a turned page corner as the next-quote button.
  - **Colour and layout:** late tasks use old-book red-brown, because peach is unreadable on the paper. A custom `Layout` (`OFFlow.swift`) sets justified text with a drop initial.
- **Cover** (target `OMCover`, prefix `OC`): a magazine cover.
  - **The numeral:** a giant gilt date numeral stands between the sky and the snowy peak. Each painting is drawn twice, behind and in front through a `-front` mask, and the numeral is lit from the sun's side.
  - **Large Day:** the month and year as a dateline, a weather cover line, 5 tasks and a month calendar (dates only, today circled, due dots) on the dark ground.
  - **Quotes:** get a giant gilt quotation mark around the peak.
  - **Porting:** flatten the masked copy with `.compositingGroup()` before `.mask`, or a seam appears. Glyph geometry is duplicated in Swift (`OCCanvas.hero`) and `make.py` (`HEROES`).
- **States:** `OI_STATES_DIR`, `OF_STATES_DIR` and `OC_STATES_DIR` render empty, error, no-weather, rain, dusk, night, long and authorless quotes, and (Cover) two-digit dates. The agents checked them; I reviewed the demo renders.
- **All three:** fixed positions for the iPhone 17 sizes, and art to the edges, so `.contentMarginsDisabled()`.

### Cover chosen; mountain is now Cloudripper (MockLab, 2026-11-03, after "cover is the best one … can we make the mountain based off of cloudripper in the inyo national forest")

*Superseded: the mountain is now the Matterhorn (see "Mountain is now the Matterhorn" below). `cloudripper.json` and its `make.py` are in `backups/cloudripper/`.*

The user picked **Cover**. Its mountains are now the real Cloudripper: 13,525 ft, 37.14251° N 118.53053° W, the highest point of the Inconsolable Range, Inyo NF.

- **Data:** public AWS Terrain Tiles (terrarium encoding, zoom 12, about 30 m), a 7×7 tile block around the peak. The DEM's top comes out at 4,116 m (about 13,505 ft).
  - The tiles and a decoded grid stay in the session scratchpad and are not in the repo.
  - `MockLab/Textures/old-master-cover/cloudripper.json` (5.8 KB) holds the derived skylines: four distance bands, with Earth curvature and refraction. Textures rebuild from it without network access.
  - `make.py --profiles <dem.npy>` regenerates the JSON byte-identically.
- **Viewpoint:** the south ridge, 1.9 km SSW of the summit (37.12601° N, 118.53608° W, 3,909 m), looking NNE. Vertical exaggeration is 2×, and the field of view is 15–35° per canvas.
  - From Green Lake and the north side, the true summit hides behind Cloudripper's own north peak (4,067 m).
  - From South Lake the near slopes block it.
  - From Coyote Flat it is only a small bump.
  - About 1,500 viewpoints were searched to confirm this.
- **Composition:** each canvas's main peak is Cloudripper's real crown, between the numeral or quote mark and the dark ground. The large Day numeral is now 238 pt with its baseline at 190, which keeps about 30% overlap. A small "Cloudripper · 13,525 ft" label sits on the large Day and large Quote.
- **Limits:**
  - Only the crown fits, the top 1.3–3° of the real profile.
  - The dark foreground with firs is still invented.
  - At 30 m per pixel, finer detail is smoothed.
- **Images:** `screenshots/films/old-master-cover-cloudripper.jpg` (before, after and the skyline). The generic Cover's sources, textures and renders are backed up in the session scratchpad (`backup-omcover-generic/`).
- **Next:** port Cover into `Shared/` and `BaroqueWidget/` once the user OKs this version.

### Cover ported into the widgets (2026-11-03)

Old Master Cover, then with Cloudripper (now the Matterhorn, see below), is now the real Day and Quote widgets (small, medium and large). The painted-night code stays in `Theme.swift`, `Landscape.swift` and `Views.swift` for MockLab and the settings app's own UI; the widgets no longer use `DayView`/`QuoteView`. Backup of the previous app sources: `backups/painted-night-2026-11-03/`.

- **Code:** `Shared/CoverStyle.swift`, `CoverPainting.swift`, `CoverDay.swift` and `CoverQuote.swift`, ported from `MockLab/Sources/OMCover/` and `OMStyle.swift` (`OM…`/`OC…` became `Cover…`). The entry points are `CoverDayView(snapshot:settings:size:)` and `CoverQuoteView(quote:size:date:error:) { next }`. The widget passes `Button(intent: NextQuoteIntent()) { CoverNextButton() }`; previews and renders pass `CoverNextButton()`.
  - The sky follows `snapshot.date` (Day) or the timeline entry's date (Quote). Due notes ("1d late", "today", "Nov 4") are counted from the snapshot date too.
  - `maxTasks` caps the rows at the smaller of the setting and what fits (5 large, 3 medium, 1 small).
  - Errors: the mock's task-error and no-weather lines are kept. On large, the error now takes the place of the "7 tasks" count so it reads "cached · No GitHub token. A…" rather than "No GitHu…". The Quote widget shows a quiet peach error line under the author (large), beside the button (medium) or under the quote (small).
- **Widget extension:** both configurations use `.contentMarginsDisabled()`. The whole composition is foreground (the numeral sits between layers of the painting); `containerBackground` is `CoverInk.ground` (#24150C). Gallery descriptions are updated. The providers are unchanged.
- **Scaling:** every layout is fixed at the iPhone 17 size (164×164, 348×164, 348×365). `CoverFrame` lays it out there and scales it uniformly to the real widget, centred, with `GeometryReader` and `scaleEffect`. On a Pro Max this is ×1.037–1.046 and on a 6.1" phone ×0.963–0.970. Any sliver (at most 1.6 pt at the sides of a medium) shows the dark ground.
- **Textures:** `python3 scripts/export_cover_textures.py` copies the 26 PNGs from `MockLab/Textures/old-master-cover/` into `Shared/PaintTextures.xcassets` as `Cover*` imagesets and removes stale ones. `--paint` repaints them first with `make.py`; the rerun was byte-identical. Sizes: the large and medium canvases are 348×365 and 348×164 (`Lo`, `Hi`, `Glow`, `Front` each), small 164×164, `CoverGilt` 348×365 and `CoverVeil` 348×220. All are 1 px per point.
- **Two opacities differ from the mock.** MockLab loaded textures through `NSImage`, which draws a template image tinted with a translucent solid colour differently from the asset catalog. The gilt hollows came out about 30% stronger and the rain veil far fainter than their numbers. The port uses 0.205 for the gilt (was 0.16) and 0.2/0.26 for rain/storm (was 0.55/0.7), so the widgets look like what the mock showed.
- **Pixel check (MockLab):** `Current` now renders the shipped Cover views (PaintKit symlinks the four files). Against `out/old-master-cover/` at 3x, the mean difference is 0.02–0.15 levels per channel. Inside the widget the maximum is 4–7, from the gilt match. The larger maxima (23–32) are only on the anti-aliased rounded-corner edge. The rain state differs by a mean of 1.2 because the mock's veil pattern can't be matched exactly; snow, dusk and night are within 0.15.
- **Simulator (iPhone 17, iOS 26.4):** every widget renders on SpringBoard: Day and Quote, all three sizes, in the fresh, cached and 401 states. The next-quote button changes the quote. All 5 UI tests pass. `-renderWidgets` writes 207 renders (3 sizes × 3 families × 15 Day and 8 Quote states) and `fit.txt`, which now notes each size's scale. The iOS renders match the macOS ones apart from text anti-aliasing.
- **UI tests:** `quoteWidget()` now picks the medium widget with the bright cream button in its corner (0.79 against 0.09) instead of the warmer right side, which no longer tells them apart. The tap point moved to the new 24 pt disc. `capture_screenshots.sh` now makes `SHOT_DIR` absolute; a relative one used to make the test runner write to `/`.
- **Builds:** the app builds for the simulator with no warnings. ParserTests pass 70 of 70. `swift build` of all MockLab targets is clean.
- **Screenshots:** `screenshots/cover/` (home screen, gallery and app, same names as before) and `screenshots/renders-cover/` (the 207 renders, about 217 MB). The painted-night screenshots in `screenshots/` are untouched.

### Mountain is now the Matterhorn (2026-11-03)

After "this does not look like cloudripper", the user asked to "use the shape from matterhorn instead". Every Cover painting's mountain is now the Matterhorn in its classic view from the Riffelsee above Zermatt: the hooked summit pyramid, the steep left face and the long shoulder on the right.

- **Data source:** 30 m terrain data rounded the summit and put it 126 m low, so the skyline was traced from a photograph instead.
  - The photograph is `File:Matterhorn_Riffelsee_2005-06-11.jpg` on Wikimedia Commons (1352×2048). For every column, the trace takes the first row that isn't sky, smoothed over 5 px.
  - Only the line is used. The photograph is not in the repo and nothing was painted from its pixels.
  - **Attribution:** the photo is by Dirk Beyer, offered under your choice of GFDL 1.2+, CC BY-SA 3.0 Unported or CC BY-SA 2.5. I checked the Commons file page (https://commons.wikimedia.org/wiki/File:Matterhorn_Riffelsee_2005-06-11.jpg) on 2026-11-03. Credit it as "Silhouette traced from a photo by Dirk Beyer, CC BY-SA 3.0, via Wikimedia Commons" if the app is ever published. The wallpaper (`MockLab/Textures/wallpaper/`) uses the same trace.
  - The full trace, the photograph and the overlay check stay in the session scratchpad (`dem-matterhorn/`).
- **`MockLab/Textures/old-master-cover/matterhorn.json`** (7.6 KB) holds the traced line:
  - 474 points: every 2 columns across the pyramid and shoulder, every 6 on the lower ridges. It is within 2.4 px of the full trace on the pyramid; the larger errors are vertical, on near-vertical steps.
  - The summit is at (0, 0) and the unit is the pyramid's height (the 348.6 px drop from the summit to the foot of the left face). It also stores the foot, the notch and the shoulder's end, and the attribution.
  - `make.py --trace <matterhorn_riffelsee_skyline.json>` rebuilds it byte-identically. This replaced the DEM `--profiles` mode.
  - `cloudripper.json` and the Cloudripper-era `make.py` moved to `backups/cloudripper/`.
- **Shape:** each canvas uses one uniform scale, with no exaggeration. `FRAMES` only places the summit and sets the pyramid's height in points. The `-front` masks follow the trace to within 1 px.
- **Paint** (`matterhorn()` in `make.py`, the same sepia value studies glazed at run time):
  - lit as in the photograph: a dark horn of rock at the summit, the left face in shadow, and the east face lit, with its snow in long streaks down the fall line (noise smeared along it) and along ledges;
  - a band of dark rock under the summit ridge, its crest lit down to the notch, carries on from the notch down to the right as the Hörnli ridge, with the north face's lit snow under the shoulder;
  - mist at the foot and a lower ridge in front; the lower ridges either side are Old Master's `mountain()`, lit from the right;
  - the edge of the shadow and the ridge band are laid back over the brush strokes, so they stay crisp;
  - the skies are rearranged so the summit reads: darker upper sky and cloud behind the lit right side, and a lighter low sky behind the shadowed face.
- **Framing and glyphs:** the summit and its hook stand in open sky beside the glyph, and the glyph's foot goes behind the mountain's flank or shoulder. Each glyph is smaller than before and moved off the summit; `HEROES`, `OCCanvas.hero` and `CoverCanvas.hero` agree. Before, each numeral was centred (238 pt on large) with the peak at its foot, and the quote marks were 440/280/220 pt.

  | Canvas | Summit (x, y) | Pyramid | Glyph |
  |---|---|---|---|
  | Day large | 0.30, 0.125 | 145 pt | numeral on the right: centre 248, baseline 192, 212 pt (one digit) / 168 pt (two); the shoulder crosses its lower left |
  | Day medium | 0.12, 0.25 | 70 pt | numeral right of the summit: 118, 104, 112 / 84 pt |
  | Day small | 0.25, 0.22 | 62 pt | numeral on the right: 116, 102, 110 / 82 pt |
  | Quote large | 0.56, 0.10 | 140 pt | mark top left: left 14, top 24, 400 pt; the left face crosses the second mark's foot, and the shoulder runs out at the right edge |
  | Quote medium | 0.25, 0.25 | 70 pt | mark: 14, 20, 176 pt |
  | Quote small | 0.58, 0.07 | 66 pt | mark: 10, 12, 170 pt |

- **Swift (mock and `Shared/`):**
  - The sun and moon arcs moved so they keep to open sky over the summit or beside the glyph, rising and setting behind the flanks.
  - The painting label is now "Matterhorn · 14,692 ft". It moved to the bottom left, under the mountain, on large Day and large Quote: at the bottom right it would have sat on the lit snow of the shoulder.
  - The widget gallery description and the OMCover and Current taglines name the Matterhorn.
- **Verification:**
  - **Textures:** `make.py` is deterministic and offline; two full runs were byte-identical. All 26 PNGs are 1 px per point, and `gilt.png` and `veil.png` are unchanged. `scripts/export_cover_textures.py` refreshed the 26 `Cover*` imagesets.
  - **Mock:** checked at 3x and on a 1x phone-size sheet. With `OC_STATES_DIR`, checked no tasks, task errors, no weather, rain, snow, dusk, night, the 28th and the 11th (two digits), one task, and long and authorless quotes. The Matterhorn reads in every one, and so do the numerals and marks.
  - **Builds:** the simulator build succeeded with no warnings. ParserTests pass 70 of 70. `swift build --scratch-path .build-all` builds every MockLab target cleanly.
  - **Pixel check:** MockLab `Current`, which draws the shipped `Shared/Cover*` views, against `out/old-master-cover/` at 3x:
    - Day large, medium and small, and Quote medium and small: mean 0.010–0.030 levels per channel.
    - Quote large: mean 0.20, from ±1-level rounding in the canvas weave across its right half and from the gilt opacity match inside the marks.
    - The maximum is 5–9 inside every widget.
  - **Simulator (iPhone 17):**
    - `SHOT_DIR=screenshots/cover scripts/capture_screenshots.sh`: all 5 UI tests pass, and all six widgets render on the home screen in the fresh, cached and 401 states. The next-quote button changes the quote. The run fell at night, so the home-screen shots show the nocturne.
    - `-seedDemoData -renderWidgets` wrote 207 renders and `fit.txt` into `screenshots/renders-cover/` (216 MB, replacing the Cloudripper set). The 9:41 (`morning`) renders match the macOS ones: Day differs by a mean of 1.8–3.2 levels and large Quote by 4.4 (apart from text antialiasing). Medium and small Quote show a different demo quote.
  - **Images:** `screenshots/films/old-master-cover-matterhorn.jpg` (before, after and the traced skyline) and an updated `screenshots/films/old-master-cover-board.jpg`.
- **Still to judge:** the user should confirm that the small widgets read as the Matterhorn at arm's length. At 62–70 pt tall the hook is a 2–3 pt step, so recognition rests on the overall silhouette and the light.

### Matterhorn wallpapers (2026-11-03/04, after "add a wallpaper" and "Do a whole ton of differnt versions of this")

These are iPhone wallpapers in the Old Master sepia-oil style, painted from the same traced Matterhorn silhouette as the widgets.
- **Script:** `MockLab/Textures/wallpaper/make.py`, deterministic and offline. Each painting is made at 2640×5740 and filtered down. The silhouette data is in `MockLab/Textures/wallpaper/matterhorn.json`, the same trace, credited to Dirk Beyer under CC BY-SA 3.0.
- **Defaults:** `screenshots/wallpaper/baroque-matterhorn-{day,night}-{1206x2622,1320x2868}.png`, with the Matterhorn reflected in the Riffelsee.
  - The summit rises into the foot of the lock-screen clock, for iOS's depth effect.
  - The dark shore sits under the dock.
  - `preview-lock.png` is current. `preview-home.png` is stale; rerun with `make.py --previews-only` once the widgets settle.
- **24 variants:** `screenshots/wallpaper/variants/NN-<slug>.png`, all 1206×2622, with `contact-sheet.jpg` and `variants.json` (title, description, and lock/home/both use).
  - They cover alpenglow, banner cloud, lenticular cap, sea of cloud, storm, Milky Way, blue hour, snow and clearing rain.
  - Compositions are lake, forest, close-up, tiny peak and low peak.
  - Palettes are sepia, umber, ivory and charcoal.
  - Regenerate with `make.py --variants [slug|NN …]`, about 45 s each.
- **Weak spots:**
  - 20's snow pattern.
  - Faint seams in the sea-of-cloud variants (04, 08, 20, 22).
  - Smudgy Milky Way lanes (10, 24).
  - Plain forest meadows (07, 11, 12, 16, 19).

### Weather-first widget mocks (MockLab, 2026-11-04, after "Wont be needing the calendar section and the todolist can be moved somewhere else … search pinterest …")

The new brief: the main widget shows the temperature, the conditions, sunrise and sunset and the month. There's no calendar grid, and tasks are optional or move to their own widget.

- **Research:**
  - **Method:** a Pinterest crawl in Chrome (16 searches, 577 unique pins classified by eye). The findings, contact sheet and references were kept in the session scratchpad (`pinterest-research/`).
  - **Top styles:**
    - oil painting and gilt frames;
    - flat UI cards (avoided);
    - moody nature photos with glass widgets and a giant thin numeral (#1 for home screens);
    - vintage prints;
    - dark academia;
    - storybook illustration (the single most repeated pin).
  - **Sun times:** a sun on an arc is the standard sun-time form, but sun times are rare in aesthetic setups.
- **Harness:** `Kit/WeatherMockKit.swift` (also linked into PaintKit) adds the `WeatherMock` protocol (`weather`, `todo`, `wallpaper`), `Mock.night` (9:15 PM) and `WeatherRunner`. The runner writes `weather-<size>[-night].png`, `todo-{small,medium}.png`, `board.png` and `meta.json`.
- **Seven directions,** each with its own `Textures/<slug>/make.py` and a states hook (`<PREFIX>_STATES_DIR`). All keep the traced Matterhorn.

  | Mock | Target | Prefix | Look |
  |---|---|---|---|
  | Sun Arc | `WSunArc` | SA | A gilt sun arc over a sepia oil, with times at its feet; serif planner to-do |
  | Celestial | `WCelestial` | CE | An engraved navy-and-gold astrolabe: sunrise east, sunset west, month on the rim; star-chart to-do |
  | Travel Poster | `WPoster` | TP | A vintage Swiss poster: the month as title, a live sun disc, sun times on the caption band; railway-ticket to-do |
  | Almanac | `WAlmanac` | AL | An almanac page: a Didone month word, typeset weather, a painted plate; espresso page at night |
  | Gilt Frame | `WGiltFrame` | GF | A framed oil on oxblood damask with a brass plate; ivory errands card |
  | Giant Numeral | `WNumeral` | GN | A huge thin temperature in a misty olive landscape, with a frosted sun-time strip |
  | Storybook Night | `WStorybook` | SB | A gouache picture-book plate in a gold-filigree frame: "Chapter XI · November", sun times on a ribbon, parchment to-do |
- **Builds:** all 31 MockLab targets build from clean with no warnings.
- **Gallery:** https://claude.ai/artifact/LzQtQqGMZZ4sU4819iF866 (private). It also holds the 24 wallpapers.
- **Sheets:** `screenshots/weather/<slug>-board.jpg` and `compare-large.jpg` (day and night).
- **Shared caveat:** several agents found that `Mock.time` follows the Mac's 24-hour setting, so each mock formats times with `en_US_POSIX`.

### Sun Arc in other landscapes (MockLab, 2026-11-04, after "doesnt just have to be matterhorn not a fan of the gold framed. I like the sun arc")
The user picked **Sun Arc**. Its large Weather canvas is now also painted in eight real places. Each is shown in its classic view, with the outline traced from a freely licensed Wikimedia Commons photograph at true proportions. The painters are in `MockLab/Textures/weather-sun-arc/scenes/<scene>/` (`make.py`, the traced skyline JSON, the `large-*` PNGs and `SOURCE.md` with the credit):
- `half-dome`: from Glacier Point, el ui, CC BY 3.0.
- `whitney`: from the Alabama Hills, BLM, CC BY 2.0.
- `big-sur`: Bixby Creek Bridge, Aaron Albrecht, CC BY 3.0.
- `joshua-tree`: Joshua Tree NP, public domain.
- `fuji`: Lake Kawaguchi, Aistleitner, CC0.
- `glencoe`: Buachaille Etive Mòr, jtweedie1976, CC BY 2.0.
- `dolomites`: Tre Cime from the Locatelli hut, Irene Scarpante, CC BY-SA 4.0.
- `tuscany`: San Quirico d'Orcia cypresses, Federica.tamburini.75, CC BY-SA 4.0.

The shared painters are `scenes/half-dome/ca_paint.py` (California) and `scenes/fuji/world.py` (the rest). Keep them if you drop a scene.

`SA_SCENE=<scene> swift run --scratch-path .build-sa WSunArc` renders one scene (`Sources/WSunArc/SALandscape.swift`):
- It reads that folder plus an optional `scene.json` arc (only `whitney` has one).
- It writes `weather-<size>[-night].png` to `out/weather-sun-arc-scenes/<scene>/`.
- Without `SA_SCENE`, the Matterhorn renders byte-identically.

Only the large canvas exists so far. The chosen scenes need medium and small canvases before porting.

The gallery is "Sun Arc Landscapes", https://claude.ai/artifact/YVPcrBpDBWhuDdZned8oGz. The sheet is `screenshots/weather/sun-arc-landscapes.jpg`.

Weak points the painters noted:
- Fuji and Whitney sit low under a big sky, because of their true proportions.
- Joshua Tree's rosettes soften at 1 px per point.
- Bixby's spandrel columns are soft.
- The Dolomites ledges read slightly ruled at night.

The CC BY-SA scenes (dolomites, tuscany) need the credit shown in the app if they ship.

### Sun Arc home screen (MockLab, 2026-11-04, after "build out the rest of the homesreen … there should be a quote spot on this as well. This should be the only widget on the home page" and "On the next page should be 3 small widgets with other important info. there will be as many as 20 apps total")
A mock of the whole iPhone 17 home screen built round Sun Arc, in `MockLab/Sources/WSunArc/SAHome.swift`:
- **Page one:** `SAWeatherQuote`, the only widget. It is Sun Arc large with the temperature smaller (76 pt, baseline 293) beside the condition, high and low, and the next sun time. Below a hairline sits the quote: a gilt opening mark, italic text, the author in spaced caps after the last word, and `CoverNextButton` at the end of the rule. Eight apps sit under it.
- **Page two:** three small widgets, each with eight apps around it:
  - `SATodoSmall(framed: false)`: the to-do small without the gilt frame. `framed` defaults to true, so the board is unchanged.
  - `SAForecastSmall`: the next rain as the headline, then four days named by date ("tomorrow", "the 6th"; no weekday names).
  - `SAMoonSmall`: the moon in its phase, moonrise, % lit, and today's daylight with its change.
- **Apps:** 20 in all, eight per page plus four in the dock. They are stand-in apps drawn as iOS Tinted-mode icons in warm cream, using SF Symbols; Baroque's icon is tinted.
- **Chrome:** a Liquid Glass dock, page dots and a status bar.
- **Paintings:** `Textures/weather-sun-arc/home/make.py` (it imports Sun Arc's `arc_painting` by path) paints:
  - `forecast-small-*` and `moon-small-*` (164×164 alpha PNGs glazed with CoverLight);
  - `wallpaper.jpg` (603×1311): a calm umber sky with a far ridge of firs behind the dock.
- **Render:** `SA_HOME=1 [SA_SCENE=<scene>] swift run --scratch-path .build-sa-home WSunArc` writes `home-{1,2}[-night].png` and each widget on its own to `out/weather-sun-arc-home/<scene>/`. All nine scenes are rendered.
- **Demo data:** the forecast, rain start time, moonrise (estimated from the phase) and the daylight change are demo values. Open-Meteo daily/hourly and a local moon calculation would supply them.
- **Problem:** with the temperature moved up, Big Sur's bridge arch now sits under "64°". Repaint that scene with the bridge higher if it's picked.
- **Gallery:** "Baroque Home Screen", https://claude.ai/artifact/XgSpGgFgHBkyVwoB6Ccc1x. The sheet and full-size PNGs are in `screenshots/home/`.
- **Porting note:** iOS Tinted mode also tints widget images unless they opt out (`widgetAccentedRenderingMode(.fullColor)`). Check this on the simulator when porting.
- **Render check:** the default `WSunArc` render is unchanged byte for byte, except `weather-medium.png`. That file changed once between runs and then matched across four reruns. Its code is untouched, so this is likely renderer nondeterminism.

Revision (same day). The user asked: "i want the custom 3d icon idea that we worked on but set for this. have a more simiilar background to the refernce for this". Then: "on the second page it should be a checker board between widet and apps. there should be a picture widget as well".
- **Icons:** `SAIcon` is a custom 3D icon. It is a raised taupe tile built like Theme's `StoneSlabModifier`: a cut side, a contact shadow, a lit chamfer, `PaintPanel` brushwork and light from the upper right. Its SF Symbol is carved in (`SACarvedGlyph`). The colours follow the reference's taupe icon pack. No saved icon design was found in the project, so this was built from the earlier widgets' raised-slab vocabulary. The icon sheet is `icons.png`. On iOS these would be set as Shortcuts home screen icons.
- **Wallpaper:** `home/make.py baroque()` is Old Master's Baroque cloudscape recomposed for 402×874, written as `wallpaper.jpg`. The first, calm version is kept as `wallpaper-calm.jpg`.
- **Page two:** a checkerboard of widgets and four-app blocks:
  - To do, then 4 apps;
  - 4 apps, then `SAPictureSmall`: a landscape cropped square with a small label, Val d'Orcia or Tre Cime when page one is Tuscany;
  - the stack (`SAForecastSmall` by day, `SAMoonSmall` at night, with stack dots), then 4 apps.
- **App count:** 12 apps on page two, so the pages hold 20 and the dock 4.
- **Gallery:** updated in place.

### Baroque in travertine (MockLab, 2026-11-04, after "make a design using all that we have learned to match https://www.pinterest.com/pin/215046950953591573/ perfectly")
The pin is a rendered showcase: a phone home screen beside a set of travertine and olive-stone widgets with raised reliefs (a gold sun, an olive branch, a flower) and a sunlit Mediterranean photo, on a plaster wall with leaf shadows. It is rebuilt in `MockLab/Sources/WSunArc/TVHome.swift` (prefix TV) with Baroque's content.
- **Render:** `SA_TRAV=1 swift run --scratch-path .build-sa-home WSunArc` writes `showcase.png` (the pin's layout, scale 2), `home-1.png`, `home-2.png`, `home-1-night.png`, each widget and `icons.png` to `out/travertine/`.
- **Materials:** `Textures/travertine/make.py` paints six stones and two plasters (deterministic, offline):
  - stones: travertine, olive, verde, terracotta, umber, tan (900² each);
  - `wallpaper.jpg`: taupe plaster with olive-leaf shadows;
  - `wall.jpg`: the showcase backdrop.
- **Construction:** `TVSlab` is a stone slab with a bevelled edge, lit from the upper left. With `lift` it also shows its underside and casts a shadow. `TVCarve` draws grooves. The reliefs (`TVSun`, `TVOliveBranch`, `TVFlower`, `TVMoonRelief`, `TVSymbolRelief`) are SwiftUI, so they port as they are.
- **Paintings:** the Sun Arc landscapes, glazed by `TVLight.sunlit`, with a warm soft-light wash and extra contrast. `SAPaint` gained `aged: Bool = true`; the travertine look passes false to drop the varnish and craquelure. The default keeps every other render unchanged.
- **Page one:** `TVHero`, a large widget: Val d'Orcia, date and temperature top right, the quote in italic, the weather in caps. Eight apps below.
- **Page two:** a checkerboard: `TVSunArc` (a carved arc with a gold inlay and the gold sun), then 4 apps; 4 apps, then `TVPictureTile` (the Matterhorn with "Good ideas take time" in Savoye LET); `TVTodaySmall`, then 4 apps.
- **The kit:** `TVQuoteTile` (verde), `TVForecastTile`, `TVTonightTile` and `TVTodayMedium` (with the flower panel).
- **Phone screens:** widgets and icons get no outside shadows, since iOS clips them. Only the kit is lifted.
- **Deviations from the pin, and why:**
  - no music or battery row (it doesn't fit iOS's grid, and Baroque can't play music);
  - calendar → Sun Arc and forecast (the user dropped the calendar);
  - Focus switches → Tonight (apps can't switch Focus);
  - clock → temperature;
  - no weekday;
  - paintings instead of photos;
  - generic symbols instead of brand logos;
  - white app names.
- **Gallery:** "Baroque in Travertine", https://claude.ai/artifact/WpgzPPn8A9HAAT2oNMW5iY. Copies are in `screenshots/travertine/`.
- **Icons in Blender** (after "Build the apps one to one take ss and replace if needed. use modeling software if possible"). All 24 app icons are 3D models rendered with Cycles in Blender 5.1 (`/Applications/Blender.app`). The pipeline is in `MockLab/Textures/travertine/icons/` and is deterministic and offline:
  - `glyphs.swift` renders SF Symbol and type masks;
  - `trace.py` (OpenCV) traces them to smoothed outlines and adds procedural ones (map pin, gear, Spotify arcs, Instagram);
  - `build.py` builds each icon: a bevelled rounded-square slab faced with the travertine stone textures, with its object either extruded from an outline or modelled (flower, camera, notepad, compass, calendar, clock, crystal, Notion cube), lit by a low sun from the upper left. It writes `<slug>.png` (512², transparent corners).
  - Run: `swift glyphs.swift && python3 trace.py && /Applications/Blender.app/Contents/MacOS/Blender -b -P build.py -- [slugs]` from that folder. All 24 take about a minute.
  - `TVIcon` draws the render when one exists and falls back to SwiftUI. On the phone screens there is no outer shadow; with `lift` (the showcase) it adds one.
  - Checked against crops of the pin with `scratchpad/trav/compare_icons.py`; the result is `screenshots/travertine/icons-vs-pin.png`.
  - New stone `moss` (the pin's darker olive-brown tiles); `umber` warmed.
  - Opaque 1024² copies for the Shortcuts app are in `screenshots/travertine/icons-for-shortcuts/`.
  - The Spotify, Notion and Instagram icons follow their marks, for the user's own home screen only.

### Your apps and layout, in travertine (MockLab, 2026-11-04, after "Make the hot bar claude, messages, safari, obsidian. Big widget on first screen then, Gmail, photos, … venmo. BUILD")
Read as a 4×6 grid, the list fills three pages exactly:
- **Dock:** Claude, Messages, Safari, Obsidian.
- **Page one:** the large widget, then Gmail, Photos, Camera, YouTube / Settings, Spotify, Maps, Calendar.
- **Page two:** a medium widget, then Weather, AllTrails, Uber Eats, Netflix / Equinox, Find My, Slack, Clock, then a medium widget.
- **Page three:** a medium widget over Wallet, App Store, Files, Venmo.

"Clock" was read as the Clock app, not a clock widget. The three medium widgets are new: `TVSunArcMedium` (Sun Arc and the days ahead on one slab), `TVTodayMedium` (as before) and `TVPictureMedium` (the Dolomites with "Good ideas take time" in script). `TVApps` holds the lists; `TVSunArc` and `TVForecastTile` gained `slab: Bool = true` so they can share the wider slab.
- **Ten new Blender icons:** Claude (the spark), Gmail (the M as olive posts under a terracotta flap), Weather (a gold sun behind a cream cloud), AllTrails (two faceted peaks, `facet_peak`), Uber Eats (the two words), Netflix (the N as a folded ribbon), Equinox ("EQX"; its current app icon couldn't be confirmed), Find My (rings round a gold dot), Slack (its four pieces in terracotta, cream, sage and gold) and Venmo (the V, with round ends: cut flat, they broke Blender's bevel). Safari, YouTube, Spotify, Maps and Files changed stone so no two neighbours share one. `build.py` now splits `APPS` (yours) from `OTHERS` (the pin's).
- **Shortcuts:** `icons/export.py [travertine|rococo]` writes your 24 as opaque 1024² PNGs named by app to `screenshots/<set>/icons-for-shortcuts/` and removes ones no longer on the screen.

### Rococo (MockLab, 2026-11-04, after "Trying a style with this as a background please try keeping this painted rococo look", "try to turn my outdoor photography into this style as well" and two more paintings, "please use these as well")
The same set and layout drawn over Hubert Robert's *The Bathing Pool* (1777–80, the Met, public domain): `TVStyle.rococo` switches `TVHome.swift`'s textures, icons, wallpaper and type, and `RCHome.swift` adds the painting details. Render: `SA_ROCOCO=1 swift run --scratch-path .build-sa-home WSunArc` → `out/rococo/` (plus `swing/` and `flowers/`).
- **Stones:** `Textures/rococo/make.py` lays the seven stones in with broad, level oil strokes in the painting's colours (limestone, foliage greens, sky teal, terracotta, umber, ochre); its wallpaper is the painting cropped round the rotunda. The type is Didot.
- **Icons:** the same Blender models with `ICON_SET=rococo` (stones from `Textures/rococo/`, objects' paint brushed, written to `Textures/rococo/icons/`).
- **Your photographs:** `Textures/rococo/photos.py` repaints ten of your landscapes from `~/Pictures` (three folders of the author's photographs) on this machine. It moves their colours toward *The Bathing Pool* and *The Swing*, then lays them in with strokes that follow the forms (broad, then fine where there's detail), bristle marks, impasto, canvas and varnish. Kings Canyon is the large widget's painting; the dead tree is page three's.
- **The two paintings you sent:** Fragonard's *The Swing* (1767, the Wallace Collection, public domain) and the flower still life (artist not identified here) are in `Textures/rococo/source/`. The still life's roses fill the Today widget's panel. Both are also rendered as alternative wallpapers: `wallpaper-swing.jpg` (cropped round the girl) and `wallpaper-flowers.jpg` (the whole bouquet, its dark ground carried up the screen).
- **Copies:** `screenshots/rococo/` (pages for each wallpaper, the showcase, night, icons, `painted-photos/`, `photos-before-after.jpg`, `icons-for-shortcuts/`).

### Rococo ships in the real widgets (2026-11-04, after "the bathing pool. show the new look", "yes build it into the real widgets", "and icons" and "can we get spotify or battery percentage related widgets")
The rococo set from MockLab is now the app's widgets. The Cover files are still compiled (MockLab's `Current` renders them) but no widget draws them.
- **Code:** `Shared/RococoStyle.swift` (ink, Didot/Avenir Next/Savoye type, `RococoFrame` scaling the iPhone 17 layouts to fill each widget, the painted limestone slab, carved lines, the gold sun and the moon), `RococoDay.swift`, `RococoToday.swift`, `RococoQuote.swift`, `RococoBattery.swift`.
- **Widgets** (`BaroqueWidget/BaroqueWidgets.swift`):
  - **Baroque Day:** small is Sun Arc (the day gone in gold, the sun or tonight's moon on the arc, sunrise, sunset and the hours of light); medium adds the days ahead (named "tomorrow", "the 6th": no weekdays; terracotta when rain is 50% likely or more); large is your Kings Canyon, repainted, with the date, the temperature, a quote one past the Quote widget's, and the weather in capitals.
  - **Baroque Today** (new): small and medium; your tasks with carved rings, terracotta when late, "+ N more", and the fetch error on the last line when the list is cached; the medium has the flower still life's roses.
  - **Baroque Quote:** small (the river), medium (the dead tree), large (the sunset). Short lines are set in script, longer ones in Didot italic, shrinking a little and then truncating. The quote itself is the next-quote button.
  - **Baroque Battery** (new): the iPhone's charge as gold along a carved arc, the figure in Didot, "charging", "full" or "low" (terracotta at 20% or less), and the time of the reading. iOS refreshes it about every 15 minutes, so it can lag. AirPods and Watch levels aren't available to apps.
- **Weather:** the Open-Meteo request now asks for 5 days and the chance of rain; `WeatherSnapshot.days` holds the days ahead (optional, so caches from before still load).
- **Images:** `scripts/export_rococo_textures.py` cuts the `Rococo*` images into `PaintTextures.xcassets` at 2 px per point (JPEG; the largest widget holds one 696×730 image). It also writes the app icon (Sun Arc in gold on painted limestone, modelled in Blender: `appicon` in `build.py`) and the 24 home screen icons to `Baroque/Assets.xcassets/HomeIcons`.
- **App:** the preview shows Day large and medium, Today medium and Quote medium. A new section, **Home screen icons**, shows your 24 icons. Tap one, or Save all, and choose Save Images, then set them in Shortcuts. iOS lets only Shortcuts give another app a custom icon, so Baroque hands them over as images. `NSPhotoLibraryAddUsageDescription` was added for the save.
- **Render harness:** `-renderWidgets` now writes the rococo widgets: Day and Today in 15 states, Quote in 8 and Battery in 4, at three phone sizes. Copies are in `screenshots/renders-rococo/` with `fit.txt`. The old app icon art was removed from it.
- **UI tests:** `test10_placeWidgets` builds four pages: Day large; Day medium and Quote medium; Today small, Battery small and Today medium; Day small, Quote small and Quote large. `test35` taps the quote's words to change it.
- **Spotify:** not built. Spotify's February 2026 rules say a Development Mode app works only while its owner has Premium (one client ID, at most five users) ([guide](https://developer.spotify.com/documentation/web-api/tutorials/february-2026-migration-guide)).

### Renamed to Baroque (2026-11-05, after "rename everything so its baroque as the name")
Everything that names the app now says Baroque:
- **The app:** its home screen name, its widgets (Baroque Day, Today, Quote and Battery) and the app's title.
- **The project:** `Baroque.xcodeproj`, with the `Baroque`, `BaroqueWidgetExtension` and `BaroqueUITests` targets, and the folders `Baroque/`, `BaroqueWidget/` and `BaroqueUITests/`.
- **The code and data:** the Swift types (`BaroqueSettings`, `BaroqueSize`, …), the widget kinds, the storage keys (`baroque.*`), the parser test module (`BaroqueCore`), the scripts, MockLab's labels, and these notes, CLAUDE.md and the README.

Kept on purpose:
- **The bundle IDs** (`com.ryanfernandez.terra…`), the App Group and the Keychain service. The original brief says not to change bundle identifiers unless a build forces it, and they never show on screen.
- **This folder:** still `~/claudeProjects/Terra`. Renaming it would break the paths this session works from; rename it whenever you like.
- **The originals:** `backups/` and `CLAUDE_CODE_PROMPT.md` keep the old name as records.

Widgets placed before the rename (on the simulator) stop updating; add them again from the gallery under "Baroque". Nothing was installed on a phone yet.

### Setting up the home screen from the app (2026-11-05, after "configure the app so there is an install button that changes the home page")
iOS lets no app move icons, set the wallpaper or place widgets, so Baroque does what an app can and shows the rest, in a new **Set up your home screen** section (`Baroque/HomeSetup.swift`):
- **Install the icons.** Your 24 icons are packed into one configuration profile, a web clip per app with its icon and a URL that opens it (`Baroque/Setup/BaroqueIcons.mobileconfig`, made by `scripts/make_icon_profile.py`).
  - The button serves the profile from the app on 127.0.0.1 for a minute and opens it in Safari, because iOS installs profiles only from Safari, Mail, Files or AirDrop. You tap Allow, then Install in Settings.
  - No Shortcuts banner when they open.
  - The URLs marked "unverified" in the script might not open their app (Camera is the likeliest); the Shortcuts route in **Home screen icons** is the fallback.
- **Save the wallpaper** puts *The Bathing Pool* in Photos (asset `Wallpaper`, from `scripts/export_rococo_textures.py`).
- **The plan** draws the dock and the three pages (`HomePlan`) with where each widget and icon goes.
- **Rehearsed on the simulator** by `scripts/build_home_screen.sh` (UI steps in `BaroqueUITests/HomeScreenBuildTests.swift`). It erases the simulator, installs Baroque with sample data, then:
  - taps the app's **Install the icons** button (this worked: Safari, Allow, Settings, Install);
  - sets the wallpaper through Photos (**Share > Use as Wallpaper**, in PosterBoard);
  - writes the dock and pages straight into SpringBoard's `IconState.plist` with the simulator shut down (`scripts/home_screen_layout.py`);
  - screenshots the pages (`screenshots/home-screen/`).

  Every widget and icon shows in its planned place. The simulator draws photo wallpapers black.
- **iOS 26 clear and tinted modes:** the paintings and the stone are marked full colour (`rococoFullColor()`), so those modes don't turn them grey.

### Your quotes file (2026-11-05, after "quotes file has also been created please add it from the obsidian doc")
- **Where it is:** `main/Quotes/Quotes.md` in the vault. It is now the app's default quotes path.
- **Your style is supported:** a quote on a line of its own, `“…” - Author`, used to be skipped as prose. Lines that open with a quotation mark now parse, and a test covers your line (71 parser tests).
- **Sync:** the file wasn't on GitHub yet. The vault's Git plugin pushes once a day (every 1,440 minutes), so the widgets see new quotes after that or after **Obsidian Git: Commit and sync**.

### Widget ideas (2026-11-05)
Research for the next version is in `WIDGET_IDEAS.md`. The five to build first are Next Adventure, Tonight's Glow, tap-to-check Today, a painting of the day, and the quarter and deadlines.

### New debug tools (Debug builds only)
- `-resetData` resets everything to a fresh install.
- `-seedDemoData` loads demo tasks and quotes into the cache.
- `-renderWidgets` writes PNGs of every widget size and data state, plus the app icon art, to the app's Documents folder.
- `-scrollTo <section>` scrolls the settings form.

The code is in `Baroque/DebugLaunch.swift` and `Baroque/WidgetRenders.swift`.

## Commands

```bash
cd ~/claudeProjects/Terra

# Regenerate the Xcode project (only after adding or removing files)
xcodegen generate

# Build for the simulator
xcodebuild -project Baroque.xcodeproj -scheme Baroque -destination 'platform=iOS Simulator,name=iPhone 17' -derivedDataPath build build

# Run in the simulator
xcrun simctl boot "iPhone 17"; open -a Simulator
xcrun simctl install booted build/Build/Products/Debug-iphonesimulator/Baroque.app
xcrun simctl launch booted com.ryanfernandez.terra                 # optionally add -seedDemoData or -resetData

# Parser unit tests
cd ParserTests && swift test && cd ..

# Regenerate the painted textures (needs numpy, scipy, Pillow), then rebuild
python3 scripts/make_textures.py

# Copy the Cover paintings into Shared/PaintTextures.xcassets as Cover* imagesets (--paint repaints them first with
# MockLab/Textures/old-master-cover/make.py; needs numpy, scipy, Pillow), then rebuild
python3 scripts/export_cover_textures.py [--paint]

# Rebuild matterhorn.json (the Cover mountain's skyline) from the full photo trace, if you have it; the textures read only the JSON
python3 -B MockLab/Textures/old-master-cover/make.py --trace <matterhorn_riffelsee_skyline.json>

# Render one alternative look (about 10 s each), then rebuild the comparison sheets
cd MockLab && swift run --scratch-path .build-topo Topo && cd ..   # FieldJournal, Topo, Woodblock, StainedGlass, PaperDiorama, PixelQuest
python3 MockLab/compose.py                                          # MockLab/out/compare-*.png, plus the shipped look as painted-night

# Render one painted layout experiment (Current is the shipped Cover widgets; compare out/layout-current with out/old-master-cover), then rebuild the sheets (MockLab/out/layouts/)
cd MockLab && swift run --scratch-path .build-layouts LPanorama && cd ..   # Current, LPanorama, LFocus, LBento, LMedallion, LTrail, LPlate
python3 MockLab/compose.py

# Render one film look, then rebuild the sheets (MockLab/out/films/, with Current first; render Current too)
cd MockLab && swift run --scratch-path .build-films NeonRain && cd ..   # OldMaster, OMInscribed, OMFolio, OMCover, GrandHotel, GrandHotelCalm (Quiet and Spare), NeonRain, CrimsonHours, AlpineHotel, Expedition
python3 MockLab/compose.py

# Full simulator run: erase, build, place widgets, screenshot every state (~10 min)
scripts/capture_screenshots.sh                                      # iPhone 17 simulator, derived data in build/
scripts/capture_screenshots.sh <SIM_UDID> <derived-data-path>       # another simulator
ERASE=0 SKIP_BUILD=1 ONLY=test35_quoteNextArrow scripts/capture_screenshots.sh   # one test, keep the home screen
```

Logs go to `build/capture-logs/`.

## Screenshots (`screenshots/`)

Apart from `cover/` and `renders-cover/`, these come from the painted-night build on the iPhone 17 simulator, in a full run on an erased simulator (5 of 5 UI tests passed).

| File | What it shows |
|---|---|
| `01-app-preview-fresh.png` | App after `-resetData`: live weather, "Couldn't load tasks / No GitHub token", fallback quote |
| `02-app-settings.png`, `03-app-settings-location.png` | Settings form: GitHub and Tasks sections, then Quotes, Weather location and About |
| `05-app-preview-cached.png` | App after `-seedDemoData`: 5 of 7 tasks, "+2 more", cached quote, error line |
| `06-app-token-401.png` | App after saving a fake token: "GitHub rejected the token (401)" |
| `10-home-day-large-fresh.png` | Home screen, Day large, no token |
| `11-home-day-medium-quote-medium-fresh.png` | Day medium and Quote medium, no token |
| `12-home-day-small-quote-small-quote-large-fresh.png` | Day small, Quote small and Quote large, no token |
| `20-home-day-large-cached.png` | Day large with cached tasks: 5 rows, "+2 more", "Cached · No GitHub token." |
| `21-home-day-medium-quote-medium-cached.png` | Day medium (3 tasks) and Quote medium, cached |
| `22-home-day-small-quote-small-quote-large-cached.png` | Small and large widgets, cached |
| `25-quote-next-before.png`, `26-quote-next-after.png` | Before and after tapping the copper next arrow; the quote changes |
| `30-widget-gallery-day-large.png`, `31-widget-gallery-quote-medium.png` | iOS widget gallery previews |
| `40-home-day-large-token-401.png`, `41-home-medium-token-401.png` | Home-screen widgets after the fake token: the widget extension read the token |
| `before-after-day-large.png` | The large Day widget on the home screen in four stages: the first pass, the stone redesign, the mountain landscape and the painted look |
| `mocks/` | The six alternative looks and the shipped one, each as a board with all six widgets on a matching wallpaper (`<look>-board.jpg`), plus side-by-side sheets: every board, Day large, Quote medium and Day small (`compare-*.jpg`). They are rendered on the Mac by MockLab, not on the simulator. |
| `layouts/` | The six layout experiments in the painted look plus the current layout (`<layout>-board.jpg`), and side-by-side sheets for every board and each Day size and Quote large and medium (`compare-*.jpg`). Rendered on the Mac by MockLab with the app's own painting code. |
| `films/` | Old Master, the sepia oil-painting look from the user's reference (`old-master-board.jpg`; `old-master-times.jpg` shows morning, dusk, night and rain). Its three inventive versions are `old-master-inscribed-board.jpg`, `old-master-folio-board.jpg` and `old-master-cover-board.jpg` (now with the Matterhorn; `old-master-cover-cloudripper.jpg` and `old-master-cover-matterhorn.jpg` show the mountain's two changes), and `old-master-family.jpg` shows all four large Day and Quote widgets side by side. Then the film looks, each as a board (`<look>-board.jpg`): Grand Hotel (the painted Grand Budapest look), its calmer versions Grand Hotel Quiet and Grand Hotel Spare, Neon Rain, Crimson Hours, Alpine Hotel and Expedition. `grand-hotel-times.jpg` shows Grand Hotel's large Day widget at morning, dusk, night and in rain. `grand-hotel-calm-compare.jpg` puts Grand Hotel, Quiet and Spare side by side. The side-by-side sheets put the current design first and cover every board and each of the six widgets (`compare-*.jpg`). All rendered on the Mac by MockLab. |
| `cover/` | The shipped Old Master Cover widgets, with the Matterhorn, on the iPhone 17 home screen, with the same file names as the painted-night shots above (fresh, cached, next quote, gallery, 401). Captured at night, so they show the nocturne |
| `renders-cover/` | 207 exact-size renders of the Cover widgets with the Matterhorn (3 sizes × every family × 15 Day and 8 Quote states) plus `fit.txt` |
| `renders/` | 117 exact-size renders of the current design: 3 screen sizes × every family × several data and weather states, plus `fit.txt` (all fit). `renders/before/` holds the original pre-review design for comparison |

## Known gaps

- **Not tested against the real vault.** Without a token, tasks and quotes were only tested on input shaped like your vault, never on your actual files. After step 2, check that real tasks appear and that the order looks right. If something looks off, add a failing example to `ParserTests/`.
- **App Groups on a free personal team are unverified.** The simulator doesn't need signing. On a device, some forum reports say personal teams can't create App Group containers, and I found no official answer either way ([forum thread](https://developer.apple.com/forums/thread/127200)). If Xcode won't add the group, the app still works, but the widget can't see your settings or token. It would show default-location weather and "No GitHub token". The fix then is a paid membership, or tell me and I'll look for a workaround.
- **Free provisioning expires after 7 days.** Press Run again to reinstall.
- **Tinted and clear home-screen modes** in iOS 26 aren't tuned. The widgets were only checked in the default full-color mode; in tinted mode iOS will flatten the painted textures to one tint.
- **The palette is dark only.** The app forces dark mode and keeps its painted-night settings UI; the widgets always use the sepia Cover palette. There is no light variant.
- **Refresh timing is up to iOS.** The widgets ask to refresh about every 30 minutes, but iOS decides when they actually do. Save & Refresh in the app forces a reload.
- **Small truncations:**
  - Very long errors (for example the offline message) are shortened in the small widgets.
  - Long task titles, city names and authors end with "…" by design.
  - The quote preview in the widget gallery doesn't show the error line.
- **Git:** since 1.0.0 this folder is a git repository, pushed to the private GitHub repo `RyeBreadFernandez/baroque` (`main`, tag `v1.0.0`). Build caches, renders and older screenshots are ignored (`.gitignore`); `screenshots/rococo-home/` is kept. No token was created or stored. The UI test types the obviously fake `not-a-real-token` and then clears it.
- **Leftovers:** the iPhone 17 simulator is shut down, in the state the Matterhorn run left it (demo data seeded, with Baroque widgets on the home screen pages). `build/` (about 250 MB) and `ParserTests/.build/` (about 200 MB) can be deleted at any time.
