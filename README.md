# JTK25 Client

Aplikasi jadwal perkuliahan JTK (Jaringan Telekomunikasi dan Komputer) untuk mahasiswa dan dosen Politeknik Negeri Bali.

## Platform

- **Android** (minSdk 23) — dengan notifikasi lokal & background polling
- **Web** — mode single-page application (SPA)

> iOS tidak didukung.

## Fitur

- **Jadwal Kuliah** — jadwal harian/mingguan per kelas, slot merged, istirahat
- **Jadwal Pengganti** — overlay pengganti di atas jadwal normal
- **Pengumuman** — daftar pengumuman kampus
- **Acara** — daftar kegiatan kampus
- **Dosen** — direktori dosen dan jadwal mengajar
- **Ruangan** — ketersediaan ruangan & matriks occupansi
- **Editor** — form input jadwal → JSON valid (untuk kontribusi data)
- **Notifikasi** — notifikasi lokal (Android) + FCM push + WorkManager background polling
- **Pengaturan** — pilih kelas default, kelola notifikasi
- **In-app Update** — cek versi terbaru dari GitHub Releases (Android only)
- **Offline Cache** — Hive-based cache untuk mode tanpa koneksi

## Prasyarat

- Flutter SDK ≥ 3.41.9
- Node.js ≥ 22 (untuk deploy server)
- Android SDK (untuk build APK)
- Chrome (untuk development web)

## Instalasi

```bash
# Install dependencies
flutter pub get

# Run di web
flutter run -d chrome

# Run di Android
flutter run -d <device-id>
```

## Build

```bash
# Build APK release (signed)
flutter build apk --release

# Build web
flutter build web
```

### Signing Android

Release build menggunakan keystore yang dikonfigurasi di `android/key.properties` (di-gitignore).

| File | Lokasi | Keterangan |
|------|--------|------------|
| `release.jks` | `android/app/` | Keystore RSA 2048-bit, alias `jtk25` |
| `key.properties` | `android/` | Pointer ke keystore + credentials |

> ⚠️ Jangan pernah commit file ini. Keystore yang konsisten wajib untuk update tanpa uninstall.

## Struktur Proyek

```
lib/
├── main.dart                    # Entry point, inisialisasi Firebase/Hive/WorkManager
├── app.dart                     # Root widget (MaterialApp.router)
├── core/
│   ├── api/                     # Dio client + interceptors
│   ├── cache/                   # Hive offline cache
│   ├── models/                  # Data models (Schedule, Dosen, Room, dll)
│   ├── notifications/           # FCM service, notifikasi lokal, WorkManager
│   ├── providers/               # Riverpod providers global
│   ├── router/                  # GoRouter (StatefulShellRoute untuk tab nav)
│   ├── shell/                   # AppShell (bottom nav), NotFoundPage
│   ├── theme/                   # Material 3 light theme
│   ├── ui/                      # Widget bersama
│   └── utils/                   # Helper functions
├── features/
│   ├── schedule/                # Jadwal kuliah (harian/mingguan)
│   ├── pengganti/               # Jadwal pengganti
│   ├── announcements/           # Pengumuman kampus
│   ├── events/                  # Kegiatan kampus
│   ├── lecturers/               # Direktori dosen
│   ├── rooms/                   # Ruangan + matriks ketersediaan
│   ├── editor/                  # Editor jadwal (form → JSON)
│   ├── settings/                # Pengaturan aplikasi + notifikasi
│   └── updater/                 # In-app update (GitHub Releases)
└── firebase_options.dart.example # Template Firebase config
```

### Arsitektur

- **State Management**: Riverpod 3.x (Notifier/NotifierProvider — bukan StateProvider)
- **Navigasi**: GoRouter dengan `StatefulShellRoute.indexedStack` untuk tab preservation
- **Networking**: Dio dengan ETag caching & manual 304 handling
- **Offline**: Hive CE sebagai local cache (network-first, cache-fallback)
- **Notifikasi**: FCM push (Android) + WorkManager background polling (15 menit) + local notifications

## Rute Aplikasi

| Path | Deskripsi |
|------|-----------|
| `/` | Jadwal hari ini |
| `/jadwal/:class` | Jadwal per kelas |
| `/pengganti` | Jadwal pengganti |
| `/dosen` | Daftar dosen |
| `/dosen/:code` | Detail dosen |
| `/ruangan` | Daftar ruangan |
| `/ruangan/matriks` | Matriks ketersediaan |
| `/ruangan/:id` | Detail ruangan |
| `/pengumuman` | Daftar pengumuman |
| `/acara` | Daftar acara |
| `/editor` | Editor jadwal |
| `/pengaturan` | Pengaturan aplikasi |
| `/pengaturan/notifikasi` | Pengaturan notifikasi |

## CI/CD

### Client CI (`.github/workflows/ci.yml`)

- Trigger: push/PR ke `main` (ubah di `lib/`, `test/`, `pubspec.*`)
- Jobs:
  1. **Analyze & Test** — `flutter analyze` + `flutter test`
  2. **Build Web** — `flutter build web` + upload artifact

### Client Release (`.github/workflows/release.yml`)

- Trigger: push tag `v*`
- Build APK release → buat GitHub Release dengan file APK

## Konfigurasi Firebase

File konfigurasi Firebase **tidak di-commit** ke repo (berisi API key). Sebelum build, buat file-file berikut:

| File | Lokasi | Cara mendapatkannya |
|------|--------|---------------------|
| `google-services.json` | `android/app/` | Firebase Console → Project Settings → Android app |
| `firebase_options.dart` | `lib/` | Jalankan `flutterfire configure` |
| `firebase-messaging-sw.js` | `web/` | Salin dari `.example` lalu isi nilai Firebase |

**Project Firebase:** `numeric-lead-265602`

> ⚠️ Jangan pernah commit file konfigurasi Firebase yang sudah diisi — file ini sudah di-gitignore.

## Pull Request Flow

1. Buat branch dari `main`: `git checkout -b feat/nama-fitur`
2. Implementasi perubahan dengan commit yang deskriptif
3. Pastikan `flutter analyze` bersih (0 issues)
4. Push dan buka PR ke `main`
5. Tunggu review dan CI passing

## Lisensi

SSPL v1 — Lihat [LICENSE](LICENSE) untuk detail.
