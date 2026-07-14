import 'package:flutter/material.dart';

import '../../domain/accent_theme.dart';
import '../../domain/currency.dart';
import '../../domain/language_choice.dart';
import '../../domain/theme_choice.dart';
import '../../l10n/gen/app_localizations.dart';
import '../currency/currency_controller.dart';
import '../locale/locale_controller.dart';
import '../profile/profile_controller.dart';
import '../theme/theme_context.dart';
import '../theme/theme_controller.dart';
import 'backup_restore_section.dart';

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
    this.currencyController,
    this.localeController,
    this.onEraseAllData,
    this.backup,
  });

  final ThemeController controller;
  final ProfileController? profileController;

  /// Drives the default-currency control (ADR 0007). The Preferences section
  /// renders only when both this and [localeController] are supplied — focused
  /// theme tests can still pump the screen bare.
  final CurrencyController? currencyController;
  final LocaleController? localeController;

  /// Factory reset (#25). When supplied, a destructive Data section appears
  /// with a type-to-confirm Erase-all-data flow that calls this. When null the
  /// section is hidden (focused theme tests are unaffected).
  final Future<void> Function()? onEraseAllData;

  /// Backup & restore (#26). When supplied, the Backup section renders; null in
  /// focused theme tests, which then hide it.
  final BackupSectionConfig? backup;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.settingsTitle)),
      body: ListenableBuilder(
        listenable: Listenable.merge([
          controller,
          ?currencyController,
          ?localeController,
        ]),
        builder: (context, _) => ListView(
          padding: EdgeInsets.all(context.spacing.lg),
          children: [
            if (profileController != null) ...[
              _ProfileSection(controller: profileController!),
              SizedBox(height: context.spacing.xl),
            ],
            if (currencyController != null && localeController != null) ...[
              _SectionHeader(l10n.settingsPreferences),
              SizedBox(height: context.spacing.md),
              _PreferencesSection(
                currencyController: currencyController!,
                localeController: localeController!,
              ),
              SizedBox(height: context.spacing.xl),
            ],
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
            SizedBox(height: context.spacing.xl),
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
            if (backup != null) ...[
              SizedBox(height: context.spacing.xl),
              BackupRestoreSection(config: backup!),
            ],
            if (onEraseAllData != null) ...[
              SizedBox(height: context.spacing.xl),
              _SectionHeader(l10n.settingsData),
              SizedBox(height: context.spacing.sm),
              ListTile(
                key: const Key('erase-all-data'),
                contentPadding: EdgeInsets.zero,
                leading: Icon(
                  Icons.delete_forever,
                  color: Theme.of(context).colorScheme.error,
                ),
                title: Text(
                  l10n.eraseAllData,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
                subtitle: Text(l10n.eraseAllDataSubtitle),
                onTap: () => _confirmErase(context, l10n, onEraseAllData!),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Type-to-confirm factory reset. The confirm button stays disabled until the
  /// user types [AppLocalizations.eraseConfirmWord]; on confirm it runs [onErase]
  /// then pops Settings back to home. The gate lives in a [StatefulBuilder] so
  /// only the dialog rebuilds as the user types.
  Future<void> _confirmErase(
    BuildContext context,
    AppLocalizations l10n,
    Future<void> Function() onErase,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        var typed = '';
        return StatefulBuilder(
          builder: (context, setLocal) => AlertDialog(
            title: Text(l10n.eraseAllDataTitle),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(l10n.eraseAllDataMessage(l10n.eraseConfirmWord)),
                SizedBox(height: context.spacing.md),
                TextField(
                  key: const Key('erase-confirm-field'),
                  autofocus: true,
                  onChanged: (value) => setLocal(() => typed = value),
                  decoration: InputDecoration(
                    border: const OutlineInputBorder(),
                    hintText: l10n.eraseConfirmWord,
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: Text(l10n.cancel),
              ),
              TextButton(
                key: const Key('erase-confirm'),
                onPressed: typed.trim() == l10n.eraseConfirmWord
                    ? () => Navigator.of(context).pop(true)
                    : null,
                child: Text(l10n.erase),
              ),
            ],
          ),
        );
      },
    );
    if (confirmed != true) return;
    await onErase();
    // Return to home, which has refetched its now-empty data.
    if (context.mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }
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

/// The behavioral defaults (ADR 0007): a default-currency segmented control and
/// an app-language segmented control (endonym labels). Both write through their
/// controllers, which persist and live-apply. Segments carry explicit keys —
/// their plain SAR/YER/System texts collide with the bottom lens and the theme
/// "System" segment.
class _PreferencesSection extends StatelessWidget {
  const _PreferencesSection({
    required this.currencyController,
    required this.localeController,
  });

  final CurrencyController currencyController;
  final LocaleController localeController;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final spacing = context.spacing;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(l10n.settingsDefaultCurrency,
            style: Theme.of(context).textTheme.bodyMedium),
        SizedBox(height: spacing.sm),
        SegmentedButton<Currency>(
          segments: [
            for (final currency in Currency.values)
              ButtonSegment(
                value: currency,
                label: Text(currency.code, key: Key('currency-${currency.code}')),
              ),
          ],
          selected: {currencyController.defaultCurrency},
          showSelectedIcon: false,
          onSelectionChanged: (selection) =>
              currencyController.setDefault(selection.first),
        ),
        SizedBox(height: spacing.lg),
        Text(l10n.settingsLanguage,
            style: Theme.of(context).textTheme.bodyMedium),
        SizedBox(height: spacing.sm),
        SegmentedButton<LanguageChoice>(
          segments: [
            ButtonSegment(
              value: LanguageChoice.system,
              label: Text(l10n.languageSystem, key: const Key('language-system')),
            ),
            ButtonSegment(
              value: LanguageChoice.arabic,
              label: Text(l10n.languageArabic, key: const Key('language-ar')),
            ),
            ButtonSegment(
              value: LanguageChoice.english,
              label: Text(l10n.languageEnglish, key: const Key('language-en')),
            ),
          ],
          selected: {localeController.languageChoice},
          showSelectedIcon: false,
          onSelectionChanged: (selection) =>
              localeController.setLanguageChoice(selection.first),
        ),
      ],
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
