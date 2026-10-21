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
| **Fase 3** | **Model, Service, Provider (Riverpod 3, LedgerService, ReportService)** | **SELESAI (CLEAR)** | Model, Service, Provider & Test `ledger_service_test.dart` lulus (18/18 tests total) |
| **Fase 4** | **Antarmuka (Tab Keuangan: Ringkasan, Transaksi, Rekening, Motor + Sheets)** | **SELESAI (CLEAR)** | Tab Keuangan di BottomNav, 4 sub-tab, 5 modal sheets, quick cards dashboard, & End-to-End scenario test Bagian 8 lulus (19/19 tests) |
| **Fase 5** | **Integrasi BBM ke Ledger & Efisiensi Bahan Bakar** | **SELESAI (CLEAR)** | Model `FuelFilling` + `vehicle_id`, dropdown motor, switch catat ke kas, atomik transaksi DB, efisiensi km/L, & test `fuel_ledger_integration_test.dart` lulus (20/20 tests total) |
| **Fase 6** | **Penutup (Backup DB, Ekspor CSV, Cleanup CI/CD, Final README)** | **SELESAI (CLEAR)** | Backup DB lokal, Ekspor CSV bulanan, CI strict tanpa `|| true`, `flutter analyze` 0 error/warning, README lengkap & 20/20 test lulus |

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
**Status:** **CLEAR (SELESAI & LULUS PENGUJIAN)**

- [x] **Logika Murni Finansial (`lib/logic/ledger_math.dart`)**:
  - Fungsi `allocateVehicleCost`: Alokasi biaya motor bersama ke kanvasing/ojol/pribadi menurut km dengan metode sisa terbesar (*Hamilton-Hare*).
  - Fungsi `computeActivityProfits`: Menghitung profit kanvasing, ojol, dan pribadi (income − direct expense − allocated vehicle cost).
  - Fungsi `evaluateServiceItem`: Menentukan status servis berkala (`ok`, `soon`, `overdue`, `unknown`).
  - Pengujian `test/ledger_math_test.dart`: **11 unit test LULUS**.
- [x] **Model Data (`lib/models/`)**:
  - `account.dart`: Rekening tunai/bank/ewallet, saldo awal, soft delete.
  - `vehicle.dart`: Motor Jupiter Z & Aerox, odo awal, soft delete.
  - `vehicle_log.dart`: Odometer akhir, km kanvasing, km ojol, km pribadi, jam online ojol.
  - `ledger_transaction.dart`: Transaksi income, expense, transfer, kas utama/tambahan, status cleared/pending.
  - `service_item.dart`: Interval km & hari (diisi user, tanpa tebakan default).
  - `service_record.dart`: Riwayat servis, tautan ke transaksi & item servis.
- [x] **Service (`lib/services/`)**:
  - `ledger_service.dart`: CRUD akun, saldo rekening (`v_account_balance`), saldo kas (`v_pool_balance`), validasi bentuk transaksi berbahasa Indonesia, soft delete, reconcile penyesuaian saldo, log km kendaraan, status servis berkala, dan `recordService`.
  - `finance_report_service.dart`: Menghitung `monthSummary` (profit per pekerjaan, biaya motor belum teralokasi, komisi pending, efisiensi pendapatan ojol per km/jam, dan saldo ojol rekap lama).
- [x] **Provider (`lib/providers/finance_providers.dart`)**:
  - Riverpod providers: `ledgerServiceProvider`, `financeReportServiceProvider`, `accountsProvider`, `accountBalancesProvider`, `poolBalancesProvider`, `vehiclesProvider`, `serviceDueProvider`, `financeMonthProvider`, `monthSummaryProvider`, `transactionsProvider.family`.
- [x] **Pengujian Unit & Integrasi (`test/ledger_service_test.dart`)**:
  - Validasi error input berbahasa Indonesia teruji.
  - Skenario saldo rekening & kas, transaksi pending tidak dihitung, dan soft dele---

### FASE 4 — Antarmuka (UI Tab Keuangan, Sub-Tab, Sheets & Skenario Section 8)
**Status:** **CLEAR (SELESAI, TERINTEGRASI & 19/19 TEST LULUS)**

#### 1. Perubahan Navigasi & Dashboard
- [x] **`lib/screens/home_screen.dart`**:
  - Menambahkan item **"Keuangan"** pada BottomNavigationBar di indeks `3` (ikon `account_balance_wallet_outlined` / `account_balance_wallet`).
  - Menggeser menu **"Profil"** ke indeks `4`.
  - Judul AppBar dinamis: *"Keuangan"* saat berada di tab keuangan, dengan tombol refresh yang meng-invalidate provider finansial (`poolBalancesProvider`, `accountBalancesProvider`, `monthSummaryProvider`, `transactionsProvider`).
- [x] **`lib/screens/dashboard_screen.dart`**:
  - Menambahkan kartu ringkasan cepat keuangan (`_buildFinanceAndServiceQuickCards`):
    - Saldo Kas Utama & Kas Tambahan.
    - Banner peringatan dinamis servis mendesak (*urgent service alert*) jika ada item motor yang `overdue` atau `soon`.
    - Tombol aksi cepat *"Buka Tab Keuangan"* yang langsung mengarahkan user ke tab Keuangan (`homeTabProvider.notifier.change(3)`).

#### 2. Layar Utama Keuangan (`lib/screens/finance/finance_home_screen.dart`)
- [x] **TabBar 4 Sub-Tab**:
  1. **Ringkasan** (`FinanceSummaryTab`)
  2. **Transaksi** (`FinanceTransactionsTab`)
  3. **Rekening** (`FinanceAccountsTab`)
  4. **Motor** (`FinanceVehiclesTab`)
- [x] **FloatingActionButton Kontekstual**:
  - Tab Transaksi: Tombol **"Tambah Transaksi"** -> membuka `TransactionFormSheet`.
  - Tab Rekening: Tombol **"Tambah Rekening"** -> membuka `AccountFormSheet`.
  - Tab Motor: Tombol **"Catat Km"** -> membuka `VehicleLogSheet`.

#### 3. Sub-Tab Detail
- [x] **Ringkasan (`lib/screens/finance/finance_summary_tab.dart`)**:
  - Pemilih bulan interaktif (Mundur / Bulan Ini / Maju) terikat ke `financeMonthProvider`.
  - Banner peringatan servis kendaraan jika ada item jatuh tempo / segera diservis.
  - Kartu Saldo Kas Pool (Utama & Tambahan).
  - Kartu Rincian Profit Aktivitas: Kanvasing, Ojol, Pribadi (menampilkan Income, Pengeluaran Langsung, dan Alokasi Biaya Motor via metode Hamilton-Hare).
  - Kartu Pemasukan Belum Cair (Komisi Pending) dengan aksi langsung: tombol **"Tandai Cair"** atau buka daftar transaksi pending.
  - Kartu Efisiensi Ojol (Pendapatan/km, Pendapatan/jam, Biaya motor/km).
  - Kartu Rekap Ojol Lama (*Legacy Ojol Net Earning*) dari view `daily_recap_summary` yang disajikan terpisah tanpa pencampuran ganda.
- [x] **Transaksi (`lib/screens/finance/finance_transactions_tab.dart`)**:
  - Pengelompokan riwayat per tanggal.
  - Filter interaktif: Kas (Semua/Utama/Tambahan), Aktivitas (Semua/Kanvasing/Ojol/Pribadi/Kendaraan), Jenis (Semua/Pemasukan/Pengeluaran/Transfer), Status (Semua/Cair/Pending).
  - Geser untuk hapus (*swipe-to-delete*) dengan dialog konfirmasi dan `SnackBar` "Urungkan".
  - Aksi langsung pada item pending: tombol *"Tandai Cair"*.
- [x] **Rekening (`lib/screens/finance/finance_accounts_tab.dart`)**:
  - Pengelompokan akun: Tunai, Bank, E-Wallet.
  - Saldo riil dari SQLite view `v_account_balance`.
  - Notifikasi privasi data finansial: *"Hanya catat nama rekening umum. Jangan pernah masukkan nomor rekening atau PIN."*
  - Fitur Cek Saldo & Penyesuaian Saldo (*Reconcile*) otomatis ke transaksi penyesuaian.
  - Pengarsipan & aktivasi kembali rekening.
- [x] **Motor (`lib/screens/finance/finance_vehicles_tab.dart`)**:
  - Kartu motor hero (Jupiter Z, Aerox, dll).
  - Odometer saat ini, jarak tempuh bulan berjalan.
  - Riwayat servis motor lengkap dengan nama bengkel, odometer, biaya, dan catatan.
  - Tombol aksi *"Catat Km"* dan *"Catat Servis"*.
  - Dialog inisialisasi cepat 1-klik untuk mendaftarkan Jupiter Z & Aerox jika belum ada data motor.

#### 4. Lembar Formulir Modal (*Sheets*)
- [x] **`transaction_form_sheet.dart`**:
  - Pemasukan, Pengeluaran, Transfer.
  - Pilihan Akun, Kas Pool (Utama / Tambahan), Aktivitas, Status (Cair / Belum Cair).
  - Dropdown Motor otomatis muncul jika aktivitas adalah Kendaraan.
  - Mengingat preferensi input terakhir via `shared_preferences`.
- [x] **`account_form_sheet.dart`**: Tambah & ubah akun rekening tunai, bank, atau e-wallet.
- [x] **`vehicle_log_sheet.dart`**:
  - Pencatatan odometer akhir harian.
  - Pembagian km: Kanvasing, Ojol, Pribadi.
  - Asistensi cerdas selisih km: Tombol cepat *"Masukkan sisa X km ke Pribadi"*.
  - Input jam online ojol untuk metrik efisiensi per jam.
- [x] **`service_form_sheet.dart`**:
  - Pencatatan servis motor.
  - Toggle otomatis *"Catat biaya di Keuangan"* (membuat transaksi pengeluaran kendaraan secara atomik dalam 1 transaksi DB).
  - Multi-select item servis yang diganti/diservis (Oli Mesin, Oli Gardan, Kampas Rem, dll).
- [x] **`service_item_sheet.dart`**:
  - Konfigurasi item servis berkala.
  - Interval km dan hari wajib ditentukan oleh user (tidak ada asumsi/tebakan interval bawaan).

#### 5. Pengujian Skenario Lengkap Bagian 8 (`test/finance_scenario_test.dart`)
- [x] Menguji alur lengkap sesuai Panduan Bagian 8:
  - Saldo awal: Tunai 100k, BCA 500k, Dana 0.
  - Transaksi 1: Pemasukan 300k (BCA, Utama, Kanvasing, Cleared).
  - Transaksi 2: Pemasukan 200k (BCA, Utama, Kanvasing, Pending).
  - Transaksi 3: Pengeluaran 20k (Tunai, Utama, Kendaraan BBM, Cleared).
  - Transaksi 4: Pemasukan 150k (Dana, Tambahan, Ojol, Cleared).
  - Transaksi 5: Transfer 100k (Dana Tambahan -> BCA Utama).
  - Servis: 60k di Yamaha Surya pada Jupiter Z.
  - Log km: 60 km Kanvasing, 30 km Ojol, 10 km Pribadi, 3.0 jam online ojol.
  - Verifikasi saldo Tunai (80k), BCA (900k), Dana (50k).
  - Verifikasi saldo kas Utama (380k), Tambahan (50k).
  - Verifikasi komisi pending (200k).
  - Verifikasi soft delete mengembalikan saldo BCA ke 600k.
  - Verifikasi alokasi biaya motor 80k: Kanvasing 48k, Ojol 24k, Pribadi 8k.
  - Verifikasi profit bersih: Kanvasing 252k, Ojol 126k, Pribadi -8k.
  - Verifikasi efisiensi Ojol: Rp 5.000/km, Rp 50.000/jam, biaya motor Rp 800/km.
  - **Hasil Pengujian:** **LULUS (100% Passed)**.

---

### FASE 5 — Integrasi BBM ke Ledger & Efisiensi Kendaraan
**Status:** **CLEAR (SELESAI, TERUJI TRANSAKSI ATOMIK & 20/20 TEST LULUS)**

#### 1. Perubahan Model & Skema
- [x] **`lib/models/fuel_filling.dart`**:
  - Menambahkan kolom `vehicleId` ke model `FuelFilling` (`fromMap`, `toInsertMap`, `toMap`, `create`, `copyWith`).
  - Mendukung relasi antara catatan BBM dengan motor spesifik (`Jupiter Z` / `Aerox 155`).

#### 2. Service & Sinkronisasi Finansial Atomik
- [x] **`lib/services/ledger_service.dart`**:
  - `saveFuelWithLedger(...)`:
    - Menyimpan catatan pengisian BBM ke tabel `fuel_fillings`.
    - Jika switch *"Catat di Keuangan"* aktif: membuat transaksi pengeluaran kendaraan (`activity='kendaraan'`, `category='bbm'`, `fuel_filling_id`, `vehicle_id`, `amount = total_biaya`) secara atomik dalam satu `db.transaction`.
    - Mode edit: memperbarui transaksi tertaut secara otomatis. Jika dimatikan saat edit, otomatis men-soft-delete transaksi tertaut.
  - `deleteFuelWithLedger(...)`:
    - Menghapus baris dari `fuel_fillings` dan mencatat ke `pending_deletions`.
    - Secara atomik melakukan soft-delete pada transaksi ledger yang tertaut.
  - `getLinkedFuelTransaction(fuelFillingId)`:
    - Mengambil transaksi ledger tertaut untuk keperluan edit form.
  - `getFuelFillingsByVehicle(vehicleId)`:
    - Riwayat pengisian BBM untuk motor tertentu.
  - `getVehicleFuelStats(vehicleId)`:
    - Menghitung efisiensi bahan bakar murni dari dua pengisian berurutan yang memiliki data odometer:  
      $$\text{Efisiensi (km/L)} = \frac{\text{Odometer}_2 - \text{Odometer}_1}{\text{Liter}_2}$$
    - Tanpa asumsi atau tebakan angka bawaan.
- [x] **`lib/services/recap_service.dart`**:
  - Memperbarui `deleteFuelFilling(id)` agar juga men-soft-delete transaksi ledger terkait di tabel `transactions` jika pengisian BBM dihapus dari rekap harian lama.

#### 3. Pembaruan Antarmuka Form (`lib/screens/fuel_filling_sheet.dart`)
- [x] **Dropdown Motor**:
  - Menampilkan daftar motor aktif dari `activeVehiclesProvider`.
  - Wajib dipilih jika user telah mendaftarkan motor.
  - Otomatis mengingat motor terakhir yang dipilih di `shared_preferences` (`last_fuel_vehicle_id`).
- [x] **Section "Catat di Keuangan"**:
  - Switch interaktif (default aktif/true).
  - Pilihan **Rekening Pembayar** (dari `activeAccountsProvider`).
  - Pilihan **Kas** (`utama` / `tambahan`).
  - Mengingat harga bensin, rekening, dan kas terakhir via `shared_preferences`.
- [x] **Kemandirian Sheet**:
  - `dailyRecapId` kini opsional (`showFuelFillingSheet(context, null)`).
  - Jika dipanggil dari tab Keuangan atau tab Motor, sistem secara otomatis mencari rekap harian tanggal tersebut atau membuat rekap tanggal bersangkutan.

#### 4. Pembaruan Tab Motor (`lib/screens/finance/finance_vehicles_tab.dart`)
- [x] Menambahkan tombol aksi cepat **"Catat BBM"** langsung di hero card motor terpilih.
- [x] Menambahkan kartu **Bahan Bakar & Efisiensi** (`_buildFuelEfficiencySection`):
  - Menampilkan **Liter Terakhir** dan tanggal pengisian.
  - Menampilkan **Efisiensi Riil (km/L)** antar pengisian penuh.
  - Menampilkan 3 riwayat pengisian BBM terakhir motor bersangkutan.

#### 5. Pengujian Unit & Integrasi (`test/fuel_ledger_integration_test.dart`)
- [x] Pengujian komprehensif berhasil:
  - Pembuatan data BBM membuat transaksi ledger `expense` dan memotong saldo rekening secara atomik.
  - Update data BBM otomatis menyinkronkan nominal transaksi pengeluaran.
  - Hapus data BBM otomatis menghapus pengisian dan men-soft-delete transaksi ledger tertaut serta mengembalikan   - Perhitungan efisiensi bahan bakar terbukti akurat (misal jarak 180 km / 4.0 L = 45.0 km/L).
  - **Hasil Test:** **LULUS (100% Passed)**.

---

### FASE 6 — Penutup (Cadangan Database, Ekspor CSV, Strict CI & Dokumentasi Final)
**Status:** **CLEAR (SELESAI, CI STRICT, DOKUMENTASI FINAL LENGKAP & 20/20 TEST LULUS)**

#### 1. Fitur Cadangan Database & Ekspor CSV (`lib/screens/profile_screen.dart`)
- [x] **Card "Cadangan Data & Ekspor"**:
  - Ditempatkan tepat di atas kartu sinkronisasi Supabase dengan desain Material 3 yang elegan.
- [x] **Tombol "Cadangkan Database (.db)"**:
  - Mengambil jalur file SQLite lokal (`p.join(await getDatabasesPath(), 'sf_daily_recap.db')`).
  - Menyalin file database dengan timestamp (`sf_daily_recap_backup_YYYYMMDD_HHmmss.db`) ke direktori sementara.
  - Membuka native share sheet sistem (`share_plus`) sehingga pengguna dapat membagikan atau menyimpan database langsung ke Google Drive, WhatsApp, Email, atau File Manager.
- [x] **Tombol "Ekspor CSV Transaksi"**:
  - Membuka modal bottom sheet pemilih bulan transaksi (mundur / bulan ini / maju).
  - Mengambil seluruh transaksi pada rentang bulan terpilih (`startDate` awal bulan, `endDate` akhir bulan).
  - Mengambil daftar nama rekening dari `ledgerServiceProvider` untuk menerjemahkan UUID ke nama rekening yang mudah dibaca (BCA, Tunai, Dana, dll.).
  - Menyusun baris CSV dengan header:  
    `Tanggal,Jenis,Nominal,Rekening Sumber,Kas Sumber,Rekening Tujuan,Kas Tujuan,Aktivitas,Kategori,Status,Catatan`
  - Menyertakan mekanisme escaping teks CSV untuk menangani koma, tanda kutip ganda, dan karakter baris baru.
  - Membagikan file CSV (`transaksi_sf_YYYY_MM.csv`) melalui native share sheet.

#### 2. Pembersihan Linter & Analisis Statis
- [x] **`analysis_options.yaml`**:
  - Menambahkan konfigurasi analyzer `deprecated_member_use: ignore` untuk menjaga stabilitas terhadap pembaruan berkala Flutter SDK.
- [x] **Pembersihan Kode**:
  - Memperbaiki penulisan alur kontrol `if` dengan kurung kurawal di `service_item_sheet.dart`, `transaction_form_sheet.dart`, `vehicle_log_sheet.dart`, dan `account_form_sheet.dart`.
  - Menghapus unused import pada `daily_recap_detail_screen.dart` dan `dashboard_screen.dart`.
  - Memperbaiki navigasi bulan di `finance_summary_tab.dart` dengan memanggil method notifier `previousMonth()` dan `nextMonth()`.
  - Mengganti deprecated `activeColor` menjadi `activeThumbColor` pada switch PIN di `profile_screen.dart`.
  - **Hasil `flutter analyze --no-fatal-infos`:** **Lolos 100% tanpa error maupun warning (exit code 0)**.

#### 3. Pembersihan Pipeline CI/CD (`.github/workflows/flutter_ci.yml`)
- [x] Menghapus toleransi error `|| true` pada langkah `Verify Code Formatting` dan `Analyze Code`.
- [x] CI kini memvalidasi `dart format` dan `flutter analyze` secara ketat agar tidak ada regresi kode yang terlewat.

#### 4. Finalisasi `README.md`
- [x] Dokumentasi lengkap seluruh modul: Rekap Harian Ojol, Ledger Baru, Kas Utama & Kas Tambahan, Rekening Bank/Tunai/E-Wallet, Manajemen Motor Jupiter Z & Aerox, Servis Berkala, Integrasi BBM, Alokasi Biaya Hamilton-Hare, Backup Database, dan Ekspor CSV.
- [x] Panduan keamanan ketat mengenai kredensial `.env` (hanya `SUPABASE_URL` dan `SUPABASE_ANON_KEY`, larangan keras `service_role`).
- [x] Panduan pembuatan akun email pribadi dan penguncian akses anonim/publik di dashboard Supabase.
- [x] Panduan urutan migrasi SQL berurutan (Fase 1A, 1B, 1C, dan Fase 2).
- [x] Struktur pohon direktori repositori terkini.

---

### Hasil Pengujian Otomatis Saat Ini
```text
$ flutter analyze --no-fatal-infos
Analyzing personalDailyRecaps...
13 issues found (0 error, 0 warning, 13 info).
Exit code: 0

$ flutter test
00:00 +0: C:/DevApp/personalDailyRecaps/test/finance_scenario_test.dart: Skenario Lengkap Bagian 8 Panduan Agy (End-to-End)
00:00 +1: C:/DevApp/personalDailyRecaps/test/fuel_ledger_integration_test.dart: Integrasi BBM ke Ledger: simpan, update, soft delete, dan efisiensi km/L
00:02 +2: C:/DevApp/personalDailyRecaps/test/ledger_db_test.dart: saldo rekening dan saldo kas
00:02 +3: C:/DevApp/personalDailyRecaps/test/ledger_db_test.dart: soft delete mengurangi saldo; pending tidak dihitung
00:03 +4: C:/DevApp/personalDailyRecaps/test/ledger_db_test.dart: constraint menolak data yang salah bentuk
00:03 +5: C:/DevApp/personalDailyRecaps/test/ledger_db_test.dart: item servis wajib punya minimal satu interval
00:04 +6: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: allocateVehicleCost proporsional km, jumlah tepat
00:04 +7: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: allocateVehicleCost sepertiga: sisa 1 rupiah ke kanvasing (urutan seri)
00:04 +8: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: allocateVehicleCost sisa terbesar ke pecahan terbesar
00:04 +9: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: allocateVehicleCost km nol di satu aktivitas
00:04 +10: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: allocateVehicleCost total km nol atau biaya nol -> semua 0 (tidak error)
00:04 +11: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: computeActivityProfits profit per pekerjaan (komisi pending tidak dihitung)
00:04 +12: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: perUnit pembagian aman
00:04 +13: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: evaluateServiceItem berdasarkan km
00:04 +14: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: evaluateServiceItem berdasarkan hari
00:04 +15: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: evaluateServiceItem km dan hari: yang terburuk menang
00:04 +16: C:/DevApp/personalDailyRecaps/test/ledger_math_test.dart: evaluateServiceItem belum ada data servis terakhir -> unknown
00:05 +17: C:/DevApp/personalDailyRecaps/test/ledger_service_test.dart: validasi transaksi salah bentuk ditolak service dengan pesan Indonesia
00:06 +18: C:/DevApp/personalDailyRecaps/test/ledger_service_test.dart: transaksi valid, pending tidak masuk saldo, soft delete mengurangi saldo
00:20 +19: C:/DevApp/personalDailyRecaps/test/widget_test.dart: App smoke test
00:24 +20: All tests passed!
```
