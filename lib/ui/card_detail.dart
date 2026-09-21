/// One card, in full: both sides, its hint, and how each direction is
/// actually going.
///
/// Reachable from the grid and from the needs-work list, so "why does this
/// one keep coming up?" has an answer you can look at.
library;

import 'package:flutter/material.dart';

import '../core/model.dart';
import '../core/rules.dart';
import 'theme.dart';
import 'widgets.dart';

Future<void> showCardDetail(
  BuildContext context, {
  required Library library,
  required Note note,

  /// Offered on a locked card. Null leaves the sheet read-only.
  VoidCallback? onUnlock,
}) {
  return showModalBottomSheet<void>(
    context: context,
    backgroundColor: Palette.panel,
    showDragHandle: true,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (context) =>
        _CardDetail(library: library, note: note, onUnlock: onUnlock),
  );
}

class _CardDetail extends StatelessWidget {
  const _CardDetail({
    required this.library,
    required this.note,
    this.onUnlock,
  });

  final Library library;
  final Note note;
  final VoidCallback? onUnlock;

  bool get _locked => !library.isUnlocked(note.id);

  @override
  Widget build(BuildContext context) {
    final hint = note.hint;

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 4, 22, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  note.front,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: Type.cardSizeFor(note.front) * 0.7,
                    height: 1.1,
                    color: Palette.text,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  note.back,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: monoFamily,
                    fontSize: Type.answerSizeFor(note.back),
                    color: Palette.dim,
                  ),
                ),
              ),
              if (hint != null) ...[
                const SizedBox(height: 18),
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1A1D25),
                    borderRadius: BorderRadius.circular(11),
                    border: Border.all(color: Palette.line),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Padding(
                        padding: EdgeInsets.only(top: 1),
                        child: Icon(Icons.lightbulb_outline,
                            size: 15, color: Palette.dim),
                      ),
                      const SizedBox(width: 9),
                      Expanded(
                        child: Text(hint,
                            style: Type.secondary.copyWith(height: 1.5)),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),
              if (_locked) ...[
                const Text(
                  'Not in play yet. It opens on its own as you master what '
                  'you already have.',
                  style: Type.secondary,
                ),
                if (onUnlock != null) ...[
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        onUnlock!();
                      },
                      icon: const Icon(Icons.lock_open, size: 17),
                      label: const Text('Open this card now'),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(52),
                        foregroundColor: Palette.text,
                        backgroundColor: const Color(0xFF1A1D25),
                        side: const BorderSide(color: Palette.line),
                        textStyle: const TextStyle(
                            fontSize: 15, fontWeight: FontWeight.w600),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(13),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Just this one — nothing before it comes with it.',
                    style: Type.secondary,
                  ),
                ],
              ] else ...[
                const SectionLabel('Recent answers'),
                const SizedBox(height: 10),
                for (final direction in Direction.values)
                  if (library.reversible || direction == Direction.forward)
                    _DirectionRow(
                      library: library,
                      note: note,
                      direction: direction,
                    ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _DirectionRow extends StatelessWidget {
  const _DirectionRow({
    required this.library,
    required this.note,
    required this.direction,
  });

  final Library library;
  final Note note;
  final Direction direction;

  @override
  Widget build(BuildContext context) {
    final state = library.stateOf(note.id, direction);
    final band = bandForCard(state);
    final forward = direction == Direction.forward;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              forward ? '→ reading' : '← writing',
              style: Type.mono.copyWith(fontSize: 11),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerLeft,
              child: LastTenDots(state: state, size: 8),
            ),
          ),
          Text(
            state.attempts == 0
                ? '—'
                : '${state.correct}/${state.attempts}',
            style: TextStyle(
              fontFamily: monoFamily,
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: state.attempts == 0 ? Palette.faint : BandColor.of(band),
            ),
          ),
        ],
      ),
    );
  }
}
