import 'package:flutter/material.dart';

import '../../domain/profile.dart';
import '../../l10n/gen/app_localizations.dart';
import 'profile_controller.dart';

/// The single seam between the [Profile] (#9) and the PDF export (#10): make
/// sure a creditor name exists, asking for it exactly once.
///
/// If a name is already set, returns the current [Profile] immediately with no
/// UI. Otherwise it shows a modal dialog collecting just the name (trimmed;
/// blank re-prompts); on save it persists via [controller] and returns the
/// resulting [Profile], on cancel it returns `null` (the caller aborts the
/// export). Because the name is stored the first time, a later call never
/// prompts again.
Future<Profile?> ensureProfileName(
  BuildContext context,
  ProfileController controller,
) async {
  final existing = controller.profile;
  if (existing != null) return existing;

  final name = await showDialog<String>(
    context: context,
    builder: (_) => const _ProfileNamePromptDialog(),
  );
  if (name == null) return null; // cancelled — abort the export

  await controller.setName(name);
  return controller.profile;
}

/// Modal that collects the owner's name on first export. Pops the entered name
/// on save, or `null` on cancel.
class _ProfileNamePromptDialog extends StatefulWidget {
  const _ProfileNamePromptDialog();

  @override
  State<_ProfileNamePromptDialog> createState() =>
      _ProfileNamePromptDialogState();
}

class _ProfileNamePromptDialogState extends State<_ProfileNamePromptDialog> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_name.text);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return AlertDialog(
      title: Text(l10n.profileNamePromptTitle),
      content: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.profileNamePromptMessage),
            const SizedBox(height: 16),
            TextFormField(
              key: const Key('profile-name-prompt-field'),
              controller: _name,
              autofocus: true,
              textInputAction: TextInputAction.done,
              onFieldSubmitted: (_) => _submit(),
              decoration: InputDecoration(
                labelText: l10n.profileName,
                border: const OutlineInputBorder(),
              ),
              validator: (value) => (value == null || value.trim().isEmpty)
                  ? l10n.nameRequired
                  : null,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          key: const Key('profile-name-prompt-save'),
          onPressed: _submit,
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
