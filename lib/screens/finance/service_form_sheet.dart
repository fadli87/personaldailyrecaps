import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/service_item.dart';
import '../../models/vehicle.dart';
import '../../providers/finance_providers.dart';

class ServiceFormSheet extends ConsumerStatefulWidget {
  final Vehicle vehicle;
  final ServiceItem? selectedItem;

  const ServiceFormSheet({
    super.key,
    required this.vehicle,
    this.selectedItem,
  });

  @override
  ConsumerState<ServiceFormSheet> createState() => _ServiceFormSheetState();
}

class _ServiceFormSheetState extends ConsumerState<ServiceFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _costController = TextEditingController();
  final _odometerController = TextEditingController();
  final _shopController = TextEditingController();
  final _noteController = TextEditingController();

  late DateTime _tanggal;
  String? _selectedServiceItemId;
  bool _recordExpenseInLedger = true;
  String? _accountId;
  String _pool = 'utama';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tanggal = DateTime.now();
    _selectedServiceItemId = widget.selectedItem?.id;
    _costController.text = '0';
    _loadCurrentOdometer();
  }

  Future<void> _loadCurrentOdometer() async {
    final ledgerService = ref.read(ledgerServiceProvider);
    final odo = await ledgerService.currentOdometer(widget.vehicle.id);
    if (mounted) {
      setState(() {
        _odometerController.text = odo.toStringAsFixed(1);
      });
    }
  }

  @override
  void dispose() {
    _costController.dispose();
    _odometerController.dispose();
    _shopController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 7)),
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

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final cost = int.tryParse(_costController.text.replaceAll('.', '')) ?? 0;
    if (_recordExpenseInLedger && cost > 0 && _accountId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Pilih rekening untuk pembayaran biaya servis.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ledgerService = ref.read(ledgerServiceProvider);
      await ledgerService.recordService(
        vehicleId: widget.vehicle.id,
        serviceItemId: _selectedServiceItemId,
        tanggal: _tanggal,
        odometer: double.tryParse(_odometerController.text),
        cost: cost,
        shop: _shopController.text.trim().isEmpty
            ? null
            : _shopController.text.trim(),
        note: _noteController.text.trim().isEmpty
            ? null
            : _noteController.text.trim(),
        accountId: (_recordExpenseInLedger && cost > 0) ? _accountId : null,
        pool: (_recordExpenseInLedger && cost > 0) ? _pool : 'utama',
      );

      ref.invalidate(serviceDueProvider);
      ref.invalidate(accountBalancesProvider);
      ref.invalidate(poolBalancesProvider);
      ref.invalidate(monthSummaryProvider);
      ref.invalidate(transactionsProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Servis ${widget.vehicle.name} berhasil dicatat'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal mencatat servis: $e'),
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
    final serviceItemsAsync = ref.watch(serviceDueProvider);

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
                    'Catat Servis: ${widget.vehicle.name}',
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

              // Dropdown Item Servis (Opsional)
              serviceItemsAsync.when(
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => const SizedBox(),
                data: (dueList) {
                  final vehicleItems = dueList
                      .where((d) => d.item.vehicleId == widget.vehicle.id)
                      .toList();
                  return DropdownButtonFormField<String>(
                    value: _selectedServiceItemId,
                    decoration: InputDecoration(
                      labelText: 'Item Servis Berkala (Opsional)',
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12)),
                      helperText:
                          'Pilih untuk memperbarui tanggal & km servis terakhir',
                    ),
                    items: [
                      const DropdownMenuItem<String>(
                        value: null,
                        child: Text('-- Servis Umum / Lainnya --'),
                      ),
                      ...vehicleItems.map((d) {
                        return DropdownMenuItem<String>(
                          value: d.item.id,
                          child: Text(d.item.name),
                        );
                      }),
                    ],
                    onChanged: (val) =>
                        setState(() => _selectedServiceItemId = val),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Tanggal & Odometer
              Row(
                children: [
                  Expanded(
                    flex: 5,
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
                    flex: 5,
                    child: TextFormField(
                      controller: _odometerController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Odometer (km)',
                        suffixText: 'km',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Biaya Servis & Bengkel
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _costController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Biaya Servis (Rp)',
                        prefixText: 'Rp ',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 5,
                    child: TextFormField(
                      controller: _shopController,
                      decoration: InputDecoration(
                        labelText: 'Nama Bengkel',
                        hintText: 'Mis. Yamaha Surya',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Integrasi Pembayaran ke Ledger
              if ((int.tryParse(_costController.text.replaceAll('.', '')) ??
                      0) >
                  0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.green.shade50,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.shade200),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Catat sebagai pengeluaran di Keuangan',
                            style: TextStyle(
                                fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          Switch(
                            value: _recordExpenseInLedger,
                            activeColor: const Color(0xFF2E7D32),
                            onChanged: (val) =>
                                setState(() => _recordExpenseInLedger = val),
                          ),
                        ],
                      ),
                      if (_recordExpenseInLedger) ...[
                        const SizedBox(height: 8),
                        accountsAsync.when(
                          loading: () => const LinearProgressIndicator(),
                          error: (_, __) => const SizedBox(),
                          data: (accounts) {
                            final activeAccounts =
                                accounts.where((a) => a.isActive).toList();
                            if (activeAccounts.isNotEmpty &&
                                _accountId == null) {
                              _accountId = activeAccounts.first.id;
                            }
                            return Row(
                              children: [
                                Expanded(
                                  flex: 6,
                                  child: DropdownButtonFormField<String>(
                                    value: activeAccounts
                                            .any((a) => a.id == _accountId)
                                        ? _accountId
                                        : null,
                                    decoration: InputDecoration(
                                      labelText: 'Rekening Pembayaran',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    items: activeAccounts.map((a) {
                                      return DropdownMenuItem(
                                        value: a.id,
                                        child:
                                            Text('${a.name} (${a.kindText})'),
                                      );
                                    }).toList(),
                                    onChanged: (val) =>
                                        setState(() => _accountId = val),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  flex: 4,
                                  child: DropdownButtonFormField<String>(
                                    value: _pool,
                                    decoration: InputDecoration(
                                      labelText: 'Kas',
                                      filled: true,
                                      fillColor: Colors.white,
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                    ),
                                    items: const [
                                      DropdownMenuItem(
                                          value: 'utama', child: Text('Utama')),
                                      DropdownMenuItem(
                                          value: 'tambahan',
                                          child: Text('Tambahan')),
                                    ],
                                    onChanged: (val) =>
                                        setState(() => _pool = val ?? 'utama'),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Catatan
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Deskripsi Pengerjaan / Part yang Diganti',
                  hintText: 'Mis. Ganti oli mesin Yamalube + kuras radiator',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 24),

              // Submit
              SizedBox(
                width: double.infinity,
                height: 48,
                child: ElevatedButton.icon(
                  onPressed: _isLoading ? null : _submit,
                  icon: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                              strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: const Text(
                    'Simpan Riwayat Servis',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
