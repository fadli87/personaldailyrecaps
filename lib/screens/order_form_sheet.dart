import 'package:flutter/material.dart';
import '../models/daily_order.dart';

class OrderFormSheet extends StatefulWidget {
  final String dailyRecapId;
  final DailyOrder? existing;
  final int nextUrutan;
  final bool isClosed;

  const OrderFormSheet({
    super.key,
    required this.dailyRecapId,
    required this.existing,
    required this.nextUrutan,
    this.isClosed = false,
  });

  @override
  State<OrderFormSheet> createState() => _OrderFormSheetState();
}

class _OrderFormSheetState extends State<OrderFormSheet> {
  late String _type;
  late bool _isFuelExpense;
  late String _platformSelected;
  late String _walletTypeSelected;
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
      _isFuelExpense = e.isFuelExpense;
      _walletTypeSelected = e.walletType;
      if (e.walletType.startsWith('grab_') || (e.platform?.toLowerCase().contains('grab') ?? false)) {
        _platformSelected = 'Grab';
      } else {
        _platformSelected = 'ShopeeFood';
      }

      if (e.saldoTopUp > 0) {
        _type = 'topup';
      } else if (e.expense > 0 && e.income == 0) {
        _type = 'expense';
      } else {
        _type = 'order';
      }
    } else {
      _type = 'order';
      _isFuelExpense = false;
      _platformSelected = 'ShopeeFood';
      _walletTypeSelected = 'shopeefood';
    }

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
    if (widget.isClosed) return;
    String? keterangan;
    double income = 0;
    double deductCashApp = 0;
    double custPay = 0;
    double custChange = 0;
    double saldoTopUp = 0;
    double expense = 0;
    bool isFuel = false;

    if (_type == 'order') {
      income = _n(_income);
      expense = _n(_expense);
      custPay = _n(_custPay);
      custChange = _n(_custChange);
      deductCashApp = _n(_deductCashApp);
      isFuel = _isFuelExpense;
    } else if (_type == 'topup') {
      keterangan = _keterangan.text.trim().isEmpty ? null : _keterangan.text.trim();
      saldoTopUp = _n(_saldoTopUp);
      deductCashApp = _n(_deductCashApp);
    } else if (_type == 'expense') {
      keterangan = _keterangan.text.trim().isEmpty ? null : _keterangan.text.trim();
      expense = _n(_expense);
      isFuel = _isFuelExpense;
    }

    final order = DailyOrder(
      id: widget.existing?.id,
      dailyRecapId: widget.dailyRecapId,
      urutan: widget.existing?.urutan ?? widget.nextUrutan,
      platform: _platformSelected,
      keterangan: keterangan,
      income: income,
      deductCashApp: deductCashApp,
      custPay: custPay,
      custChange: custChange,
      saldoTopUp: saldoTopUp,
      expense: expense,
      isFuelExpense: isFuel,
      walletType: _walletTypeSelected,
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

            // Dropdown Pilihan Platform Utama (ShopeeFood vs Grab)
            const Text(
              'Layanan / Platform',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: SegmentedButton<String>(
                segments: const [
                  ButtonSegment(
                    value: 'ShopeeFood',
                    label: Text('ShopeeFood'),
                    icon: Icon(Icons.fastfood_outlined, size: 18),
                  ),
                  ButtonSegment(
                    value: 'Grab',
                    label: Text('Grab'),
                    icon: Icon(Icons.local_taxi_outlined, size: 18),
                  ),
                ],
                selected: {_platformSelected},
                onSelectionChanged: widget.isClosed
                    ? null
                    : (newVal) {
                        setState(() {
                          _platformSelected = newVal.first;
                          if (_platformSelected == 'ShopeeFood') {
                            _walletTypeSelected = 'shopeefood';
                          } else {
                            _walletTypeSelected = 'grab_kredit';
                          }
                        });
                      },
              ),
            ),
            
            // Dropdown Pilihan Wallet Grab jika Grab terpilih
            if (_platformSelected == 'Grab') ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _walletTypeSelected,
                decoration: const InputDecoration(
                  labelText: 'Pilih Dompet Grab',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
                items: const [
                  DropdownMenuItem(value: 'grab_kredit', child: Text('Grab Kredit (Komisi/Potongan)')),
                  DropdownMenuItem(value: 'grab_tunai', child: Text('Grab Tunai (E-Wallet Driver)')),
                  DropdownMenuItem(value: 'grab_ovo', child: Text('OVO (Wallet Penumpang/Tip)')),
                ],
                onChanged: widget.isClosed ? null : (val) {
                  if (val != null) {
                    setState(() {
                      _walletTypeSelected = val;
                    });
                  }
                },
              ),
            ],
            
            const SizedBox(height: 20),
            
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
                onSelectionChanged: widget.isClosed
                    ? null
                    : (newSelection) {
                        setState(() {
                          _type = newSelection.first;
                        });
                      },
              ),
            ),
            const SizedBox(height: 20),

            // Form Fields conditional rendering
            if (_type == 'order') ...[
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
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Ada biaya bensin dalam order ini'),
                value: _isFuelExpense,
                onChanged: widget.isClosed
                    ? null
                    : (v) {
                        setState(() {
                          _isFuelExpense = v ?? false;
                        });
                      },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ] else if (_type == 'topup') ...[
              TextField(
                controller: _keterangan,
                enabled: !widget.isClosed,
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
                enabled: !widget.isClosed,
                decoration: const InputDecoration(
                  labelText: 'Keterangan Pengeluaran (misal: Beli Bensin, Makan)',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              _num('Nominal Pengeluaran', _expense),
              const SizedBox(height: 8),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Pengeluaran ini untuk beli bensin (BBM)'),
                value: _isFuelExpense,
                onChanged: widget.isClosed
                    ? null
                    : (v) {
                        setState(() {
                          _isFuelExpense = v ?? false;
                        });
                      },
                controlAffinity: ListTileControlAffinity.leading,
              ),
            ],
            
            const SizedBox(height: 12),
            TextField(
              controller: _remark,
              enabled: !widget.isClosed,
              decoration: const InputDecoration(
                labelText: 'Catatan Tambahan (opsional)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: widget.isClosed ? null : _submit,
                child: Text(widget.isClosed ? 'Transaksi Terkunci (Closed)' : 'Simpan Transaksi'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _num(String label, TextEditingController ctrl) => TextField(
        controller: ctrl,
        enabled: !widget.isClosed,
        keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
          isDense: true,
        ),
      );
}
