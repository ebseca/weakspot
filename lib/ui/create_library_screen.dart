/// Turning "I want to learn hiragana" into a prompt you can paste
/// anywhere.
///
/// There is no model in this app and no network call. The player brings
/// their own AI, which costs nothing, works with whatever they already pay
/// for, and keeps the app genuinely offline.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/deck_import.dart';
import '../core/model.dart';
import '../core/store.dart';
import 'import_screen.dart';
import 'theme.dart';
import 'widgets.dart';

class CreateLibraryScreen extends StatefulWidget {
  const CreateLibraryScreen({super.key, required this.repository});

  final LibraryRepository repository;

  @override
  State<CreateLibraryScreen> createState() => _CreateLibraryScreenState();
}

class _CreateLibraryScreenState extends State<CreateLibraryScreen> {
  final TextEditingController _topic = TextEditingController();
  bool _copied = false;

  /// Resets the button's confirmation. Held so leaving the screen cancels
  /// it rather than leaving a timer running behind us.
  Timer? _resetCopied;

  @override
  void dispose() {
    _resetCopied?.cancel();
    _topic.dispose();
    super.dispose();
  }

  String get _prompt => buildDeckPrompt(_topic.text);

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _prompt));
    if (!mounted) return;

    setState(() => _copied = true);
    _resetCopied?.cancel();
    _resetCopied = Timer(const Duration(seconds: 2), () {
      if (mounted) setState(() => _copied = false);
    });
  }

  Future<void> _openImport() async {
    final created = await Navigator.of(context).push<Library>(
      MaterialPageRoute(
        builder: (_) => ImportScreen(
          repository: widget.repository,
          topic: _topic.text,
        ),
      ),
    );
    if (created != null && mounted) Navigator.of(context).pop(created);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 22),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 22),
              TopBar(
                title: 'New library',
                onBack: () => Navigator.of(context).pop(),
                backLabel: 'Back to libraries',
              ),
              const SizedBox(height: 20),
              const Text(
                'What do you want to learn?',
                style: TextStyle(fontSize: 14, color: Color(0xFFB6BDCB)),
              ),
              const SizedBox(height: 9),
              TextField(
                controller: _topic,
                maxLines: 2,
                minLines: 2,
                style: const TextStyle(fontSize: 15, color: Palette.text),
                textInputAction: TextInputAction.done,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'I would like to learn hiragana',
                  hintStyle: const TextStyle(color: Palette.faint),
                  filled: true,
                  fillColor: Palette.panel,
                  contentPadding: const EdgeInsets.all(14),
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
              const SizedBox(height: 14),
              FilledButton.icon(
                onPressed: _copy,
                icon: Icon(_copied ? Icons.check : Icons.copy_rounded,
                    size: 18),
                label: Text(_copied ? 'Copied to clipboard' : 'Copy prompt'),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      _copied ? const Color(0xFF1E2A24) : Palette.accent,
                  foregroundColor:
                      _copied ? const Color(0xFF7FC9A2) : Colors.white,
                  minimumSize: const Size.fromHeight(54),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                    side: BorderSide(
                      color: _copied ? BandColor.mastered : Palette.accent,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              const _Steps(),
              const SizedBox(height: 14),
              const SectionLabel('What gets copied'),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: Palette.sunken,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF22262F)),
                  ),
                  child: SingleChildScrollView(
                    child: Text(
                      _prompt,
                      style: const TextStyle(
                        fontFamily: monoFamily,
                        fontSize: 11,
                        height: 1.6,
                        color: Color(0xFF98A0B0),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              OutlinedButton(
                onPressed: _openImport,
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(54),
                  foregroundColor: Palette.text,
                  backgroundColor: Palette.panel,
                  side: const BorderSide(color: Palette.line),
                  textStyle: const TextStyle(
                      fontSize: 15, fontWeight: FontWeight.w600),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(13),
                  ),
                ),
                child: const Text('I have the reply — bring it in'),
              ),
              const SizedBox(height: 22),
            ],
          ),
        ),
      ),
    );
  }
}

class _Steps extends StatelessWidget {
  const _Steps();

  static const List<String> _steps = [
    'Copy the prompt.',
    'Paste it into whatever AI you already use — nothing is sent from '
        'this app.',
    'Copy the reply back here, or save it as a file and import it.',
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < _steps.length; i++) ...[
          if (i > 0) const SizedBox(height: 9),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 20,
                height: 20,
                margin: const EdgeInsets.only(top: 1),
                alignment: Alignment.center,
                decoration: const BoxDecoration(
                  color: Palette.track,
                  shape: BoxShape.circle,
                ),
                child: Text('${i + 1}',
                    style: Type.mono.copyWith(fontSize: 11)),
              ),
              const SizedBox(width: 11),
              Expanded(
                child: Text(
                  _steps[i],
                  style: const TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: Color(0xFFB6BDCB),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
