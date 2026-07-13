import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../data/contact_repository.dart';
import '../../data/entry_repository.dart';
import '../../domain/analysis_graph.dart';
import '../../domain/currency.dart';
import '../../domain/period.dart';
import '../../l10n/gen/app_localizations.dart';
import '../money_format.dart';
import '../theme/theme_context.dart';
import '../widgets/period_selector.dart';

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

/// The Analysis graph (#8): a per-currency line of the cumulative net [[Balance]]
/// across all Contacts over time, windowed by the period filter, with tap-to-
/// drill-down into an interval's per-Contact movement. All logic lives in the
/// pure `cumulativeSeries` / `intervalBreakdown` seams; this screen loads, hosts
/// the lens + period controls, and renders. See CONTEXT.md and ADR 0004.
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

  int _firstDayOfWeek = DateTime.monday;
  bool _loaded = false;
  late Future<List<BalancePoint>> _series;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // MaterialLocalizations reports 0=Sunday..6=Saturday; DateTime uses
    // 1=Monday..7=Sunday. Honour the locale's week start for weekly buckets.
    final idx = MaterialLocalizations.of(context).firstDayOfWeekIndex;
    _firstDayOfWeek = idx == 0 ? DateTime.sunday : idx;
    if (!_loaded) {
      _reload();
      _loaded = true;
    }
  }

  void _reload() {
    _series = _load();
  }

  Future<List<BalancePoint>> _load() async {
    final entries = await widget.entryRepository.listByCurrency(_currency);
    final now = DateTime.now();
    final range = resolvePeriod(
      _period,
      now,
      customStart: _customStart,
      customEnd: _customEnd,
    );
    return cumulativeSeries(
      entries,
      range: range,
      now: now,
      firstDayOfWeek: _firstDayOfWeek,
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

  Future<void> _openBreakdown(BalancePoint point) async {
    final entries = await widget.entryRepository.entriesInRange(
      _currency,
      point.bucket,
    );
    final deltas = intervalBreakdown(entries);
    final contacts = await widget.contactRepository.list();
    final names = {for (final c in contacts) c.id!: c.name};
    if (!mounted) return;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _BreakdownSheet(
        bucket: point.bucket,
        deltas: deltas,
        names: names,
        currency: _currency,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
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
            Expanded(
              child: FutureBuilder<List<BalancePoint>>(
                future: _series,
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final points = snapshot.data ?? const <BalancePoint>[];
                  if (points.isEmpty) {
                    return Center(
                      child: Text(
                        l10n.analysisEmpty(_currency.code),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                    );
                  }
                  return Padding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    child: _AnalysisChart(
                      points: points,
                      currency: _currency,
                      onTapPoint: _openBreakdown,
                    ),
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

/// The windowed line, hand-painted (ADR 0004 — no charting dependency). Owns the
/// x-scale so tap hit-testing is a straight nearest-point search.
class _AnalysisChart extends StatelessWidget {
  const _AnalysisChart({
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
/// RTL (oldest on the right). Shared by the painter and the tap hit-test so they
/// never disagree.
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

    // X extents: first and last bucket dates in the strip below the plot.
    final first = geometry.points.first.bucket.start;
    final last = geometry.points.last.bucket.start;
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

/// The drill-down sheet: an interval's per-Contact net deltas, styled like the
/// running-summary sheet. Deltas are pre-sorted by magnitude and sum to the
/// segment's movement (#8).
class _BreakdownSheet extends StatelessWidget {
  const _BreakdownSheet({
    required this.bucket,
    required this.deltas,
    required this.names,
    required this.currency,
  });

  final DateRange bucket;
  final List<ContactDelta> deltas;
  final Map<int, String> names;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final locale = Localizations.localeOf(context).toString();
    final theme = Theme.of(context);

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Text(
                l10n.breakdownTitle(_intervalLabel(locale)),
                style: theme.textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            if (deltas.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  l10n.breakdownEmpty,
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  itemCount: deltas.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) => _deltaTile(context, deltas[index]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _deltaTile(BuildContext context, ContactDelta d) {
    final semantics = context.semanticColors;
    final settled = d.delta.abs() < 0.005;
    final toMe = d.delta > 0;
    final color = settled
        ? semantics.settled
        : (toMe ? semantics.owedToMe : semantics.owedByMe);
    final sign = settled ? '' : (toMe ? '+' : '−');
    return ListTile(
      dense: true,
      title: Text(names[d.contactId] ?? '#${d.contactId}'),
      trailing: Text(
        '$sign${formatMoney(d.delta.abs(), currency)}',
        style: Theme.of(context)
            .textTheme
            .bodyMedium
            ?.copyWith(color: color, fontWeight: FontWeight.w600),
      ),
    );
  }

  String _intervalLabel(String locale) {
    final fmt = DateFormat.yMMMd(locale);
    final lastDay = bucket.endExclusive.subtract(const Duration(days: 1));
    final start = fmt.format(bucket.start);
    final sameDay = bucket.start.year == lastDay.year &&
        bucket.start.month == lastDay.month &&
        bucket.start.day == lastDay.day;
    return sameDay ? start : '$start – ${fmt.format(lastDay)}';
  }
}
