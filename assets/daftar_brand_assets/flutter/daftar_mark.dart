import 'package:flutter/material.dart';

/// Daftar dual-script monogram (dāl / open-D), drawn as a single stroke.
/// Brand colour is Teal #14746F; the mark itself is a flat solid silhouette.
class DaftarColors {
  static const teal = Color(0xFF14746F);
}

/// The raw monogram path, authored in a 240×240 box.
Path daftarMarkPath() {
  return Path()
    ..moveTo(66, 74)
    ..lineTo(150, 74)
    ..cubicTo(192, 74, 204, 132, 170, 155)
    ..cubicTo(146, 171, 106, 173, 84, 165)
    ..cubicTo(70, 160, 71, 145, 87, 143);
}

/// Paints the monogram centred and scaled to the given [size], as a stroke.
/// [progress] 0→1 draws the stroke on (use 1.0 for a static mark).
class DaftarMarkPainter extends CustomPainter {
  DaftarMarkPainter({required this.color, this.progress = 1.0});
  final Color color;
  final double progress;

  @override
  void paint(Canvas canvas, Size size) {
    final f = size.shortestSide / 240.0;
    canvas.save();
    canvas.translate((size.width - 240 * f) / 2, (size.height - 240 * f) / 2);
    canvas.scale(f, f);

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 28
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;

    final path = daftarMarkPath();
    if (progress >= 1.0) {
      canvas.drawPath(path, paint);
    } else {
      for (final m in path.computeMetrics()) {
        canvas.drawPath(m.extractPath(0, m.length * progress.clamp(0, 1)), paint);
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(DaftarMarkPainter old) =>
      old.progress != progress || old.color != color;
}

/// Static logo widget. Drop anywhere: DaftarMark(size: 40).
class DaftarMark extends StatelessWidget {
  const DaftarMark({super.key, this.size = 48, this.color = Colors.white});
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) => SizedBox(
        width: size,
        height: size,
        child: CustomPaint(painter: DaftarMarkPainter(color: color)),
      );
}

/// The teal app-tile lockup (mark on a rounded Teal square).
class DaftarIconTile extends StatelessWidget {
  const DaftarIconTile({super.key, this.size = 64, this.radius = 14});
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: DaftarColors.teal,
          borderRadius: BorderRadius.circular(radius),
        ),
        child: Padding(
          padding: EdgeInsets.all(size * 0.22),
          child: CustomPaint(painter: DaftarMarkPainter(color: Colors.white)),
        ),
      );
}
