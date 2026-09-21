/// What a finished session actually taught you.
library;

import 'package:flutter/material.dart';

import '../core/model.dart';
import '../core/rules.dart';
import '../core/session.dart';
import 'card_detail.dart';
import 'theme.dart';
import 'widgets.dart';

class ResultsView extends StatelessWidget {
  const ResultsView({
    super.key,
    required this.session,
    required this.onDone,
    required this.onStats,
    required this.onReplay,
  });

  final Session session;
  final VoidCallback onDone;
  final VoidCallback onStats;
  final VoidCallback onReplay;

  @override
  Widget build(BuildContext context) {
    final library = session.library;
    final fullyUnlocked = library.unlockedCount >= library.notes.length;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          _Header(session: session),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 18),
              children: [
                if (session.newlyUnlocked.isNotEmpty) ...[
                  _Unlocked(notes: session.newlyUnlocked),
                  const SizedBox(height: 16),
                ] else if (!fullyUnlocked) ...[
                  _PoolStatus(library: library),
                  const SizedBox(height: 16),
                ],
                _RunHeading(session: session),
                const SizedBox(height: 10),
                _RunList(session: session),
                const SizedBox(height: 14),
                Center(
                  child: TextButton(
                    onPressed: onStats,
                    style: TextButton.styleFrom(
                      foregroundColor: Palette.accent,
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                    child: const Text('See the whole deck'),
                  ),
                ),
              ],
            ),
          ),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: onDone,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(54),
                    foregroundColor: Palette.text,
                    side: const BorderSide(color: Palette.line),
                    backgroundColor: Palette.panel,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(13),
                    ),
                    textStyle: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w600),
                  ),
                  child: const Text('Done'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: onReplay,
                  child: const Text('Play again'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final score = session.correct;
    final total = session.asked;
    final rate = total == 0 ? 0.0 : score / total;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SectionLabel('Session complete'),
              const SizedBox(height: 4),
              Text(
                '${session.library.name} · '
                // Practice is the default, so naming it adds nothing.
                '${session.config.game == GameMode.practice ? '' : '${session.config.game.label.toLowerCase()} · '}'
                '${session.config.mode.label.toLowerCase()}',
                style: const TextStyle(
                  fontSize: 19,
                  fontWeight: FontWeight.w600,
                  color: Palette.text,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.baseline,
          textBaseline: TextBaseline.alphabetic,
          children: [
            Text(
              '$score',
              style: TextStyle(
                fontFamily: monoFamily,
                fontSize: 32,
                fontWeight: FontWeight.w600,
                color: BandColor.of(bandForRate(rate)),
              ),
            ),
            Text(
              '/$total',
              style: const TextStyle(
                fontFamily: monoFamily,
                fontSize: 17,
                color: Palette.dim,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// What is still in play, and what is waiting.
///
/// The app keeps [unmasteredTarget] unmastered cards open at a time, so
/// this is the honest answer to "why haven't I got more yet": you still
/// have these to finish.
class _PoolStatus extends StatelessWidget {
  const _PoolStatus({required this.library});

  final Library library;

  @override
  Widget build(BuildContext context) {
    final working = unmasteredCount(library);
    final locked = lockedCount(library);

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: Palette.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Still working on',
                  style: Type.body.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              Text(
                '$working ${working == 1 ? 'card' : 'cards'}',
                style: const TextStyle(
                  fontFamily: monoFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BandColor.learning,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Master one and the next of the $locked still locked opens '
            'straight away.',
            style: Type.secondary,
          ),
        ],
      ),
    );
  }
}

/// What clearing the batch opened up.
class _Unlocked extends StatelessWidget {
  const _Unlocked({required this.notes});

  final List<Note> notes;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: const Color(0xFF1E2A24),
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: const Color(0xFF2F5244)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_open, size: 15, color: BandColor.mastered),
              const SizedBox(width: 8),
              Text(
                '${notes.length} new '
                '${notes.length == 1 ? 'card' : 'cards'} unlocked',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF7FC9A2),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              for (final note in notes)
                Text(
                  note.front,
                  style: const TextStyle(fontSize: 26, color: Palette.text),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The heading over the run list.
///
/// Reports this run, not the deck: the whole-deck picture is one tap away
/// on the stats screen, and repeating it here meant the page you saw after
/// every single session was the same page, whatever you had just done.
class _RunHeading extends StatelessWidget {
  const _RunHeading({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final cards = session.runCards.length;
    final shaky = session.shakyCount;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        const Flexible(child: SectionLabel('This run')),
        const SizedBox(width: 10),
        Flexible(
          child: Text(
            cards == 0
                ? 'nothing answered'
                : shaky == 0
                    ? '$cards ${cards == 1 ? 'card' : 'cards'} · all clean'
                    : '$cards ${cards == 1 ? 'card' : 'cards'} · '
                        '$shaky to work on',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.right,
            style: Type.mono.copyWith(
              fontSize: 11,
              color: shaky == 0 ? BandColor.mastered : BandColor.struggling,
            ),
          ),
        ),
      ],
    );
  }
}

/// Every card this run asked, worst first.
class _RunList extends StatelessWidget {
  const _RunList({required this.session});

  final Session session;

  @override
  Widget build(BuildContext context) {
    final cards = session.runCards;

    if (cards.isEmpty) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
        decoration: BoxDecoration(
          color: Palette.panel,
          borderRadius: BorderRadius.circular(13),
          border: Border.all(color: Palette.line),
        ),
        child: Text(
          session.introduced > 0
              ? 'Cards were shown but none were answered.'
              : 'Nothing was answered this run.',
          style: Type.secondary,
          textAlign: TextAlign.center,
        ),
      );
    }

    return Column(
      children: [
        for (var i = 0; i < cards.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          _RunRow(
            card: cards[i],
            onTap: () => showCardDetail(
              context,
              library: session.library,
              note: cards[i].note,
            ),
          ),
        ],
      ],
    );
  }
}

class _RunRow extends StatelessWidget {
  const _RunRow({required this.card, required this.onTap});

  final RunCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final band = bandForRate(card.winRate);

    return Semantics(
      button: true,
      label: '${card.prompt} to ${card.answer}, '
          '${card.correct} of ${card.asked} correct this run',
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.fromLTRB(14, 11, 14, 11),
          decoration: BoxDecoration(
            color: Palette.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.line),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 16,
                child: Text(
                  card.direction == Direction.forward ? '→' : '←',
                  style: const TextStyle(
                    fontFamily: monoFamily,
                    fontSize: 14,
                    color: Palette.faint,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      card.prompt,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: Palette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      card.answer,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Type.secondary,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              _RunDots(answers: card.answers),
              const SizedBox(width: 10),
              Text(
                '${card.correct}/${card.asked}',
                style: TextStyle(
                  fontFamily: monoFamily,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: BandColor.of(band),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// This run's answers as dots, in the order they happened.
///
/// Capped, because a timed run can hammer one card a dozen times and the
/// row still has to fit a phone. The tally beside it stays exact.
class _RunDots extends StatelessWidget {
  const _RunDots({required this.answers});

  final List<bool> answers;

  static const int _max = 6;

  @override
  Widget build(BuildContext context) {
    final shown = answers.length <= _max
        ? answers
        : answers.sublist(answers.length - _max);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (answers.length > _max)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Text('+${answers.length - _max}',
                style: Type.mono.copyWith(fontSize: 10)),
          ),
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              color:
                  shown[i] ? BandColor.mastered : BandColor.struggling,
              borderRadius: BorderRadius.circular(3.5),
            ),
          ),
        ],
      ],
    );
  }
}
