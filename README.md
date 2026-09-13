# JTK25 Client

Aplikasi jadwal perkuliahan JTK (Jaringan Telekomunikasi dan Komputer) untuk mahasiswa dan dosen.

## Platform

- Android (minSdk 23)
- Windows
- Web

## Instalasi

### Prasyarat

- Flutter SDK ≥ 3.24.0
- Android SDK (untuk build APK)
- Chrome (untuk development web)

### Development

```bash
# Install dependencies
flutter pub get

# Run di web
flutter run -d chrome

# Run di Android
flutter run -d <device-id>

# Run di Windows
flutter run -d windows
```

### Build

```bash
# Build APK debug
flutter build apk --debug

# Build web
flutter build web
```

## Struktur Proyek

```
lib/
├── main.dart              # Entry point
├── app.dart               # Root widget & router
├── core/                  # Shared utilities
│   ├── api/               # API client & interceptors
│   ├── theme/             # Theme configuration
│   ├── router/            # GoRouter setup
│   └── utils/             # Helper functions
└── features/              # Feature-first modules
    ├── schedule/          # Jadwal perkuliahan
    ├── pengganti/         # Jadwal pengganti
    ├── announcements/     # Pengumuman
    ├── events/            # Kegiatan kampus
    ├── lecturers/         # Data dosen
    ├── rooms/             # Ruangan
    ├── settings/          # Pengaturan aplikasi
    ├── updater/           # In-app update
    └── editor/            # Editor jadwal
```

Setiap fitur memiliki subdirektori: `data/`, `providers/`, `ui/`.

## Pull Request Flow

1. Buat branch dari `main`: `git checkout -b feat/nama-fitur`
2. Implementasi perubahan dengan commit yang deskriptif
3. Pastikan `flutter analyze` bersih (0 issues)
4. Push dan buka PR ke `main`
5. Tunggu review dan CI passing

## Keamanan Keystore

**PENTING:** Keystore Android (`upload-keystore.jks`) harus konsisten di semua environment build.

- Simpan keystore di tempat yang amn (jangan commit ke repo)
- Backup keystore ke password manager terpisah
- Jangan pernah menghapus atau mengganti keystore setelah publish pertama
- Gunakan `key.properties` yang di-gitignore

## Lisensi

SSPL v1 — Lihat [LICENSE](LICENSE) untuk detail.
