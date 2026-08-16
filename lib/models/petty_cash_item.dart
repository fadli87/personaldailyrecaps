/// Denominasi uang tunai yang didukung, urut dari terbesar.
const List<int> pettyCashDenoms = [100000, 50000, 20000, 10000, 5000, 2000, 1000, 500, 200, 100];

class PettyCashItem {
  final int denom;
  final int qty;

  const PettyCashItem({required this.denom, this.qty = 0});

  int get subtotal => denom * qty;

  PettyCashItem copyWith({int? qty}) =>
      PettyCashItem(denom: denom, qty: qty ?? this.qty);

  factory PettyCashItem.fromMap(Map<String, dynamic> map) => PettyCashItem(
        denom: int.parse(map['denom'] as String),
        qty: map['qty'] as int? ?? 0,
      );

  Map<String, dynamic> toInsertMap(String dailyRecapId) => {
        'daily_recap_id': dailyRecapId,
        'denom': denom.toString(),
        'qty': qty,
      };
}
