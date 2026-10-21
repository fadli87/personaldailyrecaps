import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/service_item.dart';
import '../../models/vehicle.dart';
import '../../providers/finance_providers.dart';

class ServiceItemSheet extends ConsumerStatefulWidget {
  final Vehicle vehicle;
  final ServiceItem? existingItem;

  const ServiceItemSheet({
    super.key,
    required this.vehicle,
    this.existingItem,
  });

  @override
  ConsumerState<ServiceItemSheet> createState() => _ServiceItemSheetState();
}

class _ServiceItemSheetState extends ConsumerState<ServiceItemSheet> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _intervalKmController = TextEditingController();
  final _intervalDaysController = TextEditingController();
  final _lastOdoController = TextEditingController();

  DateTime? _lastServiceDate;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    if (widget.existingItem != null) {
      final item = widget.existingItem!;
      _nameController.text = item.name;
      _intervalKmController.text = item.intervalKm?.toString() ?? '';
      _intervalDaysController.text = item.intervalDays?.toString() ?? '';
      _lastOdoController.text = item.lastServiceOdo?.toStringAsFixed(1) ?? '';
      _lastServiceDate = item.lastServiceDate;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _intervalKmController.dispose();
    _intervalDaysController.dispose();
    _lastOdoController.dispose();
    super.dispose();
  }

  Future<void> _pickLastDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _lastServiceDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
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
      setState(() => _lastServiceDate = picked);
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final km = int.tryParse(_intervalKmController.text.trim());
    final days = int.tryParse(_intervalDaysController.text.trim());

    if (km == null && days == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'Isi minimal salah satu interval: Interval Km atau Interval Hari.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final ledgerService = ref.read(ledgerServiceProvider);
      final item = widget.existingItem != null
          ? widget.existingItem!.copyWith(
              name: _nameController.text.trim(),
              intervalKm: km,
              intervalDays: days,
              lastServiceDate: _lastServiceDate,
              lastServiceOdo: double.tryParse(_lastOdoController.text.trim()),
            )
          : ServiceItem.create(
              vehicleId: widget.vehicle.id,
              name: _nameController.text.trim(),
              intervalKm: km,
              intervalDays: days,
              lastServiceDate: _lastServiceDate,
              lastServiceOdo: double.tryParse(_lastOdoController.text.trim()),
            );

      await ledgerService.saveServiceItem(item);

      ref.invalidate(serviceDueProvider);

      if (mounted) {
        Navigator.pop(context, true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(widget.existingItem != null
                ? 'Item servis diperbarui'
                : 'Item servis ditambahkan'),
            backgroundColor: const Color(0xFF2E7D32),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan item servis: $e'),
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
    final isEdit = widget.existingItem != null;

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
                    isEdit
                        ? 'Ubah Item Servis'
                        : 'Tambah Item Servis: ${widget.vehicle.name}',
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

              // Penjelasan
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Text(
                  'Angka interval selalu diisi oleh pengguna (sesuai buku manual/aplikasi Yamaha Motor On). Minimal salah satu interval (km atau hari) wajib diisi.',
                  style: TextStyle(fontSize: 12, color: Colors.blue.shade900),
                ),
              ),
              const SizedBox(height: 16),

              // Nama Item
              TextFormField(
                controller: _nameController,
                decoration: InputDecoration(
                  labelText: 'Nama Item Servis',
                  hintText:
                      'Misal: Oli Mesin, Oli Gardan, Busi, Filter Udara, Kampas Rem',
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                ),
                validator: (val) {
                  if (val == null || val.trim().isEmpty)
                    return 'Nama item servis wajib diisi';
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Interval Km & Hari
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      controller: _intervalKmController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Interval Km',
                        suffixText: 'km',
                        hintText: 'Mis. 3000',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextFormField(
                      controller: _intervalDaysController,
                      keyboardType: TextInputType.number,
                      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                      decoration: InputDecoration(
                        labelText: 'Interval Hari',
                        suffixText: 'hari',
                        hintText: 'Mis. 60 / 90',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              const Text(
                'Data Servis Terakhir (Opsional)',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),
              const SizedBox(height: 8),

              // Tanggal & Odo Terakhir
              Row(
                children: [
                  Expanded(
                    flex: 5,
                    child: InkWell(
                      onTap: _pickLastDate,
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
                              _lastServiceDate != null
                                  ? DateFormat('d MMM yyyy', 'id_ID')
                                      .format(_lastServiceDate!)
                                  : 'Pilih Tanggal',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: _lastServiceDate != null
                                    ? Colors.black87
                                    : Colors.grey,
                              ),
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
                      controller: _lastOdoController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        labelText: 'Odometer Terakhir',
                        suffixText: 'km',
                        border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
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
                      : const Icon(Icons.build),
                  label: Text(
                    isEdit ? 'Simpan Item Servis' : 'Tambah Item Servis',
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
