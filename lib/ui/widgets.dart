/// Small pieces shared across screens.
library;

import 'package:flutter/material.dart';

import '../core/model.dart';
import 'logo.dart';
import 'theme.dart';

/// The last ten answers as a row of dots, oldest on the left.
///
/// This is the win rate made visible — the thing selection actually runs
/// on — so a weak card shows *how* it is weak, not just that it is.
class LastTenDots extends StatelessWidget {
  const LastTenDots({super.key, required this.state, this.size = 7});

  final CardState state;
  final double size;

  @override
  Widget build(BuildContext context) {
    if (state.attempts == 0) {
      return Text('never tried', style: Type.mono.copyWith(fontSize: 11));
    }

    return Semantics(
      label: '${state.correct} of ${state.attempts} recent answers correct',
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < state.history.length; i++) ...[
            if (i > 0) SizedBox(width: size * 0.5),
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                color: state.history[i]
                    ? BandColor.mastered
                    : BandColor.struggling,
                borderRadius: BorderRadius.circular(size / 2),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// A small all-caps marker above a group.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) =>
      Text(text.toUpperCase(), style: Type.sectionLabel);
}

/// Back arrow and a title, sized for a comfortable touch target.
class TopBar extends StatelessWidget {
  const TopBar({
    super.key,
    required this.title,
    this.subtitle,
    this.onBack,
    this.backLabel = 'Back',
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final VoidCallback? onBack;
  final String backLabel;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (onBack != null)
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.chevron_left, size: 26),
            color: Palette.dim,
            tooltip: backLabel,
            constraints: const BoxConstraints.tightFor(width: 44, height: 44),
            padding: EdgeInsets.zero,
          )
        else
          const SizedBox(width: 4),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Type.screenTitle),
              if (subtitle != null) ...[
                const SizedBox(height: 2),
                Text(subtitle!, style: Type.secondary),
              ],
            ],
          ),
        ),
        ?trailing,
      ],
    );
  }
}

/// A quiet bordered box for a line of explanation.
class InfoNote extends StatelessWidget {
  const InfoNote({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
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
            child: Icon(Icons.info_outline, size: 16, color: Palette.accent),
          ),
          const SizedBox(width: 9),
          Expanded(child: child),
        ],
      ),
    );
  }
}

/// A row of equal-width choices, one selected.
class ChoiceRow<T> extends StatelessWidget {
  const ChoiceRow({
    super.key,
    required this.values,
    required this.selected,
    required this.onChanged,
    required this.headline,
    this.caption,
    this.isLocked,
    this.onLocked,
  });

  final List<T> values;
  final T selected;
  final ValueChanged<T> onChanged;

  /// Whether a value is shown but not yet available. A locked choice is
  /// still on screen — hiding it would leave no way to find out it
  /// exists — but tapping it calls [onLocked] instead of choosing it.
  final bool Function(T)? isLocked;

  final ValueChanged<T>? onLocked;

  /// The big line inside each choice.
  final String Function(T) headline;

  /// A smaller line under it.
  final String Function(T)? caption;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < values.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(
            child: Builder(builder: (context) {
              final value = values[i];
              final locked = isLocked?.call(value) ?? false;
              return _Choice(
                selected: !locked && value == selected,
                locked: locked,
                onTap: () =>
                    locked ? onLocked?.call(value) : onChanged(value),
                headline: headline(value),
                caption: caption?.call(value),
              );
            }),
          ),
        ],
      ],
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.onTap,
    required this.headline,
    this.caption,
    this.locked = false,
  });

  final bool selected;
  final VoidCallback onTap;
  final String headline;
  final String? caption;

  /// Drawn receded, with a padlock where the caption goes.
  final bool locked;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      enabled: !locked,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Palette.accent : Palette.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? Palette.accent : Palette.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                headline,
                style: TextStyle(
                  fontFamily: monoFamily,
                  fontSize: 21,
                  fontWeight: FontWeight.w600,
                  color: locked
                      ? Palette.faint
                      : selected
                          ? Colors.white
                          : Palette.text,
                ),
              ),
              if (locked) ...[
                const SizedBox(height: 4),
                const Icon(Icons.lock_outline,
                    size: 13, color: MarkColors.proText),
              ] else if (caption != null) ...[
                const SizedBox(height: 3),
                Text(
                  caption!,
                  style: TextStyle(
                    fontSize: 12,
                    color: selected ? Colors.white70 : Palette.dim,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// A compact selectable chip: a marker above a short label.
///
/// Three fit across a phone, which is what lets a choice sit above the
/// fold instead of at the end of a scrolling list.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.icon,
    this.glyph,
    this.semanticLabel,
  }) : assert(icon != null || glyph != null, 'needs an icon or a glyph');

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final IconData? icon;
  final String? glyph;

  /// Spoken instead of [label] where the short label is not the whole
  /// story — "Character to sound" for a chip reading "Reading".
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : Palette.dim;

    return Semantics(
      selected: selected,
      button: true,
      label: semanticLabel ?? label,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 56),
          decoration: BoxDecoration(
            color: selected ? Palette.accent : Palette.panel,
            borderRadius: BorderRadius.circular(12),
            border:
                Border.all(color: selected ? Palette.accent : Palette.line),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null)
                Icon(icon, size: 18, color: foreground)
              else
                Text(
                  glyph!,
                  style: TextStyle(
                    fontFamily: monoFamily,
                    fontSize: 17,
                    color: foreground,
                  ),
                ),
              const SizedBox(height: 3),
              Text(
                label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: foreground,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A row of [IconChip]s that fills the width.
class ChipRow extends StatelessWidget {
  const ChipRow({super.key, required this.chips});

  final List<Widget> chips;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < chips.length; i++) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(child: chips[i]),
        ],
      ],
    );
  }
}

/// A full-width selectable row with a glyph, a name and a detail line.
class OptionRow extends StatelessWidget {
  const OptionRow({
    super.key,
    this.glyph,
    this.icon,
    required this.name,
    required this.detail,
    required this.selected,
    required this.onTap,
  }) : assert(glyph != null || icon != null, 'needs a glyph or an icon');

  /// A character marker — an arrow, say. Use [icon] where no character
  /// renders reliably across devices.
  final String? glyph;

  final IconData? icon;
  final String name;
  final String detail;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: selected ? Palette.accentPanel : Palette.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: selected ? Palette.accent : Palette.line),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: icon != null
                    ? Icon(icon,
                        size: 19,
                        color: selected ? Palette.text : Palette.dim)
                    : Text(
                        glyph!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: monoFamily,
                          fontSize: 17,
                          color: selected ? Palette.text : Palette.dim,
                        ),
                      ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: selected ? Palette.text : Palette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(detail, style: Type.secondary),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
