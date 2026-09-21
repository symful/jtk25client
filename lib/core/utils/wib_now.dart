/// WIB (Waktu Indonesia Barat / UTC+7) date utility.
///
/// All date-only comparisons in the app use this helper to avoid
/// device-local timezone issues. Never use [DateTime.now()] directly
/// for date comparisons.
library;

/// Current date in WIB (UTC+7) — date-only, no time component.
DateTime get wibNow {
  final utc = DateTime.now().toUtc();
  final wib = utc.add(const Duration(hours: 7));
  return DateTime(wib.year, wib.month, wib.day);
}
