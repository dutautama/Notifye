-- =====================================================================
-- Export SEMUA data UsahaKonten dari Supabase → satu JSON
-- untuk di-import ke database lokal (SQLite) lewat menu Backup & Restore.
--
-- Cara pakai (dari HP):
--  1. Supabase → SQL Editor → New query → tempel skrip ini → Run.
--  2. Hasil = 1 baris, kolom "backup_json". Ketuk sel → salin isinya.
--  3. Simpan sebagai file teks bernama  supabase-export.json  (mis. lewat
--     aplikasi catatan/Files) lalu pilih file itu di menu Restore aplikasi.
--
-- Format sama dengan data.json backup lokal:
--   { "format": "usahakonten-backup", "schema_version": 1, "source": "supabase",
--     "exported_at": "...", "tables": { "<nama_tabel>": [ {baris}, ... ] } }
-- Kolom owner_id ikut terekspor dan diabaikan saat import.
-- Skrip ini hanya MEMBACA data (aman, tidak mengubah apa pun).
-- =====================================================================
select json_build_object(
  'format',         'usahakonten-backup',
  'schema_version', 1,
  'source',         'supabase',
  'exported_at',    now(),
  'tables', json_build_object(
    'business_profile',      coalesce((select json_agg(t) from public.business_profile t), '[]'::json),
    'doc_counters',          coalesce((select json_agg(t) from public.doc_counters t), '[]'::json),
    'categories',            coalesce((select json_agg(t) from public.categories t), '[]'::json),
    'products',              coalesce((select json_agg(t) from public.products t), '[]'::json),
    'customers',             coalesce((select json_agg(t) from public.customers t), '[]'::json),
    'suppliers',             coalesce((select json_agg(t) from public.suppliers t), '[]'::json),
    'transactions',          coalesce((select json_agg(t order by t.trx_date, t.created_at) from public.transactions t), '[]'::json),
    'transaction_items',     coalesce((select json_agg(t) from public.transaction_items t), '[]'::json),
    'payments',              coalesce((select json_agg(t) from public.payments t), '[]'::json),
    'stock_movements',       coalesce((select json_agg(t) from public.stock_movements t), '[]'::json),
    'content_ideas',         coalesce((select json_agg(t) from public.content_ideas t), '[]'::json),
    'content_assets',        coalesce((select json_agg(t) from public.content_assets t), '[]'::json),
    'content_schedules',     coalesce((select json_agg(t) from public.content_schedules t), '[]'::json),
    'content_publications',  coalesce((select json_agg(t) from public.content_publications t), '[]'::json),
    'content_product_links', coalesce((select json_agg(t) from public.content_product_links t), '[]'::json)
  )
)::text as backup_json;
