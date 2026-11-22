-- =====================================================================
-- UsahaKonten — Skema awal database Supabase
-- Jalankan SEKALI di: Supabase Dashboard → SQL Editor → New query → Run
-- Aman dijalankan ulang? TIDAK (gunakan migrasi baru untuk perubahan).
-- =====================================================================
-- Prinsip:
--  * Setiap tabel punya kolom owner_id (default auth.uid()).
--  * RLS aktif di SEMUA tabel: user hanya bisa akses baris miliknya.
--  * Stok, total bayar, dan status lunas dihitung otomatis oleh trigger
--    di database (bukan di aplikasi) agar konsisten.
--  * View memakai security_invoker = true supaya RLS tetap berlaku.
-- =====================================================================

create extension if not exists pgcrypto;

-- ---------------------------------------------------------------------
-- Fungsi utilitas: updated_at otomatis
-- ---------------------------------------------------------------------
create or replace function public.tg_set_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at := now();
  return new;
end;
$$;

-- =====================================================================
-- BAGIAN A — PROFIL USAHA
-- =====================================================================
create table public.business_profile (
  owner_id        uuid primary key default auth.uid()
                  references auth.users (id) on delete cascade,
  name            text not null default 'Usaha Saya',
  address         text,
  phone           text,
  email           text,
  logo_path       text,                 -- path di Storage bucket "assets"
  invoice_prefix  text not null default 'INV',
  purchase_prefix text not null default 'PO',
  invoice_footer  text default 'Terima kasih atas kepercayaan Anda.',
  bank_info_enc   text,                 -- terenkripsi di perangkat (AES)
  tax_percent     numeric(5,2) not null default 0,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);

-- Penomoran dokumen per pemilik & per jenis & per bulan
create table public.doc_counters (
  owner_id   uuid not null default auth.uid()
             references auth.users (id) on delete cascade,
  doc_type   text not null,             -- 'sale' | 'purchase'
  period     text not null,             -- 'YYYYMM'
  last_no    integer not null default 0,
  primary key (owner_id, doc_type, period)
);

-- =====================================================================
-- BAGIAN B — MASTER DATA
-- =====================================================================
create table public.categories (
  id          uuid primary key default gen_random_uuid(),
  owner_id    uuid not null default auth.uid()
              references auth.users (id) on delete cascade,
  name        text not null,
  color       text,                     -- hex, mis. '#4F46E5'
  created_at  timestamptz not null default now(),
  unique (owner_id, name)
);

create table public.products (
  id           uuid primary key default gen_random_uuid(),
  owner_id     uuid not null default auth.uid()
               references auth.users (id) on delete cascade,
  category_id  uuid references public.categories (id) on delete set null,
  kind         text not null default 'jasa'
               check (kind in ('barang', 'jasa', 'digital')),
  sku          text,
  barcode      text,
  name         text not null,
  unit         text not null default 'pcs',
  sell_price   numeric(14,2) not null default 0 check (sell_price >= 0),
  buy_price    numeric(14,2) not null default 0 check (buy_price >= 0),
  track_stock  boolean not null default false, -- jasa/digital biasanya false
  stock        numeric(14,2) not null default 0,
  min_stock    numeric(14,2) not null default 0,
  description  text,
  image_path   text,
  is_active    boolean not null default true,
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create unique index products_owner_sku_uq
  on public.products (owner_id, sku) where sku is not null and sku <> '';
create index products_owner_barcode_idx on public.products (owner_id, barcode);
create index products_owner_name_idx on public.products (owner_id, lower(name));

create table public.customers (
  id                 uuid primary key default gen_random_uuid(),
  owner_id           uuid not null default auth.uid()
                     references auth.users (id) on delete cascade,
  name               text not null,
  phone              text,              -- format 62xxxxxxxx untuk WhatsApp
  email              text,
  address            text,
  notes              text,
  private_notes_enc  text,              -- terenkripsi di perangkat (AES)
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index customers_owner_name_idx on public.customers (owner_id, lower(name));

create table public.suppliers (
  id                 uuid primary key default gen_random_uuid(),
  owner_id           uuid not null default auth.uid()
                     references auth.users (id) on delete cascade,
  name               text not null,
  phone              text,
  email              text,
  address            text,
  notes              text,
  private_notes_enc  text,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);
create index suppliers_owner_name_idx on public.suppliers (owner_id, lower(name));

-- =====================================================================
-- BAGIAN C — TRANSAKSI, STOK, HUTANG/PIUTANG
-- =====================================================================
create table public.transactions (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  type          text not null check (type in ('sale', 'purchase')),
  number        text not null,
  trx_date      date not null default current_date,
  due_date      date,
  customer_id   uuid references public.customers (id) on delete restrict,
  supplier_id   uuid references public.suppliers (id) on delete restrict,
  subtotal      numeric(14,2) not null default 0,
  discount      numeric(14,2) not null default 0 check (discount >= 0),
  tax           numeric(14,2) not null default 0 check (tax >= 0),
  total         numeric(14,2) not null default 0,
  paid_amount   numeric(14,2) not null default 0,  -- diisi trigger dari payments
  status        text not null default 'belum'
                check (status in ('lunas', 'sebagian', 'belum')),
  notes         text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now(),
  unique (owner_id, number),
  -- penjualan → pelanggan (opsional/umum), pembelian → supplier (opsional)
  check (not (type = 'sale' and supplier_id is not null)),
  check (not (type = 'purchase' and customer_id is not null))
);
create index transactions_owner_date_idx on public.transactions (owner_id, trx_date desc);
create index transactions_owner_status_idx on public.transactions (owner_id, type, status);

create table public.transaction_items (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid not null default auth.uid()
                  references auth.users (id) on delete cascade,
  transaction_id  uuid not null references public.transactions (id) on delete cascade,
  product_id      uuid references public.products (id) on delete set null,
  name            text not null,          -- snapshot nama saat transaksi
  qty             numeric(14,2) not null check (qty > 0),
  price           numeric(14,2) not null check (price >= 0),
  subtotal        numeric(14,2) generated always as (qty * price) stored,
  created_at      timestamptz not null default now()
);
create index transaction_items_trx_idx on public.transaction_items (transaction_id);
create index transaction_items_product_idx on public.transaction_items (product_id);

create table public.payments (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid not null default auth.uid()
                  references auth.users (id) on delete cascade,
  transaction_id  uuid not null references public.transactions (id) on delete cascade,
  pay_date        date not null default current_date,
  amount          numeric(14,2) not null check (amount > 0),
  method          text not null default 'tunai'
                  check (method in ('tunai', 'transfer', 'qris', 'ewallet', 'lainnya')),
  notes           text,
  created_at      timestamptz not null default now()
);
create index payments_trx_idx on public.payments (transaction_id);

create table public.stock_movements (
  id              uuid primary key default gen_random_uuid(),
  owner_id        uuid not null default auth.uid()
                  references auth.users (id) on delete cascade,
  product_id      uuid not null references public.products (id) on delete cascade,
  transaction_id  uuid references public.transactions (id) on delete set null,
  qty_change      numeric(14,2) not null,  -- + masuk, - keluar
  reason          text not null
                  check (reason in ('penjualan', 'pembelian', 'penyesuaian',
                                    'batal_penjualan', 'batal_pembelian')),
  notes           text,
  created_at      timestamptz not null default now()
);
create index stock_movements_product_idx on public.stock_movements (product_id, created_at desc);

-- ---------------------------------------------------------------------
-- Trigger: stok otomatis saat item transaksi ditambah / dihapus / diubah
--   sale     → stok berkurang
--   purchase → stok bertambah
-- ---------------------------------------------------------------------
create or replace function public.tg_items_adjust_stock()
returns trigger
language plpgsql
as $$
declare
  v_type text;
  v_sign numeric;
begin
  if tg_op in ('DELETE', 'UPDATE') and old.product_id is not null then
    select type into v_type from public.transactions where id = old.transaction_id;
    -- Bila transaksi induk ikut terhapus (cascade), v_type bisa NULL → abaikan;
    -- stok dikembalikan oleh trigger BEFORE DELETE pada transactions.
    if v_type is not null then
      v_sign := case when v_type = 'sale' then 1 else -1 end; -- kebalikan
      update public.products
         set stock = stock + v_sign * old.qty
       where id = old.product_id and track_stock;
      if found then
        insert into public.stock_movements (owner_id, product_id, transaction_id, qty_change, reason)
        values (old.owner_id, old.product_id, old.transaction_id, v_sign * old.qty,
                case when v_type = 'sale' then 'batal_penjualan' else 'batal_pembelian' end);
      end if;
    end if;
  end if;

  if tg_op in ('INSERT', 'UPDATE') and new.product_id is not null then
    select type into v_type from public.transactions where id = new.transaction_id;
    v_sign := case when v_type = 'sale' then -1 else 1 end;
    update public.products
       set stock = stock + v_sign * new.qty
     where id = new.product_id and track_stock;
    if found then
      insert into public.stock_movements (owner_id, product_id, transaction_id, qty_change, reason)
      values (new.owner_id, new.product_id, new.transaction_id, v_sign * new.qty,
              case when v_type = 'sale' then 'penjualan' else 'pembelian' end);
    end if;
  end if;

  return coalesce(new, old);
end;
$$;

create trigger transaction_items_stock
after insert or update of qty, product_id or delete on public.transaction_items
for each row execute function public.tg_items_adjust_stock();

-- Saat transaksi dihapus: kembalikan stok SEBELUM item ikut terhapus (cascade)
create or replace function public.tg_transactions_restore_stock()
returns trigger
language plpgsql
as $$
declare
  r record;
  v_sign numeric := case when old.type = 'sale' then 1 else -1 end;
begin
  for r in
    select product_id, qty from public.transaction_items
     where transaction_id = old.id and product_id is not null
  loop
    update public.products
       set stock = stock + v_sign * r.qty
     where id = r.product_id and track_stock;
    if found then
      insert into public.stock_movements (owner_id, product_id, transaction_id, qty_change, reason)
      values (old.owner_id, r.product_id, null, v_sign * r.qty,
              case when old.type = 'sale' then 'batal_penjualan' else 'batal_pembelian' end);
    end if;
  end loop;
  return old;
end;
$$;

create trigger transactions_restore_stock
before delete on public.transactions
for each row execute function public.tg_transactions_restore_stock();

-- ---------------------------------------------------------------------
-- Trigger: hitung ulang subtotal/total dari item
-- ---------------------------------------------------------------------
create or replace function public.recalc_transaction(p_trx_id uuid)
returns void
language plpgsql
as $$
begin
  update public.transactions t
     set subtotal = coalesce(s.sum_sub, 0),
         total    = greatest(coalesce(s.sum_sub, 0) - t.discount + t.tax, 0)
    from (select sum(subtotal) as sum_sub
            from public.transaction_items
           where transaction_id = p_trx_id) s
   where t.id = p_trx_id;
end;
$$;

create or replace function public.tg_items_recalc_total()
returns trigger
language plpgsql
as $$
begin
  perform public.recalc_transaction(coalesce(new.transaction_id, old.transaction_id));
  return null;
end;
$$;

create trigger transaction_items_recalc
after insert or update or delete on public.transaction_items
for each row execute function public.tg_items_recalc_total();

-- ---------------------------------------------------------------------
-- Trigger: total bayar & status (lunas/sebagian/belum)
-- ---------------------------------------------------------------------
create or replace function public.recalc_payment_status(p_trx_id uuid)
returns void
language plpgsql
as $$
begin
  update public.transactions t
     set paid_amount = coalesce(p.sum_paid, 0),
         status = case
                    when coalesce(p.sum_paid, 0) >= t.total then 'lunas'
                    when coalesce(p.sum_paid, 0) > 0 then 'sebagian'
                    else 'belum'
                  end
    from (select sum(amount) as sum_paid
            from public.payments
           where transaction_id = p_trx_id) p
   where t.id = p_trx_id;
end;
$$;

create or replace function public.tg_payments_recalc()
returns trigger
language plpgsql
as $$
begin
  perform public.recalc_payment_status(coalesce(new.transaction_id, old.transaction_id));
  return null;
end;
$$;

create trigger payments_recalc
after insert or update or delete on public.payments
for each row execute function public.tg_payments_recalc();

-- Bila total/diskon/pajak berubah → status pembayaran ikut dihitung ulang
create or replace function public.tg_transactions_total_changed()
returns trigger
language plpgsql
as $$
begin
  new.total := greatest(new.subtotal - new.discount + new.tax, 0);
  new.status := case
                  when new.paid_amount >= new.total then 'lunas'
                  when new.paid_amount > 0 then 'sebagian'
                  else 'belum'
                end;
  return new;
end;
$$;

create trigger transactions_total_changed
before update of subtotal, discount, tax, paid_amount on public.transactions
for each row execute function public.tg_transactions_total_changed();

-- ---------------------------------------------------------------------
-- Nomor dokumen otomatis: INV-202611-0001 / PO-202611-0001
-- ---------------------------------------------------------------------
create or replace function public.next_doc_number(p_type text, p_date date default current_date)
returns text
language plpgsql
as $$
declare
  v_period text := to_char(p_date, 'YYYYMM');
  v_no     integer;
  v_prefix text;
begin
  insert into public.doc_counters (owner_id, doc_type, period, last_no)
  values (auth.uid(), p_type, v_period, 1)
  on conflict (owner_id, doc_type, period)
  do update set last_no = public.doc_counters.last_no + 1
  returning last_no into v_no;

  select case when p_type = 'sale' then invoice_prefix else purchase_prefix end
    into v_prefix
    from public.business_profile where owner_id = auth.uid();

  v_prefix := coalesce(v_prefix, case when p_type = 'sale' then 'INV' else 'PO' end);
  return v_prefix || '-' || v_period || '-' || lpad(v_no::text, 4, '0');
end;
$$;

-- ---------------------------------------------------------------------
-- RPC: buat transaksi lengkap dalam SATU panggilan (atomik)
-- Dipanggil dari Flutter: supabase.rpc('create_transaction', params: {...})
-- payload contoh:
-- {
--   "type": "sale", "trx_date": "2026-11-22", "due_date": null,
--   "customer_id": "...", "supplier_id": null,
--   "discount": 0, "tax": 0, "notes": "",
--   "items": [{"product_id": "...", "name": "Desain Logo", "qty": 1, "price": 500000}],
--   "payment": {"amount": 200000, "method": "transfer"}   -- opsional (DP/lunas)
-- }
-- ---------------------------------------------------------------------
create or replace function public.create_transaction(payload jsonb)
returns public.transactions
language plpgsql
security invoker
as $$
declare
  v_trx  public.transactions;
  v_item jsonb;
  v_date date := coalesce((payload->>'trx_date')::date, current_date);
  v_type text := payload->>'type';
begin
  if auth.uid() is null then
    raise exception 'Tidak terautentikasi';
  end if;
  if v_type not in ('sale', 'purchase') then
    raise exception 'Jenis transaksi tidak valid: %', v_type;
  end if;
  if jsonb_array_length(coalesce(payload->'items', '[]'::jsonb)) = 0 then
    raise exception 'Transaksi harus memiliki minimal 1 item';
  end if;

  insert into public.transactions
    (type, number, trx_date, due_date, customer_id, supplier_id, discount, tax, notes)
  values
    (v_type,
     public.next_doc_number(v_type, v_date),
     v_date,
     nullif(payload->>'due_date', '')::date,
     nullif(payload->>'customer_id', '')::uuid,
     nullif(payload->>'supplier_id', '')::uuid,
     coalesce((payload->>'discount')::numeric, 0),
     coalesce((payload->>'tax')::numeric, 0),
     payload->>'notes')
  returning * into v_trx;

  for v_item in select * from jsonb_array_elements(payload->'items')
  loop
    insert into public.transaction_items (transaction_id, product_id, name, qty, price)
    values (v_trx.id,
            nullif(v_item->>'product_id', '')::uuid,
            v_item->>'name',
            (v_item->>'qty')::numeric,
            (v_item->>'price')::numeric);
  end loop;

  if payload ? 'payment'
     and coalesce((payload->'payment'->>'amount')::numeric, 0) > 0 then
    insert into public.payments (transaction_id, pay_date, amount, method)
    values (v_trx.id, v_date,
            (payload->'payment'->>'amount')::numeric,
            coalesce(payload->'payment'->>'method', 'tunai'));
  end if;

  select * into v_trx from public.transactions where id = v_trx.id;
  return v_trx;
end;
$$;

-- Penyesuaian stok manual (stok opname)
create or replace function public.adjust_stock(p_product_id uuid, p_qty_change numeric, p_notes text default null)
returns public.products
language plpgsql
security invoker
as $$
declare
  v_prod public.products;
begin
  update public.products set stock = stock + p_qty_change
   where id = p_product_id
  returning * into v_prod;
  if v_prod.id is null then
    raise exception 'Produk tidak ditemukan';
  end if;
  insert into public.stock_movements (product_id, qty_change, reason, notes)
  values (p_product_id, p_qty_change, 'penyesuaian', p_notes);
  return v_prod;
end;
$$;

-- =====================================================================
-- BAGIAN D — MANAJEMEN KONTEN (mirip Notion, saling terhubung)
-- =====================================================================
create table public.content_ideas (
  id           uuid primary key default gen_random_uuid(),
  owner_id     uuid not null default auth.uid()
               references auth.users (id) on delete cascade,
  title        text not null,
  description  text,
  platforms    text[] not null default '{}',  -- {'instagram','tiktok','youtube',...}
  status       text not null default 'ide'
               check (status in ('ide', 'produksi', 'review', 'publish')),
  priority     smallint not null default 2 check (priority between 1 and 3), -- 1 tinggi
  pillar       text,                          -- pilar konten (edukasi, promo, dll.)
  tags         text[] not null default '{}',
  due_date     date,
  position     double precision not null default 0, -- urutan di papan kanban
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index content_ideas_owner_status_idx on public.content_ideas (owner_id, status, position);

create table public.content_assets (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  idea_id       uuid not null references public.content_ideas (id) on delete cascade,
  kind          text not null default 'link'
                check (kind in ('link', 'gdrive', 'video', 'gambar', 'audio', 'dokumen', 'naskah')),
  title         text not null,
  url           text,                 -- link eksternal (Drive, YouTube, dll.)
  storage_path  text,                 -- atau file di Supabase Storage
  notes         text,
  created_at    timestamptz not null default now(),
  check (url is not null or storage_path is not null or kind = 'naskah')
);
create index content_assets_idea_idx on public.content_assets (idea_id);

create table public.content_schedules (
  id            uuid primary key default gen_random_uuid(),
  owner_id      uuid not null default auth.uid()
                references auth.users (id) on delete cascade,
  idea_id       uuid not null references public.content_ideas (id) on delete cascade,
  platform      text not null,
  scheduled_at  timestamptz not null,
  status        text not null default 'terjadwal'
                check (status in ('terjadwal', 'tayang', 'batal')),
  notes         text,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);
create index content_schedules_owner_time_idx on public.content_schedules (owner_id, scheduled_at);

create table public.content_publications (
  id                uuid primary key default gen_random_uuid(),
  owner_id          uuid not null default auth.uid()
                    references auth.users (id) on delete cascade,
  idea_id           uuid not null references public.content_ideas (id) on delete cascade,
  schedule_id       uuid references public.content_schedules (id) on delete set null,
  platform          text not null,
  post_url          text,
  published_at      timestamptz not null default now(),
  views             bigint not null default 0 check (views >= 0),
  reach             bigint not null default 0 check (reach >= 0),
  likes             bigint not null default 0 check (likes >= 0),
  comments          bigint not null default 0 check (comments >= 0),
  shares            bigint not null default 0 check (shares >= 0),
  saves             bigint not null default 0 check (saves >= 0),
  followers_gained  bigint not null default 0,
  leads             integer not null default 0 check (leads >= 0), -- calon pembeli dari konten
  metrics_updated_at timestamptz,
  notes             text,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index content_publications_idea_idx on public.content_publications (idea_id);
create index content_publications_owner_time_idx on public.content_publications (owner_id, published_at desc);

-- Relasi banyak-ke-banyak: ide konten ↔ produk/jasa yang dipromosikan
create table public.content_product_links (
  owner_id    uuid not null default auth.uid()
              references auth.users (id) on delete cascade,
  idea_id     uuid not null references public.content_ideas (id) on delete cascade,
  product_id  uuid not null references public.products (id) on delete cascade,
  created_at  timestamptz not null default now(),
  primary key (idea_id, product_id)
);
create index content_product_links_product_idx on public.content_product_links (product_id);

-- Saat publikasi dicatat → jadwal terkait ditandai "tayang" & ide jadi "publish"
create or replace function public.tg_publication_sync()
returns trigger
language plpgsql
as $$
begin
  if new.schedule_id is not null then
    update public.content_schedules set status = 'tayang'
     where id = new.schedule_id and status = 'terjadwal';
  end if;
  update public.content_ideas set status = 'publish'
   where id = new.idea_id and status <> 'publish';
  return new;
end;
$$;

create trigger content_publications_sync
after insert on public.content_publications
for each row execute function public.tg_publication_sync();

-- =====================================================================
-- BAGIAN E — TRIGGER updated_at
-- =====================================================================
create trigger set_updated_at before update on public.business_profile
  for each row execute function public.tg_set_updated_at();
create trigger set_updated_at before update on public.products
  for each row execute function public.tg_set_updated_at();
create trigger set_updated_at before update on public.customers
  for each row execute function public.tg_set_updated_at();
create trigger set_updated_at before update on public.suppliers
  for each row execute function public.tg_set_updated_at();
create trigger set_updated_at before update on public.transactions
  for each row execute function public.tg_set_updated_at();
create trigger set_updated_at before update on public.content_ideas
  for each row execute function public.tg_set_updated_at();
create trigger set_updated_at before update on public.content_schedules
  for each row execute function public.tg_set_updated_at();
create trigger set_updated_at before update on public.content_publications
  for each row execute function public.tg_set_updated_at();

-- =====================================================================
-- BAGIAN F — VIEW LAPORAN (security_invoker → RLS tetap berlaku)
-- =====================================================================
-- Piutang (pelanggan berhutang ke kita) & Hutang (kita berhutang ke supplier)
create view public.v_debts
with (security_invoker = true) as
select
  t.id,
  t.owner_id,
  t.type,
  case when t.type = 'sale' then 'piutang' else 'hutang' end as debt_kind,
  t.number,
  t.trx_date,
  t.due_date,
  t.total,
  t.paid_amount,
  (t.total - t.paid_amount) as remaining,
  t.status,
  coalesce(c.name, s.name, 'Umum') as party_name,
  coalesce(c.phone, s.phone) as party_phone,
  coalesce(t.customer_id, t.supplier_id) as party_id,
  (t.due_date is not null and t.due_date < current_date) as is_overdue
from public.transactions t
left join public.customers c on c.id = t.customer_id
left join public.suppliers s on s.id = t.supplier_id
where t.status <> 'lunas';

-- Ringkasan penjualan harian
create view public.v_daily_sales
with (security_invoker = true) as
select
  owner_id,
  trx_date,
  count(*)            as trx_count,
  sum(total)          as omzet,
  sum(paid_amount)    as received
from public.transactions
where type = 'sale'
group by owner_id, trx_date;

-- Stok menipis
create view public.v_low_stock
with (security_invoker = true) as
select id, owner_id, name, unit, stock, min_stock
from public.products
where track_stock and is_active and stock <= min_stock;

-- Performa konten per ide (gabungan semua platform)
create view public.v_content_performance
with (security_invoker = true) as
select
  i.id as idea_id,
  i.owner_id,
  i.title,
  i.status,
  count(p.id)                        as publication_count,
  coalesce(sum(p.views), 0)          as views,
  coalesce(sum(p.reach), 0)          as reach,
  coalesce(sum(p.likes + p.comments + p.shares + p.saves), 0) as engagement,
  coalesce(sum(p.leads), 0)          as leads,
  case when coalesce(sum(p.reach), 0) > 0
       then round(100.0 * sum(p.likes + p.comments + p.shares + p.saves) / sum(p.reach), 2)
       else 0 end                    as engagement_rate
from public.content_ideas i
left join public.content_publications p on p.idea_id = i.id
group by i.id, i.owner_id, i.title, i.status;

-- =====================================================================
-- BAGIAN G — ROW LEVEL SECURITY
-- =====================================================================
do $$
declare
  t text;
begin
  foreach t in array array[
    'business_profile', 'doc_counters', 'categories', 'products',
    'customers', 'suppliers', 'transactions', 'transaction_items',
    'payments', 'stock_movements', 'content_ideas', 'content_assets',
    'content_schedules', 'content_publications', 'content_product_links'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format($p$
      create policy "owner_all" on public.%I
        for all to authenticated
        using (owner_id = (select auth.uid()))
        with check (owner_id = (select auth.uid()))
    $p$, t);
  end loop;
end;
$$;

-- Role anon tidak boleh menyentuh apa pun
revoke all on all tables in schema public from anon;
revoke execute on all functions in schema public from anon, public;
grant execute on function public.create_transaction(jsonb) to authenticated;
grant execute on function public.adjust_stock(uuid, numeric, text) to authenticated;
grant execute on function public.next_doc_number(text, date) to authenticated;
grant execute on function public.recalc_transaction(uuid) to authenticated;
grant execute on function public.recalc_payment_status(uuid) to authenticated;

-- =====================================================================
-- BAGIAN H — STORAGE (bucket privat "assets", folder per user)
--   Path file wajib: <user_id>/<subfolder>/<nama_file>
-- =====================================================================
insert into storage.buckets (id, name, public, file_size_limit)
values ('assets', 'assets', false, 52428800) -- 50 MB
on conflict (id) do nothing;

create policy "assets_owner_select" on storage.objects
  for select to authenticated
  using (bucket_id = 'assets' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "assets_owner_insert" on storage.objects
  for insert to authenticated
  with check (bucket_id = 'assets' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "assets_owner_update" on storage.objects
  for update to authenticated
  using (bucket_id = 'assets' and (storage.foldername(name))[1] = (select auth.uid())::text);

create policy "assets_owner_delete" on storage.objects
  for delete to authenticated
  using (bucket_id = 'assets' and (storage.foldername(name))[1] = (select auth.uid())::text);

-- =====================================================================
-- Selesai. Langkah berikut: Authentication → Users → Add user (admin),
-- lalu matikan pendaftaran publik (lihat README.md).
-- =====================================================================
