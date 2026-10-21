import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/ledger_transaction.dart';
import '../../providers/finance_providers.dart';

class TransactionFormSheet extends ConsumerStatefulWidget {
  final LedgerTransaction? existingTransaction;
  final String? initialKind;
  final String? initialActivity;
  final String? initialPool;

  const TransactionFormSheet({
    super.key,
    this.existingTransaction,
    this.initialKind,
    this.initialActivity,
    this.initialPool,
  });

  @override
  ConsumerState<TransactionFormSheet> createState() =>
      _TransactionFormSheetState();
}

class _TransactionFormSheetState extends ConsumerState<TransactionFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _categoryController = TextEditingController();
  final _noteController = TextEditingController();

  late String _kind; // income, expense, transfer
  late DateTime _tanggal;
  String? _accountId;
  String? _toAccountId;
  late String _pool; // utama, tambahan
  String? _toPool; // utama, tambahan
  late String _activity; // kanvasing, ojol, pribadi, kendaraan
  String? _vehicleId;
  bool _isPending = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final tx = widget.existingTransaction;
    if (tx != null) {
      _kind = tx.kind;
      _tanggal = tx.tanggal;
      _amountController.text = tx.amount.toString();
      _accountId = tx.accountId;
      _toAccountId = tx.toAccountId;
      _pool = tx.pool;
      _toPool = tx.toPool;
      _activity = tx.activity;
      _vehicleId = tx.vehicleId;
      _categoryController.text = tx.category ?? '';
      _noteController.text = tx.note ?? '';
      _isPending = tx.status == 'pending';
    } else {
      _kind = widget.initialKind ?? 'income';
      _tanggal = DateTime.now();
      _pool = widget.initialPool ?? 'utama';
      _toPool = 'utama';
      _activity = widget.initialActivity ?? 'kanvasing';
      _loadLastPreferences();
    }
  }

  Future<void> _loadLastPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _accountId ??= prefs.getString('last_ledger_account_id');
      if (widget.initialPool == null) {
        _pool = prefs.getString('last_ledger_pool') ?? _pool;
      }
      if (widget.initialActivity == null) {
        _activity = prefs.getString('last_ledger_activity') ?? _activity;
      }
      _vehicleId = prefs.getString('last_ledger_vehicle_id');
    });
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF2E7D32),
              onPrimary: Colors.white,
              surface: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() => _tanggal = picked);
    }
  }

  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final rawAmount = int.tryParse(_amountController.text.replaceAll('.', ''));
    if (rawAmount == null || rawAmount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Nominal harus berupa angka bulat positif.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih rekening sumber.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (_kind == 'transfer') {
      if (_toAccountId == null || _toPool == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pilih rekening dan kas tujuan transfer.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
      if (_accountId == _toAccountId && _pool == _toPool) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Rekening dan kas tujuan tidak boleh sama persis dengan sumber.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }
    }

    setState(() => _isLoading = true);

    try {
      final ledgerService = ref.read(ledgerServiceProvider);
      final tx = widget.existingTransaction != null
          ? widget.existingTransaction!.copyWith(
              tanggal: _tanggal,
              kind: _kind,
              amount: rawAmount,
              accountId: _accountId!,
              toAccountId: _kind == 'transfer' ? _toAccountId : null,
              pool: _pool,
              toPool: _kind == 'transfer' ? _toPool : null,
              activity: _kind == 'transfer' ? 'pribadi' : _activity,
              category: _categoryController.text.trim().isEmpty
                  ? null
                  : _categoryController.text.trim(),
              vehicleId: (_activity == 'kendaraan' && _kind != 'transfer')
                  ? _vehicleId
                  : null,
              status: (_kind == 'income' && _isPending) ? 'pending' : 'cleared',
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            )
          : LedgerTransaction.create(
              tanggal: _tanggal,
              kind: _kind,
              amount: rawAmount,
              accountId: _accountId!,
              toAccountId: _kind == 'transfer' ? _toAccountId : null,
              pool: _pool,
              toPool: _kind == 'transfer' ? _toPool : null,
              activity: _kind == 'transfer' ? 'pribadi' : _activity,
              category: _categoryController.text.trim().isEmpty
                  ? null
                  : _categoryController.text.trim(),
              vehicleId: (_activity == 'kendaraan' && _kind != 'transfer')
                  ? _vehicleId
                  : null,
              status: (_kind == 'income' && _isPending) ? 'pending' : 'cleared',
              note: _noteController.text.trim().isEmpty
                  ? null
                  : _noteController.text.trim(),
            );

      if (widget.existingTransaction != null) {
        await ledgerService.updateTransaction(tx);
      } else {
        await ledgerService.addTransaction(tx);
      }

      // Simpan preferensi terakhir
      final prefs = await SharedPreferences.getInstance();
      if (_accountId != null)
        await prefs.setString('last_ledger_account_id', _accountId!);
      await prefs.setString('last_ledger_pool', _pool);
      await prefs.setString('last_ledger_activity', _activity);
      if (_vehicleId != null)
        await prefs.setString('last_ledger_vehicle_id', _vehicleId!);

      // Segarkan provider terkait
      ref.invalidate(accountBalancesProvider);
      ref.invalidate(poolBalancesProvider);
      ref.invalidate(monthSummaryProvider);
      ref.invalidate(transactionsProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingTransaction != null
                ? 'Transaksi berhasil diperbarui'
                : 'Transaksi berhasil disimpan'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan transaksi: $e'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final accountsAsync = ref.watch(accountsProvider);
    final vehiclesAsync = ref.watch(vehiclesProvider);

    final isEdit = widget.existingTransaction != null;

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: 20,
        right: 20,
        top: 20,
      ),
      child: SingleChildScrollView(
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Title
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Ubah Transaksi' : 'Catat Transaksi',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Segmented Button Kind
              Center(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'income',
                      label: Text('Pemasukan'),
                      icon: Icon(Icons.arrow_downward, color: Colors.green),
                    ),
                    ButtonSegment(
                      value: 'expense',
                      label: Text('Pengeluaran'),
                      icon: Icon(Icons.arrow_upward, color: Colors.red),
                    ),
                    ButtonSegment(
                      value: 'transfer',
                      label: Text('Transfer'),
                      icon: Icon(Icons.swap_horiz, color: Colors.blue),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (val) {
                    setState(() {
                      _kind = val.first;
                      if (_kind == 'transfer') {
                        _activity = 'pribadi';
                        _isPending = false;
                      }
                    });
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Tanggal & Nominal
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('d MMM yyyy', 'id_ID')
                                  .format(_tanggal),
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const Icon(Icons.calendar_today,
                                size: 18, color: Color(0xFF2E7D32)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Nominal (Rp)',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty)
                          return 'Wajib diisi';
                        final n = int.tryParse(val.replaceAll('.', ''));
                        if (n == null || n <= 0) return 'Nominal > 0';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Rekening & Kas Sumber
              accountsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Gagal memuat rekening: $e'),
                data: (accounts) {
                  final activeAccounts =
                      accounts.where((a) => a.isActive).toList();
                  if (activeAccounts.isNotEmpty && _accountId == null) {
                    _accountId = activeAccounts.first.id;
                  }
                  return Row(
                    children: [
                      Expanded(
                        flex: 6,
                        child: DropdownButtonFormField<String>(
                          value: activeAccounts.any((a) => a.id == _accountId)
                              ? _accountId
                              : null,
                          decoration: InputDecoration(
                            labelText: _kind == 'transfer'
                                ? 'Dari Rekening'
                                : 'Rekening',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          items: activeAccounts.map((a) {
                            return DropdownMenuItem(
                              value: a.id,
                              child: Text('${a.name} (${a.kindText})'),
                            );
                          }).toList(),
                          onChanged: (val) => setState(() => _accountId = val),
                          validator: (val) =>
                              val == null ? 'Pilih rekening' : null,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        flex: 4,
                        child: DropdownButtonFormField<String>(
                          value: _pool,
                          decoration: InputDecoration(
                            labelText: _kind == 'transfer' ? 'Dari Kas' : 'Kas',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12)),
                          ),
                          items: const [
                            DropdownMenuItem(
                                value: 'utama', child: Text('Utama')),
                            DropdownMenuItem(
                                value: 'tambahan', child: Text('Tambahan')),
                          ],
                          onChanged: (val) =>
                              setState(() => _pool = val ?? 'utama'),
                        ),
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),

              // Jika Transfer -> Rekening & Kas Tujuan
              if (_kind == 'transfer') ...[
                accountsAsync.when(
                  loading: () => const SizedBox(),
                  error: (_, __) => const SizedBox(),
                  data: (accounts) {
                    final activeAccounts =
                        accounts.where((a) => a.isActive).toList();
                    if (activeAccounts.isNotEmpty && _toAccountId == null) {
                      _toAccountId = activeAccounts.first.id;
                    }
                    return Row(
                      children: [
                        Expanded(
                          flex: 6,
                          child: DropdownButtonFormField<String>(
                            value:
                                activeAccounts.any((a) => a.id == _toAccountId)
                                    ? _toAccountId
                                    : null,
                            decoration: InputDecoration(
                              labelText: 'Ke Rekening',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            items: activeAccounts.map((a) {
                              return DropdownMenuItem(
                                value: a.id,
                                child: Text('${a.name} (${a.kindText})'),
                              );
                            }).toList(),
                            onChanged: (val) =>
                                setState(() => _toAccountId = val),
                            validator: (val) =>
                                val == null ? 'Pilih tujuan' : null,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          flex: 4,
                          child: DropdownButtonFormField<String>(
                            value: _toPool ?? 'utama',
                            decoration: InputDecoration(
                              labelText: 'Ke Kas',
                              border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(12)),
                            ),
                            items: const [
                              DropdownMenuItem(
                                  value: 'utama', child: Text('Utama')),
                              DropdownMenuItem(
                                  value: 'tambahan', child: Text('Tambahan')),
                            ],
                            onChanged: (val) =>
                                setState(() => _toPool = val ?? 'utama'),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),
              ],

              // Jika Bukan Transfer -> Aktivitas & (Kategori / Kendaraan)
              if (_kind != 'transfer') ...[
                Row(
                  children: [
                    Expanded(
                      flex: 5,
                      child: DropdownButtonFormField<String>(
                        value: _activity,
                        decoration: InputDecoration(
                          labelText: 'Aktivitas',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                        items: const [
                          DropdownMenuItem(
                              value: 'kanvasing', child: Text('Kanvasing')),
                          DropdownMenuItem(value: 'ojol', child: Text('Ojol')),
                          DropdownMenuItem(
                              value: 'pribadi', child: Text('Pribadi')),
                          DropdownMenuItem(
                              value: 'kendaraan',
                              child: Text('Kendaraan (Bersama)')),
                        ],
                        onChanged: (val) =>
                            setState(() => _activity = val ?? 'kanvasing'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 5,
                      child: TextFormField(
                        controller: _categoryController,
                        decoration: InputDecoration(
                          labelText: 'Kategori',
                          hintText: _activity == 'kendaraan'
                              ? 'bbm / servis'
                              : 'komisi / makan',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Jika aktivitas Kendaraan -> Pilih Motor
                if (_activity == 'kendaraan') ...[
                  vehiclesAsync.when(
                    loading: () => const LinearProgressIndicator(),
                    error: (e, _) => Text('Gagal memuat motor: $e'),
                    data: (vehicles) {
                      final activeVehicles =
                          vehicles.where((v) => v.isActive).toList();
                      if (activeVehicles.isNotEmpty && _vehicleId == null) {
                        _vehicleId = activeVehicles.first.id;
                      }
                      return DropdownButtonFormField<String>(
                        value: activeVehicles.any((v) => v.id == _vehicleId)
                            ? _vehicleId
                            : null,
                        decoration: InputDecoration(
                          labelText: 'Motor Terkait',
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12)),
                          helperText:
                              'Biaya motor akan dialokasikan menurut km aktivitas',
                        ),
                        items: activeVehicles.map((v) {
                          return DropdownMenuItem(
                            value: v.id,
                            child: Text(v.name +
                                (v.plateHint != null
                                    ? ' (${v.plateHint})'
                                    : '')),
                          );
                        }).toList(),
                        onChanged: (val) => setState(() => _vehicleId = val),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                ],

                // Switch Belum Cair (Hanya Pemasukan)
                if (_kind == 'income') ...[
                  Container(
                    decoration: BoxDecoration(
                      color: _isPending
                          ? Colors.amber.shade50
                          : Colors.grey.shade50,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _isPending
                            ? Colors.amber.shade400
                            : Colors.grey.shade300,
                      ),
                    ),
                    child: SwitchListTile(
                      title: const Text(
                        'Komisi Belum Cair (Pending)',
                        style: TextStyle(
                            fontWeight: FontWeight.w600, fontSize: 14),
                      ),
                      subtitle: Text(
                        _isPending
                            ? 'Tidak masuk saldo rekening hingga ditandai cair.'
                            : 'Langsung masuk saldo rekening (cleared).',
                        style: TextStyle(
                            fontSize: 12, color: Colors.grey.shade700),
                      ),
                      value: _isPending,
                      activeColor: Colors.amber.shade800,
                      onChanged: (val) => setState(() => _isPending = val),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
              ],

              // Catatan
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Catatan (Opsional)',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              // Submit Button
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveTransaction,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    isEdit ? 'Simpan Perubahan' : 'Catat Transaksi',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
