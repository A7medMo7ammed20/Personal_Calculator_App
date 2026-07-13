import 'package:flutter/material.dart';
import 'daftar_mark.dart';

/// Animated Daftar splash: the monogram draws itself on (single-stroke reveal),
/// a hairline sweeps out, then دفتر rises and Daftar settles beneath.
///
/// Usage — as the app's cold-launch screen, then route away when ready:
///
///   home: DaftarSplash(onDone: () => Navigator.of(context)
///       .pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()))),
///
/// Requires the IBM Plex fonts declared in pubspec.yaml (families
/// 'IBM Plex Sans' and 'IBM Plex Sans Arabic').
class DaftarSplash extends StatefulWidget {
  const DaftarSplash({
    super.key,
    this.onDone,
    this.duration = const Duration(milliseconds: 2200),
    this.hold = const Duration(milliseconds: 600),
  });
  final VoidCallback? onDone;
  final Duration duration;
  final Duration hold;

  @override
  State<DaftarSplash> createState() => _DaftarSplashState();
}

class _DaftarSplashState extends State<DaftarSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _draw; // monogram stroke
  late final Animation<double> _sweep; // hairline
  late final Animation<double> _word; // دفتر rise + fade
  late final Animation<double> _latin; // Daftar fade

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: widget.duration);
    Animation<double> seg(double a, double b, [Curve c = Curves.easeOutCubic]) =>
        CurvedAnimation(parent: _c, curve: Interval(a, b, curve: c));
    _draw = seg(0.00, 0.62, Curves.easeInOutCubic);
    _sweep = seg(0.48, 0.74);
    _word = seg(0.55, 0.92, Curves.easeOutBack);
    _latin = seg(0.72, 1.00);
    _c.forward().whenComplete(() async {
      await Future<void>.delayed(widget.hold);
      if (mounted) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: DaftarColors.teal,
      body: Center(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 150,
                height: 150,
                child: CustomPaint(
                  painter:
                      DaftarMarkPainter(color: Colors.white, progress: _draw.value),
                ),
              ),
              const SizedBox(height: 26),
              Container(
                width: 96 * _sweep.value,
                height: 2,
                color: Colors.white.withValues(alpha: 0.55),
              ),
              const SizedBox(height: 24),
              Opacity(
                opacity: _word.value.clamp(0, 1),
                child: Transform.translate(
                  offset: Offset(0, 16 * (1 - _word.value.clamp(0, 1))),
                  child: const Text('دفتر',
                      textDirection: TextDirection.rtl,
                      style: TextStyle(
                        fontFamily: 'IBM Plex Sans Arabic',
                        fontWeight: FontWeight.w600,
                        fontSize: 44,
                        color: Colors.white,
                        height: 1,
                      )),
                ),
              ),
              const SizedBox(height: 8),
              Opacity(
                opacity: _latin.value.clamp(0, 1),
                child: Text('Daftar',
                    style: TextStyle(
                      fontFamily: 'IBM Plex Sans',
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                      letterSpacing: 0.5,
                      color: Colors.white.withValues(alpha: 0.85),
                    )),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
