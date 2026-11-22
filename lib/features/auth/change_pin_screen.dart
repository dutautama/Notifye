import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import '../../providers/app_providers.dart';
import '../../widgets/pin_pad.dart';
import 'pin_service.dart';

enum _Step { oldPin, newPin, confirm }

/// Ubah PIN: PIN lama → PIN baru → ulangi PIN baru.
class ChangePinScreen extends ConsumerStatefulWidget {
  const ChangePinScreen({super.key});

  @override
  ConsumerState<ChangePinScreen> createState() => _ChangePinScreenState();
}

class _ChangePinScreenState extends ConsumerState<ChangePinScreen> {
  _Step _step = _Step.oldPin;
  String? _old;
  String? _new;
  String? _error;

  Future<bool> _onPin(String pin) async {
    final pins = ref.read(pinServiceProvider);
    switch (_step) {
      case _Step.oldPin:
        final r = await pins.verify(pin);
        if (r is PinOk) {
          setState(() {
            _old = pin;
            _step = _Step.newPin;
            _error = null;
          });
        } else {
          setState(() => _error = switch (r) {
                PinLocked(:final remaining) =>
                  'Terlalu banyak percobaan. Coba lagi dalam ${remaining.inSeconds + 1} detik.',
                _ => 'PIN lama salah.',
              });
        }
      case _Step.newPin:
        if (pin == _old) {
          setState(() => _error = 'PIN baru harus berbeda dari PIN lama.');
        } else {
          setState(() {
            _new = pin;
            _step = _Step.confirm;
            _error = null;
          });
        }
      case _Step.confirm:
        if (pin != _new) {
          setState(() {
            _step = _Step.newPin;
            _error = 'PIN tidak sama. Masukkan PIN baru lagi.';
          });
        } else {
          final messenger = ScaffoldMessenger.of(context);
          final router = GoRouter.of(context);
          await pins.changePin(_old!, pin);
          messenger.showSnackBar(const SnackBar(content: Text('PIN berhasil diubah')));
          router.pop();
        }
    }
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final title = switch (_step) {
      _Step.oldPin => 'Masukkan PIN lama',
      _Step.newPin => 'Masukkan PIN baru',
      _Step.confirm => 'Ulangi PIN baru',
    };
    return Scaffold(
      appBar: AppBar(title: const Text('Ubah PIN')),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              SizedBox(
                height: 40,
                child: Center(
                  child: Text(_error ?? '',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              ),
              PinPad(key: ValueKey(_step), onCompleted: _onPin),
            ],
          ),
        ),
      ),
    );
  }
}
