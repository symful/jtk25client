/// Core router — full route table for JTK25 client.
///
/// Uses StatefulShellRoute.indexedStack for tab navigation with
/// state preservation across Beranda / Pengumuman / Acara / Pengaturan.
/// All T10-T12 feature routes are reachable.
/// All strings in Bahasa Indonesia.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/announcements/announcements.dart';
import '../../features/events/events.dart';
import '../../features/lecturers/lecturers.dart';
import '../../features/pengganti/pengganti.dart';
import '../../features/rooms/rooms.dart';
import '../../features/schedule/schedule.dart';
import '../../features/settings/settings.dart';
import '../../features/settings/ui/notification_permission_screen.dart';
import '../shell/editor_placeholder.dart';
import '../shell/landing_page.dart';
import '../shell/not_found_page.dart';
import '../shell/shell.dart';

/// Full application router.
GoRouter createRouter() {
  return GoRouter(
    initialLocation: '/',
    errorBuilder: (context, state) => const NotFoundPage(),
    routes: [
      StatefulShellRoute.indexedStack(
        builder: (context, state, navigationShell) {
          return AppShell(navigationShell: navigationShell);
        },
        branches: [
          // Branch 0: Beranda (Home + Schedule + Detail routes).
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/',
                builder: (context, state) => const LandingPage(),
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
                  GoRoute(
                    path: 'pengganti',
                    builder: (context, state) => const PenggantiPage(),
                  ),
                  // Dosen routes.
                  GoRoute(
                    path: 'dosen',
                    builder: (context, state) => const LecturersListPage(),
                    routes: [
                      GoRoute(
                        path: ':code',
                        builder: (context, state) => LecturerDetailPage(
                          code: state.pathParameters['code']!,
                        ),
                      ),
                    ],
                  ),
                  // Room routes.
                  GoRoute(
                    path: 'ruangan',
                    builder: (context, state) => const RoomsListPage(),
                    routes: [
                      GoRoute(
                        path: 'matriks',
                        builder: (context, state) =>
                            const AvailabilityMatrixPage(),
                      ),
                      GoRoute(
                        path: ':id',
                        builder: (context, state) => RoomDetailPage(
                          roomId: Uri.decodeComponent(
                            state.pathParameters['id']!,
                          ),
                        ),
                      ),
                    ],
                  ),
                  // Editor placeholder (T16).
                  GoRoute(
                    path: 'editor',
                    builder: (context, state) => const EditorPlaceholderPage(),
                  ),
                ],
              ),
            ],
          ),

          // Branch 1: Pengumuman.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/pengumuman',
                builder: (context, state) => const AnnouncementsListPage(),
              ),
            ],
          ),

          // Branch 2: Acara.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/acara',
                builder: (context, state) => const EventsListPage(),
              ),
            ],
          ),

          // Branch 3: Pengaturan.
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
// Schedule with class parameter — sets selectedClassProvider on mount
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
      ref.read(selectedClassProvider.notifier).select(widget.classCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    return const SchedulePage();
  }
}
