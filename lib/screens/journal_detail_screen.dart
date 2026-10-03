import 'package:cached_network_image/cached_network_image.dart';
import 'package:custom_rating_bar/custom_rating_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../models/journal.dart';
import '../providers/journal_provider.dart';
import '../theme.dart';
import '../widgets/journal/journal_entry_sheet.dart';
import '../widgets/journal/journal_story_studio.dart';
import '../widgets/journal/next_trip_ideas_card.dart';
import '../widgets/journal/journal_budget_card.dart';
import '../widgets/journal/journal_ui.dart';
import '../widgets/place_review_sheet.dart';

/// Carnet d'un voyage passé : bilan, jours, lieux, souvenirs, story.
class JournalDetailScreen extends ConsumerStatefulWidget {
  final String tripId;

  const JournalDetailScreen({super.key, required this.tripId});

  @override
  ConsumerState<JournalDetailScreen> createState() => _JournalDetailScreenState();
}

class _JournalDetailScreenState extends ConsumerState<JournalDetailScreen> {
  int? _dayFilter; // null = tous les jours

  @override
  Widget build(BuildContext context) {
    final journalAsync = ref.watch(journalDetailProvider(widget.tripId));

    return Scaffold(
      backgroundColor: VoyagoColors.background,
      body: journalAsync.when(
        data: _content,
        loading: () => const Center(child: CircularProgressIndicator(color: VoyagoColors.primary, strokeWidth: 2.5)),
        error: (e, _) => _error(),
      ),
    );
  }

  Widget _content(JournalDetail j) {
    final days = _dayFilter == null ? j.days : j.days.where((d) => d.day == _dayFilter).toList();

    return RefreshIndicator(
      color: VoyagoColors.primary,
      backgroundColor: VoyagoColors.surface,
      onRefresh: () => ref.refresh(journalDetailProvider(widget.tripId).future),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
        slivers: [
          _appBar(j),
          SliverToBoxAdapter(
            child: Transform.translate(
              offset: const Offset(0, -36),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: _HeroCard(journal: j),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _StoryCta(onTap: () => showJournalStoryStudio(context, j)),
            ),
          ),
          // Réservations & Budget, rangé avec le voyage
          if (j.budget != null && j.budget!.hasData)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: JournalBudgetCard(tripId: j.tripId, budget: j.budget!),
              ),
            ),
          SliverToBoxAdapter(child: _dayFilters(j)),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            sliver: SliverList.builder(
              itemCount: days.length,
              itemBuilder: (_, i) => _DaySection(
                tripId: j.tripId,
                destination: j.destination,
                day: days[i],
                isFirst: days[i].day == 1,
              ),
            ),
          ),
          // « Et maintenant ? » : idées de prochain voyage
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: NextTripIdeasCard(tripId: j.tripId, destination: j.destination),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
              child: _FooterActions(journal: j),
            ),
          ),
        ],
      ),
    );
  }

  SliverAppBar _appBar(JournalDetail j) {
    return SliverAppBar(
      pinned: true,
      expandedHeight: 230,
      backgroundColor: VoyagoColors.background,
      surfaceTintColor: Colors.transparent,
      leading: IconButton(
        icon: const _CircleIcon(icon: Icons.arrow_back_rounded),
        onPressed: () => context.canPop() ? context.pop() : context.go('/journal'),
      ),
      title: Text(j.shortDestination,
          style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w800, fontSize: 18)),
      actions: [
        IconButton(
          tooltip: 'Story Studio',
          icon: const _CircleIcon(icon: Icons.ios_share_rounded),
          onPressed: () => showJournalStoryStudio(context, j),
        ),
        PopupMenuButton<String>(
          icon: const _CircleIcon(icon: Icons.more_horiz_rounded),
          color: VoyagoColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: const BorderSide(color: VoyagoColors.cardBorder),
          ),
          onSelected: (v) => v == 'map' ? context.push('/itinerary/${j.tripId}') : _reopen(j),
          itemBuilder: (_) => [
            const PopupMenuItem(
              value: 'map',
              child: _MenuRow(icon: Icons.map_outlined, label: 'Revoir l\'itinéraire'),
            ),
            if (j.completedManually)
              const PopupMenuItem(
                value: 'reopen',
                child: _MenuRow(icon: Icons.undo_rounded, label: 'Remettre sur la carte'),
              ),
          ],
        ),
        const SizedBox(width: 4),
      ],
      flexibleSpace: FlexibleSpaceBar(
        collapseMode: CollapseMode.parallax,
        background: Stack(
          fit: StackFit.expand,
          children: [
            if (j.coverImageUrl != null && j.coverImageUrl!.isNotEmpty)
              CachedNetworkImage(imageUrl: j.coverImageUrl!, fit: BoxFit.cover)
            else
              Container(color: VoyagoColors.surface),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0x990F1117), Color(0x000F1117), Color(0xFF0F1117)],
                  stops: [0, 0.45, 1],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dayFilters(JournalDetail j) {
    final chips = <(int?, String)>[
      (null, 'Tous les jours (${j.days.length})'),
      for (final d in j.days) (d.day, 'Jour ${d.day}'),
    ];
    return SizedBox(
      height: 40,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        scrollDirection: Axis.horizontal,
        itemCount: chips.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (_, i) {
          final (value, label) = chips[i];
          final selected = _dayFilter == value;
          return GestureDetector(
            onTap: () => setState(() => _dayFilter = value),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              padding: const EdgeInsets.symmetric(horizontal: 14),
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? VoyagoColors.primary : VoyagoColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: selected ? VoyagoColors.primary : VoyagoColors.cardBorder),
              ),
              child: Text(label,
                  style: TextStyle(
                    color: selected ? Colors.white : VoyagoColors.muted,
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  )),
            ),
          );
        },
      ),
    );
  }

  Future<void> _reopen(JournalDetail j) async {
    final router = GoRouter.of(context);
    try {
      await setTripCompleted(ref, tripId: j.tripId, completed: false);
      router.go('/itinerary/${j.tripId}');
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Impossible de remettre ce voyage sur la carte.')));
      }
    }
  }

  Widget _error() {
    return SafeArea(
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('🧭', style: TextStyle(fontSize: 44)),
            const SizedBox(height: 12),
            const Text('Impossible de charger ce journal', style: TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => ref.invalidate(journalDetailProvider(widget.tripId)),
              icon: const Icon(Icons.refresh_rounded, color: VoyagoColors.primary),
              label: const Text('Réessayer', style: TextStyle(color: VoyagoColors.primary, fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: () => context.go('/journal'),
              child: const Text('Retour au journal', style: TextStyle(color: VoyagoColors.muted)),
            ),
          ],
        ),
      ),
    );
  }
}

/// En-tête : statut, titre, badge débloqué et métriques du voyage.
class _HeroCard extends StatelessWidget {
  final JournalDetail journal;

  const _HeroCard({required this.journal});

  @override
  Widget build(BuildContext context) {
    final j = journal;
    final s = j.stats;
    final dates = journalDateRange(j.startDate, j.endDate);

    return GlassCard(
      glow: true,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              JournalPill(
                label: 'VOYAGE TERMINÉ${j.country != null ? ' • ${j.country!.toUpperCase()}' : ''}',
                color: VoyagoColors.primary,
                dot: true,
              ),
              if (dates.isNotEmpty) Text(dates, style: const TextStyle(color: VoyagoColors.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '${j.shortDestination} — ${j.durationDays} jour${j.durationDays > 1 ? 's' : ''} d\'exploration',
            style: const TextStyle(color: VoyagoColors.text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4, height: 1.2),
          ),
          const SizedBox(height: 4),
          Text(
            s.reviewsCount > 0
                ? '${s.reviewsCount} avis publiés · ${s.notesCount} souvenirs · ${s.photosCount} photos'
                : 'Ajoute tes souvenirs et tes avis pour faire vivre ce carnet.',
            style: const TextStyle(color: VoyagoColors.muted, fontSize: 12.5),
          ),
          const SizedBox(height: 14),
          // Badge débloqué
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: VoyagoColors.background.withValues(alpha: 0.7),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: VoyagoColors.yellow.withValues(alpha: 0.45)),
              boxShadow: [BoxShadow(color: VoyagoColors.yellow.withValues(alpha: 0.15), blurRadius: 20, spreadRadius: -4)],
            ),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.bottomLeft,
                      end: Alignment.topRight,
                      colors: [VoyagoColors.orange, VoyagoColors.yellow],
                    ),
                    borderRadius: BorderRadius.circular(13),
                  ),
                  child: Icon(journalBadgeIcon(j.badge.icon), color: VoyagoColors.background, size: 24),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('BADGE DÉBLOQUÉ',
                          style: TextStyle(color: VoyagoColors.yellow, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
                      Text(j.badge.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(color: VoyagoColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: JournalMetricTile(icon: Icons.route_rounded, color: VoyagoColors.blue, label: 'Distance', value: s.distanceLabel),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: JournalMetricTile(
                  icon: Icons.pin_drop_rounded,
                  color: VoyagoColors.primary,
                  label: 'Lieux visités',
                  value: '${s.visitedCount}/${s.placesCount}',
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: s.gemsTotal > 0
                    ? JournalMetricTile(
                        icon: Icons.diamond_rounded,
                        color: VoyagoColors.blue,
                        label: 'Pépites trouvées',
                        value: '${s.gemsCollected}/${s.gemsTotal}')
                    : s.hiddenGems > 0
                    ? JournalMetricTile(icon: Icons.diamond_rounded, color: VoyagoColors.blue, label: 'Pépites', value: '${s.hiddenGems}')
                    : JournalMetricTile(
                        icon: Icons.favorite_rounded, color: VoyagoColors.coral, label: 'Coups de cœur', value: '${s.favoritesCount}'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: JournalMetricTile(icon: Icons.bolt_rounded, color: VoyagoColors.yellow, label: 'XP du voyage', value: '+${s.xpEarned} XP'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StoryCta extends StatelessWidget {
  final VoidCallback onTap;

  const _StoryCta({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: [
            VoyagoColors.blue.withValues(alpha: 0.16),
            VoyagoColors.primary.withValues(alpha: 0.12),
          ]),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: VoyagoColors.blue.withValues(alpha: 0.35)),
        ),
        child: const Row(
          children: [
            Icon(Icons.smart_display_rounded, color: VoyagoColors.blue, size: 28),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Crée ta story de voyage',
                      style: TextStyle(color: VoyagoColors.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
                  Text('Format 9:16 pour Instagram & TikTok, ou PDF souvenir',
                      style: TextStyle(color: VoyagoColors.muted, fontSize: 11.5)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: VoyagoColors.blue),
          ],
        ),
      ),
    );
  }
}

/// Un jour du carnet : pastille numérotée, thème, météo, puis les lieux.
class _DaySection extends StatelessWidget {
  final String tripId;
  final String destination;
  final JournalDay day;
  final bool isFirst;

  const _DaySection({required this.tripId, required this.destination, required this.day, required this.isFirst});

  @override
  Widget build(BuildContext context) {
    final accent = isFirst ? VoyagoColors.primary : VoyagoColors.blue;
    final date = day.date != null ? DateFormat('EEEE d MMMM', 'fr').format(day.date!) : null;

    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Ligne de vie du voyage
            SizedBox(
              width: 34,
              child: Column(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: VoyagoColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: accent, width: 2),
                      boxShadow: [BoxShadow(color: accent.withValues(alpha: 0.35), blurRadius: 14)],
                    ),
                    child: Text(day.day.toString().padLeft(2, '0'),
                        style: TextStyle(color: accent, fontSize: 11.5, fontWeight: FontWeight.w800)),
                  ),
                  Expanded(child: Container(width: 2, color: VoyagoColors.cardBorder)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Jour ${day.day} • ${day.theme}',
                      style: TextStyle(color: accent, fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      if (date != null)
                        Text(date[0].toUpperCase() + date.substring(1),
                            style: const TextStyle(color: VoyagoColors.muted, fontSize: 12)),
                      if (day.weather != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                          decoration: BoxDecoration(
                            color: VoyagoColors.surface,
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: VoyagoColors.cardBorder),
                          ),
                          child: Text(
                            '${day.weather!.icon} ${day.weather!.tempMax.round()}°C • ${day.weather!.summary}',
                            style: const TextStyle(color: VoyagoColors.muted, fontSize: 11),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  for (final place in day.places)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: _PlaceEntryCard(
                        tripId: tripId,
                        destination: destination,
                        place: place,
                        dayCount: day.places.length,
                      ),
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

/// Un lieu du carnet : créneau, photo + légende, humeurs, étoiles, actions.
class _PlaceEntryCard extends StatelessWidget {
  final String tripId;
  final String destination;
  final JournalPlace place;
  final int dayCount;

  const _PlaceEntryCard({required this.tripId, required this.destination, required this.place, required this.dayCount});

  @override
  Widget build(BuildContext context) {
    final poi = place.poi;
    final entry = place.entry;
    final slot = journalSlot(poi.order, dayCount);
    final photo = place.coverPhoto;
    final note = entry?.note ?? '';
    final photosCount = entry?.photos.length ?? 0;

    return GlassCard(
      padding: const EdgeInsets.all(14),
      radius: 20,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              JournalPill(label: slot.label, color: slot.color),
              const Spacer(),
              if (poi.hiddenGem)
                const JournalPill(label: 'PÉPITE', color: VoyagoColors.blue, icon: Icons.diamond_rounded)
              else if (place.visited)
                const JournalPill(label: 'VISITÉ', color: VoyagoColors.primary, icon: Icons.check_circle_rounded),
            ],
          ),
          const SizedBox(height: 8),
          Text(poi.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: VoyagoColors.text, fontSize: 15.5, fontWeight: FontWeight.w800)),
          if (photo != null && photo.isNotEmpty) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: AspectRatio(
                aspectRatio: 16 / 9,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CachedNetworkImage(
                      imageUrl: photo,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Container(color: VoyagoColors.background),
                      errorWidget: (_, __, ___) => Container(color: VoyagoColors.background),
                    ),
                    if (note.isNotEmpty || photosCount > 0)
                      const DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x000F1117), Color(0xE60F1117)],
                            stops: [0.45, 1],
                          ),
                        ),
                      ),
                    if (note.isNotEmpty)
                      Positioned(
                        left: 12,
                        right: photosCount > 0 ? 54 : 12,
                        bottom: 10,
                        child: Text('« $note »',
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                                color: VoyagoColors.text, fontSize: 12, fontStyle: FontStyle.italic, height: 1.3)),
                      ),
                    if (photosCount > 0)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                          decoration: BoxDecoration(
                            color: VoyagoColors.background.withValues(alpha: 0.85),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: VoyagoColors.cardBorder),
                          ),
                          child: Text('📷 $photosCount', style: const TextStyle(color: VoyagoColors.text, fontSize: 10.5)),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ] else if (note.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text('« $note »',
                style: const TextStyle(color: VoyagoColors.text, fontSize: 13, fontStyle: FontStyle.italic, height: 1.4)),
          ],
          if (note.isEmpty) ...[
            const SizedBox(height: 8),
            Text(poi.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: VoyagoColors.muted, fontSize: 12.5, height: 1.4)),
          ],
          if (entry?.moodTags.isNotEmpty ?? false) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final tag in entry!.moodTags)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: VoyagoColors.background,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('#$tag',
                        style: const TextStyle(color: VoyagoColors.muted, fontSize: 11, fontWeight: FontWeight.w700)),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              if (place.myRating != null) ...[
                RatingBar.readOnly(
                  initialRating: place.myRating!.toDouble(),
                  filledIcon: Icons.star_rounded,
                  emptyIcon: Icons.star_outline_rounded,
                  filledColor: VoyagoColors.yellow,
                  emptyColor: VoyagoColors.muted.withValues(alpha: 0.4),
                  size: 16,
                ),
                if (place.myLiked) ...[
                  const SizedBox(width: 6),
                  const Icon(Icons.favorite_rounded, color: VoyagoColors.coral, size: 15),
                ],
              ] else
                _ActionChip(
                  icon: Icons.star_outline_rounded,
                  label: 'Noter',
                  color: VoyagoColors.yellow,
                  onTap: () async {
                    final container = ProviderScope.containerOf(context, listen: false);
                    await showPlaceReviewSheet(
                      context,
                      ReviewTarget.fromPoi(poi, destination: destination, tripId: tripId),
                    );
                    // Étoiles, coups de cœur et lieux visités du carnet à jour
                    container.invalidate(journalDetailProvider(tripId));
                    container.invalidate(journalListProvider);
                  },
                ),
              const Spacer(),
              Flexible(
                child: _ActionChip(
                  icon: entry == null || (note.isEmpty && photosCount == 0) ? Icons.add_a_photo_rounded : Icons.edit_rounded,
                  label: entry == null || (note.isEmpty && photosCount == 0) ? 'Souvenir' : 'Modifier',
                  color: VoyagoColors.primary,
                  onTap: () => showJournalEntrySheet(context, tripId: tripId, place: place),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FooterActions extends ConsumerStatefulWidget {
  final JournalDetail journal;

  const _FooterActions({required this.journal});

  @override
  ConsumerState<_FooterActions> createState() => _FooterActionsState();
}

class _FooterActionsState extends ConsumerState<_FooterActions> {
  bool _loading = false;

  Future<void> _share() async {
    setState(() => _loading = true);
    try {
      final xp = await ref.read(journalApiProvider).share(widget.journal.tripId);
      ref.invalidate(journalDetailProvider(widget.journal.tripId));
      ref.invalidate(journalListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          behavior: SnackBarBehavior.floating,
          content: Text(xp > 0 ? 'Journal partagé à la communauté ! +$xp XP 🎉' : 'Journal déjà partagé'),
        ));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Partage impossible pour le moment.')));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final shared = widget.journal.journalShared;
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: OutlinedButton.icon(
        onPressed: shared || _loading ? null : _share,
        icon: _loading
            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: VoyagoColors.blue))
            : Icon(shared ? Icons.check_circle_rounded : Icons.groups_rounded, size: 19),
        label: Text(
          shared ? 'Partagé à la communauté Voyagooo' : 'Partager à la communauté (+5 XP)',
          style: const TextStyle(fontWeight: FontWeight.w800),
        ),
        style: OutlinedButton.styleFrom(
          foregroundColor: VoyagoColors.blue,
          disabledForegroundColor: VoyagoColors.primary,
          backgroundColor: VoyagoColors.blue.withValues(alpha: 0.08),
          side: BorderSide(color: VoyagoColors.blue.withValues(alpha: 0.4)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _ActionChip({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: 0.35)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: color, size: 15),
            const SizedBox(width: 4),
            Flexible(
              child: Text(label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: color, fontSize: 11.5, fontWeight: FontWeight.w800)),
            ),
          ],
        ),
      ),
    );
  }
}

class _CircleIcon extends StatelessWidget {
  final IconData icon;

  const _CircleIcon({required this.icon});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: VoyagoColors.background.withValues(alpha: 0.65),
        shape: BoxShape.circle,
        border: Border.all(color: VoyagoColors.cardBorder),
      ),
      child: Icon(icon, color: VoyagoColors.text, size: 19),
    );
  }
}

class _MenuRow extends StatelessWidget {
  final IconData icon;
  final String label;

  const _MenuRow({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: VoyagoColors.muted, size: 18),
        const SizedBox(width: 10),
        Text(label, style: const TextStyle(color: VoyagoColors.text, fontSize: 13)),
      ],
    );
  }
}
