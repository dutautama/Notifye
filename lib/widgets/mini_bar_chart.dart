import 'package:material_ui/material_ui.dart';

import '../core/formatters.dart';
import '../models/dashboard_summary.dart';

/// Grafik batang sederhana omzet 7 hari (tanpa paket tambahan).
class MiniBarChart extends StatelessWidget {
  const MiniBarChart({super.key, required this.data, this.height = 140});

  final List<DailySales> data;
  final double height;

  static const _days = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final maxVal = data.fold<double>(0, (m, d) => d.omzet > m ? d.omzet : m);

    return SizedBox(
      height: height,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < data.length; i++)
            Expanded(
              child: Tooltip(
                message: '${Fmt.date(data[i].date)}\n${Fmt.rupiah(data[i].omzet)}',
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      Text(
                        data[i].omzet == 0 ? '' : Fmt.compact(data[i].omzet),
                        style: text.labelSmall,
                        maxLines: 1,
                        overflow: TextOverflow.clip,
                      ),
                      const SizedBox(height: 2),
                      Flexible(
                        child: FractionallySizedBox(
                          heightFactor: maxVal == 0 ? 0.03 : (data[i].omzet / maxVal).clamp(0.03, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              color: i == data.length - 1 ? scheme.primary : scheme.primary.withValues(alpha: 0.45),
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
