-- =====================================================================
-- 0003 — Kunci admin tunggal di sisi server
-- Hanya SATU akun yang boleh ada di auth.users. Pendaftaran akun kedua
-- (lewat API publik maupun dashboard) ditolak oleh database, sehingga
-- aplikasi tetap aman walau opsi "Allow new users to sign up" lupa dimatikan.
-- Ganti admin: hapus user lama di Authentication → Users, lalu buat yang baru.
-- =====================================================================
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.enforce_single_admin()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  -- Kunci transaksi agar dua pendaftaran bersamaan tidak sama-sama lolos.
  perform pg_advisory_xact_lock(hashtext('usahakonten_single_admin'));
  if exists (select 1 from auth.users where id <> new.id) then
    raise exception 'Pendaftaran ditutup: aplikasi ini hanya untuk satu admin.'
      using errcode = 'P0001';
  end if;
  return new;
end;
$$;

revoke all on function private.enforce_single_admin() from public, anon, authenticated;

drop trigger if exists enforce_single_admin on auth.users;
create trigger enforce_single_admin
before insert on auth.users
for each row execute function private.enforce_single_admin();
