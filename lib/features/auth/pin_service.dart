import 'dart:isolate';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'pin_hasher.dart';

sealed class PinCheck {
  const PinCheck();
}

class PinOk extends PinCheck {
  const PinOk();
}

class PinWrong extends PinCheck {
  const PinWrong(this.failures, this.lockedFor);
  final int failures;
  final Duration lockedFor;
}

class PinLocked extends PinCheck {
  const PinLocked(this.remaining);
  final Duration remaining;
}

/// Penyimpanan & verifikasi PIN di Android Keystore (flutter_secure_storage).
class PinService {
  PinService([FlutterSecureStorage? storage]) : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _kPin = 'pin_v1';
  static const _kFailures = 'pin_failures';
  static const _kLockedUntil = 'pin_locked_until';

  Future<bool> hasPin() async => (await _storage.read(key: _kPin)) != null;

  Future<void> setPin(String pin) async {
    if (!PinHasher.isValidPin(pin)) throw ArgumentError('PIN harus 6 digit angka');
    final salt = PinHasher.randomSalt();
    final hash = await Isolate.run(() => PinHasher.pbkdf2(pin, salt));
    await _storage.write(
      key: _kPin,
      value: StoredPin(salt: salt, hash: hash, iterations: PinHasher.iterations).encode(),
    );
    await _resetFailures();
  }

  Future<PinCheck> verify(String pin, {DateTime? now}) async {
    final t = now ?? DateTime.now();
    final lockedUntil = int.tryParse(await _storage.read(key: _kLockedUntil) ?? '');
    if (lockedUntil != null && t.millisecondsSinceEpoch < lockedUntil) {
      return PinLocked(Duration(milliseconds: lockedUntil - t.millisecondsSinceEpoch));
    }

    final raw = await _storage.read(key: _kPin);
    if (raw == null) throw StateError('PIN belum dibuat');
    final stored = StoredPin.decode(raw);
    final hash = await Isolate.run(
        () => PinHasher.pbkdf2(pin, stored.salt, iterations: stored.iterations));

    if (PinHasher.constantTimeEquals(hash, stored.hash)) {
      await _resetFailures();
      return const PinOk();
    }

    final failures = int.parse(await _storage.read(key: _kFailures) ?? '0') + 1;
    final lock = lockoutFor(failures);
    await _storage.write(key: _kFailures, value: '$failures');
    if (lock > Duration.zero) {
      await _storage.write(
          key: _kLockedUntil, value: '${t.add(lock).millisecondsSinceEpoch}');
    }
    return PinWrong(failures, lock);
  }

  /// Ubah PIN: wajib PIN lama benar.
  Future<PinCheck> changePin(String oldPin, String newPin) async {
    final check = await verify(oldPin);
    if (check is PinOk) await setPin(newPin);
    return check;
  }

  /// Hapus PIN & penghitung gagal (bagian dari "Reset aplikasi").
  Future<void> clear() async {
    await _storage.delete(key: _kPin);
    await _resetFailures();
  }

  Future<void> _resetFailures() async {
    await _storage.delete(key: _kFailures);
    await _storage.delete(key: _kLockedUntil);
  }
}
