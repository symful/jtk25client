/// Settings feature UI — pengaturan aplikasi JTK25.
///
/// Displays class selection and a single notification toggle.
/// All strings in Bahasa Indonesia.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

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
          // Editor Data section.
          const _EditorDataSection(),
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

// ---------------------------------------------------------------------------
// Editor Data section
// ---------------------------------------------------------------------------

/// Editor Data section — navigates to the unified editor.
class _EditorDataSection extends StatelessWidget {
  const _EditorDataSection();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'Data',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        ListTile(
          leading: const Icon(Icons.edit),
          title: const Text('Editor Data'),
          subtitle: const Text('Edit jadwal, pengumuman, acara, dan lainnya'),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => context.push('/editor'),
        ),
      ],
    );
  }
}
