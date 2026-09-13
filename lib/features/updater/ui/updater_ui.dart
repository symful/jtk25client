import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/github_releases_client.dart';
import '../providers/updater_providers.dart';

/// A dismissible banner that appears when an update is available.
///
/// Intended to be placed at the top of a Scaffold body or inside a Column.
/// Shows the update version and two buttons: "Unduh" (download) and "Nanti" (later).
/// Tapping the banner body opens a full dialog with changelog.
class UpdateBanner extends ConsumerWidget {
  const UpdateBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updaterProvider);

    if (!state.shouldShow) return const SizedBox.shrink();

    final release = state.release!;

    return MaterialBanner(
      content: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Pembaruan tersedia',
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            'Versi ${release.versionString} tersedia. Perbarui sekarang?',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
      leading: const Icon(Icons.system_update),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(updaterProvider.notifier).dismiss();
          },
          child: const Text('Nanti'),
        ),
        FilledButton(
          onPressed: () => _showUpdateDialog(context, ref, release),
          child: const Text('Unduh'),
        ),
      ],
    );
  }
}

/// Shows a dialog with release changelog and a download button.
void _showUpdateDialog(
  BuildContext context,
  WidgetRef ref,
  ReleaseInfo release,
) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text('Pembaruan v${release.versionString}'),
      content: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            if (release.body.isNotEmpty) ...[
              Text('Catatan rilis:', style: Theme.of(ctx).textTheme.labelLarge),
              const SizedBox(height: 8),
              Text(release.body),
            ] else
              const Text('Tidak ada catatan rilis.'),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            ref.read(updaterProvider.notifier).dismiss();
            Navigator.of(ctx).pop();
          },
          child: const Text('Nanti'),
        ),
        FilledButton(
          onPressed: () async {
            Navigator.of(ctx).pop();
            await _downloadApk(release.apkDownloadUrl as String);
          },
          child: const Text('Unduh'),
        ),
      ],
    ),
  );
}

/// Opens the APK download URL in the browser (sideload flow).
///
/// Uses `url_launcher` to open the browser_download_url from GitHub.
/// No REQUEST_INSTALL_PACKAGES permission needed — the browser handles the
/// APK download and the user installs manually from the notification/Downloads.
Future<void> _downloadApk(String url) async {
  final uri = Uri.parse(url);
  if (await canLaunchUrl(uri)) {
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}

/// A widget that listens to the updater provider and shows a banner
/// if an update is available. Place this in your app shell / home page.
///
/// Usage:
/// ```dart
/// Scaffold(
///   body: Column(
///     children: [
///       const UpdateBanner(),
///       Expanded(child: /* main content */),
///     ],
///   ),
/// )
/// ```
///
/// Or as a standalone widget that conditionally renders itself.
class UpdaterShell extends ConsumerWidget {
  const UpdaterShell({super.key, required this.child});

  /// The main app content to render below the banner.
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(updaterProvider);

    return Column(
      children: [
        if (state.shouldShow) const UpdateBanner(),
        Expanded(child: child),
      ],
    );
  }
}
