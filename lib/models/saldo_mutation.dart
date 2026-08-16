class SaldoMutation {
  final DateTime tanggal;
  final String keterangan;
  final double debit;  // Uang Keluar
  final double kredit; // Uang Masuk
  final double runningBalance; // Saldo Berjalan

  SaldoMutation({
    required this.tanggal,
    required this.keterangan,
    required this.debit,
    required this.kredit,
    required this.runningBalance,
  });
}
