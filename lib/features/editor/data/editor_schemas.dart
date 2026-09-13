/// Embedded JSON Schema definitions for editor validation.
///
/// These schemas are copied from server/schemas/*.json for single-source-of-truth
/// semantics. Any changes to server schemas must be reflected here.
library;

const String scheduleClassSchemaJson = r'''
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://jtk25.my.id/schemas/schedule-class.json",
  "title": "Schedule Class",
  "description": "Jadwal tetap per kelas untuk satu semester",
  "type": "object",
  "required": ["schema", "semester", "updatedAt", "data"],
  "properties": {
    "schema": { "type": "integer", "const": 2 },
    "semester": { "type": "string", "pattern": "^\\d{4}/\\d{4}-(GANJIL|GENAP)$" },
    "updatedAt": { "type": "string", "format": "date-time" },
    "data": {
      "type": "object",
      "required": ["class_name", "schedule"],
      "properties": {
        "class_name": { "type": "string", "pattern": "^D[34]-\\d+[A-Z](-\\w+)?$" },
        "schedule": { "type": "array", "items": { "$ref": "#/$defs/DaySchedule" } }
      },
      "additionalProperties": false
    }
  },
  "additionalProperties": false,
  "$defs": {
    "DotTime": { "type": "string", "pattern": "^\\d{2}\\.\\d{2}-\\d{2}\\.\\d{2}$" },
    "Day": { "type": "string", "enum": ["SENIN", "SELASA", "RABU", "KAMIS", "JUMAT", "SABTU", "MINGGU"] },
    "CourseType": { "type": "string", "enum": ["TE", "PR"] },
    "Session": {
      "type": "object",
      "required": ["time", "course_code", "course_name", "type", "lecturer_code", "lecturer", "room"],
      "properties": {
        "time": { "$ref": "#/$defs/DotTime" },
        "course_code": { "type": "string", "pattern": "^25(IF|TI)\\d{4}$" },
        "course_name": { "type": "string", "minLength": 1 },
        "type": { "$ref": "#/$defs/CourseType" },
        "lecturer_code": { "type": "string", "minLength": 1 },
        "lecturer": { "type": "string", "minLength": 1 },
        "room": { "type": "string", "minLength": 1 }
      },
      "additionalProperties": false
    },
    "DaySchedule": {
      "type": "object",
      "required": ["day", "sessions"],
      "properties": {
        "day": { "$ref": "#/$defs/Day" },
        "sessions": { "type": "array", "items": { "$ref": "#/$defs/Session" } }
      },
      "additionalProperties": false
    }
  }
}
''';

const String penggantiSchemaJson = r'''
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://jtk25.my.id/schemas/pengganti.json",
  "title": "Pengganti",
  "description": "Daftar jadwal pengganti (dated overrides)",
  "type": "object",
  "required": ["schema", "semester", "updatedAt", "data"],
  "properties": {
    "schema": { "type": "integer", "const": 2 },
    "semester": { "type": "string", "pattern": "^\\d{4}/\\d{4}-(GANJIL|GENAP)$" },
    "updatedAt": { "type": "string", "format": "date-time" },
    "data": { "type": "array", "items": { "$ref": "#/$defs/PenggantiEntry" } }
  },
  "additionalProperties": false,
  "$defs": {
    "DotTime": { "type": "string", "pattern": "^\\d{2}\\.\\d{2}-\\d{2}\\.\\d{2}$" },
    "Day": { "type": "string", "enum": ["SENIN", "SELASA", "RABU", "KAMIS", "JUMAT", "SABTU", "MINGGU"] },
    "CourseType": { "type": "string", "enum": ["TE", "PR"] },
    "PenggantiKind": { "type": "string", "enum": ["replace", "add", "info"] },
    "Session": {
      "type": "object",
      "required": ["time", "course_code", "course_name", "type", "lecturer_code", "lecturer", "room"],
      "properties": {
        "time": { "$ref": "#/$defs/DotTime" },
        "course_code": { "type": "string" },
        "course_name": { "type": "string", "minLength": 1 },
        "type": { "$ref": "#/$defs/CourseType" },
        "lecturer_code": { "type": "string", "minLength": 1 },
        "lecturer": { "type": "string", "minLength": 1 },
        "room": { "type": "string", "minLength": 1 }
      },
      "additionalProperties": false
    },
    "PenggantiEntry": {
      "type": "object",
      "required": ["id", "class_code", "date", "kind"],
      "properties": {
        "id": { "type": "string" },
        "class_code": { "type": "string" },
        "date": { "type": "string", "format": "date" },
        "kind": { "$ref": "#/$defs/PenggantiKind" },
        "note": { "type": "string" },
        "sessions": { "type": "array", "items": { "$ref": "#/$defs/Session" } }
      },
      "additionalProperties": false
    }
  }
}
''';

const String announcementsSchemaJson = r'''
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://jtk25.my.id/schemas/announcements.json",
  "title": "Announcements",
  "type": "object",
  "required": ["schema", "semester", "updatedAt", "data"],
  "properties": {
    "schema": { "type": "integer", "const": 2 },
    "semester": { "type": "string", "pattern": "^\\d{4}/\\d{4}-(GANJIL|GENAP)$" },
    "updatedAt": { "type": "string", "format": "date-time" },
    "data": { "type": "array", "items": { "$ref": "#/$defs/Announcement" } }
  },
  "additionalProperties": false,
  "$defs": {
    "Announcement": {
      "type": "object",
      "required": ["id", "title", "body", "createdAt"],
      "properties": {
        "id": { "type": "string" },
        "title": { "type": "string", "minLength": 1 },
        "body": { "type": "string", "minLength": 1 },
        "pinned": { "type": "boolean", "default": false },
        "createdAt": { "type": "string", "format": "date-time" },
        "expiresAt": { "type": "string", "format": "date-time" }
      },
      "additionalProperties": false
    }
  }
}
''';

const String eventsSchemaJson = r'''
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://jtk25.my.id/schemas/events.json",
  "title": "Events",
  "type": "object",
  "required": ["schema", "semester", "updatedAt", "data"],
  "properties": {
    "schema": { "type": "integer", "const": 2 },
    "semester": { "type": "string", "pattern": "^\\d{4}/\\d{4}-(GANJIL|GENAP)$" },
    "updatedAt": { "type": "string", "format": "date-time" },
    "data": { "type": "array", "items": { "$ref": "#/$defs/Event" } }
  },
  "additionalProperties": false,
  "$defs": {
    "Event": {
      "type": "object",
      "required": ["id", "title", "date", "endDate"],
      "properties": {
        "id": { "type": "string" },
        "title": { "type": "string", "minLength": 1 },
        "description": { "type": "string" },
        "date": { "type": "string", "format": "date-time" },
        "endDate": { "type": "string", "format": "date-time" },
        "location": { "type": "string" },
        "category": { "type": "string" }
      },
      "additionalProperties": false
    }
  }
}
''';

const String dosenSchemaJson = r'''
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://jtk25.my.id/schemas/dosen.json",
  "title": "Dosen",
  "type": "object",
  "required": ["schema", "semester", "updatedAt", "data"],
  "properties": {
    "schema": { "type": "integer", "const": 2 },
    "semester": { "type": "string", "pattern": "^\\d{4}/\\d{4}-(GANJIL|GENAP)$" },
    "updatedAt": { "type": "string", "format": "date-time" },
    "data": { "type": "array", "items": { "$ref": "#/$defs/Dosen" } }
  },
  "additionalProperties": false,
  "$defs": {
    "Dosen": {
      "type": "object",
      "required": ["code", "name"],
      "properties": {
        "code": { "type": "string", "minLength": 1 },
        "name": { "type": "string", "minLength": 1 },
        "email": { "type": "string", "format": "email" }
      },
      "additionalProperties": false
    }
  }
}
''';

const String roomsSchemaJson = r'''
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "$id": "https://jtk25.my.id/schemas/rooms.json",
  "title": "Rooms",
  "type": "object",
  "required": ["schema", "semester", "updatedAt", "data"],
  "properties": {
    "schema": { "type": "integer", "const": 2 },
    "semester": { "type": "string", "pattern": "^\\d{4}/\\d{4}-(GANJIL|GENAP)$" },
    "updatedAt": { "type": "string", "format": "date-time" },
    "data": { "type": "array", "items": { "$ref": "#/$defs/Room" } }
  },
  "additionalProperties": false,
  "$defs": {
    "Room": {
      "type": "object",
      "required": ["id", "name"],
      "properties": {
        "id": { "type": "string", "minLength": 1 },
        "name": { "type": "string", "minLength": 1 },
        "type": { "type": "string", "enum": ["kelas", "lab"] }
      },
      "additionalProperties": false
    }
  }
}
''';
