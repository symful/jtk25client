import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'core/router/router.dart';
import 'core/theme/theme.dart';
import 'features/settings/providers/theme_provider.dart';
import 'main.dart' show scaffoldMessengerKey;

class Jtk25App extends ConsumerStatefulWidget {
  const Jtk25App({super.key});

  @override
  ConsumerState<Jtk25App> createState() => _Jtk25AppState();
}

class _Jtk25AppState extends ConsumerState<Jtk25App> {
  late final GoRouter _router;

  @override
  void initState() {
    super.initState();
    _router = createRouter();
  }

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeModeProvider);

    return MaterialApp.router(
      title: 'JTK25 Jadwal',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: buildJtk25Theme(),
      darkTheme: buildJtk25DarkTheme(),
      themeMode: themeMode.flutterThemeMode,
      routerConfig: _router,
    );
  }
}
