import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../providers/app_providers.dart';
import 'pin_service.dart';

enum AuthStatus { loading, needsSetup, locked, unlocked }

/// Status kunci aplikasi. Terkunci saat dibuka & saat kembali dari background
/// lebih dari [autoLockAfter].
class AuthController extends Notifier<AuthStatus> {
  static const autoLockAfter = Duration(seconds: 60);

  AppLifecycleListener? _lifecycle;
  DateTime? _pausedAt;

  PinService get _pins => ref.read(pinServiceProvider);

  @override
  AuthStatus build() {
    _lifecycle = AppLifecycleListener(onHide: () => _pausedAt = DateTime.now(), onShow: _onResume);
    ref.onDispose(() => _lifecycle?.dispose());
    unawaited(_init());
    return AuthStatus.loading;
  }

  Future<void> _init() async {
    state = await _pins.hasPin() ? AuthStatus.locked : AuthStatus.needsSetup;
  }

  void _onResume() {
    final paused = _pausedAt;
    _pausedAt = null;
    if (state == AuthStatus.unlocked && paused != null && DateTime.now().difference(paused) >= autoLockAfter) {
      state = AuthStatus.locked;
    }
  }

  Future<void> createPin(String pin) async {
    await _pins.setPin(pin);
    _onUnlocked();
  }

  Future<PinCheck> unlock(String pin) async {
    final result = await _pins.verify(pin);
    if (result is PinOk) _onUnlocked();
    return result;
  }

  void _onUnlocked() {
    state = AuthStatus.unlocked;
    // Backup otomatis mingguan; gagal pun tidak boleh mengganggu pemakaian.
    unawaited(ref.read(backupServiceProvider).runAutoBackupIfDue().then((_) {}, onError: (_) {}));
  }

  void lock() {
    if (state == AuthStatus.unlocked) state = AuthStatus.locked;
  }

  /// Dipanggil setelah reset aplikasi: kembali ke pembuatan PIN.
  void markReset() => state = AuthStatus.needsSetup;
}

final authControllerProvider = NotifierProvider<AuthController, AuthStatus>(AuthController.new);
