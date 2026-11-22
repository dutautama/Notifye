import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

import '../core/validators.dart';

/// Memformat angka saat diketik: 1500000 → "1.500.000".
class ThousandsInputFormatter extends TextInputFormatter {
  static final _fmt = NumberFormat.decimalPattern('id_ID');

  @override
  TextEditingValue formatEditUpdate(TextEditingValue oldValue, TextEditingValue newValue) {
    final digits = newValue.text.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.isEmpty) return const TextEditingValue();
    final trimmed = digits.length > 15 ? digits.substring(0, 15) : digits;
    final text = _fmt.format(int.parse(trimmed));
    return TextEditingValue(text: text, selection: TextSelection.collapsed(offset: text.length));
  }

  static String format(num? v) => v == null || v == 0 ? '' : _fmt.format(v.round());
}

/// Input nominal Rupiah (bilangan bulat ≥ 0).
class MoneyField extends StatelessWidget {
  const MoneyField({
    super.key,
    required this.controller,
    required this.label,
    this.required = false,
    this.onChanged,
    this.helper,
  });

  final TextEditingController controller;
  final String label;
  final bool required;
  final ValueChanged<String>? onChanged;
  final String? helper;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: TextInputType.number,
        inputFormatters: [ThousandsInputFormatter()],
        decoration: InputDecoration(labelText: label, prefixText: 'Rp ', helperText: helper),
        validator: (v) => Validators.nonNegativeNumber(v, required: required),
        onChanged: onChanged,
      );

  static double read(TextEditingController c) => Validators.parseNumber(c.text) ?? 0;
}

/// Input jumlah/kuantitas (boleh desimal pakai koma: 1,5).
class QtyField extends StatelessWidget {
  const QtyField({super.key, required this.controller, required this.label, this.required = false, this.onChanged});

  final TextEditingController controller;
  final String label;
  final bool required;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) => TextFormField(
        controller: controller,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9,]'))],
        decoration: InputDecoration(labelText: label),
        validator: (v) => Validators.nonNegativeNumber(v, required: required),
        onChanged: onChanged,
      );

  static double read(TextEditingController c) =>
      double.tryParse(c.text.trim().replaceAll(',', '.')) ?? 0;

  static String format(double v) =>
      v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',');
}

/// Dialog konfirmasi standar. Mengembalikan true bila disetujui.
Future<bool> confirmDialog(BuildContext context,
    {required String title, required String message, String ok = 'Ya', bool danger = false}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
        FilledButton(
          style: danger
              ? FilledButton.styleFrom(
                  backgroundColor: Theme.of(ctx).colorScheme.error, minimumSize: const Size(0, 40))
              : FilledButton.styleFrom(minimumSize: const Size(0, 40)),
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(ok),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showSnack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
