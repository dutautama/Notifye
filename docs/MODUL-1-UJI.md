# Modul 1 — Login Admin & Dashboard: Langkah Uji dari Ponsel

**Syarat:** sudah menjalankan `0001_init.sql`, membuat user admin, dan mengisi secrets
`SUPABASE_URL` + `SUPABASE_KEY` (lihat README). Tidak ada SQL baru di modul ini.

## A. Login
| # | Langkah | Hasil yang diharapkan |
|---|---|---|
| 1 | Buka aplikasi | Layar **Masuk sebagai admin** |
| 2 | Ketuk **Masuk** dengan form kosong | Muncul "Email wajib diisi" / "Password wajib diisi" |
| 3 | Isi password salah | Kotak merah "Email atau password salah." |
| 4 | Isi email & password benar | Masuk ke tab **Beranda** |
| 5 | Tutup aplikasi (swipe dari recent apps), buka lagi | Langsung ke Beranda (sesi tersimpan) |
| 6 | Mode pesawat → buka Beranda → tarik ke bawah | Pesan "Tidak ada koneksi internet" + tombol **Coba lagi** |

Cek di Supabase: **Table Editor → business_profile** → ada 1 baris (dibuat otomatis saat login pertama).

## B. Dashboard dengan data contoh
Data dibuat lewat SQL dulu (layar input menyusul di Modul 2–3).
Supabase → **SQL Editor** → jalankan (ganti email):

```sql
-- Jalankan sebagai admin: set user agar RLS/default owner_id terisi
select set_config('request.jwt.claim.sub',
  (select id::text from auth.users where email = 'EMAIL_ANDA@contoh.com'), false);
set role authenticated;

insert into products (name, kind, sell_price, track_stock, stock, min_stock)
values ('Kaos Sablon', 'barang', 85000, true, 2, 5);
insert into customers (name, phone) values ('Budi', '081234567890');

select number, total, status from create_transaction(jsonb_build_object(
  'type', 'sale',
  'customer_id', (select id from customers where name = 'Budi' limit 1),
  'due_date', (current_date + 3)::text,
  'items', jsonb_build_array(jsonb_build_object(
     'product_id', (select id from products where name = 'Kaos Sablon' limit 1),
     'name', 'Kaos Sablon', 'qty', 1, 'price', 85000)),
  'payment', jsonb_build_object('amount', 25000, 'method', 'tunai')));

insert into content_ideas (title, platforms) values ('Tips memilih kaos', '{instagram}');
insert into content_schedules (idea_id, platform, scheduled_at)
select id, 'instagram', now() + interval '2 days' from content_ideas limit 1;

reset role;
```

Lalu di aplikasi, **tarik layar Beranda ke bawah**:
| Bagian | Harus tampil |
|---|---|
| Omzet hari ini | Rp 85.000 • 1 transaksi |
| Piutang | Rp 60.000 • 1 belum lunas |
| Grafik 7 hari | batang hari ini terisi |
| Jatuh tempo | Budi • INV-…-0001, Rp 60.000, ikon chat → membuka WhatsApp berisi pesan pengingat |
| Stok menipis | Kaos Sablon 1 pcs (minimal 5) — stok 2 berkurang 1 otomatis |
| Jadwal konten | "Tips memilih kaos", Instagram, chip Ide: 1 |

## C. Pengaturan
| # | Langkah | Hasil |
|---|---|---|
| 1 | Tab **Lainnya** | Email admin, server Supabase, versi build |
| 2 | **Ganti Password** → isi 2 password berbeda | "Password tidak sama" |
| 3 | Isi password baru valid → Simpan | "Password berhasil diubah" |
| 4 | **Keluar** → konfirmasi | Kembali ke layar login; login dengan password baru berhasil |

Hapus data contoh (opsional): SQL Editor → `delete from transactions; delete from content_ideas; delete from products; delete from customers;`
