import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'features/announcements/announcements.dart';
import 'features/events/events.dart';
import 'features/lecturers/lecturers.dart';
import 'features/pengganti/pengganti.dart';
import 'features/rooms/rooms.dart';
import 'features/schedule/schedule.dart';
import 'features/settings/settings.dart';
import 'main.dart' show scaffoldMessengerKey;

/// Root widget for the JTK25 client application.
class Jtk25App extends StatelessWidget {
  const Jtk25App({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'JTK25 Jadwal',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: scaffoldMessengerKey,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
        brightness: Brightness.light,
      ),
      routerConfig: _router,
    );
  }
}

/// Core router — schedule + pengganti + announcements + events + dosen + rooms.
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
    // Dosen routes.
    GoRoute(
      path: '/dosen',
      builder: (context, state) => const LecturersListPage(),
    ),
    GoRoute(
      path: '/dosen/:code',
      builder: (context, state) =>
          LecturerDetailPage(code: state.pathParameters['code']!),
    ),
    // Rooms routes.
    GoRoute(
      path: '/ruangan',
      builder: (context, state) => const RoomsListPage(),
    ),
    GoRoute(
      path: '/ruangan/matriks',
      builder: (context, state) => const AvailabilityMatrixPage(),
    ),
    GoRoute(
      path: '/ruangan/:id',
      builder: (context, state) => RoomDetailPage(
        roomId: Uri.decodeComponent(state.pathParameters['id']!),
      ),
    ),
    // Settings route.
    GoRoute(
      path: '/pengaturan',
      builder: (context, state) => const SettingsPage(),
    ),
  ],
);
