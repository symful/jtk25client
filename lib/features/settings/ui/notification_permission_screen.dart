/// Notification permission request screen — dedicated full-screen page
/// for explaining and requesting notification permissions.
///
/// States handled:
/// - Not determined (initial) → show CTA button
/// - Granted → success state with topic subscription info
/// - Denied → instructions to enable via system settings
/// - Permanently denied → explicit system settings instructions
/// - Web unsupported → explanation message
///
/// All strings in Bahasa Indonesia.
library;

import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/notifications/_web_helper_stub.dart'
    if (dart.library.js_interop) '../../../core/notifications/_web_helper.dart';
import '../../../core/notifications/fcm_service.dart';
import '../../../core/notifications/notification_providers.dart';
import '../../../core/notifications/notification_service.dart';
import '../../../core/theme/theme.dart';
import '../../schedule/providers/schedule_providers.dart';

/// Permission state for the notification permission screen.
enum _PermissionState {
  /// Permission not yet determined (initial state).
  notDetermined,

  /// Permission granted.
  granted,

  /// Permission denied (user can still request again).
  denied,

  /// Permission permanently denied (must open system settings).
  permanentlyDenied,

  /// Notifications not supported on this platform.
  unsupported,

  /// Loading / checking permission state.
  loading,
}

/// Dedicated full-screen notification permission request page.
class NotificationPermissionScreen extends ConsumerStatefulWidget {
  const NotificationPermissionScreen({super.key});

  @override
  ConsumerState<NotificationPermissionScreen> createState() =>
      _NotificationPermissionScreenState();
}

class _NotificationPermissionScreenState
    extends ConsumerState<NotificationPermissionScreen> {
  _PermissionState _state = _PermissionState.loading;
  bool _requesting = false;
  String? _topicStatus;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _checkPermissionState();
    });
  }

  Future<void> _checkPermissionState() async {
    if (!mounted) return;

    // Web without Notification API support.
    if (kIsWeb && !webNotificationSupported()) {
      setState(() => _state = _PermissionState.unsupported);
      return;
    }

    try {
      // Check current permission state via existing service.
      final service = NotificationService.instance;
      final isEnabled = await service.isEnabled();

      if (!mounted) return;

      if (isEnabled) {
        setState(() {
          _state = _PermissionState.granted;
        });
        await _subscribeToClassTopic();
      } else {
        setState(() => _state = _PermissionState.notDetermined);
      }
    } catch (_) {
      // Platform plugin not available (e.g. test environment).
      if (!mounted) return;
      setState(() => _state = _PermissionState.notDetermined);
    }
  }

  Future<void> _requestPermission() async {
    if (_requesting) return;
    setState(() => _requesting = true);

    try {
      final service = NotificationService.instance;
      final granted = await service.requestPermission();

      if (!mounted) return;

      if (granted) {
        // Enable the notification toggle.
        ref.read(notificationEnabledProvider.notifier).toggle(true);
        setState(() => _state = _PermissionState.granted);
        await _subscribeToClassTopic();
        ref.invalidate(notificationStatusProvider);
      } else {
        // Check if permanently denied.
        try {
          final isEnabled = await service.isEnabled();
          if (!mounted) return;

          if (!isEnabled) {
            setState(() => _state = _PermissionState.permanentlyDenied);
            ref.invalidate(notificationStatusProvider);
          } else {
            setState(() => _state = _PermissionState.denied);
          }
        } catch (_) {
          if (!mounted) return;
          setState(() => _state = _PermissionState.denied);
        }
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _state = _PermissionState.denied);
    } finally {
      if (mounted) {
        setState(() => _requesting = false);
      }
    }
  }

  Future<void> _subscribeToClassTopic() async {
    final selectedClass = ref.read(selectedClassProvider);
    if (selectedClass.isEmpty) {
      setState(() => _topicStatus = 'Pilih kelas terlebih dahulu');
      return;
    }

    setState(() => _topicStatus = 'Menyubscribe topik...');
    await FcmService.instance.subscribeToClassTopic(selectedClass);
    if (!mounted) return;
    setState(
      () => _topicStatus = 'Topik kelas $selectedClass berhasil dilanggani',
    );
  }

  Future<void> _openAppSettings() async {
    if (kIsWeb) return;

    try {
      // Android: open app settings via intent.
      if (!kIsWeb && Platform.isAndroid) {
        await launchUrl(
          Uri.parse('package:com.jtk25.jadwalku'),
          mode: LaunchMode.externalApplication,
        );
      }
    } catch (e) {
      debugPrint('Gagal membuka pengaturan aplikasi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifikasi'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/pengaturan');
            }
          },
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
          child: _buildBody(theme),
        ),
      ),
    );
  }

  Widget _buildBody(ThemeData theme) {
    return switch (_state) {
      _PermissionState.loading => _buildLoading(theme),
      _PermissionState.unsupported => _buildUnsupported(theme),
      _PermissionState.notDetermined => _buildNotDetermined(theme),
      _PermissionState.granted => _buildGranted(theme),
      _PermissionState.denied => _buildDenied(theme),
      _PermissionState.permanentlyDenied => _buildPermanentlyDenied(theme),
    };
  }

  Widget _buildLoading(ThemeData theme) {
    return Center(
      child: Column(
        children: [
          const SizedBox(height: 80),
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            'Memeriksa status notifikasi...',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      ),
    );
  }

  Widget _buildUnsupported(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 48),
        Icon(
          Icons.notifications_off_rounded,
          size: 80,
          color: theme.colorScheme.outline,
        ),
        const SizedBox(height: 24),
        Text(
          'Notifikasi Tidak Didukung',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Browser Anda tidak mendukung notifikasi push. '
          'Gunakan browser modern seperti Chrome atau Firefox untuk '
          'mengaktifkan notifikasi.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildNotDetermined(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 32),
        // Illustration.
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: kBrandBlue.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.notifications_active_rounded,
            size: 64,
            color: kBrandBlue,
          ),
        ),
        const SizedBox(height: 32),
        Text(
          'Aktifkan Notifikasi',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        Text(
          'Dapatkan notifikasi untuk:',
          style: theme.textTheme.bodyLarge?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 20),
        _buildFeatureItem(
          theme,
          icon: Icons.campaign_rounded,
          title: 'Pengumuman & Jadwal Pengganti',
          subtitle: 'Informasi terbaru mengenai perubahan jadwal kuliah',
        ),
        const SizedBox(height: 12),
        _buildFeatureItem(
          theme,
          icon: Icons.alarm_rounded,
          title: 'Pengingat Kelas',
          subtitle: 'Pengingat 15 menit sebelum kelas dimulai',
        ),
        const SizedBox(height: 36),
        // CTA Button.
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _requesting ? null : _requestPermission,
            style: FilledButton.styleFrom(
              backgroundColor: kBrandBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _requesting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Aktifkan Notifikasi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildGranted(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 32),
        // Success illustration.
        Container(
          width: 120,
          height: 120,
          decoration: BoxDecoration(
            color: Colors.green.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_circle_rounded,
            size: 64,
            color: Colors.green,
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'Notifikasi Aktif',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Notifikasi sudah aktif. Anda akan menerima '
          'pembaruan jadwal dan pengingat kelas.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        // Topic subscription status.
        if (_topicStatus != null)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  const Icon(Icons.topic_rounded, color: kBrandBlue),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      _topicStatus!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        // Refresh topic subscription button.
        OutlinedButton.icon(
          onPressed: _subscribeToClassTopic,
          icon: const Icon(Icons.refresh),
          label: const Text('Perbarui Langganan Topik'),
        ),
      ],
    );
  }

  Widget _buildDenied(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 32),
        Icon(
          Icons.notifications_off_rounded,
          size: 80,
          color: theme.colorScheme.error,
        ),
        const SizedBox(height: 24),
        Text(
          'Izin Ditolak',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Izin notifikasi ditolak. Tanpa izin, Anda tidak akan '
          'menerima pembaruan jadwal dan pengingat kelas.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (!kIsWeb)
          Text(
            'Untuk mengaktifkan notifikasi, buka Pengaturan Aplikasi '
            'dan aktifkan izin notifikasi.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        const SizedBox(height: 24),
        // Retry button.
        SizedBox(
          width: double.infinity,
          height: 56,
          child: FilledButton(
            onPressed: _requesting ? null : _requestPermission,
            style: FilledButton.styleFrom(
              backgroundColor: kBrandBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: _requesting
                ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Coba Lagi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
          ),
        ),
        if (!kIsWeb) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: _openAppSettings,
            icon: const Icon(Icons.settings),
            label: const Text('Buka Pengaturan Aplikasi'),
          ),
        ],
      ],
    );
  }

  Widget _buildPermanentlyDenied(ThemeData theme) {
    return Column(
      children: [
        const SizedBox(height: 32),
        Icon(Icons.block_rounded, size: 80, color: theme.colorScheme.error),
        const SizedBox(height: 24),
        Text(
          'Izin Ditolak Permanen',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.error,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 12),
        Text(
          'Izin notifikasi ditolak permanen oleh sistem. '
          'Untuk mengaktifkan notifikasi:',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        if (!kIsWeb) ...[
          _buildInstructionStep(
            theme,
            step: '1',
            text: 'Buka Pengaturan Aplikasi',
          ),
          const SizedBox(height: 8),
          _buildInstructionStep(theme, step: '2', text: 'Pilih Notifikasi'),
          const SizedBox(height: 8),
          _buildInstructionStep(
            theme,
            step: '3',
            text: 'Aktifkan izin notifikasi',
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 56,
            child: FilledButton(
              onPressed: _openAppSettings,
              style: FilledButton.styleFrom(
                backgroundColor: kBrandBlue,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: const Text(
                'Buka Pengaturan Aplikasi',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ] else
          Text(
            'Muat ulang halaman dan berikan izin saat diminta.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
      ],
    );
  }

  Widget _buildFeatureItem(
    ThemeData theme, {
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: kBrandBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: kBrandBlue),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructionStep(
    ThemeData theme, {
    required String step,
    required String text,
  }) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: kBrandBlue,
              child: Text(
                step,
                style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
          ],
        ),
      ),
    );
  }
}
