/// Meta response and schema guard for unknown schema versions.
library;

/// The current supported schema version.
const int currentSchemaVersion = 2;

/// Result of parsing a response with a schema field.
sealed class SchemaResult<T> {
  const SchemaResult();
}

/// Successfully parsed data with the expected schema.
class SchemaOk<T> extends SchemaResult<T> {
  const SchemaOk(this.data);
  final T data;
}

/// Schema version is higher than supported — the app needs an update.
class SchemaTooNew extends SchemaResult<Never> {
  const SchemaTooNew(this.receivedSchema);
  final int receivedSchema;

  String get message =>
      'Perlu update aplikasi. Schema v$receivedSchema belum didukung.';
}

/// Schema version is zero or missing — treat as unsupported.
class SchemaUnknown extends SchemaResult<Never> {
  const SchemaUnknown(this.receivedSchema);
  final int? receivedSchema;
}

/// Guard: if [schema] > [currentSchemaVersion], return [SchemaTooNew].
/// If schema is null/0, return [SchemaUnknown].
/// Otherwise return null (schema is acceptable).
SchemaResult<void>? guardSchema(int? schema) {
  if (schema == null || schema <= 0) return const SchemaUnknown(null);
  if (schema > currentSchemaVersion) return SchemaTooNew(schema);
  return null; // OK
}

/// Meta API response: {schema, dataVersion}.
class MetaResponse {
  const MetaResponse({required this.schema, required this.dataVersion});

  final int schema;
  final String dataVersion;

  factory MetaResponse.fromJson(Map<String, dynamic> json) {
    return MetaResponse(
      schema: json['schema'] as int,
      dataVersion: json['dataVersion'] as String,
    );
  }
}
