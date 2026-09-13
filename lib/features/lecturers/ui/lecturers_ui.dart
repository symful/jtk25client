/// Lecturers feature UI — searchable dosen list and detail page.
///
/// Shows dosen code, full name, and "Mengajarkan" sessions computed
/// by scanning all class schedules. All strings in Bahasa Indonesia.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/schedule.dart';
import '../data/lecturers_data.dart';
import '../providers/lecturers_providers.dart';

// ---------------------------------------------------------------------------
// Lecturers list page
// ---------------------------------------------------------------------------

/// Full-screen searchable dosen list.
class LecturersListPage extends ConsumerWidget {
  const LecturersListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filtered = ref.watch(filteredDosenProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Dosen')),
      body: Column(
        children: [
          // Search bar.
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cari dosen...',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
                contentPadding: EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
              ),
              onChanged: (value) {
                ref.read(dosenSearchProvider.notifier).update(value);
              },
            ),
          ),
          // Dosen list.
          Expanded(
            child: filtered.isEmpty
                ? const Center(
                    child: Text(
                      'Tidak ada dosen ditemukan',
                      style: TextStyle(color: Colors.grey),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final dosen = filtered[index];
                      return ListTile(
                        leading: CircleAvatar(
                          child: Text(
                            dosen.code.length <= 2
                                ? dosen.code
                                : dosen.code.substring(0, 2),
                          ),
                        ),
                        title: Text(dosen.name),
                        subtitle: Text(dosen.code),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          context.push('/dosen/${dosen.code}');
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Lecturer detail page
// ---------------------------------------------------------------------------

/// Detail page for a single dosen — shows code, name, and "Mengajarkan".
class LecturerDetailPage extends ConsumerWidget {
  const LecturerDetailPage({super.key, required this.code});

  final String code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dosen = ref.watch(dosenByCodeProvider(code));
    final sessions = ref.watch(dosenDetailProvider(code));

    if (dosen == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Dosen')),
        body: const Center(child: Text('Dosen tidak ditemukan')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(dosen.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Header card.
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Avatar + name.
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        child: Text(
                          dosen.code.length <= 2
                              ? dosen.code
                              : dosen.code.substring(0, 2),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              dosen.name,
                              style: Theme.of(context).textTheme.titleLarge,
                            ),
                            Text(
                              'Kode: ${dosen.code}',
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurfaceVariant,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (dosen.email != null) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Icon(
                          Icons.email_outlined,
                          size: 16,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          dosen.email!,
                          style: Theme.of(context).textTheme.bodySmall
                              ?.copyWith(
                                color: Theme.of(
                                  context,
                                ).colorScheme.onSurfaceVariant,
                              ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          // Mengajarkan section.
          Text(
            'Mengajarkan',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          if (sessions.isEmpty)
            const Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Text(
                  'Tidak ada jadwal mengajar',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            )
          else
            ...sessions.map((ds) => _DosenSessionCard(dosenSession: ds)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Dosen session card
// ---------------------------------------------------------------------------

class _DosenSessionCard extends StatelessWidget {
  const _DosenSessionCard({required this.dosenSession});

  final DosenSession dosenSession;

  @override
  Widget build(BuildContext context) {
    final session = dosenSession.session;
    final colorScheme = Theme.of(context).colorScheme;
    final typeColor = session.type == CourseType.te
        ? Colors.blue
        : Colors.green;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Day + time row.
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: typeColor.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    session.type == CourseType.te ? 'Teori' : 'Praktik',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: typeColor.shade700,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${dosenSession.day.label} · ${session.time}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            // Course code.
            Text(
              session.courseCode,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
            // Course name.
            Text(
              session.courseName,
              style: Theme.of(context).textTheme.bodyLarge,
            ),
            const SizedBox(height: 4),
            // Room + class.
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 2),
                Text(
                  session.room,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(width: 12),
                Icon(
                  Icons.class_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 2),
                Text(
                  dosenSession.classCode,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
