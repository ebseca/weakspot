# Weakspot — working notes

Offline multiple-choice flashcard app in Flutter. Personal project, one
user, Android phone. No account, no sync, **no network call anywhere** —
that constraint is load-bearing, not incidental.

`README.md` describes the app for a reader. This file is for working on it.

## Commands

```bash
flutter analyze            # must be clean before building
flutter test               # 253 tests, all must pass
flutter build apk --release --target-platform android-arm64
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
  session.dart      what to ask next, options, game modes
  stats.dart        direction split, weak list
  deck_import.dart  parsing AI replies, building the prompt
  store.dart        shared_preferences persistence, bundled deck seeding
lib/ui/       one file per screen, plus theme.dart and widgets.dart
assets/decks/ hiragana.json, katakana.json — same JSON shape as an AI reply
design/project/  the .dc.html mockups this was built from
test/         mirrors lib/
```

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

- **Not a git repo.** Thirteen builds, no history, nothing to roll back to.
  Raised repeatedly; the user has not asked for it yet.
- **System fonts**, not the IBM Plex / Noto Sans JP from the approved
  mockup. Bundling them means downloading ~5MB of font files.
- Parked features with a note on where they would go are listed at the
  bottom of `README.md`.
