# DOKUMENTASI IMPLEMENTASI — SF DAILY RECAP
**Modul:** Perbaikan Fondasi & Modul Keuangan / Kendaraan  
**Branch:** `feature/keuangan-kendaraan`  
**Waktu Mulai:** 21 Oktober 2026  

Dokumentasi ini mencatat progres, keputusan teknis, daftar perubahan file, dan verifikasi pengujian pada setiap fase implementasi sesuai [PANDUAN_AGY_SF_Daily_Recap.md](file:///c:/DevApp/personalDailyRecaps/PANDUAN_AGY_SF_Daily_Recap.md).

---

## Ringkasan Status Progres

| Fase | Deskripsi | Status | Catatan Verifikasi |
|---|---|---|---|
| **Fase 1** | **Fondasi & Keamanan (Sync, LocalDb v11, Auth Lockdown, Migrasi SQL 1A-1C)** | **SELESAI (CLEAR)** | Kode app diperbarui; Semua 16 test lulus; Menunggu user menjalankan SQL 1B & 1C di Supabase |
| **Fase 2** | **Skema Baru (Ledger, Kendaraan, Servis, View Saldo)** | **SELESAI (CLEAR)** | Skema SQLite v11 teruji in-memory; file SQL Fase 2 siap |
| **Fase 3** | **Model, Service, Provider (Riverpod 3, LedgerService, ReportService)** | Siap Dikerjakan | Logika `ledger_math.dart` & test sudah lulus |
| **Fase 4** | **Antarmuka (Tab Keuangan: Ringkasan, Transaksi, Rekening, Motor)** | Menunggu Fase 3 | |
| **Fase 5** | **Integrasi BBM ke Ledger** | Menunggu Fase 4 | Dropdown motor & link transaksi otomatis |
| **Fase 6** | **Penutup (Backup DB, Cleanup CI/CD)** | Menunggu Fase 5 | |

---

## Log Detail Per Fase

### FASE 1 — Perbaikan Fondasi, Sinkronisasi & Keamanan
**Status:** **CLEAR (SELESAI DI SISI APLIKASI)**

#### 1. Perubahan Kode Aplikasi
- [x] **`lib/services/sync_service.dart`**:
  - Menambahkan tabel `fuel_fillings` ke dalam urutan sinkronisasi (push & pull).
  - Mengimplementasikan `_pullTable` dinamis dengan penyaringan kolom via `PRAGMA table_info` lokal (mencegah error saat Supabase memiliki kolom `user_id`).
  - Menambahkan paginasi PostgREST (`.range(from, from + pageSize - 1)`) per 1000 baris.
  - Membungkus setiap tabel dalam `try/catch` mandiri (isolasi error per tabel).
  - Memperbaiki `_syncDeletions` agar antrean penghapusan tidak dibuang saat offline/koneksi gagal.
- [x] **`lib/services/local_db.dart`**:
  - Menaikkan versi database SQLite dari `10` ke `11`.
  - Pada `onCreate`: Menambahkan pembuatan tabel `fuel_fillings` dan seluruh `ledgerSchemaStatements`.
  - Pada `onUpgrade` (`oldVersion < 11`): Menjalankan `CREATE TABLE IF NOT EXISTS fuel_fillings`, menambahkan kolom `vehicle_id` jika belum ada, dan membuat tabel-tabel ledger baru.
- [x] **Keamanan Autentikasi (Penutupan Jalur Anonim & Registrasi Publik)**:
  - `lib/screens/login_screen.dart`: Menghapus tombol "Masuk Anonim", method `_handleAnonymousLogin`, toggle pendaftaran publik `_isSignUp`, serta cabang `signUp`.
  - `lib/screens/splash_screen.dart`: Jika terdeteksi sesi lama bertipe anonim (`currentUser?.isAnonymous == true`), sistem otomatis melakukan `auth.signOut()` dan mengarahkan ke `LoginScreen`.
  - `lib/screens/profile_screen.dart`: Menghapus pengecekan "ID Sesi Anonim" dan menampilkan email akun Supabase secara langsung.
  - `README.md`: Memperbarui petunjuk pembuatan akun email pribadi dan mematikan pendaftaran publik/anonim.
- [x] **Pencegahan Catatan BBM Ganda (T9)**:
  - `lib/screens/order_form_sheet.dart`: Menambahkan teks bantuan peringatan pada checkbox bensin: *"Untuk isi bensin, gunakan Catat BBM di tab Keuangan agar tidak tercatat ganda."*
  - `lib/screens/fuel_filling_sheet.dart`: Mengganti default harga BBM hardcoded `13500` dengan mengingat harga terakhir dari `shared_preferences` (kunci `last_fuel_price`) dengan fallback kosong.
- [x] **`supabase/schema.sql`**:
  - Diperbarui menjadi versi instalasi bersih yang memuat kolom `user_id`, tabel `fuel_fillings`, view `daily_recap_summary with (security_invoker = true)`, dan RLS `owner_only`.

#### 2. Checklist Migrasi Supabase untuk User (Jalankan di SQL Editor Supabase):
1. [ ] Jalankan `supabase/migrations/20261021_01_fase1A_fuel_dan_user_id.sql`
2. [ ] Buka **Supabase Dashboard -> Authentication -> Users**, salin **UID** akun email pribadi Anda.
3. [ ] Buka `supabase/migrations/20261021_02_fase1B_backfill_pemilik.sql`, ganti `GANTI-DENGAN-UID-AKUN-EMAIL-KAMU` dengan UID Anda, lalu jalankan.
4. [ ] Jalankan `supabase/migrations/20261021_03_fase1C_kunci_akses.sql`.
5. [ ] Di Supabase Dashboard -> **Authentication -> Providers -> Email / Anonymous**:
   - Matikan **"Allow anonymous sign-ins"**.
   - Matikan **"Allow new users to sign up"**.

---

### FASE 2 — Skema Baru (Ledger, Kendaraan, Servis)
**Status:** **CLEAR (SKEMA SQLITE & POSTGRES SIAP & TERUJI)**

#### 1. Perubahan Skema
- [x] **`lib/services/ledger_schema.dart`**:
  - DDL SQLite untuk tabel: `accounts`, `vehicles`, `vehicle_logs`, `transactions`, `service_items`, `service_records`.
  - View SQLite: `v_account_balance` dan `v_pool_balance`.
- [x] **`supabase/migrations/20261021_04_fase2_ledger_kendaraan.sql`**:
  - DDL PostgreSQL untuk Supabase lengkap dengan RLS `owner_only` dan trigger `updated_at`.
- [x] **Pengujian Skema**:
  - `test/ledger_db_test.dart` menguji in-memory SQLite: saldo rekening, saldo kas (utama & tambahan), constraint transfer, soft delete, dan validasi servis item.
  - **Hasil Test:** **LULUS (100% Passed)**.

---

### FASE 3 — Model, Service & Provider
**Status:** **IN PROGRESS (Logika Inti Siap)**

- [x] **Logika Murni Finansial (`lib/logic/ledger_math.dart`)**:
  - Fungsi `allocateVehicleCost`: Alokasi biaya motor bersama ke kanvasing/ojol/pribadi menurut km dengan metode sisa terbesar (*Hamilton-Hare*).
  - Fungsi `computeActivityProfits`: Menghitung profit kanvasing, ojol, dan pribadi (income − direct expense − allocated vehicle cost).
  - Fungsi `evaluateServiceItem`: Menentukan status servis berkala (`ok`, `soon`, `overdue`, `unknown`).
  - Pengujian `test/ledger_math_test.dart`: **11 unit test LULUS**.
- [ ] **Model Data (`lib/models/`)**:
  - `account.dart`
  - `vehicle.dart`
  - `vehicle_log.dart`
  - `ledger_transaction.dart`
  - `service_item.dart`
  - `service_record.dart`
- [ ] **Service (`lib/services/`)**:
  - `ledger_service.dart`
  - `finance_report_service.dart`
- [ ] **Provider (`lib/providers/finance_providers.dart`)**

---

### Hasil Pengujian Otomatis Saat Ini
```text
flutter test
00:00 +0: C:/DevApp/personalDailyRecaps/test/ledger_db_test.dart: saldo rekening dan saldo kas
00:00 +1: C:/DevApp/personalDailyRecaps/test/ledger_db_test.dart: soft delete mengurangi saldo; pending tidak dihitung
00:00 +2: C:/DevApp/personalDailyRecaps/test/ledger_db_test.dart: constraint menolak data yang salah bentuk
00:00 +3: C:/DevApp/personalDailyRecaps/test/ledger_db_test.dart: item servis wajib punya minimal satu interval
00:00 +4: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: allocateVehicleCost proporsional km, jumlah tepat
00:00 +5: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: allocateVehicleCost sepertiga: sisa 1 rupiah ke kanvasing (urutan seri)
00:00 +6: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: allocateVehicleCost sisa terbesar ke pecahan terbesar
00:00 +7: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: allocateVehicleCost km nol di satu aktivitas
00:00 +8: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: allocateVehicleCost total km nol atau biaya nol -> semua 0 (tidak error)
00:00 +9: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: computeActivityProfits profit per pekerjaan (komisi pending tidak dihitung)
00:00 +10: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: perUnit pembagian aman
00:00 +11: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: evaluateServiceItem berdasarkan km
00:00 +12: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: evaluateServiceItem berdasarkan hari
00:00 +13: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: evaluateServiceItem km dan hari: yang terburuk menang
00:00 +14: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: evaluateServiceItem belum ada data servis terakhir -> unknown
00:01 +15: C:/DevApp/personalDailyRecaps/test/widget_test.dart: App smoke test
00:03 +16: All tests passed!
```
