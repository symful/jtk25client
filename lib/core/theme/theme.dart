/// Light and dark Material 3 themes for JTK25.
///
/// Both themes use the same blue seed matching brand color.
/// All user-facing strings in Bahasa Indonesia.
library;

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
