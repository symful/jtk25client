/// Settings feature UI — pengaturan aplikasi JTK25.
///
/// Displays class selection and notification preferences.
/// All strings in Bahasa Indonesia.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/notifications/notification_providers.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/notifications/fcm_service.dart';
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
          // Pemberitahuan section.
          const _NotificationSection(),
          const Divider(),
          // Info pemberitahuan section.
          const _FcmPushSection(),
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
// Notification section
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
        SwitchListTile(
          title: const Text('Aktifkan Pemberitahuan'),
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
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Dapatkan kabar jadwal pengganti & pengumuman langsung ke HP-mu.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        const SizedBox(height: 8),
        // "Atur" button → navigate to permission screen.
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: () {
              context.push('/pengaturan/notifikasi');
            },
            icon: const Icon(Icons.notifications_active),
            label: const Text('Lihat Detail'),
          ),
        ),
        const SizedBox(height: 16),
        // Permission request button (when enabled but permission denied).
        if (enabled)
          statusAsync.when(
            loading: () => const SizedBox.shrink(),
            error: (_, _) => const SizedBox.shrink(),
            data: (status) {
              if (status == 'Diblokir — atur di pengaturan HP') {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: OutlinedButton.icon(
                    onPressed: () async {
                      final service = NotificationService.instance;
                      await service.requestPermission();
                      // Refresh the status.
                      ref.invalidate(notificationStatusProvider);
                    },
                    icon: const Icon(Icons.notifications_active),
                    label: const Text('Aktifkan Pemberitahuan'),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Info pemberitahuan section
// ---------------------------------------------------------------------------

class _FcmPushSection extends ConsumerWidget {
  const _FcmPushSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fcmStatusAsync = ref.watch(fcmStatusProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Info Kelas',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.cloud_queue),
          title: const Text('Status pengiriman'),
          subtitle: fcmStatusAsync.when(
            loading: () => const Text('Memuat...'),
            error: (e, _) => const Text('Gagal memuat status'),
            data: (status) => Text(status),
          ),
        ),
        if (!FcmService.instance.isSupported)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Fitur ini belum aktif di browser. Gunakan Chrome atau Firefox untuk menerima pemberitahuan.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: OutlinedButton.icon(
            onPressed: () async {
              final selectedClass = ref.read(selectedClassProvider);
              if (selectedClass.isNotEmpty) {
                await FcmService.instance.subscribeToClassTopic(selectedClass);
                ref.invalidate(fcmStatusProvider);
              }
            },
            icon: const Icon(Icons.info_outline),
            label: const Text('Perbarui info kelas'),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }
}
