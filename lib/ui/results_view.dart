/// What a finished session actually taught you.
library;

import 'package:flutter/material.dart';

import '../core/model.dart';
import '../core/rules.dart';
import '../core/session.dart';
import 'card_detail.dart';
import 'mastery_grid.dart';
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
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Flexible(
                      child: SectionLabel('All ${library.notes.length} cards'),
                    ),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Text(
                        fullyUnlocked
                            ? 'tap to read'
                            : '${library.unlockedCount} unlocked',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Type.mono.copyWith(fontSize: 11),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                MasteryGrid(
                  library: library,
                  onTapNote: (note) => showCardDetail(
                    context,
                    library: library,
                    note: note,
                  ),
                ),
                const SizedBox(height: 16),
                BandLegend(includeLocked: !fullyUnlocked),
                const SizedBox(height: 8),
                Center(
                  child: TextButton(
                    onPressed: onStats,
                    style: TextButton.styleFrom(
                      foregroundColor: Palette.accent,
                      textStyle: const TextStyle(fontSize: 14),
                    ),
                    child: const Text('See weak spots'),
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
