# JTK25 Client

Aplikasi jadwal perkuliahan JTK (Jaringan Telekomunikasi dan Komputer) untuk mahasiswa dan dosen Politeknik Negeri Bali.

## Platform

- **Android** (minSdk 23, Java 17) — notifikasi lokal, FCM push, background polling
- **Web** — SPA deployed ke Cloudflare Workers

> iOS tidak didukung.

## Fitur

| Fitur | Deskripsi |
|-------|-----------|
| Jadwal Kuliah | Jadwal harian/mingguan per kelas (6 kelas: D3-2A/B, D4-2A/B/C/D), slot merged, istirahat gap, indikator "Now" |
| Jadwal Pengganti | Overlay pengganti (replace/add/info) di atas jadwal normal, warna badge: orange/abu |
| Pengumuman | Daftar pengumuman kampus, badge "Baru" untuk yang belum dibaca, markdown body |
| Acara | Daftar kegiatan kampus, grouping upcoming/completed, category badge, clickable location |
| Dosen | Direktori 42 dosen, pencarian, detail jadwal mengajar per dosen |
| Ruangan | 16 ruangan, matriks ketersediaan (Senin-Jumat x 10 slot), filter "Tersedia sekarang", overlap detection |
| Editor | Form input jadwal → JSON valid, validasi schema 6 tipe, export copy + download, PR instructions |
| Notifikasi | FCM push (Android + Web), WorkManager 15-min polling (Android), local notifications, class reminders |
| Pengaturan | Pilih kelas default (6 kelas), kelola notifikasi, layar izin notifikasi (6 state) |
| In-app Update | Cek GitHub Releases (Android only), MaterialBanner "Unduh"/"Nanti" |
| Offline Cache | Hive CE cache (7 boxes), network-first + cache-fallback, stale >5 menit |

## Prasyarat

- Flutter SDK 3.41.9
- Node.js 22+ (untuk deploy server)
- Android SDK (untuk build APK)
- Chrome (untuk development web)
- `gh` CLI (untuk release — opsional)

## Instalasi

```bash
flutter pub get
flutter run -d chrome        # web
flutter run -d <device-id>   # android
```

## Build & Release

```bash
flutter build apk --release              # APK (signed)
flutter build web                        # Web SPA

.\release.ps1              # Full: build APK + GitHub release + deploy server
.\release.ps1 -SkipApk    # Skip APK build
.\release.ps1 -SkipRelease # Skip GitHub release
.\release.ps1 -SkipDeploy  # Skip server deploy
.\release.ps1 -DryRun      # Preview only
```

Release script membaca versi dari `pubspec.yaml`, membuat tag `vX.Y.Z`, hapus release lama jika ada, buat release baru dengan APK.

### Signing Android

Release build menggunakan keystore di `android/key.properties` (di-gitignore).

| File | Lokasi | Keterangan |
|------|--------|------------|
| `release.jks` | `android/app/` | Keystore RSA 2048-bit, alias `jtk25` |
| `key.properties` | `android/` | Pointer ke keystore + credentials |

Jangan commit file ini. Keystore yang konsisten wajib untuk update tanpa uninstall.

## Struktur Proyek

```
client/
├── main.dart                  # Entry point: Firebase, Hive, intl, timezone, WorkManager, notifications
├── app.dart                   # Root widget (MaterialApp.router)
├── firebase_options.dart      # Firebase config (hand-written)
├── pubspec.yaml               # 15 dependencies, 4 dev deps
│
├── lib/
│   ├── core/
│   │   ├── api/               # Dio client, 7 endpoints (meta, schedules, pengganti, announcements, events, dosen, rooms)
│   │   ├── cache/             # Hive offline cache (7 boxes, stale >5 min)
│   │   ├── models/            # 7 models: Schedule, Pengganti, Room, Dosen, Event, Announcement, Meta + schema guard
│   │   ├── notifications/     # 7 files: NotificationService, FcmService, WorkManager, web push, providers
│   │   ├── providers/         # 11 global Riverpod providers (network-first, cache-fallback)
│   │   ├── router/            # GoRouter: StatefulShellRoute.indexedStack (5 branches, 13 routes)
│   │   ├── shell/             # AppShell (NavigationRail >800px, BottomNav mobile), NotFoundPage
│   │   ├── theme/             # Light-only Material 3, brand blue #3B72D9
│   │   ├── ui/                # Refresh helpers (pull-to-refresh + AppBar button)
│   │   └── utils/             # Debug logging, semver, dot-time parsing (WibTime, TimeSlot, isBreak)
│   │
│   └── features/              # Feature-first: each has data/, providers/, ui/
│       ├── schedule/          # 3 providers + 743-line UI (class chips, day chips, session cards)
│       ├── pengganti/         # 2 providers + 221-line UI (color-coded kind badges)
│       ├── announcements/     # AnnouncementsSeen (Hive) + 3 providers + markdown detail
│       ├── events/            # groupEvents (upcoming/completed) + 274-line UI
│       ├── rooms/             # OccupancyMatrix (458 lines, 14 exports) + 958-line UI (largest file)
│       ├── lecturers/         # computeDosenSessions + 350-line UI (search + detail)
│       ├── settings/          # kAllClassCodes + 189-line UI + 633-line permission screen
│       ├── editor/            # 6 embedded schemas + 608-line providers + 1566-line UI (largest feature)
│       └── updater/           # GitHubReleasesClient + Semver + UpdateState + MaterialBanner
│
├── web/
│   ├── index.html             # Brand splash (CSS), AI/crawler API reference
│   ├── flutter_bootstrap.js   # Cache busting: build ID in localStorage, clears caches on mismatch
│   ├── _headers               # Cloudflare cache control (no-cache entrypoints, 7-day CDN for assets)
│   ├── manifest.json          # PWA: standalone, theme #3B72D9
│   ├── robots.txt             # SEO + AI crawler notice (GPTBot, ClaudeBot, PerplexityBot)
│   └── firebase-messaging-sw.js
│
├── android/
│   ├── app/build.gradle.kts   # namespace id.matcha.jtk25.jtk25_client, Java 17, desugaring, release signing
│   ├── app/release.jks        # RSA 2048-bit keystore (alias: jtk25)
│   └── key.properties         # Keystore credentials (gitignored)
│
├── test/                      # 21 test files + 6 fixture JSONs (live API snapshots)
│   ├── core/                  # 10 tests: model, api, cache, time_slot, semver, pengganti, notifications, regressions
│   └── features/              # 11 tests: schedule, announcements, editor, rooms, settings, updater, pull-to-refresh
│
└── .github/workflows/
    ├── ci.yml                 # Analyze & Test + Build Web (artifact upload 7-day)
    └── release.yml            # Build APK → GitHub Release (tag v*)
```

### Arsitektur

| Aspek | Teknologi |
|-------|-----------|
| State Management | Riverpod 3.x (Notifier/NotifierProvider — bukan StateProvider) |
| Navigasi | GoRouter, `StatefulShellRoute.indexedStack` (5 tab branches) |
| Networking | Dio, network-first + cache-fallback per endpoint |
| Offline | Hive CE (7 boxes: meta, schedules, pengganti, announcements, events, dosen, rooms) |
| Notifikasi | FCM push (Android + Web) + WorkManager 15-min polling (Android) + local notifications |
| Schema | v2 (`currentSchemaVersion = 2`, `guardSchema()` enforced) |
| Theme | Light-only Material 3, brand blue `#3B72D9` |
| Bahasa | Semua UI string Bahasa Indonesia |

### Dependensi Runtime

| Package | Versi | Fungsi |
|---------|-------|--------|
| flutter_riverpod | ^3.3.2 | State management |
| go_router | ^17.5.0 | Declarative routing |
| dio | ^5.11.1 | HTTP client |
| hive_ce + hive_ce_flutter | ^2.20.0 / ^2.3.4 | Local storage |
| firebase_core + firebase_messaging | ^4.14.0 / ^16.6.0 | Firebase + FCM |
| flutter_local_notifications | ^22.3.1 | Android notifications |
| workmanager | ^0.10.10 | Background tasks (Android) |
| timezone | ^0.11.1 | Asia/Jakarta timezone |
| flutter_markdown | ^0.7.7+1 | Markdown rendering |
| url_launcher | ^6.3.2 | External URLs |
| intl | ^0.20.3 | Date formatting (id_ID) |
| package_info_plus | ^8.1.3 | App version (updater) |
| web | ^1.1.1 | Web platform APIs |
| json_schema | ^5.2.2 | Schema validation (editor) |

### Rute Aplikasi

| Path | Deskripsi |
|------|-----------|
| `/` | Jadwal hari ini |
| `/jadwal/:class` | Jadwal per kelas |
| `/pengganti` | Jadwal pengganti |
| `/dosen` | Daftar dosen |
| `/dosen/:code` | Detail dosen + jadwal mengajar |
| `/editor` | Editor jadwal (form → JSON) |
| `/ruangan` | Daftar ruangan |
| `/ruangan/matriks` | Matriks ketersediaan |
| `/ruangan/:id` | Detail ruangan |
| `/pengumuman` | Daftar pengumuman |
| `/acara` | Daftar acara |
| `/pengaturan` | Pengaturan aplikasi |
| `/pengaturan/notifikasi` | Izin notifikasi |

## CI/CD

### Client CI (`.github/workflows/ci.yml`)

- Trigger: push/PR ke `main` (lib/, test/, pubspec.*)
- Jobs:
  1. **Analyze & Test** — `flutter analyze` + `flutter test`
  2. **Build Web** — `flutter build web` + upload artifact (7 hari retention)

### Client Release (`.github/workflows/release.yml`)

- Trigger: push tag `v*`
- Build APK release → GitHub Release dengan file APK

## Konfigurasi Firebase

File Firebase **tidak di-commit** ke repo. Sebelum build:

| File | Lokasi | Cara mendapatkannya |
|------|--------|---------------------|
| `google-services.json` | `android/app/` | Firebase Console → Project Settings → Android app |
| `firebase_options.dart` | `lib/` | Copy dari `firebase_options.dart.example`, isi nilai dari Firebase Console |
| `firebase-messaging-sw.js` | `web/` | Copy dari `.example`, isi nilai Firebase |

**Project Firebase:** `numeric-lead-265602`

## Pull Request Flow

1. Buat branch dari `main`: `git checkout -b feat/nama-fitur`
2. Implementasi dengan commit Conventional Commits
3. Pastikan `flutter analyze` bersih (0 issues)
4. Push dan buka PR ke `main`
5. Tunggu review dan CI passing

## Lisensi

SSPL v1 — Lihat [LICENSE](LICENSE) untuk detail.

## TODO

- [ ] Fitur Tasks (tugas/assignment, bukan hanya event)
- [ ] Dedup code (ada duplikasi di beberapa fitur)
