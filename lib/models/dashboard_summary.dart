import '../data/database/app_database.dart';
import '../data/repositories/hutang_repository.dart';
import '../data/repositories/konten_repository.dart';

/// Data ringkasan untuk layar Beranda.
class DashboardSummary {
  const DashboardSummary({
    required this.today,
    required this.salesToday,
    required this.trxCountToday,
    required this.salesThisMonth,
    required this.trxCountThisMonth,
    required this.last7Days,
    required this.receivableTotal,
    required this.receivableCount,
    required this.payableTotal,
    required this.payableCount,
    required this.dueDebts,
    required this.lowStock,
    required this.upcomingSchedules,
    required this.contentStatusCounts,
    this.recentNotes = const [],
    this.inProgress = const [],
  });

  final DateTime today;
  final double salesToday;
  final int trxCountToday;
  final double salesThisMonth;
  final int trxCountThisMonth;

  /// 7 hari terakhir (urut lama → baru), termasuk hari tanpa penjualan (0).
  final List<DailySales> last7Days;

  final double receivableTotal; // piutang
  final int receivableCount;
  final double payableTotal; // hutang
  final int payableCount;

  /// Hutang/piutang yang lewat jatuh tempo atau jatuh tempo ≤ 7 hari.
  final List<DebtRow> dueDebts;
  final List<Product> lowStock;
  final List<ScheduleWithIdea> upcomingSchedules;

  /// {'ide': 3, 'produksi': 1, 'review': 0, 'publish': 5}
  final Map<String, int> contentStatusCounts;

  /// Catatan terbaru (sematan dulu) & item koleksi yang sedang dibaca/ditonton.
  final List<Note> recentNotes;
  final List<WatchlistItem> inProgress;
}

class DailySales {
  const DailySales(this.date, this.omzet, this.trxCount);
  final DateTime date;
  final double omzet;
  final int trxCount;
}
