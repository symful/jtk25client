/// Settings feature UI — pengaturan aplikasi JTK25.
///
/// Displays class selection and a single notification toggle.
/// All strings in Bahasa Indonesia.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/notifications/notification_providers.dart';
import '../../schedule/providers/schedule_providers.dart';
import '../data/settings_data.dart';

/// Full settings page.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        children: [
          // Class selection section.
          const _ClassSelectionSection(),
          const Divider(),
          // Pemberitahuan section — single toggle.
          const _NotificationSection(),
          const Divider(),
          // About section.
          const _AboutSection(),
        ],
      ),
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
                  leading: const Icon(Icons.settings),
                  title: const Text('Atur di pengaturan HP'),
                  subtitle: const Text(
                    'Izin pemberitahuan diblokir oleh sistem',
                  ),
                  onTap: () => _openAppSettings(),
                );
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }

  /// Open app settings on Android so user can unblock notifications.
  Future<void> _openAppSettings() async {
    if (kIsWeb) return;
    try {
      if (!kIsWeb && Platform.isAndroid) {
        await launchUrl(
          Uri.parse('package:com.jtk25.jadwalku'),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint('Gagal membuka pengaturan aplikasi: $e');
    }
  }
}

// ---------------------------------------------------------------------------
// About section
// ---------------------------------------------------------------------------

class _AboutSection extends StatelessWidget {
  const _AboutSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Tentang',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.info_outline),
          title: const Text('JTK25 Jadwalku'),
          subtitle: const Text('Aplikasi jadwal kuliah JTK Poliban'),
        ),
      ],
    );
  }
}
