import 'package:flutter/material.dart';

/// The "soft rounded" corner-radius scale, held in a [ThemeExtension]. Values
/// are logical pixels; `pill` is an effectively-infinite radius for chips and
/// the tab indicator. See [docs/design-system.md](../../../docs/design-system.md).
@immutable
class AppRadius extends ThemeExtension<AppRadius> {
  const AppRadius({
    required this.sm,
    required this.md,
    required this.lg,
    required this.pill,
  });

  /// Small controls.
  final double sm;

  /// Cards, buttons, inputs.
  final double md;

  /// Summary card, bottom sheets.
  final double lg;

  /// Fully rounded — chips, segmented/tab indicator.
  final double pill;

  /// The one shipped scale.
  static const AppRadius standard = AppRadius(
    sm: 8,
    md: 12,
    lg: 20,
    pill: 999,
  );

  @override
  AppRadius copyWith({double? sm, double? md, double? lg, double? pill}) {
    return AppRadius(
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      pill: pill ?? this.pill,
    );
  }

  @override
  AppRadius lerp(covariant ThemeExtension<AppRadius>? other, double t) {
    if (other is! AppRadius) return this;
    double at(double a, double b) => a + (b - a) * t;
    return AppRadius(
      sm: at(sm, other.sm),
      md: at(md, other.md),
      lg: at(lg, other.lg),
      pill: at(pill, other.pill),
    );
  }
}
