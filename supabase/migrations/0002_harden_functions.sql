-- =====================================================================
-- 0002 — Pengerasan keamanan fungsi (hasil Supabase Security Advisor)
--  1. search_path fungsi dikunci ke '' (semua objek sudah ditulis lengkap
--     dengan skema public./auth.) → cegah pembajakan search_path.
--  2. rls_auto_enable() (event trigger bawaan Supabase) tidak boleh
--     dipanggil lewat REST API oleh user mana pun.
-- =====================================================================
alter function public.tg_set_updated_at()                    set search_path = '';
alter function public.tg_items_adjust_stock()                set search_path = '';
alter function public.tg_transactions_restore_stock()        set search_path = '';
alter function public.recalc_transaction(uuid)               set search_path = '';
alter function public.tg_items_recalc_total()                set search_path = '';
alter function public.recalc_payment_status(uuid)            set search_path = '';
alter function public.tg_payments_recalc()                   set search_path = '';
alter function public.tg_transactions_total_changed()        set search_path = '';
alter function public.next_doc_number(text, date)            set search_path = '';
alter function public.create_transaction(jsonb)              set search_path = '';
alter function public.adjust_stock(uuid, numeric, text)      set search_path = '';
alter function public.tg_publication_sync()                  set search_path = '';

do $$
begin
  if exists (select 1 from pg_proc p join pg_namespace n on n.oid = p.pronamespace
             where n.nspname = 'public' and p.proname = 'rls_auto_enable') then
    revoke execute on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end;
$$;
