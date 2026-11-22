import 'package:flutter_test/flutter_test.dart';
import 'package:usahakonten/core/validators.dart';
import 'package:usahakonten/models/dashboard_summary.dart';
import 'package:usahakonten/services/auth_service.dart';
import 'package:usahakonten/services/dashboard_service.dart';
import 'package:usahakonten/services/whatsapp_service.dart';

DebtItem debt(String kind, double remaining, DateTime? due) => DebtItem(
      id: '$kind$remaining',
      kind: kind,
      number: 'X',
      partyName: 'A',
      partyPhone: null,
      remaining: remaining,
      dueDate: due,
      isOverdue: false,
    );

void main() {
  test('deret 7 hari mengisi hari kosong dengan 0', () {
    final s = buildDailySeries([
      {'trx_date': '2026-11-20', 'omzet': 150000, 'trx_count': 2},
      {'trx_date': '2026-11-22', 'omzet': 50000.5, 'trx_count': 1},
    ], from: DateTime(2026, 11, 16), to: DateTime(2026, 11, 22));
    expect(s.length, 7);
    expect(s.first.omzet, 0);
    expect(s[4].omzet, 150000);
    expect(s.last.trxCount, 1);
  });

  test('deret melewati pergantian bulan', () {
    final s = buildDailySeries([], from: DateTime(2026, 11, 28), to: DateTime(2026, 12, 2));
    expect(s.map((e) => e.date.day), [28, 29, 30, 1, 2]);
  });

  test('ringkasan & filter hutang/piutang', () {
    final today = DateTime(2026, 11, 22);
    final list = [
      debt('piutang', 100, DateTime(2026, 11, 25)),
      debt('piutang', 50, DateTime(2026, 11, 10)),
      debt('hutang', 70, null),
      debt('piutang', 30, DateTime(2026, 12, 30)),
    ];
    final t = summarizeDebts(list);
    expect(t.receivableTotal, 180);
    expect(t.receivableCount, 3);
    expect(t.payableTotal, 70);
    final due = filterDueDebts(list, today: today, limit: today.add(const Duration(days: 7)));
    expect(due.map((d) => d.remaining), [50, 100]);
  });

  test('hitung status konten', () {
    expect(countStatuses([
      {'status': 'ide'},
      {'status': 'ide'},
      {'status': 'publish'},
    ]), {'ide': 2, 'produksi': 0, 'review': 0, 'publish': 1});
  });

  test('normalisasi nomor WhatsApp', () {
    expect(WhatsAppService.normalizePhone('0812-3456-7890'), '6281234567890');
    expect(WhatsAppService.normalizePhone('+62 812 3456 7890'), '6281234567890');
    expect(WhatsAppService.normalizePhone('81234567890'), '6281234567890');
    expect(WhatsAppService.normalizePhone('123'), isNull);
    expect(WhatsAppService.normalizePhone(null), isNull);
  });

  test('terjemahan error login', () {
    expect(translateAuthError('Invalid login credentials', 'invalid_credentials'),
        'Email atau password salah.');
  });

  test('validator & parse angka', () {
    expect(Validators.email('a@b.co'), isNull);
    expect(Validators.email('salah'), isNotNull);
    expect(Validators.parseNumber('1.500.000'), 1500000);
    expect(Validators.parseNumber('12,5'), 12.5);
  });
}
