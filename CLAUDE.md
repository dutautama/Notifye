# CLAUDE.md — Aturan Proyek UsahaKonten

Baca file ini dulu di setiap sesi SEBELUM menjawab. Perbarui **Status Migrasi/Modul**, **Status Setup
Pemilik**, dan **Catatan Pelajaran** setiap kali menyelesaikan pekerjaan.

## ⚠️ ATURAN KERJA SEMI-OTOMATIS (WAJIB, dari pemilik)

### 1. Pembagian tugas
- Claude mengerjakan semua yang bisa lewat tulisan: kode, workflow, dokumentasi, commit, push, memicu build.
- Pemilik HANYA: tap Install APK, set PIN pertama kali, memberi izin storage saat backup/restore.
- Jika ragu, default-nya Claude kerjakan sendiri. Jangan melempar tugas karena lebih mudah dijelaskan.

### 2. Format panduan untuk pemilik
- Bernomor: **[LANGKAH] → Menu → Tombol → Teks yang diketik/diklik → Hasil yang harus terlihat**.
- Nama menu persis seperti di layar. Anggap pemilik belum pernah memakai tool tsb; jelaskan istilah teknis.
- Sertakan 1 kalimat alasan kenapa langkah itu tidak bisa Claude kerjakan sendiri.
- Akhiri setiap panduan dengan: "Balas 'sudah' jika berhasil, atau kirim screenshot/tulis error yang muncul."

### 3. Checkpoint wajib (BERHENTI & tunggu "sudah"/"lanjut")
- Setelah APK rilis, sebelum lanjut ke langkah/modul berikutnya.
- **Perubahan skema database** (tabel/kolom/trigger/index, naik `currentSchemaVersion`): BERHENTI & minta
  konfirmasi SEBELUM push — menyangkut migrasi & file backup pemilik.

### 4. Otomatisasi push & build
- Setiap langkah/modul selesai → commit & push ke **main** (izin sudah diberikan pemilik).
- Workflow `on: push` (tanpa workflow_dispatch), otomatis membuat GitHub Release berisi APK.
- Signing: kunci debug TETAP `android/app/debug.keystore` (di-commit, kredensial standar). Tanpa keystore rahasia.
- Setelah push, beri 1 link Release: `https://github.com/dutautama/Notifye/releases/tag/build-<N>`.
- Build gagal → Claude perbaiki sendiri & push ulang; lapor hanya setelah berhasil.

### 5. Keamanan data pemilik
- JANGAN pernah meminta secrets, password, token, OTP, atau keystore. Proyek ini tidak memakai secrets.
- Data hanya ada di HP pemilik; jalur keluar satu-satunya = file backup yang pemilik bagikan sendiri.

### 6. Gaya komunikasi
- Bahasa Indonesia, ringkas, tanpa basa-basi.
- Setiap balasan diakhiri 1 kalimat status: apa yang selesai + apa yang pemilik lakukan (atau "menunggu konfirmasi").
- Jika UI GitHub/Android mungkin berubah, TANYAKAN tampilan menu terbaru sebelum menebak.

### 7. Larangan keras
- Jangan minta pemilik membuka terminal, Android Studio, VS Code, atau menjalankan CLI di HP.
- DILARANG: Supabase, Firebase, Turso, Neon, atau cloud DB/auth/server apa pun. Aplikasi 100% offline
  (manifest sengaja TANPA izin INTERNET). Internet hanya lewat aplikasi lain (share backup ke Drive/WhatsApp).

### 8. Reset konteks
- Aturan ini tersimpan di sini; setiap sesi baru baca CLAUDE.md dulu.

## Status Setup Pemilik
| Langkah | Status |
|---|---|
| Install APK final & buat PIN 6 digit, uji alur (lihat docs/PANDUAN-UJI.md) | ⬜ belum |
| Arsip: project Supabase `nxxdqwihakidyhkonxgm` (0 baris data) & secrets keystore lama — tidak dipakai, boleh dihapus | ⚠ arsip |

## Konteks pemilik
- Pemilik **hanya memakai ponsel Android** (tanpa PC). Semua instruksi harus bisa dari browser/aplikasi HP.
- Teks UI, pesan error, dokumentasi pemilik → **Bahasa Indonesia**. Nama variabel/kelas/fungsi → Inggris
  (kecuali nama file repository yang diminta pemilik: `produk_`, `pelanggan_`, `transaksi_`, `hutang_`, `invoice_`, `konten_`).

## Stack
| Lapisan | Teknologi |
|---|---|
| App | Flutter 3.50.1 (Dart 3.14), Material 3 via `package:material_ui` |
| State | `flutter_riverpod` 3.x (tanpa codegen) |
| Navigasi | `go_router` 18.x, `StatefulShellRoute` untuk bottom nav 5 tab |
| Database | SQLite lokal: `drift` 2.35 + `drift_flutter` 0.3 (sqlite3 3.x membawa SQLite sendiri — `sqlite3_flutter_libs` sudah EOL, jangan dipakai) |
| Kunci | PIN 6 digit, PBKDF2-HMAC-SHA256 100k iterasi + salt, `flutter_secure_storage` 11 |
| Build | GitHub Actions → `.github/workflows/build-apk.yml` (tanpa secrets) |
| App ID | `id.usahakonten.app` |

### Catatan penting Flutter 3.50
- Material dipisah ke paket **`material_ui`**: import `package:material_ui/material_ui.dart`,
  **bukan** `package:flutter/material.dart` (deprecated).
- `material_ui` sudah mengekspor `GlobalMaterialLocalizations`; dari `flutter_localizations` cukup
  `show GlobalWidgetsLocalizations`.

## Struktur folder
```
lib/
  main.dart, app.dart
  core/                        # theme, router, formatters, validators, app_info
  data/database/
    tables.dart                # tabel drift (nama tabel/kolom = versi cloud lama → export Supabase cocok)
    app_database.dart (+ app_database.g.dart hasil generate, DI-COMMIT)
    migrations/
      migration_strategy.dart  # currentSchemaVersion + _upgradeSteps
      schema_v1.dart           # index & trigger SQLite v1
  data/repositories/           # produk(+kategori,stok), pelanggan(+supplier), transaksi(+pembayaran), hutang, invoice(+profil usaha, nomor dokumen), konten
  features/<fitur>/            # auth, dashboard, business, content, reports, settings, shell
  models/  services/  providers/  widgets/
docs/                          # panduan pemilik, export-supabase-ke-json.sql
test/                          # unit test; database_test menjalankan trigger SQLite asli (in-memory)
test/fixtures/                 # supabase-export-sample.json (data uji palsu untuk importer)
```

## Konvensi kode
1. **UI tidak menyentuh drift langsung.** Alur: Screen → Provider → (Service) → Repository → AppDatabase.
   Provider repository di `lib/providers/app_providers.dart`.
2. **Uang & tanggal** selalu lewat `Fmt`. Uang disimpan REAL (rupiah utuh); DateTime = detik Unix (default drift).
3. **Logika bisnis kritis di trigger SQLite** (`schema_v1.dart`): stok, subtotal/total, paid_amount, status lunas,
   stok kembali saat transaksi dibatalkan (soft delete)/dihapus, stok diterapkan lagi saat dipulihkan,
   sinkron publikasi → jadwal "tayang" → ide "publish".
   Transaksi baru WAJIB lewat `TransaksiRepository.createTransaction` (atomik + nomor dokumen).
4. **Soft delete**: tabel utama punya `deleted_at`; query daftar selalu filter `deleted_at IS NULL`.
   Semua id = UUID v4 teks (aman untuk merge backup antar-device).
5. **Perubahan skema** = naikkan `currentSchemaVersion`, tambah langkah di `_upgradeSteps`, buat
   `migrations/schema_vN.dart`, test migrasi + restore backup versi lama, lalu **minta konfirmasi pemilik
   sebelum push** (aturan 3). Setelah ubah tabel: `dart run build_runner build` & commit `.g.dart` (CI memeriksa).
6. **Dependensi baru** hanya saat dipakai. Plugin native → cek izin `AndroidManifest.xml` & `minSdk`.
   JANGAN menambah izin INTERNET.
7. **UI**: Material 3, `Card` tanpa elevation, sudut 12–16, form `TextFormField` + validator Indonesia,
   aksi utama `FilledButton`, empty state, error → `SnackBar`/`ErrorView` bahasa Indonesia.
8. Sebelum commit: `flutter analyze` bersih & `flutter test` lulus (CI juga menjalankan keduanya).

## Alur kerja Git
- Kerjakan di branch sesi (`claude/...`/`ccr-...`; push → build artifact saja); langkah selesai →
  push ke `main` → build + Release `build-<N>` berisi `.apk`.

## Status Migrasi Offline (instruksi pemilik 2026-11-22)
| # | Langkah | Status |
|---|---|---|
| 1 | Hapus Supabase; skema drift + trigger; 6 repository; PIN lokal; workflow tanpa secrets | ✅ |
| 2 | Backup & Restore .zip (data.json, meta.json, attachments/), Replace/Merge, import export Supabase | ✅ |
| 3 | Backup otomatis mingguan (rotasi 4) + "Kirim backup terakhir ke Drive" | ✅ |
| 4 | Master data: produk/jasa, kategori, pelanggan, supplier, scanner barcode, profil usaha | ✅ |
| 5 | Transaksi jual/beli, pembayaran, batal/pulihkan, hutang/piutang | ✅ |
| 6 | Invoice PDF + share, struk Bluetooth ESC/POS, laporan + export Excel/PDF | ✅ |
| 7 | Konten: kanban ide, aset (link/lampiran), relasi produk, kalender, publikasi & reach | ✅ |

Semua fitur wajib selesai (skema v1, tidak ada perubahan skema sejak migrasi offline).
Ide lanjutan (belum diminta): enkripsi database (SQLCipher), backup terenkripsi password, kunci biometrik.

## Pola yang sudah ada (pakai ulang!)
- Gerbang PIN: `authControllerProvider` (loading/needsSetup/locked/unlocked) → redirect di `routerProvider`.
  Auto-kunci 60 dtk di background. Reset: `runResetAppFlow` (dialog peringatan + ketik "HAPUS").
- Data reaktif: repository `watch*()` (Stream) untuk daftar; Beranda: `db.tableUpdates()` → `invalidateSelf`.
- Error: `ErrorView(error, onRetry)` + `ErrorView.friendly(e)` (pesan constraint SQLite → Indonesia).
- Widget: `StatCard`, `SectionCard`, `EmptyHint`, `MiniBarChart`, `PinPad`, `TwoColumnGrid`, `MonthCalendar`,
  `MoneyField`/`QtyField` (format ribuan), `AttachmentImage`, `BarcodeScannerPage`, `confirmDialog`, `showSnack`.
- Lampiran: `AttachmentService.pick(folder)` → path relatif di `attachments/` (ikut backup).
- Dokumen: `buildInvoicePdf`, `buildReceipt` (ESC/POS), `XlsxWriter` (tanpa dependensi), `buildReportXlsx/Pdf`.
- Share file: `ShareService.saveTemp` + `shareFile`. Printer: `PrinterService` (alamat disimpan di tabel meta).
- WhatsApp: `WhatsAppService.send(phone:, message:)` (wa.me lewat aplikasi WhatsApp).
- Validasi: `Validators`; angka "1.500.000" → `Validators.parseNumber`.
- Test DB: `AppDatabase(NativeDatabase.memory())`. Test PIN: `FakeSecureStorage` di `test/pin_test.dart`.
- Urutan tabel backup/restore/reset: `backupTableOrder` (`app_database.dart`).
- Folder lampiran: `AppResetService.attachmentsDir()` (`<documents>/attachments`).

## Catatan Pelajaran
- **Flutter 3.50 + material_ui**: paket pihak ketiga yang memakai widget `package:flutter/material` (InkWell,
  dll.) CRASH ("No Material widget found") karena kelas Material berbeda. `table_calendar` dibuang → kalender
  sendiri (`MonthCalendar`). Sebelum menambah paket UI, cek `grep -r "package:flutter/material.dart"` di lib-nya.
- Lokalisasi Cupertino kini di paket `cupertino_ui` (`GlobalCupertinoLocalizations`) — wajib untuk locale id_ID.
- `excel` 4.0.6 butuh archive ^3 (bentrok dgn archive 4) → `XlsxWriter` sendiri, divalidasi openpyxl.
- Plugin bisa menyisipkan izin INTERNET (print_bluetooth_thermal) → `tools:node="remove"` di manifest app.
  Cek APK hasil build: tidak boleh ada `android.permission.INTERNET`.
- `DropdownButtonFormField` wajib `isExpanded: true`; hindari `Row(Text, Spacer, Text)` → pakai `Expanded`.
- `test/app_smoke_test.dart` merender 23 rute di layar 360×780 + font 130% → menangkap overflow/crash
  sebelum sampai ke HP pemilik. WAJIB ditambah saat membuat layar baru. Teardown: lepas widget & container
  sebelum `db.close()`, lalu `pump()` agar timer drift selesai.
- Restore backup: anak dimasukkan SEBELUM induk (FK OFF, dicek `foreign_key_check`) agar trigger stok tidak
  menghitung ulang; Merge = insert-only + stok produk lokal disesuaikan untuk transaksi baru.
- 2026-11-22 MIGRASI OFFLINE: Supabase dihapus total atas instruksi pemilik. Project Supabase berisi 0 baris
  (dicek via MCP) → tidak ada data yang dipindah; skrip export tetap di `docs/` untuk jaga-jaga.
- SQLite trigger tidak bisa mengubah NEW → total/status dihitung ulang dengan UPDATE (`_recalc`).
- Cascade/hapus induk: trigger item cek `transactions.deleted_at IS NULL` agar stok tidak dikembalikan dua kali.
- `wipeAllData`: menghapus item transaksi memicu trigger stok → kosongkan `stock_movements` lagi di akhir.
- Manifest: tanpa INTERNET & `allowBackup=false` (flutter_secure_storage bermasalah dengan Auto Backup Android).
- Kunci debug acak per-runner membuat update APK gagal → `debug.keystore` tetap di-commit.
- Workflow `concurrency: cancel-in-progress`: push baru ke branch sama membatalkan build yang berjalan.
- Era cloud (arsip): skema Postgres pernah diuji lengkap; pola trigger yang sama di-port ke SQLite.
