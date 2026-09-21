/// Where a library actually stands: reading against writing, and the
/// cards that need work.
library;

import 'package:flutter/material.dart';

import '../core/model.dart';
import '../core/rules.dart';
import '../core/stats.dart';
import '../core/store.dart';
import 'card_detail.dart';
import 'mastery_grid.dart';
import 'theme.dart';
import 'widgets.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key, required this.library, this.repository});

  final Library library;

  /// Given only where changing the library is safe — from a deck's setup
  /// screen, not from the results of a session still holding its own copy.
  /// Without it the screen is read-only and the unlock control is hidden.
  final LibraryRepository? repository;

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  late Library _library = widget.library;

  Future<void> _apply(Library next) async {
    if (next.unlockedCount == _library.unlockedCount) return;
    setState(() => _library = next);
    await widget.repository?.save(_library);
  }

  Future<void> _openMore() => _apply(openNextBatch(_library));

  Future<void> _openCard(Note note) =>
      _apply(unlockNote(_library, note.id));

  void _showCard(Note note) => showCardDetail(
        context,
        library: _library,
        note: note,
        onUnlock: widget.repository == null || _library.isUnlocked(note.id)
            ? null
            : () => _openCard(note),
      );

  @override
  Widget build(BuildContext context) {
    final library = _library;
    final answers = totalAnswers(library);
    final weak = weakestCards(library);
    final locked = lockedCount(library);
    final canOpenMore = widget.repository != null && locked > 0;

    // A one-way deck has no writing score worth showing.
    final directions = directionStats(library)
        .where((s) => library.reversible || s.direction == Direction.forward)
        .toList();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_library);
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 22),
                TopBar(
                  title: library.name,
                  subtitle: '${answers == 0 ? 'Nothing recorded yet' : '$answers '
                      '${answers == 1 ? 'answer' : 'answers'} recorded'} · '
                      '${library.unlockedCount} of ${library.notes.length} '
                      'unlocked',
                  onBack: () => Navigator.of(context).pop(_library),
                ),
                const SizedBox(height: 22),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 26),
                    children: [
                      if (answers > 0) ...[
                        const SectionLabel('By direction'),
                        const SizedBox(height: 11),
                        for (final stats in directions) ...[
                          _DirectionCard(stats: stats),
                          const SizedBox(height: 10),
                        ],
                        const SizedBox(height: 14),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.baseline,
                          textBaseline: TextBaseline.alphabetic,
                          children: [
                            const SectionLabel('Needs work'),
                            Text('last $historyWindow answers',
                                style: Type.mono.copyWith(fontSize: 11)),
                          ],
                        ),
                        const SizedBox(height: 4),
                        if (weak.isEmpty)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              'Nothing weak right now. Everything you have '
                              'answered is at 90% or better.',
                              style: Type.secondary,
                            ),
                          )
                        else
                          for (final card in weak)
                            _WeakRow(
                              card: card,
                              onTap: () => _showCard(card.note),
                            ),
                        const SizedBox(height: 26),
                      ] else
                        const Padding(
                          padding: EdgeInsets.only(bottom: 26),
                          child: Text(
                            'Play a session and your weak spots will show up '
                            'here.',
                            style: Type.secondary,
                          ),
                        ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          SectionLabel('All ${library.notes.length} cards'),
                          Text('tap one to read it',
                              style: Type.mono.copyWith(fontSize: 11)),
                        ],
                      ),
                      const SizedBox(height: 10),
                      MasteryGrid(library: library, onTapNote: _showCard),
                      const SizedBox(height: 16),
                      BandLegend(includeLocked: locked > 0),
                      if (canOpenMore) ...[
                        const SizedBox(height: 22),
                        _OpenMore(locked: locked, onTap: _openMore),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Skip the pacing and open more cards now.
class _OpenMore extends StatelessWidget {
  const _OpenMore({required this.locked, required this.onTap});

  final int locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final count = locked < batchSize ? locked : batchSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: onTap,
          icon: const Icon(Icons.lock_open, size: 17),
          label: Text('Open $count more ${count == 1 ? 'card' : 'cards'}'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            foregroundColor: Palette.text,
            backgroundColor: Palette.panel,
            side: const BorderSide(color: Palette.line),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Cards normally open on their own as you master what is already '
          'in play. This jumps ahead.',
          style: Type.secondary,
        ),
      ],
    );
  }
}

/// Reading or writing, with its accuracy.
///
/// Shown separately because they are separate skills — a strong reading
/// score hiding a weak writing score is exactly what this screen exists to
/// prevent.
class _DirectionCard extends StatelessWidget {
  const _DirectionCard({required this.stats});

  final DirectionStats stats;

  @override
  Widget build(BuildContext context) {
    final colour = stats.hasData
        ? BandColor.of(bandForRate(stats.accuracy))
        : Palette.faint;

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
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(stats.glyph,
                  style: const TextStyle(
                      fontFamily: monoFamily,
                      fontSize: 15,
                      color: Palette.accent)),
              const SizedBox(width: 9),
              Expanded(
                child: Text(stats.name,
                    style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: Palette.text)),
              ),
              Text(
                stats.hasData ? '${stats.percent}%' : '—',
                style: TextStyle(
                  fontFamily: monoFamily,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: colour,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: stats.accuracy,
              minHeight: 7,
              backgroundColor: Palette.track,
              valueColor: AlwaysStoppedAnimation(colour),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            stats.hasData
                ? '${stats.cardsTested} '
                    '${stats.cardsTested == 1 ? 'card' : 'cards'} tested · '
                    '${stats.correct}/${stats.attempts} recent answers'
                : 'Never practised this way round',
            style: Type.secondary,
          ),
        ],
      ),
    );
  }
}

/// One weak card. Laid out so a vocabulary phrase wraps instead of being
/// squeezed into a column sized for a single glyph.
class _WeakRow extends StatelessWidget {
  const _WeakRow({required this.card, required this.onTap});

  final ScoredCard card;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colour = BandColor.of(card.band);
    final long = card.prompt.runes.length > 3;

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFF22262F))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    card.prompt,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: long ? 15 : 24,
                      height: 1.25,
                      color: Palette.text,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          card.answer,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Type.mono.copyWith(
                              fontSize: 12, color: const Color(0xFFB6BDCB)),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(card.directionLabel,
                          style: Type.mono.copyWith(fontSize: 10)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                LastTenDots(state: card.state),
                const SizedBox(height: 5),
                Text(
                  '${card.state.correct}/${card.state.attempts}',
                  style: TextStyle(
                    fontFamily: monoFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colour,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
