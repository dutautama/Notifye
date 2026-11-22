import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../widgets/pin_pad.dart';
import 'auth_controller.dart';
import 'pin_service.dart';
import 'reset_app_flow.dart';

class LockScreen extends ConsumerStatefulWidget {
  const LockScreen({super.key});

  @override
  ConsumerState<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends ConsumerState<LockScreen> {
  String? _message;
  DateTime? _lockedUntil;
  Timer? _ticker;

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }

  void _startLock(Duration d) {
    _lockedUntil = DateTime.now().add(d);
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (DateTime.now().isAfter(_lockedUntil!)) {
        t.cancel();
        setState(() {
          _lockedUntil = null;
          _message = null;
        });
      } else {
        setState(() {});
      }
    });
  }

  Future<bool> _onPin(String pin) async {
    final result = await ref.read(authControllerProvider.notifier).unlock(pin);
    if (!mounted) return true;
    switch (result) {
      case PinOk():
        break;
      case PinWrong(:final failures, :final lockedFor):
        setState(() => _message = lockedFor > Duration.zero
            ? 'PIN salah $failures kali.'
            : 'PIN salah. Sisa percobaan sebelum dikunci: ${5 - failures}.');
        if (lockedFor > Duration.zero) _startLock(lockedFor);
      case PinLocked(:final remaining):
        setState(() => _message = 'Terlalu banyak percobaan.');
        _startLock(remaining);
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locked = _lockedUntil != null;
    final secs = locked ? _lockedUntil!.difference(DateTime.now()).inSeconds + 1 : 0;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.storefront, size: 48, color: scheme.primary),
                const SizedBox(height: 12),
                Text('UsahaKonten', style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 8),
                const Text('Masukkan PIN'),
                const SizedBox(height: 8),
                SizedBox(
                  height: 40,
                  child: Text(
                    [
                      ?_message,
                      if (locked) 'Coba lagi dalam $secs detik.',
                    ].join('\n'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: scheme.error),
                  ),
                ),
                const SizedBox(height: 8),
                PinPad(onCompleted: _onPin, enabled: !locked),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () => runResetAppFlow(context, ref),
                  child: const Text('Lupa PIN? Reset aplikasi'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
