/// Turning an AI's reply into notes, forgivingly and loudly.
///
/// The player pastes whatever came back from whatever model they used, so
/// this has to cope with markdown fences, a sentence of preamble, and cards
/// that are missing fields — and when it drops something it has to say
/// exactly which card and why.
library;

import 'dart:convert';

import 'model.dart';

/// What came out of a paste, including what had to be thrown away.
class DeckParseResult {
  const DeckParseResult({
    required this.deckName,
    required this.notes,
    this.problems = const [],
    this.fatal,
    this.reversible = true,
  });

  /// Name the reply gave the deck, or a fallback.
  final String deckName;

  /// Whether the reply said this deck makes sense asked backwards.
  ///
  /// Defaults to true, so a reply that says nothing behaves as decks
  /// always have.
  final bool reversible;

  /// Cards that survived validation, in reply order.
  final List<Note> notes;

  /// Per-card complaints, each naming the card and what was wrong.
  final List<String> problems;

  /// Set when nothing could be read at all. [notes] is empty.
  final String? fatal;

  bool get isUsable => fatal == null && notes.isNotEmpty;

  int get skipped => problems.length;

  /// Cards carrying a memory aid.
  int get withHints => notes.where((n) => n.hint != null).length;


  /// Cards whose wrong answers the author chose deliberately.
  int get withDistractors =>
      notes.where((n) => n.distractors.isNotEmpty).length;

  /// Answers that more than one card shares, in first-seen order.
  ///
  /// Not an error — Thai romanises ข, ค and ฆ all as "kor", and both cards
  /// are real. But a question can only offer as many choices as the deck
  /// has distinct answers, so a deck full of repeats ends up asking two-
  /// and three-choice questions. Worth saying out loud at import rather
  /// than leaving it to be noticed mid-session.
  List<String> get duplicateAnswers {
    final counts = <String, int>{};
    for (final note in notes) {
      counts[note.back] = (counts[note.back] ?? 0) + 1;
    }
    final seen = <String>[];
    for (final note in notes) {
      if (counts[note.back]! > 1 && !seen.contains(note.back)) {
        seen.add(note.back);
      }
    }
    return seen;
  }

  /// How many distinct answers the deck has, which caps how many options a
  /// question can show.
  int get distinctAnswers => notes.map((n) => n.back).toSet().length;

  /// Cards whose answer contains the question.
  ///
  /// A back like "t - th tao ฏ" reads fine going forwards, where the
  /// character is already on screen. Asked backwards it becomes the
  /// prompt — and hands over its own answer. Free marks, and a card that
  /// can never be practised the other way round.
  List<Note> get selfAnswering =>
      notes.where((n) => answerLeaksInto(n.front, n.back)).toList();

  /// A [Library] ready to store. Nothing is unlocked yet — the first
  /// session opens the pool.
  Library toLibrary({required String id, bool bundled = false}) => Library(
        id: id,
        name: deckName,
        notes: notes,
        bundled: bundled,
        reversible: reversible,
      );
}

/// Whether [back] gives away [front].
///
/// A single ASCII letter is ignored: "a" turning up inside "apple" is a
/// coincidence, not a leak. Anything longer, or anything outside ASCII —
/// a kana, a Thai consonant — is the real thing.
bool answerLeaksInto(String front, String back) {
  final needle = front.trim();
  if (needle.isEmpty || needle == back.trim()) return false;

  final trivial = needle.runes.length == 1 && needle.codeUnitAt(0) < 128;
  if (trivial) return false;

  return back.toLowerCase().contains(needle.toLowerCase());
}

/// Pull a deck out of [raw], which may be a bare JSON object, a fenced code
/// block, or JSON with chatter around it.
DeckParseResult parseDeck(String raw, {String fallbackName = 'Untitled'}) {
  final text = _extractJsonObject(raw);
  if (text == null) {
    return DeckParseResult(
      deckName: fallbackName,
      notes: const [],
      fatal: "Couldn't find any JSON in that. Copy the whole reply, "
          'including the opening { and closing }.',
    );
  }

  final Object? decoded;
  try {
    decoded = jsonDecode(text);
  } on FormatException catch (e) {
    return DeckParseResult(
      deckName: fallbackName,
      notes: const [],
      fatal: 'That JSON is malformed — ${e.message}. Ask the model to '
          'resend it with no commentary.',
    );
  }

  if (decoded is! Map) {
    return DeckParseResult(
      deckName: fallbackName,
      notes: const [],
      fatal: 'Expected a JSON object with a "cards" list.',
    );
  }

  final json = Map<String, dynamic>.from(decoded);
  final rawCards = json['cards'];
  if (rawCards is! List) {
    return DeckParseResult(
      deckName: fallbackName,
      notes: const [],
      fatal: 'No "cards" list in that reply.',
    );
  }

  final deckName = (json['deck'] as String?)?.trim();
  final notes = <Note>[];
  final problems = <String>[];
  final seenFronts = <String, int>{};

  for (var i = 0; i < rawCards.length; i++) {
    final position = i + 1;
    final entry = rawCards[i];
    if (entry is! Map) {
      problems.add('Card $position is not an object.');
      continue;
    }

    final note = Note.fromJson(Map<String, dynamic>.from(entry));

    if (note.front.isEmpty) {
      problems.add('Card $position has no "front".');
      continue;
    }
    if (note.back.isEmpty) {
      problems.add('Card $position ("${_clip(note.front)}") has no "back".');
      continue;
    }

    final firstSeen = seenFronts[note.front];
    if (firstSeen != null) {
      problems.add(
        'Card $position repeats the front "${_clip(note.front)}" '
        'already used by card $firstSeen.',
      );
      continue;
    }

    seenFronts[note.front] = position;
    notes.add(note);
  }

  if (notes.isEmpty) {
    return DeckParseResult(
      deckName: deckName?.isNotEmpty == true ? deckName! : fallbackName,
      notes: const [],
      problems: problems,
      fatal: 'None of the ${rawCards.length} cards in that reply were usable.',
    );
  }

  return DeckParseResult(
    deckName: deckName?.isNotEmpty == true ? deckName! : fallbackName,
    notes: List.unmodifiable(notes),
    problems: List.unmodifiable(problems),
    reversible: json['reversible'] != false,
  );
}

/// Find the outermost `{...}` in [raw], ignoring fences and prose.
String? _extractJsonObject(String raw) {
  var text = raw.trim();
  if (text.isEmpty) return null;

  // ```json ... ``` or ``` ... ```
  if (text.startsWith('```')) {
    final firstBreak = text.indexOf('\n');
    if (firstBreak != -1) {
      text = text.substring(firstBreak + 1);
    }
    final closing = text.lastIndexOf('```');
    if (closing != -1) {
      text = text.substring(0, closing);
    }
    text = text.trim();
  }

  final start = text.indexOf('{');
  final end = text.lastIndexOf('}');
  if (start == -1 || end == -1 || end <= start) return null;
  return text.substring(start, end + 1);
}

String _clip(String value) =>
    value.length <= 18 ? value : '${value.substring(0, 17)}…';

/// Build the prompt the player copies into whatever AI they use.
///
/// Kept beside the parser on purpose: the shape asked for here and the
/// shape accepted there must not drift apart.
String buildDeckPrompt(String topic) {
  final cleaned = topic.trim().isEmpty ? '[what you want to learn]' : topic.trim();
  return '''
You are helping build a flashcard deck.

Topic: $cleaned

Produce the COMPLETE natural set for this topic. If the topic has no
naturally bounded set, produce the 20-30 most useful items.

Reply with ONLY this JSON. No commentary, no markdown fences:

{
  "deck": "<short name>",
  "reversible": true,
  "cards": [
    {
      "front": "<prompt side>",
      "back":  "<answer side>",
      "hint":  "<optional memory aid>",
      "distractors": ["<wrong>", "<wrong>"]
    }
  ]
}

Rules:
- front and back stay short. Prefer a word or phrase to a sentence.
- hint is optional. Use it only for look-alikes that are easy to confuse.
- distractors are optional. Include them only when a specific wrong answer
  is genuinely confusable with the right one.
- keep every "back" distinct from every other. Two cards with the same
  answer cannot both be offered as choices, so repeats leave questions
  with fewer options. Disambiguate instead: "kor (egg)", "kor (buffalo)".
- never put the front inside the back. "t - th tao" is fine; "t - th tao
  [the character]" is not, because asked in reverse that card shows its
  own answer in the question.
- reversible says whether asking the card backwards makes sense. A
  vocabulary list is reversible. A quiz — "what does X do?" — is not; set
  it to false so the app does not ask nonsense questions.
- Order the cards the way they should be learned. New material is opened
  from the top of the list as earlier cards are mastered.
''';
}
