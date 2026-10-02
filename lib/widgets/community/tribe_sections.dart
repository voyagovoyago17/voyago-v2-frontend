import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../api/api_exceptions.dart';
import '../../models/community_circle.dart';
import '../../models/tribe.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../theme.dart';

/// Date au format attendu par l'API (AAAA-MM-JJ).
String apiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

// =========================================================================
// DÉFIS DU MOIS
// =========================================================================

class TribeChallengesCard extends ConsumerWidget {
  final String circleId;

  const TribeChallengesCard({super.key, required this.circleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final challengesAsync = ref.watch(circleChallengesProvider(circleId));
    return challengesAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data.challenges.isEmpty) return const SizedBox.shrink();
        final done = data.challenges.where((c) => c.completed).length;
        final daysLeft = data.endsAt?.difference(DateTime.now()).inDays;
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VoyagoColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: VoyagoColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Text('🎯', style: TextStyle(fontSize: 18)),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'Défis du mois',
                      style: TextStyle(color: VoyagoColors.text, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    '$done/${data.challenges.length} réussis',
                    style: const TextStyle(color: VoyagoColors.primary, fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              if (daysLeft != null) ...[
                const SizedBox(height: 2),
                Text(
                  'Encore ${daysLeft + 1} jour${daysLeft > 0 ? 's' : ''} • 10 XP par défi pour chaque participant',
                  style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
                ),
              ],
              const SizedBox(height: 12),
              for (final c in data.challenges) _ChallengeRow(challenge: c),
            ],
          ),
        );
      },
    );
  }
}

class _ChallengeRow extends StatelessWidget {
  final CircleChallenge challenge;

  const _ChallengeRow({required this.challenge});

  @override
  Widget build(BuildContext context) {
    final color = challenge.completed ? VoyagoColors.primary : VoyagoColors.yellow;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Text(challenge.emoji, style: const TextStyle(fontSize: 20)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        challenge.title,
                        style: const TextStyle(color: VoyagoColors.text, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      challenge.completed ? '✅' : '${challenge.progress}/${challenge.target}',
                      style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: challenge.ratio,
                    minHeight: 6,
                    backgroundColor: VoyagoColors.cardBorder,
                    valueColor: AlwaysStoppedAnimation(color),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  challenge.myContribution > 0
                      ? '${challenge.description} • ta contribution : ${challenge.myContribution}'
                      : challenge.description,
                  style: const TextStyle(color: VoyagoColors.muted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// VOYAGES DE TRIBU
// =========================================================================

class TribeTripsSection extends ConsumerWidget {
  final CommunityCircle circle;

  const TribeTripsSection({super.key, required this.circle});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plansAsync = ref.watch(circleTripPlansProvider(circle.id));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🧭', style: TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'Voyages de tribu',
                style: TextStyle(color: VoyagoColors.text, fontSize: 16, fontWeight: FontWeight.bold),
              ),
            ),
            if (circle.isMember)
              // Réservé aux membres Pro : grisé (avec cadenas) pour les autres
              ref.watch(currentUserProvider)?.isProActive ?? false
                  ? TextButton.icon(
                      onPressed: () => showCreateTripPlanSheet(context, circle),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Planifier', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(foregroundColor: VoyagoColors.primary),
                    )
                  : TextButton.icon(
                      onPressed: () => _showProRequired(context),
                      icon: const Icon(Icons.lock_outline, size: 16),
                      label: const Text('Planifier · Pro', style: TextStyle(fontWeight: FontWeight.bold)),
                      style: TextButton.styleFrom(foregroundColor: VoyagoColors.muted),
                    ),
          ],
        ),
        const SizedBox(height: 4),
        plansAsync.when(
          loading: () => const Padding(
            padding: EdgeInsets.all(12),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2, color: VoyagoColors.primary)),
          ),
          error: (_, __) => const SizedBox.shrink(),
          data: (plans) {
            if (plans.isEmpty) {
              return Text(
                circle.isMember
                        ? "Planifiez un voyage ensemble : l'IA propose des lieux, la tribu vote, l'itinéraire se construit."
                    : 'Rejoins la tribu pour planifier des voyages ensemble.',
                style: const TextStyle(color: VoyagoColors.muted, fontSize: 13),
              );
            }
            return SizedBox(
              height: 150,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: plans.length,
                separatorBuilder: (_, __) => const SizedBox(width: 10),
                itemBuilder: (context, i) => _PlanCard(
                  plan: plans[i],
                  onTap: () => context.push('/circle/${circle.id}/plan/${plans[i].id}'),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

Future<void> _showProRequired(BuildContext context) async {
  final goPro = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: VoyagoColors.surface,
      title: const Text('💎 Réservé aux membres Pro', style: TextStyle(color: VoyagoColors.text)),
      content: const Text(
        "Lancer un voyage de tribu (lieux proposés par l'IA et vote de la tribu) est réservé aux "
        'membres Voyagooo Pro. Tu peux toujours voter et rejoindre les voyages lancés par ta tribu.',
        style: TextStyle(color: VoyagoColors.muted),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Plus tard')),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          style: ElevatedButton.styleFrom(backgroundColor: VoyagoColors.primary),
          child: const Text('Découvrir Pro', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  if (goPro == true && context.mounted) context.go('/pricing');
}

class _PlanCard extends StatelessWidget {
  final TribeTripPlan plan;
  final VoidCallback onTap;

  const _PlanCard({required this.plan, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cover = plan.coverImageUrl;
    final status = plan.isVoting
        ? (plan.toVote.isEmpty ? '✅ Tu as voté' : '🗳️ ${plan.toVote.length} lieux à voter')
        : '🎉 Itinéraire prêt';
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 210,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          color: VoyagoColors.surface,
          border: Border.all(color: plan.isVoting ? VoyagoColors.yellow.withValues(alpha: 0.5) : VoyagoColors.cardBorder),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (cover != null && cover.isNotEmpty)
              CachedNetworkImage(
                imageUrl: cover,
                fit: BoxFit.cover,
                errorWidget: (_, __, ___) => const SizedBox.shrink(),
              ),
            const DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Colors.transparent, Color(0xDD000000)],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    plan.destination,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    '${plan.durationDays} jour${plan.durationDays > 1 ? 's' : ''} • ${plan.votersCount} votant${plan.votersCount > 1 ? 's' : ''}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(status, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// CRÉATION D'UN VOYAGE DE TRIBU
// =========================================================================

Future<void> showCreateTripPlanSheet(BuildContext context, CommunityCircle circle) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: VoyagoColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _CreateTripPlanSheet(circle: circle),
  );
}

class _CreateTripPlanSheet extends ConsumerStatefulWidget {
  final CommunityCircle circle;

  const _CreateTripPlanSheet({required this.circle});

  @override
  ConsumerState<_CreateTripPlanSheet> createState() => _CreateTripPlanSheetState();
}

class _CreateTripPlanSheetState extends ConsumerState<_CreateTripPlanSheet> {
  late final TextEditingController _destinationController;
  int _days = 3;
  String _pace = 'equilibre';
  DateTime? _startDate;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    final c = widget.circle;
    _destinationController = TextEditingController(
      text: c.destinationCity != null && c.destinationCountry != null
          ? '${c.destinationCity}, ${c.destinationCountry}'
          : '',
    );
  }

  @override
  void dispose() {
    _destinationController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _startDate ?? now.add(const Duration(days: 14)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (picked != null && mounted) setState(() => _startDate = picked);
  }

  Future<void> _create() async {
    final destination = _destinationController.text.trim();
    if (destination.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Indique une destination')));
      return;
    }
    setState(() => _creating = true);
    try {
      final plan = await ref.read(communityApiProvider).createTripPlan(
            widget.circle.id,
            destination: destination,
            durationDays: _days,
            pace: _pace,
            startDate: _startDate != null ? apiDate(_startDate!) : null,
          );
      ref.invalidate(circleTripPlansProvider(widget.circle.id));
      if (!mounted) return;
      Navigator.of(context).pop();
      context.push('/circle/${widget.circle.id}/plan/${plan.id}');
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _creating = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20 + MediaQuery.of(context).viewInsets.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '🧭 Planifier un voyage de tribu',
            style: TextStyle(color: VoyagoColors.text, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          const Text(
            "L'IA propose des lieux, chaque membre vote d'un swipe, puis l'itinéraire garde les favoris de la tribu.",
            style: TextStyle(color: VoyagoColors.muted, fontSize: 13),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _destinationController,
            enabled: !_creating,
            style: const TextStyle(color: VoyagoColors.text),
            decoration: const InputDecoration(
              hintText: 'Destination (ex : Lisbonne, Portugal)',
              prefixIcon: Icon(Icons.place_outlined, color: VoyagoColors.primary),
            ),
          ),
          const SizedBox(height: 16),
          const Text('Durée', style: TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (var d = 1; d <= 7; d++)
                ChoiceChip(
                  label: Text('$d j'),
                  selected: _days == d,
                  onSelected: _creating ? null : (_) => setState(() => _days = d),
                ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Rythme', style: TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.bold)),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final p in const [('tranquille', '🚶 Tranquille'), ('equilibre', '🚴 Équilibré'), ('intensif', '🏃 Intensif')])
                ChoiceChip(
                  label: Text(p.$2),
                  selected: _pace == p.$1,
                  onSelected: _creating ? null : (_) => setState(() => _pace = p.$1),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _creating ? null : _pickDate,
            icon: const Icon(Icons.event_outlined),
            label: Text(
              _startDate == null
                  ? 'Date de départ (facultative)'
                  : 'Départ le ${_startDate!.day}/${_startDate!.month}/${_startDate!.year}',
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton(
              onPressed: _creating ? null : _create,
              style: ElevatedButton.styleFrom(
                backgroundColor: VoyagoColors.primary,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _creating
                  ? const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        ),
                        SizedBox(width: 12),
                        Text("L'IA prépare les lieux…", style: TextStyle(color: Colors.white)),
                      ],
                    )
                  : const Text(
                      'Lancer le vote 🗳️',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}
