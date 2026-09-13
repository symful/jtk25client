/// Editor data layer: schema-based validation, envelope export, and PR instructions.
library;

import 'dart:convert';

import 'package:json_schema/json_schema.dart';

import '../../../core/models/announcement.dart';
import '../../../core/models/dosen.dart';
import '../../../core/models/event.dart';
import '../../../core/models/pengganti.dart';
import '../../../core/models/room.dart';
import '../../../core/models/schedule.dart';
import 'editor_schemas.dart';

/// Pre-compiled JSON Schema instances, lazily initialized.
class JtkSchemas {
  JtkSchemas._();

  static JsonSchema? _scheduleClass;
  static JsonSchema? _pengganti;
  static JsonSchema? _announcements;
  static JsonSchema? _events;
  static JsonSchema? _dosen;
  static JsonSchema? _rooms;

  static JsonSchema get scheduleClass => _scheduleClass ??= JsonSchema.create(
    jsonDecode(scheduleClassSchemaJson) as Map<String, dynamic>,
  );

  static JsonSchema get pengganti => _pengganti ??= JsonSchema.create(
    jsonDecode(penggantiSchemaJson) as Map<String, dynamic>,
  );

  static JsonSchema get announcements => _announcements ??= JsonSchema.create(
    jsonDecode(announcementsSchemaJson) as Map<String, dynamic>,
  );

  static JsonSchema get events => _events ??= JsonSchema.create(
    jsonDecode(eventsSchemaJson) as Map<String, dynamic>,
  );

  static JsonSchema get dosen => _dosen ??= JsonSchema.create(
    jsonDecode(dosenSchemaJson) as Map<String, dynamic>,
  );

  static JsonSchema get rooms => _rooms ??= JsonSchema.create(
    jsonDecode(roomsSchemaJson) as Map<String, dynamic>,
  );

  /// Reset cached schemas (for testing).
  static void reset() {
    _scheduleClass = null;
    _pengganti = null;
    _announcements = null;
    _events = null;
    _dosen = null;
    _rooms = null;
  }
}

/// A single field-level validation error.
class FieldError {
  const FieldError({required this.path, required this.message});

  /// Instance path from the JSON Schema validator, e.g. "/data/schedule/0/sessions/0/time".
  final String path;

  /// Human-readable error message.
  final String message;

  /// Extract the field key from the instance path for form mapping.
  ///
  /// E.g. "/data/schedule/0/sessions/0/time" → "schedule.0.sessions.0.time"
  String get fieldKey => path.startsWith('/') ? path.substring(1) : path;
}

/// Validation result wrapping schema validation output.
class ValidationResult {
  const ValidationResult({required this.isValid, required this.errors});

  final bool isValid;
  final List<FieldError> errors;

  /// Get errors for a specific field path prefix.
  List<FieldError> errorsFor(String pathPrefix) =>
      errors.where((e) => e.fieldKey.startsWith(pathPrefix)).toList();
}

/// Validate a JSON object against the given [schema].
ValidationResult validateAgainst(dynamic instance, JsonSchema schema) {
  final result = schema.validate(instance);
  return ValidationResult(
    isValid: result.isValid,
    errors: result.errors
        .map((e) => FieldError(path: e.instancePath, message: e.message))
        .toList(),
  );
}

/// Class-code to data filename mapping.
const Map<String, String> kClassFileNameMap = {
  'D3-3A': 'schedules_D3_S3_A',
  'D3-3B': 'schedules_D3_S3_B',
  'D4-3T-A': 'schedules_D4_S3T_A',
  'D4-3T-B': 'schedules_D4_S3T_B',
  'D4-3T-C': 'schedules_D3_S3_C',
  'D4-3T-D': 'schedules_D3_S3_D',
};

/// Fixed semester string for v2 envelopes.
const String kSemester = '2026/2027-GANJIL';

/// Build a schedule v2 envelope from a [ScheduleClass].
Map<String, dynamic> buildScheduleEnvelope(ScheduleClass scheduleClass) {
  return {
    'schema': 2,
    'semester': kSemester,
    'updatedAt': DateTime.now().toIso8601String(),
    'data': scheduleClass.toJson(),
  };
}

/// Build a pengganti v2 envelope from a list of [PenggantiEntry].
Map<String, dynamic> buildPenggantiEnvelope(List<PenggantiEntry> entries) {
  return {
    'schema': 2,
    'semester': kSemester,
    'updatedAt': DateTime.now().toIso8601String(),
    'data': entries.map((e) => e.toJson()).toList(),
  };
}

/// Build an announcements v2 envelope.
Map<String, dynamic> buildAnnouncementsEnvelope(List<Announcement> items) {
  return {
    'schema': 2,
    'semester': kSemester,
    'updatedAt': DateTime.now().toIso8601String(),
    'data': items.map((a) => a.toJson()).toList(),
  };
}

/// Build an events v2 envelope.
Map<String, dynamic> buildEventsEnvelope(List<JtkEvent> items) {
  return {
    'schema': 2,
    'semester': kSemester,
    'updatedAt': DateTime.now().toIso8601String(),
    'data': items.map((e) => e.toJson()).toList(),
  };
}

/// Build a dosen v2 envelope.
Map<String, dynamic> buildDosenEnvelope(List<Dosen> items) {
  return {
    'schema': 2,
    'semester': kSemester,
    'updatedAt': DateTime.now().toIso8601String(),
    'data': items.map((d) => d.toJson()).toList(),
  };
}

/// Build a rooms v2 envelope.
Map<String, dynamic> buildRoomsEnvelope(List<Room> items) {
  return {
    'schema': 2,
    'semester': kSemester,
    'updatedAt': DateTime.now().toIso8601String(),
    'data': items.map((r) => r.toJson()).toList(),
  };
}

/// Get the data filename for a given data type and optional class code.
String exportFilename(EditorDataType type, {String? classCode}) {
  return switch (type) {
    EditorDataType.schedule =>
      '${kClassFileNameMap[classCode ?? ''] ?? 'schedules'}.json',
    EditorDataType.pengganti => 'pengganti.json',
    EditorDataType.announcements => 'announcements.json',
    EditorDataType.events => 'events.json',
    EditorDataType.dosen => 'dosen.json',
    EditorDataType.rooms => 'rooms.json',
  };
}

/// Editor data types matching the 6 schema categories.
enum EditorDataType {
  schedule('Jadwal Tetap'),
  pengganti('Jadwal Pengganti'),
  announcements('Pengumuman'),
  events('Acara'),
  dosen('Dosen'),
  rooms('Ruangan');

  const EditorDataType(this.label);

  /// Indonesian label for the UI.
  final String label;
}

/// Generate PR instructions in Bahasa Indonesia for a given filename.
String generatePrInstructions(String filename) {
  final targetName = filename.replaceAll('.json', '').replaceAll('_', ' ');
  return '''Langkah-langkah mengirim perubahan:

1. Fork repository symful/jtk25server
2. Clone fork Anda ke komputer
3. Salin file "$filename" ke folder data/ di repository
4. Commit perubahan dengan pesan: Update $targetName
5. Push ke branch fork Anda
6. Buka pull request ke symful/jtk25server/main

Gunakan link berikut untuk pull request:
https://github.com/symful/jtk25server/compare/main...YOUR_USERNAME:jtk25server:main

Ganti YOUR_USERNAME dengan username GitHub Anda.

Judul PR yang disarankan: Update $targetName''';
}

/// Pretty-print a JSON object to a formatted string.
String prettyPrintJson(Map<String, dynamic> json) {
  return const JsonEncoder.withIndent('  ').convert(json);
}
