/// Settings feature UI — pengaturan aplikasi JTK25.
///
/// Displays class selection, theme toggle, and notification toggle.
/// All strings in Bahasa Indonesia.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/notification_providers.dart';
import '../../schedule/providers/schedule_providers.dart';
import '../data/settings_data.dart';
import '../providers/theme_provider.dart';

/// Full settings page.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          // Theme selection section.
          const _ThemeSection(),
          const Divider(),
          // Class selection section.
          const _ClassSelectionSection(),
          const Divider(),
          // Pemberitahuan section — single toggle.
          const _NotificationSection(),
          const Divider(),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Theme selection section — Terang / Gelap / Sistem
// ---------------------------------------------------------------------------

class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = ref.watch(themeModeProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Tema',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        RadioGroup<AppThemeMode>(
          groupValue: current,
          onChanged: (value) {
            if (value != null) {
              ref.read(themeModeProvider.notifier).setMode(value);
            }
          },
          child: Column(
            children: const [
              RadioListTile<AppThemeMode>(
                title: Text('Terang'),
                subtitle: Text('Mode terang selalu aktif'),
                value: AppThemeMode.light,
                secondary: Icon(Icons.light_mode),
              ),
              RadioListTile<AppThemeMode>(
                title: Text('Gelap'),
                subtitle: Text('Mode gelap selalu aktif'),
                value: AppThemeMode.dark,
                secondary: Icon(Icons.dark_mode),
              ),
              RadioListTile<AppThemeMode>(
                title: Text('Sistem'),
                subtitle: Text('Ikuti pengaturan perangkat'),
                value: AppThemeMode.system,
                secondary: Icon(Icons.brightness_auto),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Class selection section
// ---------------------------------------------------------------------------

class _ClassSelectionSection extends ConsumerWidget {
  const _ClassSelectionSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(selectedClassProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Kelas',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        RadioGroup<String>(
          groupValue: selected,
          onChanged: (value) {
            if (value != null) {
              ref.read(selectedClassProvider.notifier).select(value);
            }
          },
          child: Column(
            children: kAllClassCodes.map((code) {
              return RadioListTile<String>(
                title: Text(classLabel(code)),
                value: code,
              );
            }).toList(),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Notification section — single enable/disable toggle
// ---------------------------------------------------------------------------

class _NotificationSection extends ConsumerWidget {
  const _NotificationSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(notificationEnabledProvider);
    final statusAsync = ref.watch(notificationStatusProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Pemberitahuan',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        // Main toggle.
        SwitchListTile(
          title: const Text('Pemberitahuan'),
          subtitle: statusAsync.when(
            loading: () => const Text('Memuat...'),
            error: (_, _) => const Text('Gagal memuat status'),
            data: (status) => Text(status),
          ),
          value: enabled,
          onChanged: (value) {
            ref.read(notificationEnabledProvider.notifier).toggle(value);
          },
        ),
        // Description when off.
        if (!enabled)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Kabar jadwal pengganti & pengumuman',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        // Blocked state: tap to open app settings.
        if (enabled)
          statusAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (status) {
              if (status == 'Diblokir — atur di pengaturan HP') {
                return ListTile(
                  leading: const Icon(Icons.notifications),
                  title: const Text('Atur pemberitahuan'),
                  subtitle: const Text(
                    'Izin pemberitahuan diblokir oleh sistem',
                  ),
                  onTap: () {
                    context.push('/pengaturan/notifikasi');
                  },
                );
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }
}
