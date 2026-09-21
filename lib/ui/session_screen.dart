/// The study loop: introduce, ask, reveal, next.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import '../core/model.dart';
import '../core/session.dart';
import '../core/store.dart';
import 'results_view.dart';
import 'stats_screen.dart';
import 'theme.dart';

/// Below this the layout switches to side-by-side, which is what a phone in
/// landscape hits.
const double _landscapeMaxHeight = 520;

class SessionScreen extends StatefulWidget {
  const SessionScreen({
    super.key,
    required this.library,
    required this.repository,
    required this.config,
    this.session,
  });

  final Library library;
  final LibraryRepository repository;
  final SessionConfig config;

  /// Injected by tests so questions are deterministic.
  final Session? session;

  @override
  State<SessionScreen> createState() => _SessionScreenState();
}

class _SessionScreenState extends State<SessionScreen> {
  late Session _session = widget.session ??
      Session(library: widget.library, config: widget.config);

  /// Ticks once a second in timed mode, and is cancelled everywhere else.
  Timer? _clock;
  Duration _remaining = Duration.zero;

  @override
  void initState() {
    super.initState();
    _startClock();
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  void _startClock() {
    _clock?.cancel();
    final duration = widget.config.duration;
    if (!widget.config.isTimed || duration == null) return;

    _remaining = duration;
    _clock = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      final left = _remaining - const Duration(seconds: 1);
      if (left <= Duration.zero) {
        _clock?.cancel();
        setState(() {
          _remaining = Duration.zero;
          _session.stop();
        });
        _persist();
        return;
      }
      setState(() => _remaining = left);
    });
  }

  /// Start again on the same deck and settings, carrying forward everything
  /// just learned. Rebuilding in place rather than pushing a route keeps
  /// the back stack honest.
  void _replay() {
    setState(() {
      _session = Session(library: _session.library, config: widget.config);
    });
    _startClock();
  }

  /// Saved after every answer, so quitting mid-session keeps progress.
  Future<void> _persist() => widget.repository.save(_session.library);

  void _submit(String option) {
    setState(() => _session.submit(option));
    _persist();
  }

  void _acknowledge() {
    setState(_session.acknowledgeIntroduction);
    _persist();
  }

  void _advance() => setState(_session.advance);

  void _finish() {
    _clock?.cancel();
    Navigator.of(context).pop(_session.library);
  }

  void _openStats() => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StatsScreen(library: _session.library),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _finish();
      },
      child: Scaffold(
        body: SafeArea(
          child: _session.isComplete
              ? ResultsView(
                  session: _session,
                  onDone: _finish,
                  onStats: _openStats,
                  onReplay: _replay,
                )
              : _Playing(
                  session: _session,
                  remaining: widget.config.isTimed ? _remaining : null,
                  onPick: _submit,
                  onNext: _advance,
                  onAcknowledge: _acknowledge,
                  onQuit: _finish,
                ),
        ),
      ),
    );
  }
}

class _Playing extends StatelessWidget {
  const _Playing({
    required this.session,
    required this.onPick,
    required this.onNext,
    required this.onAcknowledge,
    required this.onQuit,
    this.remaining,
  });

  final Session session;

  /// Time left in a timed run, or null in the other modes.
  final Duration? remaining;
  final ValueChanged<String> onPick;
  final VoidCallback onNext;
  final VoidCallback onAcknowledge;
  final VoidCallback onQuit;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final sideBySide = constraints.maxHeight < _landscapeMaxHeight &&
            constraints.maxWidth > constraints.maxHeight;

        final card = _PaperCard(
          question: session.current,
          revealed: session.isRevealing,
          introducing: session.isIntroducing,
        );

        final actions = session.isIntroducing
            ? _Introduction(onAcknowledge: onAcknowledge)
            : _Answers(
                session: session,
                onPick: onPick,
                onNext: onNext,
              );

        return Padding(
          padding: EdgeInsets.fromLTRB(22, 12, 22, sideBySide ? 14 : 22),
          child: Column(
            children: [
              _ProgressBar(
                position: session.position,
                total: session.config.length,
                remaining: remaining,
                duration: session.config.duration,
                onQuit: onQuit,
              ),
              SizedBox(height: sideBySide ? 10 : 16),
              if (sideBySide)
                Expanded(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(
                        flex: 5,
                        child: Column(
                          children: [
                            _StatusPill(session: session),
                            const SizedBox(height: 10),
                            Expanded(child: card),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        flex: 4,
                        child: SingleChildScrollView(child: actions),
                      ),
                    ],
                  ),
                )
              else ...[
                _StatusPill(session: session),
                const SizedBox(height: 16),
                Expanded(child: card),
                const SizedBox(height: 16),
                actions,
              ],
            ],
          ),
        );
      },
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({
    required this.position,
    required this.total,
    required this.onQuit,
    this.remaining,
    this.duration,
  });

  final int position;
  final int total;
  final VoidCallback onQuit;

  /// Set in timed mode: the bar fills as the clock runs down and the
  /// readout counts time rather than questions.
  final Duration? remaining;
  final Duration? duration;

  static String _clock(Duration d) {
    final seconds = d.inSeconds;
    return '${seconds ~/ 60}:${(seconds % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final left = remaining;
    final whole = duration;
    final timed = left != null && whole != null && whole > Duration.zero;

    // Under ten seconds the readout turns colour. Nothing else changes, so
    // it reads as urgency rather than as something having gone wrong.
    final urgent = timed && left.inSeconds <= 10;

    final progress = timed
        ? 1 - (left.inMilliseconds / whole.inMilliseconds)
        : (total == 0 ? 0.0 : (position - 1) / total);

    return Row(
      children: [
        IconButton(
          onPressed: onQuit,
          icon: const Icon(Icons.close, size: 20),
          color: Palette.dim,
          tooltip: 'End session',
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 5,
              backgroundColor: Palette.track,
              valueColor: AlwaysStoppedAnimation(
                urgent ? BandColor.struggling : Palette.accent,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          timed ? _clock(left) : '$position/$total',
          style: Type.mono.copyWith(
            fontSize: 13,
            color: urgent ? BandColor.struggling : Palette.dim,
            fontWeight: urgent ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
      ],
    );
  }
}

/// Direction while asking, "new card" while introducing, verdict once
/// answered.
class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final question = session.current;
    final way = question.direction == Direction.forward ? 'READING' : 'WRITING';
    // A review slot goes to a card you already know, so say so — otherwise
    // an easy card turning up mid-session looks like a bug.
    final asking = question.isReview ? 'REVIEW · $way' : way;

    final (label, color, background, border, icon) = switch (session) {
      _ when session.isIntroducing => (
          'NEW CARD',
          Palette.accent,
          Palette.accentPanel,
          Palette.accent,
          Icons.auto_awesome,
        ),
      _ when !session.isRevealing => (
          asking,
          Palette.dim,
          Palette.panel,
          Palette.line,
          null,
        ),
      _ when session.wasCorrect => (
          'CORRECT',
          BandColor.mastered,
          const Color(0xFF1E2A24),
          const Color(0xFF2F5244),
          Icons.check,
        ),
      _ => (
          'NOT QUITE',
          BandColor.struggling,
          const Color(0xFF2A1D1A),
          const Color(0xFF5A3328),
          Icons.close,
        ),
    };

    // Fixed height: the arrow is text and the verdict is an icon, and
    // letting the pill size to its content made everything below it shift
    // by a few pixels the moment you answered.
    return Container(
      height: 30,
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
          ] else ...[
            Text(
              session.current.direction == Direction.forward ? '→' : '←',
              style: const TextStyle(
                fontFamily: monoFamily,
                fontSize: 13,
                color: Palette.accent,
              ),
            ),
            const SizedBox(width: 7),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: monoFamily,
              fontSize: 11,
              letterSpacing: 1,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// The flashcard. Its box never changes size; only what is written on it
/// does.
class _PaperCard extends StatelessWidget {
  const _PaperCard({
    required this.question,
    required this.revealed,
    required this.introducing,
  });

  final Question question;
  final bool revealed;
  final bool introducing;

  /// Showing both sides — either being taught, or answered.
  bool get _bothSides => revealed || introducing;

  @override
  Widget build(BuildContext context) {
    final hint = question.hint;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Palette.paper,
        borderRadius: BorderRadius.circular(18),
      ),
      // One scroll view over everything: a long prompt wraps and scrolls
      // rather than shrinking into illegibility, and a short one still
      // sits centred.
      child: Center(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                question.prompt,
                textAlign: TextAlign.center,
                style: Type.glyph(Type.cardSizeFor(question.prompt)),
              ),
              if (_bothSides) ...[
                const SizedBox(height: 8),
                Text(
                  question.answer,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: monoFamily,
                    fontSize: Type.answerSizeFor(question.answer),
                    fontWeight: FontWeight.w500,
                    color: const Color(0xFF4A5060),
                  ),
                ),
                if (hint != null) ...[
                  const SizedBox(height: 12),
                  const Divider(height: 1, color: Palette.paperLine),
                  const SizedBox(height: 10),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.lightbulb_outline,
                            size: 15, color: Color(0xFF8A8577)),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(
                          hint,
                          style: const TextStyle(
                            fontSize: 13,
                            height: 1.5,
                            color: Palette.paperDim,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Shown the first time a card comes up, before it is ever scored.
class _Introduction extends StatelessWidget {
  const _Introduction({required this.onAcknowledge});

  final VoidCallback onAcknowledge;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text(
          "You haven't seen this one before. Take it in — it won't be "
          'scored until you have.',
          textAlign: TextAlign.center,
          style: Type.secondary,
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: onAcknowledge,
            child: const Text('Got it'),
          ),
        ),
      ],
    );
  }
}

/// The options, plus space for the Next button that is reserved whether or
/// not the button is showing — so answering never resizes anything above.
class _Answers extends StatelessWidget {
  const _Answers({
    required this.session,
    required this.onPick,
    required this.onNext,
  });

  final Session session;
  final ValueChanged<String> onPick;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final question = session.current;
    final revealing = session.isRevealing;
    final last = session.asked >= session.config.length;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < question.options.length; i++) ...[
          if (i > 0) const SizedBox(height: 9),
          _OptionButton(
            label: question.options[i],
            state: _stateFor(question, revealing, session.picked,
                question.options[i]),
            onTap: revealing ? null : () => onPick(question.options[i]),
          ),
        ],
        const SizedBox(height: 12),
        Visibility(
          visible: revealing,
          maintainSize: true,
          maintainAnimation: true,
          maintainState: true,
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onNext,
              child: Text(last ? 'See results' : 'Next'),
            ),
          ),
        ),
      ],
    );
  }

  static _OptionState _stateFor(
    Question question,
    bool revealing,
    String? picked,
    String option,
  ) {
    if (!revealing) return _OptionState.idle;
    if (option == question.answer) return _OptionState.correct;
    if (option == picked) return _OptionState.wrong;
    return _OptionState.dimmed;
  }
}

enum _OptionState { idle, correct, wrong, dimmed }

class _OptionButton extends StatelessWidget {
  const _OptionButton({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final (background, border, foreground, icon) = switch (state) {
      _OptionState.idle => (Palette.panel, Palette.line, Palette.text, null),
      _OptionState.correct => (
          const Color(0xFF1E2A24),
          BandColor.mastered,
          const Color(0xFF7FC9A2),
          Icons.check,
        ),
      _OptionState.wrong => (
          const Color(0xFF2A1D1A),
          BandColor.struggling,
          const Color(0xFFE08B5F),
          Icons.close,
        ),
      _OptionState.dimmed => (Palette.panel, Palette.line, Palette.faint, null),
    };

    return Semantics(
      button: true,
      enabled: onTap != null,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Container(
          width: double.infinity,
          constraints: const BoxConstraints(minHeight: 54),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(13),
            border: Border.all(color: border),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: border),
                const SizedBox(width: 9),
              ],
              Flexible(
                child: Text(
                  label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: state == _OptionState.idle
                        ? FontWeight.w500
                        : FontWeight.w600,
                    color: foreground,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
