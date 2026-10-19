import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../models/fuel_filling.dart';
import '../providers/recap_providers.dart';

class FuelFillingFormSheet extends ConsumerStatefulWidget {
  final String dailyRecapId;
  final FuelFilling? existingFilling;

  const FuelFillingFormSheet({
    super.key,
    required this.dailyRecapId,
    this.existingFilling,
  });

  @override
  ConsumerState<FuelFillingFormSheet> createState() => _FuelFillingFormSheetState();
}

class _FuelFillingFormSheetState extends ConsumerState<FuelFillingFormSheet> {
  final _formKey = GlobalKey<FormState>();
  final _literController = TextEditingController();
  final _hargaController = TextEditingController();
  final _totalController = TextEditingController();
  final _odometerController = TextEditingController();
  final _catatanController = TextEditingController();
  
  DateTime _selectedDate = DateTime.now();
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
    } else {
      // Default harga BBM saat ini
      _hargaController.text = '13500'; // Harga Pertamax sekitar 13.500
    }
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
      
      if (widget.existingFilling != null) {
        final updated = widget.existingFilling!.copyWith(
          tanggal: _selectedDate,
          liter: liter,
          hargaPerLiter: hargaPerLiter,
          totalBiaya: totalBiaya,
          odometer: odometer,
          catatan: _catatanController.text.isEmpty ? null : _catatanController.text,
        );
        await ref.read(recapDetailNotifierProvider(widget.dailyRecapId).notifier).updateFuelFilling(updated);
      } else {
        final newFilling = FuelFilling.create(
          dailyRecapId: widget.dailyRecapId,
          tanggal: _selectedDate,
          liter: liter,
          hargaPerLiter: hargaPerLiter,
          totalBiaya: totalBiaya,
          odometer: odometer,
          catatan: _catatanController.text.isEmpty ? null : _catatanController.text,
        );
        await ref.read(recapDetailNotifierProvider(widget.dailyRecapId).notifier).addFuelFilling(newFilling);
      }
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingFilling != null 
                ? 'Pengisian BBM diperbarui' 
                : 'Pengisian BBM ditambahkan'),
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
                    child: const Icon(Icons.local_gas_station_rounded, color: Colors.white, size: 24),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isEdit ? 'Edit Pengisian BBM' : 'Tambah Pengisian BBM',
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF0F172A),
                          ),
                        ),
                        Text(
                          'Catat kapan & berapa liter isi tangki',
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              
              // Tanggal
              InkWell(
                onTap: _pickDate,
                child: InputDecorator(
                  decoration: InputDecoration(
                    labelText: 'Tanggal Pengisian',
                    prefixIcon: const Icon(Icons.calendar_today_rounded, color: Color(0xFF2E7D32)),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: Colors.grey.shade50,
                  ),
                  child: Text(
                    DateFormat('dd MMM yyyy', 'id_ID').format(_selectedDate),
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
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
                        prefixIcon: const Icon(Icons.opacity_rounded, color: Color(0xFF2E7D32)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Wajib diisi';
                        final val = double.tryParse(v);
                        if (val == null || val <= 0) return 'Masukkan angka valid';
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
                        prefixIcon: const Icon(Icons.attach_money_rounded, color: Color(0xFF2E7D32)),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        filled: true,
                        fillColor: Colors.grey.shade50,
                      ),
                      keyboardType: TextInputType.number,
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Wajib diisi';
                        final val = double.tryParse(v);
                        if (val == null || val <= 0) return 'Masukkan angka valid';
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
                  prefixIcon: const Icon(Icons.receipt_long_rounded, color: Color(0xFF2E7D32)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                  labelText: 'Kilometer (Opsional)',
                  suffixText: 'KM',
                  prefixIcon: const Icon(Icons.speed_rounded, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  helperText: 'Untuk tracking konsumsi per KM',
                ),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              
              // Catatan
              TextFormField(
                controller: _catatanController,
                decoration: InputDecoration(
                  labelText: 'Catatan (Opsional)',
                  prefixIcon: const Icon(Icons.note_alt_rounded, color: Colors.grey),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  filled: true,
                  fillColor: Colors.grey.shade50,
                  hintText: 'Contoh: Isi full di SPBU Pertamina Jalan Sudirman',
                ),
                maxLines: 2,
              ),
              const SizedBox(height: 24),
              
              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isLoading ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        side: BorderSide(color: Colors.grey.shade300),
                      ),
                      child: const Text('Batal', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
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
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        elevation: 2,
                      ),
                      child: _isLoading
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : Text(
                              isEdit ? 'Simpan Perubahan' : 'Tambah Pengisian',
                              style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
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
void showFuelFillingSheet(BuildContext context, String dailyRecapId, {FuelFilling? existingFilling}) {
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
      ),
    ),
  );
}