# Weakspot

Offline flashcard drills that hunt your weak spots.

Multiple-choice practice over as many libraries as you like. Selection
targets whatever you are currently worst at, rather than marching through a
deck in order. Nothing leaves the device — there is no account, no sync and
no network call anywhere in the app.

On Google Play as `com.ebseca.weakspot`.

## How it works

A **note** is content: a front, a back, and an optional hint. A **card** is
one testable direction of a note. Reading (`あ → a`) and writing (`a → あ`)
are scored separately, because they are different skills — you can read a
character reliably and still be unable to produce it.

There are three **modes**. *Practice* hunts your weak spots over a fixed
number of questions. *Timed* does the same hunting against a clock — 1, 3
or 5 minutes, answer as many as you can. *Random* is a straight shuffle:
no targeting, no review slots, nothing held back.

A card you have never seen is **shown before it is ever asked** — both
sides, plus its hint, with nothing to click but "Got it". Introductions are
not scored and do not use up a question. Without this, the first encounter
with a new card is a blind guess, and a lucky one would tell the picker you
know something you have never laid eyes on.

Every card keeps a rolling record of its **last 10 answers**. The question
picker takes the worst win rate and then chooses at random among the cards
tied at it, so you drill your weak spots without grinding the same card ten
times in a row. An old mistake stops counting once it falls out of the
window, so a card you have fixed actually escapes.

The app keeps about **5 unmastered cards in play**. Master one and the next
opens immediately, mid-session — so the pool never runs dry, and walking
away early costs nothing. A card needs at least 4 answers before it can
count as mastered, because one lucky guess is a 100% win rate and proves
nothing.

Two manual overrides sit on the stats screen: **open 5 more** to skip
ahead, and tapping any locked card to **open just that one** — nothing in
front of it comes with it. Pacing carries on down the deck around whatever
you opened by hand.

One question in five goes to a card you have already mastered, so the things
you learned first do not quietly rot.

When a run ends you get **that run**, not a progress report: every card it
asked, worst first, with the answers you gave as dots beside them. The
whole-deck picture is still there, one tap away — it just is not what you
are shown after every single session.

A card's colour on the grid pools **both directions** into one record.
Taking the worst direction instead meant that answering a freshly started
direction twice dropped a note that had been green for weeks back to
yellow — a card with fewer than four answers cannot be mastered yet, so
switching to writing turned the whole alphabet yellow at once. Pooled, a
few new answers nudge a long record rather than overwriting it, and real
failures still cost you.

The per-direction scores are untouched, and still drive everything that
should be direction-aware: what gets asked next, the needs-work list, and
the reading-against-writing split.

| Band | Win rate |
|---|---|
| New | no attempts yet |
| Struggling | under 50% |
| Learning | 50–89% |
| Mastered | 90% or better |

## Settings

A handful, all of which do something:

| Setting | What it moves |
|---|---|
| Deck language | The language a generated deck's answers and hints are written in |
| Answer options | 3, 4 or 6 choices a question |
| Cards in play | 3, 5 or 8 unmastered cards held open at once |
| Haptics | A buzz on answering — lighter when right |

**Deck language** is about the cards an AI writes for you, not the app's
own text. The app is in English and there is no translation of it; the
setting adds one rule to the prompt you paste, so a Turkish speaker
learning Thai gets Thai on the front and Turkish on the back.

**Weakspot Pro** is a button that says "Subscribe now", charges nothing,
and turns on a 10-minute timed run and a gold mark — in the app *and* on
the home screen, which swaps to a gold launcher icon. It is scaffolding
for a subscription that does not exist yet, and the card says as much
rather than implying otherwise. Turning it off puts everything back.

## Making your own libraries

There is no API key and no model built in. You type what you want to learn,
the app builds a prompt, you paste it into whatever AI you already use, and
you bring the reply back — by pasting it or by importing a file. Bundled
decks use exactly the same JSON shape, so one parser handles both:

```json
{
  "deck": "Hiragana",
  "reversible": true,
  "cards": [
    { "front": "ね", "back": "ne", "hint": "Vertical spine, then a loop",
      "distractors": ["nu", "re", "wa"] }
  ]
}
```

Everything but `front` and `back` is optional.

- **`hint`** shows on the reveal, never with the question.
- **`distractors`** are wrong answers chosen because they are genuinely
  confusable. Written as wrong *backs*; asked the other way round each one
  is looked up and its front used instead, so the same confusion works in
  both directions. Without them, options are sampled from the deck.
- **`reversible: false`** marks a deck that only makes sense one way — a
  quiz rather than a vocabulary list. The app then stops offering the
  reverse direction, though it stays reachable.

Card order is learning order: new material opens from the top of the list.

Import checks two things a model gets wrong often, and says so rather than
letting you find out mid-session:

- **An answer that repeats its question** — a back like `"t - th tao ฏ"`
  reads fine forwards, but asked in reverse it becomes the prompt and
  hands over its own answer.
- **Answers shared by several cards** — a question can only offer as many
  choices as the deck has *distinct* answers, so a deck where ข, ค and ฆ
  are all `"kor"` ends up asking two- and three-choice questions.

Neither blocks the import. Pasting a corrected deck with the same name
offers to **replace** the existing one, swapping the content in and keeping
everything you have answered.

## Layout

```
lib/
  core/              pure logic, no Flutter imports in model/rules
    model.dart       Note, CardState, Library, Direction + JSON
    rules.dart       every tunable number, and the logic derived from it
    deck_import.dart parsing AI replies, and building the prompt
    session.dart     what to ask next, and what a session unlocks
    stats.dart       reading vs writing, and the weak list
    store.dart       persistence + bundled deck seeding
  ui/
    theme.dart       the one palette and type scale
    widgets.dart     shared pieces
    logo.dart        the mark, shared with the icon generator
    home_screen.dart           the library list
    settings_screen.dart       options, and the Pro card
    session_setup_screen.dart  length and direction
    session_screen.dart        ask, reveal, next
    results_view.dart          the end-of-session page
    mastery_grid.dart          the whole deck at a glance
    stats_screen.dart          progress and weak spots
    create_library_screen.dart the topic box and prompt
    import_screen.dart         paste or pick a file
tool/
  generate_icons.dart  redraws every launcher icon from logo.dart
assets/decks/        hiragana.json, katakana.json
design/project/      the screen mockups this was built from
test/                mirrors lib/
```

Both launcher icons — the everyday one and the Pro one — are generated,
never drawn by hand. Change `paintMark` in `lib/ui/logo.dart` and run:

```bash
flutter test tool/generate_icons.dart
```

`rules.dart` is the spec. If a progression rule is ever argued about, it is
settled there and nowhere else.

## Running it

```bash
flutter pub get
flutter test
flutter run
```

Android is the target. Web works and is the quicker loop while developing:

```bash
flutter run -d chrome
```

Windows desktop needs Visual Studio's "Desktop development with C++"
workload, which is not installed here — `flutter build windows` will fail
until it is.

## Status

| Phase | | |
|---|---|---|
| 1 | Shell and storage | **done** |
| 2 | The loop — question, options, reveal | **done** |
| 3 | Scoring and progression | **done** |
| 4 | Results and stats | **done** |
| 5 | Your own decks | **done** |

Phase 1 shipped the data model, local storage, the two bundled kana decks
and the library list. Phase 2 added session setup, the question/reveal loop,
distractor sampling and per-answer saving. Phase 3 made selection actually
hunt weak spots, spend review slots and unlock batches. Phase 4 added the
results grid, the reading/writing split and the needs-work list. Phase 5
added the prompt generator and deck import.

All five phases are in. What was parked along the way, and where it would
go:

- **Lookalike distractors as a difficulty knob** — `buildOptions` already
  prefers the ones a deck author wrote; nothing chooses to lean on them.
- **Bundled fonts** — the mockup used IBM Plex and Noto Sans JP; the app
  runs on system fonts. `pubspec.yaml` and `ui/theme.dart`.
- **Editing cards in the app** — today a deck is re-imported to change it.
- **Deck export** — `Library.toJson` already produces the shape the
  importer reads.
- **Streaks and reminders** — eyetrainer's `flutter_local_notifications`
  setup is the model.

Controls belonging to later phases are deliberately absent rather than
present and dead, so everything on screen works.

## Privacy

Weakspot collects nothing. It requests no internet permission and no
permissions that need your approval; everything it records stays on the
device. Full policy: <https://ebseca.github.io/weakspot/>

## Licence

GNU General Public License v3.0 — see [LICENSE](LICENSE).
