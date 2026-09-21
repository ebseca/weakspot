# Weakspot — working notes

Offline multiple-choice flashcard app in Flutter. Personal project, one
user, Android phone. No account, no sync, **no network call anywhere** —
that constraint is load-bearing, not incidental.

`README.md` describes the app for a reader. This file is for working on it.

## Commands

```bash
flutter analyze            # must be clean before building
flutter test               # 293 tests, all must pass
flutter build apk --release --target-platform android-arm64

# Redraw the launcher icon after touching lib/ui/logo.dart
flutter test tool/generate_icons.dart
```

Targets are **Android and web**. Windows desktop does *not* build — Visual
Studio is missing the "Desktop development with C++" workload.

### Installing on the phone

The phone is a Xiaomi (`23090RA98I`, id `JRMZHINVIFJNQG45`). Three quirks
cost real time if rediscovered:

1. **Use PowerShell for `adb`, never Bash.** Git Bash rewrites `/sdcard/…`
   into a Windows path. `MSYS_NO_PATHCONV=1` fixes the destination but then
   breaks the *source* path, so just use PowerShell.
2. **`flutter install` does not build.** It looks for an existing APK and
   fails confusingly if there isn't one. Build first.
3. **Input injection is blocked** (`INJECT_EVENTS` permission). `adb shell
   input tap` will never work, so the app cannot be driven from here.
   Screenshots *do* work — that is the only way to see the real UI.

```powershell
$adb = "C:\Users\ebsec\AppData\Local\Android\Sdk\platform-tools\adb.exe"
& $adb install -r "C:\bigideas\flashcards\build\app\outputs\flutter-apk\app-release.apk"
& $adb shell am start -n com.ebseca.weakspot/.MainActivity
# screenshot
& $adb shell screencap -p /sdcard/s.png
& $adb pull /sdcard/s.png "<scratchpad>\s.png"
```

Pushing a copy to `/sdcard/Download/weakspot-<version>.apk` is also useful;
follow it with a media scan or it will not appear in the Files app:

```powershell
& $adb shell "content call --uri content://media/external/file --method scan_file --arg /sdcard/Download/weakspot-0.9.1.apk"
```

The phone drops off ADB fairly often. `adb kill-server; adb start-server`
usually brings it back; if `Get-PnpDevice` shows only HID "Portable Device
Control" entries and no ADB interface, the phone is in charge-only mode and
needs a tap on the notification shade.

Versioning: minor tracks the feature step, build number increments with it
(`0.9.1+13`). Bump both on every build so the phone's app info identifies
what is installed.

## Layout

```
lib/core/     pure logic — model.dart and rules.dart import no Flutter
  model.dart        Note, CardState, Library, Direction, JSON
  rules.dart        every tunable number + the logic derived from it
  session.dart      what to ask next, options, game modes, the run log
  stats.dart        direction split, weak list
  deck_import.dart  parsing AI replies, building the prompt
  store.dart        shared_preferences persistence, bundled deck seeding
  settings.dart     Settings value, its store, and SettingsController
lib/ui/       one file per screen, plus theme.dart, widgets.dart, logo.dart
tool/         generate_icons.dart — run as a test, writes android res
assets/decks/ hiragana.json, katakana.json — same JSON shape as an AI reply
design/project/  the .dc.html mockups this was built from
test/         mirrors lib/
```

## Settings

`SettingsController` is a plain `ChangeNotifier` passed down explicitly —
no package, same as the repository. `main.dart` holds the first frame until
it has loaded, so a Pro install never flashes the free mark.

- **Deck language** is about the *content an AI writes*, not the app's own
  text. There is no i18n in the app and none is planned; the setting adds
  one rule to the generated prompt and nothing else.
- **Answer options** and **cards in play** are carried into `SessionConfig`
  as `options` and `poolTarget`, which default to the `rules.dart`
  constants. `rules.dart` is still the spec; the settings move the dial,
  they do not replace it.
- **Weakspot Pro** is a local boolean. Nothing is charged, nothing is
  checked, and the card says so out loud. It gates the 10-minute timed run
  and the gold mark. Binding it to a real purchase later means changing
  where `Settings.pro` comes from and nothing that reads it.

## The mark and the icon

`lib/ui/logo.dart` holds one painter. `WeakspotMark` draws it in the app;
`tool/generate_icons.dart` renders the same function to every
`mipmap-*` PNG — legacy, adaptive foreground and Android 13 monochrome,
in both the standard and the Pro colourway — plus the adaptive XML and the
background colours. **The icons in git are generated. Never hand-edit
them**; change `paintMark` and re-run the tool.

The mark is a 3x3 grid of cards with the centre one lit and ringed: the
whole deck, with the weak spot picked out.

### Swapping the launcher icon

Android has no "set my icon" call, so the manifest declares **two
`activity-alias` entries** pointing at `MainActivity` — `.Launcher` with
the everyday icon (enabled) and `.LauncherPro` with the gold one
(disabled). `MainActivity.kt` exposes a method channel that enables one
and disables the other; `SettingsController` calls it whenever `pro`
changes, and again on every `load()` so the stored flag stays the truth.

Four things that will bite if they are changed:

1. **The swap happens in `onStop`, never while the app is on screen.**
   Disabling a component the current task was launched *through* makes
   ActivityManager finish the task: the app vanishes mid-tap and reads as
   a crash, with nothing in the crash log because nothing threw. This
   shipped once and was reported as "program crashes when I click on
   subscription button". `MainActivity` now queues the wish in
   `pendingPro` and applies it on the way out. An icon that already
   matches is dropped rather than queued, so the reconcile on every
   launch never disturbs a task.
2. **MainActivity must not carry the LAUNCHER intent-filter.** The aliases
   do. Two enabled entries put the app in the drawer twice.
3. **Enable before disabling.** An instant with no enabled launcher entry
   is what makes an app vanish from the home screen rather than change.
4. **`DONT_KILL_APP`.** Without it Android restarts the process outright
   the moment the component changes.

The deferral is visible in the UI rather than hidden: the Pro card says
"The home-screen icon changes when you next leave the app."

`adb shell pm enable|disable` **cannot** be used to test this — MIUI's
shell refuses to change another package's component state
(`SecurityException: Shell cannot change component state`). Only the app
itself can do it, so the swap has to be tested by tapping.

Verify a build with:

```powershell
& $adb shell "cmd package resolve-activity --brief -a android.intent.action.MAIN -c android.intent.category.LAUNCHER com.ebseca.weakspot"
```

It should print `.Launcher` or `.LauncherPro`, never both and never
`.MainActivity`.

Mockup canvas: https://claude.ai/code/artifact/b5266778-5ebc-440f-be43-bf1f2e615655

## Conventions

- **`rules.dart` is the spec.** Every threshold lives there as a named
  constant with a comment saying *why* that value. Tests reference the
  constants rather than hardcoding numbers.
- **`core/model.dart` and `core/rules.dart` must stay Flutter-free** so the
  logic is testable without a widget binding.
- **Tests mirror `lib/`** and are named as sentences describing behaviour,
  not method names.
- **Comments explain why, not what.** Several non-obvious constraints are
  only recorded in comments — read them before "simplifying".
- **No dead controls.** A control that does nothing yet is not shipped.
- **Single dark theme**, deliberately. The warm paper card on the ink
  ground is the app's identity; there is no light mode.
- The app follows the structure of the user's previous Flutter project,
  `github.com/ebseca/eyetrainer`: no state-management package, plain
  widgets plus a store class, `flutter_lints`.

## How progression works

Read `rules.dart` for the authoritative version. In short:

- A **note** is content; a **card** is one testable direction of it.
  Directions are scored separately.
- Each card keeps a rolling window of its **last 10 answers**.
- Selection takes the **worst win rate**, widened by `selectionBand` and to
  at least `minSelectionCandidates`, then picks at random among them.
- The pool keeps **`unmasteredTarget` (5) unmastered cards in play**.
  Master one and the next opens *immediately, mid-session*.
- A card needs **`minAttemptsToMaster` (4) answers** before it can count as
  mastered — one lucky guess is a 100% win rate.
- **20% of a practice session** goes to already-mastered cards.
- A note's **grid colour pools both directions**; the per-direction scores
  drive everything else.
- Cards can be opened **out of order** — `unlockedIds` is a set, not a
  count. Pacing still walks down the deck around anything opened by hand.

## Decisions that were made and then reversed

Do not reintroduce these without being asked. Each was built, shipped, and
deliberately removed.

- **Categories / groups.** Cards had a `category`, sessions could drill one
  group, wrong answers could be drawn from the same group, and the bundled
  kana decks were tagged with gojūon rows. Removed entirely at the user's
  request — too many groups, and it cluttered the setup screen.
- **Batch unlocking behind a 70% gate.** Replaced by the steady-supply rule
  above, because it only unlocked at session *end* and gave at most +5 per
  completed session, which stalled badly at high accuracy.
- **Pool sized as half the session length** (`poolTargetFor` /
  `ensurePoolFor`). Removed: it contradicted the steady-supply rule by
  dumping 20 cards on a 40-question session regardless of mastery.
- **`bandForNote` taking the worst direction.** Caused the whole grid to
  turn yellow the moment a second direction was started, because a card
  with under four answers cannot be mastered. Now pooled.
- **The whole-deck mastery grid on the results page.** Every session ended
  on the same screen whatever had just happened, which made the page worth
  nothing. Results now list only the cards *that run* asked, worst first,
  with this run's answers as dots. The whole-deck grid is still on the
  stats screen, one tap away behind "See the whole deck".

## Deck-content pitfalls

Both are the deck's fault, not the app's, and both are now caught at import
and warned about in the generated prompt:

- **Duplicate answers** cap how many options a question can show. Options
  are deduplicated by text — two buttons both reading "kor" would make the
  question unanswerable — so a deck with few distinct answers asks two- and
  three-choice questions. Thai romanisation triggers this constantly.
- **An answer containing its own question** (`"t - th tao ฏ"`) reads fine
  forwards but becomes a self-answering prompt in reverse.

Pasting a corrected deck with the same name offers to **replace** the
existing library, keeping all recorded answers. Card state is keyed by id,
and ids default to the front.

## Outstanding

- **No GitHub remote.** The repo is committed locally; `gh` is not
  installed on this machine, so pushing needs either `gh` or a remote added
  by hand.
- **System fonts**, not the IBM Plex / Noto Sans JP from the approved
  mockup. Bundling them means downloading ~5MB of font files.
- Parked features with a note on where they would go are listed at the
  bottom of `README.md`.
