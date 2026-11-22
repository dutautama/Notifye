import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

/// Input PIN 6 digit: indikator titik + papan angka besar (ramah jempol).
class PinPad extends StatefulWidget {
  const PinPad({super.key, required this.onCompleted, this.enabled = true, this.length = 6});

  /// Dipanggil saat 6 digit terisi. Kembalikan true agar input dikosongkan.
  final Future<bool> Function(String pin) onCompleted;
  final bool enabled;
  final int length;

  @override
  State<PinPad> createState() => _PinPadState();
}

class _PinPadState extends State<PinPad> {
  String _value = '';
  bool _busy = false;

  Future<void> _press(String digit) async {
    if (!widget.enabled || _busy || _value.length >= widget.length) return;
    HapticFeedback.selectionClick();
    setState(() => _value += digit);
    if (_value.length == widget.length) {
      setState(() => _busy = true);
      final clear = await widget.onCompleted(_value);
      if (!mounted) return;
      setState(() {
        _busy = false;
        if (clear) _value = '';
      });
    }
  }

  void _backspace() {
    if (_busy || _value.isEmpty) return;
    setState(() => _value = _value.substring(0, _value.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          label: '${_value.length} dari ${widget.length} digit terisi',
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var i = 0; i < widget.length; i++)
                AnimatedContainer(
                  duration: const Duration(milliseconds: 120),
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i < _value.length ? scheme.primary : Colors.transparent,
                    border: Border.all(color: scheme.primary, width: 2),
                  ),
                ),
            ],
          ),
        ),
        SizedBox(
          height: 32,
          child: _busy
              ? const Center(child: SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)))
              : null,
        ),
        for (final row in const [
          ['1', '2', '3'],
          ['4', '5', '6'],
          ['7', '8', '9'],
          ['', '0', '<'],
        ])
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final k in row)
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    width: 72,
                    height: 72,
                    child: k.isEmpty
                        ? null
                        : k == '<'
                        ? IconButton(
                            tooltip: 'Hapus',
                            onPressed: widget.enabled ? _backspace : null,
                            icon: const Icon(Icons.backspace_outlined),
                          )
                        : FilledButton.tonal(
                            style: FilledButton.styleFrom(
                              shape: const CircleBorder(),
                              minimumSize: const Size(72, 72),
                              textStyle: const TextStyle(fontSize: 26, fontWeight: FontWeight.w600),
                            ),
                            onPressed: widget.enabled ? () => _press(k) : null,
                            child: Text(k),
                          ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}
