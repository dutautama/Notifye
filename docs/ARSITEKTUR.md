# Arsitektur UsahaKonten (100% offline)

```
┌──────────────────────────── HP Android ────────────────────────────┐
│ UI (features/*)  ──►  Provider (Riverpod)  ──►  Repository (6)    │
│                                                     │              │
│                                                     ▼              │
│                       AppDatabase (drift)  ──►  SQLite file        │
│                       └ trigger: stok, total, status lunas, konten │
│ PIN: PBKDF2 hash ──► flutter_secure_storage (Android Keystore)     │
│ Lampiran: <app-documents>/attachments/                             │
│ Backup .zip ──► share_plus ──► Google Drive / WhatsApp / Files     │
└────────────────────────────────────────────────────────────────────┘
GitHub: push main ─► Actions (generate-check, analyze, test, build) ─► Release .apk
```

Tidak ada server. Manifest Android sengaja **tanpa izin INTERNET**.

## Keputusan & trade-off

| Keputusan | Alasan | Trade-off |
|---|---|---|
| SQLite + drift | Offline, cepat, query bertipe, migrasi terstruktur | Data hilang jika HP hilang tanpa backup → backup .zip + otomatis mingguan |
| Logika stok/total di trigger | Konsisten apa pun layarnya, teruji di unit test | Perubahan logika = perubahan skema (wajib konfirmasi pemilik) |
| UUID teks sebagai id | Merge backup antar-HP tanpa bentrok | Sedikit lebih besar dari integer |
| Soft delete (`deleted_at`) | Pembatalan bisa dipulihkan, stok otomatis kembali | Query wajib filter `deleted_at IS NULL` |
| PIN PBKDF2 100k + jeda bertingkat | PIN 6 digit hanya 1 juta kombinasi | Verifikasi ±0,5–1 dtk (jalan di isolate, UI tidak macet) |
| Debug keystore tetap di repo | Update APK tanpa uninstall (uninstall = data hilang) | Siapa pun bisa menandatangani APK dengan kunci ini; jangan instal APK dari sumber lain |
| Database tidak dienkripsi (SQLCipher) | Lebih sederhana; file DB ada di penyimpanan privat aplikasi | HP yang di-root bisa membaca file; opsi SQLCipher bisa ditambah nanti |

## Skema data (v1)

```
meta (schema_version, ...)            business_profile (1 baris)     doc_counters (INV/PO per bulan)

categories ─< products >──────────────────────────────┐
customers ──< transactions >── suppliers              │
               ├─< transaction_items >────────────────┘  (trigger: stok & total)
               └─< payments                              (trigger: paid_amount & status)
               hutang/piutang = transactions WHERE status <> 'lunas' (HutangRepository)
products ──< stock_movements                             (riwayat stok)

content_ideas ─┬─< content_assets          (link / file lampiran lokal)
               ├─< content_schedules       (kalender)
               ├─< content_publications    (link post + views/reach/likes/...)
               └─< content_product_links >── products
```

Kolom `created_at`, `updated_at`, `deleted_at` ada di semua tabel utama.

## Repository
| File | Tanggung jawab |
|---|---|
| `produk_repository.dart` | produk/jasa, kategori, penyesuaian stok, stok menipis, riwayat stok |
| `pelanggan_repository.dart` | pelanggan & supplier |
| `transaksi_repository.dart` | buat transaksi atomik, batal/pulihkan, pembayaran, omzet harian |
| `hutang_repository.dart` | daftar hutang & piutang (transaksi belum lunas) |
| `invoice_repository.dart` | nomor dokumen, profil usaha, data lengkap invoice |
| `konten_repository.dart` | ide, status, jadwal, relasi ide ↔ produk |

## Format backup (langkah 2)
```
UsahaKonten-backup-YYYYMMDD-HHmm.zip
├── meta.json      {"format":"usahakonten-backup","schema_version":1,"app_version":"...","created_at":"..."}
├── data.json      {"format":"usahakonten-backup","schema_version":1,"tables":{"products":[...], ...}}
└── attachments/   file lampiran (gambar produk, aset konten)
```
Restore: validasi `schema_version` (tidak boleh lebih baru dari aplikasi) → pilih **Replace** atau
**Merge** (berdasarkan id, baris `updated_at` terbaru menang). Export Supabase lama (`docs/export-supabase-ke-json.sql`)
memakai format `data.json` yang sama.
