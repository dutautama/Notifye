# UsahaKonten

Aplikasi Android **100% offline** untuk usaha jasa/digital dan manajemen konten media sosial.
Data tersimpan **hanya di HP** (SQLite), dikunci **PIN 6 digit**, tanpa akun & tanpa internet.

## Fitur
| Menu | Isi |
|---|---|
| **Beranda** | Omzet hari ini/bulan ini, grafik 7 hari, piutang & hutang, jatuh tempo (+ tagih via WhatsApp), stok menipis, sedang dibaca/ditonton, catatan terbaru, jadwal konten. Ikon ⚙ Pengaturan & 📊 Laporan |
| **Usaha** | Penjualan & pembelian (stok otomatis), riwayat transaksi, pembayaran/DP, batal & pulihkan, hutang/piutang, produk & jasa (barcode, gambar, stok opname), kategori, pelanggan, supplier |
| **Invoice & struk** | Invoice PDF dengan **QR tanda tangan digital** (bisa diverifikasi di aplikasi) → WhatsApp/email/Drive; struk printer thermal Bluetooth 58/80 mm |
| **Konten** | Papan ide (Ide → Produksi → Review → Publish), aset produksi (link Drive/video/naskah/file), produk yang dipromosikan, kalender bulanan/mingguan, publikasi + views/reach/engagement/leads |
| **Catatan** | Catatan markdown (tebal, miring, judul, daftar, checklist yang bisa dicentang), auto-save, sematkan, arsip, kategori & tag, pencarian cepat, lampiran gambar/PDF, bagikan ke WhatsApp/email, tautkan ke produk/pelanggan/transaksi/ide/koleksi |
| **Koleksi** | Daftar bacaan & tontonan (buku, artikel, video, film, serial, podcast): status, rating ★, progress episode/halaman, review, statistik; bagikan link dari Chrome/YouTube langsung ke aplikasi |
| **Laporan** (Usaha / ikon Beranda) | Penjualan, item terlaris, pembelian, stok, hutang/piutang, performa konten → Excel & PDF |
| **Pengaturan** (ikon ⚙) | Profil usaha (logo, info rekening), printer, Backup & Restore (zip ke Drive, otomatis mingguan), Ubah PIN, Reset aplikasi |

## Instal / update (dari HP)
1. Buka **Releases** repo ini (atau link dari Claude) → build terbaru → **Assets** → ketuk file `.apk`.
2. Buka file → izinkan *Instal aplikasi tidak dikenal* bila diminta → **Instal**.
3. Pertama kali: buat PIN 6 digit. Update berikutnya cukup instal di atas versi lama — data tetap ada.

## Penting
- **Backup rutin** lewat Lainnya → Backup & Restore → *Kirim backup terakhir ke Drive*.
- **PIN tidak bisa dipulihkan.** Lupa PIN = reset aplikasi lalu restore dari backup.
- **Uninstall menghapus semua data** di HP.
- Instal APK **hanya** dari halaman Releases repo ini.

## iPhone (iOS)
Setiap build juga menghasilkan `…-ios-unsigned.ipa`. File ini **belum ditandatangani Apple** sehingga belum
bisa dipasang langsung di iPhone — pilihan cara memasangnya ada di [docs/IOS.md](docs/IOS.md).

Dokumen: [Panduan uji](docs/PANDUAN-UJI.md) · [Arsitektur](docs/ARSITEKTUR.md) · [Aturan proyek](CLAUDE.md)
