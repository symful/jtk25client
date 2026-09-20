/// Privacy policy page for JTK25 app.
///
/// Static page displaying the privacy policy in Bahasa Indonesia.
/// Accessible from Settings (Pengaturan) as a sub-route.
/// All strings in Bahasa Indonesia.
library;

import 'package:flutter/material.dart';

/// Privacy policy page.
class PrivacyPage extends StatelessWidget {
  const PrivacyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kebijakan Privasi')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _Section(
            title: 'Pendahuluan',
            body:
                'Kebijakan Privasi ini menjelaskan bagaimana aplikasi JTK 25 '
                'mengumpulkan, menggunakan, dan melindungi data pengguna. '
                'Aplikasi ini dikembangkan oleh Program Studi Teknik Komputer '
                'dan Informatika, Politeknik Negeri Bandung untuk keperluan '
                'akademik mahasiswa.',
          ),
          _Section(
            title: 'Pengumpulan Data',
            body:
                'Aplikasi ini mengumpulkan data berikut untuk keperluan '
                'penyediaan layanan:\n\n'
                '- Data jadwal perkuliahan, termasuk mata kuliah, ruangan, '
                'waktu, dan dosen pengampu.\n'
                '- Data ruangan yang tersedia di lingkungan kampus.\n'
                '- Data pengumuman resmi dari program studi.\n\n'
                'Data ini bersumber dari server institusi dan ditampilkan '
                'kepada pengguna sesuai kebutuhan.',
          ),
          _Section(
            title: 'Firebase Cloud Messaging (FCM)',
            body:
                'Aplikasi menggunakan Firebase Cloud Messaging (FCM) untuk '
                'mengirimkan notifikasi kepada pengguna terkait perubahan '
                'jadwal, pengumuman penting, dan informasi lainnya.\n\n'
                'FCM dapat mengumpulkan data identifikasi perangkat untuk '
                'keperluan pengiriman notifikasi. Anda dapat menonaktifkan '
                'notifikasi kapan saja melalui pengaturan aplikasi atau '
                'pengaturan perangkat Anda.',
          ),
          _Section(
            title: 'Penyimpanan Lokal',
            body:
                'Aplikasi menyimpan beberapa data secara lokal di perangkat '
                'Anda, termasuk:\n\n'
                '- Pilihan kelas yang dipilih.\n'
                '- Pengaturan tema (terang/gelap/sistem).\n'
                '- Status notifikasi.\n\n'
                'Data lokal ini hanya disimpan di perangkat Anda dan tidak '
                'dikirim ke server manapun.',
          ),
          _Section(
            title: 'Berbagi Data',
            body:
                'Aplikasi ini tidak menjual, memperdagangkan, atau '
                'mentransfer data pengguna kepada pihak ketiga. Data yang '
                'dikumpulkan hanya digunakan untuk keperluan penyediaan '
                'layanan dalam aplikasi.',
          ),
          _Section(
            title: 'Keamanan Data',
            body:
                'Kami menerapkan langkah-langkah keamanan yang wajar untuk '
                'melindungi data pengguna. Namun, tidak ada metode '
                'transmisi atau penyimpanan elektronik yang sepenuhnya '
                'aman. Kami berusaha menggunakan cara yang paling aman '
                'untuk melindungi data Anda.',
          ),
          _Section(
            title: 'Hak Pengguna',
            body:
                'Anda memiliki hak untuk:\n\n'
                '- Mengetahui data apa saja yang dikumpulkan oleh aplikasi.\n'
                '- Menonaktifkan notifikasi kapan saja.\n'
                '- Mengubah pilihan kelas dan pengaturan tema.\n'
                '- Menghapus data lokal dengan menghapus aplikasi dari '
                'perangkat.',
          ),
          _Section(
            title: 'Perubahan Kebijakan',
            body:
                'Kebijakan Privasi ini dapat diperbarui dari waktu ke waktu. '
                'Perubahan akan dipublikasikan di dalam aplikasi. '
                'Disarankan untuk meninjau kebijakan ini secara berkala.',
          ),
          _Section(
            title: 'Kontak',
            body:
                'Jika Anda memiliki pertanyaan mengenai Kebijakan Privasi '
                'ini, silakan hubungi:\n\n'
                'Program Studi Teknik Komputer dan Informatika\n'
                'Politeknik Negeri Bandung\n'
                'Jl. Gegerkalong Hilir, Ciwaruga, Kec. Parongpong, '
                'Kabupaten Bandung Barat, Jawa Barat 40559',
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Section widget — reusable for each policy section.
// ---------------------------------------------------------------------------

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.body});

  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(body, style: textTheme.bodyMedium?.copyWith(height: 1.5)),
        ],
      ),
    );
  }
}
