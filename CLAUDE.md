# CLAUDE.md — Aturan Proyek UsahaKonten

Baca file ini dulu di setiap sesi SEBELUM menjawab. Perbarui bagian **Status Modul**,
**Status Setup Pemilik**, dan **Catatan Pelajaran** setiap kali menyelesaikan pekerjaan.

## ⚠️ ATURAN KERJA SEMI-OTOMATIS (WAJIB, dari pemilik)

### 1. Pembagian tugas
- Claude mengerjakan semua yang bisa lewat tulisan: kode, SQL, workflow, dokumentasi, commit, push, memicu build.
- Pemilik hanya mengerjakan yang secara fisik/jaringan tidak bisa Claude lakukan: login akun, klik tombol
  di dashboard web, menyalin nilai rahasia, tap Install APK.
- Jika ragu, default-nya Claude kerjakan sendiri. Jangan melempar tugas karena lebih mudah dijelaskan.

### 2. Format panduan untuk pemilik
- Bernomor: **[LANGKAH] → Menu → Tombol → Teks yang diketik/diklik → Hasil yang harus terlihat**.
- Nama menu persis seperti di layar (Inggris jika UI Inggris, Indonesia jika UI Indonesia).
- Anggap pemilik belum pernah memakai tool tsb. Istilah teknis wajib dijelaskan.
- Sertakan 1 kalimat alasan kenapa langkah itu tidak bisa Claude kerjakan sendiri.
- Akhiri setiap panduan dengan: "Balas 'sudah' jika berhasil, atau kirim screenshot/tulis error yang muncul."

### 3. Checkpoint wajib (BERHENTI & tunggu "sudah"/"lanjut")
- Sebelum pemilik memulai setup akun/layanan apa pun.
- Setelah pemilik selesai setup, sebelum Claude menulis kode.
- Setelah SQL siap, sebelum pemilik menempelnya ke dashboard.
- Setelah APK rilis, sebelum lanjut modul berikutnya.
- Jangan pernah lanjut fase berikutnya tanpa "sudah"/"lanjut".

### 4. Otomatisasi push & build
- Setiap modul selesai → langsung commit & push ke **main** tanpa menunggu (izin sudah diberikan pemilik).
- Workflow memakai `on: push` (tanpa workflow_dispatch) dan otomatis membuat GitHub Release berisi APK.
- Setelah push, beri pemilik 1 link Release langsung (`https://github.com/dutautama/Notifye/releases/tag/build-<N>`).
  Jangan minta pemilik mencari artifact manual.
- Build gagal → Claude perbaiki sendiri & push ulang; lapor hanya setelah berhasil.

### 5. Keamanan data pemilik
- JANGAN pernah meminta: password akun, OTP/2FA, password database, Service Role Key, file keystore.
- Boleh ditempel di chat: Project URL, anon/publishable key, GitHub PAT (scope minimum) bila benar-benar perlu.
- Nilai rahasia lain → arahkan pemilik mengisi lewat GitHub Secrets, bukan chat.
- Ingatkan 1 kali di akhir setup untuk menghapus token/kredensial sementara yang tak dipakai.

### 6. Gaya komunikasi
- Bahasa Indonesia, ringkas, tanpa basa-basi.
- Setiap balasan diakhiri 1 kalimat status: apa yang baru selesai + apa yang harus pemilik lakukan (atau "menunggu konfirmasi").
- Jika UI Supabase/GitHub mungkin berubah, TANYAKAN tampilan menu terbaru ke pemilik sebelum menebak.

### 7. Larangan keras
- Jangan minta pemilik membuka terminal, Android Studio, VS Code, atau menjalankan CLI di HP.
- Jangan pakai fitur yang butuh server tambahan di luar Supabase + GitHub Actions.
- Jangan menulis kode yang bergantung pada secrets yang belum diisi; pakai placeholder + beri tahu urutan pengisian.

### 8. Reset konteks
- Aturan ini tersimpan di sini; setiap sesi baru baca CLAUDE.md dulu.

## Status Setup Pemilik
| Langkah | Status |
|---|---|
| Project Supabase dibuat | ⬜ belum |
| SQL `0001_init.sql` dijalankan | ⬜ belum |
| User admin dibuat + signup publik dimatikan | ⬜ belum |
| Secrets `SUPABASE_URL`, `SUPABASE_KEY` | ⬜ belum |
| Secrets keystore (4 buah) — file sudah dikirim ke pemilik via chat 2026-11-22 | ⬜ belum |
| APK diinstal & login berhasil | ⬜ belum |

## Konteks pemilik
- Pemilik proyek **hanya memakai ponsel Android** (tanpa PC).
- Semua instruksi untuk pemilik harus bisa dikerjakan dari browser ponsel:
  GitHub web, Supabase Dashboard (SQL Editor), unduh APK dari Actions/Releases.
- **Dilarang** memberi langkah yang butuh Android Studio, Xcode, atau terminal PC.
- Bahasa: semua teks UI, pesan error, komentar dokumentasi untuk pemilik → **Bahasa Indonesia**.
  Nama variabel/kelas/fungsi → Bahasa Inggris.

## Stack
| Lapisan | Teknologi |
|---|---|
| App | Flutter 3.50.1 (Dart 3.14), Material 3 via `package:material_ui` |
| State | `flutter_riverpod` 3.x (tanpa codegen) |
| Navigasi | `go_router` 18.x, `StatefulShellRoute` untuk bottom nav 5 tab |
| Backend | Supabase: Auth, Postgres + RLS, Storage, Edge Functions |
| Build | GitHub Actions → `.github/workflows/build-apk.yml` |
| App ID | `id.usahakonten.app` |

### Catatan penting Flutter 3.50
- Material sudah dipisah ke paket **`material_ui`**. Import
  `package:material_ui/material_ui.dart`, **bukan** `package:flutter/material.dart` (deprecated).
- `material_ui` sudah mengekspor `GlobalMaterialLocalizations`; dari
  `flutter_localizations` cukup `show GlobalWidgetsLocalizations`.
- `supabase_flutter` 2.18: pakai `publishableKey:`, bukan `anonKey:` (deprecated).

## Struktur folder
```
lib/
  main.dart            # init intl, cek Env, init Supabase, runApp
  app.dart             # MaterialApp.router, tema, locale id_ID
  core/                # env, theme, router, formatters, utilitas lintas modul
  models/              # kelas data immutable + fromJson/toJson
  services/            # akses Supabase per domain (ProductService, dst.)
  providers/           # Riverpod provider per domain
  screens/<modul>/     # layar per modul (dashboard, business, content, reports, settings)
  widgets/             # widget reusable lintas modul
supabase/migrations/   # SQL bernomor: 0001_init.sql, 0002_xxx.sql, ...
supabase/functions/    # Edge Functions (bila perlu)
docs/                  # dokumentasi untuk pemilik
test/                  # unit test (wajib untuk logika murni)
```

## Konvensi kode
1. **Layar tidak memanggil Supabase langsung.** Alur: Screen → Provider → Service → `SupabaseService.client`.
2. **Model**: kelas immutable, `final` fields, `factory fromJson(Map)`, `Map toJson()`, `copyWith`.
   Kolom DB `snake_case` ↔ field Dart `camelCase`. Angka uang dari DB (numeric) dibaca `(json['x'] as num).toDouble()`.
3. **Uang & tanggal** selalu lewat `Fmt` (`lib/core/formatters.dart`). Jangan buat `NumberFormat` baru di layar.
4. **Logika bisnis kritis ada di database** (trigger/RPC): stok, total, status lunas,
   nomor invoice. Aplikasi tidak menghitung ulang stok sendiri.
   Transaksi baru wajib lewat RPC `create_transaction` (atomik).
5. **Keamanan**:
   - Setiap tabel baru WAJIB: kolom `owner_id uuid not null default auth.uid()`,
     `enable row level security`, policy `owner_all` (lihat 0001_init.sql bagian G).
   - View WAJIB `with (security_invoker = true)`.
   - Jangan pernah menaruh URL/key/password di kode. Gunakan `--dart-define` dari GitHub Secrets.
   - Jangan pakai `service_role` key di aplikasi.
   - Kolom berakhiran `_enc` dienkripsi di perangkat (AES-GCM) sebelum dikirim.
   - Repo ini **publik** → jangan commit keystore, `key.properties`, `.env`, atau data pelanggan.
6. **Perubahan skema** = file migrasi baru bernomor (`0002_...sql`). Jangan edit migrasi yang sudah dijalankan pemilik.
7. **Dependensi baru** ditambahkan hanya saat modul yang membutuhkannya dibangun.
   Setelah menambah plugin native, cek izin `AndroidManifest.xml` & `minSdk`.
8. **UI**: Material 3, `Card` tanpa elevation, sudut 12–16, form pakai `TextFormField` + validator berbahasa Indonesia,
   tombol aksi utama `FilledButton`, daftar kosong → tampilkan empty state, error → `SnackBar` bahasa Indonesia.
9. Sebelum commit: `flutter analyze` harus bersih dan `flutter test` lulus (CI menjalankan keduanya).

## Alur kerja Git
- Kerjakan di branch sesi (`claude/...` / `ccr-...`; push → build artifact saja), lalu saat modul selesai
  fast-forward/merge ke `main` dan push → build + Release `build-<N>` berisi `.apk`.
- Commit kecil per modul, pesan commit Bahasa Indonesia atau Inggris yang jelas.

## Secrets GitHub Actions (diisi pemilik via browser)
| Secret | Isi |
|---|---|
| `SUPABASE_URL` | `https://<ref>.supabase.co` |
| `SUPABASE_KEY` | Publishable key (`sb_publishable_...`) atau anon key lama |
| `KEYSTORE_BASE64` | keystore rilis dalam base64 |
| `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD` | kredensial keystore |

## Status Modul
| # | Modul | Status |
|---|---|---|
| 0 | Fondasi: skema DB, kerangka app, CI APK, dokumen | ✅ Selesai |
| 1 | Autentikasi (admin tunggal) & Dashboard | ✅ Selesai |
| 2 | Master data: kategori, produk/jasa, pelanggan, supplier, scanner barcode | ⏳ Berikutnya |
| 3 | Transaksi penjualan/pembelian, pembayaran, hutang/piutang | ⬜ |
| 4 | Invoice PDF, share WhatsApp/email, printer struk Bluetooth | ⬜ |
| 5 | Laporan + export Excel/PDF | ⬜ |
| 6 | Konten: ide (kanban), aset produksi, relasi produk | ⬜ |
| 7 | Konten: kalender/jadwal, publikasi & reach | ⬜ |
| 8 | Profil usaha, enkripsi field, backup JSON/CSV | ⬜ |

## Pola yang sudah ada (pakai ulang!)
- Auth guard: `routerProvider` (`lib/core/router.dart`) redirect ke `/login` berdasar `AuthService.isLoggedIn`,
  di-refresh oleh stream `onAuthStateChange`. Rute di luar tab (form, detail) didaftarkan di level atas, dibuka dengan `context.push`.
- Data layar: `FutureProvider.autoDispose` yang `ref.watch(currentUserProvider)` → otomatis reload saat ganti user.
  Pull-to-refresh: `RefreshIndicator(onRefresh: () => ref.refresh(x.future))`.
- Error: `ErrorView(error, onRetry)` + `ErrorView.friendly(e)` untuk pesan Indonesia.
- Widget: `StatCard`, `SectionCard`, `EmptyHint`, `MiniBarChart`.
- WhatsApp: `WhatsAppService.send(phone:, message:)` (wa.me, normalisasi 08xx → 628xx).
- Validasi form: `Validators` (`lib/core/validators.dart`), angka "1.500.000" → `Validators.parseNumber`.
- Logika murni ditaruh sebagai fungsi top-level di service agar bisa di-unit-test (contoh `dashboard_service.dart`).

## Catatan Pelajaran
- 2026-11-22: Skema 0001 diuji di Postgres 16 lokal dengan mock `auth.uid()`:
  stok, status bayar, v_debts, hapus transaksi (stok kembali), sinkron publikasi→jadwal→ide, dan isolasi RLS antar user semuanya lolos.
- FK cascade berjalan SETELAH baris induk terhapus → trigger item tidak bisa membaca `transactions.type`;
  karena itu pengembalian stok saat hapus transaksi dilakukan di trigger `BEFORE DELETE` pada `transactions`.
- Jangan `force row level security`: role `postgres` (SQL Editor/backup) perlu tetap bisa membaca.
- Kunci debug di runner GitHub berubah tiap build → tanpa keystore rilis, update APK gagal ("konflik paket"). Keystore rilis wajib via secrets.
- Workflow memakai `concurrency: cancel-in-progress` → push baru ke branch yang sama MEMBATALKAN build yang sedang jalan.
- Repo publik: keystore dikirim ke pemilik lewat kanal privat, tidak di-commit.
