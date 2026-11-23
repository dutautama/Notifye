import 'package:material_ui/material_ui.dart';

import '../core/formatters.dart';
import '../models/dashboard_summary.dart';

/// Grafik batang sederhana laba 7 hari (tanpa paket tambahan). Hari rugi ditandai merah.
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({super.key, required this.data, this.height = 140});

  final List<DailySales> data;
  final double height;

  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final maxVal = data.fold<double>(0, (m, d) => d.profit.abs() > m ? d.profit.abs() : m);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < data.length; i++)
            Expanded(
              child: Tooltip(
                message: '${Fmt.date(data[i].date)}\nLaba ${Fmt.rupiah(data[i].profit)}\nOmzet ${Fmt.rupiah(data[i].omzet)}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        data[i].profit == 0 ? '' : Fmt.compact(data[i].profit),
                        style: text.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                      const SizedBox(height: 2),
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: maxVal == 0 ? 0.03 : (data[i].profit.abs() / maxVal).clamp(0.03, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: (data[i].profit < 0 ? scheme.error : scheme.primary)
                                .withValues(alpha: i == data.length - 1 ? 1 : 0.45),
                              borderRadius: const BorderRadius.vertical(top: Radius.circular(6)),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _days[data[i].date.weekday - 1],
                        style: text.labelSmall?.copyWith(color: scheme.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
