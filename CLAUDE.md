# CLAUDE.md — Aturan Proyek UsahaKonten

Baca file ini dulu di setiap sesi. Perbarui bagian **Status Modul** dan
**Catatan Pelajaran** setiap kali menyelesaikan pekerjaan.

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
- Kembangkan di branch kerja sesi (mis. `claude/...` / `ccr-...`), push memicu build APK (artifact).
- Push/merge ke `main` → build + Release dengan file `.apk` langsung.
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
