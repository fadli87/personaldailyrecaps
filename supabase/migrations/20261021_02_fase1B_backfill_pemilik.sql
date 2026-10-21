-- =====================================================================
-- FASE 1B — backfill pemilik data (JALANKAN SEKALI, ganti UID dulu)
-- UID = id akun email kamu: Supabase Dashboard -> Authentication -> Users
-- =====================================================================
update daily_recap set user_id = 'GANTI-DENGAN-UID-AKUN-EMAIL-KAMU' where user_id is null;

update daily_order     x set user_id = r.user_id from daily_recap r where x.daily_recap_id = r.id and x.user_id is null;
update petty_cash_item x set user_id = r.user_id from daily_recap r where x.daily_recap_id = r.id and x.user_id is null;
update daily_extra     x set user_id = r.user_id from daily_recap r where x.daily_recap_id = r.id and x.user_id is null;
update fuel_fillings   x set user_id = r.user_id from daily_recap r where x.daily_recap_id = r.id and x.user_id is null;
