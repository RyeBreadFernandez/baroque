# Architecture

Baroque is three things that ship together, plus two that don't:

| Part | What it is | Where |
| --- | --- | --- |
| The app | Settings, the token, live widget previews, the Daily Brief page, home screen setup | `Baroque/` |
| The widget extension | Seven widgets and their timelines | `BaroqueWidget/` |
| Shared code | Only what both need: models, parsers, the GitHub and weather clients, the loader and cache, the rococo views | `Shared/`, compiled into both |
| Parser tests | A Swift package that tests the real `Shared/` parsers (and the app's `SettingsInput`) through symlinks | `ParserTests/` |
| The design lab | A macOS Swift package that renders widget looks as images | `MockLab/` |

`project.yml` is the source of truth for the Xcode project (XcodeGen). No third-party packages are used anywhere.

## Data flow

```mermaid
sequenceDiagram
    participant WK as WidgetKit
    participant P as Timeline provider
    participant DL as DataLoader
    participant GH as GitHub Contents API
    participant OM as Open-Meteo
    participant S as App Group store
    WK->>P: getTimeline
    P->>DL: loadDay()
    par weather
        DL->>OM: forecast (current + 5 days)
    and tasks
        DL->>GH: GET contents/Daily Brief/Today.md (raw)
    end
    DL->>DL: TaskParser → todaysAgenda
    DL->>S: save DaySnapshot (with any error)
    opt the brief names a new picture of the day (15 s at most)
        DL->>DL: BriefPicture.find → download (web: no token; vault: Contents API) → BandImage cut
        DL->>S: save picture.jpg and Store.briefPicture
    end
    DL-->>P: snapshot (fresh where it worked, cached where it didn't)
    P-->>WK: entries + reload policy
```

### Reading the vault

The vault is an Obsidian folder that the Obsidian Git plugin pushes to a private GitHub repository. `GitHubClient` fetches one file at a time through the Contents API with `Accept: application/vnd.github.raw+json`. That returns the raw Markdown for private repositories, given a fine-grained token with Contents permission on that one repository: Read-only is enough to read, and ticking tasks needs Read and write (see [Writing to the vault](#writing-to-the-vault)). Paths are percent-encoded segment by segment, so folders with spaces (`Daily Brief/Today.md`) work.

`Parsers.swift` holds two parsers and the agenda:

- **`TaskParser`** reads [Obsidian Tasks](https://publish.obsidian.md/tasks/) lines: `- [ ] #todo Text ⏫ 📅 2026-06-05`.
  - It reads the priority emoji (🔺 ⏫ 🔼 🔽 ⏬) and the due date.
  - It cleans the inline Markdown (wiki links, bold, block IDs).
  - It skips done tasks.
- **`TaskParser.todaysAgenda`** orders the tasks into buckets: overdue, due today, undated high priority, due within a few days, other undated, later. Inside a bucket it sorts by priority, then due date, then the order in the note.
- **`QuoteParser`** reads three shapes:
  - blockquotes followed by an author line starting with a dash;
  - bullets (`- "text" — Author`);
  - lines that open with a quotation mark (`“text” - Author`).

  An author line directly under a quote in quotation marks that has none becomes its author. Under a bullet quote that's an indented sub-bullet or a line starting with an em or en dash (`— Author`); a plain bullet there is the next quote in the list. Under a quote on a line of its own, a plain `- Author` counts too, if it reads like a name (80 characters at most, not ending in `.`, `!` or `?`). Headings and other prose are ignored, so the quotes file can be organised freely. The widgets show the author under the quote (the Quote widget at every size, and the large Day); a quote with no author in the file shows none, as nothing is guessed.

The task paths are a setting: one vault path per line, where `{daily}` expands to today's daily note (`daily note/MM.dd.yyyy - EEEE.md` by default). The default is the Daily Brief.

### The brief's picture of the day

The morning brief embeds one picture in `Today.md`, usually a public-domain painting from a museum's IIIF server, in a callout. The large Today widget lays it across its top in place of the still life.

- **Finding it.** `BriefPicture.find` takes the first picture in the note: a Markdown image with an https URL (a title after the URL is fine), a relative path in the vault, or an embed like `![[pic.jpg|300]]`, inside blockquotes and callouts as anywhere else. Pictures in fenced code (a fence in a callout ends with the callout), inline code, `%%` comments and the front matter don't count, nor do embedded notes, http links or SVGs. A vault picture is looked for beside the note, then from the top of the vault (`vaultPaths`).
- **Fetching it once.** After the day's snapshot is saved, `DataLoader` hands the brief's text to `BriefPicture.update` and waits 15 seconds at most. A picture the store already has is not fetched again. A new one is downloaded to a temporary file: from the web with a plain request and no token, from the vault through `GitHubClient.download` (raw, with the token). `BandImage` downsamples it with ImageIO (never decoding it whole, since the widget extension has little memory) and cuts the middle to 656 × 164, the band at 2 pixels per point, as a JPEG of a few tens of kilobytes.
- **Keeping or clearing it.** A brief with no picture brings the flowers back. A download that fails keeps the last picture only if the brief named it today, and the same picture isn't tried again for an hour. The band shows the picture only on the day the brief named it, so after midnight it's the flowers until the brief is read again. Offline, the widget draws what's on file.
- **Drawing it.** `RococoBriefBand` glazes it at night like the other pictures and darkens it smoothly across the whole band toward its foot (`RococoBriefBand.foot`: clear at the top, then umber from where the words begin), fixed rather than scaled by the theme. A soft ground behind each line was tried first; on a pale painting it showed as grey boxes. "Today" and the date measure at least 5.3:1 on a white painting by day, the hardest case (`scripts/check_band_contrast.py`, on the `-renderWidgets` stand-ins). The picture's alt text is its VoiceOver label. On tinted and clear home screens the shades are left out as everywhere else, so the words can be hard to read on a very pale painting there.

### Writing to the vault

Tasks can be ticked off in two places: on the Daily Brief page, where each task's ring is a button (tap again to untick), and on the Today widget at every size, where the ring is an App Intent button (`ToggleTaskIntent`) and the rest of the widget still opens the page. Both go through `TaskSync`.

- **What's written.** The tick goes to the file and line the task came from (for the brief's tasks, `Daily Brief/Today.md`), in the Obsidian Tasks convention: `- [ ]` becomes `- [x]` and ` ✅ YYYY-MM-DD` is added, before a trailing `^block-id` if there is one. Unticking reverses both. The indentation and the rest of the line stay as they were. `TaskToggle.apply` finds the line by its exact text, preferring the line number it was read from. A widget tap doesn't know the exact line, so it finds the task by its words, and when two lines share them (two "Call the dentist" on different days), by its 📅 date before its line number, which may have moved. If the line is gone, or two lines still can't be told apart, nothing is written and the page says the task changed in the vault. A tap ticks that one task only: the other one worded alike stays on the widget.
- **Repeating tasks.** A task with 🔁 is never ticked by the app: ticking it here would end the recurrence, while Obsidian's Tasks plugin makes the next one when it's ticked there. The parser marks it (`TaskItem.repeats`); the widget's ring for it is no button, the Brief page shows its ring with "Repeats: tick it in Obsidian", and a tap on it (from a widget timeline drawn before) is refused with "This task repeats: tick it in Obsidian, so the next one is made." and the task stays. If only the file shows it repeating, the write finds that out and writes nothing.
- **How.** `GitHubClient.fetchFile` reads the file and its `sha` through the Contents API, and `updateFile` sends the new text back with that `sha` as a commit, `Baroque: done "<the task's first 50 characters>"` (or `undone`). If the file changed in between (409 or 422), it fetches, ticks and tries once more. A 403 or 404 on the write means the token can only read; the app says so and doesn't retry.
- **At once, then saved.** The ring fills and the task is struck out straight away, with "Saving…" under it until the write is done. The task leaves the cached agenda first, so the Today widgets redraw without it even offline. A write that fails waits in `Store.pendingToggles` ("Not saved yet: will retry") and is tried again when the app comes to the front, on Save & Refresh, and when a widget loads the day: there the waiting ticks are written before the tasks are read (for 3 seconds at most), so the list read is the file as they left it. Taps on the same task merge: a tick and then an untick cancel out. Saved ticks decode one by one, so an entry that can't be read is dropped rather than all of them.
- **Ticks stay ticked, in the Daily Brief.** The morning brief rewrites `Today.md` every day and may list a ticked task again, unticked. `Store.doneTasks` remembers each tick made there (the newest 500): the day, and a key made from the task's text without the checkbox, the ✅ date, the priority and due markers and extra spaces. An open task in the brief whose key is remembered counts as done: the widgets leave it out, the Brief page shows it ticked, and a tick is queued so the file is ticked again. Unticking a task forgets it. Ticks in any other file aren't remembered (`TaskSync.remembers`): they're written to the file and stay ticked there on their own, so next month's "Pay rent" isn't ticked because this month's was.
- **The known limit.** In the Daily Brief, a new task worded exactly like a ticked one shows as ticked. Untick it once and it stays open. The brief's source notes usually make the wording unique.
- **Reaching Obsidian.** The commit lands in the vault's GitHub repository, and Obsidian has it the next time Obsidian Git pulls (on a schedule, and on startup). Editing the same line on the Mac before that pull can cause a merge conflict there.

Ticking needs a fine-grained token with **Contents: Read and write** on the vault's repository ([SETUP.md](SETUP.md#ticking-tasks-off)). Tests use a stubbed `URLProtocol`, never a real repository.

### Weather

`WeatherClient` asks Open-Meteo for the current conditions and five days of highs, lows, weather codes, sunrise, sunset and the chance of rain, in one request. Open-Meteo needs no key and no account. The location is set once in the app, from Core Location or typed in.

### One fetch for every widget

It fetches once and serves every widget. Day and Today share a provider, and iOS asks for each widget kind and size on its own schedule, so one refresh of the home screen used to fetch the same weather and brief once per widget. `DataLoader.loadDay()` and `loadQuotes()` now return the stored snapshot if it's less than 15 minutes old, from today, and saved without an error (`DataLoader.isFresh`); a failed fetch is never served as fresh. Widgets that load at the same moment share one fetch in progress (`SharedFetch`), and a widget's fetch that finds a newer stored snapshot keeps that one. The app's Save & Refresh passes `maxAge: 0` to fetch fresh, and the widgets it then reloads reuse that fetch.

### Storage

`Store` is the one place both targets read and write:

| Key | Contents |
| --- | --- |
| `baroque.settings` | `BaroqueSettings`: repository, paths, location, units, the quote rotation, the Obsidian vault's name |
| `baroque.daySnapshot` | weather, the agenda and any errors, with the time of the fetch |
| `baroque.quoteSnapshot` | the parsed quotes |
| `baroque.quoteOffset` | how far the next-quote button has moved the rotation |
| `baroque.brief` | the last Daily Brief fetched in full |
| `baroque.pendingToggles` | ticks and unticks not yet written to the vault |
| `baroque.doneTasks` | the Daily Brief's ticks, remembered so a task the brief lists again stays ticked |
| `baroque.briefPicture` | the brief's picture of the day on file: its source, alt text and the day the brief last named it (the JPEG itself is `Library/Caches/Brief picture/picture.jpg` in the App Group's container) |
| `baroque.briefPictureFailure` | the last picture whose download failed, and when, so it waits an hour before another try |

They live in the App Group's `UserDefaults` (`group.com.ryanfernandez.terra`). Settings decode field by field, so a field added in a later version takes its default instead of resetting what was entered, and a field no longer used, like the old "Max tasks shown" (`maxTasks`), still decodes.

The token is kept in the Keychain, in an access group both targets share. On an iPhone it's never written anywhere else: if the Keychain refuses it, the app says "Couldn't save the token to the Keychain" rather than keep a plain copy, and a copy an older version left in the App Group's defaults is moved into the Keychain at launch (the old copy is removed once the Keychain one reads back). Only the simulator, where there's no shared access group without signing, keeps it in the App Group's defaults.

### Offline and errors

Every load records what failed instead of throwing:
- The snapshot keeps the newest data it has: fresh where the fetch worked, cached where it didn't. The weather is cached only for the day it was fetched.
- The error goes in the snapshot too, and each widget sets it on its last line ("GitHub rejected the token (401)", "Not found: <path> in <owner/repo> …", "No branch …", "Set a location in the Baroque app", "No GitHub token…").

So a widget that can't reach the network still draws, and says why it's stale.

## Widgets

| Kind | Provider | Refresh | Tap |
| --- | --- | --- | --- |
| `BaroqueDay` | `DayProvider` | every 30 min and at midnight | opens the app |
| `BaroqueToday` (S M L) | `DayProvider` | the same | a task's ring: `ToggleTaskIntent` ticks it; anywhere else: `baroque://brief`, the Daily Brief page |
| `BaroqueQuote` | `QuoteProvider` | six entries ahead on wall-clock slots (every 60 min by default) | `NextQuoteIntent`: the next quote |
| `BaroqueBattery` | `BatteryProvider` | every 15 min (reads `UIDevice` in the extension) | opens the app |
| `BaroqueStillLife` | `StillLifeProvider` | never | opens the app |
| `BaroquePhotograph` (S) | `PhotographProvider` | a day of three-hour turns laid out ahead; nothing to fetch | opens the app |

**Quote rotation.** The quote for a time slot is `(offset + slot) % count`, where the slot is the wall-clock time divided by the rotation length, so the sequence keeps its place across reloads. `NextQuoteIntent` (an App Intent behind a `Button` in the widget) bumps `quoteOffset` and reloads the Quote and Day timelines. The large Day widget shows the quote one past the Quote widget's (`DataLoader.dayQuoteIndex`), with an entry at every quote slot, so the two never match.

**Photographs.** `RococoPhotos` takes the author's repainted photographs in turn, a new one every three hours on the local clock (midnight, 3, 6 …). The large Day widget uses the six landscapes with no one where its quote sits; the Photograph widget uses all ten and never shows the one the Day widget is showing. The Day provider lays out an entry at every photograph change in the next 24 hours, so the photograph changes on time even when a reload comes late.

**Layout.** Every rococo view is laid out once at its iPhone 17 size: small 164, medium 348 × 164, large 348 × 365 points. `RococoFrame` scales that layout to fill whatever size the phone gives the widget, with every layout keeping 14 points clear of the edges for the crop. The paintings are composed around the words, and words on a picture always sit on its darkened side, which is darker again at night.

**Theme.** Colours, how much brushwork shows on the stone, the edge and the darkening behind words on photographs come from `RococoTheme.current` (Quiet). `RococoInk` reads its colours from it, and `RococoFrame` adds the theme's edge.

**Images.** WidgetKit refuses to draw a widget whose images add up to too many pixels. The widget images are JPEGs cut to their frame at 2 pixels per point, so the largest is 696 × 730. `widgetAccentedRenderingMode(.fullColor)` keeps the paintings in colour when the home screen is set to clear or tinted.

## The app

The app compiles two files of its own on top of `Shared/`: `Theme.swift` and `Landscape.swift` paint its backdrop (the sky that follows the time of day, the ridges, the stone panels), building on `Shared/Sky.swift`. The widgets need only `Sky.swift`.

`ContentView` is a single form:
- **The previews:** the real rococo views with the cached snapshots.
- **Settings:** the repository, the token, the paths and the location. There's no "Max tasks shown" setting any more: the small and medium Today show four tasks and the large up to seven that fit, then "+ N more".
- **Home screen setup.**
- **The icons.**
- **Save & Refresh:** stores the settings, fetches, retries any unsaved ticks, and reloads every timeline.

`BriefView` fetches the Daily Brief and sets it out block by block: the title, the summary, the sections, tasks with rings, bullets. Each ring ticks its task ([Writing to the vault](#writing-to-the-vault)). It caches the note in `Store.brief`.

### Home screen setup

iOS lets no app move icons, set the wallpaper or place widgets, so the app hands over the pieces:
- **The icons:** the app keeps the 24 icons as files under Files › On My iPhone › Baroque, so each icon can be made as a Shortcuts **Open App** shortcut added to the Home Screen with its picture.
  - A web clip from a configuration profile looks the same but opens Safari before the app.
  - The profile key that would avoid that, `TargetApplicationBundleIdentifier`, works only in profiles installed by an MDM server.
- **The wallpaper:** saved to Photos.
- **The plan:** a drawing of the dock and pages.

`scripts/mirror_setup.py` can do the tapping through macOS's iPhone Mirroring. It photographs the mirrored screen and reads it with Vision (`scripts/mirror/ocr.swift`), recognises the icons by their pictures, and taps and drags with `cliclick`. Its docstring records what mirroring does with synthetic input. For example, a drag that starts on an icon picks it up immediately, and Return arrives only through System Events.

### Debug launch arguments

`Baroque/DebugLaunch.swift` and `WidgetRenders.swift` (debug builds only):

| Argument | Does |
| --- | --- |
| `-resetData` | fresh-install state, including the Brief cache, the one-time Daily Brief move and any pending or remembered ticks |
| `-seedDemoData` | demo tasks and quotes in the cache |
| `-renderWidgets` | exact-size PNGs of every widget state at three phone sizes, into the app's Documents |
| `-scrollTo <section>` | opens the form at a section (`github`, `setup`, `icons`, …) |
| `-briefFile <path>` | a Daily Brief read from a file |
| `-openBrief` | opens the Brief page |
| `-saveIcons` | saves the 24 icons to Photos in home screen order |

## Tests

- **Parser tests:** `ParserTests/` tests the parsers, the agenda ordering and the daily note paths against real-shaped Markdown, and ticking: the line change, tasks worded alike, repeating tasks, the ticks that stay ticked in the Daily Brief, and the GitHub writes against a stubbed `URLProtocol`, and the brief's picture of the day: finding it, vault paths, keeping or clearing it, its stubbed download and its cut to the band (`cd ParserTests && swift test`).
- **UI tests:** `BaroqueUITests/` drives SpringBoard on the simulator to place each widget on the home screen and screenshot it, fresh, cached and with a bad token (`scripts/capture_screenshots.sh`).

## The design lab

`MockLab/` has one executable per look. A look renders the six widget states and a board to `MockLab/out/<look>/` with fixed demo data, and the harness links the app's own models through symlinks.
- **The painted looks** link `PaintKit/`, which compiles the app's `Theme` and `Landscape`, the retired views (the Old Master Cover look, and the first painted-night set with its skies and ridges in `RetiredGrounds.swift`) and both image catalogs: the app's and `Archive.xcassets`.
- **`RSmalls`** links the shipped `Shared/Rococo*.swift`. It renders the small widget ideas, and with `README=1` it renders the README's pictures.
