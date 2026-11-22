import 'package:material_ui/material_ui.dart';

const trxTypeLabels = {'sale': 'Penjualan', 'purchase': 'Pembelian'};
const paymentMethodLabels = {
  'tunai': 'Tunai',
  'transfer': 'Transfer bank',
  'qris': 'QRIS',
  'ewallet': 'E-wallet',
  'lainnya': 'Lainnya',
};
const trxStatusLabels = {'lunas': 'Lunas', 'sebagian': 'Sebagian', 'belum': 'Belum bayar'};

/// Chip status pembayaran berwarna.
class TrxStatusChip extends StatelessWidget {
  const TrxStatusChip(this.status, {super.key, this.cancelled = false});
  final String status;
  final bool cancelled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (label, bg, fg) = cancelled
        ? ('Dibatalkan', scheme.surfaceContainerHighest, scheme.onSurfaceVariant)
        : switch (status) {
            'lunas' => ('Lunas', Colors.green.shade100, Colors.green.shade900),
            'sebagian' => ('Sebagian', Colors.orange.shade100, Colors.orange.shade900),
            _ => ('Belum bayar', scheme.errorContainer, scheme.onErrorContainer),
          };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(
        label,
        style: TextStyle(color: fg, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
