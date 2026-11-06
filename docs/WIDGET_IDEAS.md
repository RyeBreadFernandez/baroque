# Widget ideas for Baroque (research, 2026-11-05)

After "scan pinterest or do research for other widget ideas". Fifteen Pinterest searches (results personalised by the
signed-in Chrome), app and API documentation, and live checks of Open-Meteo. Reddit couldn't be fetched, so what
r/iOSsetups favours right now is unverified. Reference pins and thumbnails were kept in the session scratchpad.

## What Pinterest shows
- **Common widget types:** photo or painting tiles, a giant clock or date, weather, now-playing, quotes, planners and agendas, and the moon.
- **The two strongest trends:** countdowns ("D-day") and year-progress dots ("2026 is 81% done").
- **Outdoor setups are only photo tiles.** Working outdoor widgets (sunset quality, tides, stargazing, the next trip) hardly appear, so that is Baroque's opening.

## Facts that matter now
- **iOS 26 clear and tinted home screens turn widget images grey** unless they are marked full colour. Done in 1.0.0 (`rococoFullColor()`).
- **iOS refreshes a widget about 40–70 times a day.** Only `Text` timer styles and `ProgressView(timerInterval:)` move live.
- **Open-Meteo at UCLA:**
  - works: US air quality, UV, and the marine data at Santa Monica (waves, water temperature, tide height);
  - fails: pollen is Europe-only and returns null.
- **Art Institute of Chicago API:** public-domain images with no key, including Hubert Robert's Méréville canvases. The Met's v1 search was retired; v1.1 works.
- **Writing to the vault:**
  - it needs a write-scoped token;
  - if `obsidian-vault-backup` is a one-way backup, the widget's edits could be overwritten, so check how it syncs first.

## Build first
1. **Next Adventure** (S/M/L). "Bryce · 12 days" over a painting of the place; within 16 days it adds the place's forecast.
   - Data: a `Trips.md` in the vault and Open-Meteo.
   - Look: the place as a Robert capriccio, the count carved on a plinth.
   - Effort: M.
2. **Tonight's Glow** (S/M, Lock Screen).
   - Shows: a sunset-quality score from the cloud layers, humidity and air quality; golden and blue hour; a live "sunset in".
   - The score is a heuristic: check it against a sun app for two weeks.
   - Effort: M.
3. **Tap-to-check Today** (M/L, interactive).
   - Tick a task; the widget shows it done at once, then writes it to the vault.
   - Failed writes, including offline ones, wait and retry.
   - Needs the write token and the sync check above.
   - Effort: M.
4. **Salon, a painting of the day** (S/M/L). Rococo paintings and flower still lifes from the Art Institute of Chicago, with title, artist and year, in a limestone niche (no gilt frame). Effort: S.
5. **Quarter and deadlines** (S, Lock Screen). "Week 6 of 10 · Fall" and the nearest dated task with the days left; a carved hourglass. Effort: S.

## Later
- **Lock Screen set:** the moon with a sunset ring, the next deadline or Glow, and "Sunset 4:58 · 64°". The Lock Screen shows them in one colour, as engraved line art. S.
- **Beach and tide:** wave height and period, water temperature and a tide curve for a favourite beach, from Open-Meteo Marine (tides are approximate near the coast). M.
- **Stargazing tonight:** the moon's phase, rise and set, tonight's clouds and the dark window. M.
- **Study card:** one idea from the class notes; tap to reveal, tap for the next. Depends on how the notes are kept. M.
- **Daylight left:** a ring draining to sunset (`ProgressView(timerInterval:)`) and a turnaround time for hikes. S.
- **Park notices:** closures and alerts for Zion, Bryce and Kings Canyon from the National Park Service API (free key). S.
- **Tableau:** one painting filling a page, with the Sun Arc, weather and a quote, if iOS 27's extra-large iPhone widget is confirmed. L.
- **Controls** (Control Center): quick-add task, open today's note, next quote. Symbol and colour only, so they can't be painted. S.
- **On this day:** a photo from this date in past years with that day's daily-note line. M.
- **Air and sun:** US air quality, peak UV and "sunscreen until 3 pm". S.

## Skip
- **Spotify now playing:** stale between refreshes, and its developer mode needs Premium.
- **Screen Time:** not available to a free team.
- **Friend widgets** (Locket-style): they need a server and push notifications.
- **WeatherKit:** needs the paid account.
- **Miles hiked from Health:** Health can't be read while the phone is locked; revisit later.

## Small widget ideas, drawn (2026-11-05)
Ten small widgets in the shipped rococo look, rendered by MockLab's `RSmalls` target (`swift run --scratch-path .build-smalls RSmalls`, board in `MockLab/out/smalls/board.png`). Each uses the app's own `Shared/RococoStyle.swift`.

| Idea | What it shows | What it needs |
| --- | --- | --- |
| Moon | Tonight's moon raised in cream, its phase, nights to full or new | Nothing: worked out on the phone (`MoonPhase`) |
| Golden Hour | The sun half set into a carved horizon, when the light turns gold, how long until then | Today's sunset, already fetched |
| Date | The day of the month as a great gilt numeral, the month, tonight's moon (no weekday) | Nothing |
| Next | The one most urgent task, large | The vault's tasks, already fetched |
| Done Today | Today's ticked tasks as gold tally marks, "4 of 6" | The parser to count `- [x]` lines in today's daily note |
| Countdown | Days to the next trip as a cream numeral on one of the user's repainted photos | A dated task tagged `#trip` in the vault |
| Light | Daylight gained or lost since yesterday ("−1 m 37 s") | Yesterday's sunrise and sunset from Open-Meteo |
| Quarter | "Week 7 of 10" with ten notches, days to finals | The quarter's dates, set once in the app |
| Motto | A Latin motto in script and its meaning ("Festina lente") | A list in the app, or a note in the vault |
| Photograph | One of the user's repainted photographs, a different one each day, nothing else | The photos already in the app |
