import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/journal.dart';
import '../providers/auth_provider.dart';
import '../providers/journal_provider.dart';
import '../theme.dart';
import '../widgets/journal/journal_ui.dart';

/// Journal de voyage : les voyages passés, qui ont quitté la carte.
class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isAuthenticatedProvider);
    final journalAsync = ref.watch(journalListProvider);

    return Scaffold(
      backgroundColor: VoyagoColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          color: VoyagoColors.primary,
          backgroundColor: VoyagoColors.surface,
          onRefresh: () => ref.refresh(journalListProvider.future),
          child: CustomScrollView(
            physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
            slivers: [
              SliverToBoxAdapter(child: _Header(onBack: () => _back(context))),
              if (!isLoggedIn)
                const SliverFillRemaining(hasScrollBody: false, child: _GuestState())
              else
                ...journalAsync.when(
                  data: (trips) => trips.isEmpty
                      ? [const SliverFillRemaining(hasScrollBody: false, child: _EmptyState())]
                      : [
                          SliverToBoxAdapter(child: _Summary(trips: trips)),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
                            sliver: SliverList.separated(
                              itemCount: trips.length,
                              separatorBuilder: (_, __) => const SizedBox(height: 16),
                              itemBuilder: (_, i) => _JournalTripCard(trip: trips[i]),
                            ),
                          ),
                        ],
                  loading: () => [
                    SliverPadding(
                      padding: const EdgeInsets.all(16),
                      sliver: SliverList.separated(
                        itemCount: 3,
                        separatorBuilder: (_, __) => const SizedBox(height: 16),
                        itemBuilder: (_, __) => const _CardSkeleton(),
                      ),
                    ),
                  ],
                  error: (e, _) => [
                    SliverFillRemaining(
                      hasScrollBody: false,
                      child: _ErrorState(onRetry: () => ref.invalidate(journalListProvider)),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }

  void _back(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/itinerary');
    }
  }
}

class _Header extends StatelessWidget {
  final VoidCallback onBack;

  const _Header({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 16, 8),
      child: Row(
        children: [
          IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, color: VoyagoColors.text),
          ),
          const SizedBox(width: 4),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: VoyagoColors.yellow.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: VoyagoColors.yellow.withValues(alpha: 0.35)),
            ),
            child: const Icon(Icons.auto_stories_rounded, color: VoyagoColors.yellow, size: 22),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Journal de voyage',
                    style: TextStyle(color: VoyagoColors.text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4)),
                Text('Tes voyages passés, tes lieux et tes souvenirs',
                    style: TextStyle(color: VoyagoColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Récapitulatif de toutes les aventures passées.
class _Summary extends StatelessWidget {
  final List<JournalTripSummary> trips;

  const _Summary({required this.trips});

  @override
  Widget build(BuildContext context) {
    final km = trips.fold<double>(0, (s, t) => s + t.stats.distanceKm);
    final visited = trips.fold<int>(0, (s, t) => s + t.stats.visitedCount);
    final favorites = trips.fold<int>(0, (s, t) => s + t.stats.favoritesCount);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Row(
        children: [
          _SummaryItem(value: '${trips.length}', label: trips.length > 1 ? 'voyages' : 'voyage', color: VoyagoColors.primary),
          _SummaryItem(value: km >= 10 ? '${km.round()}' : km.toStringAsFixed(1), label: 'km parcourus', color: VoyagoColors.blue),
          _SummaryItem(value: '$visited', label: 'lieux visités', color: VoyagoColors.yellow),
          _SummaryItem(value: '$favorites', label: 'coups de cœur', color: VoyagoColors.coral),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _SummaryItem({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 3),
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 6),
        decoration: BoxDecoration(
          color: VoyagoColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VoyagoColors.cardBorder),
        ),
        child: Column(
          children: [
            Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: VoyagoColors.muted, fontSize: 10.5, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _JournalTripCard extends StatelessWidget {
  final JournalTripSummary trip;

  const _JournalTripCard({required this.trip});

  @override
  Widget build(BuildContext context) {
    final s = trip.stats;
    final dates = journalDateRange(trip.startDate, trip.endDate);

    return GestureDetector(
      onTap: () => context.push('/journal/${trip.tripId}'),
      child: Container(
        decoration: BoxDecoration(
          color: VoyagoColors.surface,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: VoyagoColors.cardBorder),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10))],
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 160,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (trip.coverImageUrl != null && trip.coverImageUrl!.isNotEmpty)
                    CachedNetworkImage(
                      imageUrl: trip.coverImageUrl!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: VoyagoColors.background),
                      errorWidget: (_, __, ___) => Container(color: VoyagoColors.background),
                    )
                  else
                    Container(color: VoyagoColors.background),
                  const DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x330F1117), Color(0x000F1117), Color(0xF20F1117)],
                        stops: [0, 0.4, 1],
                      ),
                    ),
                  ),
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Row(
                      children: [
                        Flexible(
                          child: JournalPill(
                            label: 'VOYAGE TERMINÉ${trip.country != null ? ' • ${trip.country!.toUpperCase()}' : ''}',
                            color: VoyagoColors.primary,
                            dot: true,
                          ),
                        ),
                        if (trip.journalShared) ...[
                          const SizedBox(width: 6),
                          const JournalPill(label: 'PARTAGÉ', color: VoyagoColors.blue, icon: Icons.groups_rounded),
                        ],
                      ],
                    ),
                  ),
                  Positioned(
                    left: 16,
                    right: 16,
                    bottom: 12,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          trip.destination.split(',').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: VoyagoColors.text, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                        ),
                        Text(
                          [if (dates.isNotEmpty) dates, '${trip.durationDays} jour${trip.durationDays > 1 ? 's' : ''}'].join(' · '),
                          style: const TextStyle(color: VoyagoColors.muted, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 14),
              child: Column(
                children: [
                  Row(
                    children: [
                      _MiniStat(icon: Icons.route_rounded, color: VoyagoColors.blue, text: s.distanceLabel),
                      _MiniStat(
                        icon: Icons.pin_drop_rounded,
                        color: VoyagoColors.primary,
                        text: '${s.visitedCount}/${s.placesCount} lieux',
                      ),
                      if (trip.budget != null)
                        _MiniStat(
                          icon: Icons.account_balance_wallet_rounded,
                          color: trip.budget!.withinBudget ? VoyagoColors.yellow : VoyagoColors.orange,
                          text: NumberFormat.simpleCurrency(locale: 'fr_FR', name: trip.budget!.currency, decimalDigits: 0)
                              .format(trip.budget!.spent),
                        )
                      else
                        _MiniStat(icon: Icons.favorite_rounded, color: VoyagoColors.coral, text: '${s.favoritesCount}'),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Container(
                        width: 30,
                        height: 30,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(colors: [VoyagoColors.orange, VoyagoColors.yellow]),
                          borderRadius: BorderRadius.circular(9),
                          boxShadow: [BoxShadow(color: VoyagoColors.yellow.withValues(alpha: 0.3), blurRadius: 12)],
                        ),
                        child: Icon(journalBadgeIcon(trip.badge.icon), color: VoyagoColors.background, size: 17),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          trip.badge.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: VoyagoColors.text, fontSize: 13.5, fontWeight: FontWeight.w700),
                        ),
                      ),
                      const Text('Ouvrir', style: TextStyle(color: VoyagoColors.primary, fontSize: 12, fontWeight: FontWeight.w800)),
                      const Icon(Icons.chevron_right_rounded, color: VoyagoColors.primary, size: 20),
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

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String text;

  const _MiniStat({required this.icon, required this.color, required this.text});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Flexible(
            child: Text(text,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: VoyagoColors.text, fontSize: 12.5, fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    );
  }
}

class _CardSkeleton extends StatelessWidget {
  const _CardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VoyagoColors.cardBorder),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📖', style: TextStyle(fontSize: 56)),
          const SizedBox(height: 16),
          const Text('Ton journal t\'attend',
              style: TextStyle(color: VoyagoColors.text, fontSize: 20, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          const Text(
            'Une fois un voyage passé, il quitte la carte et s\'installe ici avec tes lieux, tes avis et tes souvenirs. '
            'Tu peux aussi terminer un voyage depuis le menu.',
            textAlign: TextAlign.center,
            style: TextStyle(color: VoyagoColors.muted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => context.go('/swipe'),
            icon: const Icon(Icons.add_location_alt_rounded, size: 18),
            label: const Text('Planifier un voyage', style: TextStyle(fontWeight: FontWeight.w800)),
            style: ElevatedButton.styleFrom(
              backgroundColor: VoyagoColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
          ),
        ],
      ),
    );
  }
}

class _GuestState extends StatelessWidget {
  const _GuestState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('🔐', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 14),
          const Text('Connecte-toi pour retrouver ton journal',
              textAlign: TextAlign.center,
              style: TextStyle(color: VoyagoColors.text, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () => context.go('/auth'),
            style: ElevatedButton.styleFrom(
              backgroundColor: VoyagoColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Se connecter', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text('🧭', style: TextStyle(fontSize: 44)),
        const SizedBox(height: 12),
        const Text('Impossible de charger ton journal', style: TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        TextButton.icon(
          onPressed: onRetry,
          icon: const Icon(Icons.refresh_rounded, color: VoyagoColors.primary),
          label: const Text('Réessayer', style: TextStyle(color: VoyagoColors.primary, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}
