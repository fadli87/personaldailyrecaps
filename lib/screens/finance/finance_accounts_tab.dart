import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/account.dart';
import '../../providers/finance_providers.dart';
import '../home_screen.dart' show currency;
import 'account_form_sheet.dart';

class FinanceAccountsTab extends ConsumerWidget {
  const FinanceAccountsTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balancesAsync = ref.watch(accountBalancesProvider);
    final accountsAsync = ref.watch(accountsProvider);

    return balancesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Gagal memuat saldo rekening: $e'),
            const SizedBox(height: 8),
            ElevatedButton(
              onPressed: () {
                ref.invalidate(accountBalancesProvider);
                ref.invalidate(accountsProvider);
              },
              child: const Text('Coba Lagi'),
            ),
          ],
        ),
      ),
      data: (balances) {
        return accountsAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Text('Error accounts: $e'),
          data: (accounts) {
            final activeAccounts = accounts.where((a) => a.isActive).toList();
            final archivedAccounts = accounts.where((a) => !a.isActive).toList();

            final balanceMap = {for (final b in balances) b.accountId: b.balance};

            var totalBalance = 0;
            for (final a in activeAccounts) {
              totalBalance += balanceMap[a.id] ?? a.openingBalance;
            }

            if (accounts.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.all(24),
                children: [
                  const SizedBox(height: 100),
                  const Center(
                    child: Column(
                      children: [
                        Icon(Icons.account_balance_wallet_outlined, size: 64, color: Colors.grey),
                        SizedBox(height: 16),
                        Text(
                          'Belum Ada Rekening',
                          style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey),
                        ),
                        SizedBox(height: 8),
                        Text(
                          'Tambahkan rekening tunai, bank, atau e-wallet untuk mengelola saldo keuangan.',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  Center(
                    child: ElevatedButton.icon(
                      onPressed: () => _openAccountSheet(context),
                      icon: const Icon(Icons.add),
                      label: const Text('Tambah Rekening Pertama'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2E7D32),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                ],
              );
            }

            // Kelompokkan per jenis (Tunai, Bank, E-Wallet)
            final cashAccounts = activeAccounts.where((a) => a.kind == 'cash').toList();
            final bankAccounts = activeAccounts.where((a) => a.kind == 'bank').toList();
            final ewalletAccounts = activeAccounts.where((a) => a.kind == 'ewallet').toList();

            return ListView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 90),
              children: [
                // Total Likuiditas Card
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: Colors.grey.shade200),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 10,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Total Saldo Semua Rekening',
                            style: TextStyle(fontSize: 12, color: Colors.black54),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            currency.format(totalBalance),
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                        ],
                      ),
                      ElevatedButton.icon(
                        onPressed: () => _openAccountSheet(context),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Tambah', style: TextStyle(fontSize: 12)),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2E7D32),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Group 1: Kas Tunai
                if (cashAccounts.isNotEmpty) ...[
                  _buildAccountGroupHeader('Tunai (Cash)', Icons.payments_outlined, Colors.green.shade700),
                  ...cashAccounts.map((a) => _buildAccountTile(context, ref, a, balanceMap[a.id] ?? a.openingBalance)),
                  const SizedBox(height: 16),
                ],

                // Group 2: Bank
                if (bankAccounts.isNotEmpty) ...[
                  _buildAccountGroupHeader('Bank Transfer', Icons.account_balance_outlined, Colors.blue.shade700),
                  ...bankAccounts.map((a) => _buildAccountTile(context, ref, a, balanceMap[a.id] ?? a.openingBalance)),
                  const SizedBox(height: 16),
                ],

                // Group 3: E-Wallet
                if (ewalletAccounts.isNotEmpty) ...[
                  _buildAccountGroupHeader('E-Wallet', Icons.account_balance_wallet_outlined, Colors.purple.shade700),
                  ...ewalletAccounts.map((a) => _buildAccountTile(context, ref, a, balanceMap[a.id] ?? a.openingBalance)),
                  const SizedBox(height: 16),
                ],

                // Archived Accounts
                if (archivedAccounts.isNotEmpty) ...[
                  ExpansionTile(
                    title: Text(
                      'Rekening Diarsipkan (${archivedAccounts.length})',
                      style: TextStyle(fontSize: 13, color: Colors.grey.shade600),
                    ),
                    children: archivedAccounts.map((a) {
                      return ListTile(
                        title: Text(a.name, style: const TextStyle(decoration: TextDecoration.lineThrough)),
                        subtitle: Text(a.kindText),
                        trailing: TextButton(
                          onPressed: () async {
                            await ref.read(ledgerServiceProvider).saveAccount(a.copyWith(isActive: true));
                            ref.invalidate(accountsProvider);
                            ref.invalidate(accountBalancesProvider);
                          },
                          child: const Text('Aktifkan'),
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ],
            );
          },
        );
      },
    );
  }

  Widget _buildAccountGroupHeader(String title, IconData icon, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8, left: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAccountTile(
    BuildContext context,
    WidgetRef ref,
    Account account,
    int balance,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
        title: Text(
          account.name,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
        ),
        subtitle: Text(
          'Saldo awal: ${currency.format(account.openingBalance)}',
          style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  currency.format(balance),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                    color: balance >= 0 ? const Color(0xFF0F172A) : Colors.red.shade700,
                  ),
                ),
                InkWell(
                  onTap: () => _showReconcileDialog(context, ref, account, balance),
                  child: const Text(
                    'Cek Saldo',
                    style: TextStyle(
                      fontSize: 11,
                      color: Color(0xFF2E7D32),
                      fontWeight: FontWeight.bold,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(width: 8),
            PopupMenuButton<String>(
              icon: const Icon(Icons.more_vert, size: 20),
              onSelected: (val) async {
                if (val == 'edit') {
                  _openAccountSheet(context, account: account);
                } else if (val == 'archive') {
                  await ref.read(ledgerServiceProvider).archiveAccount(account.id);
                  ref.invalidate(accountsProvider);
                  ref.invalidate(accountBalancesProvider);
                }
              },
              itemBuilder: (ctx) => [
                const PopupMenuItem(value: 'edit', child: Text('Ubah Rekening')),
                const PopupMenuItem(value: 'archive', child: Text('Arsipkan')),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _openAccountSheet(BuildContext context, {Account? account}) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => AccountFormSheet(existingAccount: account),
    );
  }

  void _showReconcileDialog(
    BuildContext context,
    WidgetRef ref,
    Account account,
    int bookBalance,
  ) {
    final actualController = TextEditingController(text: bookBalance.toString());

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final actual = int.tryParse(actualController.text.replaceAll('.', '')) ?? bookBalance;
          final diff = actual - bookBalance;

          return AlertDialog(
            title: Text('Cek Saldo: ${account.name}'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Saldo buku saat ini: ${currency.format(bookBalance)}'),
                const SizedBox(height: 12),
                TextFormField(
                  controller: actualController,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                  decoration: const InputDecoration(
                    labelText: 'Saldo Asli dari Aplikasi / Dompet',
                    prefixText: 'Rp ',
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (_) => setDialogState(() {}),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: diff == 0 ? Colors.green.shade50 : (diff > 0 ? Colors.blue.shade50 : Colors.red.shade50),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: diff == 0 ? Colors.green.shade200 : (diff > 0 ? Colors.blue.shade200 : Colors.red.shade200),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text('Selisih:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      Text(
                        (diff > 0 ? '+' : '') + currency.format(diff),
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: diff == 0 ? Colors.green.shade800 : (diff > 0 ? Colors.blue.shade800 : Colors.red.shade800),
                        ),
                      ),
                    ],
                  ),
                ),
                if (diff != 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    diff > 0
                        ? 'Akan dicatat sebagai pemasukan penyesuaian saldo.'
                        : 'Akan dicatat sebagai pengeluaran penyesuaian saldo.',
                    style: TextStyle(fontSize: 11, color: Colors.grey.shade700),
                  ),
                ],
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
                  await ledgerService.reconcile(account.id, actual);

                  ref.invalidate(accountBalancesProvider);
                  ref.invalidate(poolBalancesProvider);
                  ref.invalidate(monthSummaryProvider);
                  ref.invalidate(transactionsProvider);

                  if (context.mounted) {
                    Navigator.pop(ctx);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(diff == 0
                            ? 'Saldo ${account.name} sudah cocok.'
                            : 'Penyesuaian saldo ${currency.format(diff.abs())} dicatat.'),
                        backgroundColor: const Color(0xFF2E7D32),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2E7D32),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Catat Penyesuaian'),
              ),
            ],
          );
        },
      ),
    );
  }
}
