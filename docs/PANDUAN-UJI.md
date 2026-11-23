# Panduan Uji dari HP (± 15 menit)

| # | Langkah | Hasil yang benar |
|---|---|---|
| 1 | Instal APK → buka → buat PIN 6 digit 2x | Masuk ke **Beranda** |
| 2 | **Lainnya → Profil Usaha** → isi nama usaha, no. HP, info rekening → Simpan | "Profil usaha tersimpan" |
| 3 | **Usaha → Produk & jasa → Tambah** → nama "Kaos", jenis Barang, harga jual 85.000, stok awal 10, stok minimum 3 → Simpan | Kaos muncul, "Stok 10 pcs" |
| 4 | **Usaha → Pelanggan → Tambah** → nama + no. HP → Simpan | Pelanggan muncul |
| 5 | **Usaha → Penjualan** → pilih pelanggan → **Produk** → Kaos qty 2 → matikan "Dibayar lunas" → DP 50.000 → Simpan | Detail transaksi INV-…-0001, status **Sebagian**, sisa Rp 120.000 |
| 6 | Di detail: **Invoice PDF** → pilih WhatsApp | PDF invoice terkirim |
| 7 | **Catat bayar** → 120.000 → Simpan | Status **Lunas** |
| 8 | Kembali ke produk Kaos | Stok **8** (berkurang otomatis) |
| 9 | Detail transaksi → ⋮ → **Batalkan transaksi** | Stok kembali **10**, status Dibatalkan |
| 10 | **Konten → Ide baru** → judul, platform Instagram → Simpan → **Tautkan produk** Kaos → **Tambah aset** (link Drive) → **Tambah jadwal** besok 19:00 | Semua tampil di halaman ide |
| 11 | **Konten → Kalender** | Titik di tanggal besok, jadwal tampil saat diketuk |
| 12 | Di ide: **Catat publikasi** → reach 1000, like 50 | Status ide otomatis **Publish**, jadwal **Tayang** |
| 13 | **Laporan → Bulan ini → Excel** | File .xlsx bisa dibuka di Google Sheets/Excel |
| 14 | **Lainnya → Backup & Restore → Buat backup & bagikan** → simpan ke Google Drive | File `UsahaKonten-backup-…zip` ada di Drive |
| 15 | (Opsional, HP lain / setelah Reset) **Pulihkan dari file** → pilih zip → **Ganti semua** | Semua data kembali utuh |
| 16 | (Opsional) **Lainnya → Printer Bluetooth** → pair printer di Setelan HP → Cari printer → pilih → Cetak halaman tes; lalu **Cetak struk** dari transaksi | Struk tercetak |
| 17 | (Opsional) Produk → ikon scan → arahkan ke barcode | Produk ditemukan / tawaran tambah baru |

## Modul baru (v1.3.0)
| # | Langkah | Hasil yang benar |
|---|---|---|
| 18 | Tab **Catatan → Catatan baru** → ketik judul & isi, pakai tombol ☑ untuk checklist → kembali | Catatan tersimpan otomatis (tanpa tombol Simpan) |
| 19 | Buka catatan → ikon 👁 (mode baca) → ketuk checkbox | Tercentang & tercoret |
| 20 | Kolom pencarian Catatan → ketik sebagian kata | Catatan yang cocok muncul |
| 21 | Di catatan: **Ditautkan ke → +** → Produk/jasa → pilih Kaos; buka produk Kaos | Catatan muncul di bagian **Catatan terkait** |
| 22 | Chrome/YouTube → **Bagikan** → pilih **UsahaKonten** (masukkan PIN bila terkunci) | Form **Tambah ke Koleksi** terisi judul & link → Simpan |
| 23 | Tab **Koleksi** → item → status **Sedang**, isi total episode, ketuk **+1** | Progress bertambah; saat penuh status jadi **Selesai** |
| 24 | **Beranda** | Kartu "Sedang dibaca / ditonton" & "Catatan terbaru" tampil |
| 25 | Backup → pulihkan di HP lain | Catatan, lampiran, & koleksi ikut kembali |

## Tanda tangan QR invoice (v1.4.0)
| # | Langkah | Hasil yang benar |
|---|---|---|
| 26 | ⚙ Pengaturan → **Tanda tangan invoice (QR)** → isi nama & jabatan → Simpan | Tersimpan |
| 27 | Buka transaksi → **Invoice PDF** | Pojok kanan bawah: "Hormat kami", QR, nama penanda tangan |
| 28 | Pindai QR itu dengan kamera HP biasa | Muncul teks nomor, tanggal, total, dibayar, status |
| 29 | Usaha → **Verifikasi invoice** → Pindai QR invoice | **ASLI** + "Sesuai dengan data transaksi terkini" |

Izin yang akan diminta Android (hanya saat fitur dipakai): **Kamera** (scan barcode),
**Perangkat di sekitar** (printer Bluetooth). Aplikasi tidak meminta izin internet.
