import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../widgets/pin_pad.dart';
import 'auth_controller.dart';

/// Pembuatan PIN pertama kali (masukkan 2x).
class SetupPinScreen extends ConsumerStatefulWidget {
  const SetupPinScreen({super.key});

  @override
  ConsumerState<SetupPinScreen> createState() => _SetupPinScreenState();
}

class _SetupPinScreenState extends ConsumerState<SetupPinScreen> {
  String? _first;
  String? _error;

  Future<bool> _onPin(String pin) async {
    if (_first == null) {
      setState(() {
        _first = pin;
        _error = null;
      });
      return true;
    }
    if (pin != _first) {
      setState(() {
        _first = null;
        _error = 'PIN tidak sama. Ulangi dari awal.';
      });
      return true;
    }
    await ref.read(authControllerProvider.notifier).createPin(pin);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                Icon(Icons.lock_outline, size: 48, color: scheme.primary),
                const SizedBox(height: 12),
                Text('Selamat datang di UsahaKonten', textAlign: TextAlign.center, style: text.titleLarge),
                const SizedBox(height: 8),
                Text(
                  _first == null ? 'Buat PIN 6 digit untuk mengunci aplikasi.' : 'Masukkan PIN yang sama sekali lagi.',
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'PIN tidak bisa dipulihkan. Jika lupa, satu-satunya cara adalah '
                  'reset aplikasi (semua data terhapus) lalu restore dari backup.',
                  textAlign: TextAlign.center,
                  style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  Text(_error!, style: TextStyle(color: scheme.error)),
                ],
                const SizedBox(height: 24),
                PinPad(key: ValueKey(_first == null), onCompleted: _onPin),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
