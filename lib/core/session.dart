/// Running one study session.
///
/// Pure logic: chooses what to ask, builds distractors, records answers and
/// unlocks new material at the end. The screens above it only draw what
/// this exposes.
library;

import 'dart:math';

import 'model.dart';
import 'rules.dart';

/// Which way round questions are asked in a session.
enum DirectionMode {
  /// Front to back only. Reading.
  forward,

  /// Back to front only. Writing.
  reverse,

  /// Both, chosen per question.
  mixed;

  String get label => switch (this) {
        DirectionMode.forward => 'Character to sound',
        DirectionMode.reverse => 'Sound to character',
        DirectionMode.mixed => 'Mixed',
      };

  String get glyph => switch (this) {
        DirectionMode.forward => '→',
        DirectionMode.reverse => '←',
        DirectionMode.mixed => '⇄',
      };

  String get detail => switch (this) {
        DirectionMode.forward => 'Tests reading',
        DirectionMode.reverse => 'Tests writing',
        DirectionMode.mixed => 'Both, scored separately',
      };

  /// The directions this mode draws questions from.
  List<Direction> get directions => switch (this) {
        DirectionMode.forward => const [Direction.forward],
        DirectionMode.reverse => const [Direction.reverse],
        DirectionMode.mixed => Direction.values,
      };
}

/// One note seen from one direction — the thing that actually carries a
/// score, and therefore the thing the picker chooses between.
class CardRef {
  const CardRef(this.note, this.direction);

  final Note note;
  final Direction direction;

  String get key => cardKey(note.id, direction);

  @override
  bool operator ==(Object other) =>
      other is CardRef &&
      other.note.id == note.id &&
      other.direction == direction;

  @override
  int get hashCode => Object.hash(note.id, direction);
}

/// One card as a single run saw it.
///
/// Deliberately not the card's stored record: the results page reports
/// what just happened, which is a different question from how well the
/// card is known overall. A card answered twice here shows two marks even
/// if it has a hundred behind it.
class RunCard {
  RunCard({required this.note, required this.direction});

  final Note note;
  final Direction direction;

  /// Every answer in this run, in order.
  final List<bool> answers = [];

  int get asked => answers.length;

  int get correct => answers.where((a) => a).length;

  double get winRate => asked == 0 ? 0 : correct / asked;

  String get prompt => note.prompt(direction);

  String get answer => note.answer(direction);
}

/// How a session chooses what to ask and when to stop.
enum GameMode {
  /// Hunts your weak spots over a fixed number of questions. The default,
  /// and what the rest of the app is built around.
  practice,

  /// The same hunting, but against a clock instead of a question count —
  /// answer as many as you can before time runs out.
  timed,

  /// Straight shuffle. No targeting, no review slots, nothing held back.
  random;

  String get label => switch (this) {
        GameMode.practice => 'Practice',
        GameMode.timed => 'Timed',
        GameMode.random => 'Random',
      };

  String get detail => switch (this) {
        GameMode.practice => 'Drills whatever you are worst at',
        GameMode.timed => 'Same drilling, against the clock',
        GameMode.random => 'Straight shuffle, no targeting',
      };

  /// Whether this mode ends on the clock rather than a question count.
  bool get isTimed => this == GameMode.timed;
}

/// What the player chose before starting.
class SessionConfig {
  const SessionConfig({
    required this.length,
    required this.mode,
    this.game = GameMode.practice,
    this.duration,
    this.options = optionCount,
    this.poolTarget = unmasteredTarget,
  });

  /// Questions to ask. Ignored by [GameMode.timed], which runs on
  /// [duration] instead.
  final int length;

  final DirectionMode mode;

  final GameMode game;

  /// How long a timed run lasts. Null for the other modes.
  final Duration? duration;

  /// How many choices a question shows. Defaults to [optionCount]; the
  /// difficulty setting is what moves it.
  final int options;

  /// Unmastered cards to hold in play. Defaults to [unmasteredTarget];
  /// the pacing setting is what moves it.
  final int poolTarget;

  bool get isTimed => game.isTimed;
}

/// One question as shown on screen.
class Question {
  const Question({
    required this.note,
    required this.direction,
    required this.options,
    this.isReview = false,
  });

  final Note note;
  final Direction direction;

  /// Every option, shuffled. Always contains [answer].
  final List<String> options;

  /// True when this slot went to an already-mastered card rather than a
  /// weak one, so the screen can explain why an easy card turned up.
  final bool isReview;

  String get prompt => note.prompt(direction);

  String get answer => note.answer(direction);

  /// Shown only after answering.
  String? get hint => note.hint;
}

/// Every card the session is allowed to ask, given its direction mode.
List<CardRef> candidateCards(Library library, DirectionMode mode) => [
      for (final note in library.unlocked)
        for (final direction in mode.directions) CardRef(note, direction),
    ];

/// Pick one of the weakest cards at random.
///
/// "Weakest" is a band, not a single card: everything within
/// [selectionBand] of the lowest win rate, widened to at least
/// [minSelectionCandidates] so the picker is not cornered into repeating
/// the card just asked. Untested cards sit at a win rate of zero, so newly
/// unlocked material is introduced before anything else.
CardRef pickWeakest({
  required Library library,
  required List<CardRef> candidates,
  required Random random,
  CardRef? avoid,
}) {
  assert(candidates.isNotEmpty, 'no cards to choose between');

  final ranked = [...candidates]..sort((a, b) {
      final byRate = library
          .stateOf(a.note.id, a.direction)
          .winRate
          .compareTo(library.stateOf(b.note.id, b.direction).winRate);
      if (byRate != 0) return byRate;
      // Stable, deck-order tiebreak so the sort does not depend on the
      // platform's sort stability.
      return a.key.compareTo(b.key);
    });

  final worstRate = library
      .stateOf(ranked.first.note.id, ranked.first.direction)
      .winRate;

  final band = ranked
      .where((c) =>
          library.stateOf(c.note.id, c.direction).winRate <=
          worstRate + selectionBand)
      .toList();

  // Widen to a workable number of choices when one card is far worse.
  final pool = band.length >= minSelectionCandidates
      ? band
      : ranked.take(min(minSelectionCandidates, ranked.length)).toList();

  return _chooseAvoiding(pool, random, avoid);
}

/// Pick any card at random, ignoring how well it is known.
///
/// What [GameMode.random] runs on: a straight shuffle, with only the
/// just-asked card avoided so nothing repeats back to back.
CardRef pickAny({
  required List<CardRef> candidates,
  required Random random,
  CardRef? avoid,
}) {
  assert(candidates.isNotEmpty, 'no cards to choose between');
  return _chooseAvoiding(candidates, random, avoid);
}

/// Pick a mastered card at random, or null when there are none.
CardRef? pickMastered({
  required Library library,
  required List<CardRef> candidates,
  required Random random,
  CardRef? avoid,
}) {
  final mastered = candidates
      .where((c) =>
          bandForCard(library.stateOf(c.note.id, c.direction)) ==
          Band.mastered)
      .toList();

  // When the only mastered card is the one just asked, give the slot up
  // rather than repeat it — a weak card is a better use of the question.
  final usable =
      avoid == null ? mastered : mastered.where((c) => c != avoid).toList();
  if (usable.isEmpty) return null;

  return usable[random.nextInt(usable.length)];
}

/// Choose at random, skipping [avoid] when anything else is available.
CardRef _chooseAvoiding(List<CardRef> pool, Random random, CardRef? avoid) {
  final usable = pool.length > 1 && avoid != null
      ? pool.where((c) => c != avoid).toList()
      : pool;
  final from = usable.isEmpty ? pool : usable;
  return from[random.nextInt(from.length)];
}

/// A session in progress.
///
/// Holds the library it is mutating, so the screen can save it as it goes.
class Session {
  Session({
    required Library library,
    required SessionConfig config,
    Random? random,
        // Not `this.config`: the pool has to be topped up to the size the
        // config asks for, and an initialising formal is not in scope for
        // the initialiser beside it.
        // ignore: prefer_initializing_formals
  })  : config = config,
        _random = random ?? Random(),
        _poolAtStart = Set.unmodifiable(library.unlockedIds),
        _library = topUpPool(library, target: config.poolTarget) {
    _reviewSlots = _chooseReviewSlots();
    _current = _build();
  }

  final SessionConfig config;
  final Random _random;

  Library _library;
  final Set<String> _poolAtStart;
  late final Set<int> _reviewSlots;

  Question? _current;
  CardRef? _lastAsked;
  String? _picked;
  bool _awaitingIntroduction = false;
  int _asked = 0;
  int _correct = 0;
  int _introduced = 0;

  /// What this run has asked, keyed by card, in first-asked order.
  final Map<String, RunCard> _run = {};

  /// The library including every answer recorded so far.
  Library get library => _library;

  /// Questions answered.
  int get asked => _asked;

  int get correct => _correct;

  /// One-based position of the question on screen, for "7/20". A timed
  /// run has no ceiling, so it just counts up.
  int get position =>
      config.isTimed ? _asked + 1 : (_asked + 1).clamp(1, config.length);

  bool get isComplete => _current == null;

  /// True while a card the player has never seen is being shown to them,
  /// before it is asked. Introductions are not scored and do not use up a
  /// question.
  bool get isIntroducing => _awaitingIntroduction && _current != null;

  /// How many cards this session introduced.
  int get introduced => _introduced;

  /// True once an option has been picked and the answer is showing.
  bool get isRevealing => _picked != null;

  /// The option the player picked, or null while still asking.
  String? get picked => _picked;

  bool get wasCorrect => _picked != null && _picked == _current?.answer;

  /// Notes this session has opened so far.
  ///
  /// Live rather than end-of-session: material now arrives the moment it is
  /// earned, so the count can grow while you are still playing.
  List<Note> get newlyUnlocked => _library.notes
      .where((note) =>
          _library.isUnlocked(note.id) && !_poolAtStart.contains(note.id))
      .toList(growable: false);

  /// How many notes were in play before this session started.
  int get poolAtStart => _poolAtStart.length;

  /// Every card this run asked, worst first.
  ///
  /// Worst first because the results page is a to-do list, not a
  /// scoreboard: what you dropped belongs at the top where it is read,
  /// not buried under the ones you got right. Cards tied on win rate keep
  /// the order they were first asked in, so the page is stable.
  List<RunCard> get runCards {
    final cards = _run.values.toList();
    final order = {
      for (var i = 0; i < cards.length; i++) cards[i]: i,
    };
    cards.sort((a, b) {
      final byRate = a.winRate.compareTo(b.winRate);
      if (byRate != 0) return byRate;
      return order[a]!.compareTo(order[b]!);
    });
    return List.unmodifiable(cards);
  }

  /// Cards this run got wrong at least once.
  int get shakyCount =>
      _run.values.where((card) => card.correct < card.asked).length;

  Question get current {
    final question = _current;
    if (question == null) {
      throw StateError('The session is over; check isComplete first.');
    }
    return question;
  }

  /// Dismiss the introduction so the card can be asked.
  ///
  /// Marks the card as shown, which persists — so quitting between the
  /// introduction and the answer does not introduce it twice.
  void acknowledgeIntroduction() {
    if (!isIntroducing) return;

    final question = _current!;
    _library = _library.introducing(question.note.id, question.direction);
    _awaitingIntroduction = false;
    _introduced += 1;
  }

  /// Record an answer and switch to the reveal. Ignored while revealing,
  /// and while a card is still being introduced.
  void submit(String option) {
    if (_current == null || _picked != null || _awaitingIntroduction) return;

    final question = _current!;
    final right = option == question.answer;
    _picked = option;
    _asked += 1;
    if (right) _correct += 1;

    _run
        .putIfAbsent(
          cardKey(question.note.id, question.direction),
          () => RunCard(note: question.note, direction: question.direction),
        )
        .answers
        .add(right);

    _library = _library.recording(question.note.id, question.direction, right);
    // Mastering something opens the next card straight away, so the pool
    // never runs dry mid-session and quitting early costs nothing.
    _library = topUpPool(_library, target: config.poolTarget);
  }

  /// End a timed run because the clock ran out.
  ///
  /// Anything mid-reveal is kept: the answer was already recorded, so
  /// stopping here costs nothing.
  void stop() {
    _picked = null;
    _current = null;
  }

  /// Move to the next question, or end the session. Ignored while asking.
  void advance() {
    if (_picked == null) return;
    _picked = null;

    // A timed run stops on the clock, never on a count.
    if (!config.isTimed && _asked >= config.length) {
      _current = null;
      return;
    }
    _current = _build();
  }

  /// Which question numbers go to a mastered card rather than a weak one.
  ///
  /// Only practice can plan them out in advance, because only practice
  /// knows how many questions there will be.
  Set<int> _chooseReviewSlots() {
    if (config.game != GameMode.practice) return const {};
    final count = reviewSlotsFor(config.length);
    if (count <= 0) return const {};
    final positions = List.generate(config.length, (i) => i)
      ..shuffle(_random);
    return positions.take(count).toSet();
  }

  /// Whether this question should go to something already mastered.
  bool _wantsReview() => switch (config.game) {
        GameMode.practice => _reviewSlots.contains(_asked),
        // No fixed count to spread them over, so roll for it instead.
        GameMode.timed => _random.nextDouble() < reviewSlotShare,
        // A shuffle has no notion of saving anything from rotting.
        GameMode.random => false,
      };

  Question? _build() {
    final candidates = candidateCards(_library, config.mode);
    if (candidates.isEmpty) return null;

    final reviewPick = _wantsReview()
        ? pickMastered(
            library: _library,
            candidates: candidates,
            random: _random,
            avoid: _lastAsked,
          )
        : null;

    // A review slot falls back to a weak card when nothing is mastered yet.
    final choice = reviewPick ??
        (config.game == GameMode.random
            ? pickAny(
                candidates: candidates,
                random: _random,
                avoid: _lastAsked,
              )
            : pickWeakest(
                library: _library,
                candidates: candidates,
                random: _random,
                avoid: _lastAsked,
              ));

    _lastAsked = choice;
    _awaitingIntroduction =
        _library.needsIntroduction(choice.note.id, choice.direction);

    return Question(
      note: choice.note,
      direction: choice.direction,
      isReview: reviewPick != null,
      options: buildOptions(
        library: _library,
        note: choice.note,
        direction: choice.direction,
        random: _random,
        count: config.options,
      ),
    );
  }
}

/// The answer plus up to [count] - 1 wrong options, shuffled.
///
/// Distractors the deck author supplied are preferred, because they were
/// chosen to be genuinely confusable. They are written as wrong *backs*
/// ("nu" for ね), so for a reverse question each one is looked up as a note
/// and that note's front is used instead — the same confusion, the right
/// way round. Anything still missing is sampled from the rest of the deck.
List<String> buildOptions({
  required Library library,
  required Note note,
  required Direction direction,
  required Random random,
  int count = optionCount,
}) {
  final answer = note.answer(direction);
  final options = <String>{answer};

  final byBack = {for (final n in library.notes) n.back: n};

  for (final distractor in note.distractors) {
    if (options.length >= count) break;
    final source = byBack[distractor];
    if (source == null || source.id == note.id) continue;
    options.add(source.answer(direction));
  }

  if (options.length < count) {
    // Prefer unlocked notes so options stay inside what the player has
    // seen; fall back to the whole deck for a pool too small to fill four
    // slots.
    for (final source in [
      ..._shuffled(library.unlocked.toList(), random),
      ..._shuffled(library.notes, random),
    ]) {
      if (options.length >= count) break;
      if (source.id == note.id) continue;
      options.add(source.answer(direction));
    }
  }

  return _shuffled(options.toList(), random);
}

List<T> _shuffled<T>(List<T> items, Random random) {
  final copy = List<T>.of(items);
  copy.shuffle(random);
  return copy;
}
