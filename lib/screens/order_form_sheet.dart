import 'package:flutter/material.dart';
import '../models/daily_order.dart';

class OrderFormSheet extends StatefulWidget {
  final String dailyRecapId;
  final DailyOrder? existing;
  final int nextUrutan;

  const OrderFormSheet({
    super.key,
    required this.dailyRecapId,
    required this.existing,
    required this.nextUrutan,
  });

  @override
  State<OrderFormSheet> createState() => _OrderFormSheetState();
}

class _OrderFormSheetState extends State<OrderFormSheet> {
  late String _type;
  late TextEditingController _platform;
  late TextEditingController _keterangan;
  late TextEditingController _income;
  late TextEditingController _deductCashApp;
  late TextEditingController _custPay;
  late TextEditingController _custChange;
  late TextEditingController _saldoTopUp;
  late TextEditingController _expense;
  late TextEditingController _remark;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    
    // Infer tipe transaksi dari data yang ada
    if (e != null) {
      if (e.saldoTopUp > 0) {
        _type = 'topup';
      } else if (e.expense > 0 && e.income == 0) {
        _type = 'expense';
      } else {
        _type = 'order';
      }
    } else {
      _type = 'order';
    }

    _platform = TextEditingController(text: e?.platform ?? '');
    _keterangan = TextEditingController(text: e?.keterangan ?? '');
    _income = TextEditingController(text: (e?.income ?? 0).toStringAsFixed(0));
    _deductCashApp = TextEditingController(text: (e?.deductCashApp ?? 0).toStringAsFixed(0));
    _custPay = TextEditingController(text: (e?.custPay ?? 0).toStringAsFixed(0));
    _custChange = TextEditingController(text: (e?.custChange ?? 0).toStringAsFixed(0));
    _saldoTopUp = TextEditingController(text: (e?.saldoTopUp ?? 0).toStringAsFixed(0));
    _expense = TextEditingController(text: (e?.expense ?? 0).toStringAsFixed(0));
    _remark = TextEditingController(text: e?.remark ?? '');
  }

  double _n(TextEditingController c) => double.tryParse(c.text) ?? 0;

  void _submit() {
    String? platform;
    String? keterangan;
    double income = 0;
    double deductCashApp = 0;
    double custPay = 0;
    double custChange = 0;
    double saldoTopUp = 0;
    double expense = 0;

    if (_type == 'order') {
      platform = _platform.text.trim().isEmpty ? null : _platform.text.trim();
      income = _n(_income);
      expense = _n(_expense);
      custPay = _n(_custPay);
      custChange = _n(_custChange);
      deductCashApp = _n(_deductCashApp);
    } else if (_type == 'topup') {
      keterangan = _keterangan.text.trim().isEmpty ? null : _keterangan.text.trim();
      saldoTopUp = _n(_saldoTopUp);
      deductCashApp = _n(_deductCashApp);
    } else if (_type == 'expense') {
      keterangan = _keterangan.text.trim().isEmpty ? null : _keterangan.text.trim();
      expense = _n(_expense);
    }

    final order = DailyOrder(
      id: widget.existing?.id,
      dailyRecapId: widget.dailyRecapId,
      urutan: widget.existing?.urutan ?? widget.nextUrutan,
      platform: platform,
      keterangan: keterangan,
      income: income,
      deductCashApp: deductCashApp,
      custPay: custPay,
      custChange: custChange,
      saldoTopUp: saldoTopUp,
      expense: expense,
      remark: _remark.text.trim().isEmpty ? null : _remark.text.trim(),
    );
    Navigator.pop(context, order);
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 16,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.existing == null 
                  ? 'Tambah Transaksi Baru' 
                  : 'Edit Transaksi ${widget.existing!.urutan}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            
            // Selector Tipe Transaksi
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'order',
                    label: Text('Order'),
                    icon: Icon(Icons.shopping_cart_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: 'topup',
                    label: Text('Top Up'),
                    icon: Icon(Icons.account_balance_wallet_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: 'expense',
                    label: Text('Pengeluaran'),
                    icon: Icon(Icons.money_off_outlined, size: 18),
                  ),
                ],
                selected: {_type},
                onSelectionChanged: (newSelection) {
                  setState(() {
                    _type = newSelection.first;
                  });
                },
              ),
            ),
            const SizedBox(height: 20),

            // Form Fields conditional rendering
            if (_type == 'order') ...[
              TextField(
                controller: _platform,
                decoration: const InputDecoration(
                  labelText: 'Platform (opsional, misal: Tokopedia, GrabFood)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _num('Income (Pemasukan)', _income)),
                  const SizedBox(width: 12),
                  Expanded(child: _num('Expense (Biaya/Ongkir)', _expense)),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _num('Cust Pay (Uang Cust)', _custPay)),
                  const SizedBox(width: 12),
                  Expanded(child: _num('Cust Change (Kembalian)', _custChange)),
                ],
              ),
              const SizedBox(height: 12),
              _num('Deduct Cash App (Potong Saldo App)', _deductCashApp),
            ] else if (_type == 'topup') ...[
              TextField(
                controller: _keterangan,
                decoration: const InputDecoration(
                  labelText: 'Keterangan Top Up (misal: Top Up OVO, ShopeePay)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: _num('Nominal Top Up', _saldoTopUp)),
                  const SizedBox(width: 12),
                  Expanded(child: _num('Potong dari Saldo App (Deduct)', _deductCashApp)),
                ],
              ),
            ] else if (_type == 'expense') ...[
              TextField(
                controller: _keterangan,
                decoration: const InputDecoration(
                  labelText: 'Keterangan Pengeluaran (misal: Beli Bensin, Makan)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _num('Nominal Pengeluaran', _expense),
            ],
            
            const SizedBox(height: 12),
            TextField(
              controller: _remark,
              decoration: const InputDecoration(
                labelText: 'Catatan Tambahan (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _submit,
                child: const Text('Simpan Transaksi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _num(String label, TextEditingController ctrl) => TextField(
        controller: ctrl,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      );
}
