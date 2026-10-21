# SF Daily Recap

Aplikasi pribadi untuk mencatat rekap kas & order harian — menggabungkan struktur dari
kedua contoh Excel kamu (list transaksi sederhana + rekap harian detail dengan saldo app,
petty cash, tip/insentif).

## Fitur

- **Rekap harian**: cash awal, saldo awal app, tanggal.
- **Orders**: tambah order sebanyak apapun per hari (income, expense, cust pay/change,
  deduct cash app, saldo top up, remark).
- **Petty cash breakdown**: hitung qty pecahan uang (100rb → 1rb), grand total otomatis.
- **Tip & insentif** per hari.
- **Ringkasan otomatis**: Cash Akhir, Saldo Akhir App, Net Earning — dihitung server-side
  lewat SQL view, jadi selalu konsisten dan tidak perlu dihitung manual di app.

## Setup

### 1. Buat project Supabase
1. Daftar/login di https://supabase.com, buat project baru.
2. Buka **SQL Editor** → jalankan seluruh isi `supabase/schema.sql`.
3. Buka **Project Settings → API**, salin `Project URL` dan `anon public key`.
4. Buka **Authentication → Providers**, aktifkan minimal *Email* (untuk login pribadi kamu),
   atau pakai *Anonymous sign-in* kalau mau tanpa login sama sekali (lihat catatan di bawah).

### 2. Isi kredensial di `.env`
Edit file `.env` di root project (sudah disiapkan, tinggal isi):
```
SUPABASE_URL=https://xxxxx.supabase.co
SUPABASE_ANON_KEY=ey...
```
`.env` sudah masuk `.gitignore` — aman untuk tidak ter-commit ke Git. Kalau clone ulang di
device lain, salin dari `.env.example` lalu isi ulang.

### 3. Jalankan
```bash
flutter pub get
flutter run
```

## Autentikasi & Akun Pribadi

Aplikasi ini menggunakan Supabase Auth dengan isolasi data berbasis `user_id` (`owner_only`).
1. Buat akun email pribadi kamu di **Dashboard Supabase → Authentication → Users → Add user**.
2. Di **Authentication → Sign In / Providers**:
   - **Matikan "Allow anonymous sign-ins"**
   - **Matikan "Allow new users to sign up"** (karena aplikasi ini khusus pribadi).
3. Jalankan migrasi SQL di folder `supabase/migrations/` secara berurutan.
4. Buka aplikasi dan login menggunakan email & password akun yang telah kamu buat.

## Struktur project

```
lib/
  models/          # DailyRecap, DailyOrder, PettyCashItem
  services/        # RecapService — semua query ke Supabase
  screens/
    home_screen.dart              # daftar rekap harian
    daily_recap_detail_screen.dart # form utama: header, orders, petty cash, ringkasan
    order_form_sheet.dart          # bottom sheet tambah/edit order
supabase/
  schema.sql       # tabel + view ringkasan otomatis + RLS policy
```

## Rumus ringkasan (mengikuti pola di file contoh kamu)

- `Saldo Akhir App = Saldo Awal App + Total Income - Total Expense`
- `Cash Akhir = Cash Awal + Total Cust Pay - Total Cust Change - Total Saldo Top Up`
- `Net Earning = Total Income - Total Expense`

Kalau logikanya beda dari yang kamu maksud (misalnya Cash Akhir seharusnya juga
memperhitungkan Deduct Cash App), kabari saya — tinggal edit view `daily_recap_summary`
di `supabase/schema.sql`.

## Belum termasuk (bisa ditambah kalau perlu)
- Grafik/chart tren mingguan atau bulanan
- Export ke Excel/PDF
- Login screen (lihat catatan di atas)
- Kalender untuk lompat ke tanggal tertentu

## CI/CD & Download APK Otomatis (GitHub Actions)

Aplikasi ini sudah dilengkapi pipeline CI/CD GitHub Actions:
- **Build Otomatis**: Setiap kali melakukan `push` ke branch `master`/`main` atau push tag (`v*`, `BetaTest`).
- **Download APK Langsung**:
  1. Buka repository di GitHub: [Releases](https://github.com/fadli87/personaldailyrecaps/releases).
  2. Buka tag terbaru (misal `BetaTest` atau `vX.X.X`).
  3. Unduh file `sf-daily-recap.apk` dan langsung install di perangkat Android kamu.
- **Manual Trigger**: Kamu juga bisa memicu build APK kapan saja melalui tab **Actions** → pilih **Flutter CI/CD** → klik **Run workflow**.
