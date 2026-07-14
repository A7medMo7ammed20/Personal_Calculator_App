import 'package:flutter/material.dart';

import '../../data/contact_repository.dart';
import '../../data/entry_repository.dart';
import '../../domain/contact.dart';
import '../../domain/currency.dart';
import '../../l10n/gen/app_localizations.dart';
import '../profile/profile_controller.dart';
import 'contact_screen.dart';

/// The Archived contacts view (#25): people set aside via the Contact overflow
/// menu. They keep their full ledger but stay out of the active list, grand
/// totals and analysis. Opening a row shows their [ContactScreen] (booking an
/// entry there auto-unarchives them); an inline Unarchive restores them here.
class ArchivedContactsScreen extends StatefulWidget {
  const ArchivedContactsScreen({
    super.key,
    required this.contactRepository,
    required this.entryRepository,
    required this.currency,
    this.profileController,
  });

  final ContactRepository contactRepository;
  final EntryRepository entryRepository;
  final Currency currency;
  final ProfileController? profileController;

  @override
  State<ArchivedContactsScreen> createState() => _ArchivedContactsScreenState();
}

class _ArchivedContactsScreenState extends State<ArchivedContactsScreen> {
  late Future<List<Contact>> _archived;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _archived = widget.contactRepository.listArchived();
  }

  Future<void> _unarchive(Contact contact) async {
    await widget.contactRepository.setArchived(contact.id!, archived: false);
    if (mounted) setState(_load);
  }

  Future<void> _open(Contact contact) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactScreen(
          contact: contact,
          repository: widget.entryRepository,
          currency: widget.currency,
          profileController: widget.profileController,
          contactRepository: widget.contactRepository,
          onArchivedChanged: (_) {
            if (mounted) setState(_load);
          },
        ),
      ),
    );
    // A new entry there may have auto-unarchived them — refresh on return.
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.archivedTitle)),
      body: FutureBuilder<List<Contact>>(
        future: _archived,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final archived = snapshot.data ?? const <Contact>[];
          if (archived.isEmpty) {
            return Center(
              child: Text(
                l10n.archivedEmpty,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }
          return ListView.builder(
            itemCount: archived.length,
            itemBuilder: (context, index) {
              final contact = archived[index];
              return ListTile(
                leading: CircleAvatar(child: Text(_initial(contact.name))),
                title: Text(contact.name),
                onTap: () => _open(contact),
                trailing: TextButton(
                  key: Key('unarchive-${contact.id}'),
                  onPressed: () => _unarchive(contact),
                  child: Text(l10n.unarchive),
                ),
              );
            },
          );
        },
      ),
    );
  }

  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }
}
