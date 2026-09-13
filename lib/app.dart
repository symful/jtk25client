import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/announcements/announcements.dart';
import 'features/events/events.dart';
import 'features/pengganti/pengganti.dart';
import 'features/schedule/schedule.dart';

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

/// Core router — schedule + pengganti + announcements + events.
final _router = GoRouter(
  initialLocation: '/jadwal',
  routes: [
    GoRoute(path: '/', builder: (context, state) => const SchedulePage()),
    GoRoute(path: '/jadwal', builder: (context, state) => const SchedulePage()),
    GoRoute(
      path: '/pengganti',
      builder: (context, state) => const PenggantiPage(),
    ),
    GoRoute(
      path: '/pengumuman',
      builder: (context, state) => const AnnouncementsListPage(),
    ),
    GoRoute(
      path: '/kegiatan',
      builder: (context, state) => const EventsListPage(),
    ),
  ],
);
