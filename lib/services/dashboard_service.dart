import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/dashboard_summary.dart';
import 'supabase_service.dart';

/// Mengambil semua data Beranda secara paralel dari view & tabel Supabase.
class DashboardService {
  DashboardService(this._db);

  final SupabaseClient _db;

  factory DashboardService.instance() => DashboardService(SupabaseService.client);

  Future<DashboardSummary> load({DateTime? now}) async {
    final today = _dateOnly(now ?? DateTime.now());
    final monthStart = DateTime(today.year, today.month, 1);
    final sevenDaysAgo = today.subtract(const Duration(days: 6));
    final salesFrom = sevenDaysAgo.isBefore(monthStart) ? sevenDaysAgo : monthStart;
    final dueLimit = today.add(const Duration(days: 7));
    final weekEnd = today.add(const Duration(days: 8));

    final results = await Future.wait<List<Map<String, dynamic>>>([
      _db
          .from('v_daily_sales')
          .select('trx_date, omzet, trx_count')
          .gte('trx_date', _ymd(salesFrom))
          .lte('trx_date', _ymd(today)),
      _db.from('v_debts').select(
          'id, debt_kind, number, party_name, party_phone, remaining, due_date, is_overdue'),
      _db.from('v_low_stock').select('id, name, unit, stock, min_stock').order('stock').limit(20),
      _db
          .from('content_schedules')
          .select('id, idea_id, platform, scheduled_at, content_ideas(title)')
          .eq('status', 'terjadwal')
          .gte('scheduled_at', DateTime.now().toUtc().toIso8601String())
          .lt('scheduled_at', weekEnd.toUtc().toIso8601String())
          .order('scheduled_at')
          .limit(20),
      _db.from('content_ideas').select('status'),
    ]);

    final sales = results[0];
    final debts = results[1].map(DebtItem.fromJson).toList();
    final debtTotals = summarizeDebts(debts);

    return DashboardSummary(
      salesToday: _sumOmzet(sales, from: today, to: today),
      trxCountToday: _sumCount(sales, from: today, to: today),
      salesThisMonth: _sumOmzet(sales, from: monthStart, to: today),
      trxCountThisMonth: _sumCount(sales, from: monthStart, to: today),
      last7Days: buildDailySeries(sales, from: sevenDaysAgo, to: today),
      receivableTotal: debtTotals.receivableTotal,
      receivableCount: debtTotals.receivableCount,
      payableTotal: debtTotals.payableTotal,
      payableCount: debtTotals.payableCount,
      dueDebts: filterDueDebts(debts, today: today, limit: dueLimit),
      lowStock: results[2].map(LowStockItem.fromJson).toList(),
      upcomingSchedules: results[3].map(ScheduleItem.fromJson).toList(),
      contentStatusCounts: countStatuses(results[4]),
    );
  }

  double _sumOmzet(List<Map<String, dynamic>> rows,
          {required DateTime from, required DateTime to}) =>
      _inRange(rows, from, to)
          .fold(0, (s, r) => s + (r['omzet'] as num).toDouble());

  int _sumCount(List<Map<String, dynamic>> rows,
          {required DateTime from, required DateTime to}) =>
      _inRange(rows, from, to).fold(0, (s, r) => s + (r['trx_count'] as num).toInt());

  Iterable<Map<String, dynamic>> _inRange(
      List<Map<String, dynamic>> rows, DateTime from, DateTime to) {
    return rows.where((r) {
      final d = DateTime.parse(r['trx_date'] as String);
      return !d.isBefore(from) && !d.isAfter(to);
    });
  }
}

// ---------------------------------------------------------------------------
// Fungsi murni (mudah diuji di test/dashboard_logic_test.dart)
// ---------------------------------------------------------------------------

DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

String _ymd(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

/// Deret harian lengkap [from..to]; hari tanpa data bernilai 0.
List<DailySales> buildDailySeries(List<Map<String, dynamic>> rows,
    {required DateTime from, required DateTime to}) {
  final byDate = <String, Map<String, dynamic>>{
    for (final r in rows) r['trx_date'] as String: r,
  };
  final out = <DailySales>[];
  for (var d = _dateOnly(from); !d.isAfter(to); d = DateTime(d.year, d.month, d.day + 1)) {
    final r = byDate[_ymd(d)];
    out.add(DailySales(
      d,
      r == null ? 0 : (r['omzet'] as num).toDouble(),
      r == null ? 0 : (r['trx_count'] as num).toInt(),
    ));
  }
  return out;
}

class DebtTotals {
  const DebtTotals(this.receivableTotal, this.receivableCount, this.payableTotal,
      this.payableCount);
  final double receivableTotal;
  final int receivableCount;
  final double payableTotal;
  final int payableCount;
}

DebtTotals summarizeDebts(List<DebtItem> debts) {
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

/// Lewat jatuh tempo atau jatuh tempo ≤ [limit]; terlambat paling atas.
List<DebtItem> filterDueDebts(List<DebtItem> debts,
    {required DateTime today, required DateTime limit}) {
  final list = debts
      .where((d) => d.dueDate != null && !d.dueDate!.isAfter(limit))
      .toList()
    ..sort((a, b) => a.dueDate!.compareTo(b.dueDate!));
  return list;
}

Map<String, int> countStatuses(List<Map<String, dynamic>> rows) {
  final counts = {'ide': 0, 'produksi': 0, 'review': 0, 'publish': 0};
  for (final r in rows) {
    final s = r['status'] as String;
    counts[s] = (counts[s] ?? 0) + 1;
  }
  return counts;
}
