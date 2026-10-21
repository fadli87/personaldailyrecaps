import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/vehicle.dart';
import '../../models/vehicle_log.dart';
import '../../providers/finance_providers.dart';

class VehicleLogSheet extends ConsumerStatefulWidget {
  final Vehicle vehicle;
  final VehicleLog? existingLog;

  const VehicleLogSheet({
    super.key,
    required this.vehicle,
    this.existingLog,
  });

  @override
  ConsumerState<VehicleLogSheet> createState() => _VehicleLogSheetState();
}

class _VehicleLogSheetState extends ConsumerState<VehicleLogSheet> {
  final _formKey = GlobalKey<FormState>();
  final _odoEndController = TextEditingController();
  final _kmKanvasingController = TextEditingController();
  final _kmOjolController = TextEditingController();
  final _kmPribadiController = TextEditingController();
  final _jamOnlineOjolController = TextEditingController();
  final _noteController = TextEditingController();

  late DateTime _tanggal;
  double _previousOdo = 0;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingLog != null) {
      final l = widget.existingLog!;
      _tanggal = l.tanggal;
      _odoEndController.text = l.odoEnd.toStringAsFixed(1);
      _kmKanvasingController.text = l.kmKanvasing.toStringAsFixed(1);
      _kmOjolController.text = l.kmOjol.toStringAsFixed(1);
      _kmPribadiController.text = l.kmPribadi.toStringAsFixed(1);
      _jamOnlineOjolController.text = l.jamOnlineOjol?.toStringAsFixed(1) ?? '';
      _noteController.text = l.note ?? '';
    } else {
      _tanggal = DateTime.now();
      _kmKanvasingController.text = '0';
      _kmOjolController.text = '0';
      _kmPribadiController.text = '0';
    }
    _loadPreviousOdometer();
  }

  Future<void> _loadPreviousOdometer() async {
    final ledgerService = ref.read(ledgerServiceProvider);
    final current = await ledgerService.currentOdometer(widget.vehicle.id);
    if (mounted) {
      setState(() {
        _previousOdo = current;
        if (widget.existingLog == null && _odoEndController.text.isEmpty) {
          _odoEndController.text = current.toStringAsFixed(1);
        }
      });
    }
  }

  @override
  void dispose() {
    _odoEndController.dispose();
    _kmKanvasingController.dispose();
    _kmOjolController.dispose();
    _kmPribadiController.dispose();
    _jamOnlineOjolController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _tanggal,
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
    if (picked != null) {
      setState(() => _tanggal = picked);
    }
  }

  double get _currentDiff {
    final odo = double.tryParse(_odoEndController.text) ?? _previousOdo;
    return odo >= _previousOdo ? odo - _previousOdo : 0;
  }

  double get _currentRecordedKm {
    final k = double.tryParse(_kmKanvasingController.text) ?? 0;
    final o = double.tryParse(_kmOjolController.text) ?? 0;
    final p = double.tryParse(_kmPribadiController.text) ?? 0;
    return k + o + p;
  }

  void _fillRemainingToPribadi() {
    final diff = _currentDiff;
    final k = double.tryParse(_kmKanvasingController.text) ?? 0;
    final o = double.tryParse(_kmOjolController.text) ?? 0;
    final remaining = (diff - k - o);
    setState(() {
      _kmPribadiController.text = (remaining > 0 ? remaining : 0).toStringAsFixed(1);
    });
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final odoEnd = double.tryParse(_odoEndController.text);
    if (odoEnd == null) return;

    if (odoEnd < _previousOdo && widget.existingLog == null) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Odometer Lebih Kecil'),
          content: Text(
            'Odometer yang dimasukkan ($odoEnd km) lebih kecil dari odometer sebelumnya ($_previousOdo km). Tetap lanjutkan?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.orange.shade800),
              child: const Text('Ya, Lanjutkan', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      );
      if (confirm != true) return;
    }

    setState(() => _isLoading = true);

    try {
      final ledgerService = ref.read(ledgerServiceProvider);
      final log = widget.existingLog != null
          ? widget.existingLog!.copyWith(
              tanggal: _tanggal,
              odoEnd: odoEnd,
              kmKanvasing: double.tryParse(_kmKanvasingController.text) ?? 0,
              kmOjol: double.tryParse(_kmOjolController.text) ?? 0,
              kmPribadi: double.tryParse(_kmPribadiController.text) ?? 0,
              jamOnlineOjol: double.tryParse(_jamOnlineOjolController.text),
              note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
            )
          : VehicleLog.create(
              vehicleId: widget.vehicle.id,
              tanggal: _tanggal,
              odoEnd: odoEnd,
              kmKanvasing: double.tryParse(_kmKanvasingController.text) ?? 0,
              kmOjol: double.tryParse(_kmOjolController.text) ?? 0,
              kmPribadi: double.tryParse(_kmPribadiController.text) ?? 0,
              jamOnlineOjol: double.tryParse(_jamOnlineOjolController.text),
              note: _noteController.text.trim().isEmpty ? null : _noteController.text.trim(),
            );

      await ledgerService.saveVehicleLog(log);

      ref.invalidate(monthSummaryProvider);
      ref.invalidate(serviceDueProvider);
      ref.invalidate(vehiclesProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Log km ${widget.vehicle.name} tersimpan'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan log: $e'),
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
    final diff = _currentDiff;
    final recorded = _currentRecordedKm;
    final hasDiscrepancy = (diff > 0 && (diff - recorded).abs() > 0.1);

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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Catat Km: ${widget.vehicle.name}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF0F172A),
                        ),
                      ),
                      Text(
                        'Odometer Sebelumnya: ${_previousOdo.toStringAsFixed(1)} km',
                        style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Tanggal & Odometer Akhir
              Row(
                children: [
                  Expanded(
                    flex: 4,
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('d MMM yyyy', 'id_ID').format(_tanggal),
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                            const Icon(Icons.calendar_today, size: 18, color: Color(0xFF2E7D32)),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 6,
                    child: TextFormField(
                      controller: _odoEndController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Odometer Akhir (km)',
                        suffixText: 'km',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onChanged: (_) => setState(() {}),
                      validator: (val) {
                        if (val == null || val.trim().isEmpty) return 'Wajib diisi';
                        final n = double.tryParse(val);
                        if (n == null || n < 0) return 'Angka tidak valid';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),

              // Bantuan Selisih Jarak & Auto-Distribusi ke Pribadi
              if (diff > 0) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: hasDiscrepancy ? Colors.amber.shade50 : Colors.green.shade50,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: hasDiscrepancy ? Colors.amber.shade300 : Colors.green.shade200,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Jarak Tempuh Hari Ini: ${diff.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: hasDiscrepancy ? Colors.amber.shade900 : Colors.green.shade900,
                            ),
                          ),
                          Text(
                            'Tercatat: ${recorded.toStringAsFixed(1)} km',
                            style: TextStyle(
                              fontSize: 12,
                              color: hasDiscrepancy ? Colors.amber.shade800 : Colors.green.shade800,
                            ),
                          ),
                        ],
                      ),
                      if (hasDiscrepancy) ...[
                        const SizedBox(height: 6),
                        InkWell(
                          onTap: _fillRemainingToPribadi,
                          child: Row(
                            children: [
                              Icon(Icons.auto_fix_high, size: 16, color: Colors.amber.shade900),
                              const SizedBox(width: 4),
                              Text(
                                'Masukkan sisa ${(diff - (double.tryParse(_kmKanvasingController.text) ?? 0) - (double.tryParse(_kmOjolController.text) ?? 0)).toStringAsFixed(1)} km ke Pribadi',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.amber.shade900,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // Pembagian km aktivitas
              const Text(
                'Pembagian Km Aktivitas',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _kmKanvasingController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Kanvasing',
                        suffixText: 'km',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _kmOjolController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Ojol',
                        suffixText: 'km',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextFormField(
                      controller: _kmPribadiController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Pribadi',
                        suffixText: 'km',
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onChanged: (_) => setState(() {}),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Jam Online Ojol
              TextFormField(
                controller: _jamOnlineOjolController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: InputDecoration(
                  labelText: 'Jam Online Ojol (Opsional)',
                  hintText: 'Contoh: 4.5',
                  suffixText: 'jam',
                  helperText: 'Untuk menghitung efisiensi pendapatan per jam ojol',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Catatan
              TextFormField(
                controller: _noteController,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Catatan Harian (Opsional)',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
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
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : const Icon(Icons.speed),
                  label: const Text(
                    'Simpan Log Odometer',
                    style: TextStyle(fontWeight: FontWeight.bold),
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
