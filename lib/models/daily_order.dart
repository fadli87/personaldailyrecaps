class DailyOrder {
  final String? id;
  final String dailyRecapId;
  final int urutan;
  final String? platform;
  final String? keterangan;
  final double income;
  final double deductCashApp;
  final double custPay;
  final double custChange;
  final double saldoTopUp;
  final double expense;
  final String? remark;

  DailyOrder({
    this.id,
    required this.dailyRecapId,
    required this.urutan,
    this.platform,
    this.keterangan,
    this.income = 0,
    this.deductCashApp = 0,
    this.custPay = 0,
    this.custChange = 0,
    this.saldoTopUp = 0,
    this.expense = 0,
    this.remark,
  });

  factory DailyOrder.fromMap(Map<String, dynamic> map) {
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;
    return DailyOrder(
      id: map['id'] as String?,
      dailyRecapId: map['daily_recap_id'] as String,
      urutan: map['urutan'] as int? ?? 1,
      platform: map['platform'] as String?,
      keterangan: map['keterangan'] as String?,
      income: d(map['income']),
      deductCashApp: d(map['deduct_cash_app']),
      custPay: d(map['cust_pay']),
      custChange: d(map['cust_change']),
      saldoTopUp: d(map['saldo_top_up']),
      expense: d(map['expense']),
      remark: map['remark'] as String?,
    );
  }

  Map<String, dynamic> toInsertMap() => {
        'daily_recap_id': dailyRecapId,
        'urutan': urutan,
        'platform': platform,
        'keterangan': keterangan,
        'income': income,
        'deduct_cash_app': deductCashApp,
        'cust_pay': custPay,
        'cust_change': custChange,
        'saldo_top_up': saldoTopUp,
        'expense': expense,
        'remark': remark,
      };
}
