import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/api_exceptions.dart';
import '../models/trip.dart';
import '../providers/trips_provider.dart';
import '../theme.dart';
import 'packing/packing_sheet.dart';

/// Accueil : prochain voyage (compte à rebours, météo du jour 1, valise),
/// voyage en cours, ou voyage sans dates à planifier.
class NextTripCard extends ConsumerWidget {
  final String userId;

  const NextTripCard({super.key, required this.userId});

  static DateTime _day(DateTime d) => DateTime(d.year, d.month, d.day);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final trips = ref.watch(tripsProvider(userId)).valueOrNull;
    if (trips == null || trips.isEmpty) return const SizedBox.shrink();
    final today = _day(DateTime.now());
    final active = trips.where((t) => !t.isPast && !t.id.startsWith('demo')).toList();

    DateTime? startOf(Trip t) {
      final d = DateTime.tryParse(t.startDate ?? '');
      return d == null ? null : _day(d);
    }

    // 1. Voyage en cours
    for (final t in active) {
      final start = startOf(t);
      final last = t.lastDay;
      if (start != null && last != null && !start.isAfter(today) && !_day(last).isBefore(today)) {
        return _Card(trip: t, mode: _Mode.ongoing, dayIndex: today.difference(start).inDays + 1);
      }
    }
    // 2. Prochain départ
    final upcoming = active.where((t) => startOf(t)?.isAfter(today) ?? false).toList()
      ..sort((a, b) => startOf(a)!.compareTo(startOf(b)!));
    if (upcoming.isNotEmpty) {
      final t = upcoming.first;
      return _Card(trip: t, mode: _Mode.upcoming, daysLeft: startOf(t)!.difference(today).inDays);
    }
    // 3. Voyage sans dates le plus récent : on propose de le planifier
    final undated = active.where((t) => startOf(t) == null).toList()..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    if (undated.isNotEmpty) return _Card(trip: undated.first, mode: _Mode.undated, userId: userId);
    return const SizedBox.shrink();
  }
}

enum _Mode { upcoming, ongoing, undated }

class _Card extends ConsumerWidget {
  final Trip trip;
  final _Mode mode;
  final int daysLeft;
  final int dayIndex;
  final String? userId;

  const _Card({required this.trip, required this.mode, this.daysLeft = 0, this.dayIndex = 1, this.userId});

  String get _place => trip.city ?? trip.destination;

  String get _title => switch (mode) {
        _Mode.ongoing => 'En voyage à $_place',
        _Mode.undated => 'Quand pars-tu à $_place ?',
        _ => daysLeft <= 1 ? 'Départ demain pour $_place !' : '$_place dans $daysLeft jours',
      };

  String get _subtitle {
    switch (mode) {
      case _Mode.ongoing:
        return 'Jour $dayIndex sur ${trip.durationDays} · ton programme t\'attend';
      case _Mode.undated:
        return 'Ajoute tes dates : météo, rappel de départ et journal automatique';
      case _Mode.upcoming:
        final w = trip.weather.isNotEmpty ? trip.weather.first : null;
        return w != null
            ? 'Jour 1 : ${w.tempMax.round()}°C · ${w.summary.isNotEmpty ? w.summary : 'météo à suivre'}'
            : '${trip.durationDays} jours d\'aventure en vue';
    }
  }

  Future<void> _addDates(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 3),
      helpText: 'Premier jour du voyage',
      cancelText: 'Annuler',
      confirmText: 'Valider',
    );
    if (picked == null) return;
    try {
      await ref.read(tripsApiProvider).updateDates(trip.id, picked);
      if (userId != null) ref.invalidate(tripsProvider(userId!));
      ref.invalidate(tripDetailProvider(trip.id));
      messenger.showSnackBar(const SnackBar(
        backgroundColor: VoyagoColors.primary,
        content: Text('📅 C\'est noté ! On te prévient la veille du départ'),
      ));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final icon = switch (mode) {
      _Mode.ongoing => 'assets/icons3d/world_map.png',
      _Mode.undated => 'assets/icons3d/calendar.png',
      _ => 'assets/icons3d/departure.png',
    };
    final hasPacking = trip.packingTotal > 0;
    final packingRatio = hasPacking ? trip.packingPacked / trip.packingTotal : 0.0;

    return GestureDetector(
      onTap: () => context.go('/itinerary/${trip.id}'),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: VoyagoColors.primary.withValues(alpha: 0.35)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: trip.coverImageUrl != null && trip.coverImageUrl!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: trip.coverImageUrl!,
                      fit: BoxFit.cover,
                      errorWidget: (_, __, ___) => Container(color: VoyagoColors.surface),
                    )
                  : Container(color: VoyagoColors.surface),
            ),
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [const Color(0xF2101318), const Color(0xCC101318), Colors.black.withValues(alpha: 0.25)],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              mode == _Mode.upcoming ? 'PROCHAIN DÉPART' : (mode == _Mode.ongoing ? 'EN COURS' : 'À PLANIFIER'),
                              style: const TextStyle(
                                  color: VoyagoColors.primary, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 1),
                            ),
                            const SizedBox(height: 4),
                            Text(_title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800, height: 1.15)),
                            const SizedBox(height: 4),
                            Text(_subtitle,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: Colors.white70, fontSize: 12.5)),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      _Floating(child: Image.asset(icon, width: 64, height: 64)),
                    ],
                  ),
                  if (mode == _Mode.upcoming && hasPacking) ...[
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Image.asset('assets/icons3d/suitcase.png', width: 20),
                        const SizedBox(width: 6),
                        Expanded(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: packingRatio,
                              minHeight: 6,
                              backgroundColor: Colors.white24,
                              valueColor: AlwaysStoppedAnimation(packingRatio >= 1 ? VoyagoColors.primary : VoyagoColors.yellow),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text('${trip.packingPacked}/${trip.packingTotal}',
                            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ],
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      if (mode == _Mode.upcoming)
                        _Action(
                          label: hasPacking && packingRatio >= 1 ? 'Valise prête ✓' : 'Ma valise',
                          asset: 'assets/icons3d/suitcase.png',
                          filled: true,
                          onTap: () => showPackingSheet(context, tripId: trip.id, destination: _place),
                        ),
                      if (mode == _Mode.undated)
                        _Action(
                          label: 'Ajouter mes dates',
                          icon: Icons.edit_calendar_rounded,
                          filled: true,
                          onTap: () => _addDates(context, ref),
                        ),
                      const SizedBox(width: 8),
                      _Action(
                        label: mode == _Mode.ongoing ? 'Programme du jour' : 'Itinéraire',
                        icon: Icons.map_rounded,
                        onTap: () => context.go('/itinerary/${trip.id}'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Action extends StatelessWidget {
  final String label;
  final IconData? icon;
  final String? asset;
  final bool filled;
  final VoidCallback onTap;

  const _Action({required this.label, this.icon, this.asset, this.filled = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled ? VoyagoColors.primary : Colors.white.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (asset != null) Image.asset(asset!, width: 18, height: 18) else Icon(icon, size: 16, color: Colors.white),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: Colors.white, fontSize: 12.5, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Icône 3D qui flotte doucement.
class _Floating extends StatefulWidget {
  final Widget child;

  const _Floating({required this.child});

  @override
  State<_Floating> createState() => _FloatingState();
}

class _FloatingState extends State<_Floating> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2200))..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeInOut.transform(_c.value);
        return Transform.translate(offset: Offset(0, -4 + 8 * t), child: Transform.rotate(angle: -0.06 + 0.12 * t, child: child));
      },
      child: widget.child,
    );
  }
}
