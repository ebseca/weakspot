/// Bringing an AI's reply back in.
///
/// Two ways in, because a long reply is painful to paste on a phone: a box
/// you can paste into, and a file you can pick. Both go through the same
/// parser, and both report what they had to throw away and why.
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../core/deck_import.dart';
import '../core/model.dart';
import '../core/rules.dart';
import '../core/store.dart';
import 'theme.dart';
import 'widgets.dart';

enum _Source { paste, file }

class ImportScreen extends StatefulWidget {
  const ImportScreen({
    super.key,
    required this.repository,
    this.topic = '',
  });

  final LibraryRepository repository;

  /// What the player said they wanted to learn, used to name a deck the
  /// reply forgot to name.
  final String topic;

  @override
  State<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends State<ImportScreen> {
  final TextEditingController _pasted = TextEditingController();

  _Source _source = _Source.paste;
  String? _fileName;
  String _fileContents = '';
  String? _fileError;
  bool _saving = false;
  List<Library> _existing = const [];

  @override
  void initState() {
    super.initState();
    widget.repository.loadAll().then((libraries) {
      if (mounted) setState(() => _existing = libraries);
    });
  }

  @override
  void dispose() {
    _pasted.dispose();
    super.dispose();
  }

  String get _raw =>
      _source == _Source.paste ? _pasted.text : _fileContents;

  String get _fallbackName {
    final topic = widget.topic.trim();
    return topic.isEmpty ? 'New library' : topic;
  }

  DeckParseResult? get _result =>
      _raw.trim().isEmpty ? null : parseDeck(_raw, fallbackName: _fallbackName);

  Future<void> _pickFile() async {
    try {
      final file = await FilePicker.pickFile();
      if (file == null || !mounted) return;

      final bytes = await file.readAsBytes();
      if (!mounted) return;

      if (bytes.isEmpty) {
        setState(() {
          _fileError = 'That file is empty — try pasting instead.';
          _fileName = file.name;
          _fileContents = '';
        });
        return;
      }
      setState(() {
        _fileName = file.name;
        _fileContents = utf8.decode(bytes, allowMalformed: true);
        _fileError = null;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() =>
          _fileError = "Couldn't read that file — try pasting the reply "
              'instead.');
    }
  }

  /// A deck of your own already called this, if there is one.
  ///
  /// Matched by name rather than id so that fixing a deck and pasting it
  /// back finds the original. Bundled decks are left alone — they refresh
  /// themselves from the app.
  Library? _replaceable(DeckParseResult result) {
    final name = result.deckName.trim().toLowerCase();
    for (final library in _existing) {
      if (!library.bundled && library.name.trim().toLowerCase() == name) {
        return library;
      }
    }
    return null;
  }

  Future<void> _create(DeckParseResult result) async {
    setState(() => _saving = true);

    // Re-read rather than trusting the snapshot: a deck could have been
    // added since this screen opened, and a colliding id would overwrite
    // it silently.
    final existing = await widget.repository.loadAll();
    final library = result.toLibrary(
      id: libraryIdFor(result.deckName, existing.map((l) => l.id)),
    );
    await widget.repository.save(library);

    if (!mounted) return;
    Navigator.of(context).pop(library);
  }

  /// Swap new content into an existing deck, keeping everything answered.
  ///
  /// Card state is keyed by id, and an id defaults to the front, so a
  /// corrected deck with the same cards lands on the same history.
  Future<void> _replace(Library existing, DeckParseResult result) async {
    setState(() => _saving = true);

    final updated = existing.copyWith(
      name: result.deckName,
      notes: result.notes,
      reversible: result.reversible,
    );
    await widget.repository.save(updated);

    if (!mounted) return;
    Navigator.of(context).pop(updated);
  }

  @override
  Widget build(BuildContext context) {
    final result = _result;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 22),
              TopBar(
                title: 'Bring in the reply',
                onBack: () => Navigator.of(context).pop(),
                backLabel: 'Back to the prompt',
              ),
              const SizedBox(height: 18),
              _Tabs(
                selected: _source,
                onChanged: (source) => setState(() => _source = source),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 14),
                  children: [
                    if (_source == _Source.paste)
                      _PastePanel(controller: _pasted, onChanged: () => setState(() {}))
                    else
                      _FilePanel(
                        fileName: _fileName,
                        error: _fileError,
                        onPick: _pickFile,
                      ),
                    const SizedBox(height: 16),
                    if (result != null) _Verdict(result: result),
                  ],
                ),
              ),
              _Actions(
                result: result,
                existing: result == null ? null : _replaceable(result),
                busy: _saving,
                onCreate: () => _create(result!),
                onReplace: (existing) => _replace(existing, result!),
              ),
              const SizedBox(height: 22),
            ],
          ),
        ),
      ),
    );
  }
}

/// Create a new deck, or swap the content into one already there.
class _Actions extends StatelessWidget {
  const _Actions({
    required this.result,
    required this.existing,
    required this.busy,
    required this.onCreate,
    required this.onReplace,
  });

  final DeckParseResult? result;
  final Library? existing;
  final bool busy;
  final VoidCallback onCreate;
  final ValueChanged<Library> onReplace;

  @override
  Widget build(BuildContext context) {
    final usable = result != null && result!.isUsable && !busy;
    final count = result?.notes.length ?? 0;
    final target = existing;

    if (target == null) {
      return FilledButton(
        onPressed: usable ? onCreate : null,
        child: Text(usable ? 'Create library with $count cards'
            : 'Create library'),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FilledButton(
          onPressed: usable ? () => onReplace(target) : null,
          child: Text('Replace ${target.name}'),
        ),
        const SizedBox(height: 6),
        Text(
          'Swaps in the $count new cards and keeps everything you have '
          'answered.',
          textAlign: TextAlign.center,
          style: Type.secondary,
        ),
        const SizedBox(height: 10),
        OutlinedButton(
          onPressed: usable ? onCreate : null,
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
            foregroundColor: Palette.text,
            backgroundColor: Palette.panel,
            side: const BorderSide(color: Palette.line),
            textStyle:
                const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(13),
            ),
          ),
          child: const Text('Create a separate deck instead'),
        ),
      ],
    );
  }
}

class _Tabs extends StatelessWidget {
  const _Tabs({required this.selected, required this.onChanged});

  final _Source selected;
  final ValueChanged<_Source> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final source in _Source.values) ...[
          if (source != _Source.values.first) const SizedBox(width: 6),
          Expanded(
            child: Semantics(
              selected: source == selected,
              button: true,
              child: InkWell(
                onTap: () => onChanged(source),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  constraints: const BoxConstraints(minHeight: 44),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: source == selected
                        ? Palette.accentPanel
                        : const Color(0xFF1A1D25),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: source == selected ? Palette.accent : Palette.line,
                    ),
                  ),
                  child: Text(
                    source == _Source.paste ? 'Paste text' : 'Import a file',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: source == selected ? Palette.text : Palette.dim,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

class _PastePanel extends StatelessWidget {
  const _PastePanel({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Paste everything the AI replied — extra chatter is ignored.',
          style: Type.secondary,
        ),
        const SizedBox(height: 8),
        TextField(
          controller: controller,
          onChanged: (_) => onChanged(),
          maxLines: 9,
          minLines: 7,
          style: const TextStyle(
            fontFamily: monoFamily,
            fontSize: 11,
            height: 1.5,
            color: Color(0xFF98A0B0),
          ),
          decoration: InputDecoration(
            hintText: '{"deck": "Hiragana", "cards": [ ... ]}',
            hintStyle: const TextStyle(
                fontFamily: monoFamily, fontSize: 11, color: Palette.faint),
            filled: true,
            fillColor: Palette.sunken,
            contentPadding: const EdgeInsets.all(13),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Palette.line),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Palette.line),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: const BorderSide(color: Palette.accent),
            ),
          ),
        ),
      ],
    );
  }
}

class _FilePanel extends StatelessWidget {
  const _FilePanel({
    required this.fileName,
    required this.error,
    required this.onPick,
  });

  final String? fileName;
  final String? error;
  final VoidCallback onPick;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'For replies too long to paste comfortably on a phone.',
          style: Type.secondary,
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onPick,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 150,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Palette.sunken,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF39404F),
                style: BorderStyle.solid,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.file_upload_outlined,
                    size: 26, color: Palette.accent),
                const SizedBox(height: 11),
                Text(
                  fileName ?? 'Choose a file',
                  style: Type.mono.copyWith(
                      fontSize: 12, color: const Color(0xFFB6BDCB)),
                ),
                if (fileName != null) ...[
                  const SizedBox(height: 6),
                  const Text('Tap to choose a different one',
                      style: TextStyle(fontSize: 12, color: Palette.accent)),
                ],
              ],
            ),
          ),
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Text(error!,
              style: const TextStyle(
                  fontSize: 13, color: BandColor.struggling)),
        ],
      ],
    );
  }
}

/// What the parser made of it, good and bad.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.result});

  final DeckParseResult result;

  @override
  Widget build(BuildContext context) {
    final fatal = result.fatal;

    return Column(
      children: [
        if (fatal != null)
          _Card(
            background: const Color(0xFF2A1D1A),
            border: const Color(0xFF5A3328),
            icon: Icons.error_outline,
            iconColour: BandColor.struggling,
            title: "Can't read that",
            child: Text(fatal, style: Type.secondary),
          )
        else
          _Card(
            background: const Color(0xFF1E2A24),
            border: const Color(0xFF2F5244),
            icon: Icons.check,
            iconColour: BandColor.mastered,
            title: '${result.deckName} — ready to create',
            child: Row(
              children: [
                _Count(value: result.notes.length, label: 'cards'),
                _Count(value: result.withHints, label: 'with hints'),
                _Count(
                    value: result.withDistractors, label: 'with distractors'),
              ],
            ),
          ),
        if (fatal == null && result.selfAnswering.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Card(
            background: const Color(0xFF2A2419),
            border: const Color(0xFF5A4A28),
            icon: Icons.warning_amber_rounded,
            iconColour: BandColor.learning,
            title: '${result.selfAnswering.length} '
                '${result.selfAnswering.length == 1 ? 'answer repeats' : 'answers repeat'} '
                'the question',
            titleColour: const Color(0xFFE8C983),
            child: Text(
              'Such as "${result.selfAnswering.first.back}", which contains '
              '"${result.selfAnswering.first.front}". Asked the other way '
              'round the answer becomes the question, so those cards give '
              'themselves away. Ask the model to leave the front out of '
              'the back.',
              style: Type.secondary.copyWith(height: 1.4),
            ),
          ),
        ],
        if (fatal == null && result.duplicateAnswers.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Card(
            background: const Color(0xFF2A2419),
            border: const Color(0xFF5A4A28),
            icon: Icons.info_outline,
            iconColour: BandColor.learning,
            title: '${result.duplicateAnswers.length} '
                '${result.duplicateAnswers.length == 1 ? 'answer is' : 'answers are'} '
                'used by more than one card',
            titleColour: const Color(0xFFE8C983),
            child: Text(
              'Such as "${result.duplicateAnswers.first}". Questions can '
              'only offer as many choices as the deck has different '
              'answers — this one has ${result.distinctAnswers}, so some '
              'questions will show fewer than $optionCount options. Ask '
              'the model to make each answer distinct if that matters.',
              style: Type.secondary.copyWith(height: 1.4),
            ),
          ),
        ],
        if (result.problems.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Card(
            background: const Color(0xFF2A2419),
            border: const Color(0xFF5A4A28),
            icon: Icons.warning_amber_rounded,
            iconColour: BandColor.learning,
            title: '${result.skipped} '
                '${result.skipped == 1 ? 'card' : 'cards'} skipped',
            titleColour: const Color(0xFFE8C983),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final problem in result.problems.take(6))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(problem,
                        style: Type.secondary.copyWith(height: 1.4)),
                  ),
                if (result.problems.length > 6)
                  Text('…and ${result.problems.length - 6} more.',
                      style: Type.secondary),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({
    required this.background,
    required this.border,
    required this.icon,
    required this.iconColour,
    required this.title,
    required this.child,
    this.titleColour = Palette.text,
  });

  final Color background;
  final Color border;
  final IconData icon;
  final Color iconColour;
  final String title;
  final Color titleColour;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 15),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(13),
        border: Border.all(color: border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 1),
                child: Icon(icon, size: 17, color: iconColour),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: titleColour,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$value',
            style: const TextStyle(
              fontFamily: monoFamily,
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Color(0xFF7FC9A2),
            ),
          ),
          const SizedBox(height: 2),
          Text(label, style: const TextStyle(fontSize: 11, color: Palette.dim)),
        ],
      ),
    );
  }
}
