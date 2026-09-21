/// Everything that applies to every deck.
library;

import 'package:flutter/material.dart';

import '../core/settings.dart';
import 'logo.dart';
import 'theme.dart';
import 'widgets.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.controller});

  final SettingsController controller;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) => _Body(controller: controller),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.controller});

  final SettingsController controller;

  Settings get _settings => controller.settings;

  Future<void> _pickLanguage(BuildContext context) async {
    final chosen = await showModalBottomSheet<PromptLanguage>(
      context: context,
      backgroundColor: Palette.panel,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 18),
          children: [
            const SectionLabel('Deck language'),
            const SizedBox(height: 12),
            for (final language in PromptLanguage.values) ...[
              OptionRow(
                icon: Icons.translate,
                name: language.nativeName,
                detail: language.isDefault
                    ? 'The default — the prompt asks for nothing special'
                    : 'Answers and hints written in '
                        '${language.englishName.toLowerCase()}',
                selected: language == _settings.language,
                onTap: () => Navigator.of(context).pop(language),
              ),
              const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );

    if (chosen == null) return;
    await controller.update(_settings.copyWith(language: chosen));
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
                title: 'Settings',
                onBack: () => Navigator.of(context).pop(),
                backLabel: 'Back to libraries',
              ),
              const SizedBox(height: 22),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(bottom: 28),
                  children: [
                    _ProCard(controller: controller),
                    const SizedBox(height: 26),
                    const SectionLabel('Deck language'),
                    const SizedBox(height: 10),
                    OptionRow(
                      icon: Icons.translate,
                      name: _settings.language.nativeName,
                      detail: 'New decks are written in this. Nothing '
                          'already made changes.',
                      selected: false,
                      onTap: () => _pickLanguage(context),
                    ),
                    const SizedBox(height: 26),
                    const SectionLabel('Answer options'),
                    const SizedBox(height: 10),
                    ChoiceRow<int>(
                      values: optionCountChoices,
                      selected: _settings.optionCount,
                      onChanged: (value) => controller
                          .update(_settings.copyWith(optionCount: value)),
                      headline: (value) => '$value',
                      caption: (value) => switch (value) {
                        3 => 'easier',
                        4 => 'normal',
                        _ => 'harder',
                      },
                    ),
                    const SizedBox(height: 10),
                    const InfoNote(
                      child: Text(
                        'A deck can only offer as many choices as it has '
                        'distinct answers, so a small deck may still show '
                        'fewer.',
                        style: Type.secondary,
                      ),
                    ),
                    const SizedBox(height: 26),
                    const SectionLabel('Cards in play'),
                    const SizedBox(height: 10),
                    ChoiceRow<int>(
                      values: cardsInPlayChoices,
                      selected: _settings.cardsInPlay,
                      onChanged: (value) => controller
                          .update(_settings.copyWith(cardsInPlay: value)),
                      headline: (value) => '$value',
                      caption: (value) => switch (value) {
                        3 => 'steady',
                        5 => 'normal',
                        _ => 'cramming',
                      },
                    ),
                    const SizedBox(height: 10),
                    const InfoNote(
                      child: Text(
                        'How many unmastered cards are held open at once. '
                        'Master one and the next arrives.',
                        style: Type.secondary,
                      ),
                    ),
                    const SizedBox(height: 26),
                    const SectionLabel('Feedback'),
                    const SizedBox(height: 10),
                    _SwitchRow(
                      icon: Icons.vibration,
                      name: 'Haptics',
                      detail: 'A short buzz when you answer',
                      value: _settings.haptics,
                      onChanged: (value) =>
                          controller.update(_settings.copyWith(haptics: value)),
                    ),
                    const SizedBox(height: 26),
                    Center(
                      child: Text(
                        'No account, no sync, no network call anywhere.',
                        style: Type.mono.copyWith(fontSize: 11),
                      ),
                    ),
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

/// The subscription that is not one.
///
/// Flips a local flag and charges nothing — said out loud on the card
/// rather than implied, because a button reading "Subscribe" that quietly
/// does nothing is the kind of thing this app should not ship. What it is
/// for is the plumbing: everything Pro gates is built and working, so
/// binding this to a real purchase later changes where the flag comes
/// from and nothing else.
class _ProCard extends StatelessWidget {
  const _ProCard({required this.controller});

  final SettingsController controller;

  static const Color _edge = Color(0xFF6A5628);
  static const Color _fill = Color(0xFF221D12);

  @override
  Widget build(BuildContext context) {
    final pro = controller.settings.pro;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        color: _fill,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _edge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const WeakspotMark(size: 30, pro: true),
              const SizedBox(width: 11),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Weakspot Pro',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: MarkColors.proText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      pro ? 'Active' : 'Nothing is charged',
                      style: Type.secondary,
                    ),
                  ],
                ),
              ),
              if (pro) const ProBadge(),
            ],
          ),
          const SizedBox(height: 14),
          const _Perk(
            icon: Icons.timer_outlined,
            text: '$proTimedMinutes-minute timed runs',
          ),
          const SizedBox(height: 8),
          const _Perk(
            icon: Icons.auto_awesome,
            text: 'The gold mark, and a gold home-screen icon',
          ),
          const SizedBox(height: 10),
          // Said up front, both ways round: the launcher icon cannot be
          // swapped while the app is on screen without Android tearing
          // the task down, so it changes on the way out.
          Text(
            'The home-screen icon changes when you next leave the app.',
            style: Type.mono.copyWith(fontSize: 11),
          ),
          const SizedBox(height: 14),
          if (pro)
            OutlinedButton(
              onPressed: () =>
                  controller.update(controller.settings.copyWith(pro: false)),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
                foregroundColor: MarkColors.proText,
                side: const BorderSide(color: _edge),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Turn Pro off'),
            )
          else
            FilledButton(
              onPressed: () =>
                  controller.update(controller.settings.copyWith(pro: true)),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFD7A13F),
                foregroundColor: const Color(0xFF221D12),
                minimumSize: const Size.fromHeight(48),
                textStyle:
                    const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Subscribe now'),
            ),
          const SizedBox(height: 10),
          Text(
            pro
                ? 'Turning it off puts the everyday mark back and hides '
                    'the $proTimedMinutes-minute run.'
                : 'Free. This build has no payments in it — the button just '
                    'turns the extras on.',
            style: Type.mono.copyWith(fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class _Perk extends StatelessWidget {
  const _Perk({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: MarkColors.proText),
        const SizedBox(width: 10),
        Expanded(
          child: Text(text, style: Type.body.copyWith(fontSize: 13.5)),
        ),
      ],
    );
  }
}

/// A full-width row with a switch on the end.
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.name,
    required this.detail,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final String name;
  final String detail;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      toggled: value,
      child: InkWell(
        onTap: () => onChanged(!value),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          constraints: const BoxConstraints(minHeight: 60),
          padding: const EdgeInsets.fromLTRB(14, 10, 10, 10),
          decoration: BoxDecoration(
            color: Palette.panel,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Palette.line),
          ),
          child: Row(
            children: [
              SizedBox(
                width: 30,
                child: Icon(icon, size: 19, color: Palette.dim),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Palette.text,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(detail, style: Type.secondary),
                  ],
                ),
              ),
              Switch(
                value: value,
                onChanged: onChanged,
                activeThumbColor: Colors.white,
                activeTrackColor: Palette.accent,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
