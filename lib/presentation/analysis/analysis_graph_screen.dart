import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../data/contact_repository.dart';
import '../../data/entry_repository.dart';
import '../../domain/analysis_graph.dart';
import '../../domain/balance.dart';
import '../../domain/currency.dart';
import '../../domain/entry.dart';
import '../../domain/period.dart';
import '../../l10n/gen/app_localizations.dart';
import '../money_format.dart';
import '../theme/theme_context.dart';
import '../widgets/period_selector.dart';

/// The two ways to read the same currency lens (#8): the cumulative net-balance
/// line **over time**, or the all-time net balance **by contact** as diverging
/// bars. See ADR 0004.
enum _ChartType { overTime, byContact }

/// The lens + period the graph hands back to home on pop, so home adopts any
/// change made here. See ADR 0004 (return-on-pop, no lifted controller).
class AnalysisGraphResult {
  const AnalysisGraphResult({
    required this.currency,
    required this.period,
    this.customStart,
    this.customEnd,
  });

  final Currency currency;
  final PeriodOption period;
  final DateTime? customStart;
  final DateTime? customEnd;
}

/// Everything one lens+period load needs to render either chart, fetched
/// together so toggling chart type is a pure `setState` with no re-query.
class _AnalysisData {
  const _AnalysisData({
    required this.series,
    required this.bars,
    required this.names,
  });

  /// Per-entry cumulative points for the over-time line (windowed by period).
  final List<BalancePoint> series;

  /// All-time per-contact balances for the by-contact bars (never windowed).
  final List<ContactBalance> bars;

  /// Contact id → display name, for bar labels and the drill-down sheet.
  final Map<int, String> names;
}

/// The Analysis graph (#8): two views on the per-currency net [[Balance]] across
/// all Contacts — a per-entry cumulative line **over time** (windowed by the
/// period filter, carrying in the opening balance) and an all-time **by-contact**
/// diverging bar chart. A segmented toggle switches between them. All maths lives
/// in the pure `runningBalanceSeries` / `contactBalancesSorted` seams; this screen
/// loads, hosts the controls, and renders. See CONTEXT.md and ADR 0004.
class AnalysisGraphScreen extends StatefulWidget {
  const AnalysisGraphScreen({
    super.key,
    required this.entryRepository,
    required this.contactRepository,
    required this.currency,
    required this.period,
    this.customStart,
    this.customEnd,
  });

  final EntryRepository entryRepository;
  final ContactRepository contactRepository;
  final Currency currency;
  final PeriodOption period;
  final DateTime? customStart;
  final DateTime? customEnd;

  @override
  State<AnalysisGraphScreen> createState() => _AnalysisGraphScreenState();
}

class _AnalysisGraphScreenState extends State<AnalysisGraphScreen> {
  late Currency _currency = widget.currency;
  late PeriodOption _period = widget.period;
  late DateTime? _customStart = widget.customStart;
  late DateTime? _customEnd = widget.customEnd;
  _ChartType _chartType = _ChartType.overTime;

  bool _loaded = false;
  late Future<_AnalysisData> _data;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_loaded) {
      _reload();
      _loaded = true;
    }
  }

  void _reload() {
    _data = _load();
  }

  Future<_AnalysisData> _load() async {
    final entries = await widget.entryRepository.listByCurrency(_currency);
    final balances = await widget.entryRepository.balancesByCurrency(_currency);
    final contacts = await widget.contactRepository.list();
    final names = {for (final c in contacts) c.id!: c.name};
    final now = DateTime.now();
    final range = resolvePeriod(
      _period,
      now,
      customStart: _customStart,
      customEnd: _customEnd,
    );
    return _AnalysisData(
      series: runningBalanceSeries(entries, range: range),
      bars: contactBalancesSorted(balances),
      names: names,
    );
  }

  AnalysisGraphResult get _result => AnalysisGraphResult(
    currency: _currency,
    period: _period,
    customStart: _customStart,
    customEnd: _customEnd,
  );

  void _selectCurrency(Currency currency) {
    if (currency == _currency) return;
    setState(() {
      _currency = currency;
      _reload();
    });
  }

  void _selectChartType(_ChartType type) {
    if (type == _chartType) return;
    setState(() => _chartType = type);
  }

  Future<void> _selectPeriod(PeriodOption option) async {
    if (option == PeriodOption.custom) {
      final picked = await showDateRangePicker(
        context: context,
        firstDate: DateTime(2000),
        lastDate: DateTime(DateTime.now().year + 1, 12, 31),
        initialDateRange: _customStart != null && _customEnd != null
            ? DateTimeRange(start: _customStart!, end: _customEnd!)
            : null,
      );
      if (picked == null) return; // cancelled — keep the current period
      setState(() {
        _period = PeriodOption.custom;
        _customStart = picked.start;
        _customEnd = picked.end;
        _reload();
      });
      return;
    }
    setState(() {
      _period = option;
      _reload();
    });
  }

  void _openEntryDetail(BalancePoint point, Map<int, String> names) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _EntryDetailSheet(
        entry: point.entry,
        contactName: names[point.entry.contactId] ?? '#${point.entry.contactId}',
        currency: _currency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final overTime = _chartType == _ChartType.overTime;
    // Return-on-pop: intercept the pop so home receives the (possibly changed)
    // lens + period. canPop:false lets us pop with a result ourselves.
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        Navigator.of(context).pop(_result);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(l10n.analysisTitle),
          actions: [
            // The period only windows the over-time line; the by-contact bars
            // are all-time, so the chip is hidden there.
            if (overTime)
              PeriodSelector(period: _period, onSelected: _selectPeriod),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: SegmentedButton<Currency>(
                segments: [
                  for (final c in Currency.values)
                    ButtonSegment(value: c, label: Text(c.code)),
                ],
                selected: {_currency},
                showSelectedIcon: false,
                onSelectionChanged: (s) => _selectCurrency(s.first),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
              child: SegmentedButton<_ChartType>(
                segments: [
                  ButtonSegment(
                    value: _ChartType.overTime,
                    icon: const Icon(Icons.show_chart),
                    label: Text(l10n.chartOverTime),
                  ),
                  ButtonSegment(
                    value: _ChartType.byContact,
                    icon: const Icon(Icons.bar_chart),
                    label: Text(l10n.chartByContact),
                  ),
                ],
                selected: {_chartType},
                showSelectedIcon: false,
                onSelectionChanged: (s) => _selectChartType(s.first),
              ),
            ),
            Expanded(
              child: FutureBuilder<_AnalysisData>(
                future: _data,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final data = snapshot.data;
                  final hasData = data != null &&
                      (overTime ? data.series.isNotEmpty : data.bars.isNotEmpty);
                  if (!hasData) {
                    return Center(
                      child: Text(
                        l10n.analysisEmpty(_currency.code),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    );
                  }
                  if (overTime) {
                    return Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                      child: _OverTimeChart(
                        points: data.series,
                        currency: _currency,
                        onTapPoint: (p) => _openEntryDetail(p, data.names),
                      ),
                    );
                  }
                  return _ByContactChart(
                    bars: data.bars,
                    names: data.names,
                    currency: _currency,
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The windowed per-entry line, hand-painted (ADR 0004 — no charting dependency).
/// Owns the x-scale so tap hit-testing is a straight nearest-point search.
class _OverTimeChart extends StatelessWidget {
  const _OverTimeChart({
    required this.points,
    required this.currency,
    required this.onTapPoint,
  });

  final List<BalancePoint> points;
  final Currency currency;
  final ValueChanged<BalancePoint> onTapPoint;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final locale = Localizations.localeOf(context).toString();
    final lineColor = theme.colorScheme.primary;
    final gridColor = theme.colorScheme.outlineVariant;
    final labelStyle = theme.textTheme.labelSmall?.copyWith(
      color: theme.colorScheme.onSurfaceVariant,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = Size(constraints.maxWidth, constraints.maxHeight);
        final geometry = _ChartGeometry(size: size, points: points, isRtl: isRtl);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: (details) {
            final point = geometry.nearest(details.localPosition);
            if (point != null) onTapPoint(point);
          },
          child: CustomPaint(
            size: size,
            painter: _LinePainter(
              geometry: geometry,
              currency: currency,
              locale: locale,
              lineColor: lineColor,
              gridColor: gridColor,
              labelStyle: labelStyle,
            ),
          ),
        );
      },
    );
  }
}

/// Pure layout: maps [points] to screen [offsets] within a plot rect, honouring
/// RTL (oldest on the right). Points are spaced evenly **by index** so a cluster
/// of same-timestamp entries never overlaps. Shared by the painter and the tap
/// hit-test so they never disagree.
class _ChartGeometry {
  _ChartGeometry({
    required this.size,
    required this.points,
    required this.isRtl,
  }) {
    var lo = 0.0, hi = 0.0; // always include the zero baseline
    for (final p in points) {
      lo = math.min(lo, p.balance.signed);
      hi = math.max(hi, p.balance.signed);
    }
    if (lo == hi) hi = lo + 1; // avoid a zero-height range
    // A little headroom top and bottom so the line never glues to an edge.
    final pad = (hi - lo) * 0.12;
    minY = lo - pad;
    maxY = hi + pad;
    plot = Rect.fromLTRB(
      _padLeft,
      _padTop,
      size.width - _padRight,
      size.height - _padBottom,
    );
    offsets = [
      for (var i = 0; i < points.length; i++)
        Offset(_xForIndex(i), _yForValue(points[i].balance.signed)),
    ];
  }

  static const double _padLeft = 4;
  static const double _padRight = 4;
  static const double _padTop = 20;
  static const double _padBottom = 22;

  final Size size;
  final List<BalancePoint> points;
  final bool isRtl;

  late final double minY;
  late final double maxY;
  late final Rect plot;
  late final List<Offset> offsets;

  double _xForIndex(int i) {
    final n = points.length;
    final t = n == 1 ? 0.5 : i / (n - 1);
    return isRtl ? plot.right - t * plot.width : plot.left + t * plot.width;
  }

  double _yForValue(double value) {
    final t = (value - minY) / (maxY - minY);
    return plot.bottom - t * plot.height;
  }

  double get zeroY => _yForValue(0);

  /// The point whose x is nearest [pos] — the drill-down target.
  BalancePoint? nearest(Offset pos) {
    if (points.isEmpty) return null;
    var best = 0;
    var bestDx = double.infinity;
    for (var i = 0; i < offsets.length; i++) {
      final dx = (offsets[i].dx - pos.dx).abs();
      if (dx < bestDx) {
        bestDx = dx;
        best = i;
      }
    }
    return points[best];
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required this.geometry,
    required this.currency,
    required this.locale,
    required this.lineColor,
    required this.gridColor,
    this.labelStyle,
  });

  final _ChartGeometry geometry;
  final Currency currency;
  final String locale;
  final Color lineColor;
  final Color gridColor;
  final TextStyle? labelStyle;

  @override
  void paint(Canvas canvas, Size size) {
    final plot = geometry.plot;

    // Zero baseline, only when the line actually crosses zero.
    if (geometry.minY < 0 && geometry.maxY > 0) {
      final zeroPaint = Paint()
        ..color = gridColor
        ..strokeWidth = 1;
      final y = geometry.zeroY;
      canvas.drawLine(Offset(plot.left, y), Offset(plot.right, y), zeroPaint);
    }

    final offsets = geometry.offsets;

    // A faint fill under the line, then the line, then dot markers.
    if (offsets.length > 1) {
      final fill = Path()..moveTo(offsets.first.dx, geometry.zeroY);
      for (final o in offsets) {
        fill.lineTo(o.dx, o.dy);
      }
      fill.lineTo(offsets.last.dx, geometry.zeroY);
      fill.close();
      canvas.drawPath(fill, Paint()..color = lineColor.withValues(alpha: 0.08));
    }

    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;
    final line = Path();
    for (var i = 0; i < offsets.length; i++) {
      final o = offsets[i];
      if (i == 0) {
        line.moveTo(o.dx, o.dy);
      } else {
        line.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(line, linePaint);

    final dotPaint = Paint()..color = lineColor;
    for (final o in offsets) {
      canvas.drawCircle(o, 2.5, dotPaint);
    }

    // Y extents (top = max, bottom = min) on the leading edge, kept inside the
    // plot so they never collide with the date row beneath it.
    _paintLabel(canvas, _money(geometry.maxY), Offset(plot.left, 2),
        align: _Align.start);
    _paintLabel(canvas, _money(geometry.minY),
        Offset(plot.left, plot.bottom - 14), align: _Align.start);

    // X extents: first and last entry dates in the strip below the plot.
    final first = geometry.points.first.entry.createdAt;
    final last = geometry.points.last.entry.createdAt;
    final leftLabel = geometry.isRtl ? _date(last) : _date(first);
    final rightLabel = geometry.isRtl ? _date(first) : _date(last);
    final dateY = size.height - 14;
    _paintLabel(canvas, leftLabel, Offset(plot.left, dateY), align: _Align.start);
    _paintLabel(canvas, rightLabel, Offset(plot.right, dateY), align: _Align.end);
  }

  String _money(double v) => formatMoney(v.abs(), currency);
  String _date(DateTime d) => DateFormat.MMMd(locale).format(d);

  void _paintLabel(Canvas canvas, String text, Offset at, {required _Align align}) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: labelStyle),
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      _Align.start => at.dx,
      _Align.end => at.dx - tp.width,
    };
    tp.paint(canvas, Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) =>
      old.geometry != geometry ||
      old.lineColor != lineColor ||
      old.currency != currency;
}

enum _Align { start, end }

/// The all-time by-contact view: one diverging bar per contact around a centre
/// zero line — green growing toward owed-to-me, red toward owed-by-me — sorted by
/// magnitude. Built from plain widgets (no charting dependency; ADR 0004) so
/// labels, RTL, and hit-testing come for free.
class _ByContactChart extends StatelessWidget {
  const _ByContactChart({
    required this.bars,
    required this.names,
    required this.currency,
  });

  final List<ContactBalance> bars;
  final Map<int, String> names;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final maxMagnitude = bars.fold<double>(
      0,
      (m, b) => math.max(m, b.balance.magnitude),
    );
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      itemCount: bars.length,
      separatorBuilder: (_, _) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final bar = bars[index];
        return _ContactBar(
          name: names[bar.contactId] ?? '#${bar.contactId}',
          balance: bar.balance,
          fraction: maxMagnitude == 0 ? 0 : bar.balance.magnitude / maxMagnitude,
          currency: currency,
        );
      },
    );
  }
}

/// A single diverging bar: the contact name and signed amount above, a track
/// split at the centre with the bar growing right (owed-to-me, green) or left
/// (owed-by-me, red) proportionally to [fraction] of the largest balance.
class _ContactBar extends StatelessWidget {
  const _ContactBar({
    required this.name,
    required this.balance,
    required this.fraction,
    required this.currency,
  });

  final String name;
  final Balance balance;
  final double fraction;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semanticColors;
    final toMe = balance.signed > 0;
    final color = toMe ? semantics.owedToMe : semantics.owedByMe;
    final sign = toMe ? '+' : '−';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              '$sign${formatMoney(balance.magnitude, currency)}',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        LayoutBuilder(
          builder: (context, constraints) {
            final half = constraints.maxWidth / 2;
            final barWidth = (half * fraction).clamp(2.0, half);
            return SizedBox(
              height: 12,
              child: Stack(
                children: [
                  // Centre zero divider.
                  Positioned(
                    left: half - 0.5,
                    top: 0,
                    bottom: 0,
                    width: 1,
                    child: ColoredBox(color: theme.colorScheme.outlineVariant),
                  ),
                  Positioned(
                    left: toMe ? half : half - barWidth,
                    width: barWidth,
                    top: 0,
                    bottom: 0,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: color,
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ],
    );
  }
}

/// The over-time drill-down: the tapped entry's contact, signed amount, date, and
/// note — who moved the line here, and which way (#8).
class _EntryDetailSheet extends StatelessWidget {
  const _EntryDetailSheet({
    required this.entry,
    required this.contactName,
    required this.currency,
  });

  final Entry entry;
  final String contactName;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final semantics = context.semanticColors;
    final locale = Localizations.localeOf(context).toString();
    final toMe = entry.direction == Direction.owedToMe;
    final entryColor = toMe ? semantics.owedToMe : semantics.owedByMe;
    final entrySign = toMe ? '+' : '−';

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(contactName, style: theme.textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              DateFormat.yMMMd(locale).add_jm().format(entry.createdAt),
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _detailRow(
              context,
              label: toMe
                  ? AppLocalizations.of(context).directionOwedToMe
                  : AppLocalizations.of(context).directionOwedByMe,
              value: '$entrySign${formatMoney(entry.amount, currency)}',
              color: entryColor,
            ),
            if (entry.description != null && entry.description!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(entry.description!, style: theme.textTheme.bodyMedium),
            ],
          ],
        ),
      ),
    );
  }

  Widget _detailRow(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
