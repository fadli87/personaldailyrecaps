import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'finance_summary_tab.dart';
import 'finance_transactions_tab.dart';
import 'finance_accounts_tab.dart';
import 'finance_vehicles_tab.dart';
import 'transaction_form_sheet.dart';
import 'account_form_sheet.dart';

class FinanceHomeScreen extends ConsumerStatefulWidget {
  const FinanceHomeScreen({super.key});

  @override
  ConsumerState<FinanceHomeScreen> createState() => _FinanceHomeScreenState();
}

class _FinanceHomeScreenState extends ConsumerState<FinanceHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) {
        setState(() {});
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _navigateToTab(int index) {
    if (index >= 0 && index < 4) {
      _tabController.animateTo(index);
    }
  }

  Widget? _buildFab() {
    final currentIndex = _tabController.index;

    if (currentIndex == 0 || currentIndex == 1) {
      // Tab Ringkasan & Transaksi -> Tambah Transaksi
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Catat Transaksi'),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => const TransactionFormSheet(),
          );
        },
      );
    } else if (currentIndex == 2) {
      // Tab Rekening -> Tambah Rekening
      return FloatingActionButton.extended(
        backgroundColor: const Color(0xFF2E7D32),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_card),
        label: const Text('Tambah Rekening'),
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true,
            backgroundColor: Colors.white,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            builder: (_) => const AccountFormSheet(),
          );
        },
      );
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) {
          return [
            SliverToBoxAdapter(
              child: Container(
                color: Colors.white,
                padding: const EdgeInsets.only(top: 8),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: false,
                  labelColor: const Color(0xFF2E7D32),
                  unselectedLabelColor: Colors.grey.shade600,
                  indicatorColor: const Color(0xFF2E7D32),
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                  tabs: const [
                    Tab(
                      icon: Icon(Icons.dashboard_outlined, size: 20),
                      text: 'Ringkasan',
                    ),
                    Tab(
                      icon: Icon(Icons.receipt_long_outlined, size: 20),
                      text: 'Transaksi',
                    ),
                    Tab(
                      icon: Icon(Icons.account_balance_wallet_outlined, size: 20),
                      text: 'Rekening',
                    ),
                    Tab(
                      icon: Icon(Icons.two_wheeler_outlined, size: 20),
                      text: 'Motor',
                    ),
                  ],
                ),
              ),
            ),
          ];
        },
        body: TabBarView(
          controller: _tabController,
          children: [
            FinanceSummaryTab(onNavigateToTab: _navigateToTab),
            const FinanceTransactionsTab(),
            const FinanceAccountsTab(),
            const FinanceVehiclesTab(),
          ],
        ),
      ),
      floatingActionButton: _buildFab(),
    );
  }
}
