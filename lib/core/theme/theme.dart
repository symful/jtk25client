/// Light and dark Material 3 themes for JTK25.
///
/// Both themes use the same blue seed matching brand color.
/// All user-facing strings in Bahasa Indonesia.
library;

import 'package:flutter/material.dart';

/// Brand blue matching app icon, manifest theme_color, and splash.
const Color kBrandBlue = Color(0xFF3B72D9);

/// Build the light Material 3 theme for JTK25.
ThemeData buildJtk25Theme() {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: kBrandBlue,
    brightness: Brightness.light,
    fontFamily: 'Plus Jakarta Sans',
  );
}

/// Build the dark Material 3 theme for JTK25.
ThemeData buildJtk25DarkTheme() {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: kBrandBlue,
    brightness: Brightness.dark,
    fontFamily: 'Plus Jakarta Sans',
  );
}
