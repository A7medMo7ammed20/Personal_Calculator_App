import 'package:flutter/material.dart';

import '../../data/contact_repository.dart';
import '../../data/entry_repository.dart';
import '../../domain/contact.dart';
import '../../l10n/gen/app_localizations.dart';
import '../contacts/add_contact_screen.dart';
import '../contacts/contact_screen.dart';

/// Home screen: the Contact list plus a button to add one. Later slices add the
/// currency lens, period filter and grand-total header.
class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.repository,
    required this.entryRepository,
  });

  final ContactRepository repository;
  final EntryRepository entryRepository;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<Contact>> _contacts;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _load() {
    _contacts = widget.repository.list();
  }

  Future<void> _addContact() async {
    final saved = await Navigator.of(context).push<Contact>(
      MaterialPageRoute(
        builder: (_) => AddContactScreen(repository: widget.repository),
      ),
    );
    if (saved != null && mounted) {
      setState(_load);
    }
  }

  Future<void> _openContact(Contact contact) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ContactScreen(
          contact: contact,
          repository: widget.entryRepository,
        ),
      ),
    );
    // Refresh on return; a later slice surfaces the per-Contact balance here.
    if (mounted) setState(_load);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.appTitle)),
      body: FutureBuilder<List<Contact>>(
        future: _contacts,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          final contacts = snapshot.data ?? const [];
          if (contacts.isEmpty) {
            return Center(
              child: Text(
                l10n.homeEmpty,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            );
          }
          return ListView.builder(
            itemCount: contacts.length,
            itemBuilder: (context, index) {
              final contact = contacts[index];
              return ListTile(
                leading: CircleAvatar(child: Text(_initial(contact.name))),
                title: Text(contact.name),
                subtitle: contact.phone == null ? null : Text(contact.phone!),
                onTap: () => _openContact(contact),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addContact,
        tooltip: l10n.addContact,
        child: const Icon(Icons.person_add),
      ),
    );
  }

  String _initial(String name) {
    final trimmed = name.trim();
    return trimmed.isEmpty ? '?' : trimmed.characters.first.toUpperCase();
  }
}
