/// The library list — the app's front door.
library;

import 'package:flutter/material.dart';

import '../core/model.dart';
import '../core/rules.dart';
import '../core/settings.dart';
import '../core/store.dart';
import 'create_library_screen.dart';
import 'logo.dart';
import 'session_setup_screen.dart';
import 'settings_screen.dart';
import 'theme.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.settings,
  });

  final LibraryRepository repository;
  final SettingsController settings;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  List<Library>? _libraries;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final libraries = await widget.repository.loadAll();
      if (!mounted) return;
      setState(() {
        _libraries = libraries;
        _failed = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _failed = true);
    }
  }

  Future<void> _open(Library library) async {
    final played = await Navigator.of(context).push<Library>(
      MaterialPageRoute(
        builder: (_) => SessionSetupScreen(
          library: library,
          repository: widget.repository,
          settings: widget.settings,
        ),
      ),
    );
    if (played == null || !mounted) return;

    // Swap in the played library so the bands and unlock count refresh
    // without re-reading everything from storage.
    setState(() {
      _libraries = [
        for (final existing in _libraries ?? const <Library>[])
          existing.id == played.id ? played : existing,
      ];
    });
  }

  Future<void> _create() async {
    final created = await Navigator.of(context).push<Library>(
      MaterialPageRoute(
        builder: (_) => CreateLibraryScreen(
          repository: widget.repository,
          settings: widget.settings,
        ),
      ),
    );
    if (created == null || !mounted) return;
    setState(() {
      _libraries = [...?_libraries, created];
    });
  }

  /// Only offered for libraries the player made — the bundled decks come
  /// straight back on the next launch, so deleting one would be a lie.
  Future<void> _confirmDelete(Library library) async {
    if (library.bundled) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Palette.panel,
        title: Text('Delete ${library.name}?', style: Type.cardTitle),
        content: Text(
          'Its ${library.notes.length} cards and everything you have '
          'answered will be gone for good.',
          style: Type.secondary,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep it'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(
                foregroundColor: BandColor.struggling),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;
    await widget.repository.remove(library.id);
    if (!mounted) return;
    setState(() {
      _libraries = [
        for (final existing in _libraries ?? const <Library>[])
          if (existing.id != library.id) existing,
      ];
    });
  }

  void _openSettings() => Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => SettingsScreen(controller: widget.settings),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Listens so the mark switches the moment Pro is turned on or off,
    // without the settings screen having to hand anything back.
    return ListenableBuilder(
      listenable: widget.settings,
      builder: (context, _) => Scaffold(
        body: SafeArea(child: _body()),
      ),
    );
  }

  Widget _body() {
    if (_failed) {
      return const _Message(
        title: "Couldn't open your libraries",
        detail: 'The stored decks could not be read. Reinstalling restores '
            'the bundled ones.',
      );
    }

    final libraries = _libraries;
    if (libraries == null) {
      return const Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(22, 28, 22, 28),
      children: [
        _Header(
          pro: widget.settings.settings.pro,
          onSettings: _openSettings,
        ),
        const SizedBox(height: 22),
        const Text('YOUR LIBRARIES', style: Type.sectionLabel),
        const SizedBox(height: 10),
        if (libraries.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 10),
            child: Text(
              'Nothing here yet. Make one below — you bring your own AI, '
              'and nothing leaves this device.',
              style: Type.secondary,
            ),
          ),
        for (final library in libraries) ...[
          _LibraryCard(
            library: library,
            onTap: () => _open(library),
            onLongPress:
                library.bundled ? null : () => _confirmDelete(library),
          ),
          const SizedBox(height: 12),
        ],
        _CreateButton(onTap: _create),
      ],
    );
  }
}

/// Adding a library of your own.
class _CreateButton extends StatelessWidget {
  const _CreateButton({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        constraints: const BoxConstraints(minHeight: 56),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF39404F)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.add, size: 18, color: Palette.dim),
            const SizedBox(width: 9),
            Text(
              'Create a library',
              style: Type.body.copyWith(
                  color: Palette.dim, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.pro, required this.onSettings});

  final bool pro;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(child: Wordmark(pro: pro)),
        const SizedBox(width: 8),
        IconButton(
          onPressed: onSettings,
          icon: const Icon(Icons.settings_outlined, size: 22),
          color: Palette.dim,
          tooltip: 'Settings',
          constraints: const BoxConstraints.tightFor(width: 44, height: 44),
          padding: EdgeInsets.zero,
        ),
      ],
    );
  }
}

class _LibraryCard extends StatelessWidget {
  const _LibraryCard({
    required this.library,
    required this.onTap,
    this.onLongPress,
  });

  final Library library;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  @override
  Widget build(BuildContext context) {
    final counts = bandCounts(library);
    final total = library.notes.length;

    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: Palette.panel,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Palette.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(child: Text(library.name, style: Type.cardTitle)),
                const SizedBox(width: 12),
                Text('$total notes', style: Type.mono),
                const SizedBox(width: 6),
                // The cards are tappable; without this they read as inert
                // panels.
                const Icon(Icons.chevron_right, size: 18, color: Palette.faint),
              ],
            ),
            const SizedBox(height: 4),
            Text(_status(library), style: Type.secondary),
            const SizedBox(height: 12),
            _BandBar(counts: counts, total: total),
            const SizedBox(height: 9),
            _BandLegend(counts: counts),
          ],
        ),
      ),
    );
  }

  String _status(Library library) {
    if (!library.isStarted) {
      return 'Not started — the first session opens $batchSize cards';
    }
    return '${library.unlockedCount} of ${library.notes.length} unlocked';
  }
}

/// A single bar showing how the whole deck splits across bands.
class _BandBar extends StatelessWidget {
  const _BandBar({required this.counts, required this.total});

  final Map<Band, int> counts;
  final int total;

  /// Strongest first, so progress reads left to right.
  static const List<Band> _order = [
    Band.mastered,
    Band.learning,
    Band.struggling,
    Band.fresh,
  ];

  @override
  Widget build(BuildContext context) {
    if (total == 0) return const SizedBox.shrink();

    // The bar carries an outline and a visible track: without them an
    // almost-untouched deck rendered as a near-invisible strip the same
    // colour as the card behind it.
    return Container(
      height: 10,
      decoration: BoxDecoration(
        color: BandColor.fresh,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: Palette.line),
      ),
      clipBehavior: Clip.antiAlias,
      child: Row(
        // Without this the segments centre at zero height — a ColoredBox
        // has no size of its own, so the bar renders as an empty track.
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final band in _order)
            if ((counts[band] ?? 0) > 0)
              Expanded(
                flex: counts[band]!,
                child: ColoredBox(
                  color: band == Band.fresh
                      ? BandColor.fresh
                      : BandColor.of(band),
                ),
              ),
        ],
      ),
    );
  }
}

class _BandLegend extends StatelessWidget {
  const _BandLegend({required this.counts});

  final Map<Band, int> counts;

  static const List<Band> _shown = [
    Band.mastered,
    Band.learning,
    Band.struggling,
  ];

  @override
  Widget build(BuildContext context) {
    final entries = [
      for (final band in _shown)
        if ((counts[band] ?? 0) > 0) (band, counts[band]!),
    ];

    if (entries.isEmpty) {
      return Text(
        'No answers recorded yet',
        style: Type.mono.copyWith(fontSize: 11),
      );
    }

    return Wrap(
      spacing: 14,
      runSpacing: 4,
      children: [
        for (final (band, count) in entries)
          Text(
            '$count ${BandColor.label(band).toLowerCase()}',
            style: Type.mono.copyWith(fontSize: 11, color: BandColor.of(band)),
          ),
      ],
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.title, required this.detail});

  final String title;
  final String detail;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(title, style: Type.cardTitle, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(detail, style: Type.secondary, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
