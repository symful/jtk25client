/// Light-only Material 3 theme for JTK25.
///
/// NO dark mode — light theme only, blue seed matching brand color.
/// All user-facing strings in Bahasa Indonesia.
library;

import 'package:flutter/material.dart';

/// Brand blue matching app icon, manifest theme_color, and splash.
const Color kBrandBlue = Color(0xFF3B72D9);

/// Build the light-only Material 3 theme for JTK25.
ThemeData buildJtk25Theme() {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: kBrandBlue,
    brightness: Brightness.light,
  );
}
