/// The whole deck at a glance, one tile per note.
library;

import 'package:flutter/material.dart';

import '../core/model.dart';
import '../core/rules.dart';
import 'theme.dart';

/// Every note in the library, coloured by band.
///
/// Locked notes are drawn too, greyed out — seeing what is still ahead is
/// the point of showing the whole alphabet rather than only what is in
/// play.
class MasteryGrid extends StatelessWidget {
  const MasteryGrid({
    super.key,
    required this.library,
    this.columns = 6,
    this.tileHeight = 46,
    this.onTapNote,
  });

  final Library library;
  final int columns;
  final double tileHeight;

  /// Tapping a tile opens that card. Null leaves the grid read-only.
  final ValueChanged<Note>? onTapNote;

  @override
  Widget build(BuildContext context) {
    final notes = library.notes;
    if (notes.isEmpty) return const SizedBox.shrink();

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: notes.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: columns,
        mainAxisSpacing: 6,
        crossAxisSpacing: 6,
        mainAxisExtent: tileHeight,
      ),
      itemBuilder: (context, index) {
        final note = notes[index];
        final locked = !library.isUnlocked(note.id);
        return _Tile(
          label: note.front,
          band: locked ? null : bandForNote(library, note.id),
          onTap: onTapNote == null ? null : () => onTapNote!(note),
        );
      },
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.label, required this.band, this.onTap});

  final String label;

  /// Null means locked.
  final Band? band;

  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final locked = band == null;
    final background = locked ? BandColor.locked : BandColor.of(band!);
    final border = locked ? BandColor.lockedBorder : background;
    final foreground =
        locked ? BandColor.lockedText : BandColor.textOn(band!);

    return Semantics(
      button: onTap != null,
      label: label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(9),
        child: Container(
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 4),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(9),
            border: Border.all(color: border),
          ),
          // A vocabulary deck's fronts are words, not glyphs, so they have
          // to shrink to fit a tile sized for kana.
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              maxLines: 1,
              style: TextStyle(fontSize: 21, height: 1.1, color: foreground),
            ),
          ),
        ),
      ),
    );
  }
}

/// What the grid's colours mean.
class BandLegend extends StatelessWidget {
  const BandLegend({super.key, this.includeLocked = true});

  final bool includeLocked;

  @override
  Widget build(BuildContext context) {
    final entries = <(Color, String)>[
      (BandColor.mastered, 'Mastered · ${_pct(masteredFloor)}+'),
      (
        BandColor.learning,
        'Learning · ${_pct(strugglingCeiling)}–${_pct(masteredFloor) - 1}'
      ),
      (BandColor.struggling, 'Struggling · under ${_pct(strugglingCeiling)}'),
      if (includeLocked) (BandColor.lockedBorder, 'Locked'),
    ];

    return Wrap(
      spacing: 14,
      runSpacing: 8,
      children: [
        for (final (color, label) in entries)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontSize: 11, color: Palette.dim)),
            ],
          ),
      ],
    );
  }

  static int _pct(double value) => (value * 100).round();
}
