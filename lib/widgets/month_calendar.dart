import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';

DateTime dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);
bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

/// Hari pertama (Senin) pada grid bulan yang memuat [month].
DateTime gridStartForMonth(DateTime month) {
  final first = DateTime(month.year, month.month, 1);
  return first.subtract(Duration(days: first.weekday - 1));
}

/// Senin pada minggu yang memuat [day].
DateTime weekStart(DateTime day) => dateOnly(day).subtract(Duration(days: day.weekday - 1));

/// Kalender ringan (bulan/minggu), Senin sebagai awal minggu, penanda jumlah acara per hari.
class MonthCalendar extends StatelessWidget {
  const MonthCalendar({
    super.key,
    required this.focused,
    required this.selected,
    required this.weekMode,
    required this.eventCount,
    required this.onSelect,
    required this.onFocusChange,
    required this.onModeChange,
  });

  final DateTime focused;
  final DateTime selected;
  final bool weekMode;
  final int Function(DateTime day) eventCount;
  final ValueChanged<DateTime> onSelect;
  final ValueChanged<DateTime> onFocusChange;
  final ValueChanged<bool> onModeChange;

  static const _weekdays = ['Sen', 'Sel', 'Rab', 'Kam', 'Jum', 'Sab', 'Min'];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final today = DateTime.now();
    final start = weekMode ? weekStart(focused) : gridStartForMonth(focused);
    final days = weekMode ? 7 : 42;
    final title = weekMode
        ? '${DateFormat('d MMM', 'id_ID').format(start)} – '
            '${DateFormat('d MMM yyyy', 'id_ID').format(start.add(const Duration(days: 6)))}'
        : DateFormat('MMMM yyyy', 'id_ID').format(focused);

    void shift(int dir) => onFocusChange(weekMode
        ? focused.add(Duration(days: 7 * dir))
        : DateTime(focused.year, focused.month + dir, 1));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(children: [
        Row(children: [
          IconButton(tooltip: 'Sebelumnya', icon: const Icon(Icons.chevron_left), onPressed: () => shift(-1)),
          Expanded(
            child: Text(title,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleMedium,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ),
          IconButton(tooltip: 'Berikutnya', icon: const Icon(Icons.chevron_right), onPressed: () => shift(1)),
          TextButton(
            onPressed: () => onModeChange(!weekMode),
            child: Text(weekMode ? 'Bulan' : 'Minggu'),
          ),
        ]),
        Row(children: [
          for (final w in _weekdays)
            Expanded(
              child: Center(
                child: Text(w, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ),
            ),
        ]),
        const SizedBox(height: 4),
        for (var row = 0; row < days ~/ 7; row++)
          Row(children: [
            for (var col = 0; col < 7; col++)
              Expanded(
                child: _DayCell(
                  day: start.add(Duration(days: row * 7 + col)),
                  inMonth: weekMode || start.add(Duration(days: row * 7 + col)).month == focused.month,
                  isToday: sameDay(start.add(Duration(days: row * 7 + col)), today),
                  isSelected: sameDay(start.add(Duration(days: row * 7 + col)), selected),
                  events: eventCount(start.add(Duration(days: row * 7 + col))),
                  onTap: onSelect,
                ),
              ),
          ]),
      ]),
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.day,
    required this.inMonth,
    required this.isToday,
    required this.isSelected,
    required this.events,
    required this.onTap,
  });

  final DateTime day;
  final bool inMonth;
  final bool isToday;
  final bool isSelected;
  final int events;
  final ValueChanged<DateTime> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fg = isSelected
        ? scheme.onPrimary
        : inMonth
            ? scheme.onSurface
            : scheme.onSurface.withValues(alpha: 0.35);
    return Semantics(
      button: true,
      selected: isSelected,
      label: '${DateFormat('d MMMM', 'id_ID').format(day)}${events > 0 ? ', $events jadwal' : ''}',
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: () => onTap(day),
        child: SizedBox(
          height: 46,
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 32,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isSelected ? scheme.primary : (isToday ? scheme.primary.withValues(alpha: 0.18) : null),
              ),
              child: Text('${day.day}', style: TextStyle(color: fg, fontWeight: isToday ? FontWeight.bold : null)),
            ),
            SizedBox(
              height: 8,
              child: events == 0
                  ? null
                  : Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                      for (var i = 0; i < (events > 3 ? 3 : events); i++)
                        Container(
                          width: 5,
                          height: 5,
                          margin: const EdgeInsets.symmetric(horizontal: 1, vertical: 1.5),
                          decoration: BoxDecoration(color: scheme.primary, shape: BoxShape.circle),
                        ),
                    ]),
            ),
          ]),
        ),
      ),
    );
  }
}
