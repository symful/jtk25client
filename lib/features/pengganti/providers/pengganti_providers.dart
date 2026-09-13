/// Pengganti feature providers — filtering and detail state.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/pengganti.dart';
import '../../../core/providers/providers.dart';

/// Filtered pengganti entries for a specific class code.
final classPenggantiProvider = Provider.family<List<PenggantiEntry>, String>((
  ref,
  classCode,
) {
  final entries = ref.watch(penggantiProvider);
  return entries.whenOrNull(
        data: (data) => data.where((e) => e.classCode == classCode).toList(),
      ) ??
      [];
});

/// Currently viewed pengganti entry for the detail sheet.
class _PenggantiDetailNotifier extends Notifier<PenggantiEntry?> {
  @override
  PenggantiEntry? build() => null;

  void show(PenggantiEntry entry) => state = entry;
  void dismiss() => state = null;
}

/// Pengganti detail entry for bottom sheet display.
final penggantiDetailProvider =
    NotifierProvider<_PenggantiDetailNotifier, PenggantiEntry?>(
      _PenggantiDetailNotifier.new,
    );
