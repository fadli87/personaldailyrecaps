# PANDUAN IMPLEMENTASI UNTUK AGY — Perbaikan & Modul Keuangan/Kendaraan (SF Daily Recap)

Repo: `fadli87/personaldailyrecaps` (Flutter + Riverpod 3 + SQLite lokal + sinkron Supabase).
Disusun: 21 Okt 2026. Bahasa antarmuka aplikasi: **Indonesia**. Uang: **rupiah bulat**.

## 0. Cara memakai panduan ini

1. Kerjakan **berurutan per fase**. Satu fase = satu commit (branch `feature/keuangan-kendaraan`).
2. Setelah tiap fase jalankan: `flutter pub get && dart format . && flutter analyze && flutter test`. Jangan menambah warning baru.
3. **Jangan** mengubah rumus view `daily_recap_summary` (SQLite maupun Supabase), jangan menghapus/mengganti nama kolom lama, jangan memigrasi data lama. Semua perubahan bersifat **menambah**.
4. Kode di Lampiran sudah diuji sebagian: SQL diuji di PostgreSQL 16 dan SQLite 3.45 (saldo, constraint, RLS), angka uji logika dihitung silang dengan Python. **Kode Dart belum pernah dikompilasi** (Flutter tidak tersedia saat panduan ini disusun). Jika `flutter analyze` mengeluh soal sintaks, perbaiki tanpa mengubah perilaku yang diuji oleh test.
5. Hal yang tidak bisa dicek penyusun: pengaturan project Supabase milik user (apakah *Anonymous sign-ins* aktif, apakah *sign up* terbuka) dan isi layar `dashboard_screen.dart`/`report_screen.dart`. Periksa sendiri.

## 1. Keputusan desain (sudah disepakati dengan user)

| Hal | Keputusan |
|---|---|
| Kas utama | Pekerjaan utama: **kanvasing WiFi XL Satu / XL Home** (komisi/insentif per pemasangan) |
| Kas tambahan | **Ojol** (sidejob). Saldo awal/akhir terpisah dari kas utama |
| Transfer | Jenis transaksi tersendiri, bukan pemasukan+pengeluaran. Bisa pindah rekening dan/atau pindah kas |
| Rekening | Tunai, bank, e-wallet. Nama panggilan saja. **Dilarang menyimpan nomor rekening/kartu** |
| Motor | Dua unit: **Jupiter Z** dan **Aerox**. Tanpa hardware/OBD. Status motor tetap dipantau di aplikasi Yamaha Motor On; di sini hanya input manual |
| Biaya motor | Dicatat sebagai `activity = 'kendaraan'`, lalu **dialokasikan** ke kanvasing/ojol/pribadi menurut km (metode sisa terbesar, lihat `allocateVehicleCost`) |
| Komisi belum cair | `status = 'pending'`: tidak masuk saldo sampai ditandai `cleared` |
| Hapus data | Tabel baru memakai **soft delete** (`deleted_at`), bukan antrean `pending_deletions` |

**Opsi A (diterapkan): ledger baru TIDAK menggantikan Rekap Harian lama.**
- Rekap Harian lama tetap mengurus ojol (ShopeeFood/Grab/Mandiri/BCA, petty cash, tip, insentif) apa adanya.
- Ledger baru mengurus kanvasing, biaya motor, transfer, dan rekening baru.
- Tiap rupiah dicatat di **satu tempat saja** agar tidak terhitung ganda. Di layar Ringkasan, angka ojol dari Rekap Harian lama ditampilkan **terpisah** (jangan dijumlahkan dengan profit ojol dari ledger).
- Migrasi penuh wallet lama ke `accounts` (Opsi B) **ditunda**; jangan dikerjakan.

## 2. Temuan pada kode saat ini (alasan Fase 1)

| # | Temuan | Lokasi | Dampak |
|---|---|---|---|
| T1 | `fuel_fillings` hanya ada di SQLite, **tidak ada di Supabase dan tidak ikut sync** | `supabase/schema.sql`, `lib/services/sync_service.dart` | Data BBM hilang bila HP hilang/app dipasang ulang |
| T2 | **Instalasi baru tidak punya tabel `fuel_fillings`**: `onCreate` (versi 10) tidak membuatnya, hanya blok `oldVersion < 10` | `lib/services/local_db.dart` | Menambah pengisian BBM di perangkat baru gagal |
| T3 | RLS = "semua pengguna terautentikasi boleh semuanya", tanpa `user_id`. Sesi **anonim** juga ber-role `authenticated` | `supabase/schema.sql`, `login_screen.dart` (`_handleAnonymousLogin`, tombol di sekitar baris 331) | Jika *Anonymous sign-ins* aktif **atau pendaftaran email terbuka** (app punya tombol Daftar), siapa pun yang punya URL + anon key (tertanam di APK) bisa membaca/menulis seluruh data keuangan. Repo ini publik dan CI meng-upload APK sebagai artifact |
| T4 | View `daily_recap_summary` berjalan dengan hak pemilik view dan **melewati RLS** | `supabase/schema.sql` | Bahkan dengan RLS yang benar pada tabel, view membocorkan data. Sudah dibuktikan di simulasi: akun lain melihat 1 baris. **`CREATE OR REPLACE VIEW` menghapus opsi `security_invoker`**, jadi setelah setiap replace opsi itu harus dipasang ulang |
| T5 | Pull sync memasukkan `Map.from(remote)` langsung ke SQLite | `sync_service.dart` `_syncPull` | Begitu Supabase punya kolom `user_id`, insert/update lokal **error** (kolom tidak ada di SQLite) |
| T6 | `select()` tanpa paginasi | `sync_service.dart` `_syncPull` | PostgREST membatasi 1000 baris per request; `daily_order` bisa melewati itu dan terpangkas diam-diam |
| T7 | Tidak ada try/catch per tabel di `_syncPush` | `sync_service.dart` | Satu baris gagal menghentikan seluruh sync |
| T8 | README menyebut `main.dart` memanggil `signInAnonymously()`, kenyataannya tidak; ada juga toggle "Daftar akun baru" | `README.md`, `login_screen.dart` (`_isSignUp`) | Dokumentasi menyesatkan; pendaftaran publik tidak perlu untuk app pribadi |
| T9 | Dua cara mencatat BBM: flag `is_fuel_expense` di order lama dan tabel `fuel_fillings` | `daily_order`, `fuel_filling_sheet.dart` | Berisiko tercatat ganda saat motor bertambah. Default harga BBM juga di-hardcode (13500 di sheet, 10000 di rekap) |
| T10 | `.env` ter-bundle sebagai asset | `pubspec.yaml` | Aman **hanya** bila yang ada di sana anon key (publik by design) dan RLS benar. Jangan pernah menaruh service_role key |
| T11 | `_syncDeletions` membuang antrean penghapusan pada **error apa pun**, termasuk saat offline | `sync_service.dart` `_syncDeletions` | Baris yang dihapus saat offline tetap ada di server, lalu **muncul lagi** di HP saat pull |

## 3. FASE 1 — Perbaikan fondasi (kerjakan dulu, risiko rendah)

### 1.1 Perubahan kode app (kerjakan SEBELUM menjalankan SQL di Supabase)

Urutan ini penting: kode baru harus toleran terhadap kolom `user_id` dan tabel yang belum ada, sehingga tidak ada jendela waktu di mana sync rusak.

**a. `lib/services/sync_service.dart`** — ganti implementasi dengan pola generik (referensi kode di **Lampiran H**):
- Tambahkan `fuel_fillings` ke push dan pull (urutan: setelah `daily_recap`, sebelum tabel yang bergantung padanya).
- `_pullTable` memfilter kolom remote menurut `PRAGMA table_info` lokal (menyelesaikan T5), memakai paginasi `.order(pk).range()` (T6), dan mengonversi boolean.
- Bungkus tiap tabel dengan try/catch; kumpulkan error, lanjutkan tabel berikutnya, lalu lempar satu error ringkasan di akhir (T7).
- Kolom boolean Supabase↔SQLite: `daily_order.is_fuel_expense` (sudah ada), plus `accounts.is_active`, `vehicles.is_active` pada Fase 2.
- Tabel `daily_extra` memakai PK `daily_recap_id`; tabel lain `id`.
- `_syncDeletions`: jangan buang antrean saat gagal; saat pull, lewati id yang masih ada di `pending_deletions` (T11).
- Pertahankan semantik yang ada: baris lokal `is_synced = 0` tidak ditimpa oleh pull.

**b. `lib/services/local_db.dart`** — naikkan `version` dari 10 ke **11** (kode di **Lampiran I**):
- `onCreate`: tambahkan pembuatan `fuel_fillings` (kini dengan kolom `vehicle_id`) dan semua `ledgerSchemaStatements` (menyelesaikan T2).
- `onUpgrade`, blok baru `if (oldVersion < 11)`: `CREATE TABLE IF NOT EXISTS fuel_fillings` (untuk instalasi yang dibuat pada v10 lewat `onCreate` dan tidak punya tabelnya), tambahkan kolom `vehicle_id` bila belum ada (cek dengan `PRAGMA table_info`), jalankan `ledgerSchemaStatements`.
- Biarkan baris "selalu re-create view" tetap di akhir `onUpgrade`.
- Salin **Lampiran E** persis ke `lib/services/ledger_schema.dart`.

**c. Hapus jalur anonim dan pendaftaran publik**
- `login_screen.dart`: hapus tombol "Masuk Anonim" dan method `_handleAnonymousLogin`; hapus toggle `_isSignUp` dan cabang `signUp` (akun dibuat sekali lewat dashboard Supabase).
- `splash_screen.dart` (sekitar baris 47–66): bila `currentSession` ada tetapi `currentUser?.isAnonymous == true`, panggil `auth.signOut()` lalu arahkan ke `LoginScreen`.
- `profile_screen.dart` (sekitar baris 478–483): hapus cabang teks "ID Sesi Anonim"; tampilkan email saja.
- `README.md`: hapus bagian "Catatan tentang login" yang menyuruh mengaktifkan anonymous sign-in; ganti dengan langkah membuat akun email + menjalankan migrasi di `supabase/migrations/`.

**d. Hindari catatan BBM ganda (T9)** — di `lib/screens/order_form_sheet.dart` beri teks bantuan pada switch/checkbox penanda pengeluaran bensin (`_isFuelExpense`): *"Untuk isi bensin, gunakan Catat BBM di tab Keuangan agar tidak tercatat ganda."* Di `fuel_filling_sheet.dart` ganti default harga hardcoded 13500 dengan harga terakhir yang dipakai (simpan di `shared_preferences`, kunci `last_fuel_price`), fallback kosong (bukan angka tebakan).

### 1.2 Migrasi Supabase (dijalankan user di SQL Editor, berurutan)

1. **Cadangkan dulu**: Table Editor → Export CSV untuk 4 tabel, dan salin file `sf_daily_recap.db` dari HP.
2. Pasang build app baru dari 1.1 (sync-nya sudah toleran).
3. Jalankan `supabase/migrations/20261021_01_fase1A_fuel_dan_user_id.sql` (**Lampiran A**). Aman, hanya menambah.
4. Buat akun email sendiri (Dashboard → Authentication → Users → Add user), salin **UID**.
5. Edit **Lampiran B** (`..._02_fase1B_backfill_pemilik.sql`): ganti `GANTI-DENGAN-UID-AKUN-EMAIL-KAMU` dengan UID itu, jalankan. Lalu pastikan tidak ada yang NULL:
   `select count(*) from daily_recap where user_id is null;` (ulangi untuk 4 tabel lain) → semuanya 0.
6. Login di app dengan akun email tadi dan pastikan sync berhasil.
7. Jalankan **Lampiran C** (`..._03_fase1C_kunci_akses.sql`). Langkah ini gagal bila masih ada `user_id` NULL, dan itu disengaja.
8. Dashboard → Authentication → Sign In / Providers: **matikan "Allow anonymous sign-ins"** dan **matikan "Allow new users to sign up"**.
9. Perbarui `supabase/schema.sql` menjadi keadaan akhir untuk instalasi bersih: tambahkan `fuel_fillings`, `user_id`, kebijakan `owner_only`, dan ubah definisi view menjadi `create or replace view daily_recap_summary with (security_invoker = true) as ...`. Tambahkan juga komentar: *setiap `create or replace view` menghapus opsi security_invoker; selalu akhiri dengan `alter view ... set (security_invoker = true);`*.

### 1.3 Kriteria selesai Fase 1
- [ ] Instalasi baru (hapus app, pasang ulang, login) bisa menambah pengisian BBM tanpa error.
- [ ] Pengisian BBM muncul di tabel `fuel_fillings` Supabase dan kembali setelah app dipasang ulang.
- [ ] Akun lain / sesi anonim tidak bisa membaca tabel maupun `daily_recap_summary` (uji dengan dua akun).
- [ ] Sync tidak error walau salah satu tabel gagal; error tampil ringkas.
- [ ] Sync menarik >1000 baris `daily_order` dengan benar (uji dengan data dummy bila perlu).

## 4. FASE 2 — Skema baru (Supabase + SQLite)

1. Salin **Lampiran D** ke `supabase/migrations/20261021_04_fase2_ledger_kendaraan.sql`; user menjalankannya setelah Fase 1C. Tabel: `accounts`, `vehicles`, `vehicle_logs`, `transactions`, `service_items`, `service_records`, kolom `fuel_fillings.vehicle_id`, view `v_account_balance`, `v_pool_balance` (keduanya `security_invoker`). Semua punya RLS pemilik+non-anonim dan trigger `updated_at`.
2. SQLite: `ledger_schema.dart` (Lampiran E) sudah dipakai oleh `LocalDb` di Fase 1. Pastikan view SQLite `v_account_balance` dan `v_pool_balance` ikut dibuat.
3. Tambahkan tabel baru ke daftar sync (Lampiran H) dengan urutan push yang menghormati foreign key:
   `accounts → vehicles → daily_recap → daily_order → petty_cash_item → daily_extra → fuel_fillings → vehicle_logs → service_items → transactions → service_records`.
4. Salin `test/ledger_db_test.dart` (Lampiran G2). Test ini menjalankan skema SQLite di memori dan memeriksa saldo.

Aturan data (sudah dipaksa oleh constraint, jangan dilonggarkan):
- `amount > 0`; jenis `income|expense|transfer`.
- Transfer wajib punya `to_account_id` dan `to_pool`, serta berbeda rekening **atau** berbeda kas; transfer selalu `cleared`.
- Non-transfer tidak boleh punya `to_account_id`/`to_pool`.
- `service_items` wajib punya minimal satu interval (km atau hari). **Angka interval selalu diisi user** (buku servis / Yamaha Motor On). Jangan pernah mengisi default interval.
- Jangan menyimpan plat nomor lengkap (`plate_hint` hanya petunjuk, mis. 4 digit akhir).

## 5. FASE 3 — Model, service, provider

Letakkan logika murni di `lib/logic/ledger_math.dart` (Lampiran F, salin persis) dan test di `test/ledger_math_test.dart` (Lampiran G1). **Semua perhitungan angka (alokasi biaya, profit, status servis) harus lewat file itu**, bukan ditulis ulang di widget.

### 3.1 Model (`lib/models/`, gaya sama dengan `fuel_filling.dart`: `fromMap`, `toMap`, `copyWith`, `create` dengan `Uuid().v4()`)
- `Account`: id, name, kind(`cash|bank|ewallet`), openingBalance(int), isActive, sortOrder, createdAt, updatedAt, deletedAt.
- `Vehicle`: id, name, plateHint?, odoInitial(double), isActive, …
- `VehicleLog`: id, vehicleId, tanggal, odoEnd, kmKanvasing, kmOjol, kmPribadi, jamOnlineOjol?, note?.
- `LedgerTransaction`: id, tanggal, kind, amount(int), accountId, toAccountId?, pool, toPool?, activity, category?, vehicleId?, fuelFillingId?, status, note?.
- `ServiceItem`: id, vehicleId, name, intervalKm?, intervalDays?, lastServiceDate?, lastServiceOdo?.
- `ServiceRecord`: id, vehicleId, serviceItemId?, tanggal, odometer?, cost(int), shop?, note?, transactionId?.
- Konversi `is_active` SQLite `int` ↔ `bool`. Tanggal disimpan `YYYY-MM-DD`, timestamp ISO8601.

### 3.2 Service (`lib/services/ledger_service.dart`, gaya sama dengan `RecapService`)
Setiap tulis: set `updated_at = now`, `is_synced = 0`, lalu `Future.microtask(() => SyncService.sync())`. Hapus = isi `deleted_at` (bukan hapus baris). Semua query membuang baris `deleted_at IS NOT NULL`.

Akun & kas:
- `getAccounts()`, `saveAccount()`, `archiveAccount()` (is_active=false; rekening yang punya transaksi tidak boleh di-soft-delete).
- `getAccountBalances()` dari view `v_account_balance`; `getPoolBalances()` dari `v_pool_balance` (default `utama` dan `tambahan` = 0 bila tidak ada baris).
- `addTransaction(LedgerTransaction)` memvalidasi bentuk (sama dengan constraint) **sebelum** insert dan melempar `ArgumentError` berpesan Indonesia.
- `updateTransaction`, `softDeleteTransaction`, `markCleared(id)` (pending → cleared, tanggal tetap).
- `getTransactions({range, accountId, pool, activity, kind, status})` terurut `tanggal DESC, created_at DESC`.
- `reconcile(accountId, actualBalance)`: hitung selisih dengan saldo buku; jika ≠ 0, buat transaksi penyesuaian (selisih > 0 → `income`, < 0 → `expense`), `activity='pribadi'`, `category='penyesuaian saldo'`, `pool` mengikuti kas default rekening, `note` berisi saldo buku dan saldo aktual. Kembalikan selisihnya.

Kendaraan & servis:
- `getVehicles()`, `saveVehicle()`.
- `saveVehicleLog()` meng-upsert per `(vehicle_id, tanggal)` (unik). Validasi: `odo_end` tidak boleh lebih kecil dari log sebelumnya (tampilkan konfirmasi, jangan blok diam-diam); bila ada log sebelumnya dan `km_kanvasing+km_ojol+km_pribadi` ≠ selisih odometer, UI menawarkan "sisanya masuk Pribadi".
- `currentOdometer(vehicleId)` = `odo_end` log terbaru, fallback `odo_initial`.
- `getServiceItems(vehicleId)`, `saveServiceItem()`, `serviceDueList()` memakai `evaluateServiceItem` (urut: overdue, soon, ok, unknown).
- `recordService(...)` dalam **satu `db.transaction`**: insert `service_records`; bila `cost > 0` dan user memilih rekening, buat transaksi `expense` (`activity='kendaraan'`, `category='servis'`, `vehicle_id`) dan isi `transaction_id`; perbarui `service_items.last_service_date/odo` bila item dipilih.
- `recordFuel(...)`: lihat Fase 5.

Laporan (`lib/services/finance_report_service.dart`):
- `monthSummary(DateTime month, {String? vehicleId})` → `FinanceMonthSummary`:
  - transaksi cleared bulan itu → `LedgerTx` → `computeActivityProfits` dengan `allocateVehicleCost(totalCost: sumVehicleCost(txs), km dari vehicle_logs bulan itu)`;
  - `unallocatedVehicleCost` = total biaya kendaraan bila total km = 0 (tampilkan sebagai "belum teralokasi", jangan dibagi);
  - `pendingIncome` = `sumPendingIncome`;
  - `ojolIncomePerKm` dan `ojolIncomePerHour` memakai `perUnit` (null → tampil "-");
  - `biayaMotorPerKm` = total biaya kendaraan / total km;
  - `legacyOjolNetEarning` = jumlah `net_earning` dari `daily_recap_summary` pada bulan itu (hanya untuk ditampilkan terpisah).

### 3.3 Provider (`lib/providers/finance_providers.dart`, gaya Riverpod 3 yang sama dengan `recap_providers.dart`)
`ledgerServiceProvider`, `financeReportServiceProvider`, `accountsProvider`, `accountBalancesProvider`, `poolBalancesProvider`, `vehiclesProvider`, `serviceDueProvider`, `financeMonthProvider` (`Notifier<DateTime>`, awal = bulan ini), `monthSummaryProvider` (watch `financeMonthProvider`), `transactionsProvider.family`. Setelah setiap tulis lakukan `ref.invalidate(...)` untuk provider terkait (saldo, ringkasan, daftar).

### 3.4 Kriteria selesai Fase 3
- [ ] `flutter test` hijau, termasuk `ledger_math_test.dart` dan `ledger_db_test.dart`.
- [ ] Menambah transaksi dengan bentuk salah ditolak di service (pesan Indonesia), bukan hanya oleh constraint database.
- [ ] Soft delete transaksi mengurangi saldo; transaksi `pending` tidak menambah saldo.

## 6. FASE 4 — Antarmuka

Gaya: Material 3, seed hijau `0xFF2E7D32`, `GoogleFonts.plusJakartaSans`, bottom sheet berbentuk seperti `fuel_filling_sheet.dart`, format uang memakai `currency` yang sudah ada di `home_screen.dart` (locale `id_ID`, tanpa desimal). Semua teks Indonesia. Setiap daftar punya keadaan kosong, loading, dan error dengan tombol "Coba Lagi".

### 4.1 Navigasi
Tambahkan tab **Keuangan** di `home_screen.dart` pada **indeks 3** (Profil bergeser ke 4). Aman: pemanggilan `homeTabProvider.change(2)` di dashboard (menuju Laporan) tidak terpengaruh. Perbarui ternary judul AppBar.

`lib/screens/finance/finance_home_screen.dart`: `TabBar` dengan 4 tab — **Ringkasan | Transaksi | Rekening | Motor**; tiap tab punya FAB sendiri.

### 4.2 Ringkasan
- Pemilih bulan (`financeMonthProvider`), tombol sebelumnya/berikutnya.
- Kartu **Saldo Kas**: Utama dan Tambahan, plus **Total semua rekening**.
- Kartu **Profit per pekerjaan** (kanvasing, ojol, pribadi) = pemasukan − pengeluaran langsung − alokasi biaya motor. Beri ikon info yang menjelaskan alokasi. Bila `unallocatedVehicleCost > 0`, tampilkan baris "Biaya motor belum teralokasi (km belum diisi)".
- Kartu **Komisi belum cair** (`pendingIncome`) dengan tombol "Tandai cair" per item.
- Kartu **Efisiensi**: biaya motor per km, pendapatan ojol per km dan per jam (hanya bila datanya ada).
- Baris terpisah berlabel **"Ojol (Rekap Harian lama)"** menampilkan `legacyOjolNetEarning`. Jangan dijumlahkan dengan profit ojol dari ledger.
- Kartu **Servis**: tampilkan item `overdue`/`soon` per motor; ketuk → tab Motor.
- Tiga aksi cepat: **Catat komisi**, **Catat BBM**, **Km hari ini**.

### 4.3 Transaksi
- Daftar dikelompokkan per tanggal; filter rekening, kas, aktivitas, jenis, status (chip). Geser untuk hapus (soft delete) dengan SnackBar "Urungkan".
- `transaction_form_sheet.dart`: pilih jenis (SegmentedButton: Pemasukan / Pengeluaran / Transfer).
  - Pemasukan/pengeluaran: nominal, tanggal, rekening, kas, aktivitas, kategori (autocomplete dari kategori yang pernah dipakai), motor (hanya bila aktivitas `kendaraan`), catatan, switch **"Belum cair"** (hanya pemasukan).
  - Transfer: nominal, tanggal, dari rekening + kas, ke rekening + kas, catatan. Larang tujuan = sumber.
  - Default cerdas: ingat rekening, kas, aktivitas, dan motor terakhir (`shared_preferences`).
  - Input nominal: hanya angka, tampil dengan pemisah ribuan titik, disimpan `int`; tolak 0 dan negatif.

### 4.4 Rekening
- Daftar rekening dengan saldo (dari `v_account_balance`), dikelompokkan Tunai / Bank / E-wallet; total di atas.
- Tambah/ubah rekening: nama panggilan, jenis, saldo awal. **Tidak ada kolom nomor rekening/kartu.**
- Aksi **Cek saldo**: user memasukkan saldo asli dari aplikasi bank/e-wallet; tampilkan selisih terhadap saldo buku; tombol "Catat penyesuaian" memanggil `reconcile`.
- Arsip rekening (sembunyikan dari pilihan, riwayat tetap).

### 4.5 Motor
- Daftar motor (Jupiter Z, Aerox) sebagai kartu; ketuk → detail.
- Detail motor: odometer terakhir, tombol **Km hari ini** (`vehicle_log_sheet.dart`: odometer akhir, km kanvasing, km ojol, km pribadi, jam online ojol, catatan; tampilkan selisih terhadap odometer sebelumnya dan tawarkan "sisanya ke Pribadi").
- Bagian **Servis berkala**: daftar item dengan status berwarna (hijau/kuning/merah/abu) dan sisa km/hari. Tambah item (nama + interval km dan/atau hari, **diisi user**); tombol **Catat servis** (`recordService`).
- Riwayat servis dan pengisian BBM motor tersebut.
- Seed awal: bila belum ada motor, tawarkan membuat "Jupiter Z" dan "Aerox" dengan satu ketukan (odometer awal diisi user). **Jangan** membuat item servis otomatis.

### 4.6 Dashboard lama
Tambahkan dua kartu kecil di `dashboard_screen.dart` (setelah memeriksa strukturnya): "Saldo Kas" (utama/tambahan) dan "Servis jatuh tempo", masing-masing memanggil `homeTabProvider.notifier.change(3)`.

### 4.7 Kriteria selesai Fase 4
- [ ] Skenario di bagian 8 menghasilkan angka yang sama persis di layar.
- [ ] Tidak ada overflow pada layar sempit (360 dp) dan mode gelap tidak rusak.
- [ ] Semua form menolak input tidak valid dengan pesan Indonesia.

## 7. FASE 5 — BBM terintegrasi

Ubah `fuel_filling_sheet.dart` dan `RecapService`/`LedgerService`:
- Tambah dropdown **Motor** (wajib bila ada motor) dan section **"Catat di Keuangan"** (switch, default aktif): rekening pembayar dan kas (default `utama`).
- Bila aktif, simpan pengisian BBM **dan** transaksi `expense` (`activity='kendaraan'`, `category='bbm'`, `fuel_filling_id`, `vehicle_id`, `amount = total_biaya`) dalam **satu `db.transaction`**.
- Edit pengisian → perbarui transaksi tertaut; hapus pengisian → soft delete transaksi tertaut.
- Tampilkan di detail motor: liter terakhir, km per liter antar pengisian penuh (hanya bila odometer dua pengisian ada; jangan menebak).
- Biarkan `daily_recap.kml_parameter` dan view telemetri lama apa adanya.

## 8. Angka uji (skenario akhir — layar harus sama persis)

Data awal: Tunai Rp100.000 (cash), BCA Rp500.000 (bank), Dana Rp0 (ewallet).
Transaksi (semua 2 Okt 2026):

| # | Jenis | Nominal | Rekening | Kas | Aktivitas | Status |
|---|---|---|---|---|---|---|
| 1 | Pemasukan | 300.000 | BCA | utama | kanvasing (komisi) | cleared |
| 2 | Pemasukan | 200.000 | BCA | utama | kanvasing (komisi) | **pending** |
| 3 | Pengeluaran | 20.000 | Tunai | utama | kendaraan (bbm) | cleared |
| 4 | Pemasukan | 150.000 | Dana | tambahan | ojol | cleared |
| 5 | Transfer | 100.000 | Dana (tambahan) → BCA (utama) | | | cleared |

Hasil yang benar:
- Saldo rekening: **Tunai 80.000 · BCA 900.000 · Dana 50.000**.
- Saldo kas: **utama 380.000 · tambahan 50.000**.
- Komisi belum cair: **200.000**.
- Soft delete transaksi #1 → BCA **600.000**.
- Tambah servis (kendaraan) 60.000 → total biaya kendaraan **80.000**; km bulan itu kanvasing 60 / ojol 30 / pribadi 10 → alokasi **48.000 / 24.000 / 8.000**; profit kanvasing **252.000**, ojol (ledger) **126.000**, pribadi **−8.000**.
- Alokasi 100.000 dengan km 1/1/1 → **33.334 / 33.333 / 33.333**.
- Contoh servis (angka hanya untuk uji, bukan rekomendasi): interval 3.000 km, servis terakhir pada 10.000 km: odometer 11.000 → hijau (sisa 2.000); 12.500 → kuning (sisa 500); 13.100 → merah (−100). Interval 90 hari, terakhir 1 Agu 2026, hari ini 21 Okt 2026 → kuning (sisa 9 hari).

## 9. FASE 6 — Penutup (opsional tapi disarankan)
- Ekspor CSV transaksi per bulan dan tombol **Cadangkan database** (bagikan file `sf_daily_recap.db`) di tab Profil.
- Di `.github/workflows/flutter_ci.yml` hapus `|| true` pada langkah *Analyze* setelah semua warning diperbaiki, agar CI benar-benar gagal bila ada masalah.
- Perbarui `README.md`: struktur proyek, urutan migrasi, cara membuat akun, dan catatan bahwa `.env` hanya boleh berisi `SUPABASE_URL` dan anon key.

## 10. Di luar cakupan (JANGAN dikerjakan sekarang)
- Migrasi wallet lama (ShopeeFood/Grab/Mandiri/BCA) ke `accounts` (Opsi B).
- Integrasi otomatis dengan Yamaha Motor On, OBD/ELM327, atau pelacakan GPS.
- Penyimpanan nomor rekening/kartu, impor mutasi bank.
- Mengubah rumus rekap harian yang ada.

## 11. Urutan commit yang disarankan
1. `fix(sync): fuel_fillings, filter kolom pull, paginasi, isolasi error per tabel` + `fix(db): fuel_fillings pada onCreate (v11)`
2. `fix(auth): hapus login anonim dan pendaftaran publik` + migrasi SQL Fase 1 + `schema.sql` final
3. `feat(db): skema ledger/kendaraan v11 + view saldo`
4. `feat(logic): ledger_math + test`
5. `feat(ledger): model, service, provider, sync`
6. `feat(ui): tab Keuangan (Ringkasan, Transaksi, Rekening, Motor)`
7. `feat(fuel): BBM terhubung ke ledger`


---

# LAMPIRAN (kode siap salin)

Semua SQL di bawah sudah dijalankan berurutan pada PostgreSQL 16 (dengan stub `auth`) di atas `supabase/schema.sql` repo, dan versi SQLite diuji di SQLite 3.45 terhadap baseline yang dibangun dari `local_db.dart` asli.

### Lampiran A — Fase 1A (tambahan aman)
Salin ke: `supabase/migrations/20261021_01_fase1A_fuel_dan_user_id.sql`

```sql
-- =====================================================================
-- FASE 1A — tambahan aman (boleh dijalankan kapan saja, data lama tidak berubah)
-- =====================================================================

-- 1. Tabel fuel_fillings di server (sebelumnya hanya ada di SQLite lokal)
create table if not exists fuel_fillings (
  id uuid primary key,
  daily_recap_id uuid not null references daily_recap(id) on delete cascade,
  tanggal date not null,
  liter numeric(10,2) not null,
  harga_per_liter numeric(14,2) not null default 0,
  total_biaya numeric(14,2) not null default 0,
  odometer numeric(14,2),
  catatan text,
  created_at timestamptz not null default now()
);
create index if not exists idx_fuel_fillings_recap on fuel_fillings(daily_recap_id);
create index if not exists idx_fuel_fillings_tanggal on fuel_fillings(tanggal);
alter table fuel_fillings enable row level security;

-- 2. Kolom pemilik data (user_id) di semua tabel lama
alter table daily_recap      add column if not exists user_id uuid references auth.users(id) on delete cascade default auth.uid();
alter table daily_order      add column if not exists user_id uuid references auth.users(id) on delete cascade default auth.uid();
alter table petty_cash_item  add column if not exists user_id uuid references auth.users(id) on delete cascade default auth.uid();
alter table daily_extra      add column if not exists user_id uuid references auth.users(id) on delete cascade default auth.uid();
alter table fuel_fillings    add column if not exists user_id uuid references auth.users(id) on delete cascade default auth.uid();
```

### Lampiran B — Fase 1B (backfill pemilik, JALANKAN SEKALI)
Salin ke: `supabase/migrations/20261021_02_fase1B_backfill_pemilik.sql`

Ganti `GANTI-DENGAN-UID-AKUN-EMAIL-KAMU` dengan UID akun email user sebelum dijalankan.

```sql
-- =====================================================================
-- FASE 1B — backfill pemilik data (JALANKAN SEKALI, ganti UID dulu)
-- UID = id akun email kamu: Supabase Dashboard -> Authentication -> Users
-- =====================================================================
update daily_recap set user_id = 'GANTI-DENGAN-UID-AKUN-EMAIL-KAMU' where user_id is null;

update daily_order     x set user_id = r.user_id from daily_recap r where x.daily_recap_id = r.id and x.user_id is null;
update petty_cash_item x set user_id = r.user_id from daily_recap r where x.daily_recap_id = r.id and x.user_id is null;
update daily_extra     x set user_id = r.user_id from daily_recap r where x.daily_recap_id = r.id and x.user_id is null;
update fuel_fillings   x set user_id = r.user_id from daily_recap r where x.daily_recap_id = r.id and x.user_id is null;
```

### Lampiran C — Fase 1C (kunci akses)
Salin ke: `supabase/migrations/20261021_03_fase1C_kunci_akses.sql`

```sql
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
```

### Lampiran D — Fase 2 (ledger, kendaraan, servis)
Salin ke: `supabase/migrations/20261021_04_fase2_ledger_kendaraan.sql`

Tabel dibuat setelah Fase 1C. Memakai fungsi `set_updated_at()` yang sudah ada di `supabase/schema.sql`.

```sql
-- =====================================================================
-- FASE 2 — tabel baru: rekening, kendaraan, transaksi (ledger), servis
-- Uang di tabel baru = BILANGAN BULAT RUPIAH (bigint), bukan numeric/REAL.
-- Semua tabel punya user_id (diisi otomatis auth.uid()), RLS pemilik saja, dan soft delete (deleted_at).
-- Butuh fungsi set_updated_at() yang sudah ada di supabase/schema.sql.
-- =====================================================================

create table if not exists accounts (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,
  kind text not null check (kind in ('cash','bank','ewallet')),
  opening_balance bigint not null default 0,
  is_active boolean not null default true,
  sort_order int not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

create table if not exists vehicles (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  name text not null,                       -- contoh: 'Aerox', 'Jupiter Z'
  plate_hint text,                          -- opsional, JANGAN simpan plat lengkap
  odo_initial numeric(12,1) not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- BBM bisa ditautkan ke motor (relasi ke ledger hanya lewat transactions.fuel_filling_id, supaya tidak melingkar)
alter table fuel_fillings add column if not exists vehicle_id uuid references vehicles(id) on delete set null;

-- Satu baris per motor per hari: odometer akhir + pembagian km per aktivitas
create table if not exists vehicle_logs (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  tanggal date not null,
  odo_end numeric(12,1) not null,
  km_kanvasing numeric(10,1) not null default 0 check (km_kanvasing >= 0),
  km_ojol      numeric(10,1) not null default 0 check (km_ojol >= 0),
  km_pribadi   numeric(10,1) not null default 0 check (km_pribadi >= 0),
  jam_online_ojol numeric(5,2),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  unique (vehicle_id, tanggal)
);

-- Ledger: pemasukan, pengeluaran, transfer
--   pool  = kas mana (utama = kanvasing, tambahan = ojol)
--   account_id = disimpan di rekening mana (sumber, untuk transfer)
--   status 'pending' = komisi belum cair (tidak masuk saldo sampai jadi 'cleared')
--   activity 'kendaraan' = biaya motor bersama, dialokasikan ke kanvasing/ojol/pribadi menurut km (dihitung di app)
create table if not exists transactions (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  tanggal date not null,
  kind text not null check (kind in ('income','expense','transfer')),
  amount bigint not null check (amount > 0),
  account_id uuid not null references accounts(id),
  to_account_id uuid references accounts(id),
  pool text not null default 'utama' check (pool in ('utama','tambahan')),
  to_pool text check (to_pool in ('utama','tambahan')),
  activity text not null default 'kanvasing' check (activity in ('kanvasing','ojol','pribadi','kendaraan')),
  category text,
  vehicle_id uuid references vehicles(id),
  fuel_filling_id uuid references fuel_fillings(id) on delete set null,
  status text not null default 'cleared' check (status in ('cleared','pending')),
  note text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint tx_transfer_shape check (
    (kind = 'transfer' and to_account_id is not null and to_pool is not null
       and (to_account_id <> account_id or to_pool <> pool))
    or (kind <> 'transfer' and to_account_id is null and to_pool is null)
  ),
  constraint tx_transfer_cleared check (kind <> 'transfer' or status = 'cleared')
);
create index if not exists idx_tx_tanggal on transactions(tanggal) where deleted_at is null;
create index if not exists idx_tx_account on transactions(account_id);
create index if not exists idx_logs_vehicle_tanggal on vehicle_logs(vehicle_id, tanggal);

-- Item servis berkala. Interval DIISI USER (dari buku servis / Yamaha Motor On); app tidak menebak angka.
create table if not exists service_items (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  name text not null,
  interval_km int check (interval_km is null or interval_km > 0),
  interval_days int check (interval_days is null or interval_days > 0),
  last_service_date date,
  last_service_odo numeric(12,1),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz,
  constraint si_has_interval check (interval_km is not null or interval_days is not null)
);

create table if not exists service_records (
  id uuid primary key,
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  vehicle_id uuid not null references vehicles(id) on delete cascade,
  service_item_id uuid references service_items(id) on delete set null,
  tanggal date not null,
  odometer numeric(12,1),
  cost bigint not null default 0 check (cost >= 0),
  shop text,
  note text,
  transaction_id uuid references transactions(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  deleted_at timestamptz
);

-- Trigger updated_at
create trigger trg_accounts_updated_at before update on accounts for each row execute function set_updated_at();
create trigger trg_vehicles_updated_at before update on vehicles for each row execute function set_updated_at();
create trigger trg_vehicle_logs_updated_at before update on vehicle_logs for each row execute function set_updated_at();
create trigger trg_transactions_updated_at before update on transactions for each row execute function set_updated_at();
create trigger trg_service_items_updated_at before update on service_items for each row execute function set_updated_at();
create trigger trg_service_records_updated_at before update on service_records for each row execute function set_updated_at();

-- RLS
alter table accounts enable row level security;
alter table vehicles enable row level security;
alter table vehicle_logs enable row level security;
alter table transactions enable row level security;
alter table service_items enable row level security;
alter table service_records enable row level security;
create policy owner_only on accounts for all to authenticated
  using      ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
create policy owner_only on vehicles for all to authenticated
  using      ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
create policy owner_only on vehicle_logs for all to authenticated
  using      ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
create policy owner_only on transactions for all to authenticated
  using      ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
create policy owner_only on service_items for all to authenticated
  using      ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);
create policy owner_only on service_records for all to authenticated
  using      ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false)
  with check ((select auth.uid()) = user_id and coalesce((select auth.jwt() ->> 'is_anonymous')::boolean, false) = false);

-- Saldo per rekening (hanya transaksi 'cleared' dan belum dihapus)
create or replace view v_account_balance with (security_invoker = true) as
with mv as (
  select account_id as acc, case kind when 'income' then amount else -amount end as delta
    from transactions where deleted_at is null and status = 'cleared'
  union all
  select to_account_id, amount
    from transactions where deleted_at is null and status = 'cleared' and kind = 'transfer'
)
select a.id as account_id, a.user_id, a.name, a.kind, a.opening_balance,
       (a.opening_balance + coalesce(sum(mv.delta), 0))::bigint as balance
from accounts a
left join mv on mv.acc = a.id
where a.deleted_at is null
group by a.id;

-- Saldo per kas (utama / tambahan). Transfer memindahkan dari pool ke to_pool.
create or replace view v_pool_balance with (security_invoker = true) as
with mv as (
  select user_id, pool, case kind when 'income' then amount else -amount end as delta
    from transactions where deleted_at is null and status = 'cleared'
  union all
  select user_id, to_pool, amount
    from transactions where deleted_at is null and status = 'cleared' and kind = 'transfer'
)
select user_id, pool, sum(delta)::bigint as balance
from mv group by user_id, pool;
```

### Lampiran E — Skema SQLite v11 (hasil generate, salin persis)
Salin ke: `lib/services/ledger_schema.dart`

```dart
// GENERATED dari panduan Agy — skema SQLite v11 untuk modul Keuangan & Kendaraan.
// Dipakai oleh LocalDb (onCreate dan onUpgrade oldVersion < 11) dan oleh test/ledger_db_test.dart.
// sqflite hanya menjalankan SATU statement per execute(), karena itu berupa daftar.

const List<String> ledgerSchemaStatements = <String>[
  r'''
CREATE TABLE IF NOT EXISTS accounts (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('cash','bank','ewallet')),
  opening_balance INTEGER NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  sort_order INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  is_synced INTEGER NOT NULL DEFAULT 0
)
''',
  r'''
CREATE TABLE IF NOT EXISTS vehicles (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  plate_hint TEXT,
  odo_initial REAL NOT NULL DEFAULT 0,
  is_active INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  is_synced INTEGER NOT NULL DEFAULT 0
)
''',
  r'''
CREATE TABLE IF NOT EXISTS vehicle_logs (
  id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  tanggal TEXT NOT NULL,
  odo_end REAL NOT NULL,
  km_kanvasing REAL NOT NULL DEFAULT 0 CHECK (km_kanvasing >= 0),
  km_ojol REAL NOT NULL DEFAULT 0 CHECK (km_ojol >= 0),
  km_pribadi REAL NOT NULL DEFAULT 0 CHECK (km_pribadi >= 0),
  jam_online_ojol REAL,
  note TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  is_synced INTEGER NOT NULL DEFAULT 0,
  UNIQUE (vehicle_id, tanggal)
)
''',
  r'''
CREATE TABLE IF NOT EXISTS transactions (
  id TEXT PRIMARY KEY,
  tanggal TEXT NOT NULL,
  kind TEXT NOT NULL CHECK (kind IN ('income','expense','transfer')),
  amount INTEGER NOT NULL CHECK (amount > 0),
  account_id TEXT NOT NULL,
  to_account_id TEXT,
  pool TEXT NOT NULL DEFAULT 'utama' CHECK (pool IN ('utama','tambahan')),
  to_pool TEXT CHECK (to_pool IN ('utama','tambahan')),
  activity TEXT NOT NULL DEFAULT 'kanvasing' CHECK (activity IN ('kanvasing','ojol','pribadi','kendaraan')),
  category TEXT,
  vehicle_id TEXT,
  fuel_filling_id TEXT,
  status TEXT NOT NULL DEFAULT 'cleared' CHECK (status IN ('cleared','pending')),
  note TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  is_synced INTEGER NOT NULL DEFAULT 0,
  CHECK (
    (kind = 'transfer' AND to_account_id IS NOT NULL AND to_pool IS NOT NULL
       AND (to_account_id <> account_id OR to_pool <> pool))
    OR (kind <> 'transfer' AND to_account_id IS NULL AND to_pool IS NULL)
  ),
  CHECK (kind <> 'transfer' OR status = 'cleared')
)
''',
  r'''
CREATE INDEX IF NOT EXISTS idx_tx_tanggal ON transactions(tanggal)
''',
  r'''
CREATE INDEX IF NOT EXISTS idx_tx_account ON transactions(account_id)
''',
  r'''
CREATE TABLE IF NOT EXISTS service_items (
  id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  name TEXT NOT NULL,
  interval_km INTEGER CHECK (interval_km IS NULL OR interval_km > 0),
  interval_days INTEGER CHECK (interval_days IS NULL OR interval_days > 0),
  last_service_date TEXT,
  last_service_odo REAL,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  is_synced INTEGER NOT NULL DEFAULT 0,
  CHECK (interval_km IS NOT NULL OR interval_days IS NOT NULL)
)
''',
  r'''
CREATE TABLE IF NOT EXISTS service_records (
  id TEXT PRIMARY KEY,
  vehicle_id TEXT NOT NULL,
  service_item_id TEXT,
  tanggal TEXT NOT NULL,
  odometer REAL,
  cost INTEGER NOT NULL DEFAULT 0 CHECK (cost >= 0),
  shop TEXT,
  note TEXT,
  transaction_id TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL,
  deleted_at TEXT,
  is_synced INTEGER NOT NULL DEFAULT 0
)
''',
  r'''
DROP VIEW IF EXISTS v_account_balance
''',
  r'''
CREATE VIEW v_account_balance AS
WITH mv AS (
  SELECT account_id AS acc, CASE kind WHEN 'income' THEN amount ELSE -amount END AS delta
    FROM transactions WHERE deleted_at IS NULL AND status = 'cleared'
  UNION ALL
  SELECT to_account_id, amount
    FROM transactions WHERE deleted_at IS NULL AND status = 'cleared' AND kind = 'transfer'
)
SELECT a.id AS account_id, a.name, a.kind, a.opening_balance,
       a.opening_balance + COALESCE(SUM(mv.delta), 0) AS balance
FROM accounts a
LEFT JOIN mv ON mv.acc = a.id
WHERE a.deleted_at IS NULL
GROUP BY a.id
''',
  r'''
DROP VIEW IF EXISTS v_pool_balance
''',
  r'''
CREATE VIEW v_pool_balance AS
WITH mv AS (
  SELECT pool, CASE kind WHEN 'income' THEN amount ELSE -amount END AS delta
    FROM transactions WHERE deleted_at IS NULL AND status = 'cleared'
  UNION ALL
  SELECT to_pool, amount
    FROM transactions WHERE deleted_at IS NULL AND status = 'cleared' AND kind = 'transfer'
)
SELECT pool, SUM(delta) AS balance FROM mv GROUP BY pool
''',
];
```

### Lampiran F — Logika murni
Salin ke: `lib/logic/ledger_math.dart`

Alokasi biaya motor, profit per aktivitas, dan status servis. Semua angka laporan harus lewat file ini.

```dart
// Logika murni (tanpa database/UI) untuk modul Keuangan & Kendaraan.
// Semua uang = int rupiah. Semua fungsi di sini harus punya unit test (test/ledger_math_test.dart).

const List<String> kActivityOrder = <String>['kanvasing', 'ojol', 'pribadi'];

/// Alokasi biaya kendaraan bersama (activity 'kendaraan') ke kanvasing/ojol/pribadi menurut km.
/// Metode sisa terbesar: jumlah hasil SELALU sama dengan [totalCost].
/// Seri dipecah dengan urutan kanvasing, ojol, pribadi.
/// Jika total km <= 0 atau totalCost <= 0, semua 0 (pemanggil menampilkan biaya itu sebagai "belum teralokasi").
Map<String, int> allocateVehicleCost({
  required int totalCost,
  required double kmKanvasing,
  required double kmOjol,
  required double kmPribadi,
}) {
  final kms = <double>[kmKanvasing, kmOjol, kmPribadi];
  final result = <String, int>{for (final a in kActivityOrder) a: 0};

  var kmTotal = 0.0;
  for (final k in kms) {
    if (k > 0) kmTotal += k;
  }
  if (totalCost <= 0 || kmTotal <= 0) return result;

  final floors = List<int>.filled(3, 0);
  final fracs = List<double>.filled(3, 0);
  var assigned = 0;
  for (var i = 0; i < 3; i++) {
    final km = kms[i] > 0 ? kms[i] : 0.0;
    final quota = totalCost * km / kmTotal;
    floors[i] = quota.floor();
    fracs[i] = quota - floors[i];
    assigned += floors[i];
  }

  var remainder = totalCost - assigned;
  final order = <int>[0, 1, 2];
  order.sort((a, b) {
    final c = fracs[b].compareTo(fracs[a]);
    return c != 0 ? c : a.compareTo(b);
  });
  for (var j = 0; j < order.length && remainder > 0; j++) {
    floors[order[j]] += 1;
    remainder -= 1;
  }

  for (var i = 0; i < 3; i++) {
    result[kActivityOrder[i]] = floors[i];
  }
  return result;
}

/// Baris ledger minimal untuk perhitungan laporan.
class LedgerTx {
  final String kind; // income | expense | transfer
  final int amount;
  final String activity; // kanvasing | ojol | pribadi | kendaraan
  final String status; // cleared | pending

  const LedgerTx({
    required this.kind,
    required this.amount,
    required this.activity,
    this.status = 'cleared',
  });
}

class ActivityProfit {
  final int income;
  final int directExpense;
  final int allocatedVehicleCost;

  const ActivityProfit({
    this.income = 0,
    this.directExpense = 0,
    this.allocatedVehicleCost = 0,
  });

  int get profit => income - directExpense - allocatedVehicleCost;
}

/// Total biaya kendaraan bersama (activity 'kendaraan', hanya 'cleared').
int sumVehicleCost(List<LedgerTx> txs) {
  var total = 0;
  for (final t in txs) {
    if (t.kind == 'expense' && t.activity == 'kendaraan' && t.status == 'cleared') {
      total += t.amount;
    }
  }
  return total;
}

/// Komisi/pendapatan yang belum cair (status 'pending'), tidak masuk saldo.
int sumPendingIncome(List<LedgerTx> txs) {
  var total = 0;
  for (final t in txs) {
    if (t.kind == 'income' && t.status == 'pending') total += t.amount;
  }
  return total;
}

/// Profit per aktivitas. Transfer diabaikan. Hanya transaksi 'cleared' yang dihitung.
/// [allocatedVehicleCost] berasal dari [allocateVehicleCost].
Map<String, ActivityProfit> computeActivityProfits({
  required List<LedgerTx> txs,
  required Map<String, int> allocatedVehicleCost,
}) {
  final income = <String, int>{for (final a in kActivityOrder) a: 0};
  final expense = <String, int>{for (final a in kActivityOrder) a: 0};

  for (final t in txs) {
    if (t.status != 'cleared') continue;
    if (t.kind == 'income' && income.containsKey(t.activity)) {
      income[t.activity] = income[t.activity]! + t.amount;
    } else if (t.kind == 'expense' && expense.containsKey(t.activity)) {
      expense[t.activity] = expense[t.activity]! + t.amount;
    }
  }

  return <String, ActivityProfit>{
    for (final a in kActivityOrder)
      a: ActivityProfit(
        income: income[a]!,
        directExpense: expense[a]!,
        allocatedVehicleCost: allocatedVehicleCost[a] ?? 0,
      ),
  };
}

/// value / unit, atau null bila unit <= 0 (hindari pembagian nol di UI: tampilkan "-").
double? perUnit(num value, num unit) => unit <= 0 ? null : value / unit;

enum ServiceStatus { unknown, ok, soon, overdue }

class ServiceDue {
  final ServiceStatus status;
  final double? remainingKm;
  final int? remainingDays;

  const ServiceDue(this.status, {this.remainingKm, this.remainingDays});
}

/// Status reminder servis. Interval SELALU berasal dari input user (buku servis / Yamaha Motor On);
/// jangan pernah mengisi angka interval otomatis.
/// - overdue: sisa km atau sisa hari <= 0
/// - soon: sisa <= [soonRatio] x interval (default 20%)
/// - unknown: belum ada data servis terakhir untuk satuan yang punya interval
ServiceDue evaluateServiceItem({
  required int? intervalKm,
  required int? intervalDays,
  required DateTime? lastDate,
  required double? lastOdo,
  required double currentOdo,
  required DateTime today,
  double soonRatio = 0.2,
}) {
  double? remKm;
  int? remDays;

  if (intervalKm != null && lastOdo != null) {
    remKm = lastOdo + intervalKm - currentOdo;
  }
  if (intervalDays != null && lastDate != null) {
    final due = DateTime.utc(lastDate.year, lastDate.month, lastDate.day + intervalDays);
    final t = DateTime.utc(today.year, today.month, today.day);
    remDays = due.difference(t).inDays;
  }

  if (remKm == null && remDays == null) {
    return const ServiceDue(ServiceStatus.unknown);
  }

  const eps = 1e-9;
  final overdue = (remKm != null && remKm <= 0) || (remDays != null && remDays <= 0);
  if (overdue) {
    return ServiceDue(ServiceStatus.overdue, remainingKm: remKm, remainingDays: remDays);
  }

  final soon = (remKm != null && intervalKm != null && remKm <= intervalKm * soonRatio + eps) ||
      (remDays != null && intervalDays != null && remDays <= intervalDays * soonRatio + eps);
  return ServiceDue(
    soon ? ServiceStatus.soon : ServiceStatus.ok,
    remainingKm: remKm,
    remainingDays: remDays,
  );
}
```

### Lampiran G1 — Test logika
Salin ke: `test/ledger_math_test.dart`

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sf_daily_recap/logic/ledger_math.dart';

void main() {
  group('allocateVehicleCost', () {
    test('proporsional km, jumlah tepat', () {
      final r = allocateVehicleCost(totalCost: 80000, kmKanvasing: 60, kmOjol: 30, kmPribadi: 10);
      expect(r, {'kanvasing': 48000, 'ojol': 24000, 'pribadi': 8000});
    });

    test('sepertiga: sisa 1 rupiah ke kanvasing (urutan seri)', () {
      final r = allocateVehicleCost(totalCost: 100000, kmKanvasing: 1, kmOjol: 1, kmPribadi: 1);
      expect(r, {'kanvasing': 33334, 'ojol': 33333, 'pribadi': 33333});
      expect(r.values.reduce((a, b) => a + b), 100000);
    });

    test('sisa terbesar ke pecahan terbesar', () {
      final r = allocateVehicleCost(totalCost: 50001, kmKanvasing: 3, kmOjol: 3, kmPribadi: 4);
      expect(r, {'kanvasing': 15000, 'ojol': 15000, 'pribadi': 20001});
    });

    test('km nol di satu aktivitas', () {
      final r = allocateVehicleCost(totalCost: 1000, kmKanvasing: 1, kmOjol: 2, kmPribadi: 0);
      expect(r, {'kanvasing': 333, 'ojol': 667, 'pribadi': 0});
    });

    test('total km nol atau biaya nol -> semua 0 (tidak error)', () {
      expect(allocateVehicleCost(totalCost: 100000, kmKanvasing: 0, kmOjol: 0, kmPribadi: 0),
          {'kanvasing': 0, 'ojol': 0, 'pribadi': 0});
      expect(allocateVehicleCost(totalCost: 0, kmKanvasing: 1, kmOjol: 1, kmPribadi: 1),
          {'kanvasing': 0, 'ojol': 0, 'pribadi': 0});
    });
  });

  group('computeActivityProfits', () {
    test('profit per pekerjaan (komisi pending tidak dihitung)', () {
      final txs = <LedgerTx>[
        const LedgerTx(kind: 'income', amount: 300000, activity: 'kanvasing'),
        const LedgerTx(kind: 'income', amount: 200000, activity: 'kanvasing', status: 'pending'),
        const LedgerTx(kind: 'income', amount: 150000, activity: 'ojol'),
        const LedgerTx(kind: 'expense', amount: 20000, activity: 'kendaraan'),
        const LedgerTx(kind: 'expense', amount: 60000, activity: 'kendaraan'),
        const LedgerTx(kind: 'transfer', amount: 100000, activity: 'pribadi'),
      ];
      expect(sumVehicleCost(txs), 80000);
      expect(sumPendingIncome(txs), 200000);

      final alloc = allocateVehicleCost(
          totalCost: sumVehicleCost(txs), kmKanvasing: 60, kmOjol: 30, kmPribadi: 10);
      final p = computeActivityProfits(txs: txs, allocatedVehicleCost: alloc);
      expect(p['kanvasing']!.profit, 252000);
      expect(p['ojol']!.profit, 126000);
      expect(p['pribadi']!.profit, -8000);
    });
  });

  group('perUnit', () {
    test('pembagian aman', () {
      expect(perUnit(150000, 30), 5000);
      expect(perUnit(150000, 0), isNull);
    });
  });

  group('evaluateServiceItem', () {
    final today = DateTime(2026, 10, 21);

    ServiceDue byKm(double current) => evaluateServiceItem(
          intervalKm: 3000,
          intervalDays: null,
          lastDate: null,
          lastOdo: 10000,
          currentOdo: current,
          today: today,
        );

    ServiceDue byDays(DateTime last) => evaluateServiceItem(
          intervalKm: null,
          intervalDays: 90,
          lastDate: last,
          lastOdo: null,
          currentOdo: 0,
          today: today,
        );

    // Angka interval di test ini hanya contoh, BUKAN rekomendasi servis.
    test('berdasarkan km', () {
      expect(byKm(11000).status, ServiceStatus.ok);
      expect(byKm(11000).remainingKm, 2000);
      expect(byKm(12500).status, ServiceStatus.soon);
      expect(byKm(12400).status, ServiceStatus.soon); // tepat 20% (sisa 600)
      expect(byKm(13100).status, ServiceStatus.overdue);
      expect(byKm(13100).remainingKm, -100);
    });

    test('berdasarkan hari', () {
      expect(byDays(DateTime(2026, 10, 1)).status, ServiceStatus.ok);
      expect(byDays(DateTime(2026, 10, 1)).remainingDays, 70);
      expect(byDays(DateTime(2026, 8, 1)).status, ServiceStatus.soon);
      expect(byDays(DateTime(2026, 8, 1)).remainingDays, 9);
      expect(byDays(DateTime(2026, 7, 1)).status, ServiceStatus.overdue);
      expect(byDays(DateTime(2026, 7, 1)).remainingDays, -22);
    });

    test('km dan hari: yang terburuk menang', () {
      final r = evaluateServiceItem(
        intervalKm: 3000,
        intervalDays: 90,
        lastDate: DateTime(2026, 10, 1),
        lastOdo: 10000,
        currentOdo: 13000,
        today: today,
      );
      expect(r.status, ServiceStatus.overdue); // sisa km 0, sisa hari 70
    });

    test('belum ada data servis terakhir -> unknown', () {
      final r = evaluateServiceItem(
        intervalKm: 3000,
        intervalDays: null,
        lastDate: null,
        lastOdo: null,
        currentOdo: 13000,
        today: today,
      );
      expect(r.status, ServiceStatus.unknown);
    });
  });
}
```

### Lampiran G2 — Test skema SQLite
Salin ke: `test/ledger_db_test.dart`

Memakai `sqflite_common_ffi` (sudah ada di `pubspec.yaml`); CI sudah memasang `libsqlite3-dev`.

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:sf_daily_recap/services/ledger_schema.dart';

void main() {
  sqfliteFfiInit();

  late Database db;
  const now = '2026-10-02T10:00:00';

  setUp(() async {
    db = await databaseFactoryFfi.openDatabase(inMemoryDatabasePath);
    for (final s in ledgerSchemaStatements) {
      await db.execute(s);
    }
    for (final a in [
      {'id': 'A1', 'name': 'Tunai', 'kind': 'cash', 'opening_balance': 100000},
      {'id': 'A2', 'name': 'BCA', 'kind': 'bank', 'opening_balance': 500000},
      {'id': 'A3', 'name': 'Dana', 'kind': 'ewallet', 'opening_balance': 0},
    ]) {
      await db.insert('accounts', {...a, 'created_at': now, 'updated_at': now});
    }
  });

  tearDown(() async => db.close());

  Future<void> tx(
    String id,
    String kind,
    int amount,
    String acc,
    String pool,
    String activity, {
    String? toAcc,
    String? toPool,
    String status = 'cleared',
  }) {
    return db.insert('transactions', {
      'id': id,
      'tanggal': '2026-10-02',
      'kind': kind,
      'amount': amount,
      'account_id': acc,
      'to_account_id': toAcc,
      'pool': pool,
      'to_pool': toPool,
      'activity': activity,
      'status': status,
      'created_at': now,
      'updated_at': now,
    });
  }

  Future<void> seed() async {
    await tx('t1', 'income', 300000, 'A2', 'utama', 'kanvasing');
    await tx('t2', 'income', 200000, 'A2', 'utama', 'kanvasing', status: 'pending');
    await tx('t3', 'expense', 20000, 'A1', 'utama', 'kendaraan');
    await tx('t4', 'income', 150000, 'A3', 'tambahan', 'ojol');
    await tx('t5', 'transfer', 100000, 'A3', 'tambahan', 'pribadi', toAcc: 'A2', toPool: 'utama');
  }

  test('saldo rekening dan saldo kas', () async {
    await seed();
    final acc = {
      for (final r in await db.query('v_account_balance')) r['name'] as String: r['balance'] as int,
    };
    expect(acc, {'Tunai': 80000, 'BCA': 900000, 'Dana': 50000});

    final pool = {
      for (final r in await db.query('v_pool_balance')) r['pool'] as String: r['balance'] as int,
    };
    expect(pool, {'utama': 380000, 'tambahan': 50000});
  });

  test('soft delete mengurangi saldo; pending tidak dihitung', () async {
    await seed();
    await db.update('transactions', {'deleted_at': now}, where: 'id = ?', whereArgs: ['t1']);
    final rows = await db.query('v_account_balance', where: 'name = ?', whereArgs: ['BCA']);
    expect(rows.first['balance'], 600000);
  });

  test('constraint menolak data yang salah bentuk', () async {
    expect(() => tx('x1', 'transfer', 1000, 'A2', 'utama', 'pribadi'), throwsA(isA<DatabaseException>()));
    expect(() => tx('x2', 'expense', 0, 'A2', 'utama', 'pribadi'), throwsA(isA<DatabaseException>()));
    expect(
      () => tx('x3', 'income', 1000, 'A2', 'utama', 'pribadi', toAcc: 'A1', toPool: 'utama'),
      throwsA(isA<DatabaseException>()),
    );
    expect(
      () => tx('x4', 'transfer', 1000, 'A2', 'utama', 'pribadi', toAcc: 'A2', toPool: 'utama'),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('item servis wajib punya minimal satu interval', () async {
    expect(
      () => db.insert('service_items', {
        'id': 's1',
        'vehicle_id': 'v1',
        'name': 'Contoh',
        'created_at': now,
        'updated_at': now,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
}
```

### Lampiran H — Sync service (referensi implementasi utuh)
Salin ke: `lib/services/sync_service.dart (ganti isi)`

```dart
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:sqflite/sqflite.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'local_db.dart';

/// Sinkronisasi SQLite <-> Supabase (REFERENSI IMPLEMENTASI — ganti isi lib/services/sync_service.dart).
/// Perilaku yang dipertahankan: baris lokal is_synced = 0 tidak ditimpa oleh pull.
/// Perbaikan: filter kolom pull, paginasi, isolasi error per tabel, antrean hapus tidak dibuang saat gagal.
class SyncService {
  static final SupabaseClient _client = Supabase.instance.client;

  /// Urutan push/pull: tabel induk dulu (foreign key).
  static const List<String> _order = <String>[
    'accounts',
    'vehicles',
    'daily_recap',
    'daily_order',
    'petty_cash_item',
    'daily_extra',
    'fuel_fillings',
    'vehicle_logs',
    'service_items',
    'transactions',
    'service_records',
  ];

  /// Kunci utama selain 'id'.
  static const Map<String, String> _pk = <String, String>{
    'daily_extra': 'daily_recap_id',
  };

  /// Boolean di Supabase, INTEGER 0/1 di SQLite.
  static const Map<String, List<String>> _boolCols = <String, List<String>>{
    'daily_order': <String>['is_fuel_expense'],
    'accounts': <String>['is_active'],
    'vehicles': <String>['is_active'],
  };

  static final Map<String, Set<String>> _colCache = <String, Set<String>>{};

  static Future<void> sync() async {
    final errors = <String>[];

    Future<void> guard(String label, Future<void> Function() fn) async {
      try {
        await fn();
      } catch (e) {
        debugPrint('Sync $label gagal: $e');
        errors.add('$label: $e');
      }
    }

    // 1. Penghapusan dulu agar data yang dihapus tidak dibuat ulang.
    await guard('hapus', _syncDeletions);
    // 2. Push perubahan lokal.
    for (final t in _order) {
      await guard('push $t', () => _pushTable(t));
    }
    // 3. Pull perubahan remote.
    for (final t in _order) {
      await guard('pull $t', () => _pullTable(t));
    }

    if (errors.isNotEmpty) {
      throw StateError('Sinkronisasi sebagian gagal (${errors.length}): ${errors.first}');
    }
  }

  static Future<void> _syncDeletions() async {
    final db = await LocalDb.instance.database;
    final deletions = await db.query('pending_deletions');
    for (final del in deletions) {
      final queueId = del['id'] as int;
      final table = del['table_name'] as String;
      final recordId = del['record_id'] as String;
      try {
        await _client.from(table).delete().eq('id', recordId);
        await db.delete('pending_deletions', where: 'id = ?', whereArgs: [queueId]);
      } catch (e) {
        // JANGAN buang antrean saat gagal (mis. offline): kalau dibuang, baris remote
        // masih ada dan akan "hidup lagi" saat pull. Coba lagi pada sync berikutnya.
        debugPrint('Hapus remote gagal ($table): $e');
      }
    }
  }

  static Future<Set<String>> _localCols(Database db, String table) async {
    final cached = _colCache[table];
    if (cached != null) return cached;
    final info = await db.rawQuery('PRAGMA table_info($table)');
    final cols = info.map((r) => r['name'] as String).toSet();
    _colCache[table] = cols;
    return cols;
  }

  static Future<void> _pushTable(String table) async {
    final db = await LocalDb.instance.database;
    final pk = _pk[table] ?? 'id';
    final boolCols = _boolCols[table] ?? const <String>[];

    final rows = await db.query(table, where: 'is_synced = 0');
    for (final r in rows) {
      final data = Map<String, dynamic>.from(r)..remove('is_synced');
      for (final c in boolCols) {
        if (data[c] != null) data[c] = data[c] == 1;
      }
      // user_id tidak ada di SQLite: server mengisinya lewat default auth.uid().
      await _client.from(table).upsert(data);
      await db.update(table, {'is_synced': 1}, where: '$pk = ?', whereArgs: [r[pk]]);
    }
  }

  static Future<void> _pullTable(String table) async {
    final db = await LocalDb.instance.database;
    final pk = _pk[table] ?? 'id';
    final cols = await _localCols(db, table);
    final boolCols = _boolCols[table] ?? const <String>[];

    // Baris yang menunggu dihapus (mis. sedang offline) tidak boleh dihidupkan lagi oleh pull.
    final pending = (await db.query(
      'pending_deletions',
      columns: ['record_id'],
      where: 'table_name = ?',
      whereArgs: [table],
    ))
        .map((r) => r['record_id'] as String)
        .toSet();

    const pageSize = 1000; // batas default PostgREST
    var from = 0;
    while (true) {
      final chunk = await _client.from(table).select().order(pk).range(from, from + pageSize - 1);

      for (final rr in chunk) {
        final id = rr[pk].toString();
        if (pending.contains(id)) continue;

        // Buang kolom yang tidak ada di SQLite (mis. user_id), konversi boolean.
        final data = <String, dynamic>{};
        rr.forEach((k, v) {
          if (cols.contains(k)) data[k] = v;
        });
        for (final c in boolCols) {
          if (data[c] is bool) data[c] = (data[c] as bool) ? 1 : 0;
        }
        data['is_synced'] = 1;

        final local = await db.query(
          table,
          columns: ['is_synced'],
          where: '$pk = ?',
          whereArgs: [id],
        );
        if (local.isEmpty) {
          await db.insert(table, data);
        } else if ((local.first['is_synced'] as int) == 1) {
          await db.update(table, data, where: '$pk = ?', whereArgs: [id]);
        }
      }

      if (chunk.length < pageSize) break;
      from += pageSize;
    }
  }
}
```

### Lampiran I — Perubahan local_db.dart
Salin ke: `lib/services/local_db.dart (ubah, bukan ganti)`

```dart
// REFERENSI PERUBAHAN untuk lib/services/local_db.dart (bukan file utuh).

// 1) Tambahkan import di bagian atas:
import 'ledger_schema.dart';

// 2) Di dalam class LocalDb, tambahkan:
static const String _fuelFillingsDdl = '''
  CREATE TABLE IF NOT EXISTS fuel_fillings (
    id TEXT PRIMARY KEY,
    daily_recap_id TEXT NOT NULL,
    tanggal TEXT NOT NULL,
    liter REAL NOT NULL,
    harga_per_liter REAL NOT NULL DEFAULT 0,
    total_biaya REAL NOT NULL DEFAULT 0,
    odometer REAL,
    catatan TEXT,
    vehicle_id TEXT,
    created_at TEXT NOT NULL,
    is_synced INTEGER NOT NULL DEFAULT 0
  )
''';

static Future<void> _createFuelFillings(Database db) async {
  await db.execute(_fuelFillingsDdl);
  await db.execute('CREATE INDEX IF NOT EXISTS idx_fuel_fillings_recap ON fuel_fillings(daily_recap_id)');
  await db.execute('CREATE INDEX IF NOT EXISTS idx_fuel_fillings_tanggal ON fuel_fillings(tanggal)');
}

static Future<void> _addColumnIfMissing(Database db, String table, String column, String ddl) async {
  final info = await db.rawQuery('PRAGMA table_info($table)');
  final exists = info.any((r) => r['name'] == column);
  if (!exists) {
    await db.execute('ALTER TABLE $table ADD COLUMN $column $ddl');
  }
}

// 3) openDatabase(... version: 11, ...)   // sebelumnya 10

// 4) Di onCreate, SETELAH membuat tabel pending_deletions dan SEBELUM `await _createSummaryView(db);`:
await _createFuelFillings(db);
for (final s in ledgerSchemaStatements) {
  await db.execute(s);
}

// 5) Di onUpgrade, SETELAH blok `if (oldVersion < 10) { ... }` dan SEBELUM
//    komentar "Selalu re-create view":
if (oldVersion < 11) {
  // Instalasi yang dibuat langsung di v10 lewat onCreate tidak punya fuel_fillings.
  await _createFuelFillings(db);
  await _addColumnIfMissing(db, 'fuel_fillings', 'vehicle_id', 'TEXT');
  for (final s in ledgerSchemaStatements) {
    await db.execute(s);
  }
}
```
