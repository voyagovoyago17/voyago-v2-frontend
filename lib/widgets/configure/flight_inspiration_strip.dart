import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../models/trip_bookings.dart';
import '../../providers/trips_provider.dart';
import '../../theme.dart';
import 'travel_party_section.dart';

/// Inspiration budget : les vols aller-retour les moins chers depuis la ville du voyageur
/// (Aviasales via Travelpayouts). Avec un budget chiffré, seuls les vols qui y tiennent restent.
class FlightInspirationStrip extends ConsumerStatefulWidget {
  final TravelPartyValue party;
  final ValueChanged<FlightIdea> onPick;

  const FlightInspirationStrip({super.key, required this.party, required this.onPick});

  @override
  ConsumerState<FlightInspirationStrip> createState() => _FlightInspirationStripState();
}

class _FlightInspirationStripState extends ConsumerState<FlightInspirationStrip> {
  FlightInspiration? _data;
  bool _loading = true;
  Timer? _debounce;
  String _lastQuery = '';

  /// Les vols ne doivent pas manger plus de 40 % du budget : plafond par personne
  int? get _maxPrice {
    final budget = widget.party.budgetAmount;
    if (budget == null || budget <= 0) return null;
    final payers = widget.party.adults + widget.party.childrenAges.where((a) => a >= 2).length;
    return (budget * 0.4 / (payers < 1 ? 1 : payers)).round();
  }

  String get _query => '$_maxPrice|${widget.party.currency}|${widget.party.adults}|${widget.party.childrenAges.join('.')}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant FlightInspirationStrip oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_query != _lastQuery) {
      _debounce?.cancel();
      _debounce = Timer(const Duration(milliseconds: 700), _load);
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    _lastQuery = _query;
    try {
      final data = await ref.read(tripsApiProvider).getFlightInspiration(
            maxPrice: _maxPrice,
            currency: widget.party.currency,
            adults: widget.party.adults,
            childrenAges: widget.party.childrenAges,
          );
      if (mounted) {
        setState(() {
          _data = data;
          _loading = false;
        });
      }
    } catch (_) {
      // L'inspiration est un bonus : en cas d'erreur, on n'affiche simplement rien
      if (mounted) {
        setState(() {
          _data = null;
          _loading = false;
        });
      }
    }
  }

  static String _flag(String? code) {
    if (code == null || code.length != 2) return '🌍';
    return String.fromCharCodes(code.toUpperCase().codeUnits.map((c) => 0x1F1E6 + c - 65));
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (_loading) {
      return const SizedBox(
        height: 20,
        child: Align(
          alignment: Alignment.centerLeft,
          child: SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: VoyagoColors.primary)),
        ),
      );
    }
    if (data == null) return const SizedBox.shrink();
    if (data.needsCity) {
      return InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => context.push('/profile'),
        child: const Padding(
          padding: EdgeInsets.symmetric(vertical: 6),
          child: Text('✈️ Ajoute ta ville dans ton profil pour voir les vols pas chers depuis chez toi',
              style: TextStyle(color: VoyagoColors.muted, fontSize: 12)),
        ),
      );
    }
    if (data.items.isEmpty) return const SizedBox.shrink();

    final money = NumberFormat.simpleCurrency(locale: 'fr_FR', name: data.currency, decimalDigits: 0);
    final day = DateFormat('d MMM', 'fr_FR');
    String dates(FlightIdea i) {
      final d = i.departure == null ? null : DateTime.tryParse(i.departure!);
      final r = i.returnDate == null ? null : DateTime.tryParse(i.returnDate!);
      if (d == null) return 'Dates flexibles';
      return r == null ? day.format(d) : '${day.format(d)} → ${day.format(r)}';
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '✈️ Petits prix depuis ${data.originName ?? 'ta ville'}',
          style: const TextStyle(color: VoyagoColors.text, fontSize: 13, fontWeight: FontWeight.w800),
        ),
        Text(
          _maxPrice != null
              ? 'Aller-retour par personne, dans ton budget (≤ ${money.format(_maxPrice)})'
              : 'Aller-retour par personne, relevés récents',
          style: const TextStyle(color: VoyagoColors.muted, fontSize: 11.5),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 92,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            itemCount: data.items.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, i) {
              final idea = data.items[i];
              return InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  HapticFeedback.selectionClick();
                  widget.onPick(idea);
                },
                child: Container(
                  width: 150,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: VoyagoColors.background,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: i == 0 ? VoyagoColors.primary.withValues(alpha: 0.6) : VoyagoColors.cardBorder),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(_flag(idea.countryCode), style: const TextStyle(fontSize: 15)),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(idea.city,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: VoyagoColors.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      const Spacer(),
                      Text(money.format(idea.price),
                          style: const TextStyle(color: VoyagoColors.primary, fontSize: 17, fontWeight: FontWeight.w900)),
                      Text(
                        '${dates(idea)}${idea.transfers == 0 ? ' · direct' : ''}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: VoyagoColors.muted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
