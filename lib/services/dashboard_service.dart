import '../data/repositories/hutang_repository.dart';
import '../data/repositories/konten_repository.dart';
import '../data/repositories/produk_repository.dart';
import '../data/repositories/transaksi_repository.dart';
import '../models/dashboard_summary.dart';

/// Menyusun data Beranda dari repository (tanpa akses database langsung).
class DashboardService {
  DashboardService({required this.transaksi, required this.hutang, required this.produk, required this.konten});

  final TransaksiRepository transaksi;
  final HutangRepository hutang;
  final ProdukRepository produk;
  final KontenRepository konten;

  Future<DashboardSummary> load({DateTime? now}) async {
    final clock = now ?? DateTime.now();
    final today = DateTime(clock.year, clock.month, clock.day);
    final monthStart = DateTime(today.year, today.month, 1);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));
    final salesFrom = sevenDaysAgo.isBefore(monthStart) ? sevenDaysAgo : monthStart;

    final sales = await transaksi.dailySales(salesFrom, today);
    final debts = await hutang.getDebts();
    final lowStock = await produk.watchLowStock().first;
    final schedules = await konten.schedulesBetween(clock, today.add(const Duration(days: 8)));
    final statusCounts = await konten.statusCounts();
    final totals = summarizeDebts(debts);

    return DashboardSummary(
      today: today,
      salesToday: sumOmzet(sales, today, today),
      trxCountToday: sumCount(sales, today, today),
      salesThisMonth: sumOmzet(sales, monthStart, today),
      trxCountThisMonth: sumCount(sales, monthStart, today),
      last7Days: buildDailySeries(sales, from: sevenDaysAgo, to: today),
      receivableTotal: totals.receivableTotal,
      receivableCount: totals.receivableCount,
      payableTotal: totals.payableTotal,
      payableCount: totals.payableCount,
      dueDebts: filterDueDebts(debts, limit: today.add(const Duration(days: 7))),
      lowStock: lowStock,
      upcomingSchedules: schedules,
      contentStatusCounts: statusCounts,
    );
  }
}

// ---------------------------------------------------------------------------
// Fungsi murni (diuji di test/dashboard_logic_test.dart)
// ---------------------------------------------------------------------------

Iterable<DailySalesRow> _inRange(List<DailySalesRow> rows, DateTime from, DateTime to) =>
    rows.where((r) => !r.date.isBefore(from) && !r.date.isAfter(to));

double sumOmzet(List<DailySalesRow> rows, DateTime from, DateTime to) =>
    _inRange(rows, from, to).fold(0, (s, r) => s + r.omzet);

int sumCount(List<DailySalesRow> rows, DateTime from, DateTime to) =>
    _inRange(rows, from, to).fold(0, (s, r) => s + r.trxCount);

/// Deret harian lengkap [from..to]; hari tanpa data bernilai 0.
List<DailySales> buildDailySeries(List<DailySalesRow> rows, {required DateTime from, required DateTime to}) {
  final byDate = {for (final r in rows) DateTime(r.date.year, r.date.month, r.date.day): r};
  final out = <DailySales>[];
  for (var d = DateTime(from.year, from.month, from.day); !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) {
    final r = byDate[d];
    out.add(DailySales(d, r?.omzet ?? 0, r?.trxCount ?? 0));
  }
  return out;
}

class DebtTotals {
  const DebtTotals(this.receivableTotal, this.receivableCount, this.payableTotal, this.payableCount);
  final double receivableTotal;
  final int receivableCount;
  final double payableTotal;
  final int payableCount;
}

DebtTotals summarizeDebts(List<DebtRow> debts) {
  double rt = 0, pt = 0;
  int rc = 0, pc = 0;
  for (final d in debts) {
    if (d.isReceivable) {
      rt += d.remaining;
      rc++;
    } else {
      pt += d.remaining;
      pc++;
    }
  }
  return DebtTotals(rt, rc, pt, pc);
}

/// Lewat jatuh tempo atau jatuh tempo ≤ [limit]; paling mendesak di atas.
List<DebtRow> filterDueDebts(List<DebtRow> debts, {required DateTime limit}) =>
    debts.where((d) => d.dueDate != null && !d.dueDate!.isAfter(limit)).toList()
      ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
