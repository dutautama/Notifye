# Arsitektur UsahaKonten

## Gambaran besar

```
┌──────────────── Ponsel Android ────────────────┐
│ Flutter App (UsahaKonten.apk)                  │
│  Screens ─► Providers (Riverpod) ─► Services   │
│  PDF/Excel dibuat di perangkat (pdf, excel)     │
│  WhatsApp/email (url_launcher, share_plus)     │
│  Printer thermal Bluetooth, scanner barcode     │
└───────────────┬────────────────────────────────┘
                │ HTTPS (supabase_flutter, JWT user)
┌───────────────▼──────────── Supabase ──────────┐
│ Auth (1 admin, signup dimatikan)               │
│ Postgres + RLS (owner_id = auth.uid())          │
│   trigger: stok, total, status lunas, nomor doc │
│   RPC: create_transaction, adjust_stock          │
│   view: v_debts, v_daily_sales, v_low_stock,     │
│         v_content_performance                    │
│ Storage bucket privat "assets/<user_id>/..."    │
│ Edge Functions (opsional: tugas server-side)    │
└─────────────────────────────────────────────────┘
GitHub: push ─► Actions (analyze, test, build) ─► Artifact / Release .apk
```

## Bottom navigation (5 tab)

| Tab | Isi |
|---|---|
| **Beranda** | ringkasan omzet, piutang jatuh tempo, stok menipis, jadwal konten minggu ini |
| **Usaha** | Kasir/transaksi baru, Produk & Jasa, Pelanggan, Supplier, Hutang/Piutang |
| **Konten** | Papan ide (kanban per status), Kalender, Publikasi & Reach |
| **Laporan** | Penjualan, Stok, Hutang/Piutang, Performa Konten → Excel/PDF |
| **Lainnya** | Profil usaha, printer Bluetooth, backup/export, keamanan, keluar |

## Skema data (ringkas)

```
business_profile (1 baris per user)        doc_counters (penomoran INV/PO)

categories ─┐
            └─< products >──────────────┐
customers ──< transactions >── suppliers │
               │  ├─< transaction_items >┘ (stok otomatis via trigger)
               │  └─< payments            (paid_amount & status via trigger)
               └─ v_debts (piutang = sale belum lunas, hutang = purchase belum lunas)
products ──< stock_movements              (riwayat keluar/masuk stok)

content_ideas ─┬─< content_assets          (link Drive/video/naskah/file Storage)
               ├─< content_schedules       (platform + waktu tayang → kalender)
               ├─< content_publications    (link post + views/reach/likes/...)
               └─< content_product_links >── products   (relasi 2 arah)
```

Semua tabel memiliki `owner_id` + RLS. Detail lengkap: `supabase/migrations/0001_init.sql`.

### Aturan otomatis di database
| Kejadian | Efek |
|---|---|
| Item penjualan ditambah | stok produk (yang `track_stock`) berkurang + catat `stock_movements` |
| Item pembelian ditambah | stok bertambah |
| Transaksi dihapus | stok dikembalikan |
| Item berubah | subtotal & total transaksi dihitung ulang |
| Pembayaran dicatat/dihapus | `paid_amount` & status `belum/sebagian/lunas` dihitung ulang |
| Transaksi baru via RPC | nomor otomatis `INV-YYYYMM-0001` / `PO-YYYYMM-0001` |
| Publikasi konten dicatat | jadwal terkait → `tayang`, ide → `publish` |

## Keamanan
1. **Auth**: email+password, satu akun admin, pendaftaran publik dimatikan.
2. **RLS** di semua tabel & storage; role `anon` dicabut seluruh aksesnya; view `security_invoker`.
3. **Enkripsi**: Supabase mengenkripsi data saat disimpan (AES-256) & saat dikirim (TLS).
   Untuk kolom sangat sensitif (`*_enc`: info rekening, catatan privat pelanggan)
   aplikasi mengenkripsi lagi di perangkat (AES-GCM, kunci dari PIN/passphrase
   pemilik via PBKDF2, disimpan di Android Keystore lewat `flutter_secure_storage`).
4. **Sesi** disimpan aman oleh `supabase_flutter`; opsi kunci aplikasi dengan PIN/biometrik (Modul 8).
5. **Secrets** hanya di GitHub Secrets; keystore tidak di-commit (repo publik).
6. **Backup**: export JSON/CSV semua tabel dari aplikasi → bagikan ke Google Drive (Modul 8),
   plus opsi workflow terjadwal backup database.

## Rencana paket per modul
| Modul | Paket utama |
|---|---|
| 1 Auth & Dashboard | supabase_flutter, flutter_riverpod, go_router, fl_chart |
| 2 Master data | mobile_scanner (barcode) |
| 3 Transaksi | — (RPC Supabase) |
| 4 Invoice & cetak | pdf, printing, share_plus, url_launcher, print_bluetooth_thermal, esc_pos_utils_plus |
| 5 Laporan | excel, pdf, path_provider, share_plus |
| 6–7 Konten | table_calendar, file_picker, url_launcher |
| 8 Profil, enkripsi, backup | cryptography, flutter_secure_storage, local_auth |

## Struktur proyek target
```
lib/
├── main.dart
├── app.dart
├── core/        env.dart, theme.dart, router.dart, formatters.dart, validators.dart, crypto.dart
├── models/      product.dart, category.dart, customer.dart, supplier.dart, transaction.dart,
│                payment.dart, debt.dart, content_idea.dart, content_asset.dart,
│                content_schedule.dart, content_publication.dart, business_profile.dart
├── services/    supabase_service.dart, auth_service.dart, product_service.dart,
│                party_service.dart, transaction_service.dart, report_service.dart,
│                content_service.dart, invoice_pdf_service.dart, excel_service.dart,
│                printer_service.dart, whatsapp_service.dart, backup_service.dart
├── providers/   *_provider.dart per domain
├── screens/
│   ├── auth/        login_screen.dart
│   ├── shell/       main_shell.dart
│   ├── dashboard/   dashboard_screen.dart
│   ├── business/    business_home, product_list/form, customer_list/form,
│   │                supplier_list/form, transaction_form, transaction_detail, debt_list
│   ├── content/     content_home (kanban), idea_detail, idea_form, calendar_screen,
│   │                publication_form
│   ├── reports/     reports_screen, sales_report, stock_report, debt_report, content_report
│   ├── settings/    settings_screen, business_profile, printer_settings, backup_screen
│   └── setup/       config_missing_screen.dart
└── widgets/     coming_soon, empty_state, money_text, status_chip, search_field, ...
```
