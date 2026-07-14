import 'package:debt_ledger/domain/contact.dart';
import 'package:debt_ledger/domain/currency.dart';
import 'package:debt_ledger/domain/entry.dart';
import 'package:debt_ledger/domain/period.dart';
import 'package:debt_ledger/domain/profile.dart';
import 'package:debt_ledger/domain/statement.dart';
import 'package:debt_ledger/l10n/gen/app_localizations.dart';
import 'package:debt_ledger/presentation/statements/statement_pdf.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

Entry _entry(double amount, Direction direction, DateTime when, {int id = 0}) =>
    Entry(
      id: id,
      contactId: 1,
      amount: amount,
      direction: direction,
      currency: Currency.sar,
      createdAt: when,
      description: 'note $id',
    );

StatementDocument _doc({required bool isRtl}) => buildStatement(
      profile: const Profile(name: 'Ahmed', phone: '0555'),
      contact: const Contact(id: 1, name: 'Khaled', phone: '0999'),
      entries: [
        _entry(100, Direction.owedToMe, DateTime(2026, 1, 1), id: 1),
        _entry(30, Direction.owedByMe, DateTime(2026, 1, 2), id: 2),
      ],
      currency: Currency.sar,
      range: null,
      isRtl: isRtl,
    );

bool _isPdf(List<int> bytes) =>
    bytes.length > 5 && String.fromCharCodes(bytes.take(5)) == '%PDF-';

void main() {
  testWidgets('renders a valid PDF for an LTR (English) statement', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));

    final bytes = await renderStatementPdf(_doc(isRtl: false), l10n, 'en');

    expect(bytes, isNotEmpty);
    expect(_isPdf(bytes), isTrue);
  });

  testWidgets('renders a valid PDF for an RTL (Arabic) statement', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));

    final bytes = await renderStatementPdf(_doc(isRtl: true), l10n, 'ar');

    expect(bytes, isNotEmpty);
    expect(_isPdf(bytes), isTrue);
  });

  testWidgets('renders an empty ledger without throwing', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    final doc = buildStatement(
      profile: const Profile(name: 'Ahmed'),
      contact: const Contact(id: 1, name: 'Khaled'),
      entries: const [],
      currency: Currency.sar,
      range: null,
      isRtl: false,
    );

    final bytes = await renderStatementPdf(doc, l10n, 'en');

    expect(_isPdf(bytes), isTrue);
  });

  testWidgets('renders a valid PDF for a filtered RTL statement', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('ar'));
    final doc = buildStatement(
      profile: const Profile(name: 'Ahmed'),
      contact: const Contact(id: 1, name: 'Khaled'),
      entries: [_entry(100, Direction.owedToMe, DateTime(2026, 7, 5), id: 1)],
      currency: Currency.sar,
      range: DateRange(DateTime(2026, 7, 1), DateTime(2026, 8, 1)),
      isRtl: true,
    );
    final bytes = await renderStatementPdf(doc, l10n, 'ar');
    expect(_isPdf(bytes), isTrue);
  });
}
