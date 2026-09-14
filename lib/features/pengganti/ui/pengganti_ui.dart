/// Pengganti feature UI — list of all schedule overrides for the selected class.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/pengganti.dart';
import '../../schedule/providers/schedule_providers.dart';
import '../providers/pengganti_providers.dart';

// ---------------------------------------------------------------------------
// Pengganti page
// ---------------------------------------------------------------------------

/// Full-screen list of pengganti entries for the selected class.
class PenggantiPage extends ConsumerWidget {
  const PenggantiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final classCode = ref.watch(viewedClassProvider);
    final entries = ref.watch(classPenggantiProvider(classCode));

    return Scaffold(
      appBar: AppBar(title: const Text('Jadwal Pengganti')),
      body: entries.isEmpty
          ? const Center(
              child: Text(
                'Tidak ada jadwal pengganti',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 4),
              itemBuilder: (context, index) {
                final entry = entries[index];
                return _PenggantiTile(entry: entry);
              },
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Tile
// ---------------------------------------------------------------------------

class _PenggantiTile extends StatelessWidget {
  const _PenggantiTile({required this.entry});

  final PenggantiEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    final (color, icon, kindLabel) = switch (entry.kind) {
      PenggantiKind.replace => (
        Colors.orange.shade50,
        Icons.swap_horiz,
        'Ganti',
      ),
      PenggantiKind.add => (
        Colors.blue.shade50,
        Icons.add_circle_outline,
        'Tambah',
      ),
      PenggantiKind.info => (Colors.grey.shade100, Icons.info_outline, 'Info'),
    };

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: colorScheme.onSurface, size: 20),
        ),
        title: Text(entry.date, style: Theme.of(context).textTheme.titleSmall),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              kindLabel,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            if (entry.sessions.any((s) => s.mode != null)) ...[
              const SizedBox(height: 2),
              Wrap(
                spacing: 4,
                runSpacing: 2,
                children: entry.sessions
                    .where((s) => s.mode != null)
                    .map((s) => _ModeBadge(mode: s.mode))
                    .toList(),
              ),
            ],
            if (entry.note != null && entry.note!.isNotEmpty) ...[
              const SizedBox(height: 2),
              Text(
                entry.note!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
        trailing: entry.sessions.isNotEmpty
            ? Chip(
                label: Text(
                  '${entry.sessions.length} sesi',
                  style: const TextStyle(fontSize: 11),
                ),
              )
            : null,
        onTap: () => _showDetail(context),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => _PenggantiDetailSheet(entry: entry),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail bottom sheet
// ---------------------------------------------------------------------------

class _PenggantiDetailSheet extends StatelessWidget {
  const _PenggantiDetailSheet({required this.entry});

  final PenggantiEntry entry;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Handle bar.
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // Kind badge.
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: switch (entry.kind) {
                  PenggantiKind.replace => Colors.orange.shade50,
                  PenggantiKind.add => Colors.blue.shade50,
                  PenggantiKind.info => Colors.grey.shade100,
                },
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                _kindLabel(entry.kind),
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
            ),
            const SizedBox(height: 12),
            // Date.
            Text(entry.date, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 4),
            // Class.
            Text(
              'Kelas: ${entry.classCode}',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            // Note.
            if (entry.note != null && entry.note!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(entry.note!, style: Theme.of(context).textTheme.bodyLarge),
            ],
            // Sessions.
            if (entry.sessions.isNotEmpty) ...[
              const SizedBox(height: 16),
              Text(
                'Sesi (${entry.sessions.length})',
                style: Theme.of(context).textTheme.titleSmall,
              ),
              const SizedBox(height: 8),
              ...entry.sessions.map(
                (s) => ListTile(
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text('${s.courseCode} — ${s.courseName}'),
                  subtitle: Row(
                    children: [
                      Expanded(
                        child: Text('${s.time} · ${s.room} · ${s.lecturer}'),
                      ),
                      _ModeBadge(mode: s.mode),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }

  String _kindLabel(PenggantiKind kind) => switch (kind) {
    PenggantiKind.replace => 'Ganti Jadwal',
    PenggantiKind.add => 'Tambah Jadwal',
    PenggantiKind.info => 'Info',
  };
}

// ---------------------------------------------------------------------------
// Mode badge (offline / online)
// ---------------------------------------------------------------------------

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode});

  final String? mode;

  @override
  Widget build(BuildContext context) {
    final effectiveMode = mode ?? 'offline';
    final isOnline = effectiveMode == 'online';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: isOnline ? Colors.blue.shade50 : Colors.grey.shade100,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isOnline ? Icons.wifi : Icons.school,
            size: 12,
            color: isOnline ? Colors.blue.shade700 : Colors.grey.shade600,
          ),
          const SizedBox(width: 3),
          Text(
            isOnline ? 'Online' : 'Offline',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: isOnline ? Colors.blue.shade700 : Colors.grey.shade600,
            ),
          ),
        ],
      ),
    );
  }
}
