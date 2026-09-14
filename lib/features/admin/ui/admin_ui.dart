/// Admin feature UI — schedule editing page with login, CRUD dialogs.
///
/// Standalone page at /admin, not part of the main navigation shell.
/// All strings in Bahasa Indonesia.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_data.dart';
import '../providers/admin_providers.dart';

// ---------------------------------------------------------------------------
// Main admin page
// ---------------------------------------------------------------------------

/// Admin page — login gate + schedule management.
class AdminPage extends ConsumerWidget {
  const AdminPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(adminAuthProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin Jadwal'),
        actions: [
          if (auth.isAuthenticated)
            IconButton(
              icon: const Icon(Icons.logout),
              tooltip: 'Keluar',
              onPressed: () {
                ref.read(adminAuthProvider.notifier).logout();
                ref.read(adminSchedulesProvider.notifier).reset();
              },
            ),
        ],
      ),
      body: auth.isAuthenticated ? const _AdminDashboard() : const _LoginForm(),
    );
  }
}

// ---------------------------------------------------------------------------
// Login form
// ---------------------------------------------------------------------------

class _LoginForm extends ConsumerStatefulWidget {
  const _LoginForm();

  @override
  ConsumerState<_LoginForm> createState() => _LoginFormState();
}

class _LoginFormState extends ConsumerState<_LoginForm> {
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);
    ref.read(adminAuthProvider.notifier).clearError();

    final success = await ref
        .read(adminAuthProvider.notifier)
        .login(_passwordController.text);

    if (success && mounted) {
      // Fetch schedules after successful login.
      await ref.read(adminSchedulesProvider.notifier).fetch();
    }

    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(adminAuthProvider);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon.
                Icon(
                  Icons.admin_panel_settings,
                  size: 64,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(height: 16),

                // Title.
                Text(
                  'Panel Admin',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Masukkan kata sandi admin untuk mengakses',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),

                // Password field.
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Kata Sandi',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator: (value) {
                    if (value == null || value.isEmpty) {
                      return 'Kata sandi tidak boleh kosong';
                    }
                    return null;
                  },
                  onFieldSubmitted: (_) => _login(),
                ),
                const SizedBox(height: 8),

                // Error message.
                if (auth.error != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                      auth.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 13,
                      ),
                    ),
                  ),

                // Login button.
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: FilledButton(
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Masuk'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Admin dashboard (after login)
// ---------------------------------------------------------------------------

class _AdminDashboard extends ConsumerStatefulWidget {
  const _AdminDashboard();

  @override
  ConsumerState<_AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends ConsumerState<_AdminDashboard> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      ref.read(adminSchedulesProvider.notifier).fetch();
    });
  }

  @override
  Widget build(BuildContext context) {
    final schedulesAsync = ref.watch(adminSchedulesProvider);
    final auth = ref.watch(adminAuthProvider);

    return Column(
      children: [
        // Scope badge.
        if (auth.scope.isNotEmpty) _ScopeBadge(scope: auth.scope),

        // Class selector + actions.
        _ClassSelectorBar(
          schedulesAsync: schedulesAsync,
          onRefresh: () => ref.read(adminSchedulesProvider.notifier).refresh(),
          onAdd: () => _showSessionForm(context, ref),
        ),

        // Schedule content.
        Expanded(
          child: schedulesAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.red),
                  const SizedBox(height: 16),
                  Text(
                    'Gagal memuat jadwal',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 8),
                  FilledButton.tonal(
                    onPressed: () =>
                        ref.read(adminSchedulesProvider.notifier).fetch(),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
            data: (response) {
              if (response == null || response.classes.isEmpty) {
                return const Center(child: Text('Tidak ada data jadwal'));
              }
              return _ScheduleList(response: response);
            },
          ),
        ),
      ],
    );
  }

  void _showSessionForm(
    BuildContext context,
    WidgetRef ref, {
    AdminScheduleSession? existing,
    String? day,
  }) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SessionFormSheet(existing: existing, day: day),
    );
  }
}

// ---------------------------------------------------------------------------
// Scope badge
// ---------------------------------------------------------------------------

class _ScopeBadge extends StatelessWidget {
  const _ScopeBadge({required this.scope});

  final String scope;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final isGlobal = scope == 'global';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: isGlobal
          ? colorScheme.primaryContainer
          : colorScheme.tertiaryContainer,
      child: Row(
        children: [
          Icon(
            isGlobal ? Icons.public : Icons.class_,
            size: 16,
            color: isGlobal
                ? colorScheme.onPrimaryContainer
                : colorScheme.onTertiaryContainer,
          ),
          const SizedBox(width: 8),
          Text(
            isGlobal ? 'Akses Global' : 'Kelas: $scope',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: isGlobal
                  ? colorScheme.onPrimaryContainer
                  : colorScheme.onTertiaryContainer,
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Class selector bar
// ---------------------------------------------------------------------------

class _ClassSelectorBar extends ConsumerWidget {
  const _ClassSelectorBar({
    required this.schedulesAsync,
    required this.onRefresh,
    required this.onAdd,
  });

  final AsyncValue<AdminSchedulesResponse?> schedulesAsync;
  final VoidCallback onRefresh;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedClass = ref.watch(selectedAdminClassProvider);
    final classes = schedulesAsync.whenOrNull(
      data: (r) => r?.classes.map((c) => c.className).toList() ?? [],
    );

    // Auto-select first class if none selected.
    if (classes != null && classes.isNotEmpty && selectedClass.isEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(selectedAdminClassProvider.notifier).autoSelect(classes);
      });
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
        ),
      ),
      child: Row(
        children: [
          // Class dropdown.
          if (classes != null && classes.isNotEmpty)
            Expanded(
              child: DropdownButtonFormField<String>(
                initialValue: classes.contains(selectedClass)
                    ? selectedClass
                    : null,
                decoration: const InputDecoration(
                  labelText: 'Pilih Kelas',
                  border: OutlineInputBorder(),
                  isDense: true,
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 12,
                  ),
                ),
                items: classes
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    ref.read(selectedAdminClassProvider.notifier).select(value);
                  }
                },
              ),
            )
          else
            const Expanded(child: Text('Memuat data kelas...')),

          const SizedBox(width: 8),

          // Refresh button.
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Muat Ulang',
            onPressed: onRefresh,
          ),

          // Add button.
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Tambah'),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Schedule list (grouped by day)
// ---------------------------------------------------------------------------

class _ScheduleList extends ConsumerWidget {
  const _ScheduleList({required this.response});

  final AdminSchedulesResponse response;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedClass = ref.watch(selectedAdminClassProvider);

    final classData = response.classes
        .where((c) => c.className == selectedClass)
        .firstOrNull;

    if (classData == null) {
      return Center(
        child: Text(
          'Kelas "$selectedClass" tidak ditemukan',
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      );
    }

    if (classData.schedule.isEmpty) {
      return const Center(
        child: Text(
          'Tidak ada jadwal untuk kelas ini',
          style: TextStyle(color: Colors.grey),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: classData.schedule.length,
      itemBuilder: (context, dayIndex) {
        final daySchedule = classData.schedule[dayIndex];
        return _DaySection(daySchedule: daySchedule);
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Day section
// ---------------------------------------------------------------------------

class _DaySection extends StatelessWidget {
  const _DaySection({required this.daySchedule});

  final AdminDaySchedule daySchedule;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Day header.
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            daySchedule.day,
            style: Theme.of(
              context,
            ).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),

        // Sessions.
        ...daySchedule.sessions.map(
          (session) => _SessionTile(session: session),
        ),

        const SizedBox(height: 16),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Session tile (individual row)
// ---------------------------------------------------------------------------

class _SessionTile extends ConsumerWidget {
  const _SessionTile({required this.session});

  final AdminScheduleSession session;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colorScheme = Theme.of(context).colorScheme;
    final isTe = session.type.toUpperCase() == 'TE';

    return Card(
      margin: const EdgeInsets.only(bottom: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: time + type badge + action buttons.
            Row(
              children: [
                // Time.
                Icon(
                  Icons.access_time,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 4),
                Text(
                  session.time,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(width: 8),

                // Type badge.
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isTe ? Colors.blue.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    session.type.toUpperCase(),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: isTe
                          ? Colors.blue.shade700
                          : Colors.green.shade700,
                    ),
                  ),
                ),

                const Spacer(),

                // Edit button.
                IconButton(
                  icon: const Icon(Icons.edit, size: 18),
                  tooltip: 'Edit',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _editSession(context, ref),
                ),

                // Delete button.
                IconButton(
                  icon: Icon(
                    Icons.delete_outline,
                    size: 18,
                    color: colorScheme.error,
                  ),
                  tooltip: 'Hapus',
                  visualDensity: VisualDensity.compact,
                  onPressed: () => _deleteSession(context, ref),
                ),
              ],
            ),

            // Row 2: course code.
            Text(
              session.courseCode,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),

            // Row 3: course name.
            Text(
              session.courseName,
              style: Theme.of(context).textTheme.bodyMedium,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),

            const SizedBox(height: 4),

            // Row 4: room.
            Row(
              children: [
                Icon(
                  Icons.location_on_outlined,
                  size: 14,
                  color: colorScheme.onSurfaceVariant,
                ),
                const SizedBox(width: 2),
                Expanded(
                  child: Text(
                    session.room,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),

            // Row 5: lecturer.
            if (session.lecturer.isNotEmpty)
              Row(
                children: [
                  Icon(
                    Icons.person_outline,
                    size: 14,
                    color: colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 2),
                  Expanded(
                    child: Text(
                      session.lecturer,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: colorScheme.onSurfaceVariant,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
          ],
        ),
      ),
    );
  }

  void _editSession(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _SessionFormSheet(existing: session, day: _findDay(ref)),
    );
  }

  void _deleteSession(BuildContext context, WidgetRef ref) {
    if (!session.hasId) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Tidak dapat menghapus: ID sesi tidak tersedia'),
        ),
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Hapus Sesi?'),
        content: Text(
          'Hapus ${session.courseName} (${session.courseCode}) '
          'pada ${session.time}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _doDelete(context, ref);
            },
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );
  }

  Future<void> _doDelete(BuildContext context, WidgetRef ref) async {
    final api = ref.read(adminApiProvider);
    try {
      final ok = await api.deleteSchedule(session.id!);
      if (!context.mounted) return;
      if (ok) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Sesi berhasil dihapus')));
        ref.read(adminSchedulesProvider.notifier).refresh();
      } else {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Gagal menghapus sesi')));
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  String? _findDay(WidgetRef ref) {
    final response = ref.read(adminSchedulesProvider).value;
    if (response == null) return null;
    for (final classSchedule in response.classes) {
      for (final daySchedule in classSchedule.schedule) {
        if (daySchedule.sessions.any((s) => s == session)) {
          return daySchedule.day;
        }
      }
    }
    return null;
  }
}

// ---------------------------------------------------------------------------
// Session form sheet (add / edit)
// ---------------------------------------------------------------------------

class _SessionFormSheet extends ConsumerStatefulWidget {
  const _SessionFormSheet({this.existing, this.day});

  /// Existing session to edit (null = add new).
  final AdminScheduleSession? existing;

  /// Pre-selected day (for adding).
  final String? day;

  @override
  ConsumerState<_SessionFormSheet> createState() => _SessionFormSheetState();
}

class _SessionFormSheetState extends ConsumerState<_SessionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _classNameController;
  late final TextEditingController _semesterController;
  late final TextEditingController _dayController;
  late final TextEditingController _timeController;
  late final TextEditingController _courseCodeController;
  late final TextEditingController _courseNameController;
  late final TextEditingController _typeController;
  late final TextEditingController _lecturerCodeController;
  late final TextEditingController _lecturerController;
  late final TextEditingController _roomController;
  late final TextEditingController _modeController;
  bool _isLoading = false;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    final selectedClass = ref.read(selectedAdminClassProvider);
    final schedules = ref.read(adminSchedulesProvider).value;
    final semester = schedules?.semester ?? '2025/2026-Genap';

    _classNameController = TextEditingController(text: selectedClass);
    _semesterController = TextEditingController(text: semester);
    _dayController = TextEditingController(text: widget.day ?? '');
    _timeController = TextEditingController(text: existing?.time ?? '');
    _courseCodeController = TextEditingController(
      text: existing?.courseCode ?? '',
    );
    _courseNameController = TextEditingController(
      text: existing?.courseName ?? '',
    );
    _typeController = TextEditingController(text: existing?.type ?? 'TE');
    _lecturerCodeController = TextEditingController(
      text: existing?.lecturerCode ?? '',
    );
    _lecturerController = TextEditingController(text: existing?.lecturer ?? '');
    _roomController = TextEditingController(text: existing?.room ?? '');
    _modeController = TextEditingController(text: existing?.mode ?? 'offline');
  }

  @override
  void dispose() {
    _classNameController.dispose();
    _semesterController.dispose();
    _dayController.dispose();
    _timeController.dispose();
    _courseCodeController.dispose();
    _courseNameController.dispose();
    _typeController.dispose();
    _lecturerCodeController.dispose();
    _lecturerController.dispose();
    _roomController.dispose();
    _modeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        expand: false,
        builder: (context, scrollController) {
          return SingleChildScrollView(
            controller: scrollController,
            padding: const EdgeInsets.all(20),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Handle bar.
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),

                  // Title.
                  Text(
                    _isEditing ? 'Edit Sesi' : 'Tambah Sesi Baru',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 20),

                  // Class name.
                  TextFormField(
                    controller: _classNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Kelas',
                      hintText: 'D3-2A',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),

                  // Semester.
                  TextFormField(
                    controller: _semesterController,
                    decoration: const InputDecoration(
                      labelText: 'Semester',
                      hintText: '2025/2026-Genap',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),

                  // Day selector.
                  DropdownButtonFormField<String>(
                    initialValue: _dayController.text.isNotEmpty
                        ? _dayController.text
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Hari',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'SENIN', child: Text('Senin')),
                      DropdownMenuItem(value: 'SELASA', child: Text('Selasa')),
                      DropdownMenuItem(value: 'RABU', child: Text('Rabu')),
                      DropdownMenuItem(value: 'KAMIS', child: Text('Kamis')),
                      DropdownMenuItem(value: 'JUMAT', child: Text('Jumat')),
                    ],
                    onChanged: (v) {
                      if (v != null) _dayController.text = v;
                    },
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Pilih hari' : null,
                  ),
                  const SizedBox(height: 12),

                  // Time.
                  TextFormField(
                    controller: _timeController,
                    decoration: const InputDecoration(
                      labelText: 'Waktu',
                      hintText: '07.00-07.50',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),

                  // Course code.
                  TextFormField(
                    controller: _courseCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Kode Mata Kuliah',
                      hintText: '25IF2116',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),

                  // Course name.
                  TextFormField(
                    controller: _courseNameController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Mata Kuliah',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),

                  // Type selector.
                  DropdownButtonFormField<String>(
                    initialValue: _typeController.text.isNotEmpty
                        ? _typeController.text.toUpperCase()
                        : null,
                    decoration: const InputDecoration(
                      labelText: 'Tipe',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'TE', child: Text('Teori (TE)')),
                      DropdownMenuItem(
                        value: 'PR',
                        child: Text('Praktik (PR)'),
                      ),
                    ],
                    onChanged: (v) {
                      if (v != null) _typeController.text = v;
                    },
                    validator: (v) =>
                        v == null || v.isEmpty ? 'Pilih tipe' : null,
                  ),
                  const SizedBox(height: 12),

                  // Lecturer code.
                  TextFormField(
                    controller: _lecturerCodeController,
                    decoration: const InputDecoration(
                      labelText: 'Kode Dosen',
                      hintText: 'MV',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Lecturer name.
                  TextFormField(
                    controller: _lecturerController,
                    decoration: const InputDecoration(
                      labelText: 'Nama Dosen',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Room.
                  TextFormField(
                    controller: _roomController,
                    decoration: const InputDecoration(
                      labelText: 'Ruang',
                      hintText: 'D108-Kelas',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) => v?.isEmpty ?? true ? 'Wajib diisi' : null,
                  ),
                  const SizedBox(height: 12),

                  // Mode (offline/online).
                  DropdownButtonFormField<String>(
                    initialValue: _modeController.text.isNotEmpty
                        ? _modeController.text
                        : 'offline',
                    decoration: const InputDecoration(
                      labelText: 'Mode',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: 'offline',
                        child: Text('Offline'),
                      ),
                      DropdownMenuItem(value: 'online', child: Text('Online')),
                    ],
                    onChanged: (v) {
                      if (v != null) _modeController.text = v;
                    },
                  ),
                  const SizedBox(height: 24),

                  // Action buttons.
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text('Batal'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton(
                          onPressed: _isLoading ? null : _save,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Text('Simpan'),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final api = ref.read(adminApiProvider);

    try {
      if (_isEditing) {
        if (!widget.existing!.hasId) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Tidak dapat mengedit: ID sesi tidak tersedia'),
              ),
            );
          }
          return;
        }

        final ok = await api.updateSchedule(
          widget.existing!.id!,
          className: _classNameController.text,
          semester: _semesterController.text,
          day: _dayController.text,
          time: _timeController.text,
          courseCode: _courseCodeController.text,
          courseName: _courseNameController.text,
          type: _typeController.text,
          lecturerCode: _lecturerCodeController.text,
          lecturer: _lecturerController.text,
          room: _roomController.text,
          mode: _modeController.text,
        );

        if (!mounted) return;
        if (ok) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesi berhasil diupdate')),
          );
          ref.read(adminSchedulesProvider.notifier).refresh();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal mengupdate sesi')),
          );
        }
      } else {
        final id = await api.addSchedule(
          className: _classNameController.text,
          semester: _semesterController.text,
          day: _dayController.text,
          time: _timeController.text,
          courseCode: _courseCodeController.text,
          courseName: _courseNameController.text,
          type: _typeController.text,
          lecturerCode: _lecturerCodeController.text,
          lecturer: _lecturerController.text,
          room: _roomController.text,
          mode: _modeController.text,
        );

        if (!mounted) return;
        if (id != null) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Sesi berhasil ditambahkan')),
          );
          ref.read(adminSchedulesProvider.notifier).refresh();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Gagal menambahkan sesi')),
          );
        }
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }
}
