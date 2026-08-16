class DailyRecap {
  final String id;
  final DateTime tanggal;
  final double cashAwal;
  final double saldoAwalApp;
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
  final double cashAkhir;
  final double netEarning;

  DailyRecap({
    required this.id,
    required this.tanggal,
    required this.cashAwal,
    required this.saldoAwalApp,
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
    this.cashAkhir = 0,
    this.netEarning = 0,
  });

  factory DailyRecap.fromSummaryMap(Map<String, dynamic> map) {
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return DailyRecap(
      id: map['id'] as String,
      tanggal: DateTime.parse(map['tanggal'] as String),
      cashAwal: d(map['cash_awal']),
      saldoAwalApp: d(map['saldo_awal_app']),
      totalIncome: d(map['total_income']),
      totalExpense: d(map['total_expense']),
      totalCustPay: d(map['total_cust_pay']),
      totalCustChange: d(map['total_cust_change']),
      totalSaldoTopUp: d(map['total_saldo_top_up']),
      pettyCashTotal: d(map['petty_cash_total']),
      tip: d(map['tip']),
      insentif: d(map['insentif']),
      saldoAkhirApp: d(map['saldo_akhir_app']),
      cashAkhir: d(map['cash_akhir']),
      netEarning: d(map['net_earning']),
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'tanggal': tanggal.toIso8601String().split('T').first,
        'cash_awal': cashAwal,
        'saldo_awal_app': saldoAwalApp,
        'catatan': catatan,
      };
}
