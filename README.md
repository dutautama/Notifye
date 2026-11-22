# UsahaKonten

Aplikasi Android **100% offline** untuk manajemen usaha jasa/digital (produk, transaksi, stok,
hutang/piutang, invoice, laporan) dan manajemen konten media sosial ala Notion
(ide → produksi → review → publish, aset, kalender, reach), saling terhubung.

- Data tersimpan **hanya di HP** (SQLite). Tanpa akun, tanpa server, tanpa internet.
- Dikunci dengan **PIN 6 digit**.
- Pindah HP / cadangan: menu **Backup & Restore** (file `.zip` → Google Drive/WhatsApp).
- APK dibuat otomatis oleh GitHub Actions setiap ada perubahan di branch `main`.

## Instal (dari HP)

1. Buka halaman **Releases** repo ini (atau link yang dikirim Claude) → build terbaru →
   bagian **Assets** → ketuk `UsahaKonten-...apk`.
2. Buka file yang terunduh → jika diminta, **Setelan → Izinkan dari sumber ini** → **Instal**.
3. Buka aplikasi → buat **PIN 6 digit** (masukkan 2x).

Update berikutnya cukup instal APK baru di atas yang lama — data tetap ada.

## Penting

- **PIN tidak bisa dipulihkan.** Lupa PIN = reset aplikasi (semua data terhapus) lalu restore dari backup.
- **Uninstall aplikasi menghapus semua data.** Selalu backup sebelum ganti/reset HP.

## Dokumen lain
- [docs/ARSITEKTUR.md](docs/ARSITEKTUR.md) — arsitektur, skema data, rencana langkah
- [docs/export-supabase-ke-json.sql](docs/export-supabase-ke-json.sql) — export data lama dari Supabase (arsip)
- [CLAUDE.md](CLAUDE.md) — aturan proyek untuk sesi pengembangan berikutnya
