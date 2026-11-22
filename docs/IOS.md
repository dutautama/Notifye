# UsahaKonten di iPhone (iOS)

## Status
- Kode aplikasi **sudah mendukung iOS 15+** dan otomatis di-build di server macOS GitHub setiap push ke `main`.
- Hasilnya: file `UsahaKonten-…-ios-unsigned.ipa` di halaman **Releases** (di samping file `.apk`).
- File itu **belum ditandatangani Apple**. iPhone hanya mau memasang aplikasi yang ditandatangani
  sertifikat Apple, jadi file ini **tidak bisa langsung diinstal** dengan diketuk seperti APK Android.

## Pilihan agar bisa dipasang di iPhone

| Pilihan | Biaya | Butuh PC/Mac? | Masa berlaku | Catatan |
|---|---|---|---|---|
| **A. TestFlight (resmi, disarankan)** | US$99/tahun (Apple Developer Program) | Tidak — semua lewat browser/HP | Tiap build 90 hari; build baru otomatis | Claude menambahkan upload otomatis ke TestFlight. Butuh 3 nilai rahasia di GitHub Secrets (kunci API App Store Connect) |
| B. Sideload dengan Apple ID gratis (Sideloadly/AltStore) | Gratis | **Ya** (Windows/Mac) untuk menandatangani | 7 hari, lalu harus ulang | Bertentangan dengan syarat "tanpa PC" |
| C. Layanan "sign IPA" pihak ketiga | Bervariasi | Tidak | Sering dicabut Apple tiba-tiba | **Tidak disarankan**: sertifikat pinjaman, melanggar aturan Apple, risiko keamanan data |

### Alur pilihan A (setelah pemilik setuju)
1. Pemilik mendaftar Apple Developer Program (aplikasi **Apple Developer** di iPhone/iPad atau developer.apple.com) — perlu Apple ID dengan 2FA dan pembayaran.
2. Di **App Store Connect** (browser): buat aplikasi baru dengan Bundle ID `id.usahakonten.app`, lalu buat
   **API key** (Users and Access → Integrations → App Store Connect API).
3. Simpan 3 nilai di GitHub → Settings → Secrets and variables → Actions:
   `ASC_ISSUER_ID`, `ASC_KEY_ID`, `ASC_PRIVATE_KEY` (isi file .p8). Nilai ini **tidak pernah** dikirim ke chat.
4. Claude menambah langkah CI: tanda tangan otomatis + upload ke TestFlight.
5. Pengguna iPhone memasang aplikasi **TestFlight** dari App Store → terima undangan → instal UsahaKonten.

> Pilihan A mengubah aturan proyek "tanpa secrets" (khusus untuk build iOS). Aplikasinya tetap 100% offline.

## Perbedaan perilaku di iPhone
- **Printer struk**: iPhone hanya mendukung printer thermal **Bluetooth LE (BLE)**. Printer Bluetooth
  "klasik" yang hanya bisa di-pair di Android tidak terdeteksi di iPhone.
- **PIN**: disimpan di Keychain iOS. Jika aplikasi di-uninstall lalu dipasang lagi, aplikasi meminta PIN
  baru (data lama ikut terhapus — pulihkan dari file backup).
- **Backup**: tombol bagikan membuka menu share iOS (Simpan ke File/iCloud Drive/Google Drive/WhatsApp).
  Restore memilih file dari aplikasi **File**.
- Backup antar-platform berfungsi: file backup dari HP Android bisa dipulihkan di iPhone dan sebaliknya.
