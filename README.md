# SF Daily Recap & Financial Ledger

Aplikasi Android pribadi untuk rekap kas, pesanan harian (ojol), serta manajemen keuangan terpadu (kanvasing XL Satu, sidejob ojol, multi-rekening, perawatan motor, dan integrasi pengisian BBM).

Dibangun menggunakan **Flutter** + **Riverpod 3** + **SQLite lokal (v11)** dengan sinkronisasi cloud **Supabase** berbasis otorisasi ketat (`owner_only` RLS).

---

## Fitur Utama

### 1. Rekap Harian & Pesanan (Legacy Ojol)
- **Rekap Harian**: Cash awal, saldo awal aplikasi, petty cash breakdown (perhitungan pecahan rupiah otomatis), dan tanggal.
- **Order & Transaksi Harian**: Pemasukan, pengeluaran pesanan, cash customer, deduct cash app, dan top-up saldo.
- **Perhitungan Net Earning**: Dihitung konsisten via SQL view server-side & client-side tanpa duplikasi data.

### 2. Modul Keuangan & Multi-Kas (Ledger Terpadu)
- **Kas Utama**: Pekerjaan utama kanvasing WiFi XL Satu / XL Home (komisi/insentif per pemasangan).
- **Kas Tambahan**: Pekerjaan sampingan Ojol. Saldo dan performa terpisah dari kas utama.
- **Manajemen Rekening**: Rekening Tunai, Bank (BCA, Mandiri, dll.), dan E-Wallet (Dana, GoPay, ShopeePay). *Hanya nama panggilan umum, dilarang menyimpan nomor rekening atau kartu kredit/debit demi privasi.*
- **Transfer Antar Rekening/Kas**: Pindah dana antar rekening dan/atau kas secara aman.
- **Komisi Belum Cair (Pending)**: Status `pending` tidak memengaruhi saldo kas sampai ditandai `cleared`.
- **Cek Saldo & Penyesuaian (Reconcile)**: Penyesuaian otomatis antara saldo buku dan saldo riil aplikasi bank.

### 3. Modul Kendaraan & Perawatan Motor
- **Multi-Motor**: Pemantauan terpisah untuk **Jupiter Z** dan **Aerox 155**.
- **Log Jarak Tempuh (Km)**: Pembagian km harian untuk Kanvasing, Ojol, dan Pribadi.
- **Alokasi Biaya Motor (Metode Hamilton-Hare)**: Biaya bahan bakar dan servis motor bersama dialokasikan secara adil ke profit kanvasing, ojol, dan pribadi berdasarkan proporsi km riil dengan metode sisa terbesar (rupiah bulat).
- **Servis Berkala**: Pemantauan jatuh tempo servis (status Hijau/Kuning/Merah) berdasarkan interval km dan/atau hari yang ditentukan sendiri oleh pengguna.
- **Pencatatan Servis Atomik**: Biaya servis otomatis membuat transaksi pengeluaran kendaraan di ledger dalam satu transaksi database.

### 4. Bahan Bakar (BBM) Terintegrasi
- **Pencatatan BBM Mandiri**: Catat BBM langsung dari tab Keuangan atau rekap harian.
- **Otomatis Masuk Ledger**: Opsi switch "Catat di Keuangan" untuk memotong saldo kas/rekening secara atomik.
- **Efisiensi Bahan Bakar Riil (km/L)**: Dihitung akurat dari selisih odometer antar pengisian tanpa angka tebakan bawaan.

### 5. Cadangan Data & Ekspor CSV
- **Cadangkan Database Lokal**: Salin dan bagikan file `sf_daily_recap.db` langsung ke Google Drive, WhatsApp, Email, atau penyimpanan lokal melalui menu Profil.
- **Ekspor CSV Transaksi Bulanan**: Unduh rekap mutasi keuangan per bulan dalam format CSV standar yang dapat dibuka di Microsoft Excel atau Google Sheets.

---

## Keamanan & Pengaturan `.env`

File `.env` di-load oleh aplikasi untuk koneksi ke Supabase.

```env
SUPABASE_URL=https://xxxxxxxxxxxx.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9...
```

> [!IMPORTANT]
> **Peringatan Keamanan Kredensial:**
> - File `.env` **HANYA BOLEH** berisi `SUPABASE_URL` dan `SUPABASE_ANON_KEY` (kunci publik anonim).
> - **JANGAN PERNAH** memasukkan `service_role key` ke dalam `.env` atau kode aplikasi, karena kunci tersebut melewati seluruh kebijakan keamanan RLS.
> - File `.env` sudah masuk ke dalam `.gitignore` sehingga tidak akan terunggah ke repositori publik.

---

## Panduan Autentikasi & Akun Pribadi

Aplikasi ini dirancang khusus untuk penggunaan pribadi dengan keamanan data penuh:

1. **Buat Akun Pribadi di Supabase:**
   - Masuk ke **Supabase Dashboard** -> **Authentication** -> **Users** -> Klik **Add user** -> Pilih **Create user**.
   - Masukkan email pribadi dan kata sandi yang aman.
   - Salin **UID** user tersebut untuk langkah migrasi.
2. **Kunci Akses Publik & Anonim:**
   - Masuk ke **Authentication** -> **Sign In / Providers** -> **Email**:
     - **Matikan "Allow new users to sign up"** (mencegah pendaftaran orang asing).
   - Masuk ke **Authentication** -> **Sign In / Providers** -> **Anonymous**:
     - **Matikan "Allow anonymous sign-ins"**.
3. **Login di Aplikasi:**
   - Buka aplikasi dan masuk menggunakan email dan password yang telah didaftarkan.

---

## Urutan Migrasi Database Supabase

### A. Untuk Database yang Sudah Berisi Data Lama:
Jalankan file SQL berikut secara berurutan di **Supabase SQL Editor**:

1. `supabase/migrations/20261021_01_fase1A_fuel_dan_user_id.sql`  
   *(Menambahkan tabel `fuel_fillings`, kolom `user_id`, dan RLS awal)*
2. Buka `supabase/migrations/20261021_02_fase1B_backfill_pemilik.sql`:  
   Ganti `GANTI-DENGAN-UID-AKUN-EMAIL-KAMU` dengan UID akun Supabase Anda, lalu jalankan.
3. `supabase/migrations/20261021_03_fase1C_kunci_akses.sql`  
   *(Mengaktifkan `NOT NULL` pada `user_id` dan mengunci view dengan `security_invoker = true`)*
4. `supabase/migrations/20261021_04_fase2_ledger_kendaraan.sql`  
   *(Membuat tabel `accounts`, `vehicles`, `vehicle_logs`, `transactions`, `service_items`, `service_records`, serta view saldo)*

### B. Untuk Instalasi Bersih (Project Supabase Baru):
Jalankan file `supabase/schema.sql` langsung di SQL Editor. File ini sudah mencakup seluruh skema lengkap dan kebijakan keamanan mutakhir.

---

## Struktur Direktori Proyek

```
lib/
├── logic/
│   └── ledger_math.dart               # Logika murni: alokasi biaya Hamilton-Hare, profit, status servis
├── models/
│   ├── account.dart                   # Model rekening (cash, bank, ewallet)
│   ├── daily_order.dart               # Model pesanan ojol
│   ├── daily_recap.dart               # Model rekap harian
│   ├── fuel_filling.dart              # Model pengisian BBM (+ vehicleId)
│   ├── ledger_transaction.dart        # Model mutasi ledger (income, expense, transfer)
│   ├── petty_cash_item.dart           # Model pecahan petty cash
│   ├── saldo_mutation.dart            # Model mutasi saldo rekap lama
│   ├── service_item.dart              # Model item servis berkala & interval
│   ├── service_record.dart            # Model riwayat servis bengkel
│   ├── vehicle.dart                   # Model motor (Jupiter Z, Aerox)
│   └── vehicle_log.dart               # Model log km harian & jam online
├── providers/
│   ├── finance_providers.dart         # State management Keuangan & Motor (Riverpod 3)
│   └── recap_providers.dart           # State management Rekap Harian
├── screens/
│   ├── finance/
│   │   ├── account_form_sheet.dart    # Lembar modal tambah/ubah rekening
│   │   ├── finance_accounts_tab.dart  # Sub-tab daftar rekening & rekonsiliasi
│   │   ├── finance_home_screen.dart   # Layar utama tab Keuangan
│   │   ├── finance_summary_tab.dart   # Sub-tab ringkasan kas, profit & efisiensi
│   │   ├── finance_transactions_tab.dart # Sub-tab mutasi & filter transaksi
│   │   ├── finance_vehicles_tab.dart  # Sub-tab motor, servis & BBM
│   │   ├── service_form_sheet.dart    # Lembar modal catat riwayat servis
│   │   ├── service_item_sheet.dart    # Lembar modal konfigurasi item servis
│   │   ├── transaction_form_sheet.dart# Lembar modal catat pemasukan/pengeluaran/transfer
│   │   └── vehicle_log_sheet.dart     # Lembar modal catat km harian motor
│   ├── dashboard_screen.dart          # Dashboard ringkasan + kartu cepat finansial
│   ├── daily_recap_detail_screen.dart # Detail rekap harian pesanan ojol
│   ├── fuel_filling_sheet.dart        # Lembar modal catat BBM terintegrasi
│   ├── home_screen.dart               # Navigasi utama (Dashboard, Rekap, Laporan, Keuangan, Profil)
│   ├── login_screen.dart              # Layar masuk email pribadi
│   ├── pin_lock_screen.dart           # Layar proteksi keamanan PIN lokal
│   ├── profile_screen.dart            # Profil, backup database, ekspor CSV, sync
│   └── splash_screen.dart             # Penanganan sesi awal
└── services/
    ├── finance_report_service.dart    # Agregasi laporan laba-rugi & performa
    ├── ledger_schema.dart             # Definisi skema SQLite lokal v11
    ├── ledger_service.dart            # Operasi database ledger, kendaraan & servis
    ├── local_db.dart                  # Singleton database SQLite
    ├── recap_service.dart             # Operasi database rekap harian
    └── sync_service.dart              # Mesin sinkronisasi SQLite <-> Supabase

supabase/
├── migrations/                        # Berkas migrasi bertahap (Fase 1A, 1B, 1C, Fase 2)
└── schema.sql                         # Skema lengkap konsolidasi untuk instalasi baru

test/
├── finance_scenario_test.dart         # Pengujian End-to-End skenario keuangan Bagian 8
├── fuel_ledger_integration_test.dart  # Pengujian integrasi atomik BBM ke ledger
├── ledger_db_test.dart                # Pengujian skema SQLite lokal & view saldo
├── ledger_math_test.dart              # Pengujian unit kalkulasi alokasi & profit
├── ledger_service_test.dart           # Pengujian validasi & operasi service ledger
└── widget_test.dart                   # Smoke test aplikasi
```

---

## Menjalankan Pengujian & Format Kode

Untuk memverifikasi keutuhan kode:

```bash
# Format kode sesuai standar Dart
dart format .

# Analisis statis linter
flutter analyze --no-fatal-infos

# Menjalankan seluruh test suite otomatis (20 test)
flutter test
```

---

## CI/CD & Rilis APK Otomatis

Aplikasi ini menggunakan GitHub Actions (`.github/workflows/flutter_ci.yml`):
- **Otomatisasi Lint & Test**: Setiap pull request atau push ke branch `master`/`main` memvalidasi formatting, linter, dan 20 pengujian unit/integrasi.
- **Rilis APK Otomatis**: Setiap push tag (misal `BetaTest` atau `v1.0.0`) secara otomatis mengompilasi release APK dan mengunggahnya ke halaman [Releases GitHub](https://github.com/fadli87/personaldailyrecaps/releases).
