import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/account.dart';
import '../../providers/finance_providers.dart';

class AccountFormSheet extends ConsumerStatefulWidget {
  final Account? existingAccount;

  const AccountFormSheet({super.key, this.existingAccount});

  @override
  ConsumerState<AccountFormSheet> createState() => _AccountFormSheetState();
}

class _AccountFormSheetState extends ConsumerState<AccountFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _balanceController = TextEditingController();

  late String _kind;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingAccount != null) {
      final a = widget.existingAccount!;
      _nameController.text = a.name;
      _kind = a.kind;
      _balanceController.text = a.openingBalance.toString();
    } else {
      _kind = 'bank';
      _balanceController.text = '0';
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  Future<void> _saveAccount() async {
    if (!_formKey.currentState!.validate()) return;

    final balance = int.tryParse(_balanceController.text.replaceAll('.', '')) ?? 0;

    setState(() => _isLoading = true);

    try {
      final ledgerService = ref.read(ledgerServiceProvider);
      final account = widget.existingAccount != null
          ? widget.existingAccount!.copyWith(
              name: _nameController.text.trim(),
              kind: _kind,
              openingBalance: balance,
            )
          : Account.create(
              name: _nameController.text.trim(),
              kind: _kind,
              openingBalance: balance,
            );

      await ledgerService.saveAccount(account);

      ref.invalidate(accountsProvider);
      ref.invalidate(accountBalancesProvider);
      ref.invalidate(monthSummaryProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingAccount != null
                ? 'Rekening diperbarui'
                : 'Rekening ditambahkan'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan rekening: $e'),
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
    final isEdit = widget.existingAccount != null;

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
                    isEdit ? 'Ubah Rekening' : 'Tambah Rekening',
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
              const SizedBox(height: 12),

              // Peringatan Privasi (Wajib sesuai panduan)
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.shield_outlined, color: Colors.blue.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Demi keamanan privasi, gunakan nama panggilan saja (mis. BCA, Dompet Tunai). Dilarang memasukkan nomor rekening/kartu.',
                        style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),

              // Nama Rekening
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Panggilan Rekening',
                  hintText: 'Contoh: BCA, Tunai, Dana, ShopeePay',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Nama rekening wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Jenis Rekening (SegmentedButton)
              const Text(
                'Jenis Rekening',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 6),
              Center(
                child: SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'cash',
                      label: Text('Tunai'),
                      icon: Icon(Icons.payments_outlined),
                    ),
                    ButtonSegment(
                      value: 'bank',
                      label: Text('Bank'),
                      icon: Icon(Icons.account_balance_outlined),
                    ),
                    ButtonSegment(
                      value: 'ewallet',
                      label: Text('E-Wallet'),
                      icon: Icon(Icons.account_balance_wallet_outlined),
                    ),
                  ],
                  selected: {_kind},
                  onSelectionChanged: (val) => setState(() => _kind = val.first),
                ),
              ),
              const SizedBox(height: 16),

              // Saldo Awal
              TextFormField(
                controller: _balanceController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: 'Saldo Awal (Rp)',
                  prefixText: 'Rp ',
                  helperText: 'Saldo sebelum pencatatan dimulai di aplikasi',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty) return 'Saldo awal wajib diisi';
                  final n = int.tryParse(val.replaceAll('.', ''));
                  if (n == null || n < 0) return 'Saldo awal tidak boleh negatif';
                  return null;
                },
              ),
              const SizedBox(height: 24),

              // Tombol Simpan
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _saveAccount,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.save),
                  label: Text(
                    isEdit ? 'Simpan Perubahan' : 'Tambah Rekening',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
