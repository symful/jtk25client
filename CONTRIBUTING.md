# Kontribusi untuk JTK25 Client

Terima kasih atas kontribusi Anda! Berikut panduan untuk berkontribusi.

## Development Setup

1. Fork dan clone repository ini
2. Jalankan `flutter pub get` untuk install dependencies
3. Buat branch baru untuk fitur/fix Anda

## Branch Naming

- `feat/nama-fitur` — untuk fitur baru
- `fix/nama-bug` — untuk perbaikan bug
- `refactor/nama-komponen` — untuk refaktor

## Code Style

- Ikuti [Dart style guide](https://dart.dev/effective-dart/style)
- Gunakan `flutter analyze` sebelum commit (harus 0 issues)
- Format code dengan `dart format .`

## Commit Messages

Gunakan format [Conventional Commits](https://www.conventionalcommits.org/):

```
feat(schedule): tambah filter hari
fix(pengganti): perbaiki loading state
refactor(api): extract dio client
```

## Pull Request

1. Pastikan `flutter analyze` bersih
2. Pastikan semua test passes
3. Update dokumentasi jika diperlukan
4. Gunakan deskripsi yang jelas di PR
5. Tunggu review minimal 1 approval

## Architecture

Proyek ini menggunakan:
- **Feature-first** structure
- **Riverpod** untuk state management
- **GoRouter** untuk navigasi
- **Dio** untuk HTTP requests
- **Hive** untuk offline cache

Lihat [README.md](README.md) untuk detail struktur.

## Issues

Jika menemukan bug atau memiliki saran fitur, buka issue di repository.
