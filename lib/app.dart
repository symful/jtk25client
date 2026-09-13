import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Root widget for the JTK25 client application.
class Jtk25App extends StatelessWidget {
  const Jtk25App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'JTK25 Jadwal',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      routerConfig: _router,
    );
  }
}

/// Placeholder router — will be expanded in T8 (core router).
final _router = GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const _PlaceholderPage(
        title: 'Beranda',
        subtitle: 'Selamat datang di JTK25',
      ),
    ),
    GoRoute(
      path: '/jadwal',
      builder: (context, state) => const _PlaceholderPage(
        title: 'Jadwal',
        subtitle: 'Jadwal perkuliahan',
      ),
    ),
    GoRoute(
      path: '/pengganti',
      builder: (context, state) => const _PlaceholderPage(
        title: 'Pengganti',
        subtitle: 'Jadwal pengganti',
      ),
    ),
    GoRoute(
      path: '/pengumuman',
      builder: (context, state) => const _PlaceholderPage(
        title: 'Pengumuman',
        subtitle: 'Pengumuman terbaru',
      ),
    ),
    GoRoute(
      path: '/kegiatan',
      builder: (context, state) => const _PlaceholderPage(
        title: 'Kegiatan',
        subtitle: 'Kegiatan kampus',
      ),
    ),
  ],
);

/// Simple placeholder page for routing verification.
class _PlaceholderPage extends StatelessWidget {
  const _PlaceholderPage({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Text(
          subtitle,
          style: Theme.of(context).textTheme.headlineMedium,
        ),
      ),
    );
  }
}
