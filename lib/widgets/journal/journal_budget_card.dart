import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/journal.dart';
import '../../theme.dart';

/// Bilan « Réservations & Budget » d'un voyage terminé, rangé dans le journal.
class JournalBudgetCard extends StatefulWidget {
  final String tripId;
  final JournalBudget budget;

  const JournalBudgetCard({super.key, required this.tripId, required this.budget});

  @override
  State<JournalBudgetCard> createState() => _JournalBudgetCardState();
}

class _JournalBudgetCardState extends State<JournalBudgetCard> {
  bool _expanded = false;

  static const _cats = <String, (String, Color, String)>{
    'lodging': ('Hébergement', VoyagoColors.primary, 'assets/icons3d/bed.png'),
    'transport': ('Transports', VoyagoColors.blue, 'assets/icons3d/bus.png'),
    'activities': ('Activités', VoyagoColors.yellow, 'assets/icons3d/admission_tickets.png'),
    'meals': ('Repas & extras', VoyagoColors.orange, 'assets/icons3d/fork_and_knife_with_plate.png'),
    'flights': ('Vols', Color(0xFFB57BFF), 'assets/icons3d/airplane.png'),
    'other': ('Autre', VoyagoColors.muted, 'assets/icons3d/credit_card.png'),
  };

  @override
  Widget build(BuildContext context) {
    final b = widget.budget;
    final money = NumberFormat.simpleCurrency(locale: 'fr_FR', name: b.currency, decimalDigits: 0);
    final within = b.withinBudget;
    final color = within ? VoyagoColors.primary : VoyagoColors.orange;
    final ratio = b.total <= 0 ? 0.0 : (b.spent / b.total).clamp(0.0, 1.0);
    final rows = _cats.entries.where((e) => e.key != 'flights' && (b.spentBy[e.key] ?? 0) > 0).toList();
    final bookings = _expanded ? b.bookings : b.bookings.take(4).toList();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VoyagoColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/icons3d/money_bag.png', width: 36, height: 36),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Budget du voyage',
                    style: TextStyle(color: VoyagoColors.text, fontSize: 17, fontWeight: FontWeight.w900)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  within ? 'Budget tenu 💪' : 'Dépassé de ${money.format(b.spent - b.total)}',
                  style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text.rich(
            TextSpan(
              style: const TextStyle(color: VoyagoColors.muted, fontSize: 13),
              children: [
                TextSpan(
                  text: money.format(b.spent),
                  style: const TextStyle(color: VoyagoColors.text, fontSize: 22, fontWeight: FontWeight.w900),
                ),
                TextSpan(text: '  dépensés sur place · ${b.announcedBudget ? 'budget' : 'budget estimé'} ${money.format(b.total)}'),
              ],
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: color,
              backgroundColor: VoyagoColors.cardBorder,
            ),
          ),
          if (b.flightsSpent > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text('+ ${money.format(b.flightsSpent)} de vols, suivis à part',
                  style: const TextStyle(color: VoyagoColors.muted, fontSize: 11.5)),
            ),
          if (rows.isNotEmpty) ...[
            const SizedBox(height: 12),
            for (final e in rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Image.asset(e.value.$3, width: 20, height: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(e.value.$1, style: const TextStyle(color: VoyagoColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
                    ),
                    Text(
                      [
                        money.format(b.spentBy[e.key] ?? 0),
                        if ((b.allocation[e.key] ?? 0) > 0) ' / ${money.format(b.allocation[e.key])}',
                      ].join(),
                      style: TextStyle(
                        color: (b.spentBy[e.key] ?? 0) > (b.allocation[e.key] ?? 1 << 30) ? VoyagoColors.coral : VoyagoColors.text,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          if (b.bookings.isNotEmpty) ...[
            const SizedBox(height: 10),
            const Divider(color: VoyagoColors.cardBorder, height: 1),
            const SizedBox(height: 8),
            for (final x in bookings)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(color: (_cats[x.category] ?? _cats['other']!).$2, shape: BoxShape.circle),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(x.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: VoyagoColors.muted, fontSize: 12.5)),
                    ),
                    Text(money.format(x.amount),
                        style: const TextStyle(color: VoyagoColors.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            if (b.bookings.length > 4)
              TextButton(
                onPressed: () => setState(() => _expanded = !_expanded),
                child: Text(_expanded ? 'Réduire' : 'Voir les ${b.bookings.length} dépenses',
                    style: const TextStyle(color: VoyagoColors.primary, fontWeight: FontWeight.w800)),
              ),
          ],
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => context.push('/trip/${widget.tripId}/bookings'),
              icon: const Icon(Icons.receipt_long_rounded, size: 18, color: VoyagoColors.primary),
              label: const Text('Détail des réservations',
                  style: TextStyle(color: VoyagoColors.primary, fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}
