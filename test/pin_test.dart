import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:usahakonten/features/auth/pin_hasher.dart';
import 'package:usahakonten/features/auth/pin_service.dart';

/// Penyimpanan palsu di memori untuk menguji PinService tanpa perangkat.
class FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({required String key, AppleOptions? iOptions, AndroidOptions? aOptions,
          LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions,
          WindowsOptions? wOptions}) async =>
      data[key];

  @override
  Future<void> write({required String key, required String? value, AppleOptions? iOptions,
      AndroidOptions? aOptions, LinuxOptions? lOptions, WebOptions? webOptions,
      AppleOptions? mOptions, WindowsOptions? wOptions}) async {
    if (value == null) {
      data.remove(key);
    } else {
      data[key] = value;
    }
  }

  @override
  Future<void> delete({required String key, AppleOptions? iOptions, AndroidOptions? aOptions,
          LinuxOptions? lOptions, WebOptions? webOptions, AppleOptions? mOptions,
          WindowsOptions? wOptions}) async =>
      data.remove(key);
}

void main() {
  test('PBKDF2 sesuai vektor uji RFC 7914 (1 iterasi, blok pertama)', () {
    // Verifikasi manual: PBKDF2 1 iterasi = HMAC(password, salt || 00000001).
    final expected = Hmac(sha256, utf8.encode('passwd')).convert([...utf8.encode('salt'), 0, 0, 0, 1]).bytes;
    expect(PinHasher.pbkdf2('passwd', utf8.encode('salt'), iterations: 1), expected);
    // Vektor resmi RFC 7914 §11: PBKDF2-HMAC-SHA256("passwd","salt",1) diawali 55ac046e56e3089f
    final hex = PinHasher.pbkdf2('passwd', utf8.encode('salt'), iterations: 1)
        .take(8)
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    expect(hex, '55ac046e56e3089f');
  });

  test('validasi format PIN', () {
    expect(PinHasher.isValidPin('123456'), isTrue);
    expect(PinHasher.isValidPin('12345'), isFalse);
    expect(PinHasher.isValidPin('12345a'), isFalse);
    expect(PinHasher.isValidPin('1234567'), isFalse);
  });

  test('jeda kunci bertingkat', () {
    expect(lockoutFor(4), Duration.zero);
    expect(lockoutFor(5), const Duration(seconds: 30));
    expect(lockoutFor(6), const Duration(seconds: 60));
    expect(lockoutFor(20), const Duration(minutes: 15));
  });

  test('set, verifikasi, salah berulang → terkunci, ubah PIN, reset', () async {
    final store = FakeSecureStorage();
    final pins = PinService(store);
    expect(await pins.hasPin(), isFalse);
    await pins.setPin('123456');
    expect(await pins.hasPin(), isTrue);
    expect(store.data['pin_v1'], isNot(contains('123456')), reason: 'PIN asli tidak disimpan');

    expect(await pins.verify('123456'), isA<PinOk>());
    final now = DateTime(2026, 11, 22, 10);
    for (var i = 1; i <= 4; i++) {
      final r = await pins.verify('000000', now: now);
      expect((r as PinWrong).lockedFor, Duration.zero);
    }
    final fifth = await pins.verify('000000', now: now) as PinWrong;
    expect(fifth.lockedFor, const Duration(seconds: 30));
    // PIN benar pun ditolak selama masa kunci
    expect(await pins.verify('123456', now: now.add(const Duration(seconds: 10))), isA<PinLocked>());
    expect(await pins.verify('123456', now: now.add(const Duration(seconds: 31))), isA<PinOk>());

    expect(await pins.changePin('999999', '654321'), isA<PinWrong>());
    expect(await pins.changePin('123456', '654321'), isA<PinOk>());
    expect(await pins.verify('654321'), isA<PinOk>());

    await pins.clear();
    expect(await pins.hasPin(), isFalse);
  });

  test('PIN tidak valid ditolak saat dibuat', () async {
    expect(() => PinService(FakeSecureStorage()).setPin('12ab56'), throwsArgumentError);
  });
}
