/// Core router — full route table for JTK25 client.
///
/// Uses StatefulShellRoute.indexedStack for tab navigation with
/// state preservation across Jadwal / Pengumuman / Acara / Pengaturan.
/// All T10-T12 feature routes are reachable.
/// All strings in Bahasa Indonesia.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/admin.dart';
import '../../features/announcements/announcements.dart';
import '../../features/calendar/calendar.dart';
import '../../features/rooms/rooms.dart';
import '../../features/schedule/schedule.dart';
import '../../features/settings/settings.dart';
import '../../features/privacy/ui/privacy_ui.dart';
import '../../features/settings/ui/notification_permission_screen.dart';

import '../shell/not_found_page.dart';
import '../shell/shell.dart';

/// Full application router.
GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: [
      // Standalone admin route — no navigation shell.
      GoRoute(path: '/admin', builder: (context, state) => const AdminPage()),

      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Jadwal (Schedule + Detail routes).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const SchedulePage(),
                routes: [
                  GoRoute(
                    path: 'jadwal',
                    builder: (context, state) => const SchedulePage(),
                    routes: [
                      GoRoute(
                        path: ':class',
                        builder: (context, state) => _ScheduleWithParam(
                          classCode: state.pathParameters['class']!,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),

          // Branch 1: Ruangan.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ruangan',
                builder: (context, state) => const RoomsListPage(),
                routes: [
                  GoRoute(
                    path: 'matriks',
                    builder: (context, state) => const AvailabilityMatrixPage(),
                  ),
                  GoRoute(
                    path: ':id',
                    builder: (context, state) => RoomDetailPage(
                      roomId: Uri.decodeComponent(state.pathParameters['id']!),
                    ),
                  ),
                ],
              ),
            ],
          ),

          // Branch 2: Pengumuman.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pengumuman',
                builder: (context, state) => const AnnouncementsListPage(),
              ),
            ],
          ),

          // Branch 3: Acara.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/acara',
                builder: (context, state) => const CalendarPage(),
              ),
            ],
          ),

          // Branch 4: Pengaturan.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pengaturan',
                builder: (context, state) => const SettingsPage(),
                routes: [
                  GoRoute(
                    path: 'notifikasi',
                    builder: (context, state) =>
                        const NotificationPermissionScreen(),
                  ),
                  GoRoute(
                    path: 'privasi',
                    builder: (context, state) => const PrivacyPage(),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
}

// ---------------------------------------------------------------------------
// Schedule with class parameter — sets viewedClassProvider on mount
// ---------------------------------------------------------------------------

class _ScheduleWithParam extends ConsumerStatefulWidget {
  const _ScheduleWithParam({required this.classCode});

  final String classCode;

  @override
  ConsumerState<_ScheduleWithParam> createState() => _ScheduleWithParamState();
}

class _ScheduleWithParamState extends ConsumerState<_ScheduleWithParam> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(viewedClassProvider.notifier).select(widget.classCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SchedulePage();
  }
}
