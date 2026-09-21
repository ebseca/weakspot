/// Choosing what to study and how.
library;

import 'package:flutter/material.dart';

import '../core/model.dart';
import '../core/rules.dart';
import '../core/session.dart';
import '../core/store.dart';
import 'session_screen.dart';
import 'stats_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class SessionSetupScreen extends StatefulWidget {
  const SessionSetupScreen({
    super.key,
    required this.library,
    required this.repository,
  });

  final Library library;
  final LibraryRepository repository;

  @override
  State<SessionSetupScreen> createState() => _SessionSetupScreenState();
}

class _SessionSetupScreenState extends State<SessionSetupScreen> {
  late Library _library = widget.library;

  int _length = 20;
  int _minutes = 3;
  GameMode _game = GameMode.practice;
  DirectionMode _mode = DirectionMode.forward;

  /// A deck the AI marked one-way keeps the other directions tucked away,
  /// so nobody picks "mixed" on a quiz just because it was on screen.
  bool _showAllDirections = false;

  bool get _oneWay => !_library.reversible;

  /// What the session will actually open with, including anything the
  /// top-up will pull in the moment it starts.
  int get _pool => topUpPool(_library).unlockedCount;

  Future<void> _openStats() async {
    final updated = await Navigator.of(context).push<Library>(
      MaterialPageRoute(
        builder: (_) => StatsScreen(
          library: _library,
          repository: widget.repository,
        ),
      ),
    );
    if (updated == null || !mounted) return;
    setState(() => _library = updated);
  }

  Future<void> _start() async {
    final played = await Navigator.of(context).push<Library>(
      MaterialPageRoute(
        builder: (_) => SessionScreen(
          library: _library,
          repository: widget.repository,
          config: SessionConfig(
            length: _length,
            mode: _mode,
            game: _game,
            duration: _game.isTimed ? Duration(minutes: _minutes) : null,
          ),
        ),
      ),
    );
    if (!mounted) return;
    Navigator.of(context).pop(played ?? _library);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) Navigator.of(context).pop(_library);
      },
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(22, 22, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TopBar(
                  title: _library.name,
                  onBack: () => Navigator.of(context).pop(_library),
                  backLabel: 'Back to libraries',
                  trailing: IconButton(
                    onPressed: _openStats,
                    icon: const Icon(Icons.insights_outlined, size: 22),
                    color: Palette.dim,
                    tooltip: 'Progress and weak spots',
                    constraints:
                        const BoxConstraints.tightFor(width: 44, height: 44),
                  ),
                ),
                const SizedBox(height: 26),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      const SectionLabel('Mode'),
                      const SizedBox(height: 11),
                      ChipRow(
                        chips: [
                          for (final game in GameMode.values)
                            IconChip(
                              icon: switch (game) {
                                GameMode.practice => Icons.my_location,
                                GameMode.timed => Icons.timer_outlined,
                                GameMode.random => Icons.shuffle,
                              },
                              label: game.label,
                              selected: _game == game,
                              onTap: () => setState(() => _game = game),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(_game.detail, style: Type.secondary),
                      const SizedBox(height: 26),
                      SectionLabel(
                        _game.isTimed ? 'How long' : 'How many questions',
                      ),
                      const SizedBox(height: 11),
                      if (_game.isTimed)
                        ChoiceRow<int>(
                          values: timedMinutes,
                          selected: _minutes,
                          onChanged: (value) =>
                              setState(() => _minutes = value),
                          headline: (value) => '$value',
                          caption: (value) =>
                              value == 1 ? 'minute' : 'minutes',
                        )
                      else
                        ChoiceRow<int>(
                          values: sessionLengths,
                          selected: _length,
                          onChanged: (value) => setState(() => _length = value),
                          headline: (value) => '$value',
                          caption: (value) => switch (value) {
                            10 => 'quick',
                            20 => 'normal',
                            _ => 'long',
                          },
                        ),
                      const SizedBox(height: 11),
                      InfoNote(
                        child: Text.rich(
                          TextSpan(
                            style: const TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: Color(0xFFB6BDCB),
                            ),
                            children: [
                              const TextSpan(text: 'Opens with '),
                              TextSpan(
                                text: '$_pool ${_pool == 1 ? 'card' : 'cards'}',
                                style: const TextStyle(
                                  color: Palette.text,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const TextSpan(
                                text: ' in play. More arrive as you master '
                                    'what you have.',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Pinned rather than sitting at the end of the list, so
                // switching direction never means scrolling for it.
                const SizedBox(height: 16),
                const SectionLabel('Which way round'),
                const SizedBox(height: 10),
                if (_oneWay && !_showAllDirections)
                  _OneWayNote(
                    library: _library,
                    onShowAll: () =>
                        setState(() => _showAllDirections = true),
                  )
                else ...[
                  ChipRow(
                    chips: [
                      for (final mode in DirectionMode.values)
                        IconChip(
                          glyph: mode.glyph,
                          label: _shortName(mode),
                          semanticLabel: mode.label,
                          selected: _mode == mode,
                          onTap: () => setState(() => _mode = mode),
                        ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(_detailFor(_mode), style: Type.secondary),
                ],
                const SizedBox(height: 14),
                FilledButton(
                  onPressed: _library.notes.isEmpty ? null : _start,
                  child: const Text('Start session'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// The chip label. The full name is spoken for screen readers.
  static String _shortName(DirectionMode mode) => switch (mode) {
        DirectionMode.forward => 'Reading',
        DirectionMode.reverse => 'Writing',
        DirectionMode.mixed => 'Mixed',
      };

  /// Show a real example from this deck rather than a generic description.
  String _detailFor(DirectionMode mode) {
    final sample = _library.notes.isEmpty ? null : _library.notes.first;
    if (sample == null) return mode.detail;

    final front = _clip(sample.front);
    final back = _clip(sample.back);

    return switch (mode) {
      DirectionMode.forward => '$front → $back · tests reading',
      DirectionMode.reverse => '$back → $front · tests writing',
      DirectionMode.mixed => 'Both, scored separately',
    };
  }

  static String _clip(String value) =>
      value.runes.length <= 12 ? value : '${value.substring(0, 11)}…';
}

/// A deck the AI said should not be reversed.
///
/// Stated plainly rather than hidden: the other directions are one tap
/// away, they just are not the default and do not sit there inviting a
/// pointless difficulty bump.
class _OneWayNote extends StatelessWidget {
  const _OneWayNote({required this.library, required this.onShowAll});

  final Library library;
  final VoidCallback onShowAll;

  @override
  Widget build(BuildContext context) {
    final sample = library.notes.isEmpty ? null : library.notes.first;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
          decoration: BoxDecoration(
            color: Palette.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('→',
                      style: TextStyle(
                          fontFamily: monoFamily,
                          fontSize: 15,
                          color: Palette.accent)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      sample == null
                          ? 'One way only'
                          : '${_clip(sample.front)} → ${_clip(sample.back)}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Palette.text,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              const Text(
                'This deck reads one way. Asked backwards its questions '
                'stop making sense.',
                style: Type.secondary,
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton(
            onPressed: onShowAll,
            style: TextButton.styleFrom(
              foregroundColor: Palette.faint,
              textStyle: const TextStyle(fontSize: 13),
              padding: const EdgeInsets.symmetric(horizontal: 4),
            ),
            child: const Text('Use another direction anyway'),
          ),
        ),
      ],
    );
  }

  static String _clip(String value) =>
      value.runes.length <= 14 ? value : '${value.substring(0, 13)}…';
}
