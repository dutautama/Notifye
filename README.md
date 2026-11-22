# UsahaKonten

Aplikasi Android untuk **manajemen usaha jasa/digital** (produk, transaksi, stok,
hutang/piutang, invoice, laporan) dan **manajemen konten media sosial** ala Notion
(ide → produksi → review → publish, aset, kalender, reach), saling terhubung.

Dibangun dengan Flutter + Supabase, APK dibuat otomatis oleh GitHub Actions.
**Semua langkah di bawah bisa dikerjakan dari ponsel Android.**

---

## 1. Siapkan Supabase (sekali saja, ±10 menit)

1. Buka **supabase.com** di Chrome ponsel → Sign in → **New project**.
   Pilih region **Southeast Asia (Singapore)**, buat password database yang kuat, simpan.
2. Setelah project siap: menu ☰ → **SQL Editor** → **New query**.
3. Buka file [`supabase/migrations/0001_init.sql`](supabase/migrations/0001_init.sql) di GitHub →
   tombol **Raw** → tekan lama → **Pilih semua** → **Salin**.
4. Tempel di SQL Editor → **Run**. Harus muncul *Success. No rows returned*.
5. Buat akun admin: menu **Authentication → Users → Add user → Create new user**.
   Isi email & password Anda, centang **Auto Confirm User**.
6. Matikan pendaftaran publik (agar hanya Anda yang bisa login):
   **Authentication → Sign In / Providers** → matikan **Allow new users to sign up** → Save.
7. Ambil kredensial: **Project Settings → Data API** salin **Project URL**;
   **Project Settings → API Keys** salin **Publishable key** (`sb_publishable_...`).
   > Jangan pernah memakai `secret` / `service_role` key di aplikasi.

**Cek:** menu **Table Editor** → terlihat tabel `products`, `transactions`, `content_ideas`, dst.
dengan label **RLS enabled**.

## 2. Isi Secrets di GitHub (sekali saja)

Di Chrome: buka repo ini → **Settings** (mode *Desktop site* jika menu tidak terlihat) →
**Secrets and variables → Actions → New repository secret**. Buat:

| Name | Value |
|---|---|
| `SUPABASE_URL` | Project URL dari langkah 1.7 |
| `SUPABASE_KEY` | Publishable key dari langkah 1.7 |
| `KEYSTORE_BASE64` | dari file `KEYSTORE_BASE64.txt` yang dikirim Claude |
| `KEYSTORE_PASSWORD` | dari file `PETUNJUK_SECRETS.txt` |
| `KEY_ALIAS` | `usahakonten` |
| `KEY_PASSWORD` | dari file `PETUNJUK_SECRETS.txt` |

> Keystore membuat setiap APK baru bisa **meng-update** aplikasi lama tanpa uninstall.
> Simpan file `usahakonten-release.jks` di Google Drive pribadi sebagai cadangan.

## 3. Bangun & unduh APK

- Build berjalan otomatis setiap ada push ke `main`, `claude/**`, atau `ccr-**`.
- Manual: tab **Actions → Build APK → Run workflow** → pilih branch → **Run workflow**.
- Tunggu ±8–12 menit sampai tanda ✅ hijau.

**Unduh (cara termudah):** halaman **Releases** (di beranda repo, kolom kanan/bawah) →
build terbaru → **Assets** → ketuk `UsahaKonten-...apk`.

**Atau lewat Artifact:** Actions → run terbaru → gulir ke **Artifacts** →
`UsahaKonten-APK-<nomor>` → file `.zip` terunduh → buka di aplikasi **Files** →
ketuk zip → **Ekstrak** → dapat file `.apk`.

## 4. Instal di ponsel

1. Ketuk file `.apk` → jika muncul peringatan, **Setelan → Izinkan dari sumber ini**.
2. **Instal** → **Buka**.
3. Jika Play Protect bertanya, pilih **Tetap instal** (aplikasi ini milik Anda sendiri).

## 5. Backup

Sampai modul Backup selesai: Supabase → **Table Editor** → pilih tabel → **Export → CSV**.

---

Dokumen lain:
- [docs/ARSITEKTUR.md](docs/ARSITEKTUR.md) — arsitektur, skema data, rencana modul
- [CLAUDE.md](CLAUDE.md) — aturan proyek untuk sesi pengembangan berikutnya
