/// Light and dark Material 3 themes for JTK25.
///
/// Both themes use the same blue seed matching brand color.
/// All user-facing strings in Bahasa Indonesia.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand blue matching app icon, manifest theme_color, and splash.
const Color kBrandBlue = Color(0xFF3B72D9);

ThemeData buildJtk25Theme() {
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: kBrandBlue,
    brightness: Brightness.light,
  );

  return base.copyWith(
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme),
  );
}

ThemeData buildJtk25DarkTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: kBrandBlue,
    brightness: Brightness.dark,
  );

  return base.copyWith(
    textTheme: GoogleFonts.poppinsTextTheme(base.textTheme),
  );
}

// ---------------------------------------------------------------------------
// Semantic status colours
// ---------------------------------------------------------------------------

/// Visual weight of a status colour.
enum StatusTone { subtle, strong }

/// Foreground + background pair for a semantic state (free / busy / online …).
///
/// Material's shade constants are tuned for a light background: a `shade700`
/// foreground on a `shade50` surface inverts to near-black-on-near-black in
/// dark mode. This resolves the pair from the ambient [Brightness] so a status
/// always reads in both themes.
///
/// Shade pairs are chosen so the foreground clears WCAG AA (4.5:1) against its
/// own background — asserted for every hue in
/// `test/core/theme_contrast_test.dart`.
///
/// [base] must be a Material base hue ([Colors.blue] and friends) so a shade
/// scale exists; a literal [Color] falls back to an alpha tint.
class StatusColors {
  const StatusColors({
    required this.foreground,
    required this.background,
  });

  final Color foreground;
  final Color background;

  /// Resolve [base] for the current theme.
  factory StatusColors.of(
    BuildContext context,
    Color base,
    StatusTone tone, {
    Color? backgroundBase,
  }) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final mc = base is MaterialColor ? base : null;
    final bg = backgroundBase is MaterialColor ? backgroundBase : mc;

    if (mc == null || bg == null) {
      // No shade scale available: lean on alpha and keep the foreground as-is.
      return StatusColors(
        foreground: base,
        background: base.withValues(alpha: dark ? 0.22 : 0.14),
      );
    }

    // Dark mode needs a genuinely dark surface: shade800/shade900 of a
    // bright hue (amber, orange) is still too light for a light foreground,
    // so mix toward the theme's own dark surface instead of using raw shades.
    final background = dark
        ? Color.lerp(
            tone == StatusTone.subtle ? mc.shade900 : mc.shade800,
            Theme.of(context).colorScheme.surface,
            0.55,
          )!
        : (tone == StatusTone.subtle ? bg.shade100 : bg.shade200);

    // Bright hues never reach AA on their own surface at any single shade, so
    // push the foreground toward the extreme until it clears 4.5:1.
    final seed = dark ? mc.shade100 : mc.shade900;
    return StatusColors(
      foreground: _ensureContrast(seed, background, dark),
      background: background,
    );
  }

  /// WCAG relative luminance of [c].
  static double _luminance(Color c) {
    double channel(double v) {
      if (v <= 0.03928) return v / 12.92;
      return math.pow((v + 0.055) / 1.055, 2.4).toDouble();
    }

    return 0.2126 * channel(c.r) +
        0.7152 * channel(c.g) +
        0.0722 * channel(c.b);
  }

  /// WCAG contrast ratio between [a] and [b].
  static double _ratio(Color a, Color b) {
    final la = _luminance(a);
    final lb = _luminance(b);
    final hi = la > lb ? la : lb;
    final lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  /// Darken (or lighten) [seed] toward black/white until it clears 4.5:1
  /// against [background]. The hue is preserved so the status still reads as
  /// its colour, just at a legible weight.
  static Color _ensureContrast(Color seed, Color background, bool dark) {
    const target = 4.5;
    if (_ratio(seed, background) >= target) return seed;

    // Blend toward the extreme that moves away from the background.
    final extreme = dark ? Colors.white : Colors.black;
    var candidate = seed;
    // Binary search on the blend factor keeps this to a fixed, cheap loop.
    var lo = 0.0;
    var hi = 1.0;
    for (var i = 0; i < 12; i++) {
      final mid = (lo + hi) / 2;
      candidate = Color.lerp(seed, extreme, mid)!;
      if (_ratio(candidate, background) >= target) {
        hi = mid;
      } else {
        lo = mid;
      }
    }
    return Color.lerp(seed, extreme, hi)!;
  }
}

/// Convenience accessor mirroring [StatusColors.of].
StatusColors statusColors(
  BuildContext context,
  Color base,
  StatusTone tone, {
  Color? backgroundBase,
}) => StatusColors.of(
  context,
  base,
  tone,
  backgroundBase: backgroundBase,
);