import 'package:flutter/material.dart';

/// The 8pt spacing rhythm, held in a [ThemeExtension] so widgets read tokens
/// (`context.spacing.lg`) instead of inlining magic numbers. Values are in
/// logical pixels; see [docs/design-system.md](../../../docs/design-system.md).
@immutable
class AppSpacing extends ThemeExtension<AppSpacing> {
  const AppSpacing({
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
    required this.xxxl,
  });

  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;
  final double xxxl;

  /// The one shipped scale.
  static const AppSpacing standard = AppSpacing(
    xs: 4,
    sm: 8,
    md: 12,
    lg: 16,
    xl: 24,
    xxl: 32,
    xxxl: 48,
  );

  @override
  AppSpacing copyWith({
    double? xs,
    double? sm,
    double? md,
    double? lg,
    double? xl,
    double? xxl,
    double? xxxl,
  }) {
    return AppSpacing(
      xs: xs ?? this.xs,
      sm: sm ?? this.sm,
      md: md ?? this.md,
      lg: lg ?? this.lg,
      xl: xl ?? this.xl,
      xxl: xxl ?? this.xxl,
      xxxl: xxxl ?? this.xxxl,
    );
  }

  @override
  AppSpacing lerp(covariant ThemeExtension<AppSpacing>? other, double t) {
    if (other is! AppSpacing) return this;
    double at(double a, double b) => a + (b - a) * t;
    return AppSpacing(
      xs: at(xs, other.xs),
      sm: at(sm, other.sm),
      md: at(md, other.md),
      lg: at(lg, other.lg),
      xl: at(xl, other.xl),
      xxl: at(xxl, other.xxl),
      xxxl: at(xxxl, other.xxxl),
    );
  }
}
