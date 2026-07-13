import 'package:flutter/material.dart';

/// The money-direction colours, held in a [ThemeExtension] so widgets read them
/// from the theme instead of hard-coding literals.
///
/// These are **fixed across every accent** (see
/// [ADR 0002](../../../docs/adr/0002-design-system-and-switchable-accent-themes.md)):
/// the accent themes the chrome, but green="owed to me" / red="owed by me" /
/// neutral="settled" must mean the same thing in every theme. Only brightness
/// varies them, so text stays legible on dark surfaces. Concrete hexes live in
/// [docs/design-system.md](../../../docs/design-system.md).
@immutable
class AppSemanticColors extends ThemeExtension<AppSemanticColors> {
  const AppSemanticColors({
    required this.owedToMe,
    required this.owedByMe,
    required this.settled,
  });

  /// Positive amounts — someone owes the user (↑).
  final Color owedToMe;

  /// Negative amounts — the user owes someone (↓).
  final Color owedByMe;

  /// Zero balance — nothing outstanding, neutral.
  final Color settled;

  /// Light-mode semantics.
  static const AppSemanticColors light = AppSemanticColors(
    owedToMe: Color(0xFF2E7D5B),
    owedByMe: Color(0xFFC0392B),
    settled: Color(0xFF6B7280),
  );

  /// Dark-mode semantics — brightened so they read on dark surfaces.
  static const AppSemanticColors dark = AppSemanticColors(
    owedToMe: Color(0xFF43D9A3),
    owedByMe: Color(0xFFF87171),
    settled: Color(0xFF9CA3AF),
  );

  /// The set matching a [brightness].
  static AppSemanticColors of(Brightness brightness) =>
      brightness == Brightness.dark ? dark : light;

  @override
  AppSemanticColors copyWith({
    Color? owedToMe,
    Color? owedByMe,
    Color? settled,
  }) {
    return AppSemanticColors(
      owedToMe: owedToMe ?? this.owedToMe,
      owedByMe: owedByMe ?? this.owedByMe,
      settled: settled ?? this.settled,
    );
  }

  @override
  AppSemanticColors lerp(
    covariant ThemeExtension<AppSemanticColors>? other,
    double t,
  ) {
    if (other is! AppSemanticColors) return this;
    return AppSemanticColors(
      owedToMe: Color.lerp(owedToMe, other.owedToMe, t)!,
      owedByMe: Color.lerp(owedByMe, other.owedByMe, t)!,
      settled: Color.lerp(settled, other.settled, t)!,
    );
  }
}
