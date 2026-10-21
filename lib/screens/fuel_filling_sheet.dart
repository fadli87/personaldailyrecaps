import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/fuel_filling.dart';
import '../providers/finance_providers.dart';
import '../providers/recap_providers.dart';

class FuelFillingFormSheet extends ConsumerStatefulWidget {
  final String? dailyRecapId;
  final FuelFilling? existingFilling;
  final String? preselectedVehicleId;

  const FuelFillingFormSheet({
    super.key,
    this.dailyRecapId,
    this.existingFilling,
    this.preselectedVehicleId,
  });

  @override
  ConsumerState<FuelFillingFormSheet> createState() =>
      _FuelFillingFormSheetState();
}

class _FuelFillingFormSheetState extends ConsumerState<FuelFillingFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _literController = TextEditingController();
  final _hargaController = TextEditingController();
  final _totalController = TextEditingController();
  final _odometerController = TextEditingController();
  final _catatanController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedVehicleId;
  bool _recordInFinance = true;
  String? _selectedAccountId;
  String _selectedPool = 'utama';
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingFilling != null) {
      final f = widget.existingFilling!;
      _literController.text = f.liter.toStringAsFixed(2);
      _hargaController.text = f.hargaPerLiter.toStringAsFixed(0);
      _totalController.text = f.totalBiaya.toStringAsFixed(0);
      _odometerController.text = f.odometer?.toStringAsFixed(0) ?? '';
      _catatanController.text = f.catatan ?? '';
      _selectedDate = f.tanggal;
      _selectedVehicleId = f.vehicleId;

      // Muat transaksi terkait jika ada
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final tx = await ref
            .read(ledgerServiceProvider)
            .getLinkedFuelTransaction(f.id);
        if (mounted) {
          setState(() {
            if (tx != null) {
              _recordInFinance = true;
              _selectedAccountId = tx.accountId;
              _selectedPool = tx.pool;
            } else {
              _recordInFinance = false;
            }
          });
        }
      });
    } else {
      _selectedVehicleId = widget.preselectedVehicleId;
      _loadPreferences();
    }
  }

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      final lastPrice = prefs.getString('last_fuel_price');
      if (lastPrice != null && lastPrice.isNotEmpty) {
        _hargaController.text = lastPrice;
      }
      _selectedVehicleId ??= prefs.getString('last_fuel_vehicle_id');
      _selectedAccountId ??= prefs.getString('last_fuel_account_id');
      _selectedPool = prefs.getString('last_fuel_pool') ?? _selectedPool;
    });
  }

  @override
  void dispose() {
    _literController.dispose();
    _hargaController.dispose();
    _totalController.dispose();
    _odometerController.dispose();
    _catatanController.dispose();
    super.dispose();
  }

  void _calculateTotal() {
    final liter = double.tryParse(_literController.text) ?? 0;
    final harga = double.tryParse(_hargaController.text) ?? 0;
    _totalController.text = (liter * harga).toStringAsFixed(0);
  }

  void _calculateLiter() {
    final total = double.tryParse(_totalController.text) ?? 0;
    final harga = double.tryParse(_hargaController.text) ?? 0;
    if (harga > 0) {
      _literController.text = (total / harga).toStringAsFixed(2);
    }
  }

  Future<void> _pickDate() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 30)),
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
    if (date != null) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final liter = double.parse(_literController.text);
      final hargaPerLiter = double.parse(_hargaController.text);
      final totalBiaya = double.parse(_totalController.text);
      final odometer = _odometerController.text.isNotEmpty
          ? double.parse(_odometerController.text)
          : null;

      // Cari atau buat daily_recap_id bila tidak diberikan dari context
      String recapIdStr = widget.dailyRecapId ?? '';
      if (recapIdStr.isEmpty) {
        final existingRecap =
            await ref.read(recapServiceProvider).getRecapByDate(_selectedDate);
        if (existingRecap != null) {
          recapIdStr = existingRecap.id;
        } else {
          recapIdStr = await ref.read(recapServiceProvider).createRecap(
                tanggal: _selectedDate,
                cashAwal: 0,
                saldoAwalApp: 0,
              );
        }
      }

      final isEdit = widget.existingFilling != null;
      final filling = isEdit
          ? widget.existingFilling!.copyWith(
              dailyRecapId: recapIdStr,
              tanggal: _selectedDate,
              liter: liter,
              hargaPerLiter: hargaPerLiter,
              totalBiaya: totalBiaya,
              odometer: odometer,
              catatan: _catatanController.text.isEmpty
                  ? null
                  : _catatanController.text.trim(),
              vehicleId: _selectedVehicleId,
            )
          : FuelFilling.create(
              dailyRecapId: recapIdStr,
              tanggal: _selectedDate,
              liter: liter,
              hargaPerLiter: hargaPerLiter,
              totalBiaya: totalBiaya,
              odometer: odometer,
              catatan: _catatanController.text.isEmpty
                  ? null
                  : _catatanController.text.trim(),
              vehicleId: _selectedVehicleId,
            );

      // Simpan terintegrasi secara atomik ke fuel_fillings dan ledger transactions
      await ref.read(ledgerServiceProvider).saveFuelWithLedger(
            filling: filling,
            recordInFinance: _recordInFinance,
            accountId: _selectedAccountId,
            pool: _selectedPool,
            isEdit: isEdit,
          );

      // Simpan preferensi input terakhir
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString('last_fuel_price', _hargaController.text.trim());
      if (_selectedVehicleId != null) {
        await prefs.setString('last_fuel_vehicle_id', _selectedVehicleId!);
      }
      if (_selectedAccountId != null) {
        await prefs.setString('last_fuel_account_id', _selectedAccountId!);
      }
      await prefs.setString('last_fuel_pool', _selectedPool);

      // Refresh providers
      if (widget.dailyRecapId != null && widget.dailyRecapId!.isNotEmpty) {
        await ref
            .read(recapDetailNotifierProvider(widget.dailyRecapId!).notifier)
            .refreshSummary();
        ref.invalidate(fuelFillingsProvider(widget.dailyRecapId!));
      }
      ref.invalidate(allFuelFillingsProvider);
      ref.invalidate(poolBalancesProvider);
      ref.invalidate(accountBalancesProvider);
      ref.invalidate(monthSummaryProvider);
      ref.invalidate(transactionsProvider);
      if (_selectedVehicleId != null) {
        ref.invalidate(vehicleFuelStatsProvider(_selectedVehicleId!));
        ref.invalidate(vehicleFuelFillingsProvider(_selectedVehicleId!));
      }

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isEdit
                ? 'Pengisian BBM diperbarui'
                : 'Pengisian BBM berhasil dicatat'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
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
    final isEdit = widget.existingFilling != null;
    final vehiclesAsync = ref.watch(activeVehiclesProvider);
    final accountsAsync = ref.watch(activeAccountsProvider);

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
              const SizedBox(height: 20),

              // Title
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFFEF4444), Color(0xFFF97316)],
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.local_gas_station_rounded,
                        color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit
                              ? 'Edit Pengisian BBM'
                              : 'Tambah Pengisian BBM',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Catat konsumsi bahan bakar & integrasikan ke kas',
                          style: TextStyle(
                              fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Dropdown Motor (Wajib jika ada motor)
              vehiclesAsync.when(
                data: (vehicles) {
                  if (vehicles.isEmpty) return const SizedBox.shrink();

                  // Set default bila belum dipilih
                  if (_selectedVehicleId == null && vehicles.isNotEmpty) {
                    _selectedVehicleId = vehicles.first.id;
                  }

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: DropdownButtonFormField<String>(
                      value: _selectedVehicleId,
                      decoration: InputDecoration(
                        labelText: 'Pilih Motor *',
                        prefixIcon: const Icon(Icons.two_wheeler_rounded,
                            color: Color(0xFF2E7D32)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      items: vehicles.map((v) {
                        return DropdownMenuItem<String>(
                          value: v.id,
                          child: Text(
                            '${v.name}${v.plateHint != null ? ' (${v.plateHint})' : ''}',
                          ),
                        );
                      }).toList(),
                      validator: (val) {
                        if (vehicles.isNotEmpty &&
                            (val == null || val.isEmpty)) {
                          return 'Pilih motor terlebih dahulu';
                        }
                        return null;
                      },
                      onChanged: (val) =>
                          setState(() => _selectedVehicleId = val),
                    ),
                  );
                },
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),

              // Tanggal
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Tanggal Pengisian',
                    prefixIcon: const Icon(Icons.calendar_today_rounded,
                        color: Color(0xFF2E7D32)),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  child: Text(
                    DateFormat('dd MMM yyyy', 'id_ID').format(_selectedDate),
                    style: const TextStyle(
                        fontSize: 16, fontWeight: FontWeight.w500),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Liter & Harga per Liter (Row)
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _literController,
                      decoration: InputDecoration(
                        labelText: 'Liter',
                        suffixText: 'L',
                        prefixIcon: const Icon(Icons.opacity_rounded,
                            color: Color(0xFF2E7D32)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Wajib diisi';
                        final val = double.tryParse(v);
                        if (val == null || val <= 0) {
                          return 'Masukkan angka valid';
                        }
                        return null;
                      },
                      onChanged: (_) => _calculateTotal(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _hargaController,
                      decoration: InputDecoration(
                        labelText: 'Harga/Liter',
                        prefixText: 'Rp ',
                        prefixIcon: const Icon(Icons.attach_money_rounded,
                            color: Color(0xFF2E7D32)),
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Wajib diisi';
                        final val = double.tryParse(v);
                        if (val == null || val <= 0) {
                          return 'Masukkan angka valid';
                        }
                        return null;
                      },
                      onChanged: (_) => _calculateTotal(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Total Biaya
              TextFormField(
                controller: _totalController,
                decoration: InputDecoration(
                  labelText: 'Total Biaya (Otomatis)',
                  prefixText: 'Rp ',
                  prefixIcon: const Icon(Icons.receipt_long_rounded,
                      color: Color(0xFF2E7D32)),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade100,
                  helperText: 'Otomatis terhitung: Liter × Harga/Liter',
                ),
                keyboardType: TextInputType.number,
                onChanged: (_) => _calculateLiter(),
              ),
              const SizedBox(height: 16),

              // Odometer (Opsional)
              TextFormField(
                controller: _odometerController,
                decoration: InputDecoration(
                  labelText: 'Kilometer Odometer (Opsional)',
                  suffixText: 'KM',
                  prefixIcon:
                      const Icon(Icons.speed_rounded, color: Colors.grey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  helperText: 'Diperlukan untuk menghitung efisiensi (km/L)',
                ),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),

              // Catatan
              TextFormField(
                controller: _catatanController,
                decoration: InputDecoration(
                  labelText: 'Catatan (Opsional)',
                  prefixIcon:
                      const Icon(Icons.note_alt_rounded, color: Colors.grey),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  hintText: 'Contoh: Isi full di SPBU Pertamina',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 20),

              // Section: Catat di Keuangan (Fase 5)
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.grey.shade200),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SwitchListTile(
                      contentPadding:
                          const EdgeInsets.symmetric(horizontal: 16),
                      value: _recordInFinance,
                      activeColor: const Color(0xFF2E7D32),
                      title: const Text(
                        'Catat di Keuangan',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      subtitle: const Text(
                        'Buat pengeluaran BBM motor di buku kas secara otomatis',
                        style: TextStyle(fontSize: 11, color: Colors.grey),
                      ),
                      onChanged: (val) {
                        setState(() => _recordInFinance = val);
                      },
                    ),
                    if (_recordInFinance) ...[
                      const Divider(height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          children: [
                            // Rekening Pembayar
                            accountsAsync.when(
                              data: (accounts) {
                                if (accounts.isEmpty) {
                                  return const Text(
                                    'Belum ada rekening aktif. Tambahkan rekening di tab Keuangan.',
                                    style: TextStyle(
                                        color: Colors.red, fontSize: 12),
                                  );
                                }
                                _selectedAccountId ??= accounts.first.id;

                                return DropdownButtonFormField<String>(
                                  value: _selectedAccountId,
                                  decoration: InputDecoration(
                                    labelText: 'Rekening Pembayar *',
                                    prefixIcon: const Icon(
                                        Icons.account_balance_rounded,
                                        color: Color(0xFF2E7D32)),
                                    border: OutlineInputBorder(
                                        borderRadius:
                                            BorderRadius.circular(12)),
                                    filled: true,
                                    fillColor: Colors.white,
                                  ),
                                  items: accounts.map((acc) {
                                    return DropdownMenuItem<String>(
                                      value: acc.id,
                                      child:
                                          Text('${acc.name} (${acc.kindText})'),
                                    );
                                  }).toList(),
                                  validator: (v) {
                                    if (_recordInFinance &&
                                        (v == null || v.isEmpty)) {
                                      return 'Pilih rekening pembayar';
                                    }
                                    return null;
                                  },
                                  onChanged: (val) =>
                                      setState(() => _selectedAccountId = val),
                                );
                              },
                              loading: () => const LinearProgressIndicator(),
                              error: (_, __) => const SizedBox.shrink(),
                            ),
                            const SizedBox(height: 12),

                            // Pilihan Kas (Pool)
                            DropdownButtonFormField<String>(
                              value: _selectedPool,
                              decoration: InputDecoration(
                                labelText: 'Alokasi Kas *',
                                prefixIcon: const Icon(Icons.pie_chart_rounded,
                                    color: Color(0xFF2E7D32)),
                                border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12)),
                                filled: true,
                                fillColor: Colors.white,
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'utama',
                                  child:
                                      Text('Kas Utama (XL Satu / Kanvasing)'),
                                ),
                                DropdownMenuItem(
                                  value: 'tambahan',
                                  child: Text('Kas Tambahan (Ojol)'),
                                ),
                              ],
                              onChanged: (val) {
                                if (val != null) {
                                  setState(() => _selectedPool = val);
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed:
                          _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text('Batal',
                          style: TextStyle(
                              fontWeight: FontWeight.w600, fontSize: 16)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFEF4444),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isEdit ? 'Simpan Perubahan' : 'Tambah Pengisian',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w600, fontSize: 16),
                            ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }
}

// Helper function to show the bottom sheet
void showFuelFillingSheet(
  BuildContext context,
  String? dailyRecapId, {
  FuelFilling? existingFilling,
  String? preselectedVehicleId,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: FuelFillingFormSheet(
        dailyRecapId: dailyRecapId,
        existingFilling: existingFilling,
        preselectedVehicleId: preselectedVehicleId,
      ),
    ),
  );
}
