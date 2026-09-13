/// Editor state management providers using Riverpod 3.x patterns.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/announcement.dart';
import '../../../core/models/dosen.dart';
import '../../../core/models/event.dart';
import '../../../core/models/pengganti.dart';
import '../../../core/models/room.dart';
import '../../../core/models/schedule.dart';
import '../data/editor_data.dart';

// ---------------------------------------------------------------------------
// Selected data type
// ---------------------------------------------------------------------------

class _SelectedTypeNotifier extends Notifier<EditorDataType> {
  @override
  EditorDataType build() => EditorDataType.schedule;

  void select(EditorDataType value) => state = value;
}

/// The currently selected editor data type.
final selectedTypeProvider =
    NotifierProvider<_SelectedTypeNotifier, EditorDataType>(
      _SelectedTypeNotifier.new,
    );

// ---------------------------------------------------------------------------
// Schedule form state
// ---------------------------------------------------------------------------

/// Form state for editing a single session within a day.
class SessionForm {
  SessionForm({
    this.time = '',
    this.courseCode = '',
    this.courseName = '',
    this.type = 'TE',
    this.lecturerCode = '',
    this.lecturer = '',
    this.room = '',
  });

  factory SessionForm.fromSession(Session s) => SessionForm(
    time: s.time,
    courseCode: s.courseCode,
    courseName: s.courseName,
    type: s.type.label,
    lecturerCode: s.lecturerCode,
    lecturer: s.lecturer,
    room: s.room,
  );

  String time;
  String courseCode;
  String courseName;
  String type;
  String lecturerCode;
  String lecturer;
  String room;

  /// Convert to the core model.
  Session toSession() => Session(
    time: time,
    courseCode: courseCode,
    courseName: courseName,
    type: CourseType.fromJson(type) ?? CourseType.te,
    lecturerCode: lecturerCode,
    lecturer: lecturer,
    room: room,
  );

  /// Convert to a raw map for envelope building.
  Map<String, dynamic> toMap() => {
    'time': time,
    'course_code': courseCode,
    'course_name': courseName,
    'type': type,
    'lecturer_code': lecturerCode,
    'lecturer': lecturer,
    'room': room,
  };

  SessionForm copy() => SessionForm(
    time: time,
    courseCode: courseCode,
    courseName: courseName,
    type: type,
    lecturerCode: lecturerCode,
    lecturer: lecturer,
    room: room,
  );
}

/// State for editing a single class schedule.
class ScheduleFormState {
  ScheduleFormState({
    this.classCode = 'D3-2A',
    Map<String, List<SessionForm>>? days,
  }) : days =
           days ??
           {
             'SENIN': <SessionForm>[],
             'SELASA': <SessionForm>[],
             'RABU': <SessionForm>[],
             'KAMIS': <SessionForm>[],
             'JUMAT': <SessionForm>[],
           };

  String classCode;

  /// Sessions per day label (SENIN..JUMAT).
  final Map<String, List<SessionForm>> days;

  /// Build a ScheduleClass model from form data.
  ScheduleClass toScheduleClass() => ScheduleClass(
    className: classCode,
    schedule: days.entries
        .map(
          (e) => DaySchedule(
            day: Day.fromJson(e.key) ?? Day.senin,
            sessions: e.value.map((s) => s.toSession()).toList(),
          ),
        )
        .toList(),
  );

  /// Build the full v2 envelope for schema validation.
  Map<String, dynamic> toEnvelope() => buildScheduleEnvelope(toScheduleClass());
}

class _ScheduleFormNotifier extends Notifier<ScheduleFormState> {
  @override
  ScheduleFormState build() => ScheduleFormState();

  void selectClass(String code) => state = ScheduleFormState(classCode: code);

  void updateSession(String day, int index, SessionForm session) {
    final updated = Map<String, List<SessionForm>>.fromEntries(
      state.days.entries.map(
        (e) => MapEntry(e.key, List<SessionForm>.from(e.value)),
      ),
    );
    updated[day]![index] = session;
    state = ScheduleFormState(classCode: state.classCode, days: updated);
  }

  void addSession(String day) {
    final updated = Map<String, List<SessionForm>>.fromEntries(
      state.days.entries.map(
        (e) => MapEntry(e.key, List<SessionForm>.from(e.value)),
      ),
    );
    updated[day] = [...?updated[day], SessionForm()];
    state = ScheduleFormState(classCode: state.classCode, days: updated);
  }

  void removeSession(String day, int index) {
    final updated = Map<String, List<SessionForm>>.fromEntries(
      state.days.entries.map(
        (e) => MapEntry(e.key, List<SessionForm>.from(e.value)),
      ),
    );
    updated[day]!.removeAt(index);
    state = ScheduleFormState(classCode: state.classCode, days: updated);
  }

  /// Load form state from a ScheduleClass model.
  void loadFromClass(ScheduleClass scheduleClass) {
    final days = <String, List<SessionForm>>{};
    for (final ds in scheduleClass.schedule) {
      days[ds.day.label] = ds.sessions
          .map((s) => SessionForm.fromSession(s))
          .toList();
    }
    // Ensure all weekdays exist.
    for (final day in ['SENIN', 'SELASA', 'RABU', 'KAMIS', 'JUMAT']) {
      days.putIfAbsent(day, () => <SessionForm>[]);
    }
    state = ScheduleFormState(classCode: scheduleClass.className, days: days);
  }
}

/// Provider for the schedule form state.
final scheduleFormProvider =
    NotifierProvider<_ScheduleFormNotifier, ScheduleFormState>(
      _ScheduleFormNotifier.new,
    );

// ---------------------------------------------------------------------------
// Pengganti form state
// ---------------------------------------------------------------------------

/// Form state for a single pengganti session entry.
class PenggantiSessionForm {
  PenggantiSessionForm({
    this.time = '',
    this.courseCode = '',
    this.courseName = '',
    this.type = 'TE',
    this.lecturerCode = '',
    this.lecturer = '',
    this.room = '',
  });

  String time;
  String courseCode;
  String courseName;
  String type;
  String lecturerCode;
  String lecturer;
  String room;

  Map<String, dynamic> toMap() => {
    'time': time,
    'course_code': courseCode,
    'course_name': courseName,
    'type': type,
    'lecturer_code': lecturerCode,
    'lecturer': lecturer,
    'room': room,
  };

  PenggantiSessionForm copy() => PenggantiSessionForm(
    time: time,
    courseCode: courseCode,
    courseName: courseName,
    type: type,
    lecturerCode: lecturerCode,
    lecturer: lecturer,
    room: room,
  );
}

/// Form state for a single pengganti entry.
class PenggantiEntryForm {
  PenggantiEntryForm({
    this.id = '',
    this.classCode = 'D3-2A',
    this.date = '',
    this.kind = 'replace',
    this.note = '',
    List<PenggantiSessionForm>? sessions,
  }) : sessions = sessions ?? <PenggantiSessionForm>[];

  String id;
  String classCode;
  String date;
  String kind;
  String note;
  final List<PenggantiSessionForm> sessions;

  Map<String, dynamic> toMap() => {
    'id': id,
    'class_code': classCode,
    'date': date,
    'kind': kind,
    if (note.isNotEmpty) 'note': note,
    'sessions': sessions.map((s) => s.toMap()).toList(),
  };

  PenggantiEntryForm copy() => PenggantiEntryForm(
    id: id,
    classCode: classCode,
    date: date,
    kind: kind,
    note: note,
    sessions: sessions.map((s) => s.copy()).toList(),
  );
}

/// State for editing pengganti entries.
class PenggantiFormState {
  PenggantiFormState({List<PenggantiEntryForm>? entries})
    : entries = entries ?? <PenggantiEntryForm>[];

  final List<PenggantiEntryForm> entries;

  /// Build a v2 envelope for validation.
  Map<String, dynamic> toEnvelope() {
    final dataItems = entries.map((e) => e.toMap()).toList();
    return {
      'schema': 2,
      'semester': kSemester,
      'updatedAt': DateTime.now().toIso8601String(),
      'data': dataItems,
    };
  }
}

class _PenggantiFormNotifier extends Notifier<PenggantiFormState> {
  @override
  PenggantiFormState build() => PenggantiFormState();

  void addEntry() {
    state = PenggantiFormState(
      entries: [...state.entries, PenggantiEntryForm()],
    );
  }

  void removeEntry(int index) {
    final updated = List<PenggantiEntryForm>.from(state.entries);
    updated.removeAt(index);
    state = PenggantiFormState(entries: updated);
  }

  void updateEntry(int index, PenggantiEntryForm entry) {
    final updated = List<PenggantiEntryForm>.from(state.entries);
    updated[index] = entry;
    state = PenggantiFormState(entries: updated);
  }

  void addSessionToEntry(int entryIndex) {
    final entry = state.entries[entryIndex].copy();
    entry.sessions.add(PenggantiSessionForm());
    updateEntry(entryIndex, entry);
  }

  void removeSessionFromEntry(int entryIndex, int sessionIndex) {
    final entry = state.entries[entryIndex].copy();
    entry.sessions.removeAt(sessionIndex);
    updateEntry(entryIndex, entry);
  }

  void updateSessionInEntry(
    int entryIndex,
    int sessionIndex,
    PenggantiSessionForm session,
  ) {
    final entry = state.entries[entryIndex].copy();
    entry.sessions[sessionIndex] = session;
    updateEntry(entryIndex, entry);
  }

  /// Load from existing pengganti entries.
  void loadFromEntries(List<PenggantiEntry> entries) {
    state = PenggantiFormState(
      entries: entries
          .map(
            (e) => PenggantiEntryForm(
              id: e.id,
              classCode: e.classCode,
              date: e.date,
              kind: e.kind.label,
              note: e.note ?? '',
              sessions: e.sessions
                  .map(
                    (s) => PenggantiSessionForm(
                      time: s.time,
                      courseCode: s.courseCode,
                      courseName: s.courseName,
                      type: s.type.label,
                      lecturerCode: s.lecturerCode,
                      lecturer: s.lecturer,
                      room: s.room,
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }
}

/// Provider for the pengganti form state.
final penggantiFormProvider =
    NotifierProvider<_PenggantiFormNotifier, PenggantiFormState>(
      _PenggantiFormNotifier.new,
    );

// ---------------------------------------------------------------------------
// Generic list form state (for announcements, events, dosen, rooms)
// ---------------------------------------------------------------------------

/// State for editing a list of items (announcements, events, dosen, rooms).
class ListFormState<T> {
  ListFormState({List<T>? items}) : items = items ?? <T>[];

  final List<T> items;
}

/// Notifier for announcement form state.
class _AnnouncementsFormNotifier extends Notifier<List<Announcement>> {
  @override
  List<Announcement> build() => [];

  void load(List<Announcement> items) => state = items;

  void add() {
    state = [
      ...state,
      Announcement(
        id: '',
        title: '',
        body: '',
        createdAt: DateTime.now().toIso8601String(),
      ),
    ];
  }

  void update(int index, Announcement item) {
    final updated = List<Announcement>.from(state);
    updated[index] = item;
    state = updated;
  }

  void remove(int index) {
    final updated = List<Announcement>.from(state);
    updated.removeAt(index);
    state = updated;
  }
}

/// Provider for announcement form state.
final announcementsFormProvider =
    NotifierProvider<_AnnouncementsFormNotifier, List<Announcement>>(
      _AnnouncementsFormNotifier.new,
    );

/// Notifier for events form state.
class _EventsFormNotifier extends Notifier<List<JtkEvent>> {
  @override
  List<JtkEvent> build() => [];

  void load(List<JtkEvent> items) => state = items;

  void add() {
    state = [
      ...state,
      JtkEvent(
        id: '',
        title: '',
        date: DateTime.now().toIso8601String(),
        endDate: DateTime.now().toIso8601String(),
      ),
    ];
  }

  void update(int index, JtkEvent item) {
    final updated = List<JtkEvent>.from(state);
    updated[index] = item;
    state = updated;
  }

  void remove(int index) {
    final updated = List<JtkEvent>.from(state);
    updated.removeAt(index);
    state = updated;
  }
}

/// Provider for events form state.
final eventsFormProvider =
    NotifierProvider<_EventsFormNotifier, List<JtkEvent>>(
      _EventsFormNotifier.new,
    );

/// Notifier for dosen form state.
class _DosenFormNotifier extends Notifier<List<Dosen>> {
  @override
  List<Dosen> build() => [];

  void load(List<Dosen> items) => state = items;

  void add() {
    state = [...state, const Dosen(code: '', name: '')];
  }

  void update(int index, Dosen item) {
    final updated = List<Dosen>.from(state);
    updated[index] = item;
    state = updated;
  }

  void remove(int index) {
    final updated = List<Dosen>.from(state);
    updated.removeAt(index);
    state = updated;
  }
}

/// Provider for dosen form state.
final dosenFormProvider = NotifierProvider<_DosenFormNotifier, List<Dosen>>(
  _DosenFormNotifier.new,
);

/// Notifier for rooms form state.
class _RoomsFormNotifier extends Notifier<List<Room>> {
  @override
  List<Room> build() => [];

  void load(List<Room> items) => state = items;

  void add() {
    state = [...state, const Room(id: '', name: '')];
  }

  void update(int index, Room item) {
    final updated = List<Room>.from(state);
    updated[index] = item;
    state = updated;
  }

  void remove(int index) {
    final updated = List<Room>.from(state);
    updated.removeAt(index);
    state = updated;
  }
}

/// Provider for rooms form state.
final roomsFormProvider = NotifierProvider<_RoomsFormNotifier, List<Room>>(
  _RoomsFormNotifier.new,
);

// ---------------------------------------------------------------------------
// Validation state providers
// ---------------------------------------------------------------------------

/// Current validation errors from schema validation.
final validationErrorsProvider = Provider<List<FieldError>>((ref) {
  final selectedType = ref.watch(selectedTypeProvider);
  final json = switch (selectedType) {
    EditorDataType.schedule => ref.watch(scheduleFormProvider).toEnvelope(),
    EditorDataType.pengganti => ref.watch(penggantiFormProvider).toEnvelope(),
    EditorDataType.announcements => buildAnnouncementsEnvelope(
      ref.watch(announcementsFormProvider),
    ),
    EditorDataType.events => buildEventsEnvelope(ref.watch(eventsFormProvider)),
    EditorDataType.dosen => buildDosenEnvelope(ref.watch(dosenFormProvider)),
    EditorDataType.rooms => buildRoomsEnvelope(ref.watch(roomsFormProvider)),
  };

  final schema = switch (selectedType) {
    EditorDataType.schedule => JtkSchemas.scheduleClass,
    EditorDataType.pengganti => JtkSchemas.pengganti,
    EditorDataType.announcements => JtkSchemas.announcements,
    EditorDataType.events => JtkSchemas.events,
    EditorDataType.dosen => JtkSchemas.dosen,
    EditorDataType.rooms => JtkSchemas.rooms,
  };

  final result = validateAgainst(json, schema);
  return result.errors;
});

/// Whether the current form state is valid (can be exported).
final canExportProvider = Provider<bool>((ref) {
  final errors = ref.watch(validationErrorsProvider);
  return errors.isEmpty;
});

/// The current JSON to export (pretty-printed).
final exportJsonProvider = Provider<String>((ref) {
  final selectedType = ref.watch(selectedTypeProvider);
  final json = switch (selectedType) {
    EditorDataType.schedule => ref.watch(scheduleFormProvider).toEnvelope(),
    EditorDataType.pengganti => ref.watch(penggantiFormProvider).toEnvelope(),
    EditorDataType.announcements => buildAnnouncementsEnvelope(
      ref.watch(announcementsFormProvider),
    ),
    EditorDataType.events => buildEventsEnvelope(ref.watch(eventsFormProvider)),
    EditorDataType.dosen => buildDosenEnvelope(ref.watch(dosenFormProvider)),
    EditorDataType.rooms => buildRoomsEnvelope(ref.watch(roomsFormProvider)),
  };
  return prettyPrintJson(json);
});

/// The current export filename.
final exportFilenameProvider = Provider<String>((ref) {
  final selectedType = ref.watch(selectedTypeProvider);
  final classCode = switch (selectedType) {
    EditorDataType.schedule => ref.watch(scheduleFormProvider).classCode,
    _ => null,
  };
  return exportFilename(selectedType, classCode: classCode);
});
