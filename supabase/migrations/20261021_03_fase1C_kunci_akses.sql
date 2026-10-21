-- =====================================================================
-- FASE 1C — kunci akses (JALANKAN SETELAH 1B; kalau masih ada user_id NULL, langkah ini gagal dan itu disengaja)
-- =====================================================================
alter table daily_recap     alter column user_id set not null;
alter table daily_order     alter column user_id set not null;
alter table petty_cash_item alter column user_id set not null;
alter table daily_extra     alter column user_id set not null;
alter table fuel_fillings   alter column user_id set not null;

drop policy if exists "allow all for authenticated" on daily_recap;
drop policy if exists "allow all for authenticated" on daily_order;
drop policy if exists "allow all for authenticated" on petty_cash_item;
drop policy if exists "allow all for authenticated" on daily_extra;

-- Hanya pemilik, dan bukan sesi anonim
create policy owner_only on daily_recap for all to authenticated
  using      ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
create policy owner_only on daily_order for all to authenticated
  using      ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
create policy owner_only on petty_cash_item for all to authenticated
  using      ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
create policy owner_only on daily_extra for all to authenticated
  using      ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
create policy owner_only on fuel_fillings for all to authenticated
  using      ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);

-- PENTING: view berjalan dengan hak pemilik view dan MELEWATI RLS kecuali diatur seperti ini
alter view daily_recap_summary set (security_invoker = true);
