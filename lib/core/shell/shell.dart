/// Responsive app shell — NavigationRail on wide screens,
/// BottomNavigationBar on mobile.
///
/// Uses StatefulNavigationShell from go_router for tab state preservation.
/// Nav badge on Pengumuman for unseen announcements (T11).
/// All strings in Bahasa Indonesia.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/announcements/providers/announcements_providers.dart';
import '../../features/updater/updater.dart';

/// Responsive shell scaffold wrapping the app's tab navigation.
class AppShell extends ConsumerWidget {
  const AppShell({required this.navigationShell, super.key});

  /// The go_router stateful navigation shell.
  final StatefulNavigationShell navigationShell;

  static const double _wideBreakpoint = 800;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isWide = MediaQuery.sizeOf(context).width > _wideBreakpoint;
    final hasUnseen = ref.watch(hasUnseenAnnouncementsProvider);
    final unseen = hasUnseen;
    final colorScheme = Theme.of(context).colorScheme;

    // Build the icon for the Pengumuman tab with optional badge.
    Widget pengumumanIcon({bool isSelected = false}) {
      final icon = Icon(isSelected ? Icons.campaign : Icons.campaign_outlined);
      if (!unseen) return icon;
      return Badge(backgroundColor: colorScheme.error, child: icon);
    }

    if (isWide) {
      return Scaffold(
        body: Row(
          children: [
            NavigationRail(
              selectedIndex: navigationShell.currentIndex,
              onDestinationSelected: _onDestinationSelected,
              labelType: NavigationRailLabelType.all,
              leading: const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Icon(Icons.school, size: 28),
              ),
              destinations: [
                const NavigationRailDestination(
                  icon: Icon(Icons.schedule_outlined),
                  selectedIcon: Icon(Icons.schedule),
                  label: Text('Jadwal'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.meeting_room_outlined),
                  selectedIcon: Icon(Icons.meeting_room),
                  label: Text('Ruangan'),
                ),
                NavigationRailDestination(
                  icon: pengumumanIcon(),
                  selectedIcon: pengumumanIcon(isSelected: true),
                  label: const Text('Pengumuman'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.event_outlined),
                  selectedIcon: Icon(Icons.event),
                  label: Text('Acara'),
                ),
                const NavigationRailDestination(
                  icon: Icon(Icons.settings_outlined),
                  selectedIcon: Icon(Icons.settings),
                  label: Text('Pengaturan'),
                ),
              ],
            ),
            const VerticalDivider(width: 1),
            Expanded(child: UpdaterShell(child: navigationShell)),
          ],
        ),
      );
    }

    return Scaffold(
      body: UpdaterShell(child: navigationShell),
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: _onDestinationSelected,
        labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 10)),
        destinations: [
          const NavigationDestination(
            icon: Icon(Icons.schedule_outlined),
            selectedIcon: Icon(Icons.schedule),
            label: 'Jadwal',
          ),
          const NavigationDestination(
            icon: Icon(Icons.meeting_room_outlined),
            selectedIcon: Icon(Icons.meeting_room),
            label: 'Ruangan',
          ),
          NavigationDestination(
            icon: pengumumanIcon(),
            selectedIcon: pengumumanIcon(isSelected: true),
            label: 'Pengumuman',
          ),
          const NavigationDestination(
            icon: Icon(Icons.event_outlined),
            selectedIcon: Icon(Icons.event),
            label: 'Acara',
          ),
          const NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings),
            label: 'Pengaturan',
          ),
        ],
      ),
    );
  }

  void _onDestinationSelected(int index) {
    navigationShell.goBranch(
      index,
      initialLocation: index == navigationShell.currentIndex,
    );
  }
}
