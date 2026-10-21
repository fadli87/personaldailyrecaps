import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../../models/ledger_transaction.dart';
import '../../providers/finance_providers.dart';
import '../home_screen.dart' show currency;
import 'transaction_form_sheet.dart';

class FinanceTransactionsTab extends ConsumerStatefulWidget {
  const FinanceTransactionsTab({super.key});

  @override
  ConsumerState<FinanceTransactionsTab> createState() =>
      _FinanceTransactionsTabState();
}

class _FinanceTransactionsTabState
    extends ConsumerState<FinanceTransactionsTab> {
  String? _filterPool;
  String? _filterActivity;
  String? _filterKind;
  String? _filterStatus;

  @override
  Widget build(BuildContext context) {
    final selectedMonth = ref.watch(financeMonthProvider);
    final accountsAsync = ref.watch(accountsProvider);

    final filter = TransactionFilter(
      startDate: DateTime(selectedMonth.year, selectedMonth.month, 1),
      endDate: DateTime(selectedMonth.year, selectedMonth.month + 1, 0),
      pool: _filterPool,
      activity: _filterActivity,
      kind: _filterKind,
      status: _filterStatus,
    );

    final txsAsync = ref.watch(transactionsProvider(filter));

    return Column(
      children: [
        // Filter Chips Row
        Container(
          color: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                // Filter Kas
                _buildFilterChip<String?>(
                  label: _filterPool == null
                      ? 'Kas: Semua'
                      : 'Kas: ${_filterPool == 'utama' ? 'Utama' : 'Tambahan'}',
                  isSelected: _filterPool != null,
                  onSelected: () => _showFilterDialog(
                    title: 'Pilih Kas',
                    options: {
                      'Semua': null,
                      'Kas Utama': 'utama',
                      'Kas Tambahan': 'tambahan'
                    },
                    current: _filterPool,
                    onPick: (val) => setState(() => _filterPool = val),
                  ),
                ),
                const SizedBox(width: 8),

                // Filter Aktivitas
                _buildFilterChip<String?>(
                  label: _filterActivity == null
                      ? 'Aktivitas: Semua'
                      : 'Aktivitas: $_filterActivity',
                  isSelected: _filterActivity != null,
                  onSelected: () => _showFilterDialog(
                    title: 'Pilih Aktivitas',
                    options: {
                      'Semua': null,
                      'Kanvasing': 'kanvasing',
                      'Ojol': 'ojol',
                      'Pribadi': 'pribadi',
                      'Kendaraan': 'kendaraan',
                    },
                    current: _filterActivity,
                    onPick: (val) => setState(() => _filterActivity = val),
                  ),
                ),
                const SizedBox(width: 8),

                // Filter Jenis
                _buildFilterChip<String?>(
                  label: _filterKind == null
                      ? 'Jenis: Semua'
                      : 'Jenis: ${_filterKind == 'income' ? 'Pemasukan' : (_filterKind == 'expense' ? 'Pengeluaran' : 'Transfer')}',
                  isSelected: _filterKind != null,
                  onSelected: () => _showFilterDialog(
                    title: 'Pilih Jenis Transaksi',
                    options: {
                      'Semua': null,
                      'Pemasukan': 'income',
                      'Pengeluaran': 'expense',
                      'Transfer': 'transfer',
                    },
                    current: _filterKind,
                    onPick: (val) => setState(() => _filterKind = val),
                  ),
                ),
                const SizedBox(width: 8),

                // Filter Status
                _buildFilterChip<String?>(
                  label: _filterStatus == null
                      ? 'Status: Semua'
                      : (_filterStatus == 'pending'
                          ? 'Belum Cair (Pending)'
                          : 'Cleared'),
                  isSelected: _filterStatus != null,
                  onSelected: () => _showFilterDialog(
                    title: 'Pilih Status',
                    options: {
                      'Semua': null,
                      'Belum Cair (Pending)': 'pending',
                      'Cleared': 'cleared'
                    },
                    current: _filterStatus,
                    onPick: (val) => setState(() => _filterStatus = val),
                  ),
                ),

                // Reset Filters
                if (_filterPool != null ||
                    _filterActivity != null ||
                    _filterKind != null ||
                    _filterStatus != null) ...[
                  const SizedBox(width: 8),
                  TextButton.icon(
                    onPressed: () {
                      setState(() {
                        _filterPool = null;
                        _filterActivity = null;
                        _filterKind = null;
                        _filterStatus = null;
                      });
                    },
                    icon: const Icon(Icons.clear, size: 16),
                    label: const Text('Reset', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ],
            ),
          ),
        ),
        const Divider(height: 1),

        // Daftar Transaksi
        Expanded(
          child: txsAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Gagal memuat transaksi: $e'),
                  const SizedBox(height: 8),
                  ElevatedButton(
                    onPressed: () => ref.invalidate(transactionsProvider),
                    child: const Text('Coba Lagi'),
                  ),
                ],
              ),
            ),
            data: (transactions) {
              if (transactions.isEmpty) {
                return ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: const [
                    SizedBox(height: 120),
                    Center(
                      child: Column(
                        children: [
                          Icon(Icons.receipt_long_outlined,
                              size: 56, color: Colors.grey),
                          SizedBox(height: 12),
                          Text(
                            'Belum ada transaksi di bulan ini.',
                            style: TextStyle(
                                color: Colors.grey,
                                fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text(
                            'Tekan tombol + untuk mencatat transaksi baru.',
                            style: TextStyle(color: Colors.grey, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              }

              // Kelompokkan per tanggal
              final Map<String, List<LedgerTransaction>> grouped = {};
              for (final tx in transactions) {
                final dateKey = DateFormat('yyyy-MM-dd').format(tx.tanggal);
                grouped.putIfAbsent(dateKey, () => []).add(tx);
              }

              final dateKeys = grouped.keys.toList();

              return accountsAsync.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Text('Error accounts: $e'),
                data: (accounts) {
                  final accountNames = {for (final a in accounts) a.id: a.name};

                  return ListView.builder(
                    itemCount: dateKeys.length,
                    padding: const EdgeInsets.only(bottom: 80),
                    itemBuilder: (context, index) {
                      final dateStr = dateKeys[index];
                      final dayTxs = grouped[dateStr]!;
                      final parsedDate = DateTime.parse(dateStr);

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header Tanggal
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 8),
                            color: const Color(0xFFF8FAFC),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  DateFormat('EEEE, d MMM yyyy', 'id_ID')
                                      .format(parsedDate),
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Color(0xFF334155),
                                  ),
                                ),
                                Text(
                                  '${dayTxs.length} transaksi',
                                  style: TextStyle(
                                      fontSize: 11,
                                      color: Colors.grey.shade600),
                                ),
                              ],
                            ),
                          ),

                          // Daftar transaksi pada tanggal ini
                          ...dayTxs.map((tx) {
                            return _buildTransactionTile(
                                context, tx, accountNames);
                          }),
                        ],
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip<T>({
    required String label,
    required bool isSelected,
    required VoidCallback onSelected,
  }) {
    return FilterChip(
      label: Text(label,
          style: TextStyle(
              fontSize: 12, color: isSelected ? Colors.white : Colors.black87)),
      selected: isSelected,
      selectedColor: const Color(0xFF2E7D32),
      backgroundColor: Colors.grey.shade100,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
    );
  }

  void _showFilterDialog({
    required String title,
    required Map<String, String?> options,
    required String? current,
    required void Function(String?) onPick,
  }) {
    showDialog(
      context: context,
      builder: (ctx) => SimpleDialog(
        title: Text(title,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        children: options.entries.map((e) {
          final isCurrent = e.value == current;
          return SimpleDialogOption(
            onPressed: () {
              Navigator.pop(ctx);
              onPick(e.value);
            },
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(e.key,
                    style: TextStyle(
                        fontWeight:
                            isCurrent ? FontWeight.bold : FontWeight.normal)),
                if (isCurrent)
                  const Icon(Icons.check, size: 18, color: Color(0xFF2E7D32)),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildTransactionTile(
    BuildContext context,
    LedgerTransaction tx,
    Map<String, String> accountNames,
  ) {
    final isIncome = tx.kind == 'income';
    final isExpense = tx.kind == 'expense';
    final isTransfer = tx.kind == 'transfer';
    final isPending = tx.status == 'pending';

    final accName = accountNames[tx.accountId] ?? 'Rekening';
    final toAccName = tx.toAccountId != null
        ? accountNames[tx.toAccountId] ?? 'Rekening'
        : null;

    IconData icon;
    Color iconColor;
    if (isIncome) {
      icon = Icons.arrow_downward;
      iconColor = isPending ? Colors.amber.shade800 : Colors.green.shade700;
    } else if (isExpense) {
      icon = Icons.arrow_upward;
      iconColor = Colors.red.shade700;
    } else {
      icon = Icons.swap_horiz;
      iconColor = Colors.blue.shade700;
    }

    String subtitleText;
    if (isTransfer) {
      subtitleText = '$accName (${tx.pool}) → $toAccName (${tx.toPool})';
    } else {
      final act = tx.activity == 'kanvasing'
          ? 'Kanvasing'
          : (tx.activity == 'ojol'
              ? 'Ojol'
              : (tx.activity == 'kendaraan' ? 'Kendaraan' : 'Pribadi'));
      final cat = tx.category != null ? ' · ${tx.category}' : '';
      subtitleText = '$accName (${tx.pool}) · $act$cat';
    }

    return Dismissible(
      key: Key('tx_${tx.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        color: Colors.red.shade700,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Icon(Icons.delete_outline, color: Colors.white),
            SizedBox(width: 8),
            Text('Hapus',
                style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
      confirmDismiss: (dir) async {
        return true;
      },
      onDismissed: (dir) async {
        final ledgerService = ref.read(ledgerServiceProvider);
        await ledgerService.softDeleteTransaction(tx.id);

        ref.invalidate(transactionsProvider);
        ref.invalidate(monthSummaryProvider);
        ref.invalidate(accountBalancesProvider);
        ref.invalidate(poolBalancesProvider);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Transaksi dihapus'),
              action: SnackBarAction(
                label: 'Urungkan',
                onPressed: () async {
                  // Pulihkan dengan menghapus deleted_at
                  await ledgerService.updateTransaction(
                    tx.copyWith(deletedAt: null),
                  );
                  ref.invalidate(transactionsProvider);
                  ref.invalidate(monthSummaryProvider);
                  ref.invalidate(accountBalancesProvider);
                  ref.invalidate(poolBalancesProvider);
                },
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: iconColor.withOpacity(0.12),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                tx.note?.isNotEmpty == true
                    ? tx.note!
                    : (isTransfer
                        ? 'Transfer Saldo'
                        : (tx.category ??
                            (isIncome ? 'Pemasukan' : 'Pengeluaran'))),
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              (isIncome ? '+' : (isExpense ? '-' : '')) +
                  currency.format(tx.amount),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 14,
                color: isIncome
                    ? (isPending
                        ? Colors.amber.shade800
                        : Colors.green.shade700)
                    : (isExpense ? Colors.red.shade700 : Colors.blue.shade700),
              ),
            ),
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(subtitleText,
                style: TextStyle(fontSize: 12, color: Colors.grey.shade700)),
            if (isPending) ...[
              const SizedBox(height: 4),
              Row(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Belum Cair',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: Colors.amber.shade900,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  InkWell(
                    onTap: () async {
                      await ref.read(ledgerServiceProvider).markCleared(tx.id);
                      ref.invalidate(transactionsProvider);
                      ref.invalidate(monthSummaryProvider);
                      ref.invalidate(accountBalancesProvider);
                      ref.invalidate(poolBalancesProvider);
                    },
                    child: Text(
                      'Tandai Cair',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.green.shade800,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
        onTap: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => TransactionFormSheet(existingTransaction: tx),
          );
        },
      ),
    );
  }
}
