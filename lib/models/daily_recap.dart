class DailyRecap {
  final String id;
  final DateTime tanggal;
  final double cashAwal;
  final double saldoAwalApp;
  final double saldoAwalGrabKredit;
  final double saldoAwalGrabTunai;
  final double saldoAwalGrabOvo;
  final double odoStart;
  final double odoEnd;
  final double fuelPricePerLiter;
  final double kmlParameter;
  final String status;
  final double saldoAkhirAppAktual;
  final double saldoAkhirGrabKreditAktual;
  final double saldoAkhirGrabTunaiAktual;
  final double saldoAkhirGrabOvoAktual;
  final String? catatan;

  // Fields below come from the `daily_recap_summary` view (auto-calculated).
  final double totalIncome;
  final double totalExpense;
  final double totalCustPay;
  final double totalCustChange;
  final double totalSaldoTopUp;
  final double pettyCashTotal;
  final double tip;
  final double insentif;
  final double saldoAkhirApp;
  final double saldoAkhirGrabKredit;
  final double saldoAkhirGrabTunai;
  final double saldoAkhirGrabOvo;
  final double cashAkhir;
  final double netEarning;
  final double jarakTempuh;
  final double totalFuelExpense;
  final double literMasuk;
  final double literTerpakai;
  final double cashDiscrepancy;
  final double appDiscrepancy;
  final double grabKreditDiscrepancy;
  final double grabTunaiDiscrepancy;
  final double grabOvoDiscrepancy;

  DailyRecap({
    required this.id,
    required this.tanggal,
    required this.cashAwal,
    required this.saldoAwalApp,
    this.saldoAwalGrabKredit = 0,
    this.saldoAwalGrabTunai = 0,
    this.saldoAwalGrabOvo = 0,
    this.odoStart = 0,
    this.odoEnd = 0,
    this.fuelPricePerLiter = 10000,
    this.kmlParameter = 45.5,
    this.status = 'open',
    this.saldoAkhirAppAktual = 0,
    this.saldoAkhirGrabKreditAktual = 0,
    this.saldoAkhirGrabTunaiAktual = 0,
    this.saldoAkhirGrabOvoAktual = 0,
    this.catatan,
    this.totalIncome = 0,
    this.totalExpense = 0,
    this.totalCustPay = 0,
    this.totalCustChange = 0,
    this.totalSaldoTopUp = 0,
    this.pettyCashTotal = 0,
    this.tip = 0,
    this.insentif = 0,
    this.saldoAkhirApp = 0,
    this.saldoAkhirGrabKredit = 0,
    this.saldoAkhirGrabTunai = 0,
    this.saldoAkhirGrabOvo = 0,
    this.cashAkhir = 0,
    this.netEarning = 0,
    this.jarakTempuh = 0,
    this.totalFuelExpense = 0,
    this.literMasuk = 0,
    this.literTerpakai = 0,
    this.cashDiscrepancy = 0,
    this.appDiscrepancy = 0,
    this.grabKreditDiscrepancy = 0,
    this.grabTunaiDiscrepancy = 0,
    this.grabOvoDiscrepancy = 0,
  });

  factory DailyRecap.fromSummaryMap(Map<String, dynamic> map) {
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return DailyRecap(
      id: map['id'] as String,
      tanggal: DateTime.parse(map['tanggal'] as String),
      cashAwal: d(map['cash_awal']),
      saldoAwalApp: d(map['saldo_awal_app']),
      saldoAwalGrabKredit: d(map['saldo_awal_grab_kredit']),
      saldoAwalGrabTunai: d(map['saldo_awal_grab_tunai']),
      saldoAwalGrabOvo: d(map['saldo_awal_grab_ovo']),
      odoStart: d(map['odo_start']),
      odoEnd: d(map['odo_end']),
      fuelPricePerLiter: d(map['fuel_price_per_liter']),
      kmlParameter: d(map['kml_parameter']),
      status: map['status'] as String? ?? 'open',
      saldoAkhirAppAktual: d(map['saldo_akhir_app_aktual']),
      saldoAkhirGrabKreditAktual: d(map['saldo_akhir_grab_kredit_aktual']),
      saldoAkhirGrabTunaiAktual: d(map['saldo_akhir_grab_tunai_aktual']),
      saldoAkhirGrabOvoAktual: d(map['saldo_akhir_grab_ovo_aktual']),
      catatan: map['catatan'] as String?,
      totalIncome: d(map['total_income']),
      totalExpense: d(map['total_expense']),
      totalCustPay: d(map['total_cust_pay']),
      totalCustChange: d(map['total_cust_change']),
      totalSaldoTopUp: d(map['total_saldo_top_up']),
      pettyCashTotal: d(map['petty_cash_total']),
      tip: d(map['tip']),
      insentif: d(map['insentif']),
      saldoAkhirApp: d(map['saldo_akhir_app']),
      saldoAkhirGrabKredit: d(map['saldo_akhir_grab_kredit']),
      saldoAkhirGrabTunai: d(map['saldo_akhir_grab_tunai']),
      saldoAkhirGrabOvo: d(map['saldo_akhir_grab_ovo']),
      cashAkhir: d(map['cash_akhir']),
      netEarning: d(map['net_earning']),
      jarakTempuh: d(map['jarak_tempuh']),
      totalFuelExpense: d(map['total_fuel_expense']),
      literMasuk: d(map['liter_masuk']),
      literTerpakai: d(map['liter_terpakai']),
      cashDiscrepancy: d(map['cash_discrepancy']),
      appDiscrepancy: d(map['app_discrepancy']),
      grabKreditDiscrepancy: d(map['grab_kredit_discrepancy']),
      grabTunaiDiscrepancy: d(map['grab_tunai_discrepancy']),
      grabOvoDiscrepancy: d(map['grab_ovo_discrepancy']),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'tanggal': tanggal.toIso8601String().split('T').first,
        'cash_awal': cashAwal,
        'saldo_awal_app': saldoAwalApp,
        'saldo_awal_grab_kredit': saldoAwalGrabKredit,
        'saldo_awal_grab_tunai': saldoAwalGrabTunai,
        'saldo_awal_grab_ovo': saldoAwalGrabOvo,
        'odo_start': odoStart,
        'odo_end': odoEnd,
        'fuel_price_per_liter': fuelPricePerLiter,
        'kml_parameter': kmlParameter,
        'status': status,
        'saldo_akhir_app_aktual': saldoAkhirAppAktual,
        'saldo_akhir_grab_kredit_aktual': saldoAkhirGrabKreditAktual,
        'saldo_akhir_grab_tunai_aktual': saldoAkhirGrabTunaiAktual,
        'saldo_akhir_grab_ovo_aktual': saldoAkhirGrabOvoAktual,
        'catatan': catatan,
      };
}
