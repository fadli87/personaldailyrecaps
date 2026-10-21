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
  final bool isFuelExpense;
  final String walletType;
  final String topupSource;
  final String? remark;
  final double? odometer;

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
    this.isFuelExpense = false,
    this.walletType = 'shopeefood',
    this.topupSource = 'cash',
    this.remark,
    this.odometer,
  });

  factory DailyOrder.fromMap(Map<String, dynamic> map) {
    double d(dynamic v) => (v as num?)?.toDouble() ?? 0;

    final rawFuel = map['is_fuel_expense'];
    bool isFuel = false;
    if (rawFuel is bool) {
      isFuel = rawFuel;
    } else if (rawFuel is int) {
      isFuel = rawFuel == 1;
    }

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
      isFuelExpense: isFuel,
      walletType: map['wallet_type'] as String? ?? 'shopeefood',
      topupSource: map['topup_source'] as String? ?? 'cash',
      remark: map['remark'] as String?,
      odometer: map['odometer'] != null ? d(map['odometer']) : null,
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
        'is_fuel_expense': isFuelExpense ? 1 : 0,
        'wallet_type': walletType,
        'topup_source': topupSource,
        'remark': remark,
        'odometer': odometer,
      };
}
