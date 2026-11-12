# Setting up Baroque on an iPhone

About 30 minutes the first time. You need a Mac with Xcode 16 or later and [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), an iPhone on iOS 17 or later, and any Apple ID. A paid developer account isn't required.

## 1. Your vault on GitHub

Baroque reads your Obsidian vault from a GitHub repository; it can be private.
1. Push your vault to GitHub. The [Obsidian Git](https://github.com/Vinzent03/obsidian-git) plugin does it on a schedule.
2. Check that the vault has the notes Baroque reads (see [`examples/`](../examples/)):
   - **`Daily Brief/Today.md`:** the tasks, as Obsidian Tasks lines (`- [ ] #todo …`). The path can be changed in the app, and can be a list of notes.
   - **A quotes file:** blockquotes, bullets or lines in quotation marks.
3. Make a token: on github.com go to **Settings › Developer settings › Personal access tokens › Fine-grained tokens › Generate new token**.
   - Under **Repository access**, choose **Only select repositories** and pick your vault.
   - Under **Permissions › Repository permissions**, set **Contents** to **Read and write**, so a task you tick in Baroque is ticked in the vault too. **Read-only** is enough if you only want to read: everything works but ticking.
   - You'll paste the token into Baroque below. On the iPhone it's kept only in the Keychain.

## 2. Build and install

1. Generate the project:
   ```sh
   xcodegen generate
   ```
2. In Xcode, open **Settings › Accounts** and sign in with your Apple ID. A **Personal Team** appears under your name.
3. Copy `Config/Local.example.xcconfig` to `Config/Local.xcconfig` and put your team ID in it. Git ignores that file.
4. If someone else already uses the bundle identifiers, change `com.ryanfernandez.terra` to your own in `project.yml`. Do the same in both `.entitlements` files (the App Group) and in `Shared/Store.swift`. Then run `xcodegen generate` again.
5. Open `Baroque.xcodeproj`. In **Signing & Capabilities**, for both **Baroque** and **BaroqueWidgetExtension**, tick the App Group under **App Groups** once.
   - Xcode registers it with your team; the command line can't.
   - The App Group is how the widgets share the app's settings and token, and it works on a free team.
6. Connect the phone, unlock it, and tap **Trust**. If iOS asks for Developer Mode, turn it on in **Settings › Privacy & Security › Developer Mode** and restart.
7. Run the install script, or press Run in Xcode:
   ```sh
   scripts/install_on_iphone.sh
   ```
8. The first time, trust yourself on the phone: **Settings › General › VPN & Device Management**, your Apple ID, **Trust**.

On a free Apple ID the app stops opening after seven days. Run the script again; nothing is lost.

## 3. In the app

1. Under **GitHub (Obsidian vault)**, fill in the owner and repository, then paste the token.
2. Tap **Use current location** for the weather.
3. Tap **Save & Refresh**. The previews fill with your tasks, quotes and weather.

## 4. The home screen

iOS doesn't let an app arrange your home screen, so this part is by hand, or with `scripts/mirror_setup.py` (below).

**The icons.** Make each as a shortcut:
1. In **Shortcuts**, tap **+**, add **Open App** and choose the app.
2. Tap the shortcut's name, then **Add to Home Screen**.
3. Tap **Image**, then **Choose File**, and pick the app's icon. The icons are in **On My iPhone › Baroque › Home screen icons**; Baroque's **Show the icons in Files** button opens the folder.
4. Tap **Add**.

The icon opens the app directly. A small banner or a Dynamic Island flicker can show as it does. Web clips from a configuration profile look the same but open Safari first, so Baroque doesn't use them.

**The wallpaper.**
1. In Baroque, tap **Save the wallpaper**.
2. In Photos, open *The Bathing Pool*.
3. Tap **Share › Use as Wallpaper › Add › Set as Wallpaper Pair**.

**The widgets.**
1. Long-press the home screen, then tap **Edit › Add Widget**.
2. Search for **Baroque** and pick a size with the page dots under the preview.
3. The author's layout is drawn in the app, under **Set up your home screen**:
   - page one: Day large over eight icons;
   - page two: Day, Today and Quote small among twelve more.

**Hiding the originals.** Move your old icons off the home screen: long-press, then **Remove App › Remove from Home Screen**. They stay in the App Library. Or hide whole pages under **Edit › Edit Pages**.

### Doing it through iPhone Mirroring

`scripts/mirror_setup.py` drives the phone through macOS's iPhone Mirroring. It reads the screen with Vision and taps, drags and types with `cliclick` (`brew install cliclick`). It made the author's 24 icons and laid out the pages.

It needs:
- **Mirroring:** iPhone Mirroring set up, and the phone locked nearby.
- **Permissions:** Accessibility and Screen Recording for the terminal it runs in.
- **The Mac to itself:** it takes over the mouse while it runs.

It never types a passcode or a token, and it never deletes anything of yours. See its docstring for what it can do and what mirroring allows.

## Ticking tasks off

Tap a task's ring on the Today widget or on the Daily Brief page to tick it; on the page, tap it again to untick it. Baroque writes the tick into the note the task came from, the way the Obsidian Tasks plugin does: `- [ ]` becomes `- [x]`, and the line ends with ✅ and today's date.

- **The token needs Read and write.** With a read-only token the task stays ticked in Baroque, with a note that the token can only read. Make a token as in section 1, step 3, with **Contents** set to **Read and write**, paste it in the app and tap **Save & Refresh**. The waiting ticks are written then.
- **Offline.** A tick made offline says "Not saved yet: will retry", and is written the next time the app opens, on Save & Refresh, or when a widget refreshes.
- **Ticks stay ticked.** If your morning brief rewrites `Today.md` and lists a ticked task again, Baroque keeps it ticked and ticks it in the note again. A new task worded exactly like one you ticked shows as ticked too; untick it once and it stays open.
- **In Obsidian.** The tick arrives the next time Obsidian Git pulls. If you edit the same line on your Mac before then, Obsidian Git may report a merge conflict.
- **"This task changed in the vault."** The line was edited or moved since Baroque read it. Pull down to refresh, then tick it again.

## Troubleshooting

| Seen | Fix |
| --- | --- |
| "No GitHub token" on a widget | Paste the token in the app and tap Save & Refresh |
| "GitHub rejected the token (401)" | The token has expired or lacks Contents: Read-only on the vault |
| "Not found: Daily Brief/Today.md" | The path doesn't exist on the branch; check the Tasks setting and that the vault has been pushed |
| Widgets don't change after Save & Refresh | iOS budgets widget reloads; lock and unlock the phone, or wait a few minutes |
| The build fails on App Groups | Tick the App Group in Signing & Capabilities for both targets once |
| The app won't open after a week | A free-team build expires after seven days; run the install script again |
