import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show ImageFilter;
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import '../api/api_exceptions.dart';
import '../models/trip_bookings.dart';
import '../providers/trips_provider.dart';
import 'partner_webview_screen.dart';
import '../theme.dart';

/// Couleurs et libellés des postes du budget
class _Cat {
  final String key;
  final String label;
  final Color color;
  final String icon;
  const _Cat(this.key, this.label, this.color, this.icon);
}

const _lodging = _Cat('lodging', 'Hébergement', VoyagoColors.primary, 'assets/icons3d/bed.png');
const _transport = _Cat('transport', 'Transports', VoyagoColors.blue, 'assets/icons3d/bus.png');
const _activities = _Cat('activities', 'Activités', VoyagoColors.yellow, 'assets/icons3d/admission_tickets.png');
const _meals = _Cat('meals', 'Repas & extras', VoyagoColors.orange, 'assets/icons3d/fork_and_knife_with_plate.png');
const _flights = _Cat('flights', 'Vols', Color(0xFFB57BFF), 'assets/icons3d/airplane.png');
const _other = _Cat('other', 'Autre', VoyagoColors.muted, 'assets/icons3d/credit_card.png');
const _budgetCats = [_lodging, _transport, _activities, _meals];
const _allCats = [_lodging, _transport, _activities, _meals, _flights, _other];

_Cat _catOf(String key) => _allCats.firstWhere((c) => c.key == key, orElse: () => _other);

const _bookingBlue = Color(0xFF2F6FDB);
const _airbnbRed = Color(0xFFFF5A5F);

/// « Réservations & Budget » : où dormir, comment bouger, quoi réserver selon le budget du voyage,
/// avec des liens pré-remplis vers les partenaires et le suivi de ce qui est déjà payé.
class BookingsBudgetScreen extends ConsumerStatefulWidget {
  final String tripId;

  const BookingsBudgetScreen({super.key, required this.tripId});

  @override
  ConsumerState<BookingsBudgetScreen> createState() => _BookingsBudgetScreenState();
}

class _BookingsBudgetScreenState extends ConsumerState<BookingsBudgetScreen> {
  TripBookings? _data;
  String? _error;
  int _tab = 0;
  bool _busy = false;

  /// Partenaire fermé sans confirmer : « Tu as réservé ? » reste proposé
  _PendingBooking? _pending;

  /// Alerte prix du vol (suivie à part pour un retour instantané du bouton)
  PriceAlertState? _alert;
  bool _alertBusy = false;

  /// Estimations IA en cours côté serveur : on rafraîchit tout seul toutes les 4 s
  Timer? _poll;
  int _polls = 0;
  static const _maxPolls = 15;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load({bool retry = false, bool silent = false}) async {
    _poll?.cancel();
    if (!silent) setState(() => _error = null);
    try {
      final data = await ref.read(tripsApiProvider).getBookings(widget.tripId, retry: retry);
      if (!mounted) return;
      setState(() {
        _data = data;
        _alert = data.priceAlert ?? _alert;
      });
      if (data.estimatesStatus == 'pending' && _polls < _maxPolls) {
        _poll = Timer(const Duration(seconds: 4), () {
          _polls++;
          _load(silent: true);
        });
      } else {
        _polls = 0;
      }
    } on ApiException catch (e) {
      // Rafraîchissement silencieux : on garde l'écran affiché
      if (mounted && (!silent || _data == null)) setState(() => _error = e.message);
    } catch (_) {
      if (mounted && (!silent || _data == null)) setState(() => _error = 'Impossible de charger tes réservations pour le moment.');
    }
  }

  NumberFormat get _money => NumberFormat.simpleCurrency(locale: 'fr_FR', name: _data?.currency ?? 'EUR', decimalDigits: 0);
  String _fmt(num v) => _money.format(v);

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  /// Ouvre le partenaire dans Voyagooo (WebView) ; au retour, on propose d'ajouter la dépense.
  Future<void> _open(String url, {_PendingBooking? track, String title = 'Réservation'}) async {
    HapticFeedback.selectionClick();
    final booked = await openPartnerPage(context, url: url, title: title);
    if (!mounted || track == null) return;
    if (booked) {
      setState(() => _pending = null);
      await _askBooked(track);
    } else {
      setState(() => _pending = track);
    }
  }

  Future<void> _togglePriceAlert(bool enabled) async {
    if (_alertBusy) return;
    final previous = _alert;
    HapticFeedback.selectionClick();
    setState(() {
      _alertBusy = true;
      _alert = PriceAlertState(
        enabled: enabled,
        lastPrice: previous?.lastPrice,
        lowestPrice: previous?.lowestPrice,
        baselinePrice: previous?.baselinePrice,
      );
    });
    try {
      final state = await ref.read(tripsApiProvider).setPriceAlert(widget.tripId, enabled);
      if (!mounted) return;
      setState(() => _alert = state);
      _snack(enabled ? '🔔 Alerte activée : on te prévient dès que le vol baisse' : 'Alerte prix coupée');
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _alert = previous);
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _alertBusy = false);
    }
  }

  /// « Prix incorrect ? » : signalé une fois par visite et par session
  final Set<String> _reported = {};

  Future<void> _reportPrice(ActivityProposal a) async {
    if (_reported.contains(a.name)) {
      _snack('Déjà signalé, merci !');
      return;
    }
    HapticFeedback.selectionClick();
    _reported.add(a.name);
    try {
      await ref.read(tripsApiProvider).reportActivityPrice(widget.tripId, a.name);
      _snack('Merci ! On revérifie le prix de ${a.name} pour tous les voyageurs.');
    } on ApiException catch (e) {
      _reported.remove(a.name);
      _snack(e.message, error: true);
    }
  }

  void _openChoice(PartnerChoice c, {required String category, required String label, int? amount}) {
    _open(c.url,
        title: c.label,
        track: _PendingBooking(category: category, label: '$label · ${c.label}', amount: amount, url: c.url));
  }

  Future<void> _askBooked(_PendingBooking pending) async {
    final result = await showModalBottomSheet<_PendingBooking>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBookingSheet(initial: pending, currency: _data?.currency ?? 'EUR', fromPartner: true),
    );
    if (result != null) await _add(result);
  }

  Future<void> _addManually() async {
    final result = await showModalBottomSheet<_PendingBooking>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _AddBookingSheet(
        initial: _PendingBooking(category: const ['other', 'lodging', 'transport', 'activities', 'other'][_tab], label: ''),
        currency: _data?.currency ?? 'EUR',
      ),
    );
    if (result != null) await _add(result);
  }

  Future<void> _add(_PendingBooking b) async {
    setState(() => _busy = true);
    try {
      final data = await ref.read(tripsApiProvider).addBooking(
            widget.tripId,
            category: b.category,
            label: b.label,
            amount: b.amount ?? 0,
            url: b.url,
          );
      if (!mounted) return;
      HapticFeedback.mediumImpact();
      setState(() => _data = data);
      _snack('${b.label} ajouté à ton budget ✅');
    } on ApiException catch (e) {
      _snack(e.message, error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _remove(BookedItem item) async {
    final previous = _data;
    try {
      final data = await ref.read(tripsApiProvider).removeBooking(widget.tripId, item.id);
      if (mounted) setState(() => _data = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _data = previous);
      _snack(e.message, error: true);
    }
  }

  void _snack(String text, {bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: error ? VoyagoColors.coral : VoyagoColors.surface,
        content: Text(text, style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w600)),
      ));
  }

  // ---------------------------------------------------------------------------
  // Construction
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final data = _data;
    return Scaffold(
      backgroundColor: VoyagoColors.background,
      body: data == null
          ? (_error != null ? _ErrorView(message: _error!, onRetry: _load) : const _LoadingView())
          : RefreshIndicator(
              color: VoyagoColors.primary,
              onRefresh: _load,
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
                slivers: [
                  _Hero(data: data),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
                    sliver: SliverList.list(children: [
                      _BudgetCard(data: data, fmt: _fmt),
                      if (data.plan == null && data.estimatesStatus == 'pending') ...[
                        const SizedBox(height: 12),
                        const _PlanPending(),
                      ],
                      if (data.plan != null) ...[
                        const SizedBox(height: 12),
                        _PlanCard(
                          plan: data.plan!,
                          fmt: _fmt,
                          onSaving: (tab) {
                            HapticFeedback.selectionClick();
                            setState(() => _tab = tab);
                          },
                        ),
                      ],
                      if (!data.datesKnown) ...[
                        const SizedBox(height: 12),
                        const _InfoBanner(
                          icon: Icons.edit_calendar_rounded,
                          color: VoyagoColors.blue,
                          text: 'Ajoute tes dates depuis l’itinéraire : les liens s’ouvriront avec les bonnes nuits et des prix réels.',
                        ),
                      ],
                      const SizedBox(height: 18),
                      _Tabs(
                        index: _tab,
                        labels: ['Jour par jour', 'Hébergements', 'Transports', 'Activités', 'Réservé (${data.bookings.length})'],
                        onChanged: (i) {
                          HapticFeedback.selectionClick();
                          setState(() => _tab = i);
                        },
                      ),
                      const SizedBox(height: 14),
                    ]),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList.list(children: _tabContent(data)),
                  ),
                ],
              ),
            ),
      bottomNavigationBar: data == null
          ? null
          : Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                AnimatedSize(
                  duration: const Duration(milliseconds: 220),
                  child: _pending == null
                      ? const SizedBox(width: double.infinity)
                      : _PendingBanner(
                          label: _pending!.label,
                          onYes: () {
                            final p = _pending!;
                            setState(() => _pending = null);
                            _askBooked(p);
                          },
                          onDismiss: () => setState(() => _pending = null),
                        ),
                ),
                _StickyFooter(data: data, fmt: _fmt, busy: _busy, onAdd: _addManually),
              ],
            ),
    );
  }

  List<Widget> _tabContent(TripBookings data) {
    Widget fade(List<Widget> children) => AnimatedSwitcher(
          duration: const Duration(milliseconds: 220),
          child: Column(key: ValueKey(_tab), children: children),
        );

    switch (_tab) {
      case 0:
        return [
          fade([
            if (data.daily.isEmpty)
              const _EmptyTab(icon: 'assets/icons3d/calendar.png', text: 'Le programme jour par jour arrive dès que ton itinéraire est prêt.')
            else ...[
              if (data.estimatesStatus != 'ready' || !data.estimatesAvailable)
                _EstimatesNote(status: data.estimatesStatus, onRetry: () => _load(retry: true)),
              for (final d in data.daily) _DayCard(plan: d, fmt: _fmt),
            ],
            const _PriceDisclaimer(),
          ]),
        ];
      case 1:
        return [
          fade([
            if (data.estimatesStatus != 'ready' || !data.estimatesAvailable)
                _EstimatesNote(status: data.estimatesStatus, onRetry: () => _load(retry: true)),
            if (data.stays.isEmpty)
              const _EmptyTab(icon: 'assets/icons3d/hotel.png', text: 'Voyage d’une journée : pas de nuit à réserver.')
            else
              for (final stay in data.stays)
                _StayCard(
                  stay: stay,
                  multi: data.stays.length > 1,
                  fmt: _fmt,
                  onChoice: (c, area) => _openChoice(c, category: 'lodging', label: area),
                ),
            const _PriceDisclaimer(),
          ]),
        ];
      case 2:
        return [
          fade([
            for (final t in data.transport)
              if (t.kind == 'flight' && t.livePrices)
                _FlightCard(
                  option: t,
                  fmt: _fmt,
                  onOpen: (url, price) => _open(url,
                      title: 'Aviasales',
                      track: _PendingBooking(category: 'flights', label: 'Vols ${t.title}', amount: price, url: url)),
                  onBooked: () => _askBooked(_PendingBooking(category: 'flights', label: 'Vols ${t.title}', amount: t.price)),
                  alert: data.datesKnown ? (_alert ?? const PriceAlertState()) : null,
                  alertBusy: _alertBusy,
                  onToggleAlert: _togglePriceAlert,
                )
              else
              _TransportCard(
                option: t,
                fmt: _fmt,
                onChoice: (c) => _openChoice(
                  c,
                  category: t.kind == 'flight' ? 'flights' : (t.kind == 'esim' ? 'other' : 'transport'),
                  label: t.title,
                  amount: t.price,
                ),
                onOpen: t.link == null
                    ? null
                    : () => _open(t.link!,
                        title: t.title,
                        track: t.kind == 'intercity'
                            ? null
                            : _PendingBooking(
                                category: t.kind == 'flight' ? 'flights' : 'transport',
                                label: t.title,
                                url: t.link,
                              )),
                onBooked: () => _askBooked(_PendingBooking(
                  category: t.kind == 'flight' ? 'flights' : 'transport',
                  label: t.title,
                  amount: t.price,
                )),
              ),
            const _PriceDisclaimer(),
          ]),
        ];
      case 3:
        return [
          fade([
            if (data.activities.isEmpty)
              _EmptyTab(
                icon: 'assets/icons3d/admission_tickets.png',
                text: data.estimatesAvailable
                    ? 'Tes visites sont gratuites ou se paient sur place. Profite !'
                    : 'Estimations indisponibles pour le moment. Tire vers le bas pour réessayer.',
              )
            else ...[
              if (data.passCompare != null) _PassCard(pass: data.passCompare!, fmt: _fmt),
              for (final a in data.activities)
                _ActivityCard(
                  activity: a,
                  fmt: _fmt,
                  travelers: data.travelersCount,
                  onChoice: (c) => _openChoice(c, category: 'activities', label: a.name, amount: a.priceGroup),
                  onReportPrice: () => _reportPrice(a),
                ),
            ],
            const _PriceDisclaimer(),
          ]),
        ];
      default:
        return [
          fade([
            if (data.bookings.isEmpty)
              const _EmptyTab(
                icon: 'assets/icons3d/money_bag.png',
                text: 'Rien de réservé pour l’instant. Ouvre une proposition ou ajoute une dépense : ton budget se met à jour tout seul.',
              )
            else
              for (final b in data.bookings)
                _BookedTile(
                  item: b,
                  fmt: _fmt,
                  onDelete: () => _remove(b),
                  onOpen: b.url == null ? null : () => _open(b.url!, title: b.label),
                ),
          ]),
        ];
    }
  }
}

// =============================================================================
// En-tête
// =============================================================================

class _Hero extends StatelessWidget {
  final TripBookings data;

  const _Hero({required this.data});

  @override
  Widget build(BuildContext context) {
    final kids = data.childrenAges.length;
    final who = [
      '${data.adults} adulte${data.adults > 1 ? 's' : ''}',
      if (kids > 0) '$kids enfant${kids > 1 ? 's' : ''}',
    ].join(' · ');
    final level = switch (data.level) {
      'economique' => 'Économique',
      'luxe' => 'Luxe',
      _ => 'Confort',
    };

    return SliverAppBar(
      pinned: true,
      expandedHeight: 210,
      backgroundColor: VoyagoColors.background,
      surfaceTintColor: Colors.transparent,
      leading: Padding(
        padding: const EdgeInsets.all(8),
        child: _GlassIcon(icon: Icons.arrow_back_rounded, onTap: () => Navigator.of(context).maybePop()),
      ),
      title: const Text('Réservations & Budget', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (data.coverImageUrl != null)
              CachedNetworkImage(
                imageUrl: data.coverImageUrl!,
                fit: BoxFit.cover,
                memCacheWidth: 900,
                errorWidget: (_, __, ___) => const _HeroFallback(),
                placeholder: (_, __) => const _HeroFallback(),
              )
            else
              const _HeroFallback(),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x990F1117), Color(0x330F1117), VoyagoColors.background],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
            Positioned(
              left: 16,
              right: 16,
              bottom: 14,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    data.destination,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: VoyagoColors.text, fontSize: 28, fontWeight: FontWeight.w900, height: 1.1),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      _GlassChip(icon: Icons.groups_rounded, label: who),
                      _GlassChip(
                        icon: Icons.nights_stay_rounded,
                        label: '${data.days} jour${data.days > 1 ? 's' : ''} · ${data.nights} nuit${data.nights > 1 ? 's' : ''}',
                      ),
                      _GlassChip(icon: Icons.workspace_premium_rounded, label: level),
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

class _HeroFallback extends StatelessWidget {
  const _HeroFallback();

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1E3A12), Color(0xFF0F2A3A)],
        ),
      ),
      alignment: const Alignment(0.75, -0.1),
      child: Image.asset('assets/icons3d/world_map.png', width: 110, height: 110, opacity: const AlwaysStoppedAnimation(0.5)),
    );
  }
}

class _GlassChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _GlassChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.18)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: VoyagoColors.primaryLight),
              const SizedBox(width: 5),
              Text(label, style: const TextStyle(color: VoyagoColors.text, fontSize: 12, fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassIcon extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _GlassIcon({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.35),
      shape: const CircleBorder(),
      child: InkWell(customBorder: const CircleBorder(), onTap: onTap, child: Icon(icon, color: Colors.white, size: 20)),
    );
  }
}

// =============================================================================
// Budget
// =============================================================================

class _BudgetCard extends StatelessWidget {
  final TripBookings data;
  final String Function(num) fmt;

  const _BudgetCard({required this.data, required this.fmt});

  int _alloc(BudgetSplit s, String key) => switch (key) {
        'lodging' => s.lodging,
        'transport' => s.transport,
        'activities' => s.activities,
        _ => s.meals,
      };

  @override
  Widget build(BuildContext context) {
    final b = data.budget;
    final total = b.total <= 0 ? 1 : b.total;
    final over = b.available < 0;
    final ratio = (b.spent / total).clamp(0.0, 1.0);

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
              Image.asset('assets/icons3d/money_bag.png', width: 38, height: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.announcedBudget ? 'Ton budget' : 'Budget estimé',
                      style: const TextStyle(color: VoyagoColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                    Text(fmt(b.total),
                        style: const TextStyle(color: VoyagoColors.text, fontSize: 26, fontWeight: FontWeight.w900, height: 1.1)),
                  ],
                ),
              ),
              _RingProgress(value: ratio, over: over),
            ],
          ),
          const SizedBox(height: 16),
          // Barre répartie par poste ; la partie pleine = consommé
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: SizedBox(
              height: 14,
              child: Row(
                children: [
                  for (final c in _budgetCats)
                    if (_alloc(b.allocation, c.key) > 0)
                      Expanded(
                        flex: _alloc(b.allocation, c.key),
                        child: _SegmentFill(
                          color: c.color,
                          value: _alloc(b.allocation, c.key) == 0
                              ? 0
                              : (_alloc(b.spentBy, c.key) / _alloc(b.allocation, c.key)).clamp(0.0, 1.0),
                        ),
                      ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              _Stat(label: 'Consommé', value: fmt(b.spent), color: VoyagoColors.orange),
              _Stat(
                label: over ? 'Dépassement' : 'Disponible',
                value: fmt(b.available.abs()),
                color: over ? VoyagoColors.coral : VoyagoColors.primary,
              ),
              _Stat(label: 'Vols (hors budget)', value: fmt(b.flightsSpent), color: _flights.color),
            ],
          ),
          const SizedBox(height: 12),
          const Divider(color: VoyagoColors.cardBorder, height: 1),
          const SizedBox(height: 6),
          for (final c in _budgetCats)
            _CategoryRow(
              cat: c,
              allocated: _alloc(b.allocation, c.key),
              spent: _alloc(b.spentBy, c.key),
              need: c.key == 'transport' ? null : _alloc(b.estimatedNeeds, c.key),
              fmt: fmt,
            ),
          if (!data.announcedBudget)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Estimé d’après ton standing et la taille du groupe. Indique un montant à la création de ton prochain voyage pour un suivi au plus juste.',
                style: TextStyle(color: VoyagoColors.muted, fontSize: 11.5, height: 1.35),
              ),
            ),
        ],
      ),
    );
  }
}

class _SegmentFill extends StatelessWidget {
  final Color color;
  final double value;

  const _SegmentFill({required this.color, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 2),
      color: color.withValues(alpha: 0.22),
      alignment: Alignment.centerLeft,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: value),
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOutCubic,
        builder: (_, v, __) => FractionallySizedBox(widthFactor: v, heightFactor: 1, child: ColoredBox(color: color)),
      ),
    );
  }
}

class _RingProgress extends StatelessWidget {
  final double value;
  final bool over;

  const _RingProgress({required this.value, required this.over});

  @override
  Widget build(BuildContext context) {
    final color = over ? VoyagoColors.coral : (value > 0.85 ? VoyagoColors.orange : VoyagoColors.primary);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value),
      duration: const Duration(milliseconds: 800),
      curve: Curves.easeOutCubic,
      builder: (_, v, __) => SizedBox(
        width: 54,
        height: 54,
        child: Stack(
          alignment: Alignment.center,
          children: [
            CircularProgressIndicator(
              value: v,
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              backgroundColor: VoyagoColors.cardBorder,
              color: color,
            ),
            Text('${(v * 100).round()}%', style: TextStyle(color: color, fontSize: 12.5, fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _Stat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: VoyagoColors.muted, fontSize: 11)),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(value, style: TextStyle(color: color, fontSize: 16, fontWeight: FontWeight.w900)),
          ),
        ],
      ),
    );
  }
}

class _CategoryRow extends StatelessWidget {
  final _Cat cat;
  final int allocated;
  final int spent;
  final int? need;
  final String Function(num) fmt;

  const _CategoryRow({required this.cat, required this.allocated, required this.spent, this.need, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final tight = need != null && need! > allocated && need! > 0;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Container(width: 8, height: 8, decoration: BoxDecoration(color: cat.color, shape: BoxShape.circle)),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(cat.label, style: const TextStyle(color: VoyagoColors.text, fontSize: 13, fontWeight: FontWeight.w700)),
                if (need != null && need! > 0)
                  Text(
                    tight ? 'Prix estimés ~${fmt(need!)} : un peu serré' : 'Prix estimés ~${fmt(need!)}',
                    style: TextStyle(color: tight ? VoyagoColors.orange : VoyagoColors.muted, fontSize: 11),
                  ),
              ],
            ),
          ),
          Text(
            spent > 0 ? '${fmt(spent)} / ${fmt(allocated)}' : fmt(allocated),
            style: TextStyle(
              color: spent > allocated ? VoyagoColors.coral : VoyagoColors.text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Onglets
// =============================================================================

class _Tabs extends StatelessWidget {
  final int index;
  final List<String> labels;
  final ValueChanged<int> onChanged;

  const _Tabs({required this.index, required this.labels, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onTap: () => onChanged(i),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
                  decoration: BoxDecoration(
                    color: i == index ? VoyagoColors.primary : VoyagoColors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: i == index ? VoyagoColors.primaryDark : VoyagoColors.cardBorder),
                    boxShadow: i == index
                        ? const [BoxShadow(color: VoyagoColors.primaryDark, offset: Offset(0, 3))]
                        : null,
                  ),
                  child: Text(
                    labels[i],
                    style: TextStyle(
                      color: i == index ? Colors.white : VoyagoColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// =============================================================================
// Cartes
// =============================================================================

class _Card extends StatelessWidget {
  final Widget child;
  final Color? accent;

  const _Card({required this.child, this.accent});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: (accent ?? VoyagoColors.cardBorder).withValues(alpha: accent == null ? 1 : 0.4)),
      ),
      child: child,
    );
  }
}

class _StayCard extends StatelessWidget {
  final StayProposal stay;
  final bool multi;
  final String Function(num) fmt;
  final void Function(PartnerChoice choice, String area) onChoice;

  const _StayCard({
    required this.stay,
    required this.multi,
    required this.fmt,
    required this.onChoice,
  });

  /// Partenaires envoyés par le serveur, sinon les deux liens historiques
  List<PartnerChoice> get _stayChoices => stay.choices.isNotEmpty
      ? stay.choices
      : [
          if (stay.bookingUrl != null) PartnerChoice(partner: 'booking', label: 'Booking.com', url: stay.bookingUrl!),
          if (stay.airbnbUrl != null) PartnerChoice(partner: 'airbnb', label: 'Airbnb', url: stay.airbnbUrl!),
        ];

  String _dates() {
    if (stay.checkin == null || stay.checkout == null) {
      return stay.fromDay == stay.toDay ? 'Jour ${stay.fromDay}' : 'Jours ${stay.fromDay} → ${stay.toDay}';
    }
    final f = DateFormat('d MMM', 'fr_FR');
    return '${f.format(DateTime.parse(stay.checkin!))} → ${f.format(DateTime.parse(stay.checkout!))}';
  }

  @override
  Widget build(BuildContext context) {
    final hasEstimate = stay.nightlyMin != null;
    final fits = stay.fitsBudget;
    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/icons3d/hotel.png', width: 40, height: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [if (multi) 'Étape ${stay.index}', _dates(), '${stay.nights} nuit${stay.nights > 1 ? 's' : ''}'].join(' · '),
                      style: const TextStyle(color: VoyagoColors.muted, fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    Text(stay.area,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: VoyagoColors.text, fontSize: 17, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          if (stay.why != null) ...[
            const SizedBox(height: 8),
            Text(stay.why!, style: const TextStyle(color: VoyagoColors.text, fontSize: 13, height: 1.35)),
          ],
          if (stay.near.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final n in stay.near)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(color: VoyagoColors.background, borderRadius: BorderRadius.circular(8)),
                    child: Text('📍 $n', style: const TextStyle(color: VoyagoColors.muted, fontSize: 11)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (fits ? VoyagoColors.primary : VoyagoColors.orange).withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Prix constaté / nuit', style: TextStyle(color: VoyagoColors.muted, fontSize: 11)),
                      Text(
                        hasEstimate ? '${fmt(stay.nightlyMin!)} – ${fmt(stay.nightlyMax ?? stay.nightlyMin!)}' : '—',
                        style: const TextStyle(color: VoyagoColors.text, fontSize: 15, fontWeight: FontWeight.w900),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    const Text('Ton plafond / nuit', style: TextStyle(color: VoyagoColors.muted, fontSize: 11)),
                    Text(
                      stay.nightlyBudget > 0 ? fmt(stay.nightlyBudget) : '—',
                      style: TextStyle(
                        color: fits ? VoyagoColors.primary : VoyagoColors.orange,
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (hasEstimate && !fits)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text(
                'Les liens sont filtrés sous ton plafond : vise une chambre simple ou un quartier voisin.',
                style: TextStyle(color: VoyagoColors.orange, fontSize: 11.5),
              ),
            ),
          if (stay.tip != null) ...[
            const SizedBox(height: 8),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('💡 ', style: TextStyle(fontSize: 13)),
                Expanded(
                  child: Text(stay.tip!, style: const TextStyle(color: VoyagoColors.muted, fontSize: 12, height: 1.35)),
                ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          _PartnerChoices(choices: _stayChoices, onTap: (c) => onChoice(c, stay.area)),
          if (stay.options.isNotEmpty) ...[
            const SizedBox(height: 14),
            Text(
              fits ? 'Autres façons de dormir' : 'Pour rester dans ton budget',
              style: TextStyle(
                color: fits ? VoyagoColors.text : VoyagoColors.primary,
                fontSize: 13.5,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            for (final o in stay.options)
              _StayOptionTile(option: o, fmt: fmt, onTap: (c) => onChoice(c, '${o.kind} · ${o.area}')),
          ],
        ],
      ),
    );
  }
}

class _PartnerButton extends StatelessWidget {
  final String label;
  final Color color;
  final VoidCallback? onTap;
  const _PartnerButton({required this.label, required this.color, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13.5, fontWeight: FontWeight.w800)),
              ),
              const SizedBox(width: 6),
              const Icon(Icons.open_in_new_rounded, size: 15, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}

class _TransportCard extends StatelessWidget {
  final TransportOption option;
  final String Function(num) fmt;
  final VoidCallback? onOpen;
  final VoidCallback onBooked;
  final ValueChanged<PartnerChoice> onChoice;

  const _TransportCard({required this.option, required this.fmt, this.onOpen, required this.onBooked, required this.onChoice});

  @override
  Widget build(BuildContext context) {
    final (icon, cta) = switch (option.kind) {
      'flight' => ('assets/icons3d/airplane.png', 'Comparer les vols'),
      'intercity' => ('assets/icons3d/bus.png', 'Voir les trajets'),
      'pass' => ('assets/icons3d/credit_card.png', ''),
      'car' => ('assets/icons3d/automobile.png', 'Trouver une agence'),
      'transfer' => ('assets/icons3d/taxi.png', ''),
      'esim' => ('assets/icons3d/phone.png', ''),
      _ => ('assets/icons3d/world_map.png', 'Voir sur la carte'),
    };
    return _Card(
      accent: option.kind == 'flight' ? _flights.color : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(icon, width: 38, height: 38),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: VoyagoColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(option.subtitle, style: const TextStyle(color: VoyagoColors.muted, fontSize: 12, height: 1.3)),
                  ],
                ),
              ),
              if (option.price != null) ...[
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('~${fmt(option.price!)}',
                        style: const TextStyle(color: VoyagoColors.blue, fontSize: 15, fontWeight: FontWeight.w900)),
                    if (option.priceLabel != null)
                      Text(option.priceLabel!, style: const TextStyle(color: VoyagoColors.muted, fontSize: 10.5)),
                  ],
                ),
              ],
            ],
          ),
          if (option.outsideBudget)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text('Les vols sont suivis à part : ils ne réduisent pas ton budget sur place.',
                  style: TextStyle(color: VoyagoColors.muted, fontSize: 11.5)),
            ),
          const SizedBox(height: 12),
          if (option.choices.isNotEmpty && option.kind != 'flight') ...[
            _PartnerChoices(choices: option.choices, onTap: onChoice, showNotes: true),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              if (onOpen != null && cta.isNotEmpty && (option.choices.isEmpty || option.kind == 'flight'))
                Expanded(child: _PartnerButton(label: cta, color: VoyagoColors.blue, onTap: onOpen)),
              if (onOpen != null && cta.isNotEmpty && (option.choices.isEmpty || option.kind == 'flight') && option.kind != 'intercity')
                const SizedBox(width: 8),
              if (option.kind != 'intercity')
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: onBooked,
                    icon: const Icon(Icons.check_circle_rounded, size: 16),
                    label: const Text("C'est réservé"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: VoyagoColors.primary,
                      side: const BorderSide(color: VoyagoColors.primary),
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final ActivityProposal activity;
  final String Function(num) fmt;
  final int travelers;
  final ValueChanged<PartnerChoice> onChoice;
  final VoidCallback onReportPrice;

  const _ActivityCard({
    required this.activity,
    required this.fmt,
    required this.travelers,
    required this.onChoice,
    required this.onReportPrice,
  });

  /// « relevé en mars 2026 », « confirmé par des voyageurs », « tarif de haute saison »…
  String? get _priceMeta {
    final parts = <String>[
      if (activity.priceSource == 'voyageurs')
        'prix confirmé par des voyageurs'
      else if (activity.pricedAt != null)
        'relevé en ${DateFormat('MMMM yyyy', 'fr_FR').format(activity.pricedAt!.toLocal())}',
      if (activity.seasonal) 'tarif selon la saison',
    ];
    return parts.isEmpty ? null : parts.join(' · ');
  }

  List<PartnerChoice> get _choices => activity.choices.isNotEmpty
      ? activity.choices
      : [if (activity.link != null) PartnerChoice(partner: 'getyourguide', label: 'GetYourGuide', url: activity.link!)];

  @override
  Widget build(BuildContext context) {
    return _Card(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: SizedBox(
              width: 72,
              height: 72,
              child: activity.imageUrl != null
                  ? CachedNetworkImage(
                      imageUrl: activity.imageUrl!,
                      fit: BoxFit.cover,
                      memCacheWidth: 220,
                      errorWidget: (_, __, ___) => const _ActivityPlaceholder(),
                      placeholder: (_, __) => const _ActivityPlaceholder(),
                    )
                  : const _ActivityPlaceholder(),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (activity.day != null)
                  Text('Jour ${activity.day}',
                      style: const TextStyle(color: VoyagoColors.yellow, fontSize: 11, fontWeight: FontWeight.w800)),
                Text(activity.name,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: VoyagoColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 2),
                Text(
                  [
                    '${fmt(activity.priceAdult)}/adulte',
                    if (activity.priceChild != null) '${fmt(activity.priceChild!)}/enfant',
                  ].join(' · '),
                  style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
                ),
                if (activity.advice != null) ...[
                  const SizedBox(height: 4),
                  Text(activity.advice!, style: const TextStyle(color: VoyagoColors.muted, fontSize: 12, height: 1.3)),
                ],
                const SizedBox(height: 8),
                Text(
                  travelers > 1 ? '~${fmt(activity.priceGroup)} pour vous $travelers' : '~${fmt(activity.priceGroup)}',
                  style: const TextStyle(color: VoyagoColors.yellow, fontSize: 14, fontWeight: FontWeight.w900),
                ),
                Row(
                  children: [
                    if (_priceMeta != null)
                      Flexible(
                        child: Text(_priceMeta!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: VoyagoColors.muted, fontSize: 10.5)),
                      ),
                    if (_priceMeta != null) const Text(' · ', style: TextStyle(color: VoyagoColors.muted, fontSize: 10.5)),
                    GestureDetector(
                      onTap: onReportPrice,
                      child: const Text('Prix incorrect ?',
                          style: TextStyle(
                            color: VoyagoColors.muted,
                            fontSize: 10.5,
                            decoration: TextDecoration.underline,
                            decorationColor: VoyagoColors.muted,
                          )),
                    ),
                  ],
                ),
                if (_choices.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  _PartnerChoices(choices: _choices, onTap: onChoice, compact: true, primaryLabel: 'Billets'),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ActivityPlaceholder extends StatelessWidget {
  const _ActivityPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VoyagoColors.yellow.withValues(alpha: 0.1),
      alignment: Alignment.center,
      child: Image.asset('assets/icons3d/admission_tickets.png', width: 40, height: 40),
    );
  }
}

class _BookedTile extends StatelessWidget {
  final BookedItem item;
  final String Function(num) fmt;
  final VoidCallback onDelete;
  final VoidCallback? onOpen;

  const _BookedTile({required this.item, required this.fmt, required this.onDelete, this.onOpen});

  @override
  Widget build(BuildContext context) {
    final cat = _catOf(item.category);
    return Dismissible(
      key: ValueKey(item.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDelete(),
      background: Container(
        margin: const EdgeInsets.only(bottom: 10),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 20),
        decoration: BoxDecoration(color: VoyagoColors.coral, borderRadius: BorderRadius.circular(18)),
        child: const Icon(Icons.delete_rounded, color: Colors.white),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        decoration: BoxDecoration(
          color: VoyagoColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: VoyagoColors.cardBorder),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: ListTile(
            onTap: onOpen,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            leading: Container(
              width: 42,
              height: 42,
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
              child: Image.asset(cat.icon),
            ),
            title: Text(item.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: VoyagoColors.text, fontSize: 14, fontWeight: FontWeight.w700)),
            subtitle: Text(cat.label, style: TextStyle(color: cat.color, fontSize: 12, fontWeight: FontWeight.w600)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(fmt(item.amount),
                    style: const TextStyle(color: VoyagoColors.text, fontSize: 15, fontWeight: FontWeight.w900)),
                IconButton(
                  tooltip: 'Retirer',
                  visualDensity: VisualDensity.compact,
                  onPressed: onDelete,
                  icon: const Icon(Icons.close_rounded, size: 18, color: VoyagoColors.muted),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Pied de page collant
// =============================================================================

class _StickyFooter extends StatelessWidget {
  final TripBookings data;
  final String Function(num) fmt;
  final bool busy;
  final VoidCallback onAdd;

  const _StickyFooter({required this.data, required this.fmt, required this.busy, required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final over = data.budget.available < 0;
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          decoration: BoxDecoration(
            color: VoyagoColors.surface.withValues(alpha: 0.92),
            border: const Border(top: BorderSide(color: VoyagoColors.cardBorder)),
          ),
          child: SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Réservé ${fmt(data.budget.spent)}',
                            style: const TextStyle(color: VoyagoColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            over ? 'Dépassé de ${fmt(-data.budget.available)}' : 'Reste ${fmt(data.budget.available)}',
                            style: TextStyle(
                              color: over ? VoyagoColors.coral : VoyagoColors.primary,
                              fontSize: 19,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  ElevatedButton.icon(
                    onPressed: busy ? null : onAdd,
                    icon: busy
                        ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.add_rounded, size: 20),
                    label: const Text('Dépense'),
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                      textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// Ajout d'une prestation réservée
// =============================================================================

class _PendingBooking {
  final String category;
  final String label;
  final int? amount;
  final String? url;

  const _PendingBooking({required this.category, required this.label, this.amount, this.url});
}

class _AddBookingSheet extends StatefulWidget {
  final _PendingBooking initial;
  final String currency;
  final bool fromPartner;

  const _AddBookingSheet({required this.initial, required this.currency, this.fromPartner = false});

  @override
  State<_AddBookingSheet> createState() => _AddBookingSheetState();
}

class _AddBookingSheetState extends State<_AddBookingSheet> {
  late String _category = widget.initial.category;
  late final _label = TextEditingController(text: widget.initial.label);
  late final _amount = TextEditingController(text: widget.initial.amount?.toString() ?? '');

  @override
  void dispose() {
    _label.dispose();
    _amount.dispose();
    super.dispose();
  }

  bool get _valid => _label.text.trim().isNotEmpty && int.tryParse(_amount.text.trim()) != null;

  void _submit() {
    if (!_valid) return;
    Navigator.of(context).pop(_PendingBooking(
      category: _category,
      label: _label.text.trim(),
      amount: int.parse(_amount.text.trim()),
      url: widget.initial.url,
    ));
  }

  InputDecoration _deco(String hint, {String? suffix}) => InputDecoration(
        hintText: hint,
        suffixText: suffix,
        filled: true,
        fillColor: VoyagoColors.background,
        hintStyle: const TextStyle(color: VoyagoColors.muted),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        decoration: const BoxDecoration(
          color: VoyagoColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(color: VoyagoColors.cardBorder, borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Image.asset('assets/icons3d/money_bag.png', width: 40, height: 40),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      widget.fromPartner ? 'Tu as réservé ?' : 'Ajouter une dépense',
                      style: const TextStyle(color: VoyagoColors.text, fontSize: 20, fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
              if (widget.fromPartner)
                const Padding(
                  padding: EdgeInsets.only(top: 6),
                  child: Text('Indique le montant payé : ton budget se met à jour.',
                      style: TextStyle(color: VoyagoColors.muted, fontSize: 13)),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in _allCats)
                    ChoiceChip(
                      label: Text(c.label),
                      selected: _category == c.key,
                      onSelected: (_) => setState(() => _category = c.key),
                      avatar: Image.asset(c.icon, width: 18, height: 18),
                      showCheckmark: false,
                      selectedColor: c.color.withValues(alpha: 0.22),
                      backgroundColor: VoyagoColors.background,
                      side: BorderSide(color: _category == c.key ? c.color : VoyagoColors.cardBorder),
                      labelStyle: TextStyle(
                        color: _category == c.key ? VoyagoColors.text : VoyagoColors.muted,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _label,
                maxLength: 100,
                textCapitalization: TextCapitalization.sentences,
                style: const TextStyle(color: VoyagoColors.text),
                decoration: _deco('Ex. Hôtel du Port, 3 nuits').copyWith(counterText: ''),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _amount,
                autofocus: widget.fromPartner,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(7)],
                style: const TextStyle(color: VoyagoColors.text, fontSize: 18, fontWeight: FontWeight.w800),
                decoration: _deco('Montant', suffix: widget.currency),
                onChanged: (_) => setState(() {}),
                onSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (widget.fromPartner)
                    Expanded(
                      child: TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Pas encore', style: TextStyle(color: VoyagoColors.muted, fontWeight: FontWeight.w700)),
                      ),
                    ),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(onPressed: _valid ? _submit : null, child: const Text('Enregistrer')),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// États
// =============================================================================

/// Chargement : les icônes 3D du voyage tournent autour du budget, et les étapes de la
/// comparaison se cochent une à une (purement visuel : l'écran s'affiche dès que les données arrivent).
class _LoadingView extends StatefulWidget {
  const _LoadingView();

  @override
  State<_LoadingView> createState() => _LoadingViewState();
}

class _LoadingViewState extends State<_LoadingView> with TickerProviderStateMixin {
  static const _orbit = [
    'assets/icons3d/airplane.png',
    'assets/icons3d/hotel.png',
    'assets/icons3d/bus.png',
    'assets/icons3d/admission_tickets.png',
    'assets/icons3d/automobile.png',
    'assets/icons3d/fork_and_knife_with_plate.png',
  ];

  static const _steps = [
    ('assets/icons3d/airplane.png', 'Vols aux vrais prix'),
    ('assets/icons3d/hotel.png', 'Hébergements dans ton budget'),
    ('assets/icons3d/bus.png', 'Transferts et transports'),
    ('assets/icons3d/admission_tickets.png', 'Billets et pass'),
    ('assets/icons3d/money_bag.png', 'Ton meilleur plan'),
  ];

  late final AnimationController _spin = AnimationController(vsync: this, duration: const Duration(seconds: 9))..repeat();
  late final AnimationController _pulse =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400))..repeat(reverse: true);
  Timer? _ticker;
  int _step = 0;

  @override
  void initState() {
    super.initState();
    // Une étape toutes les 1,6 s ; la dernière reste « en cours » jusqu'à l'arrivée des données
    _ticker = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (!mounted || _step >= _steps.length - 1) return;
      setState(() => _step++);
    });
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _spin.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: VoyagoColors.text),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const Spacer(),
          SizedBox(
            width: 240,
            height: 240,
            child: AnimatedBuilder(
              animation: Listenable.merge([_spin, _pulse]),
              builder: (_, __) {
                final pulse = Curves.easeInOut.transform(_pulse.value);
                return Stack(
                  alignment: Alignment.center,
                  children: [
                    // Orbite en perspective et halo
                    Container(
                      width: 200,
                      height: 84,
                      decoration: ShapeDecoration(
                        shape: OvalBorder(side: BorderSide(color: VoyagoColors.primary.withValues(alpha: 0.22), width: 1.5)),
                      ),
                    ),
                    Container(
                      width: 110 + 12 * pulse,
                      height: 110 + 12 * pulse,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          VoyagoColors.primary.withValues(alpha: 0.28),
                          VoyagoColors.primary.withValues(alpha: 0.0),
                        ]),
                      ),
                    ),
                    // Icônes derrière le sac, le sac, puis celles qui passent devant
                    for (var i = 0; i < _orbit.length; i++)
                      if (!_inFront(i)) _orbitIcon(i, pulse),
                    Transform.scale(
                      scale: 0.94 + 0.08 * pulse,
                      child: Image.asset('assets/icons3d/money_bag.png', width: 84, height: 84),
                    ),
                    for (var i = 0; i < _orbit.length; i++)
                      if (_inFront(i)) _orbitIcon(i, pulse),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 18),
          const Text('On compare les prix pour ton budget…',
              textAlign: TextAlign.center,
              style: TextStyle(color: VoyagoColors.text, fontSize: 17, fontWeight: FontWeight.w900)),
          const SizedBox(height: 18),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 48),
            child: Column(
              children: [
                for (var i = 0; i < _steps.length; i++)
                  _LoadingStep(
                    icon: _steps[i].$1,
                    label: _steps[i].$2,
                    state: i < _step ? 2 : (i == _step ? 1 : 0),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: 180,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: (_step + 1) / _steps.length * 0.92),
                duration: const Duration(milliseconds: 600),
                curve: Curves.easeOutCubic,
                builder: (_, v, __) => LinearProgressIndicator(
                  value: v,
                  minHeight: 5,
                  color: VoyagoColors.primary,
                  backgroundColor: VoyagoColors.cardBorder,
                ),
              ),
            ),
          ),
          const Spacer(flex: 2),
        ],
      ),
    );
  }

  double _angle(int i) => 2 * math.pi * (_spin.value + i / _orbit.length);

  bool _inFront(int i) => math.sin(_angle(i)) > 0;

  /// Une icône sur l'orbite, qui flotte légèrement à son propre rythme
  Widget _orbitIcon(int i, double pulse) {
    const radius = 100.0;
    final angle = _angle(i);
    final bob = math.sin(2 * math.pi * _spin.value * 3 + i) * 4;
    final depth = (math.sin(angle) + 1) / 2; // 0 derrière, 1 devant
    return Transform.translate(
      offset: Offset(math.cos(angle) * radius, math.sin(angle) * radius * 0.42 + bob),
      child: Opacity(
        opacity: 0.55 + 0.45 * depth,
        child: Transform.scale(
          scale: 0.75 + 0.35 * depth,
          child: Container(
            width: 48,
            height: 48,
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: VoyagoColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: VoyagoColors.cardBorder),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 10, offset: const Offset(0, 4))],
            ),
            child: Image.asset(_orbit[i]),
          ),
        ),
      ),
    );
  }
}

/// Une étape de la comparaison : à venir (0), en cours (1), faite (2)
class _LoadingStep extends StatelessWidget {
  final String icon;
  final String label;
  final int state;

  const _LoadingStep({required this.icon, required this.label, required this.state});

  @override
  Widget build(BuildContext context) {
    final done = state == 2;
    final active = state == 1;
    return AnimatedOpacity(
      duration: const Duration(milliseconds: 300),
      opacity: state == 0 ? 0.4 : 1,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 5),
        child: Row(
          children: [
            Image.asset(icon, width: 22, height: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  color: active || done ? VoyagoColors.text : VoyagoColors.muted,
                  fontSize: 13.5,
                  fontWeight: active ? FontWeight.w800 : FontWeight.w600,
                ),
              ),
            ),
            SizedBox(
              width: 20,
              height: 20,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                transitionBuilder: (child, anim) => ScaleTransition(scale: anim, child: child),
                child: done
                    ? const Icon(Icons.check_circle_rounded, key: ValueKey('done'), color: VoyagoColors.primary, size: 20)
                    : active
                        ? const CircularProgressIndicator(key: ValueKey('active'), strokeWidth: 2.2, color: VoyagoColors.primary)
                        : const Icon(Icons.circle_outlined, key: ValueKey('todo'), color: VoyagoColors.cardBorder, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              icon: const Icon(Icons.arrow_back_rounded, color: VoyagoColors.text),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
          const Spacer(),
          const Icon(Icons.cloud_off_rounded, size: 56, color: VoyagoColors.muted),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(message, textAlign: TextAlign.center, style: const TextStyle(color: VoyagoColors.text, fontSize: 15)),
          ),
          const SizedBox(height: 16),
          ElevatedButton(onPressed: onRetry, child: const Text('Réessayer')),
          const Spacer(flex: 2),
        ],
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _InfoBanner({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(color: VoyagoColors.text, fontSize: 12.5, height: 1.35))),
        ],
      ),
    );
  }
}

/// État des estimations IA : en cours (animé) ou indisponibles (avec « Réessayer »)
class _EstimatesNote extends StatelessWidget {
  final String status;
  final VoidCallback onRetry;

  const _EstimatesNote({required this.status, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    if (status == 'pending') {
      return const Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: _PendingShimmer(
          child: Row(
            children: [
              SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: VoyagoColors.primary)),
              SizedBox(width: 10),
              Expanded(
                child: Text(
                  '✨ On estime les prix des hébergements et des visites… Ça s’affiche tout seul dans quelques secondes.',
                  style: TextStyle(color: VoyagoColors.text, fontSize: 12.5, height: 1.35),
                ),
              ),
            ],
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 6, 8),
        decoration: BoxDecoration(
          color: VoyagoColors.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VoyagoColors.orange.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Icon(Icons.info_outline_rounded, color: VoyagoColors.orange, size: 20),
            const SizedBox(width: 10),
            const Expanded(
              child: Text(
                'Estimations indisponibles pour le moment : les liens restent filtrés selon ton budget.',
                style: TextStyle(color: VoyagoColors.text, fontSize: 12.5, height: 1.35),
              ),
            ),
            TextButton(
              onPressed: onRetry,
              child: const Text('Réessayer', style: TextStyle(color: VoyagoColors.orange, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

/// Bandeau qui « respire » pendant un calcul en cours
class _PendingShimmer extends StatefulWidget {
  final Widget child;

  const _PendingShimmer({required this.child});

  @override
  State<_PendingShimmer> createState() => _PendingShimmerState();
}

class _PendingShimmerState extends State<_PendingShimmer> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VoyagoColors.primary.withValues(alpha: 0.35)),
          gradient: LinearGradient(
            begin: Alignment(-1.5 + 3 * _c.value, 0),
            end: Alignment(-0.5 + 3 * _c.value, 0),
            colors: [
              VoyagoColors.primary.withValues(alpha: 0.06),
              VoyagoColors.primary.withValues(alpha: 0.18),
              VoyagoColors.primary.withValues(alpha: 0.06),
            ],
          ),
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

/// Place du « meilleur plan » pendant que les estimations arrivent
class _PlanPending extends StatelessWidget {
  const _PlanPending();

  @override
  Widget build(BuildContext context) {
    return const _PendingShimmer(
      child: Row(
        children: [
          Text('🧭', style: TextStyle(fontSize: 24)),
          SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Ton meilleur plan se prépare…',
                    style: TextStyle(color: VoyagoColors.text, fontSize: 15, fontWeight: FontWeight.w900)),
                SizedBox(height: 2),
                Text('Vols, hébergements et pass comparés selon ton budget',
                    style: TextStyle(color: VoyagoColors.muted, fontSize: 12)),
              ],
            ),
          ),
          SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: VoyagoColors.primary)),
        ],
      ),
    );
  }
}

class _PriceDisclaimer extends StatelessWidget {
  const _PriceDisclaimer();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.only(top: 4, bottom: 8),
      child: Text(
        'Prix indicatifs estimés pour tes dates, à confirmer chez le partenaire.',
        textAlign: TextAlign.center,
        style: TextStyle(color: VoyagoColors.muted, fontSize: 11),
      ),
    );
  }
}

class _EmptyTab extends StatelessWidget {
  final String icon;
  final String text;

  const _EmptyTab({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      child: Column(
        children: [
          Image.asset(icon, width: 72, height: 72),
          const SizedBox(height: 12),
          Text(text, textAlign: TextAlign.center, style: const TextStyle(color: VoyagoColors.muted, fontSize: 13.5, height: 1.4)),
        ],
      ),
    );
  }
}

// =============================================================================
// Jour par jour
// =============================================================================

class _DayCard extends StatelessWidget {
  final DayPlan plan;
  final String Function(num) fmt;

  const _DayCard({required this.plan, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final date = plan.date == null ? null : DateTime.tryParse(plan.date!);
    final over = plan.budget > 0 && plan.total > plan.budget;
    final ratio = plan.budget <= 0 ? 0.0 : (plan.total / plan.budget).clamp(0.0, 1.0);
    final color = over ? VoyagoColors.orange : VoyagoColors.primary;
    final dateLabel = date == null ? null : DateFormat('EEEE d MMM', 'fr_FR').format(date);

    return _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: VoyagoColors.primary.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('JOUR', style: TextStyle(color: VoyagoColors.primary, fontSize: 8.5, fontWeight: FontWeight.w900)),
                    Text('${plan.day}',
                        style: const TextStyle(color: VoyagoColors.primary, fontSize: 18, fontWeight: FontWeight.w900, height: 1)),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      dateLabel == null ? 'Jour ${plan.day}' : '${dateLabel[0].toUpperCase()}${dateLabel.substring(1)}',
                      style: const TextStyle(color: VoyagoColors.text, fontSize: 15, fontWeight: FontWeight.w800),
                    ),
                    Text(
                      plan.sleeps ? 'Nuit · ${plan.area ?? 'sur place'}' : 'Jour du retour',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (plan.weatherIcon != null)
                Text(
                  '${plan.weatherIcon}${plan.tempMax != null ? ' ${plan.tempMax}°' : ''}',
                  style: const TextStyle(color: VoyagoColors.text, fontSize: 14, fontWeight: FontWeight.w700),
                ),
            ],
          ),
          if (plan.places.isNotEmpty) ...[
            const SizedBox(height: 10),
            for (final p in plan.places)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 3),
                child: Row(
                  children: [
                    const Icon(Icons.place_rounded, size: 14, color: VoyagoColors.muted),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(p.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: VoyagoColors.text, fontSize: 13)),
                    ),
                    Text(
                      p.price > 0 ? fmt(p.price) : 'Gratuit',
                      style: TextStyle(
                        color: p.price > 0 ? VoyagoColors.yellow : VoyagoColors.primary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              if (plan.lodging > 0) _CostPill(cat: _lodging, value: fmt(plan.lodging)),
              if (plan.activities > 0) _CostPill(cat: _activities, value: fmt(plan.activities)),
              if (plan.meals > 0) _CostPill(cat: _meals, value: fmt(plan.meals)),
              if (plan.transport > 0) _CostPill(cat: _transport, value: fmt(plan.transport)),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 6,
                    backgroundColor: VoyagoColors.cardBorder,
                    color: color,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '~${fmt(plan.total)}',
                style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w900),
              ),
              if (plan.budget > 0)
                Text(' / ${fmt(plan.budget)}', style: const TextStyle(color: VoyagoColors.muted, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }
}

class _CostPill extends StatelessWidget {
  final _Cat cat;
  final String value;

  const _CostPill({required this.cat, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(4, 3, 8, 3),
      decoration: BoxDecoration(color: cat.color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset(cat.icon, width: 16, height: 16),
          const SizedBox(width: 4),
          Text(value, style: TextStyle(color: cat.color, fontSize: 11.5, fontWeight: FontWeight.w800)),
        ],
      ),
    );
  }
}

// =============================================================================
// Vols : vrais prix
// =============================================================================

class _FlightCard extends StatelessWidget {
  final TransportOption option;
  final String Function(num) fmt;
  final void Function(String url, int? price) onOpen;
  final VoidCallback onBooked;
  final PriceAlertState? alert;
  final bool alertBusy;
  final ValueChanged<bool> onToggleAlert;

  const _FlightCard({required this.option, required this.fmt, required this.onOpen, required this.onBooked, this.alert, this.alertBusy = false, required this.onToggleAlert});

  static String _day(String? iso) {
    final d = iso == null ? null : DateTime.tryParse(iso.substring(0, iso.length >= 10 ? 10 : iso.length));
    return d == null ? '' : DateFormat('d MMM', 'fr_FR').format(d);
  }

  /// Heure locale telle qu'annoncée par la compagnie (sans conversion de fuseau)
  static String _time(String? iso) => iso != null && iso.length >= 16 ? iso.substring(11, 16).replaceFirst(':', 'h') : '';

  static String _stops(int n) => n == 0 ? 'Direct' : '$n escale${n > 1 ? 's' : ''}';

  /// Repères du comparatif, une ligne par offre (une offre peut cumuler plusieurs titres)
  List<({List<String> labels, FlightOffer offer})> _rows() {
    if (option.highlights.isEmpty) return [for (final o in option.offers.take(3)) (labels: const <String>[], offer: o)];
    final rows = <({List<String> labels, FlightOffer offer})>[];
    for (final h in option.highlights) {
      final label = switch (h.kind) {
        'cheapest' => 'Le moins cher',
        'direct' => 'Direct',
        'fastest' => 'Le plus rapide',
        _ => 'Meilleur rapport',
      };
      final i = rows.indexWhere((r) => r.offer.link == h.offer.link && r.offer.price == h.offer.price);
      if (i >= 0) {
        rows[i].labels.add(label);
      } else {
        rows.add((labels: [label], offer: h.offer));
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return _Card(
      accent: _flights.color,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/icons3d/airplane.png', width: 40, height: 40),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: VoyagoColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
                    Text(option.subtitle, style: const TextStyle(color: VoyagoColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                decoration: BoxDecoration(
                  color: VoyagoColors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bolt_rounded, size: 12, color: VoyagoColors.primary),
                    Text('Prix réels', style: TextStyle(color: VoyagoColors.primary, fontSize: 10.5, fontWeight: FontWeight.w800)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (option.priceVerdict != null) ...[
            _PriceVerdict(verdict: option.priceVerdict!, median: option.monthMedian, fmt: fmt),
            const SizedBox(height: 8),
          ],
          if (option.offers.isEmpty)
            const Text(
              'Pas encore de tarif relevé pour ces dates exactes : compare en direct ci-dessous.',
              style: TextStyle(color: VoyagoColors.muted, fontSize: 12.5),
            )
          else
            for (final row in _rows())
              _FlightOfferRow(
                labels: row.labels,
                offer: row.offer,
                fmt: fmt,
                onTap: () => onOpen(row.offer.link, row.offer.price * option.passengers),
              ),
          if (option.price != null && option.offers.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                'Pour tout le groupe : ~${fmt(option.price!)} · suivi à part du budget sur place',
                style: const TextStyle(color: VoyagoColors.muted, fontSize: 11.5),
              ),
            ),
          if (option.cheaperDates.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('💡 Moins cher à d’autres dates',
                style: TextStyle(color: VoyagoColors.text, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final o in option.cheaperDates)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(12),
                        onTap: () => onOpen(o.link, null),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                          decoration: BoxDecoration(
                            color: VoyagoColors.primary.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: VoyagoColors.primary.withValues(alpha: 0.35)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('${_day(o.departureAt)} → ${_day(o.returnAt)}',
                                  style: const TextStyle(color: VoyagoColors.text, fontSize: 12, fontWeight: FontWeight.w700)),
                              Text(
                                o.saving != null && o.saving! > 0
                                    ? '${fmt(o.price)} · −${fmt(o.saving!)}'
                                    : fmt(o.price),
                                style: const TextStyle(color: VoyagoColors.primary, fontSize: 12.5, fontWeight: FontWeight.w900),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ],
          if (option.flexible.length > 1) ...[
            const SizedBox(height: 12),
            const Text('📅 ± 3 jours autour de ton départ',
                style: TextStyle(color: VoyagoColors.text, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            _FlexibleDates(days: option.flexible, fmt: fmt, onTap: (d) => onOpen(d.link, d.price * option.passengers)),
          ],
          if (option.nearby.isNotEmpty) ...[
            const SizedBox(height: 12),
            const Text('🛫 Aéroports proches moins chers',
                style: TextStyle(color: VoyagoColors.text, fontSize: 13, fontWeight: FontWeight.w800)),
            const SizedBox(height: 6),
            for (final n in option.nearby)
              _NearbyRow(alt: n, fmt: fmt, onTap: () => onOpen(n.link, n.price * option.passengers)),
          ],
          if (alert != null) ...[
            const SizedBox(height: 12),
            _PriceAlertRow(alert: alert!, busy: alertBusy, fmt: fmt, onChanged: onToggleAlert),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (option.link != null)
                Expanded(
                  child: _PartnerButton(
                    label: 'Comparer en direct',
                    color: VoyagoColors.blue,
                    onTap: () => onOpen(option.link!, option.price),
                  ),
                ),
              if (option.link != null) const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onBooked,
                  icon: const Icon(Icons.check_circle_rounded, size: 16),
                  label: const Text("C'est réservé"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: VoyagoColors.primary,
                    side: const BorderSide(color: VoyagoColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 11),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Après un lien partenaire : « Tu as réservé ? » reste à portée de pouce
class _PendingBanner extends StatelessWidget {
  final String label;
  final VoidCallback onYes;
  final VoidCallback onDismiss;

  const _PendingBanner({required this.label, required this.onYes, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      padding: const EdgeInsets.fromLTRB(12, 8, 4, 8),
      decoration: BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VoyagoColors.primary.withValues(alpha: 0.5)),
        boxShadow: const [BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4))],
      ),
      child: Row(
        children: [
          Image.asset('assets/icons3d/money_bag.png', width: 28, height: 28),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Tu as réservé « $label » ?',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: VoyagoColors.text, fontSize: 12.5, fontWeight: FontWeight.w700),
            ),
          ),
          TextButton(
            onPressed: onYes,
            child: const Text('Oui, ajouter', style: TextStyle(color: VoyagoColors.primary, fontWeight: FontWeight.w900)),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
            icon: const Icon(Icons.close_rounded, size: 18, color: VoyagoColors.muted),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Choix des partenaires
// =============================================================================

const _partnerColors = <String, Color>{
  'booking': _bookingBlue,
  'airbnb': _airbnbRed,
  'agoda': Color(0xFF5A3FD8),
  'trip': Color(0xFF287DFA),
  'expedia': Color(0xFFE5A100),
  'tiqets': Color(0xFF14A49B),
  'klook': Color(0xFFFF5B00),
  'getyourguide': Color(0xFFFF5533),
  'viator': Color(0xFF186B6D),
  'kiwitaxi': Color(0xFFF5A623),
  'welcomepickups': Color(0xFF1FB37A),
  'gettransfer': Color(0xFFFF6A13),
  'localrent': Color(0xFF2EB872),
  'getrentacar': Color(0xFFD7263D),
  'discovercars': Color(0xFFE8B10D),
  'airalo': Color(0xFFE5484D),
  'aviasales': Color(0xFF0C73FE),
};

Color _partnerColor(String partner) => _partnerColors[partner] ?? VoyagoColors.blue;

/// Le premier partenaire en grand bouton, les autres en pastilles : plusieurs choix, un seul geste.
class _PartnerChoices extends StatelessWidget {
  final List<PartnerChoice> choices;
  final ValueChanged<PartnerChoice> onTap;
  final bool compact;
  final bool showNotes;
  final String? primaryLabel;

  const _PartnerChoices({
    required this.choices,
    required this.onTap,
    this.compact = false,
    this.showNotes = false,
    this.primaryLabel,
  });

  @override
  Widget build(BuildContext context) {
    if (choices.isEmpty) return const SizedBox.shrink();
    final first = choices.first;
    final others = choices.skip(1).toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _PartnerButton(
          label: primaryLabel != null ? '$primaryLabel · ${first.label}' : 'Voir sur ${first.label}',
          color: _partnerColor(first.partner),
          onTap: () => onTap(first),
        ),
        if (showNotes && first.note != null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(first.note!, style: const TextStyle(color: VoyagoColors.muted, fontSize: 11)),
          ),
        if (others.isNotEmpty) ...[
          SizedBox(height: compact ? 6 : 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in others)
                _PartnerChip(choice: c, color: _partnerColor(c.partner), onTap: () => onTap(c)),
            ],
          ),
        ],
      ],
    );
  }
}

class _PartnerChip extends StatelessWidget {
  final PartnerChoice choice;
  final Color color;
  final VoidCallback onTap;

  const _PartnerChip({required this.choice, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: choice.note ?? choice.label,
      child: Material(
        color: color.withValues(alpha: 0.13),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withValues(alpha: 0.45)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 7, height: 7, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(choice.label,
                    style: const TextStyle(color: VoyagoColors.text, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(width: 4),
                const Icon(Icons.north_east_rounded, size: 12, color: VoyagoColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Alternative d'hébergement : type, quartier, prix par nuit et accès direct aux annonces
class _StayOptionTile extends StatelessWidget {
  final StayOption option;
  final String Function(num) fmt;
  final ValueChanged<PartnerChoice> onTap;

  const _StayOptionTile({required this.option, required this.fmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = option.fitsBudget ? VoyagoColors.primary : VoyagoColors.orange;
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: VoyagoColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(option.kind,
                        style: const TextStyle(color: VoyagoColors.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
                    Text('📍 ${option.area}', style: const TextStyle(color: VoyagoColors.muted, fontSize: 11.5)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    option.nightlyMax > option.nightlyMin
                        ? '${fmt(option.nightlyMin)} – ${fmt(option.nightlyMax)}'
                        : fmt(option.nightlyMin),
                    style: TextStyle(color: color, fontSize: 13.5, fontWeight: FontWeight.w900),
                  ),
                  Text(option.fitsBudget ? 'dans ton budget' : '/ nuit',
                      style: TextStyle(color: option.fitsBudget ? color : VoyagoColors.muted, fontSize: 10.5)),
                ],
              ),
            ],
          ),
          if (option.why != null) ...[
            const SizedBox(height: 4),
            Text(option.why!, style: const TextStyle(color: VoyagoColors.muted, fontSize: 12, height: 1.3)),
          ],
          if (option.choices.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final c in option.choices) _PartnerChip(choice: c, color: _partnerColor(c.partner), onTap: () => onTap(c)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// =============================================================================
// Comparatif : meilleur plan, vols, pass
// =============================================================================

/// « Ton meilleur plan » : coût estimé face au budget, économies classées, astuces locales
class _PlanCard extends StatelessWidget {
  final TripPlan plan;
  final String Function(num) fmt;
  final ValueChanged<int> onSaving;

  const _PlanCard({required this.plan, required this.fmt, required this.onSaving});

  @override
  Widget build(BuildContext context) {
    final color = plan.fits ? VoyagoColors.primary : VoyagoColors.orange;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [color.withValues(alpha: 0.16), VoyagoColors.surface],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('🧭', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Ton meilleur plan',
                    style: TextStyle(color: VoyagoColors.text, fontSize: 17, fontWeight: FontWeight.w900)),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                decoration: BoxDecoration(color: color.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(10)),
                child: Text(
                  plan.fits ? 'Dans ton budget' : 'Dépasse de ${fmt(plan.gap)}',
                  style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w900),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text.rich(
            TextSpan(
              style: const TextStyle(color: VoyagoColors.muted, fontSize: 13, height: 1.4),
              children: [
                const TextSpan(text: 'Sur place '),
                TextSpan(
                  text: '~${fmt(plan.costOnSite)}',
                  style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w900),
                ),
                TextSpan(text: ' pour un budget de ${fmt(plan.budgetTotal)}'),
                if (plan.totalWithFlights != null) ...[
                  const TextSpan(text: '\nAvec les vols : '),
                  TextSpan(
                    text: '~${fmt(plan.totalWithFlights!)}',
                    style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w900),
                  ),
                ],
              ],
            ),
          ),
          if (plan.savings.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              plan.fits ? 'Pour en garder plus dans ta poche' : 'Pour revenir dans ton budget',
              style: const TextStyle(color: VoyagoColors.text, fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            for (final x in plan.savings) _SavingRow(saving: x, fmt: fmt, onTap: () => onSaving(x.tab)),
          ],
          if (plan.moneyTips.isNotEmpty || plan.bookingWindow != null) ...[
            const SizedBox(height: 10),
            for (final t in plan.moneyTips)
              _TipLine(icon: '💡', text: t),
            if (plan.bookingWindow != null) _TipLine(icon: '⏰', text: plan.bookingWindow!),
          ],
        ],
      ),
    );
  }
}

class _SavingRow extends StatelessWidget {
  final PlanSaving saving;
  final String Function(num) fmt;
  final VoidCallback onTap;

  const _SavingRow({required this.saving, required this.fmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final icon = switch (saving.kind) {
      'lodging' => 'assets/icons3d/hotel.png',
      'pass' => 'assets/icons3d/admission_tickets.png',
      _ => 'assets/icons3d/airplane.png',
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: VoyagoColors.background.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Image.asset(icon, width: 28, height: 28),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(saving.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: VoyagoColors.text, fontSize: 13, fontWeight: FontWeight.w800)),
                      Text(saving.detail,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: VoyagoColors.muted, fontSize: 11.5)),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text('−${fmt(saving.amount)}',
                    style: const TextStyle(color: VoyagoColors.primary, fontSize: 14, fontWeight: FontWeight.w900)),
                const Icon(Icons.chevron_right_rounded, size: 18, color: VoyagoColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TipLine extends StatelessWidget {
  final String icon;
  final String text;

  const _TipLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('$icon ', style: const TextStyle(fontSize: 12.5)),
          Expanded(child: Text(text, style: const TextStyle(color: VoyagoColors.muted, fontSize: 12, height: 1.35))),
        ],
      ),
    );
  }
}

/// Bon prix / prix moyen / prix élevé face aux prix du mois sur la ligne
class _PriceVerdict extends StatelessWidget {
  final String verdict;
  final int? median;
  final String Function(num) fmt;

  const _PriceVerdict({required this.verdict, this.median, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (verdict) {
      'good' => ('Bon prix : sous la moyenne du mois', VoyagoColors.primary),
      'high' => ('Prix élevé : regarde les autres dates', VoyagoColors.orange),
      _ => ('Prix dans la moyenne du mois', VoyagoColors.blue),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Icon(verdict == 'high' ? Icons.trending_up_rounded : Icons.trending_down_rounded, size: 16, color: color),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              median != null ? '$label (≈ ${fmt(median!)}/pers.)' : label,
              style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

class _FlightOfferRow extends StatelessWidget {
  final List<String> labels;
  final FlightOffer offer;
  final String Function(num) fmt;
  final VoidCallback onTap;

  const _FlightOfferRow({required this.labels, required this.offer, required this.fmt, required this.onTap});

  static String _duration(int? minutes) {
    if (minutes == null || minutes <= 0) return '';
    final h = minutes ~/ 60, m = minutes % 60;
    return m == 0 ? '${h}h' : '${h}h${m.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final out = _duration(offer.durationTo);
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: VoyagoColors.background,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (labels.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: Wrap(
                            spacing: 4,
                            runSpacing: 4,
                            children: [
                              for (final l in labels)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                  decoration: BoxDecoration(
                                    color: VoyagoColors.primary.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(l,
                                      style: const TextStyle(color: VoyagoColors.primary, fontSize: 10, fontWeight: FontWeight.w800)),
                                ),
                            ],
                          ),
                        ),
                      Text(offer.airline ?? 'Compagnie',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: VoyagoColors.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          if (_FlightCard._time(offer.departureAt).isNotEmpty) 'Départ ${_FlightCard._time(offer.departureAt)}',
                          if (out.isNotEmpty) out,
                          _FlightCard._stops(offer.transfers),
                          if (offer.returnTransfers != null && offer.returnTransfers != offer.transfers)
                            'retour ${_FlightCard._stops(offer.returnTransfers!).toLowerCase()}',
                        ].join(' · '),
                        style: const TextStyle(color: VoyagoColors.muted, fontSize: 11.5),
                      ),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(fmt(offer.price),
                        style: const TextStyle(color: VoyagoColors.text, fontSize: 16, fontWeight: FontWeight.w900)),
                    const Text('/pers. A/R', style: TextStyle(color: VoyagoColors.muted, fontSize: 10.5)),
                  ],
                ),
                const SizedBox(width: 6),
                const Icon(Icons.chevron_right_rounded, color: VoyagoColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Grille ± 3 jours : le prix de chaque jour de départ, le moins cher en vert
class _FlexibleDates extends StatelessWidget {
  final List<FlightAlternative> days;
  final String Function(num) fmt;
  final ValueChanged<FlightAlternative> onTap;

  const _FlexibleDates({required this.days, required this.fmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cheapest = days.map((d) => d.price).reduce((a, b) => a < b ? a : b);
    return SizedBox(
      height: 64,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 6),
        itemBuilder: (_, i) {
          final d = days[i];
          final date = DateTime.tryParse(d.departure);
          final best = d.price == cheapest;
          final color = best ? VoyagoColors.primary : VoyagoColors.cardBorder;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => onTap(d),
            child: Container(
              width: 74,
              padding: const EdgeInsets.symmetric(vertical: 6),
              decoration: BoxDecoration(
                color: best ? VoyagoColors.primary.withValues(alpha: 0.14) : VoyagoColors.background,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: color),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(date == null ? d.departure : DateFormat('EEE d', 'fr_FR').format(date),
                      style: const TextStyle(color: VoyagoColors.muted, fontSize: 11)),
                  const SizedBox(height: 2),
                  Text(fmt(d.price),
                      style: TextStyle(
                        color: best ? VoyagoColors.primary : VoyagoColors.text,
                        fontSize: 13.5,
                        fontWeight: FontWeight.w900,
                      )),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _NearbyRow extends StatelessWidget {
  final FlightAlternative alt;
  final String Function(num) fmt;
  final VoidCallback onTap;

  const _NearbyRow({required this.alt, required this.fmt, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: VoyagoColors.background,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Text('${alt.origin ?? ''} → ${alt.destination ?? ''}',
                    style: const TextStyle(color: VoyagoColors.text, fontSize: 13, fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(_FlightCard._stops(alt.transfers),
                      style: const TextStyle(color: VoyagoColors.muted, fontSize: 11.5)),
                ),
                Text(fmt(alt.price), style: const TextStyle(color: VoyagoColors.text, fontSize: 13.5, fontWeight: FontWeight.w900)),
                if (alt.saving != null && alt.saving! > 0) ...[
                  const SizedBox(width: 6),
                  Text('−${fmt(alt.saving!)}',
                      style: const TextStyle(color: VoyagoColors.primary, fontSize: 12, fontWeight: FontWeight.w800)),
                ],
                const Icon(Icons.chevron_right_rounded, size: 18, color: VoyagoColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pass touristique ou billets à l'unité : le verdict chiffré
class _PassCard extends StatelessWidget {
  final PassCompare pass;
  final String Function(num) fmt;

  const _PassCard({required this.pass, required this.fmt});

  @override
  Widget build(BuildContext context) {
    final color = pass.worthIt ? VoyagoColors.primary : VoyagoColors.muted;
    return _Card(
      accent: pass.worthIt ? VoyagoColors.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/icons3d/credit_card.png', width: 36, height: 36),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pass.name,
                        style: const TextStyle(color: VoyagoColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
                    Text(
                      pass.worthIt ? 'Le pass est plus avantageux' : 'Les billets à l’unité restent moins chers',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _CompareCell(label: 'Pass', value: fmt(pass.priceGroup), highlight: pass.worthIt)),
              const SizedBox(width: 8),
              Expanded(child: _CompareCell(label: 'À l’unité', value: fmt(pass.individualTotal), highlight: !pass.worthIt)),
            ],
          ),
          const SizedBox(height: 8),
          Text('Inclut : ${pass.covers.join(', ')}',
              style: const TextStyle(color: VoyagoColors.muted, fontSize: 11.5, height: 1.3)),
          if (pass.worthIt && pass.saving > 0)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text('Économie : ${fmt(pass.saving)} pour le groupe',
                  style: const TextStyle(color: VoyagoColors.primary, fontSize: 12.5, fontWeight: FontWeight.w800)),
            ),
          if (pass.tip != null) _TipLine(icon: '💡', text: pass.tip!),
        ],
      ),
    );
  }
}

class _CompareCell extends StatelessWidget {
  final String label;
  final String value;
  final bool highlight;

  const _CompareCell({required this.label, required this.value, required this.highlight});

  @override
  Widget build(BuildContext context) {
    final color = highlight ? VoyagoColors.primary : VoyagoColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: highlight ? VoyagoColors.primary.withValues(alpha: 0.12) : VoyagoColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: highlight ? VoyagoColors.primary.withValues(alpha: 0.5) : VoyagoColors.cardBorder),
      ),
      child: Column(
        children: [
          Text(label, style: const TextStyle(color: VoyagoColors.muted, fontSize: 11)),
          Text(value, style: TextStyle(color: highlight ? color : VoyagoColors.text, fontSize: 16, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}

/// « 🔔 Alerte prix » : suivi du vol, notification quand il baisse
class _PriceAlertRow extends StatelessWidget {
  final PriceAlertState alert;
  final bool busy;
  final String Function(num) fmt;
  final ValueChanged<bool> onChanged;

  const _PriceAlertRow({required this.alert, required this.busy, required this.fmt, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final on = alert.enabled;
    final detail = on
        ? [
            if (alert.lastPrice != null) 'Dernier relevé ${fmt(alert.lastPrice!)}',
            if (alert.lowestPrice != null && alert.lowestPrice != alert.lastPrice) 'plus bas ${fmt(alert.lowestPrice!)}',
          ].join(' · ')
        : 'On te prévient dès que ce vol baisse';
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: on ? VoyagoColors.primary.withValues(alpha: 0.12) : VoyagoColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: on ? VoyagoColors.primary.withValues(alpha: 0.5) : VoyagoColors.cardBorder),
      ),
      child: Row(
        children: [
          Icon(on ? Icons.notifications_active_rounded : Icons.notifications_none_rounded,
              color: on ? VoyagoColors.primary : VoyagoColors.muted, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(on ? 'Alerte prix active' : 'Alerte prix',
                    style: const TextStyle(color: VoyagoColors.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
                Text(detail.isEmpty ? 'Suivi en cours' : detail,
                    style: const TextStyle(color: VoyagoColors.muted, fontSize: 11.5)),
              ],
            ),
          ),
          Switch(
            value: on,
            activeThumbColor: Colors.white,
            activeTrackColor: VoyagoColors.primary,
            onChanged: busy ? null : onChanged,
          ),
        ],
      ),
    );
  }
}
