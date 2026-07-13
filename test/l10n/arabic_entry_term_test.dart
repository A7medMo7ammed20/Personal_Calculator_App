import 'package:debt_ledger/l10n/gen/app_localizations_ar.dart';
import 'package:flutter_test/flutter_test.dart';

// The Entry label was retired from حركة to معاملة (CONTEXT.md — Entry; ADR 0005),
// because حركة was overloaded with Flow (الحركة) and read as meaningless. These
// guard that the Arabic Entry strings say معاملة and never fall back to حركة.
void main() {
  final ar = AppLocalizationsAr();

  test('Add / edit / delete Entry strings use معاملة, not حركة', () {
    expect(ar.addEntry, contains('معاملة'));
    expect(ar.editEntry, contains('معاملة'));
    expect(ar.deleteEntryTitle, contains('معاملة'));
    expect(ar.deleteEntryMessage, contains('معاملة'));
    expect(ar.entryDeleted, contains('معاملة'));
    expect(ar.contactEntriesEmpty, contains('معاملات'));

    for (final s in [
      ar.addEntry,
      ar.editEntry,
      ar.deleteEntryTitle,
      ar.deleteEntryMessage,
      ar.entryDeleted,
      ar.contactEntriesEmpty,
    ]) {
      expect(s, isNot(contains('حركة')), reason: '"$s" still uses حركة');
      expect(s, isNot(contains('حركات')), reason: '"$s" still uses حركات');
    }
  });

  test('The cascade delete-count message pluralises معاملة', () {
    expect(ar.deleteContactMessage(1), contains('معاملة واحدة'));
    expect(ar.deleteContactMessage(2), contains('معاملتان'));
    expect(ar.deleteContactMessage(5), contains('معاملات'));
    expect(ar.deleteContactMessage(2), isNot(contains('حرك')));
  });
}
