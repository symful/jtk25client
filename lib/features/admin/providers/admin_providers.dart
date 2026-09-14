/// Admin feature providers — auth state, schedules, class selection.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/admin_data.dart';

// ---------------------------------------------------------------------------
// Admin API client (singleton)
// ---------------------------------------------------------------------------

/// Singleton [AdminApi] client.
final adminApiProvider = Provider<AdminApi>((ref) {
  final api = AdminApi();
  ref.onDispose(api.close);
  return api;
});

// ---------------------------------------------------------------------------
// Auth state
// ---------------------------------------------------------------------------

/// Authentication state for the admin feature.
class AdminAuthState {
  const AdminAuthState({
    this.isAuthenticated = false,
    this.scope = '',
    this.error,
  });

  final bool isAuthenticated;
  final String scope;
  final String? error;

  AdminAuthState copyWith({
    bool? isAuthenticated,
    String? scope,
    String? error,
  }) {
    return AdminAuthState(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      scope: scope ?? this.scope,
      error: error,
    );
  }
}

/// Notifier for admin authentication state.
class _AdminAuthNotifier extends Notifier<AdminAuthState> {
  @override
  AdminAuthState build() => const AdminAuthState();

  /// Attempt to authenticate with password.
  Future<bool> login(String password) async {
    final api = ref.read(adminApiProvider);
    try {
      final result = await api.auth(password);
      if (result.ok) {
        state = AdminAuthState(isAuthenticated: true, scope: result.scope);
        return true;
      }
      state = AdminAuthState(error: 'Kata sandi salah');
      return false;
    } catch (e) {
      state = AdminAuthState(error: 'Gagal terhubung ke server');
      return false;
    }
  }

  /// Logout and clear auth state.
  void logout() {
    ref.read(adminApiProvider).clearToken();
    state = const AdminAuthState();
  }

  /// Clear any error message.
  void clearError() {
    if (state.error != null) {
      state = state.copyWith(error: null);
    }
  }
}

/// Admin authentication state.
final adminAuthProvider = NotifierProvider<_AdminAuthNotifier, AdminAuthState>(
  _AdminAuthNotifier.new,
);

// ---------------------------------------------------------------------------
// Admin schedules
// ---------------------------------------------------------------------------

/// Notifier for admin schedule data.
class _AdminSchedulesNotifier
    extends Notifier<AsyncValue<AdminSchedulesResponse?>> {
  @override
  AsyncValue<AdminSchedulesResponse?> build() => const AsyncValue.data(null);

  /// Fetch schedules from the admin API.
  Future<void> fetch() async {
    state = const AsyncValue.loading();
    final api = ref.read(adminApiProvider);
    try {
      final result = await api.getSchedules();
      state = AsyncValue.data(result);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Force refresh schedules.
  Future<void> refresh() async {
    final api = ref.read(adminApiProvider);
    try {
      final result = await api.getSchedules();
      state = AsyncValue.data(result);
    } catch (e) {
      state = AsyncValue.error(e, StackTrace.current);
    }
  }

  /// Reset to initial state.
  void reset() {
    state = const AsyncValue.data(null);
  }
}

/// Admin schedules data (AsyncValue).
final adminSchedulesProvider =
    NotifierProvider<
      _AdminSchedulesNotifier,
      AsyncValue<AdminSchedulesResponse?>
    >(_AdminSchedulesNotifier.new);

// ---------------------------------------------------------------------------
// Selected admin class
// ---------------------------------------------------------------------------

/// Notifier for the currently selected class in the admin view.
class _SelectedAdminClassNotifier extends Notifier<String> {
  @override
  String build() => '';

  /// Select a class.
  void select(String className) => state = className;

  /// Auto-select the first class if available.
  void autoSelect(List<String> classNames) {
    if (state.isEmpty && classNames.isNotEmpty) {
      state = classNames.first;
    }
  }
}

/// Currently selected class in the admin schedule view.
final selectedAdminClassProvider =
    NotifierProvider<_SelectedAdminClassNotifier, String>(
      _SelectedAdminClassNotifier.new,
    );
