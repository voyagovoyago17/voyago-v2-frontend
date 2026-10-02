import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/api_exceptions.dart';
import '../models/poi.dart';
import '../models/tribe.dart';
import '../providers/community_provider.dart';
import '../providers/trips_provider.dart';
import '../theme.dart';
import '../widgets/community/tribe_sections.dart';

/// Voyage de tribu : vote des lieux d'un swipe, classement de la tribu, puis itinéraire final.
class TribePlanScreen extends ConsumerStatefulWidget {
  final String circleId;
  final String planId;

  const TribePlanScreen({super.key, required this.circleId, required this.planId});

  @override
  ConsumerState<TribePlanScreen> createState() => _TribePlanScreenState();
}

class _TribePlanScreenState extends ConsumerState<TribePlanScreen> {
  /// Votes faits sur cet écran (clé du lieu → 'up' | 'down') et totaux à jour
  final Map<String, String> _myVotes = {};
  final Map<String, (int, int)> _counts = {};
  bool _busy = false;

  void _back() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/circle/${widget.circleId}');
    }
  }

  void _showError(Object e) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: VoyagoColors.coral,
        content: Text(e is ApiException ? e.message : 'Une erreur est survenue'),
      ),
    );
  }

  String? _voteOf(PlanCandidate c) => _myVotes[c.key] ?? c.myVote;
  (int, int) _countsOf(PlanCandidate c) => _counts[c.key] ?? (c.up, c.down);

  Future<void> _vote(PlanCandidate c, String vote) async {
    final previous = _myVotes[c.key];
    setState(() => _myVotes[c.key] = vote);
    try {
      final res = await ref.read(communityApiProvider).voteTripPlan(widget.planId, c.key, vote);
      if (!mounted) return;
      setState(() => _counts[c.key] = ((res['up'] as num?)?.toInt() ?? 0, (res['down'] as num?)?.toInt() ?? 0));
      ref.invalidate(circleTripPlansProvider(widget.circleId));
    } catch (e) {
      if (!mounted) return;
      setState(() => previous == null ? _myVotes.remove(c.key) : _myVotes[c.key] = previous);
      _showError(e);
    }
  }

  Future<void> _finalize(TribeTripPlan plan) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VoyagoColors.surface,
        title: const Text('Clore le vote ?', style: TextStyle(color: VoyagoColors.text)),
        content: Text(
          "L'itinéraire de ${plan.durationDays} jour${plan.durationDays > 1 ? 's' : ''} gardera les lieux préférés "
          'de la tribu (${plan.votersCount} votant${plan.votersCount > 1 ? 's' : ''}). Le vote ne pourra plus changer.',
          style: const TextStyle(color: VoyagoColors.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Finaliser')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref.read(communityApiProvider).finalizeTripPlan(widget.planId);
      ref.invalidate(tripPlanProvider(widget.planId));
      ref.invalidate(circleTripPlansProvider(widget.circleId));
    } catch (e) {
      if (mounted) _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _join(TribeTripPlan plan) async {
    DateTime? startDate;
    if (plan.startDate == null) {
      final now = DateTime.now();
      startDate = await showDatePicker(
        context: context,
        helpText: 'Ta date de départ (facultative)',
        initialDate: now.add(const Duration(days: 14)),
        firstDate: now,
        lastDate: now.add(const Duration(days: 365 * 2)),
      );
      if (!mounted) return;
    }
    setState(() => _busy = true);
    try {
      final trip = await ref
          .read(communityApiProvider)
          .joinTripPlan(widget.planId, startDate: startDate != null ? apiDate(startDate) : null);
      ref.invalidate(tripsProvider);
      ref.invalidate(tripPlanProvider(widget.planId));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: VoyagoColors.primary, content: Text('🧭 ${plan.destination} ajouté à tes voyages !')),
      );
      context.go('/itinerary/${trip.id}', extra: trip);
    } on ApiException catch (e) {
      if (!mounted) return;
      final isQuota = e.statusCode == 402;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: isQuota ? VoyagoColors.orange : VoyagoColors.coral,
          content: Text(e.message),
          action: isQuota ? SnackBarAction(label: 'Passer Pro', onPressed: () => context.go('/pricing')) : null,
        ),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final planAsync = ref.watch(tripPlanProvider(widget.planId));
    return Scaffold(
      backgroundColor: VoyagoColors.background,
      appBar: AppBar(
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: _back),
        title: Text(planAsync.valueOrNull?.destination ?? 'Voyage de tribu'),
      ),
      body: planAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: VoyagoColors.primary)),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(
              e is ApiException ? e.message : 'Impossible de charger ce voyage de tribu',
              textAlign: TextAlign.center,
              style: const TextStyle(color: VoyagoColors.muted),
            ),
          ),
        ),
        data: (plan) => RefreshIndicator(
          color: VoyagoColors.primary,
          onRefresh: () async {
            _myVotes.clear();
            _counts.clear();
            return ref.refresh(tripPlanProvider(widget.planId).future);
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
            children: [
              _buildHeader(plan),
              const SizedBox(height: 16),
              if (plan.isVoting) ...[
                _buildDeck(plan),
                const SizedBox(height: 20),
                _buildRanking(plan),
                if (plan.canFinalize) ...[
                  const SizedBox(height: 16),
                  ElevatedButton.icon(
                    onPressed: _busy ? null : () => _finalize(plan),
                    icon: const Icon(Icons.flag_rounded, color: Colors.white),
                    label: const Text('Clore le vote et créer l\'itinéraire', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VoyagoColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ],
              ] else
                _buildItinerary(plan),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(TribeTripPlan plan) {
    final status = plan.isVoting ? '🗳️ Vote en cours' : '🎉 Itinéraire prêt';
    return Text(
      '$status • ${plan.durationDays} jour${plan.durationDays > 1 ? 's' : ''} • '
      '${plan.votersCount} votant${plan.votersCount > 1 ? 's' : ''}\nProposé par ${plan.creatorName}',
      style: const TextStyle(color: VoyagoColors.muted, fontSize: 13, height: 1.4),
    );
  }

  // --- Swipe : un lieu à la fois, glisser à droite = 👍, à gauche = 👎 ---
  Widget _buildDeck(TribeTripPlan plan) {
    final remaining = plan.candidates.where((c) => _voteOf(c) == null).toList();
    if (remaining.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: VoyagoColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: VoyagoColors.primary.withValues(alpha: 0.4)),
        ),
        child: const Text(
          "🎉 Tu as voté pour tous les lieux !\nTu peux encore changer d'avis dans le classement ci-dessous.",
          textAlign: TextAlign.center,
          style: TextStyle(color: VoyagoColors.text, height: 1.4),
        ),
      );
    }

    final current = remaining.first;
    final votedCount = plan.candidates.length - remaining.length;
    return Column(
      children: [
        Text(
          'Lieu ${votedCount + 1} sur ${plan.candidates.length} • glisse à droite si tu veux y aller',
          style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
        ),
        const SizedBox(height: 8),
        Dismissible(
          key: ValueKey('deck-${current.key}'),
          onDismissed: (dir) => _vote(current, dir == DismissDirection.startToEnd ? 'up' : 'down'),
          background: _swipeHint('👍 J\'y vais', VoyagoColors.primary, Alignment.centerLeft),
          secondaryBackground: _swipeHint('👎 Bof', VoyagoColors.coral, Alignment.centerRight),
          child: _PlaceCard(poi: current.poi),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _RoundVoteButton(icon: Icons.thumb_down_rounded, color: VoyagoColors.coral, onTap: () => _vote(current, 'down')),
            const SizedBox(width: 32),
            _RoundVoteButton(icon: Icons.thumb_up_rounded, color: VoyagoColors.primary, onTap: () => _vote(current, 'up')),
          ],
        ),
      ],
    );
  }

  Widget _swipeHint(String label, Color color, Alignment alignment) {
    return Container(
      alignment: alignment,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(20)),
      child: Text(label, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildRanking(TribeTripPlan plan) {
    final ranked = [...plan.candidates]
      ..sort((a, b) {
        final (aUp, aDown) = _countsOf(a);
        final (bUp, bDown) = _countsOf(b);
        return (bUp - bDown) - (aUp - aDown);
      });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '🏆 Classement de la tribu',
          style: TextStyle(color: VoyagoColors.text, fontSize: 16, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 8),
        for (final c in ranked)
          Builder(builder: (context) {
            final (up, down) = _countsOf(c);
            final vote = _voteOf(c);
            return ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(c.poi.name, style: const TextStyle(color: VoyagoColors.text, fontSize: 14)),
              subtitle: Text('👍 $up   👎 $down', style: const TextStyle(color: VoyagoColors.muted, fontSize: 12)),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: Icon(Icons.thumb_down_rounded,
                        color: vote == 'down' ? VoyagoColors.coral : VoyagoColors.cardBorder),
                    onPressed: () => _vote(c, 'down'),
                  ),
                  IconButton(
                    icon: Icon(Icons.thumb_up_rounded,
                        color: vote == 'up' ? VoyagoColors.primary : VoyagoColors.cardBorder),
                    onPressed: () => _vote(c, 'up'),
                  ),
                ],
              ),
            );
          }),
      ],
    );
  }

  Widget _buildItinerary(TribeTripPlan plan) {
    final byDay = <int, List<POI>>{};
    for (final p in plan.finalPois) {
      byDay.putIfAbsent(p.day, () => []).add(p);
    }
    final days = byDay.keys.toList()..sort();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (plan.joinedByMe)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Text('✅ Ce voyage est dans tes voyages', style: TextStyle(color: VoyagoColors.primary)),
          )
        else
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: ElevatedButton.icon(
              onPressed: _busy ? null : () => _join(plan),
              icon: const Icon(Icons.add_location_alt_rounded, color: Colors.white),
              label: const Text('Ajouter à mes voyages', style: TextStyle(color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: VoyagoColors.primary,
                padding: const EdgeInsets.symmetric(vertical: 14),
                minimumSize: const Size.fromHeight(48),
              ),
            ),
          ),
        if (plan.joinedCount > 0)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              '${plan.joinedCount} membre${plan.joinedCount > 1 ? 's partent' : ' part'} avec ce voyage',
              style: const TextStyle(color: VoyagoColors.muted, fontSize: 13),
            ),
          ),
        for (final day in days) ...[
          Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 6),
            child: Text(
              'Jour $day',
              style: const TextStyle(color: VoyagoColors.yellow, fontSize: 15, fontWeight: FontWeight.bold),
            ),
          ),
          for (final p in byDay[day]!)
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 52,
                  height: 52,
                  child: p.imageUrl != null && p.imageUrl!.isNotEmpty
                      ? CachedNetworkImage(imageUrl: p.imageUrl!, fit: BoxFit.cover)
                      : Container(color: VoyagoColors.cardBorder),
                ),
              ),
              title: Text(p.name, style: const TextStyle(color: VoyagoColors.text, fontSize: 14)),
              subtitle: Text(
                p.description,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
              ),
            ),
        ],
      ],
    );
  }
}

class _PlaceCard extends StatelessWidget {
  final POI poi;

  const _PlaceCard({required this.poi});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 360,
      decoration: BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VoyagoColors.cardBorder),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        fit: StackFit.expand,
        children: [
          if (poi.imageUrl != null && poi.imageUrl!.isNotEmpty)
            CachedNetworkImage(
              imageUrl: poi.imageUrl!,
              fit: BoxFit.cover,
              errorWidget: (_, __, ___) => Container(color: VoyagoColors.cardBorder),
            )
          else
            Container(color: VoyagoColors.cardBorder),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.center,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xEE000000)],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (poi.category.isNotEmpty)
                  Text(poi.category.toUpperCase(),
                      style: const TextStyle(color: VoyagoColors.yellow, fontSize: 11, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(poi.name,
                    style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text(
                  poi.description,
                  maxLines: 4,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white70, fontSize: 13, height: 1.35),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RoundVoteButton extends StatelessWidget {
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _RoundVoteButton({required this.icon, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: color.withValues(alpha: 0.15),
          border: Border.all(color: color, width: 2),
        ),
        child: Icon(icon, color: color, size: 28),
      ),
    );
  }
}
