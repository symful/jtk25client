/// Shared pull-to-refresh helpers for all list screens.
///
/// Provides [refreshData] (provider invalidation + change detection + snackbar)
/// and [AppRefreshButton] (AppBar icon with loading state) to avoid
/// duplicating refresh logic across screens.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../cache/offline_cache.dart';
import '../providers/providers.dart';
import '../utils/debug_log.dart';

/// Refresh data by invalidating providers and optionally comparing cached
/// JSON strings for change detection.
///
/// When [keys] are provided, snapshots cached JSON before/after and shows
/// "Data diperbarui" or "Data sudah terbaru". When only [endpoints] are
/// provided (legacy callers), just refreshes without change detection.
///
/// On failure, shows "Gagal memperbarui data".
Future<void> refreshData(
  BuildContext context,
  WidgetRef ref, {
  List<CacheKey>? keys,
  List<String>? endpoints,
  required Future<void> Function() refresh,
}) async {
  final cache = ref.read(offlineCacheProvider);

  // Snapshot current cached JSON for change detection (when keys provided).
  final oldSnapshots = <CacheKey, String?>{};
  if (keys != null) {
    for (final key in keys) {
      oldSnapshots[key] = cache.load(key)?.json;
    }
  }

  try {
    await refresh();

    // When keys are provided, compare new cached JSON with snapshot.
    if (keys != null) {
      var changed = false;
      for (final key in keys) {
        final newJson = cache.load(key)?.json;
        if (newJson != oldSnapshots[key]) {
          changed = true;
          break;
        }
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(changed ? 'Data diperbarui' : 'Data sudah terbaru'),
            duration: const Duration(seconds: 1),
          ),
        );
      }
    } else {
      // Legacy callers (endpoints only) — just confirm refresh.
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Data diperbarui'),
            duration: Duration(seconds: 1),
          ),
        );
      }
    }
  } on Object catch (e) {
    debugLog('[RefreshData] refresh failed: $e');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            kDebugMode ? 'Gagal memperbarui: $e' : 'Gagal memperbarui data',
          ),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }
}

/// AppBar refresh [IconButton] with a built-in loading spinner.
///
/// Used as a web/desktop affordance where pull-to-refresh is not available.
class AppRefreshButton extends StatefulWidget {
  const AppRefreshButton({required this.onRefresh, super.key});

  /// Called when the user taps the refresh icon.
  final Future<void> Function() onRefresh;

  @override
  State<AppRefreshButton> createState() => _AppRefreshButtonState();
}

class _AppRefreshButtonState extends State<AppRefreshButton> {
  bool _refreshing = false;

  @override
  Widget build(BuildContext context) {
    if (_refreshing) {
      return const Padding(
        padding: EdgeInsets.all(12),
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    return IconButton(
      icon: const Icon(Icons.refresh),
      tooltip: 'Segarkan data',
      onPressed: () async {
        setState(() => _refreshing = true);
        await widget.onRefresh();
        if (mounted) setState(() => _refreshing = false);
      },
    );
  }
}
