import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// Hash PIN dengan PBKDF2-HMAC-SHA256 (+ salt acak). PIN 6 digit hanya punya
/// 1 juta kemungkinan, jadi iterasi tinggi + pembatasan percobaan di
/// [PinService] sama-sama penting.
class PinHasher {
  PinHasher._();

  static const iterations = 100000;
  static const _keyLength = 32; // = panjang output SHA-256 (1 blok)

  static final _pinRe = RegExp(r'^\d{6}$');
  static bool isValidPin(String pin) => _pinRe.hasMatch(pin);

  static Uint8List randomSalt([int length = 16]) {
    final r = Random.secure();
    return Uint8List.fromList(List.generate(length, (_) => r.nextInt(256)));
  }

  static Uint8List pbkdf2(String pin, List<int> salt, {int iterations = iterations}) {
    final hmac = Hmac(sha256, utf8.encode(pin));
    // Blok 1: U1 = HMAC(salt || INT_32_BE(1))
    var u = hmac.convert([...salt, 0, 0, 0, 1]).bytes;
    final out = Uint8List.fromList(u);
    for (var i = 1; i < iterations; i++) {
      u = hmac.convert(u).bytes;
      for (var j = 0; j < _keyLength; j++) {
        out[j] ^= u[j];
      }
    }
    return out;
  }

  /// Perbandingan waktu-konstan (tidak bocor lewat lama proses).
  static bool constantTimeEquals(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    var diff = 0;
    for (var i = 0; i < a.length; i++) {
      diff |= a[i] ^ b[i];
    }
    return diff == 0;
  }
}

/// Data PIN yang disimpan (tanpa PIN asli).
class StoredPin {
  const StoredPin({required this.salt, required this.hash, required this.iterations});

  final List<int> salt;
  final List<int> hash;
  final int iterations;

  String encode() => jsonEncode({
        'v': 1,
        'salt': base64Encode(salt),
        'hash': base64Encode(hash),
        'iter': iterations,
      });

  static StoredPin decode(String raw) {
    final j = jsonDecode(raw) as Map<String, dynamic>;
    return StoredPin(
      salt: base64Decode(j['salt'] as String),
      hash: base64Decode(j['hash'] as String),
      iterations: j['iter'] as int,
    );
  }
}

/// Lama kunci setelah [failures] percobaan gagal berturut-turut.
/// 1–4 gagal: tanpa jeda; ke-5: 30 dtk; lalu berlipat dua, maksimal 15 menit.
Duration lockoutFor(int failures) {
  if (failures < 5) return Duration.zero;
  final seconds = 30 * pow(2, failures - 5);
  return Duration(seconds: min(seconds.toInt(), 15 * 60));
}
