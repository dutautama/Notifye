/// Data ringkasan untuk layar Beranda.
class DashboardSummary {
  const DashboardSummary({
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
  });

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
  final List<DebtItem> dueDebts;
  final List<LowStockItem> lowStock;
  final List<ScheduleItem> upcomingSchedules;

  /// {'ide': 3, 'produksi': 1, 'review': 0, 'publish': 5}
  final Map<String, int> contentStatusCounts;
}

class DailySales {
  const DailySales(this.date, this.omzet, this.trxCount);
  final DateTime date;
  final double omzet;
  final int trxCount;
}

class DebtItem {
  const DebtItem({
    required this.id,
    required this.kind,
    required this.number,
    required this.partyName,
    required this.partyPhone,
    required this.remaining,
    required this.dueDate,
    required this.isOverdue,
  });

  final String id;
  final String kind; // 'piutang' | 'hutang'
  final String number;
  final String partyName;
  final String? partyPhone;
  final double remaining;
  final DateTime? dueDate;
  final bool isOverdue;

  bool get isReceivable => kind == 'piutang';

  factory DebtItem.fromJson(Map<String, dynamic> j) => DebtItem(
        id: j['id'] as String,
        kind: j['debt_kind'] as String,
        number: j['number'] as String,
        partyName: (j['party_name'] as String?) ?? 'Umum',
        partyPhone: j['party_phone'] as String?,
        remaining: (j['remaining'] as num).toDouble(),
        dueDate: j['due_date'] == null
            ? null
            : DateTime.parse(j['due_date'] as String),
        isOverdue: (j['is_overdue'] as bool?) ?? false,
      );
}

class LowStockItem {
  const LowStockItem({
    required this.id,
    required this.name,
    required this.unit,
    required this.stock,
    required this.minStock,
  });

  final String id;
  final String name;
  final String unit;
  final double stock;
  final double minStock;

  factory LowStockItem.fromJson(Map<String, dynamic> j) => LowStockItem(
        id: j['id'] as String,
        name: j['name'] as String,
        unit: j['unit'] as String,
        stock: (j['stock'] as num).toDouble(),
        minStock: (j['min_stock'] as num).toDouble(),
      );
}

class ScheduleItem {
  const ScheduleItem({
    required this.id,
    required this.ideaId,
    required this.title,
    required this.platform,
    required this.scheduledAt,
  });

  final String id;
  final String ideaId;
  final String title;
  final String platform;
  final DateTime scheduledAt;

  factory ScheduleItem.fromJson(Map<String, dynamic> j) => ScheduleItem(
        id: j['id'] as String,
        ideaId: j['idea_id'] as String,
        title: (j['content_ideas'] as Map<String, dynamic>?)?['title']
                as String? ??
            '(tanpa judul)',
        platform: j['platform'] as String,
        scheduledAt: DateTime.parse(j['scheduled_at'] as String),
      );
}
