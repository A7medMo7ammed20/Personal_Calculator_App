import 'package:flutter/material.dart';

import '../../domain/accent_theme.dart';
import '../../domain/theme_choice.dart';
import '../../l10n/gen/app_localizations.dart';
import '../profile/profile_controller.dart';
import '../theme/theme_context.dart';
import '../theme/theme_controller.dart';

/// Appearance settings: the brand [AccentTheme] (chrome only) and the
/// [ThemeChoice] brightness axis. Both are driven by the [ThemeController], so
/// a change re-tints the whole app immediately and persists (ADR 0002). Reached
/// from the home overflow menu.
///
/// When a [profileController] is supplied it also hosts the [Profile] editor at
/// the top (name + optional phone, #9). It is optional so focused theme tests
/// can pump the screen without wiring the profile.
class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
    required this.controller,
    this.profileController,
  });

  final ThemeController controller;
  final ProfileController? profileController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListenableBuilder(
        listenable: controller,
        builder: (context, _) => ListView(
          padding: EdgeInsets.all(context.spacing.lg),
          children: [
            if (profileController != null) ...[
              _ProfileSection(controller: profileController!),
              SizedBox(height: context.spacing.xl),
            ],
            _SectionHeader(l10n.settingsAccent),
            SizedBox(height: context.spacing.md),
            Wrap(
              spacing: context.spacing.md,
              runSpacing: context.spacing.md,
              children: [
                for (final accent in AccentTheme.values)
                  _AccentSwatch(
                    accent: accent,
                    label: _accentName(l10n, accent),
                    selected: controller.accent == accent,
                    onTap: () => controller.setAccent(accent),
                  ),
              ],
            ),
            SizedBox(height: context.spacing.xl),
            _SectionHeader(l10n.settingsAppearance),
            SizedBox(height: context.spacing.md),
            SegmentedButton<ThemeChoice>(
              segments: [
                ButtonSegment(
                  value: ThemeChoice.system,
                  icon: const Icon(Icons.brightness_auto),
                  label: Text(l10n.themeSystem),
                ),
                ButtonSegment(
                  value: ThemeChoice.light,
                  icon: const Icon(Icons.light_mode),
                  label: Text(l10n.themeLight),
                ),
                ButtonSegment(
                  value: ThemeChoice.dark,
                  icon: const Icon(Icons.dark_mode),
                  label: Text(l10n.themeDark),
                ),
              ],
              selected: {controller.themeChoice},
              showSelectedIcon: false,
              onSelectionChanged: (selection) =>
                  controller.setThemeChoice(selection.first),
            ),
          ],
        ),
      ),
    );
  }

  String _accentName(AppLocalizations l10n, AccentTheme accent) =>
      switch (accent) {
        AccentTheme.teal => l10n.accentTeal,
        AccentTheme.indigo => l10n.accentIndigo,
        AccentTheme.plum => l10n.accentPlum,
        AccentTheme.ocean => l10n.accentOcean,
      };
}

/// The [Profile] editor pinned at the top of Settings (#9): a required name and
/// an optional phone. Saving writes through the [ProfileController] (which
/// persists and notifies), so the name is available the next time a PDF export
/// asks for it. Local text controllers seed from the current profile.
class _ProfileSection extends StatefulWidget {
  const _ProfileSection({required this.controller});

  final ProfileController controller;

  @override
  State<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends State<_ProfileSection> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    final profile = widget.controller.profile;
    _name = TextEditingController(text: profile?.name ?? '');
    _phone = TextEditingController(text: profile?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final phone = _phone.text.trim();
    await widget.controller.save(
      name: _name.text,
      phone: phone.isEmpty ? null : phone,
    );
    if (mounted) FocusScope.of(context).unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionHeader(l10n.settingsProfile),
          SizedBox(height: spacing.md),
          TextFormField(
            key: const Key('profile-name-field'),
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: l10n.profileName,
              border: const OutlineInputBorder(),
            ),
            validator: (value) =>
                (value == null || value.trim().isEmpty) ? l10n.nameRequired : null,
          ),
          SizedBox(height: spacing.md),
          TextFormField(
            key: const Key('profile-phone-field'),
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: l10n.profilePhone,
              border: const OutlineInputBorder(),
            ),
          ),
          SizedBox(height: spacing.md),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: FilledButton(
              key: const Key('profile-save'),
              onPressed: _save,
              child: Text(l10n.save),
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: Theme.of(context).textTheme.titleMedium?.copyWith(
            color: Theme.of(context).colorScheme.primary,
          ),
    );
  }
}

/// A tappable circular colour chip for one accent. The selected chip carries a
/// ring + check. Tooltip/semantics use the localised accent name.
class _AccentSwatch extends StatelessWidget {
  const _AccentSwatch({
    required this.accent,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final AccentTheme accent;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(accent.seedValue);
    return Semantics(
      label: label,
      selected: selected,
      button: true,
      child: Tooltip(
        message: label,
        child: InkWell(
          key: Key('accent-${accent.code}'),
          onTap: onTap,
          customBorder: const CircleBorder(),
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
              border: selected
                  ? Border.all(
                      color: Theme.of(context).colorScheme.onSurface,
                      width: 3,
                    )
                  : null,
            ),
            child: selected
                ? const Icon(Icons.check, color: Colors.white)
                : null,
          ),
        ),
      ),
    );
  }
}
