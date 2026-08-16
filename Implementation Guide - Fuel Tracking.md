# **Implementation Guide: Fitur Telemetri & BBM (Fuel Tracking)**

Dokumen ini berisi langkah-langkah implementasi penambahan fitur pencatatan jarak tempuh (Odometer) dan konsumsi Bahan Bakar Minyak (BBM) ke dalam aplikasi SF Daily Recap.

## **Fase 1: Pembaruan Skema Supabase (Remote DB)**

Jalankan *script* SQL berikut di Supabase SQL Editor untuk menambahkan kolom baru dan memperbarui View kalkulasi harian. Karena tabel sudah memiliki data, kita menggunakan ALTER TABLE dengan nilai *default* agar tidak merusak data lama.  
`-- 1. Tambah parameter telemetri di tabel daily_recap`  
`ALTER TABLE daily_recap`   
`ADD COLUMN odo_start numeric(14,2) NOT NULL DEFAULT 0,`  
`ADD COLUMN odo_end numeric(14,2) NOT NULL DEFAULT 0,`  
`ADD COLUMN fuel_price_per_liter numeric(14,2) NOT NULL DEFAULT 10000, -- Default misal Pertalite`  
`ADD COLUMN kml_parameter numeric(10,2) NOT NULL DEFAULT 45.5; -- Standar konsumsi rasio motor km/liter`

`-- 2. Tambah flag khusus di daily_order untuk menandai pengeluaran bensin`  
`ALTER TABLE daily_order`   
`ADD COLUMN is_fuel_expense boolean NOT NULL DEFAULT false;`

`-- 3. Perbarui View daily_recap_summary dengan sub-query bensin`  
`CREATE OR REPLACE VIEW daily_recap_summary AS`  
`SELECT`  
  `dr.id,`  
  `dr.tanggal,`  
  `dr.cash_awal,`  
  `dr.saldo_awal_app,`  
  `dr.odo_start,`  
  `dr.odo_end,`  
  `dr.fuel_price_per_liter,`  
  `dr.kml_parameter,`  
  `coalesce(o.total_income, 0) as total_income,`  
  `coalesce(o.total_deduct_cash_app, 0) as total_deduct_cash_app,`  
  `coalesce(o.total_cust_pay, 0) as total_cust_pay,`  
  `coalesce(o.total_cust_change, 0) as total_cust_change,`  
  `coalesce(o.total_saldo_top_up, 0) as total_saldo_top_up,`  
  `coalesce(o.total_expense, 0) as total_expense,`  
  `coalesce(pc.grand_total, 0) as petty_cash_total,`  
  `coalesce(de.tip, 0) as tip,`  
  `coalesce(de.insentif, 0) as insentif,`  
    
  `-- Kalkulasi Finansial`  
  `dr.saldo_awal_app + coalesce(o.total_income, 0) - coalesce(o.total_expense, 0) as saldo_akhir_app,`  
  `dr.cash_awal + coalesce(o.total_cust_pay, 0) - coalesce(o.total_cust_change, 0) - coalesce(o.total_saldo_top_up, 0) as cash_akhir,`  
  `coalesce(o.total_income, 0) - coalesce(o.total_expense, 0) as net_earning,`  
    
  `-- Kalkulasi Telemetri & BBM`  
  `(dr.odo_end - dr.odo_start) as jarak_tempuh,`  
  `coalesce(f.total_fuel_expense, 0) as total_fuel_expense,`  
    
  `-- Mencegah division by zero`  
  `CASE WHEN dr.fuel_price_per_liter > 0`   
       `THEN coalesce(f.total_fuel_expense, 0) / dr.fuel_price_per_liter`   
       `ELSE 0 END as liter_masuk,`  
         
  `CASE WHEN dr.kml_parameter > 0`   
       `THEN (dr.odo_end - dr.odo_start) / dr.kml_parameter`   
       `ELSE 0 END as liter_terpakai`

`FROM daily_recap dr`  
`LEFT JOIN (`  
  `SELECT`  
    `daily_recap_id,`  
    `SUM(income) AS total_income,`  
    `SUM(deduct_cash_app) AS total_deduct_cash_app,`  
    `SUM(cust_pay) AS total_cust_pay,`  
    `SUM(cust_change) AS total_cust_change,`  
    `SUM(saldo_top_up) AS total_saldo_top_up,`  
    `SUM(expense) AS total_expense`  
  `FROM daily_order`  
  `GROUP BY daily_recap_id`  
`) o ON o.daily_recap_id = dr.id`  
`LEFT JOIN (`  
  `-- Sub-query khusus untuk menjumlahkan pengeluaran bensin saja`  
  `SELECT daily_recap_id, SUM(expense) AS total_fuel_expense`  
  `FROM daily_order`  
  `WHERE is_fuel_expense = true`  
  `GROUP BY daily_recap_id`  
`) f ON f.daily_recap_id = dr.id`  
`LEFT JOIN (`  
  `SELECT daily_recap_id, SUM(denom::text::numeric * qty) AS grand_total`  
  `FROM petty_cash_item`  
  `GROUP BY daily_recap_id`  
`) pc ON pc.daily_recap_id = dr.id`  
`LEFT JOIN daily_extra de ON de.daily_recap_id = dr.id;`

## **Fase 2: Pembaruan SQLite (local\_db.dart)**

Ubah versi database lokal ke version: 2 dan tambahkan blok onUpgrade agar pengguna lama tidak kehilangan data saat menginstal versi pembaruan ini.  
`// Di dalam local_db.dart`  
`return await openDatabase(`  
  `dbPath,`  
  `version: 2, // Naikkan versi`  
  `onCreate: (db, version) async {`  
    `// ... (query CREATE TABLE lama, ditambah kolom baru sesuai schema Supabase di atas)`  
  `},`  
  `onUpgrade: (db, oldVersion, newVersion) async {`  
    `if (oldVersion < 2) {`  
      `// 1. Tambah kolom di daily_recap`  
      `await db.execute('ALTER TABLE daily_recap ADD COLUMN odo_start REAL NOT NULL DEFAULT 0');`  
      `await db.execute('ALTER TABLE daily_recap ADD COLUMN odo_end REAL NOT NULL DEFAULT 0');`  
      `await db.execute('ALTER TABLE daily_recap ADD COLUMN fuel_price_per_liter REAL NOT NULL DEFAULT 10000');`  
      `await db.execute('ALTER TABLE daily_recap ADD COLUMN kml_parameter REAL NOT NULL DEFAULT 45.5');`  
        
      `// 2. Tambah kolom di daily_order`  
      `await db.execute('ALTER TABLE daily_order ADD COLUMN is_fuel_expense INTEGER NOT NULL DEFAULT 0');`  
        
      `// 3. Re-create View`  
      `await db.execute('DROP VIEW IF EXISTS daily_recap_summary');`  
        
      `// Paste SQL script pembuatan VIEW di sini (mirip dengan query Supabase fase 1,`  
      `// perbedaannya pada boolean Supabase (true) menjadi integer SQLite (1) di WHERE is_fuel_expense = 1)`  
      `await db.execute('''`  
        `CREATE VIEW daily_recap_summary AS`  
        `SELECT ... -- (masukkan query view dari Fase 1 dengan penyesuaian sintaks SQLite)`  
      `''');`  
    `}`  
  `},`  
`);`

## **Fase 3: Penyesuaian Data Model**

Tambahkan properti baru di file model agar Flutter bisa membaca JSON yang dihasilkan dari database dan menuliskannya kembali.

### **models/daily\_recap.dart (Tambahan properti):**

`final double odoStart;`  
`final double odoEnd;`  
`final double fuelPricePerLiter;`  
`final double kmlParameter;`

`// Properti turunan dari View summary`  
`final double jarakTempuh;`  
`final double literMasuk;`  
`final double literTerpakai;`  
`final double sisaTangkiHarian; // = literMasuk - literTerpakai`

`// Pastikan menambahkan parsing dari map di factory fromSummaryMap()`

### **models/daily\_order.dart (Tambahan properti):**

`final bool isFuelExpense;`   
`// Parsing SQLite menggunakan (map['is_fuel_expense'] as int) == 1`

## **Fase 4: Konsep UI/UX**

### **1\. Form Recap Header (Awal/Akhir Hari)**

Tambahkan 4 kolom TextField baru (bisa diletakkan di tab/halaman settings terpisah atau menggunakan Accordion agar layar form utama tidak terlalu penuh).

> * **Odometer Awal:** \[ \_\_\_\_\_\_ \] KM  
> * **Odometer Akhir:** \[ \_\_\_\_\_\_ \] KM  
> * **Harga BBM Saat Ini:** Rp \[ 10.000 \] / Liter  
> * **Parameter Kinerja:** \[ 45.5 \] KM/Liter

### **2\. Form Daily Order**

Tepat di bawah input nominal Expense, tambahkan CheckboxListTile atau Switch:  
\[ \] Pengeluaran ini adalah untuk beli bensin

### **3\. Dashboard Widget (Indikator Kendaraan)**

Buat komponen khusus untuk menyajikan konversi BBM harian.  
`Widget _buildVehicleStats(DailyRecap recap) {`  
  `final surplus = recap.literMasuk - recap.literTerpakai;`  
  `final isPositive = surplus >= 0;`

  `return Container(`  
    `padding: const EdgeInsets.all(16),`  
    `decoration: BoxDecoration(`  
      `color: Colors.grey.shade900,`  
      `borderRadius: BorderRadius.circular(12),`  
    `),`  
    `child: Row(`  
      `mainAxisAlignment: MainAxisAlignment.spaceAround,`  
      `children: [`  
        `_statItem(Icons.speed, '${recap.jarakTempuh} KM', 'Jarak Tempuh'),`  
        `_statItem(Icons.local_gas_station, '+${recap.literMasuk.toStringAsFixed(1)} L', 'BBM Masuk'),`  
        `_statItem(Icons.whatshot, '-${recap.literTerpakai.toStringAsFixed(1)} L', 'BBM Terpakai'),`  
        `_statItem(`  
          `isPositive ? Icons.battery_charging_full : Icons.battery_alert,`  
          `'${isPositive ? '+' : ''}${surplus.toStringAsFixed(1)} L',`   
          `'Est. Sisa Tangki',`  
          `color: isPositive ? Colors.greenAccent : Colors.redAccent,`  
        `),`  
      `],`  
    `),`  
  `);`  
`}`  
