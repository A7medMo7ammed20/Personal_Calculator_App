import 'dart:typed_data';

import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../domain/balance.dart';
import '../../domain/statement.dart';
import '../../domain/statement_period.dart';
import '../../l10n/gen/app_localizations.dart';
import '../money_format.dart';

/// Renders a [StatementDocument] into PDF bytes (ADR 0006). The thin seam
/// between the pure model and the `pdf`/`printing` toolchain: it reads the model
/// and localized [l10n]/[localeName] into `pw.*` widgets — no balance logic
/// lives here.
///
/// Arabic renders right-to-left with automatic glyph shaping by embedding the
/// bundled IBM Plex Sans Arabic TTF and setting the page [pw.TextDirection] from
/// [StatementDocument.isRtl]; the Latin family is kept as a fallback (and vice
/// versa) so a mixed-script name or the Latin money digits always have glyphs.
Future<Uint8List> renderStatementPdf(
  StatementDocument doc,
  AppLocalizations l10n,
  String localeName,
) async {
  // Ensure the requested locale's date symbols exist (idempotent). In the app
  // flutter_localizations has already done this; doing it here keeps the
  // renderer self-contained and testable in isolation.
  await initializeDateFormatting(localeName);

  final latin = await fontFromAssetBundle('assets/fonts/IBMPlexSans-Regular.ttf');
  final latinBold =
      await fontFromAssetBundle('assets/fonts/IBMPlexSans-Bold.ttf');
  final arabic =
      await fontFromAssetBundle('assets/fonts/IBMPlexSansArabic-Regular.ttf');
  final arabicBold =
      await fontFromAssetBundle('assets/fonts/IBMPlexSansArabic-Bold.ttf');

  final theme = pw.ThemeData.withFont(
    base: doc.isRtl ? arabic : latin,
    bold: doc.isRtl ? arabicBold : latinBold,
    fontFallback: [arabic, latin, arabicBold, latinBold],
  );

  final pdf = pw.Document(theme: theme);
  final dateFormat = DateFormat.yMMMd(localeName);
  String money(double v) => formatMoney(v, doc.currency);

  // Balance shown as a coloured magnitude with a leading minus for owed-by-me,
  // so the direction survives a black-and-white print (colour + sign, not
  // colour alone). Settled reads as a neutral zero.
  PdfColor balanceColor(Balance b) => b.isSettled
      ? PdfColors.grey600
      : (b.isOwedToMe ? PdfColors.green800 : PdfColors.red800);
  String balanceAmount(Balance b) =>
      (b.isOwedByMe ? '−' : '') + money(b.magnitude);

  // The long-form directional label reused from the app (owes you / you owe /
  // settled) for the opening and closing summary lines.
  String balanceLabel(Balance b) {
    if (b.isSettled) return l10n.balanceSettled;
    final amount = money(b.magnitude);
    return b.isOwedToMe
        ? l10n.balanceOwedToMe(amount)
        : l10n.balanceOwedByMe(amount);
  }

  pdf.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      textDirection: doc.isRtl ? pw.TextDirection.rtl : pw.TextDirection.ltr,
      margin: const pw.EdgeInsets.all(28),
      build: (context) => [
        _header(doc, l10n, dateFormat),
        pw.SizedBox(height: 16),
        if (doc.dateRange != null)
          pw.Padding(
            padding: const pw.EdgeInsets.only(bottom: 8),
            child: pw.Text(
              '${l10n.statementOpeningBalance}: ${balanceLabel(doc.openingBalance)}',
              style: pw.TextStyle(
                color: balanceColor(doc.openingBalance),
                fontWeight: pw.FontWeight.bold,
              ),
            ),
          ),
        _entriesTable(
          doc,
          l10n,
          dateFormat,
          money: money,
          balanceAmount: balanceAmount,
          balanceColor: balanceColor,
        ),
        pw.SizedBox(height: 16),
        _closing(doc, l10n, balanceLabel, balanceColor),
      ],
    ),
  );

  return pdf.save();
}

pw.Widget _cell(
  String text, {
  PdfColor? color,
  pw.TextAlign? align,
  bool bold = false,
}) =>
    pw.Padding(
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      child: pw.Text(
        text,
        textAlign: align,
        style: pw.TextStyle(
          color: color,
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    );

pw.Widget _header(
  StatementDocument doc,
  AppLocalizations l10n,
  DateFormat dateFormat,
) {
  final period = statementPeriodLabel(
    range: doc.dateRange,
    dateFormat: dateFormat,
    allTimeLabel: l10n.periodAllTime,
  );
  final to = doc.contactPhone == null
      ? doc.contactName
      : '${doc.contactName} · ${doc.contactPhone}';
  return pw.Column(
    crossAxisAlignment: pw.CrossAxisAlignment.start,
    children: [
      pw.Text(
        l10n.statementTitle,
        style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold),
      ),
      pw.SizedBox(height: 8),
      pw.Text('${l10n.statementFrom}: ${doc.creditorName}'),
      pw.Text('${l10n.statementTo}: $to'),
      pw.Text(doc.currency.code),
      pw.Text('${l10n.statementPeriod}: $period'),
    ],
  );
}

pw.Widget _entriesTable(
  StatementDocument doc,
  AppLocalizations l10n,
  DateFormat dateFormat, {
  required String Function(double) money,
  required String Function(Balance) balanceAmount,
  required PdfColor Function(Balance) balanceColor,
}) {
  final rows = <pw.TableRow>[
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey200),
      children: [
        _cell(l10n.statementDateColumn, bold: true),
        _cell(l10n.statementDescriptionColumn, bold: true),
        _cell(l10n.directionOwedToMe, align: pw.TextAlign.end, bold: true),
        _cell(l10n.directionOwedByMe, align: pw.TextAlign.end, bold: true),
        _cell(l10n.statementBalanceColumn, align: pw.TextAlign.end, bold: true),
      ],
    ),
    for (final r in doc.rows)
      pw.TableRow(
        children: [
          _cell(dateFormat.format(r.date)),
          _cell(r.description ?? ''),
          _cell(r.owedToMe == null ? '' : money(r.owedToMe!),
              align: pw.TextAlign.end),
          _cell(r.owedByMe == null ? '' : money(r.owedByMe!),
              align: pw.TextAlign.end),
          _cell(balanceAmount(r.balance),
              color: balanceColor(r.balance), align: pw.TextAlign.end),
        ],
      ),
    // Footer row: label in the description cell, gross totals under their columns,
    // and the closing balance terminating the balance column (ADR 0009).
    pw.TableRow(
      decoration: const pw.BoxDecoration(color: PdfColors.grey100),
      children: [
        _cell(''),
        _cell(l10n.statementTotal, bold: true),
        _cell(money(doc.totalOwedToMe), align: pw.TextAlign.end, bold: true),
        _cell(money(doc.totalOwedByMe), align: pw.TextAlign.end, bold: true),
        _cell(
          balanceAmount(doc.closingBalance),
          color: balanceColor(doc.closingBalance),
          align: pw.TextAlign.end,
          bold: true,
        ),
      ],
    ),
  ];

  return pw.Table(
    border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.5),
    columnWidths: const {
      0: pw.FlexColumnWidth(2.2),
      1: pw.FlexColumnWidth(3),
      2: pw.FlexColumnWidth(2),
      3: pw.FlexColumnWidth(2),
      4: pw.FlexColumnWidth(2.2),
    },
    children: rows,
  );
}

pw.Widget _closing(
  StatementDocument doc,
  AppLocalizations l10n,
  String Function(Balance) balanceLabel,
  PdfColor Function(Balance) balanceColor,
) {
  return pw.Container(
    alignment: pw.Alignment.centerRight,
    child: pw.Text(
      '${l10n.statementClosingBalance}: ${balanceLabel(doc.closingBalance)}',
      style: pw.TextStyle(
        fontSize: 14,
        fontWeight: pw.FontWeight.bold,
        color: balanceColor(doc.closingBalance),
      ),
    ),
  );
}
