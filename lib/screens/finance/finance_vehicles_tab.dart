import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../logic/ledger_math.dart';
import '../../models/vehicle.dart';
import '../../providers/finance_providers.dart';
import '../home_screen.dart' show currency;
import '../fuel_filling_sheet.dart';
import 'service_form_sheet.dart';
import 'service_item_sheet.dart';
import 'vehicle_log_sheet.dart';

class FinanceVehiclesTab extends ConsumerStatefulWidget {
  const FinanceVehiclesTab({super.key});

  @override
  ConsumerState<FinanceVehiclesTab> createState() => _FinanceVehiclesTabState();
}

class _FinanceVehiclesTabState extends ConsumerState<FinanceVehiclesTab> {
  String? _selectedVehicleId;

  @override
  Widget build(BuildContext context) {
    final vehiclesAsync = ref.watch(vehiclesProvider);
    final serviceDueAsync = ref.watch(serviceDueProvider);

    return vehiclesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Gagal memuat motor: $e'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () => ref.invalidate(vehiclesProvider),
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
      data: (vehicles) {
        if (vehicles.isEmpty) {
          return ListView(
            padding: const EdgeInsets.all(24),
            children: [
              const SizedBox(height: 100),
              const Center(
                child: Column(
                  children: [
                    Icon(Icons.two_wheeler, size: 64, color: Colors.grey),
                    SizedBox(height: 16),
                    Text(
                      'Belum Ada Motor Terdaftar',
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.grey),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Daftarkan motor (Jupiter Z & Aerox) untuk mencatat odometer harian, BBM, dan reminder servis berkala.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Center(
                child: ElevatedButton.icon(
                  onPressed: () => _showSeedVehiclesDialog(context),
                  icon: const Icon(Icons.add),
                  label: const Text('Inisialisasi Jupiter Z & Aerox'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2E7D32),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 24, vertical: 12),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
            ],
          );
        }

        final selectedVehicle = vehicles.firstWhere(
          (v) => v.id == _selectedVehicleId,
          orElse: () => vehicles.first,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
          children: [
            // Pilihan Motor (Pills / Cards)
            Row(
              children: vehicles.map((v) {
                final isSelected = v.id == selectedVehicle.id;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: InkWell(
                      onTap: () => setState(() => _selectedVehicleId = v.id),
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 12),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? const Color(0xFF2E7D32)
                              : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? const Color(0xFF2E7D32)
                                : Colors.grey.shade300,
                          ),
                          boxShadow: [
                            if (isSelected)
                              BoxShadow(
                                color: const Color(0xFF2E7D32).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                          ],
                        ),
                        child: Column(
                          children: [
                            Icon(
                              Icons.two_wheeler,
                              color: isSelected
                                  ? Colors.white
                                  : Colors.grey.shade700,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              v.name,
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                                color:
                                    isSelected ? Colors.white : Colors.black87,
                              ),
                            ),
                            if (v.plateHint != null)
                              Text(
                                v.plateHint!,
                                style: TextStyle(
                                  fontSize: 11,
                                  color: isSelected
                                      ? Colors.white70
                                      : Colors.grey.shade600,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Detail Motor Terpilih
            _buildVehicleHeroCard(context, selectedVehicle),
            const SizedBox(height: 20),

            // Bagian Bahan Bakar & Efisiensi (Fase 5)
            _buildFuelEfficiencySection(context, selectedVehicle),
            const SizedBox(height: 20),

            // Bagian Servis Berkala
            _buildPeriodicServiceSection(
                context, selectedVehicle, serviceDueAsync),
            const SizedBox(height: 20),

            // Bagian Riwayat Servis
            _buildServiceHistorySection(context, selectedVehicle),
          ],
        );
      },
    );
  }

  Widget _buildVehicleHeroCard(BuildContext context, Vehicle vehicle) {
    return FutureBuilder<double>(
      future: ref.read(ledgerServiceProvider).currentOdometer(vehicle.id),
      builder: (context, snapshot) {
        final odo = snapshot.data ?? vehicle.odoInitial;

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.speed,
                          color: Colors.greenAccent, size: 28),
                      const SizedBox(width: 8),
                      Text(
                        vehicle.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  if (vehicle.plateHint != null)
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white12,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        vehicle.plateHint!,
                        style: const TextStyle(
                            color: Colors.white70, fontSize: 11),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              const Text(
                'Odometer Saat Ini',
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
              const SizedBox(height: 4),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Text(
                    odo.toStringAsFixed(1),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(width: 6),
                  const Text('km',
                      style:
                          TextStyle(color: Colors.greenAccent, fontSize: 16)),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (_) => VehicleLogSheet(vehicle: vehicle),
                        );
                      },
                      icon: const Icon(Icons.add_road, size: 14),
                      label: const Text('Km Hari Ini',
                          style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showFuelFillingSheet(
                          context,
                          null,
                          preselectedVehicleId: vehicle.id,
                        );
                      },
                      icon: const Icon(Icons.local_gas_station, size: 14),
                      label: const Text('Catat BBM',
                          style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () {
                        showModalBottomSheet(
                          context: context,
                          isScrollControlled: true,
                          backgroundColor: Colors.white,
                          shape: const RoundedRectangleBorder(
                            borderRadius:
                                BorderRadius.vertical(top: Radius.circular(24)),
                          ),
                          builder: (_) => ServiceFormSheet(vehicle: vehicle),
                        );
                      },
                      icon: const Icon(Icons.build, size: 14),
                      label:
                          const Text('Servis', style: TextStyle(fontSize: 12)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: const BorderSide(color: Colors.white30),
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 4),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildFuelEfficiencySection(BuildContext context, Vehicle vehicle) {
    final fuelStatsAsync = ref.watch(vehicleFuelStatsProvider(vehicle.id));
    final fillingsAsync = ref.watch(vehicleFuelFillingsProvider(vehicle.id));

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade50,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(Icons.local_gas_station_rounded,
                        color: Colors.orange.shade800, size: 20),
                  ),
                  const SizedBox(width: 10),
                  const Text(
                    'Bahan Bakar & Efisiensi',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF0F172A),
                    ),
                  ),
                ],
              ),
              TextButton.icon(
                onPressed: () {
                  showFuelFillingSheet(
                    context,
                    null,
                    preselectedVehicleId: vehicle.id,
                  );
                },
                icon: const Icon(Icons.add, size: 16, color: Color(0xFF2E7D32)),
                label: const Text(
                  'Catat BBM',
                  style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          fuelStatsAsync.when(
            data: (stats) {
              final lastLitersStr = stats.lastLiters != null
                  ? '${stats.lastLiters!.toStringAsFixed(2)} L'
                  : '-';
              final kmPerLStr = stats.kmPerLiter != null
                  ? '${stats.kmPerLiter!.toStringAsFixed(1)} km/L'
                  : '-';

              return Row(
                children: [
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Pengisian Terakhir',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(lastLitersStr,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF0F172A))),
                          if (stats.lastFillingDate != null)
                            Text(
                              DateFormat('d MMM yyyy', 'id_ID')
                                  .format(stats.lastFillingDate!),
                              style: TextStyle(
                                  fontSize: 10, color: Colors.grey.shade500),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF8FAFC),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Efisiensi Riil',
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey.shade600)),
                          const SizedBox(height: 4),
                          Text(kmPerLStr,
                              style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF2E7D32))),
                          Text(
                            stats.kmPerLiter != null
                                ? 'Antar isi penuh'
                                : 'Perlu 2x isi odo',
                            style: TextStyle(
                                fontSize: 10, color: Colors.grey.shade500),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
            loading: () => const Center(
              child: Padding(
                padding: EdgeInsets.all(8.0),
                child: CircularProgressIndicator(),
              ),
            ),
            error: (_, __) => const SizedBox.shrink(),
          ),
          const SizedBox(height: 12),

          // Riwayat Pengisian BBM Terakhir
          fillingsAsync.when(
            data: (fillings) {
              if (fillings.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Center(
                    child: Text(
                      'Belum ada catatan BBM untuk ${vehicle.name}.',
                      style:
                          TextStyle(color: Colors.grey.shade500, fontSize: 11),
                    ),
                  ),
                );
              }
              return Column(
                children: fillings.take(3).map((f) {
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.check_circle_outline,
                                size: 14, color: Colors.green),
                            const SizedBox(width: 6),
                            Text(
                              DateFormat('d MMM yyyy', 'id_ID')
                                  .format(f.tanggal),
                              style: const TextStyle(fontSize: 12),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '${f.liter.toStringAsFixed(1)}L',
                              style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.grey.shade700,
                                  fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                        Text(
                          currency.format(f.totalBiaya.round()),
                          style: const TextStyle(
                              fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),
        ],
      ),
    );
  }

  Widget _buildPeriodicServiceSection(
    BuildContext context,
    Vehicle vehicle,
    AsyncValue<List<dynamic>> serviceDueAsync,
  ) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Servis Berkala',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline,
                    color: Color(0xFF2E7D32)),
                tooltip: 'Tambah Item Servis',
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.white,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(24)),
                    ),
                    builder: (_) => ServiceItemSheet(vehicle: vehicle),
                  );
                },
              ),
            ],
          ),
          const SizedBox(height: 8),
          serviceDueAsync.when(
            loading: () => const LinearProgressIndicator(),
            error: (e, _) => Text('Error: $e'),
            data: (dueList) {
              final vehicleItems =
                  dueList.where((d) => d.item.vehicleId == vehicle.id).toList();

              if (vehicleItems.isEmpty) {
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Column(
                      children: [
                        Text(
                          'Belum ada item servis berkala untuk ${vehicle.name}.',
                          style: TextStyle(
                              color: Colors.grey.shade600, fontSize: 12),
                        ),
                        const SizedBox(height: 8),
                        TextButton.icon(
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              backgroundColor: Colors.white,
                              shape: const RoundedRectangleBorder(
                                borderRadius: BorderRadius.vertical(
                                    top: Radius.circular(24)),
                              ),
                              builder: (_) =>
                                  ServiceItemSheet(vehicle: vehicle),
                            );
                          },
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text('Tambah Item (Oli/Busi/Filter)',
                              style: TextStyle(fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return Column(
                children: vehicleItems.map((d) {
                  return _buildServiceItemTile(context, vehicle, d);
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildServiceItemTile(
      BuildContext context, Vehicle vehicle, dynamic due) {
    final item = due.item;
    final status = due.status as ServiceStatus;
    final remKm = due.remainingKm as double?;
    final remDays = due.remainingDays as int?;

    Color badgeColor;
    Color badgeBg;
    String statusText;

    switch (status) {
      case ServiceStatus.overdue:
        badgeColor = Colors.red.shade800;
        badgeBg = Colors.red.shade100;
        statusText = 'Lewat Tempo';
        break;
      case ServiceStatus.soon:
        badgeColor = Colors.amber.shade900;
        badgeBg = Colors.amber.shade100;
        statusText = 'Segera';
        break;
      case ServiceStatus.ok:
        badgeColor = Colors.green.shade800;
        badgeBg = Colors.green.shade100;
        statusText = 'Aman';
        break;
      case ServiceStatus.unknown:
        badgeColor = Colors.grey.shade800;
        badgeBg = Colors.grey.shade200;
        statusText = 'Belum Ada Data';
        break;
    }

    String subtitleDetails = '';
    if (remKm != null) {
      subtitleDetails += remKm >= 0
          ? 'Sisa ${remKm.toStringAsFixed(0)} km'
          : 'Lewat ${(-remKm).toStringAsFixed(0)} km';
    }
    if (remDays != null) {
      if (subtitleDetails.isNotEmpty) subtitleDetails += ' · ';
      subtitleDetails +=
          remDays >= 0 ? 'Sisa $remDays hari' : 'Lewat ${-remDays} hari';
    }
    if (subtitleDetails.isEmpty) {
      subtitleDetails =
          'Interval: ${item.intervalKm != null ? '${item.intervalKm} km' : ''}${item.intervalDays != null ? ' / ${item.intervalDays} hari' : ''}';
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                          fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: badgeBg,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        statusText,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: badgeColor,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  subtitleDetails,
                  style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                ),
              ],
            ),
          ),
          ElevatedButton(
            onPressed: () {
              showModalBottomSheet(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.white,
                shape: const RoundedRectangleBorder(
                  borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
                ),
                builder: (_) =>
                    ServiceFormSheet(vehicle: vehicle, selectedItem: item),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              minimumSize: const Size(60, 30),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text('Servis', style: TextStyle(fontSize: 11)),
          ),
        ],
      ),
    );
  }

  Widget _buildServiceHistorySection(BuildContext context, Vehicle vehicle) {
    return FutureBuilder<List<dynamic>>(
      future: ref.read(ledgerServiceProvider).getServiceRecords(vehicle.id),
      builder: (context, snapshot) {
        final records = snapshot.data ?? [];

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Riwayat Servis',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF0F172A),
                ),
              ),
              const SizedBox(height: 12),
              if (records.isEmpty) ...[
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Center(
                    child: Text(
                      'Belum ada riwayat servis untuk ${vehicle.name}.',
                      style:
                          TextStyle(color: Colors.grey.shade600, fontSize: 12),
                    ),
                  ),
                ),
              ] else ...[
                ...records.take(5).map((r) {
                  return ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    leading: const CircleAvatar(
                      backgroundColor: Color(0xFFE8F5E9),
                      child:
                          Icon(Icons.build, size: 16, color: Color(0xFF2E7D32)),
                    ),
                    title: Text(
                      r.shop ?? 'Bengkel',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    subtitle: Text(
                      '${DateFormat('d MMM yyyy', 'id_ID').format(r.tanggal)}${r.odometer != null ? ' · ${r.odometer.toStringAsFixed(0)} km' : ''}',
                      style:
                          TextStyle(fontSize: 11, color: Colors.grey.shade600),
                    ),
                    trailing: Text(
                      currency.format(r.cost),
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  );
                }),
              ],
            ],
          ),
        );
      },
    );
  }

  void _showSeedVehiclesDialog(BuildContext context) {
    final jupiterOdoCtrl = TextEditingController(text: '0');
    final aeroxOdoCtrl = TextEditingController(text: '0');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Inisialisasi Motor'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Masukkan odometer awal untuk kedua motor Anda (angka interval servis diisi manual nanti sesuai kebutuhan):',
              style: TextStyle(fontSize: 12, color: Colors.black54),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: jupiterOdoCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Odometer Awal Jupiter Z (km)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: aeroxOdoCtrl,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Odometer Awal Aerox (km)',
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          ElevatedButton(
            onPressed: () async {
              final ledgerService = ref.read(ledgerServiceProvider);
              final jupiterOdo = double.tryParse(jupiterOdoCtrl.text) ?? 0;
              final aeroxOdo = double.tryParse(aeroxOdoCtrl.text) ?? 0;

              await ledgerService.saveVehicle(
                Vehicle.create(name: 'Jupiter Z', odoInitial: jupiterOdo),
              );
              await ledgerService.saveVehicle(
                Vehicle.create(name: 'Aerox', odoInitial: aeroxOdo),
              );

              ref.invalidate(vehiclesProvider);
              ref.invalidate(serviceDueProvider);

              if (context.mounted) {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Jupiter Z & Aerox berhasil didaftarkan!'),
                    backgroundColor: Color(0xFF2E7D32),
                    behavior: SnackBarBehavior.floating,
                  ),
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E7D32),
              foregroundColor: Colors.white,
            ),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }
}
