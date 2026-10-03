import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme.dart';
import '../models/trip_edits.dart';

class TravelCalendarPicker extends StatefulWidget {
  final DateTime? initialStartDate;
  final DateTime? initialEndDate;
  final Function(DateTime? start, DateTime? end, int durationDays) onRangeChanged;

  /// Voyages déjà programmés : leurs jours sont hachurés et ne peuvent pas être choisis
  final List<BusyRange> busyRanges;

  /// Durée imposée (voyage existant) : un seul tap choisit le premier jour
  final int? fixedDurationDays;

  const TravelCalendarPicker({
    super.key,
    this.initialStartDate,
    this.initialEndDate,
    required this.onRangeChanged,
    this.busyRanges = const [],
    this.fixedDurationDays,
  });

  @override
  State<TravelCalendarPicker> createState() => _TravelCalendarPickerState();
}

class _TravelCalendarPickerState extends State<TravelCalendarPicker> {
  late DateTime _currentMonth;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _startDate = widget.initialStartDate;
    _endDate = widget.initialEndDate;
    final now = DateTime.now();
    _currentMonth = _startDate != null
        ? DateTime(_startDate!.year, _startDate!.month)
        : DateTime(now.year, now.month);
  }

  void _prevMonth() {
    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month);
    final prev = DateTime(_currentMonth.year, _currentMonth.month - 1);
    if (!prev.isBefore(currentMonthStart)) {
      setState(() => _currentMonth = prev);
    }
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1);
    });
  }

  static const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];
  String _short(DateTime d) => '${d.day} ${_months[d.month - 1]}';

  /// Voyage programmé qui occupe ce jour (le jour de transition reste libre)
  BusyRange? _busyOn(DateTime day) => busyConflict(widget.busyRanges, day, day);

  void _warnBusy(BusyRange r) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        backgroundColor: VoyagoColors.orange,
        behavior: SnackBarBehavior.floating,
        content: Text(
          '🧳 Déjà en voyage à ${r.destination} du ${_short(r.start)} au ${_short(r.end)}. '
          'Tu peux partir le jour de ton retour.',
        ),
      ));
  }

  void _onDateTapped(DateTime day) {
    final fixed = widget.fixedDurationDays;
    if (fixed != null) {
      final end = day.add(Duration(days: fixed - 1));
      final conflict = busyConflict(widget.busyRanges, day, end);
      if (conflict != null) return _warnBusy(conflict);
      setState(() {
        _startDate = day;
        _endDate = fixed > 1 ? end : null;
      });
      widget.onRangeChanged(day, fixed > 1 ? end : null, fixed);
      return;
    }
    final selectingEnd = _startDate != null && _endDate == null && !day.isBefore(_startDate!);
    final conflict = selectingEnd ? busyConflict(widget.busyRanges, _startDate!, day) : _busyOn(day);
    if (conflict != null) return _warnBusy(conflict);
    setState(() {
      if (_startDate == null || (_startDate != null && _endDate != null)) {
        // First tap: set start date
        _startDate = day;
        _endDate = null;
        widget.onRangeChanged(_startDate, _endDate, 1);
      } else {
        // Second tap: set end date or swap
        if (day.isBefore(_startDate!)) {
          _startDate = day;
          _endDate = null;
          widget.onRangeChanged(_startDate, _endDate, 1);
        } else {
          _endDate = day;
          final days = _endDate!.difference(_startDate!).inDays + 1;
          final clampedDays = days.clamp(1, 30);
          widget.onRangeChanged(_startDate, _endDate, clampedDays);
        }
      }
    });
  }

  void _clearDates() {
    setState(() {
      _startDate = null;
      _endDate = null;
    });
    widget.onRangeChanged(null, null, widget.fixedDurationDays ?? 5); // default fallback duration
  }

  bool _isSameDay(DateTime? a, DateTime? b) {
    if (a == null || b == null) return false;
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  bool _isInRange(DateTime day) {
    if (_startDate == null || _endDate == null) return false;
    return day.isAfter(_startDate!) && day.isBefore(_endDate!);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final monthStart = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final daysInMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 0).day;

    // In Europe / France: Monday = 1, Sunday = 7
    // Offset so Monday is 0
    final firstWeekday = monthStart.weekday; // 1 (Mon) to 7 (Sun)
    final leadingEmptyCount = (firstWeekday - 1) % 7;

    final monthName = DateFormat('MMMM yyyy', 'fr_FR').format(_currentMonth);
    final capitalizedMonthName = monthName[0].toUpperCase() + monthName.substring(1);

    final isPrevDisabled = _currentMonth.year == now.year && _currentMonth.month == now.month;

    int totalDays = 0;
    if (_startDate != null && _endDate != null) {
      totalDays = _endDate!.difference(_startDate!).inDays + 1;
    } else if (_startDate != null) {
      totalDays = 1;
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VoyagoColors.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VoyagoColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Month navigation header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: const Icon(Icons.chevron_left, color: VoyagoColors.text),
                onPressed: isPrevDisabled ? null : _prevMonth,
                disabledColor: VoyagoColors.muted.withValues(alpha: 0.3),
                splashRadius: 20,
              ),
              Text(
                capitalizedMonthName,
                style: const TextStyle(
                  color: VoyagoColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.chevron_right, color: VoyagoColors.text),
                onPressed: _nextMonth,
                splashRadius: 20,
              ),
            ],
          ),
          const SizedBox(height: 8),

          // Day of week labels
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _WeekdayLabel('L'),
              _WeekdayLabel('M'),
              _WeekdayLabel('M'),
              _WeekdayLabel('J'),
              _WeekdayLabel('V'),
              _WeekdayLabel('S'),
              _WeekdayLabel('D'),
            ],
          ),
          const SizedBox(height: 10),

          // Calendar Grid
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: leadingEmptyCount + daysInMonth,
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              mainAxisSpacing: 4,
              crossAxisSpacing: 0,
              childAspectRatio: 1.05,
            ),
            itemBuilder: (context, index) {
              if (index < leadingEmptyCount) {
                return const SizedBox.shrink();
              }
              final dayNumber = index - leadingEmptyCount + 1;
              final dayDate = DateTime(_currentMonth.year, _currentMonth.month, dayNumber);
              final isPast = dayDate.isBefore(today);
              final busy = isPast ? null : _busyOn(dayDate);

              final isStart = _isSameDay(dayDate, _startDate);
              final isEnd = _isSameDay(dayDate, _endDate);
              final inRange = _isInRange(dayDate);

              return GestureDetector(
                onTap: isPast ? null : () => _onDateTapped(dayDate),
                child: CustomPaint(
                  painter: busy != null ? const _HatchPainter() : null,
                  child: Container(
                  decoration: BoxDecoration(
                    color: inRange
                        ? VoyagoColors.primary.withValues(alpha: 0.18)
                        : (isStart && _endDate != null)
                            ? VoyagoColors.primary.withValues(alpha: 0.18)
                            : (isEnd && _startDate != null)
                                ? VoyagoColors.primary.withValues(alpha: 0.18)
                                : Colors.transparent,
                    borderRadius: isStart && isEnd
                        ? BorderRadius.circular(20)
                        : isStart
                            ? const BorderRadius.horizontal(left: Radius.circular(20))
                            : isEnd
                                ? const BorderRadius.horizontal(right: Radius.circular(20))
                                : BorderRadius.zero,
                  ),
                  child: Center(
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: (isStart || isEnd)
                            ? VoyagoColors.primary
                            : Colors.transparent,
                        shape: BoxShape.circle,
                        boxShadow: (isStart || isEnd)
                            ? [
                                BoxShadow(
                                  color: VoyagoColors.primary.withValues(alpha: 0.4),
                                  blurRadius: 8,
                                  offset: const Offset(0, 2),
                                ),
                              ]
                            : null,
                      ),
                      child: Center(
                        child: Text(
                          '$dayNumber',
                          style: TextStyle(
                            decoration: busy != null ? TextDecoration.lineThrough : null,
                            decorationColor: VoyagoColors.muted,
                            color: isPast || busy != null
                                ? VoyagoColors.muted.withValues(alpha: 0.35)
                                : (isStart || isEnd)
                                    ? Colors.white
                                    : inRange
                                        ? VoyagoColors.primaryLight
                                        : VoyagoColors.text,
                            fontWeight: (isStart || isEnd || inRange)
                                ? FontWeight.bold
                                : FontWeight.normal,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                ),
              );
            },
          ),
          if (widget.busyRanges.isNotEmpty) ...[
            const SizedBox(height: 8),
            const Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 12,
                  child: CustomPaint(painter: _HatchPainter()),
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Jours déjà pris par un voyage programmé',
                    style: TextStyle(color: VoyagoColors.muted, fontSize: 11),
                  ),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),

          // Bottom Bar: Selected days count & Clear dates
          Container(
            padding: const EdgeInsets.only(top: 10),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: VoyagoColors.cardBorder, width: 1),
              ),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.date_range,
                      size: 16,
                      color: VoyagoColors.primary,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      totalDays > 0
                          ? 'Sélectionné : $totalDays jour${totalDays > 1 ? 's' : ''}'
                          : 'Aucune date choisie',
                      style: TextStyle(
                        color: totalDays > 0 ? VoyagoColors.text : VoyagoColors.muted,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                if (_startDate != null)
                  TextButton(
                    onPressed: _clearDates,
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Effacer les dates',
                      style: TextStyle(
                        color: VoyagoColors.coral,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Hachures diagonales des jours déjà pris
class _HatchPainter extends CustomPainter {
  const _HatchPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    canvas.save();
    canvas.clipRRect(RRect.fromRectAndRadius(rect.deflate(2), const Radius.circular(8)));
    canvas.drawRect(rect, Paint()..color = VoyagoColors.orange.withValues(alpha: 0.08));
    final paint = Paint()
      ..color = VoyagoColors.orange.withValues(alpha: 0.35)
      ..strokeWidth = 1.2;
    for (double x = -size.height; x < size.width; x += 6) {
      canvas.drawLine(Offset(x, size.height), Offset(x + size.height, 0), paint);
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _WeekdayLabel extends StatelessWidget {
  final String label;
  const _WeekdayLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 36,
      child: Center(
        child: Text(
          label,
          style: const TextStyle(
            color: VoyagoColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}
