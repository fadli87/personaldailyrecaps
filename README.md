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

## Catatan tentang login

Schema ini pakai RLS policy `auth.role() = 'authenticated'` — artinya kamu perlu login
(walau cuma untuk diri sendiri) sebelum bisa baca/tulis data. `main.dart` sudah otomatis
memanggil `signInAnonymously()` saat app start, jadi tidak perlu form login sama sekali.

**Wajib:** aktifkan **Authentication → Sign In / Providers → Allow anonymous sign-ins** di
dashboard Supabase, atau app akan gagal sign-in saat pertama dibuka.

Kalau nanti mau proteksi lebih (misal HP dipakai orang lain juga), tinggal ganti jadi
email+password dan tambahkan `LoginScreen` sebelum `HomeScreen`.

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
