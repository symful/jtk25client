/// Editor page UI — forms per data type with schema validation and JSON export.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/announcement.dart';
import '../../../core/models/dosen.dart';
import '../../../core/models/event.dart';
import '../../../core/models/room.dart';
import '../data/editor_data.dart';
import '../providers/editor_providers.dart';
import '_download_helper.dart'
    if (dart.library.js_interop) '_download_helper_web.dart';

/// Shows a confirmation dialog before deleting. Returns `true` if confirmed.
Future<bool> _confirmDelete(BuildContext context) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Hapus Item'),
      content: const Text('Yakin ingin menghapus item ini?'),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Batal'),
        ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('Hapus'),
        ),
      ],
    ),
  );
  return result ?? false;
}

/// Empty state widget shown when a list has no items.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child: Text(
          message,
          style: TextStyle(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

/// Top-level editor page mounted at /editor by the router.
///
/// Two-state design: file list (no selection) or editor form (file selected).
class EditorPage extends ConsumerWidget {
  const EditorPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedFile = ref.watch(selectedFileProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(selectedFile?.label ?? 'Editor Data'),
        leading: selectedFile != null
            ? IconButton(
                icon: const Icon(Icons.arrow_back),
                onPressed: () =>
                    ref.read(selectedFileProvider.notifier).clear(),
              )
            : null,
      ),
      body: selectedFile == null
          ? const _FileListView()
          : _EditorFormView(selectedFile: selectedFile),
    );
  }
}

// ---------------------------------------------------------------------------
// File list view
// ---------------------------------------------------------------------------

/// Maps editor data type to an icon.
IconData _iconForType(EditorDataType type) => switch (type) {
  EditorDataType.schedule => Icons.schedule,
  EditorDataType.pengganti => Icons.swap_horiz,
  EditorDataType.announcements => Icons.campaign,
  EditorDataType.events => Icons.event,
  EditorDataType.dosen => Icons.person,
  EditorDataType.rooms => Icons.meeting_room,
};

/// File list showing all 11 editable data files.
class _FileListView extends ConsumerWidget {
  const _FileListView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView.builder(
      itemCount: kAllEditorFiles.length,
      itemBuilder: (context, index) {
        final file = kAllEditorFiles[index];
        return ListTile(
          leading: Icon(_iconForType(file.type)),
          title: Text(file.label),
          subtitle: Text(file.type.label),
          trailing: const Icon(Icons.chevron_right),
          onTap: () => ref.read(selectedFileProvider.notifier).select(file),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Editor form view
// ---------------------------------------------------------------------------

/// Editor form view for a selected file.
class _EditorFormView extends ConsumerWidget {
  const _EditorFormView({required this.selectedFile});

  final EditorFile selectedFile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final errors = ref.watch(validationErrorsProvider);
    final canExport = ref.watch(canExportProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Form area
          _buildFormArea(selectedFile.type),
          const SizedBox(height: 16),

          // Validation errors
          if (errors.isNotEmpty) _ValidationErrorsPanel(errors: errors),

          // Export buttons
          _ExportPanel(
            canExport: canExport,
            onCopy: () => _copyToClipboard(context, ref),
            onDownload: () => _downloadFile(context, ref),
          ),
          const SizedBox(height: 16),

          // PR instructions
          const _PrInstructionsPanel(),
        ],
      ),
    );
  }

  Widget _buildFormArea(EditorDataType type) {
    return switch (type) {
      EditorDataType.schedule => const _ScheduleForm(),
      EditorDataType.pengganti => const _PenggantiForm(),
      EditorDataType.announcements => const _AnnouncementsForm(),
      EditorDataType.events => const _EventsForm(),
      EditorDataType.dosen => const _DosenForm(),
      EditorDataType.rooms => const _RoomsForm(),
    };
  }
}

// ---------------------------------------------------------------------------
// Export helpers
// ---------------------------------------------------------------------------

void _copyToClipboard(BuildContext context, WidgetRef ref) {
  final json = ref.read(exportJsonProvider);
  Clipboard.setData(ClipboardData(text: json));
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(const SnackBar(content: Text('JSON disalin ke clipboard')));
}

void _downloadFile(BuildContext context, WidgetRef ref) {
  final json = ref.read(exportJsonProvider);
  final filename = ref.read(exportFilenameProvider);
  downloadJsonFile(filename, json);
  ScaffoldMessenger.of(
    context,
  ).showSnackBar(SnackBar(content: Text('File $filename diunduh')));
}

// ---------------------------------------------------------------------------
// Validation errors panel
// ---------------------------------------------------------------------------

class _ValidationErrorsPanel extends StatelessWidget {
  const _ValidationErrorsPanel({required this.errors});

  final List<FieldError> errors;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Theme.of(context).colorScheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Error Validasi (${errors.length})',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            for (final error in errors.take(20))
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  '${error.fieldKey}: ${error.message}',
                  style: TextStyle(
                    color: Theme.of(context).colorScheme.onErrorContainer,
                    fontSize: 13,
                  ),
                ),
              ),
            if (errors.length > 20)
              Text(
                '... dan ${errors.length - 20} error lainnya',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onErrorContainer,
                  fontStyle: FontStyle.italic,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Export panel
// ---------------------------------------------------------------------------

class _ExportPanel extends StatelessWidget {
  const _ExportPanel({
    required this.canExport,
    required this.onCopy,
    required this.onDownload,
  });

  final bool canExport;
  final VoidCallback onCopy;
  final VoidCallback onDownload;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: canExport ? onCopy : null,
            icon: const Icon(Icons.copy),
            label: const Text('Salin ke Clipboard'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: ElevatedButton.icon(
            onPressed: canExport ? onDownload : null,
            icon: const Icon(Icons.download),
            label: const Text('Unduh'),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Schedule form
// ---------------------------------------------------------------------------

class _ScheduleForm extends ConsumerWidget {
  const _ScheduleForm();

  static const _days = ['SENIN', 'SELASA', 'RABU', 'KAMIS', 'JUMAT'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(scheduleFormProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Class selector
        const Text(
          'Pilih Kelas:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final code in kClassFileNameMap.keys)
              ChoiceChip(
                label: Text(code),
                selected: form.classCode == code,
                onSelected: (_) =>
                    ref.read(scheduleFormProvider.notifier).selectClass(code),
              ),
          ],
        ),
        const SizedBox(height: 16),

        // Day tabs
        DefaultTabController(
          length: _days.length,
          child: Column(
            children: [
              TabBar(
                isScrollable: true,
                tabs: [for (final d in _days) Tab(text: d)],
              ),
              SizedBox(
                height: 400,
                child: TabBarView(
                  children: [
                    for (final day in _days)
                      _SessionList(day: day, sessions: form.days[day] ?? []),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SessionList extends ConsumerWidget {
  const _SessionList({required this.day, required this.sessions});

  final String day;
  final List<SessionForm> sessions;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListView(
      children: [
        if (sessions.isEmpty)
          const _EmptyState(
            message: 'Belum ada sesi. Tekan tombol di bawah untuk menambah.',
          ),
        for (var i = 0; i < sessions.length; i++)
          _SessionCard(
            key: ValueKey('$day-$i-${sessions[i].time.hashCode}'),
            session: sessions[i],
            onChanged: (updated) => ref
                .read(scheduleFormProvider.notifier)
                .updateSession(day, i, updated),
            onDelete: () async {
              if (await _confirmDelete(context)) {
                ref.read(scheduleFormProvider.notifier).removeSession(day, i);
              }
            },
          ),
        TextButton.icon(
          onPressed: () =>
              ref.read(scheduleFormProvider.notifier).addSession(day),
          icon: const Icon(Icons.add),
          label: const Text('Tambah Sesi'),
        ),
      ],
    );
  }
}

class _SessionCard extends StatefulWidget {
  const _SessionCard({
    super.key,
    required this.session,
    required this.onChanged,
    required this.onDelete,
  });

  final SessionForm session;
  final ValueChanged<SessionForm> onChanged;
  final VoidCallback onDelete;

  @override
  State<_SessionCard> createState() => _SessionCardState();
}

class _SessionCardState extends State<_SessionCard> {
  late final TextEditingController _timeCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _lecturerCodeCtrl;
  late final TextEditingController _lecturerCtrl;
  late final TextEditingController _roomCtrl;
  String _type = 'TE';

  @override
  void initState() {
    super.initState();
    _timeCtrl = TextEditingController(text: widget.session.time);
    _codeCtrl = TextEditingController(text: widget.session.courseCode);
    _nameCtrl = TextEditingController(text: widget.session.courseName);
    _lecturerCodeCtrl = TextEditingController(
      text: widget.session.lecturerCode,
    );
    _lecturerCtrl = TextEditingController(text: widget.session.lecturer);
    _roomCtrl = TextEditingController(text: widget.session.room);
    _type = widget.session.type;
  }

  @override
  void didUpdateWidget(covariant _SessionCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _updateIfChanged(_timeCtrl, widget.session.time);
      _updateIfChanged(_codeCtrl, widget.session.courseCode);
      _updateIfChanged(_nameCtrl, widget.session.courseName);
      _updateIfChanged(_lecturerCodeCtrl, widget.session.lecturerCode);
      _updateIfChanged(_lecturerCtrl, widget.session.lecturer);
      _updateIfChanged(_roomCtrl, widget.session.room);
      if (_type != widget.session.type) _type = widget.session.type;
    }
  }

  void _updateIfChanged(TextEditingController ctrl, String value) {
    if (ctrl.text != value) ctrl.text = value;
  }

  void _emit() {
    widget.onChanged(
      SessionForm(
        time: _timeCtrl.text,
        courseCode: _codeCtrl.text,
        courseName: _nameCtrl.text,
        type: _type,
        lecturerCode: _lecturerCodeCtrl.text,
        lecturer: _lecturerCtrl.text,
        room: _roomCtrl.text,
      ),
    );
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _lecturerCodeCtrl.dispose();
    _lecturerCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _timeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Waktu (07.00-07.50)',
                      isDense: true,
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: DropdownButtonFormField<String>(
                    initialValue: _type,
                    items: const [
                      DropdownMenuItem(value: 'TE', child: Text('TE')),
                      DropdownMenuItem(value: 'PR', child: Text('PR')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _type = v);
                        _emit();
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Tipe',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () async {
                    if (await _confirmDelete(context)) {
                      widget.onDelete();
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Kode Mata Kuliah (25IFxxxx)',
                isDense: true,
              ),
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Mata Kuliah',
                isDense: true,
              ),
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _lecturerCodeCtrl,
              decoration: const InputDecoration(
                labelText: 'Kode Dosen (koma: MV, LH)',
                isDense: true,
              ),
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _lecturerCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Dosen',
                isDense: true,
              ),
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _roomCtrl,
              decoration: const InputDecoration(
                labelText: 'Ruang',
                isDense: true,
              ),
              onChanged: (_) => _emit(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Pengganti form
// ---------------------------------------------------------------------------

class _PenggantiForm extends ConsumerWidget {
  const _PenggantiForm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.watch(penggantiFormProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daftar Pengganti:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (form.entries.isEmpty)
          const _EmptyState(
            message:
                'Belum ada entri pengganti. Tekan tombol di bawah untuk menambah.',
          ),
        for (var i = 0; i < form.entries.length; i++)
          _PenggantiEntryCard(entry: form.entries[i], entryIndex: i),
        TextButton.icon(
          onPressed: () => ref.read(penggantiFormProvider.notifier).addEntry(),
          icon: const Icon(Icons.add),
          label: const Text('Tambah Entri Pengganti'),
        ),
      ],
    );
  }
}

class _PenggantiEntryCard extends ConsumerWidget {
  const _PenggantiEntryCard({required this.entry, required this.entryIndex});

  final PenggantiEntryForm entry;
  final int entryIndex;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'ID Unik',
                      isDense: true,
                    ),
                    controller: TextEditingController(text: entry.id),
                    onChanged: (v) {
                      final updated = entry.copy();
                      updated.id = v;
                      ref
                          .read(penggantiFormProvider.notifier)
                          .updateEntry(entryIndex, updated);
                    },
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await _confirmDelete(context)) {
                      ref
                          .read(penggantiFormProvider.notifier)
                          .removeEntry(entryIndex);
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: entry.classCode,
                    items: [
                      for (final code in kClassFileNameMap.keys)
                        DropdownMenuItem(value: code, child: Text(code)),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        final updated = entry.copy();
                        updated.classCode = v;
                        ref
                            .read(penggantiFormProvider.notifier)
                            .updateEntry(entryIndex, updated);
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Kelas',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Tanggal (YYYY-MM-DD)',
                      isDense: true,
                    ),
                    controller: TextEditingController(text: entry.date),
                    onChanged: (v) {
                      final updated = entry.copy();
                      updated.date = v;
                      ref
                          .read(penggantiFormProvider.notifier)
                          .updateEntry(entryIndex, updated);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            DropdownButtonFormField<String>(
              initialValue: entry.kind,
              items: const [
                DropdownMenuItem(
                  value: 'replace',
                  child: Text('Ganti (replace)'),
                ),
                DropdownMenuItem(value: 'add', child: Text('Tambah (add)')),
                DropdownMenuItem(value: 'info', child: Text('Info')),
              ],
              onChanged: (v) {
                if (v != null) {
                  final updated = entry.copy();
                  updated.kind = v;
                  ref
                      .read(penggantiFormProvider.notifier)
                      .updateEntry(entryIndex, updated);
                }
              },
              decoration: const InputDecoration(
                labelText: 'Jenis',
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                isDense: true,
              ),
              controller: TextEditingController(text: entry.note),
              onChanged: (v) {
                final updated = entry.copy();
                updated.note = v;
                ref
                    .read(penggantiFormProvider.notifier)
                    .updateEntry(entryIndex, updated);
              },
            ),
            const SizedBox(height: 12),
            const Text('Sesi:', style: TextStyle(fontWeight: FontWeight.bold)),
            for (var j = 0; j < entry.sessions.length; j++)
              _PenggantiSessionTile(
                session: entry.sessions[j],
                entryIndex: entryIndex,
                sessionIndex: j,
              ),
            TextButton.icon(
              onPressed: () => ref
                  .read(penggantiFormProvider.notifier)
                  .addSessionToEntry(entryIndex),
              icon: const Icon(Icons.add, size: 18),
              label: const Text('Tambah Sesi'),
            ),
          ],
        ),
      ),
    );
  }
}

class _PenggantiSessionTile extends ConsumerStatefulWidget {
  const _PenggantiSessionTile({
    required this.session,
    required this.entryIndex,
    required this.sessionIndex,
  });

  final PenggantiSessionForm session;
  final int entryIndex;
  final int sessionIndex;

  @override
  ConsumerState<_PenggantiSessionTile> createState() =>
      _PenggantiSessionTileState();
}

class _PenggantiSessionTileState extends ConsumerState<_PenggantiSessionTile> {
  late final TextEditingController _timeCtrl;
  late final TextEditingController _codeCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _lecturerCodeCtrl;
  late final TextEditingController _lecturerCtrl;
  late final TextEditingController _roomCtrl;
  String _type = 'TE';

  @override
  void initState() {
    super.initState();
    _timeCtrl = TextEditingController(text: widget.session.time);
    _codeCtrl = TextEditingController(text: widget.session.courseCode);
    _nameCtrl = TextEditingController(text: widget.session.courseName);
    _lecturerCodeCtrl = TextEditingController(
      text: widget.session.lecturerCode,
    );
    _lecturerCtrl = TextEditingController(text: widget.session.lecturer);
    _roomCtrl = TextEditingController(text: widget.session.room);
    _type = widget.session.type;
  }

  @override
  void didUpdateWidget(covariant _PenggantiSessionTile oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.session != widget.session) {
      _updateIfChanged(_timeCtrl, widget.session.time);
      _updateIfChanged(_codeCtrl, widget.session.courseCode);
      _updateIfChanged(_nameCtrl, widget.session.courseName);
      _updateIfChanged(_lecturerCodeCtrl, widget.session.lecturerCode);
      _updateIfChanged(_lecturerCtrl, widget.session.lecturer);
      _updateIfChanged(_roomCtrl, widget.session.room);
      if (_type != widget.session.type) _type = widget.session.type;
    }
  }

  void _updateIfChanged(TextEditingController ctrl, String value) {
    if (ctrl.text != value) ctrl.text = value;
  }

  void _emit() {
    ref
        .read(penggantiFormProvider.notifier)
        .updateSessionInEntry(
          widget.entryIndex,
          widget.sessionIndex,
          PenggantiSessionForm(
            time: _timeCtrl.text,
            courseCode: _codeCtrl.text,
            courseName: _nameCtrl.text,
            type: _type,
            lecturerCode: _lecturerCodeCtrl.text,
            lecturer: _lecturerCtrl.text,
            room: _roomCtrl.text,
          ),
        );
  }

  @override
  void dispose() {
    _timeCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _lecturerCodeCtrl.dispose();
    _lecturerCtrl.dispose();
    _roomCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _timeCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Waktu (07.00-07.50)',
                      isDense: true,
                    ),
                    onChanged: (_) => _emit(),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 80,
                  child: DropdownButtonFormField<String>(
                    initialValue: _type,
                    items: const [
                      DropdownMenuItem(value: 'TE', child: Text('TE')),
                      DropdownMenuItem(value: 'PR', child: Text('PR')),
                    ],
                    onChanged: (v) {
                      if (v != null) {
                        setState(() => _type = v);
                        _emit();
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Tipe',
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline, size: 20),
                  onPressed: () async {
                    if (await _confirmDelete(context)) {
                      ref
                          .read(penggantiFormProvider.notifier)
                          .removeSessionFromEntry(
                            widget.entryIndex,
                            widget.sessionIndex,
                          );
                    }
                  },
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _codeCtrl,
              decoration: const InputDecoration(
                labelText: 'Kode Mata Kuliah',
                isDense: true,
              ),
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Mata Kuliah',
                isDense: true,
              ),
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _lecturerCodeCtrl,
              decoration: const InputDecoration(
                labelText: 'Kode Dosen',
                isDense: true,
              ),
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _lecturerCtrl,
              decoration: const InputDecoration(
                labelText: 'Nama Dosen',
                isDense: true,
              ),
              onChanged: (_) => _emit(),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _roomCtrl,
              decoration: const InputDecoration(
                labelText: 'Ruang',
                isDense: true,
              ),
              onChanged: (_) => _emit(),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Announcements form
// ---------------------------------------------------------------------------

class _AnnouncementsForm extends ConsumerWidget {
  const _AnnouncementsForm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(announcementsFormProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daftar Pengumuman:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const _EmptyState(
            message:
                'Belum ada pengumuman. Tekan tombol di bawah untuk menambah.',
          ),
        for (var i = 0; i < items.length; i++)
          _AnnouncementCard(item: items[i], index: i),
        TextButton.icon(
          onPressed: () => ref.read(announcementsFormProvider.notifier).add(),
          icon: const Icon(Icons.add),
          label: const Text('Tambah Pengumuman'),
        ),
      ],
    );
  }
}

class _AnnouncementCard extends ConsumerWidget {
  const _AnnouncementCard({required this.item, required this.index});

  final Announcement item;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'Judul',
                isDense: true,
              ),
              controller: TextEditingController(text: item.title),
              onChanged: (v) {
                ref
                    .read(announcementsFormProvider.notifier)
                    .update(
                      index,
                      Announcement(
                        id: item.id,
                        title: v,
                        body: item.body,
                        pinned: item.pinned,
                        createdAt: item.createdAt,
                        expiresAt: item.expiresAt,
                      ),
                    );
              },
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Isi',
                isDense: true,
              ),
              maxLines: 3,
              controller: TextEditingController(text: item.body),
              onChanged: (v) {
                ref
                    .read(announcementsFormProvider.notifier)
                    .update(
                      index,
                      Announcement(
                        id: item.id,
                        title: item.title,
                        body: v,
                        pinned: item.pinned,
                        createdAt: item.createdAt,
                        expiresAt: item.expiresAt,
                      ),
                    );
              },
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'ID',
                      isDense: true,
                    ),
                    controller: TextEditingController(text: item.id),
                    onChanged: (v) {
                      ref
                          .read(announcementsFormProvider.notifier)
                          .update(
                            index,
                            Announcement(
                              id: v,
                              title: item.title,
                              body: item.body,
                              pinned: item.pinned,
                              createdAt: item.createdAt,
                              expiresAt: item.expiresAt,
                            ),
                          );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Tanggal Dibuat (ISO)',
                      isDense: true,
                    ),
                    controller: TextEditingController(text: item.createdAt),
                    onChanged: (v) {
                      ref
                          .read(announcementsFormProvider.notifier)
                          .update(
                            index,
                            Announcement(
                              id: item.id,
                              title: item.title,
                              body: item.body,
                              pinned: item.pinned,
                              createdAt: v,
                              expiresAt: item.expiresAt,
                            ),
                          );
                    },
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Kadaluarsa (ISO, opsional)',
                      isDense: true,
                    ),
                    controller: TextEditingController(text: item.expiresAt),
                    onChanged: (v) {
                      ref
                          .read(announcementsFormProvider.notifier)
                          .update(
                            index,
                            Announcement(
                              id: item.id,
                              title: item.title,
                              body: item.body,
                              pinned: item.pinned,
                              createdAt: item.createdAt,
                              expiresAt: v.isEmpty ? null : v,
                            ),
                          );
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Sematkan', style: TextStyle(fontSize: 12)),
                    Switch(
                      value: item.pinned,
                      onChanged: (v) {
                        ref
                            .read(announcementsFormProvider.notifier)
                            .update(
                              index,
                              Announcement(
                                id: item.id,
                                title: item.title,
                                body: item.body,
                                pinned: v,
                                createdAt: item.createdAt,
                                expiresAt: item.expiresAt,
                              ),
                            );
                      },
                    ),
                  ],
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await _confirmDelete(context)) {
                      ref
                          .read(announcementsFormProvider.notifier)
                          .remove(index);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Events form
// ---------------------------------------------------------------------------

class _EventsForm extends ConsumerWidget {
  const _EventsForm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(eventsFormProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daftar Acara:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const _EmptyState(
            message: 'Belum ada acara. Tekan tombol di bawah untuk menambah.',
          ),
        for (var i = 0; i < items.length; i++)
          _EventCard(item: items[i], index: i),
        TextButton.icon(
          onPressed: () => ref.read(eventsFormProvider.notifier).add(),
          icon: const Icon(Icons.add),
          label: const Text('Tambah Acara'),
        ),
      ],
    );
  }
}

class _EventCard extends ConsumerWidget {
  const _EventCard({required this.item, required this.index});

  final JtkEvent item;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'ID',
                      isDense: true,
                    ),
                    controller: TextEditingController(text: item.id),
                    onChanged: (v) => ref
                        .read(eventsFormProvider.notifier)
                        .update(index, _copyWithId(item, v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Judul',
                      isDense: true,
                    ),
                    controller: TextEditingController(text: item.title),
                    onChanged: (v) => ref
                        .read(eventsFormProvider.notifier)
                        .update(index, _copyWith(item, title: v)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Deskripsi (opsional)',
                isDense: true,
              ),
              maxLines: 2,
              controller: TextEditingController(text: item.description),
              onChanged: (v) => ref
                  .read(eventsFormProvider.notifier)
                  .update(index, _copyWith(item, description: v)),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Tanggal Mulai (ISO)',
                      isDense: true,
                    ),
                    controller: TextEditingController(text: item.date),
                    onChanged: (v) => ref
                        .read(eventsFormProvider.notifier)
                        .update(index, _copyWith(item, date: v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Tanggal Selesai (ISO)',
                      isDense: true,
                    ),
                    controller: TextEditingController(text: item.endDate),
                    onChanged: (v) => ref
                        .read(eventsFormProvider.notifier)
                        .update(index, _copyWith(item, endDate: v)),
                  ),
                ),
              ],
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Lokasi',
                      isDense: true,
                    ),
                    controller: TextEditingController(text: item.location),
                    onChanged: (v) => ref
                        .read(eventsFormProvider.notifier)
                        .update(index, _copyWith(item, location: v)),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      isDense: true,
                    ),
                    controller: TextEditingController(text: item.category),
                    onChanged: (v) => ref
                        .read(eventsFormProvider.notifier)
                        .update(index, _copyWith(item, category: v)),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    if (await _confirmDelete(context)) {
                      ref.read(eventsFormProvider.notifier).remove(index);
                    }
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  JtkEvent _copyWithId(JtkEvent e, String id) => JtkEvent(
    id: id,
    title: e.title,
    description: e.description,
    date: e.date,
    endDate: e.endDate,
    location: e.location,
    category: e.category,
  );

  JtkEvent _copyWith(
    JtkEvent e, {
    String? title,
    String? description,
    String? date,
    String? endDate,
    String? location,
    String? category,
  }) => JtkEvent(
    id: e.id,
    title: title ?? e.title,
    description: description ?? e.description,
    date: date ?? e.date,
    endDate: endDate ?? e.endDate,
    location: location ?? e.location,
    category: category ?? e.category,
  );
}

// ---------------------------------------------------------------------------
// Dosen form
// ---------------------------------------------------------------------------

class _DosenForm extends ConsumerWidget {
  const _DosenForm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(dosenFormProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daftar Dosen:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const _EmptyState(
            message: 'Belum ada dosen. Tekan tombol di bawah untuk menambah.',
          ),
        for (var i = 0; i < items.length; i++)
          _DosenCard(item: items[i], index: i),
        TextButton.icon(
          onPressed: () => ref.read(dosenFormProvider.notifier).add(),
          icon: const Icon(Icons.add),
          label: const Text('Tambah Dosen'),
        ),
      ],
    );
  }
}

class _DosenCard extends ConsumerWidget {
  const _DosenCard({required this.item, required this.index});

  final Dosen item;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Kode',
                  isDense: true,
                ),
                controller: TextEditingController(text: item.code),
                onChanged: (v) => ref
                    .read(dosenFormProvider.notifier)
                    .update(
                      index,
                      Dosen(code: v, name: item.name, email: item.email),
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Nama',
                  isDense: true,
                ),
                controller: TextEditingController(text: item.name),
                onChanged: (v) => ref
                    .read(dosenFormProvider.notifier)
                    .update(
                      index,
                      Dosen(code: item.code, name: v, email: item.email),
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Email (opsional)',
                  isDense: true,
                ),
                controller: TextEditingController(text: item.email),
                onChanged: (v) => ref
                    .read(dosenFormProvider.notifier)
                    .update(
                      index,
                      Dosen(
                        code: item.code,
                        name: item.name,
                        email: v.isEmpty ? null : v,
                      ),
                    ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await _confirmDelete(context)) {
                  ref.read(dosenFormProvider.notifier).remove(index);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Rooms form
// ---------------------------------------------------------------------------

class _RoomsForm extends ConsumerWidget {
  const _RoomsForm();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items = ref.watch(roomsFormProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Daftar Ruangan:',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        if (items.isEmpty)
          const _EmptyState(
            message: 'Belum ada ruangan. Tekan tombol di bawah untuk menambah.',
          ),
        for (var i = 0; i < items.length; i++)
          _RoomCard(item: items[i], index: i),
        TextButton.icon(
          onPressed: () => ref.read(roomsFormProvider.notifier).add(),
          icon: const Icon(Icons.add),
          label: const Text('Tambah Ruangan'),
        ),
      ],
    );
  }
}

class _RoomCard extends ConsumerWidget {
  const _RoomCard({required this.item, required this.index});

  final Room item;
  final int index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'ID',
                  isDense: true,
                ),
                controller: TextEditingController(text: item.id),
                onChanged: (v) => ref
                    .read(roomsFormProvider.notifier)
                    .update(
                      index,
                      Room(id: v, name: item.name, type: item.type),
                    ),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: TextField(
                decoration: const InputDecoration(
                  labelText: 'Nama',
                  isDense: true,
                ),
                controller: TextEditingController(text: item.name),
                onChanged: (v) => ref
                    .read(roomsFormProvider.notifier)
                    .update(index, Room(id: item.id, name: v, type: item.type)),
              ),
            ),
            const SizedBox(width: 8),
            SizedBox(
              width: 100,
              child: DropdownButtonFormField<String>(
                initialValue: item.type?.label ?? 'kelas',
                items: const [
                  DropdownMenuItem(value: 'kelas', child: Text('Kelas')),
                  DropdownMenuItem(value: 'lab', child: Text('Lab')),
                ],
                onChanged: (v) {
                  if (v != null) {
                    ref
                        .read(roomsFormProvider.notifier)
                        .update(
                          index,
                          Room(
                            id: item.id,
                            name: item.name,
                            type: RoomType.fromJson(v),
                          ),
                        );
                  }
                },
                decoration: const InputDecoration(
                  labelText: 'Tipe',
                  isDense: true,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () async {
                if (await _confirmDelete(context)) {
                  ref.read(roomsFormProvider.notifier).remove(index);
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// PR Instructions panel
// ---------------------------------------------------------------------------

class _PrInstructionsPanel extends ConsumerWidget {
  const _PrInstructionsPanel();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filename = ref.watch(exportFilenameProvider);
    final instructions = generatePrInstructions(filename);
    return ExpansionTile(
      leading: const Icon(Icons.code),
      title: const Text('Instruksi Pull Request'),
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: SelectableText(
            instructions,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 13),
          ),
        ),
      ],
    );
  }
}
