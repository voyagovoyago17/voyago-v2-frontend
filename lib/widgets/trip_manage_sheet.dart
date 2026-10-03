import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';

import '../api/api.dart';
import '../models/poi.dart';
import '../models/trip.dart';
import '../models/trip_edits.dart';
import '../providers/auth_provider.dart';
import '../providers/trips_provider.dart';
import '../services/api_service.dart' show ApiService;
import '../theme.dart';
import 'travel_calendar_picker.dart';

// =============================================================================
// Choisir le premier jour (voyage existant) : jours passés grisés, voyages
// programmés hachurés, la durée du voyage est conservée.
// =============================================================================

Future<DateTime?> showTripStartPicker(
  BuildContext context, {
  required int durationDays,
  String? excludeTripId,
  DateTime? initial,
  String title = 'Premier jour du voyage',
}) {
  return showModalBottomSheet<DateTime>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VoyagoColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _StartPickerSheet(
      durationDays: durationDays,
      excludeTripId: excludeTripId,
      initial: initial,
      title: title,
    ),
  );
}

class _StartPickerSheet extends ConsumerStatefulWidget {
  final int durationDays;
  final String? excludeTripId;
  final DateTime? initial;
  final String title;

  const _StartPickerSheet({required this.durationDays, this.excludeTripId, this.initial, required this.title});

  @override
  ConsumerState<_StartPickerSheet> createState() => _StartPickerSheetState();
}

class _StartPickerSheetState extends ConsumerState<_StartPickerSheet> {
  DateTime? _start;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final init = widget.initial;
    if (init != null && !init.isBefore(today)) _start = DateTime(init.year, init.month, init.day);
  }

  @override
  Widget build(BuildContext context) {
    final busy = ref.watch(busyDatesProvider(widget.excludeTripId));
    final days = widget.durationDays;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _Grabber(),
              Text(widget.title,
                  style: const TextStyle(color: VoyagoColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              Text(
                'Ton voyage dure $days jour${days > 1 ? 's' : ''} : choisis le jour du départ.',
                style: const TextStyle(color: VoyagoColors.muted, fontSize: 13),
              ),
              const SizedBox(height: 12),
              busy.when(
                data: (ranges) => TravelCalendarPicker(
                  initialStartDate: _start,
                  initialEndDate: _start?.add(Duration(days: days - 1)),
                  busyRanges: ranges,
                  fixedDurationDays: days,
                  onRangeChanged: (start, _, __) => setState(() => _start = start),
                ),
                loading: () => const SizedBox(
                  height: 320,
                  child: Center(child: CircularProgressIndicator(color: VoyagoColors.primary)),
                ),
                error: (_, __) => const SizedBox.shrink(),
              ),
              const SizedBox(height: 14),
              ElevatedButton(
                onPressed: _start == null ? null : () => Navigator.of(context).pop(_start),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VoyagoColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(
                  _start == null
                      ? 'Choisis une date'
                      : 'Partir le ${DateFormat('d MMMM', 'fr_FR').format(_start!)}',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// « Gérer mon voyage » : dates, lieux, journées, plan B, tout refaire, annuler
// =============================================================================

Future<void> showTripManageSheet(
  BuildContext context, {
  required Trip trip,
  required ValueChanged<Trip> onTripChanged,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => _TripManageSheet(trip: trip, onTripChanged: onTripChanged, controller: controller),
    ),
  );
}

class _TripManageSheet extends ConsumerStatefulWidget {
  final Trip trip;
  final ValueChanged<Trip> onTripChanged;
  final ScrollController controller;

  const _TripManageSheet({required this.trip, required this.onTripChanged, required this.controller});

  @override
  ConsumerState<_TripManageSheet> createState() => _TripManageSheetState();
}

class _TripManageSheetState extends ConsumerState<_TripManageSheet> {
  late Trip _trip = widget.trip;
  TripEditOptions? _options;
  String? _error;

  /// Modification IA en cours (quelques secondes à une minute)
  String? _working;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final o = await ref.read(tripsApiProvider).getEditOptions(_trip.id);
      if (mounted) setState(() => _options = o);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  void _applied(TripEditResult r, String message) {
    setState(() {
      _trip = r.trip;
      _options = r.options;
    });
    widget.onTripChanged(r.trip);
    _refreshLists();
    _toast(message);
  }

  void _refreshLists() {
    ref.invalidate(tripDetailProvider(_trip.id));
    ref.invalidate(tripGemsProvider(_trip.id));
    ref.invalidate(busyDatesProvider);
    final userId = ref.read(currentUserProvider)?.userId;
    if (userId != null) ref.invalidate(tripsProvider(userId));
  }

  void _toast(String message, {Color color = VoyagoColors.primary}) {
    ScaffoldMessenger.maybeOf(context)
      ?..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(backgroundColor: color, behavior: SnackBarBehavior.floating, content: Text(message)));
  }

  Future<void> _quota(String reason) async {
    final o = _options;
    if (o == null) return;
    final updated = await showEditQuotaSheet(context, tripId: _trip.id, options: o, reason: reason);
    if (updated != null && mounted) setState(() => _options = updated);
  }

  /// Lance une modification ; un quota épuisé (402) ouvre les solutions pour continuer
  Future<void> _run(String label, String reason, Future<TripEditResult> Function() action, String done) async {
    setState(() => _working = label);
    try {
      final r = await action();
      if (mounted) _applied(r, done);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 402) {
        await _quota(reason);
      } else {
        _toast(e.message, color: VoyagoColors.coral);
      }
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  // --- Actions ---------------------------------------------------------------

  Future<void> _shiftDates() async {
    final o = _options!;
    if (!o.isPro && o.dateChanges.remaining == 0 && _trip.startDate != null) return _quota('date');
    final picked = await showTripStartPicker(
      context,
      durationDays: _trip.durationDays,
      excludeTripId: _trip.id,
      initial: DateTime.tryParse(_trip.startDate ?? ''),
      title: _trip.startDate == null ? 'Programmer ce voyage' : 'Décaler mon voyage',
    );
    if (picked == null || !mounted) return;
    setState(() => _working = 'Mise à jour des dates et de la météo…');
    try {
      final trip = await ref.read(tripsApiProvider).updateDates(_trip.id, picked);
      final o2 = await ref.read(tripsApiProvider).getEditOptions(_trip.id);
      if (mounted) _applied(TripEditResult(trip, o2), '📅 Nouvelles dates enregistrées : météo et rappels mis à jour');
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 402) {
        await _quota('date');
      } else {
        _toast(e.message, color: VoyagoColors.coral);
      }
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  Future<void> _replacePlace() async {
    final o = _options!;
    if (!o.swaps.unlimited && o.swaps.remaining == 0) return _quota('swap');
    final poi = await _pickPoi();
    if (poi == null || !mounted) return;
    final r = await showPoiAlternativesSheet(context, trip: _trip, poi: poi, options: o);
    if (r != null && mounted) _applied(r, '🔁 Lieu remplacé par un lieu vérifié');
  }

  Future<void> _redoDay() async {
    final o = _options!;
    if (o.redosRemaining == 0) return _quota('redo');
    final day = await _pickDay(title: 'Quelle journée refaire ?');
    if (day == null || !mounted) return;
    final ok = await _confirm(
      title: 'Refaire le jour $day ?',
      body: 'Voyagooo prépare un nouveau programme avec des lieux réels vérifiés. '
          'Cela utilise 1 modification (${o.redosRemaining} restante${o.redosRemaining > 1 ? 's' : ''}).',
      cta: 'Refaire la journée',
    );
    if (ok != true) return;
    await _run(
      'Voyagooo prépare ta nouvelle journée… (lieux vérifiés)',
      'redo',
      () => ref.read(tripsApiProvider).redoDay(_trip.id, day),
      '✨ Jour $day refait !',
    );
  }

  Future<void> _planB() async {
    final o = _options!;
    if (!o.isPro && !o.planBGift) return _quota('plan_b');
    final day = await _pickDay(title: 'Quelle journée mettre à l’abri ?', exclude: o.planBDays);
    if (day == null || !mounted) return;
    await _run(
      'Plan B : musées, marchés couverts, cafés… à l’abri de la pluie',
      'plan_b',
      () => ref.read(tripsApiProvider).redoDay(_trip.id, day, planB: true),
      '☔ Plan B prêt pour le jour $day',
    );
  }

  Future<void> _regenerate() async {
    final o = _options!;
    if (o.redosRemaining == 0) return _quota('redo');
    final changes = await showRegenerateSheet(context, trip: _trip, remaining: o.redosRemaining);
    if (changes == null || !mounted) return;
    await _run(
      'Voyagooo refait tout ton voyage… (lieux vérifiés)',
      'redo',
      () => ref.read(tripsApiProvider).regenerate(_trip.id, changes),
      '🧭 Ton nouveau voyage est prêt !',
    );
  }

  Future<void> _cancel() async {
    final ok = await _confirm(
      title: 'Annuler ce voyage ?',
      body: 'Il rejoint tes idées sans dates, avec son itinéraire et son budget. '
          'Tu pourras le reprogrammer quand tu veux. C’est gratuit.',
      cta: 'Annuler le voyage',
      danger: true,
    );
    if (ok != true || !mounted) return;
    setState(() => _working = 'Annulation…');
    try {
      final trip = await ref.read(tripsApiProvider).cancelTrip(_trip.id);
      if (!mounted) return;
      widget.onTripChanged(trip);
      _refreshLists();
      Navigator.of(context).pop();
      _toast('🗂️ Voyage annulé : retrouve-le dans le menu ☰ › Mes idées de voyage');
    } on ApiException catch (e) {
      if (mounted) _toast(e.message, color: VoyagoColors.coral);
    } finally {
      if (mounted) setState(() => _working = null);
    }
  }

  // --- Petits sélecteurs -------------------------------------------------------

  int get _firstEditableDay => (_options?.started ?? false) ? (_options!.currentDay).clamp(1, _trip.durationDays) : 1;

  String _dayLabel(int day) {
    final start = DateTime.tryParse(_trip.startDate ?? '');
    if (start == null) return 'Jour $day';
    final d = start.add(Duration(days: day - 1));
    return 'Jour $day · ${DateFormat('EEE d MMM', 'fr_FR').format(d)}';
  }

  Future<int?> _pickDay({required String title, List<int> exclude = const []}) {
    final days = [
      for (var d = _firstEditableDay; d <= _trip.durationDays; d++)
        if (!exclude.contains(d)) d,
    ];
    return showModalBottomSheet<int>(
      context: context,
      backgroundColor: VoyagoColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          children: [
            const _Grabber(),
            Text(title, style: const TextStyle(color: VoyagoColors.text, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            if (days.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text('Aucune journée disponible.', style: TextStyle(color: VoyagoColors.muted)),
              ),
            for (final d in days)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(_dayLabel(d), style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w700)),
                subtitle: Text(
                  _trip.poisForDay(d).map((p) => p.name).take(3).join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
                ),
                trailing: const Icon(Icons.chevron_right, color: VoyagoColors.muted),
                onTap: () => Navigator.of(ctx).pop(d),
              ),
          ],
        ),
      ),
    );
  }

  Future<POI?> _pickPoi() {
    final days = [for (var d = _firstEditableDay; d <= _trip.durationDays; d++) d];
    return showModalBottomSheet<POI>(
      context: context,
      isScrollControlled: true,
      backgroundColor: VoyagoColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.92,
        expand: false,
        builder: (_, controller) => ListView(
          controller: controller,
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          children: [
            const _Grabber(),
            const Text('Quel lieu remplacer ?',
                style: TextStyle(color: VoyagoColors.text, fontSize: 17, fontWeight: FontWeight.w800)),
            for (final d in days) ...[
              Padding(
                padding: const EdgeInsets.only(top: 14, bottom: 4),
                child: Text(_dayLabel(d).toUpperCase(),
                    style: const TextStyle(color: VoyagoColors.muted, fontSize: 11, fontWeight: FontWeight.w800)),
              ),
              for (final p in _trip.poisForDay(d))
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  leading: _Thumb(url: p.imageUrl),
                  title: Text(p.name, style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w600)),
                  trailing: const Icon(Icons.swap_horiz_rounded, color: VoyagoColors.primary),
                  onTap: () => Navigator.of(ctx).pop(p),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<bool?> _confirm({required String title, required String body, required String cta, bool danger = false}) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VoyagoColors.surface,
        title: Text(title, style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w800)),
        content: Text(body, style: const TextStyle(color: VoyagoColors.muted, height: 1.4)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Plus tard')),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: danger ? VoyagoColors.coral : VoyagoColors.primary,
              foregroundColor: Colors.white,
            ),
            child: Text(cta),
          ),
        ],
      ),
    );
  }

  // --- Interface ---------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final o = _options;
    return Container(
      decoration: const BoxDecoration(
        color: VoyagoColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Stack(
        children: [
          ListView(
            controller: widget.controller,
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
            children: [
              const _Grabber(),
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Gérer mon voyage',
                            style: TextStyle(color: VoyagoColors.text, fontSize: 20, fontWeight: FontWeight.w900)),
                        Text(_trip.city ?? _trip.destination,
                            style: const TextStyle(color: VoyagoColors.muted, fontSize: 13)),
                      ],
                    ),
                  ),
                  if (o != null) _PlanChip(options: o),
                ],
              ),
              const SizedBox(height: 14),
              if (_error != null)
                Text(_error!, style: const TextStyle(color: VoyagoColors.coral))
              else if (o == null)
                const Padding(
                  padding: EdgeInsets.all(40),
                  child: Center(child: CircularProgressIndicator(color: VoyagoColors.primary)),
                )
              else ...[
                _CountersCard(options: o, onMore: () => _quota('redo')),
                const SizedBox(height: 14),
                if (!o.canEditPlaces)
                  const _InfoBanner(
                    emoji: '🗳️',
                    text: 'Itinéraire voté par ta tribu : seul son fondateur peut changer les lieux. '
                        'Tu peux toujours décaler tes dates ou annuler.',
                  ),
                _ActionTile(
                  emoji: '📅',
                  title: _trip.startDate == null ? 'Programmer les dates' : 'Décaler les dates',
                  subtitle: !o.canShiftDates
                      ? 'Le voyage a commencé : les dates ne bougent plus'
                      : o.isPro
                          ? 'Sans limite avant le départ'
                          : _trip.startDate == null
                              ? 'Choisis ton départ : les jours déjà pris sont hachurés'
                              : o.dateChanges.remaining > 0
                                  ? '1 décalage offert sur ce voyage'
                                  : 'Décalage offert utilisé · illimité avec Pro',
                  locked: o.canShiftDates && !o.isPro && _trip.startDate != null && o.dateChanges.remaining == 0,
                  enabled: o.canShiftDates,
                  onTap: _shiftDates,
                ),
                _ActionTile(
                  emoji: '🔁',
                  title: 'Remplacer un lieu',
                  subtitle: o.swaps.unlimited
                      ? 'À volonté · parmi des lieux réels vérifiés à proximité'
                      : '${o.swaps.remaining} sur ${o.swaps.limit} restant${o.swaps.remaining > 1 ? 's' : ''} · lieux réels vérifiés',
                  locked: !o.swaps.unlimited && o.swaps.remaining == 0,
                  enabled: o.canEditPlaces && !o.finished,
                  onTap: _replacePlace,
                ),
                _ActionTile(
                  emoji: '✨',
                  title: 'Refaire une journée',
                  subtitle: o.redosRemaining > 0
                      ? (o.freeTrial && !o.isPro
                          ? '1 essai offert · nouveau programme vérifié'
                          : '${o.redosRemaining} modification${o.redosRemaining > 1 ? 's' : ''} restante${o.redosRemaining > 1 ? 's' : ''} sur ce voyage')
                      : 'Plus de modification · ajoute des crédits',
                  locked: o.redosRemaining == 0,
                  enabled: o.canEditPlaces && !o.finished,
                  onTap: _redoDay,
                ),
                _ActionTile(
                  emoji: '☔',
                  title: 'Plan B pluie',
                  subtitle: o.isPro
                      ? 'Une journée à l’abri en un geste · ne compte pas dans tes modifications'
                      : o.planBGift
                          ? '🎁 Offert par ta pépite légendaire : une journée à l’abri en un geste'
                          : 'Avantage Pro : musées, marchés couverts, cafés quand il pleut',
                  locked: !o.isPro && !o.planBGift,
                  badge: o.isPro ? null : (o.planBGift ? 'OFFERT' : 'PRO'),
                  enabled: o.canEditPlaces && !o.finished,
                  onTap: _planB,
                ),
                _ActionTile(
                  emoji: '🧭',
                  title: 'Tout refaire',
                  subtitle: o.canRegenerate
                      ? 'Rythme, budget, envies ou durée · avant le départ'
                      : 'Le voyage a commencé : refais plutôt une journée',
                  locked: o.canRegenerate && o.redosRemaining == 0,
                  enabled: o.canEditPlaces && o.canRegenerate,
                  onTap: _regenerate,
                ),
                if (o.canCancel)
                  _ActionTile(
                    emoji: '🗂️',
                    title: 'Annuler le voyage',
                    subtitle: 'Gratuit · il rejoint tes idées, prêt à être reprogrammé',
                    danger: true,
                    onTap: _cancel,
                  ),
              ],
            ],
          ),
          if (_working != null)
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  color: VoyagoColors.background.withValues(alpha: 0.88),
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const CircularProgressIndicator(color: VoyagoColors.primary),
                    const SizedBox(height: 18),
                    Text(_working!,
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: VoyagoColors.text, fontSize: 15, fontWeight: FontWeight.w700)),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _PlanChip extends StatelessWidget {
  final TripEditOptions options;
  const _PlanChip({required this.options});

  @override
  Widget build(BuildContext context) {
    final pro = options.isPro;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: (pro ? VoyagoColors.yellow : VoyagoColors.muted).withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (pro ? VoyagoColors.yellow : VoyagoColors.muted).withValues(alpha: 0.5)),
      ),
      child: Text(
        '${pro ? '💎 ' : ''}${options.planLabel}',
        style: TextStyle(color: pro ? VoyagoColors.yellow : VoyagoColors.muted, fontSize: 12, fontWeight: FontWeight.w800),
      ),
    );
  }
}

class _CountersCard extends StatelessWidget {
  final TripEditOptions options;
  final VoidCallback onMore;
  const _CountersCard({required this.options, required this.onMore});

  @override
  Widget build(BuildContext context) {
    final o = options;
    Widget counter(String value, String label) => Expanded(
          child: Column(
            children: [
              Text(value, style: const TextStyle(color: VoyagoColors.text, fontSize: 20, fontWeight: FontWeight.w900)),
              const SizedBox(height: 2),
              Text(label,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: VoyagoColors.muted, fontSize: 11, height: 1.2)),
            ],
          ),
        );
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VoyagoColors.cardBorder),
      ),
      child: Column(
        children: [
          Row(
            children: [
              counter('${o.redosRemaining}', 'journées à\nrefaire'),
              counter(o.swaps.unlimited ? '∞' : '${o.swaps.remaining}', 'lieux à\nremplacer'),
              counter(o.isPro ? '∞' : '${o.dateChanges.remaining}', 'décalage\nde dates'),
            ],
          ),
          if (o.shardBalance != null) ...[
            const SizedBox(height: 10),
            Text(
              '💎 ${o.shardBalance} Éclats · ${o.shardsPerCredit} = 1 modification'
              '${o.shardsEarnedOnTrip > 0 ? ' · ${o.shardsEarnedOnTrip} gagnés sur ce voyage' : ''}',
              textAlign: TextAlign.center,
              style: const TextStyle(color: VoyagoColors.blue, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
          if (o.extraCredits > 0) ...[
            const SizedBox(height: 8),
            Text('dont ${o.extraCredits} crédit${o.extraCredits > 1 ? 's' : ''} en plus',
                style: const TextStyle(color: VoyagoColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
          ],
          const SizedBox(height: 10),
          InkWell(
            onTap: onMore,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Text(
                o.isPro
                    ? '+ Ajouter des modifications (${o.shardsPerCredit} Éclats 💎 ou pack ${_euro(o.packPrice)})'
                    : '💎 Pro : 2 à 6 journées refaites par voyage, lieux et dates à volonté',
                textAlign: TextAlign.center,
                style: const TextStyle(color: VoyagoColors.primary, fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionTile extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final bool enabled;
  final bool locked;
  final bool danger;
  final String? badge;

  const _ActionTile({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.enabled = true,
    this.locked = false,
    this.danger = false,
    this.badge,
  });

  @override
  Widget build(BuildContext context) {
    final color = danger ? VoyagoColors.coral : VoyagoColors.text;
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: _TileCard(
        borderColor: danger ? VoyagoColors.coral.withValues(alpha: 0.35) : VoyagoColors.cardBorder,
        child: ListTile(
          onTap: enabled ? onTap : null,
          leading: Text(emoji, style: const TextStyle(fontSize: 24)),
          title: Row(
            children: [
              Flexible(child: Text(title, style: TextStyle(color: color, fontWeight: FontWeight.w800))),
              if (badge != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(color: VoyagoColors.yellow, borderRadius: BorderRadius.circular(6)),
                  child: Text(badge!,
                      style: const TextStyle(color: Colors.black, fontSize: 10, fontWeight: FontWeight.w900)),
                ),
              ],
            ],
          ),
          subtitle: Text(subtitle, style: const TextStyle(color: VoyagoColors.muted, fontSize: 12.5)),
          trailing: Icon(
            locked ? Icons.lock_outline_rounded : Icons.chevron_right_rounded,
            color: locked ? VoyagoColors.yellow : VoyagoColors.muted,
          ),
        ),
      ),
    );
  }
}

/// Carte d'une ligne cliquable (Material : l'effet du tap reste visible)
class _TileCard extends StatelessWidget {
  final Widget child;
  final Color borderColor;
  const _TileCard({required this.child, this.borderColor = VoyagoColors.cardBorder});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: VoyagoColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: borderColor),
        ),
        child: child,
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final String emoji;
  final String text;
  const _InfoBanner({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: VoyagoColors.blue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VoyagoColors.blue.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: VoyagoColors.text, fontSize: 12.5, height: 1.35))),
        ],
      ),
    );
  }
}

// =============================================================================
// Remplacer un lieu : lieux réels vérifiés à proximité (aucune invention)
// =============================================================================

Future<TripEditResult?> showPoiAlternativesSheet(
  BuildContext context, {
  required Trip trip,
  required POI poi,
  TripEditOptions? options,
}) {
  return showModalBottomSheet<TripEditResult>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, controller) => _AlternativesSheet(trip: trip, poi: poi, options: options, controller: controller),
    ),
  );
}

class _AlternativesSheet extends ConsumerStatefulWidget {
  final Trip trip;
  final POI poi;
  final TripEditOptions? options;
  final ScrollController controller;

  const _AlternativesSheet({required this.trip, required this.poi, this.options, required this.controller});

  @override
  ConsumerState<_AlternativesSheet> createState() => _AlternativesSheetState();
}

class _AlternativesSheetState extends ConsumerState<_AlternativesSheet> {
  List<PoiAlternative>? _items;
  TripEditOptions? _options;
  String? _error;
  String? _saving;

  @override
  void initState() {
    super.initState();
    _options = widget.options;
    _load();
  }

  Future<void> _load() async {
    final api = ref.read(tripsApiProvider);
    try {
      final results = await Future.wait([
        api.getPoiAlternatives(widget.trip.id, day: widget.poi.day, order: widget.poi.order),
        if (_options == null) api.getEditOptions(widget.trip.id),
      ]);
      if (!mounted) return;
      setState(() {
        _items = results[0] as List<PoiAlternative>;
        if (results.length > 1) _options = results[1] as TripEditOptions;
      });
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _pick(PoiAlternative alt) async {
    final o = _options;
    if (o != null && !o.swaps.unlimited && o.swaps.remaining == 0) {
      await showEditQuotaSheet(context, tripId: widget.trip.id, options: o, reason: 'swap');
      return;
    }
    setState(() => _saving = alt.name);
    try {
      final r = await ref
          .read(tripsApiProvider)
          .swapPoi(widget.trip.id, day: widget.poi.day, order: widget.poi.order, name: alt.name);
      if (mounted) Navigator.of(context).pop(r);
    } on ApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 402 && o != null) {
        await showEditQuotaSheet(context, tripId: widget.trip.id, options: o, reason: 'swap');
      } else {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _options;
    return Container(
      decoration: const BoxDecoration(
        color: VoyagoColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: ListView(
        controller: widget.controller,
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 28),
        children: [
          const _Grabber(),
          Text('Remplacer « ${widget.poi.name} »',
              style: const TextStyle(color: VoyagoColors.text, fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 4),
          Text(
            [
              'Lieux réels vérifiés, du plus proche au plus loin',
              if (o != null)
                o.swaps.unlimited
                    ? 'remplacements illimités (Pro)'
                    : '${o.swaps.remaining} remplacement${o.swaps.remaining > 1 ? 's' : ''} restant${o.swaps.remaining > 1 ? 's' : ''}',
            ].join(' · '),
            style: const TextStyle(color: VoyagoColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          if (_error != null)
            Text(_error!, style: const TextStyle(color: VoyagoColors.coral))
          else if (_items == null)
            const Padding(
              padding: EdgeInsets.all(40),
              child: Center(child: CircularProgressIndicator(color: VoyagoColors.primary)),
            )
          else if (_items!.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Aucun autre lieu vérifié à proximité pour le moment. Essaie avec une autre étape.',
                style: TextStyle(color: VoyagoColors.muted),
              ),
            )
          else
            for (final alt in _items!)
              _TileCard(
                child: ListTile(
                  onTap: _saving == null ? () => _pick(alt) : null,
                  leading: _Thumb(url: alt.imageUrl, size: 52),
                  title: Text(alt.name, style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w700)),
                  subtitle: Text(
                    [
                      if (alt.kind != null && alt.kind!.isNotEmpty && alt.kind != 'lieu')
                        '${alt.kind![0].toUpperCase()}${alt.kind!.substring(1)}',
                      alt.distanceKm < 1 ? '${(alt.distanceKm * 1000).round()} m' : '${alt.distanceKm.toStringAsFixed(1)} km',
                      '✓ vérifié',
                    ].join(' · '),
                    style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
                  ),
                  trailing: _saving == alt.name
                      ? const SizedBox(
                          width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: VoyagoColors.primary))
                      : const Icon(Icons.swap_horiz_rounded, color: VoyagoColors.primary),
                ),
              ),
        ],
      ),
    );
  }
}

// =============================================================================
// Tout refaire (avant le départ)
// =============================================================================

Future<Map<String, dynamic>?> showRegenerateSheet(BuildContext context, {required Trip trip, required int remaining}) {
  return showModalBottomSheet<Map<String, dynamic>>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VoyagoColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _RegenerateSheet(trip: trip, remaining: remaining),
  );
}

class _RegenerateSheet extends StatefulWidget {
  final Trip trip;
  final int remaining;
  const _RegenerateSheet({required this.trip, required this.remaining});

  @override
  State<_RegenerateSheet> createState() => _RegenerateSheetState();
}

class _RegenerateSheetState extends State<_RegenerateSheet> {
  static const _paces = [('tranquille', 'Tranquille', '🧘'), ('equilibre', 'Équilibré', '🚶'), ('intensif', 'Intensif', '🏃')];
  static const _budgets = [('economique', 'Économique', '💰'), ('moyen', 'Moyen', '💳'), ('luxe', 'Luxe', '💎')];

  late String _pace = widget.trip.pace;
  late String _budget = widget.trip.budget;
  late int _days = widget.trip.durationDays;

  Widget _chips(List<(String, String, String)> items, String value, ValueChanged<String> onChanged) => Wrap(
        spacing: 8,
        children: [
          for (final (key, label, emoji) in items)
            ChoiceChip(
              label: Text('$emoji $label'),
              selected: value == key,
              onSelected: (_) => setState(() => onChanged(key)),
              selectedColor: VoyagoColors.primary.withValues(alpha: 0.25),
              backgroundColor: VoyagoColors.surface,
              labelStyle: TextStyle(
                color: value == key ? VoyagoColors.primaryLight : VoyagoColors.text,
                fontWeight: FontWeight.w700,
              ),
            ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final changes = <String, dynamic>{
      if (_pace != t.pace) 'pace': _pace,
      if (_budget != t.budget) 'budget': _budget,
      if (_days != t.durationDays) 'duration_days': _days,
    };
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _Grabber(),
            const Text('Tout refaire',
                style: TextStyle(color: VoyagoColors.text, fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 4),
            Text(
              'Nouveau programme complet avec des lieux réels vérifiés · utilise 1 modification '
              '(${widget.remaining} restante${widget.remaining > 1 ? 's' : ''}). Tes réservations sont gardées.',
              style: const TextStyle(color: VoyagoColors.muted, fontSize: 12.5, height: 1.35),
            ),
            const SizedBox(height: 16),
            const Text('RYTHME', style: TextStyle(color: VoyagoColors.muted, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            _chips(_paces, _pace, (v) => _pace = v),
            const SizedBox(height: 14),
            const Text('BUDGET', style: TextStyle(color: VoyagoColors.muted, fontSize: 11, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            _chips(_budgets, _budget, (v) => _budget = v),
            const SizedBox(height: 14),
            Row(
              children: [
                const Expanded(
                  child: Text('DURÉE',
                      style: TextStyle(color: VoyagoColors.muted, fontSize: 11, fontWeight: FontWeight.w800)),
                ),
                IconButton(
                  onPressed: _days > 1 ? () => setState(() => _days--) : null,
                  icon: const Icon(Icons.remove_circle_outline, color: VoyagoColors.primary),
                ),
                Text('$_days jour${_days > 1 ? 's' : ''}',
                    style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w800)),
                IconButton(
                  onPressed: _days < 30 ? () => setState(() => _days++) : null,
                  icon: const Icon(Icons.add_circle_outline, color: VoyagoColors.primary),
                ),
              ],
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(changes),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VoyagoColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: Text(changes.isEmpty ? 'Refaire avec les mêmes envies' : 'Refaire mon voyage',
                    style: const TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Quota atteint : passer Pro, pack 0,99 € ou échanger des Éclats (pépites)
// =============================================================================

/// [reason] : redo | swap | date | plan_b. Renvoie les compteurs à jour si des crédits ont été ajoutés.
Future<TripEditOptions?> showEditQuotaSheet(
  BuildContext context, {
  required String tripId,
  required TripEditOptions options,
  required String reason,
}) {
  return showModalBottomSheet<TripEditOptions>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VoyagoColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _QuotaSheet(tripId: tripId, options: options, reason: reason),
  );
}

class _QuotaSheet extends ConsumerStatefulWidget {
  final String tripId;
  final TripEditOptions options;
  final String reason;
  const _QuotaSheet({required this.tripId, required this.options, required this.reason});

  @override
  ConsumerState<_QuotaSheet> createState() => _QuotaSheetState();
}

class _QuotaSheetState extends ConsumerState<_QuotaSheet> {
  String? _busy; // shards | pack
  String? _message;
  Timer? _poll;

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  bool get _creditsApply => widget.reason == 'redo';

  (String, String) get _headline => switch (widget.reason) {
        'swap' => (
            'Tu as remplacé ${widget.options.swaps.limit ?? 2} lieux sur ce voyage',
            'Avec Pro, remplace autant de lieux que tu veux, toujours parmi des lieux réels vérifiés.',
          ),
        'date' => (
            'Tu as déjà décalé ce voyage une fois',
            'Avec Pro, décale tes dates sans limite tant que le voyage n’a pas commencé. Tu peux aussi l’annuler gratuitement.',
          ),
        'plan_b' => (
            'Le plan B pluie est un avantage Pro',
            'Quand la pluie est annoncée, ta journée bascule à l’abri (musées, marchés couverts, cafés) en un geste.',
          ),
        _ => widget.options.isPro
            ? (
                'Tu as utilisé tes modifications pour ce voyage',
                'Ajoute des crédits pour continuer, ou passe à une formule avec plus de modifications par voyage.',
              )
            : (
                'Refaire une journée, c’est avec Pro',
                'Ton essai offert est utilisé. Pro te donne 2 à 6 journées refaites par voyage, ou débloque-en à l’unité.',
              ),
      };

  Future<void> _spendShards() async {
    setState(() => _busy = 'shards');
    try {
      final r = await ref.read(tripsApiProvider).creditWithShards(widget.tripId);
      ref.invalidate(shardWalletProvider);
      if (mounted) Navigator.of(context).pop(r.options);
    } on ApiException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  Future<void> _buyPack() async {
    setState(() {
      _busy = 'pack';
      _message = null;
    });
    try {
      final res = await ApiService.instance.pro.createEditPackCheckout(widget.tripId);
      final uri = Uri.tryParse(res.checkoutUrl);
      if (uri == null || !await launchUrl(uri, mode: LaunchMode.externalApplication)) {
        if (mounted) setState(() => _message = 'Impossible d’ouvrir la page de paiement.');
        if (mounted) setState(() => _busy = null);
        return;
      }
      if (mounted) setState(() => _message = 'Finalise le paiement : tes crédits arrivent ici automatiquement.');
      var tries = 0;
      _poll = Timer.periodic(const Duration(seconds: 3), (timer) async {
        if (++tries > 60) {
          timer.cancel();
          if (mounted) {
            setState(() {
              _busy = null;
              _message = 'Paiement non confirmé pour l’instant. Les crédits s’ajouteront dès sa validation.';
            });
          }
          return;
        }
        try {
          final status = await ApiService.instance.getProStatus(res.sessionId);
          if (status['applied'] == true || status['payment_status'] == 'paid') {
            timer.cancel();
            final o = await ref.read(tripsApiProvider).getEditOptions(widget.tripId);
            if (mounted) Navigator.of(context).pop(o);
          } else if (status['status'] == 'expired') {
            timer.cancel();
            if (mounted) {
              setState(() {
                _busy = null;
                _message = 'Paiement annulé.';
              });
            }
          }
        } catch (_) {
          // On réessaie au prochain tour
        }
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _busy = null;
          _message = e.message;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = widget.options;
    final (title, body) = _headline;
    final shards = o.shardBalance ?? 0;
    final capReached = o.shardCreditsUsed >= o.shardCreditsLimit;
    final canShards = !capReached && shards >= o.shardsPerCredit;
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Grabber(),
            Text(title, style: const TextStyle(color: VoyagoColors.text, fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            Text(body, style: const TextStyle(color: VoyagoColors.muted, fontSize: 13, height: 1.4)),
            const SizedBox(height: 16),

            // Passer Pro (Annuel mis en avant)
            if (o.plan != 'lifetime')
              _OfferCard(
                highlight: true,
                badge: o.plan == 'free' ? '⭐ −33 % vs mensuel' : null,
                title: o.plan == 'free'
                    ? 'Pro Annuel · 39,99 €/an'
                    : o.plan == 'monthly'
                        ? 'Passer à l’Annuel · 4 journées par voyage'
                        : 'Passer À vie · 6 journées par voyage',
                subtitle: 'Mensuel 2 · Annuel 4 · À vie 6 journées refaites par voyage, '
                    'lieux et dates à volonté, plan B pluie',
                cta: 'Voir les formules',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/pricing');
                },
              ),

            if (_creditsApply) ...[
              _OfferCard(
                title: 'Pack ${o.packCredits} modifications · ${_euro(o.packPrice)}',
                subtitle: 'Paiement unique pour ce voyage',
                cta: 'Acheter',
                loading: _busy == 'pack',
                onTap: _busy == null ? _buyPack : null,
              ),
              _OfferCard(
                title: '1 modification contre ${o.shardsPerCredit} Éclats 💎',
                subtitle: capReached
                    ? 'Échange déjà utilisé sur ce voyage (${o.shardCreditsLimit} par voyage${o.isPro ? '' : ' en gratuit, 3 avec Pro'})'
                    : canShards
                        ? 'Tu as $shards Éclats · tes XP et ton niveau ne bougent pas'
                        : 'Tu as $shards Éclats · il t’en manque ${o.shardsPerCredit - shards} : '
                            'ramasse des pépites sur la carte pendant ton voyage',
                progress: capReached ? null : (shards / o.shardsPerCredit).clamp(0.0, 1.0),
                cta: canShards ? 'Échanger' : 'Pas encore assez',
                loading: _busy == 'shards',
                onTap: canShards && _busy == null ? _spendShards : null,
              ),
            ],
            if (_message != null) ...[
              const SizedBox(height: 8),
              Text(_message!,
                  textAlign: TextAlign.center, style: const TextStyle(color: VoyagoColors.orange, fontSize: 12.5)),
            ],
          ],
        ),
      ),
    );
  }
}

class _OfferCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String cta;
  final VoidCallback? onTap;
  final bool highlight;
  final bool loading;
  final String? badge;

  /// Progression vers l'offre (Éclats), de 0 à 1
  final double? progress;

  const _OfferCard({
    required this.title,
    required this.subtitle,
    required this.cta,
    this.onTap,
    this.highlight = false,
    this.loading = false,
    this.badge,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: highlight ? VoyagoColors.primary.withValues(alpha: 0.10) : VoyagoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: highlight ? VoyagoColors.primary : VoyagoColors.cardBorder, width: highlight ? 1.6 : 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (badge != null)
            Container(
              margin: const EdgeInsets.only(bottom: 6),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(color: VoyagoColors.yellow, borderRadius: BorderRadius.circular(6)),
              child: Text(badge!, style: const TextStyle(color: Colors.black, fontSize: 11, fontWeight: FontWeight.w900)),
            ),
          Text(title, style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w800, fontSize: 14.5)),
          const SizedBox(height: 3),
          Text(subtitle, style: const TextStyle(color: VoyagoColors.muted, fontSize: 12, height: 1.3)),
          if (progress != null) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: VoyagoColors.cardBorder,
                color: VoyagoColors.blue,
              ),
            ),
          ],
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: highlight ? VoyagoColors.primary : VoyagoColors.background,
                foregroundColor: highlight ? Colors.white : VoyagoColors.primary,
                side: highlight ? null : const BorderSide(color: VoyagoColors.primary),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              child: loading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(cta, style: const TextStyle(fontWeight: FontWeight.w800)),
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================

String _euro(double v) => '${v.toStringAsFixed(2).replaceAll('.', ',')} €';

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(color: VoyagoColors.cardBorder, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

class _Thumb extends StatelessWidget {
  final String? url;
  final double size;
  const _Thumb({this.url, this.size = 40});

  @override
  Widget build(BuildContext context) {
    final placeholder = Container(
      width: size,
      height: size,
      color: VoyagoColors.cardBorder,
      child: const Icon(Icons.place_rounded, color: VoyagoColors.muted, size: 20),
    );
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: url == null || url!.isEmpty
          ? placeholder
          : Image.network(url!, width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => placeholder),
    );
  }
}

// =============================================================================
// Plan B pluie (depuis la notification de la veille)
// =============================================================================

Future<void> showPlanBSheet(BuildContext context, {required String tripId, required int day}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VoyagoColors.background,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _PlanBSheet(tripId: tripId, day: day),
  );
}

class _PlanBSheet extends ConsumerStatefulWidget {
  final String tripId;
  final int day;
  const _PlanBSheet({required this.tripId, required this.day});

  @override
  ConsumerState<_PlanBSheet> createState() => _PlanBSheetState();
}

class _PlanBSheetState extends ConsumerState<_PlanBSheet> {
  TripEditOptions? _options;
  bool _working = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    ref.read(tripsApiProvider).getEditOptions(widget.tripId).then((o) {
      if (mounted) setState(() => _options = o);
    }).catchError((Object e) {
      if (mounted) setState(() => _error = e is ApiException ? e.message : 'Voyage introuvable.');
    });
  }

  Future<void> _apply() async {
    setState(() {
      _working = true;
      _error = null;
    });
    try {
      final r = await ref.read(tripsApiProvider).redoDay(widget.tripId, widget.day, planB: true);
      ref.invalidate(tripDetailProvider(widget.tripId));
      ref.invalidate(tripGemsProvider(widget.tripId));
      if (!mounted) return;
      final router = GoRouter.of(context);
      final messenger = ScaffoldMessenger.maybeOf(context);
      Navigator.of(context).pop();
      router.go('/itinerary/${widget.tripId}', extra: r.trip);
      messenger?.showSnackBar(SnackBar(
        backgroundColor: VoyagoColors.primary,
        content: Text('☔ Plan B prêt pour le jour ${widget.day} : bonne journée à l’abri !'),
      ));
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _working = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final o = _options;
    final applied = o?.planBDays.contains(widget.day) ?? false;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const _Grabber(),
            const Text('☔', textAlign: TextAlign.center, style: TextStyle(fontSize: 44)),
            const SizedBox(height: 6),
            Text('Pluie annoncée le jour ${widget.day}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: VoyagoColors.text, fontSize: 19, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text(
              'Ton plan B remplace les visites en plein air par des lieux réels à l’abri : '
              'musées, marchés couverts, cafés, galeries…',
              textAlign: TextAlign.center,
              style: TextStyle(color: VoyagoColors.muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 16),
            if (o == null && _error == null)
              const Center(child: CircularProgressIndicator(color: VoyagoColors.primary))
            else if (o != null && applied)
              const Text('Le plan B de cette journée est déjà appliqué ✓',
                  textAlign: TextAlign.center, style: TextStyle(color: VoyagoColors.primary, fontWeight: FontWeight.w800))
            else if (o != null && (o.isPro || o.planBGift))
              ElevatedButton(
                onPressed: _working ? null : _apply,
                style: ElevatedButton.styleFrom(
                  backgroundColor: VoyagoColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                child: _working
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : Text(
                        o.isPro ? 'Basculer ma journée à l’abri' : '🎁 Utiliser mon plan B offert',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
              )
            else if (o != null)
              _OfferCard(
                highlight: true,
                badge: '💎 Avantage Pro',
                title: 'Plan B pluie en un geste',
                subtitle: 'Inclus dans toutes les formules Pro, sans entamer tes modifications.',
                cta: 'Voir Pro',
                onTap: () {
                  Navigator.of(context).pop();
                  context.push('/pricing');
                },
              ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: VoyagoColors.coral)),
            ],
          ],
        ),
      ),
    );
  }
}
