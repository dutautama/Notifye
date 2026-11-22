# UsahaKonten

Aplikasi Android untuk **manajemen usaha jasa/digital** (produk, transaksi, stok,
hutang/piutang, invoice, laporan) dan **manajemen konten media sosial** ala Notion
(ide → produksi → review → publish, aset, kalender, reach), saling terhubung.

Dibangun dengan Flutter + Supabase, APK dibuat otomatis oleh GitHub Actions.
**Semua langkah di bawah bisa dikerjakan dari ponsel Android.**

---

## 1. Supabase (sudah dikerjakan Claude lewat konektor)

Project `nxxdqwihakidyhkonxgm` (Singapore): tabel, trigger, RLS, storage, dan pengerasan keamanan
sudah diterapkan (`supabase/migrations/0001`–`0003`). Security Advisor: 0 temuan.
Database hanya menerima **satu akun admin** (migrasi 0003).

Yang dikerjakan pemilik: membuat akun admin di **Authentication → Users → Add user → Create new user**
(centang **Auto Confirm User**).

## 2. Secrets GitHub (hanya kunci tanda tangan APK)

URL & publishable key Supabase sudah tertanam di workflow (keduanya memang publik).
Isi 4 secret di **Settings → Secrets and variables → Actions → New repository secret**:

| Name | Value |
|---|---|
| `KEYSTORE_BASE64` | isi file `KEYSTORE_BASE64.txt` yang dikirim Claude |
| `KEYSTORE_PASSWORD` | dari file `PETUNJUK_SECRETS.txt` |
| `KEY_ALIAS` | `usahakonten` |
| `KEY_PASSWORD` | dari file `PETUNJUK_SECRETS.txt` |

> Keystore membuat setiap APK baru bisa **meng-update** aplikasi lama tanpa uninstall.
> Simpan file `usahakonten-release.jks` di Google Drive pribadi sebagai cadangan.

## 3. Bangun & unduh APK

- Build berjalan otomatis setiap ada push ke `main`, `claude/**`, atau `ccr-**`.
- Setiap push ke `main` otomatis membuat **Release** berisi APK (Claude yang melakukan push).
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
