import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'features/settings/providers/theme_provider.dart';
import 'main.dart' show scaffoldMessengerKey;

/// Root widget for the JTK25 client application.
class Jtk25App extends ConsumerWidget {
  const Jtk25App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'JTK25 Jadwal',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: buildJtk25Theme(),
      darkTheme: buildJtk25DarkTheme(),
      themeMode: themeMode.flutterThemeMode,
      routerConfig: createRouter(),
    );
  }
}
