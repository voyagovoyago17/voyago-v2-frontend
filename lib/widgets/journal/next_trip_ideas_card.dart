import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/journal.dart';
import '../../providers/journal_provider.dart';
import '../../theme.dart';

/// « Et maintenant ? » : 3 idées de prochain voyage inspirées de celui-ci.
/// Un tap ouvre la création de voyage avec la destination déjà remplie.
class NextTripIdeasCard extends ConsumerWidget {
  final String tripId;
  final String destination;

  const NextTripIdeasCard({super.key, required this.tripId, required this.destination});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(journalNextIdeasProvider(tripId));
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [VoyagoColors.primary.withValues(alpha: 0.12), VoyagoColors.surface],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: VoyagoColors.primary.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset('assets/icons3d/world_map.png', width: 42, height: 42),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Et maintenant ?',
                        style: TextStyle(color: VoyagoColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
                    Text('Inspiré de ce que tu as aimé à $destination',
                        style: const TextStyle(color: VoyagoColors.muted, fontSize: 12.5)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          async.when(
            loading: () => const _IdeasLoading(),
            error: (_, __) => _Fallback(onTap: () => context.go('/swipe')),
            data: (ideas) => ideas.isEmpty
                ? _Fallback(onTap: () => context.go('/swipe'))
                : Column(
                    children: [
                      for (var i = 0; i < ideas.length; i++)
                        TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: 1),
                          duration: Duration(milliseconds: 380 + i * 140),
                          curve: Curves.easeOutCubic,
                          builder: (_, t, child) => Opacity(
                            opacity: t,
                            child: Transform.translate(offset: Offset(0, 14 * (1 - t)), child: child),
                          ),
                          child: _IdeaTile(idea: ideas[i]),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _IdeaTile extends StatelessWidget {
  final NextTripIdea idea;

  const _IdeaTile({required this.idea});

  Color get _color => switch (idea.kind) {
        'meme_esprit' => VoyagoColors.primary,
        'pas_loin' => VoyagoColors.blue,
        _ => VoyagoColors.yellow,
      };

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: VoyagoColors.background,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => context.go('/configure', extra: {'destination': idea.fullName, 'interests': idea.interests}),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Container(
                  width: 50,
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: _color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(14)),
                  child: Text(idea.emoji, style: const TextStyle(fontSize: 26)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(idea.fullName,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: VoyagoColors.text, fontSize: 14.5, fontWeight: FontWeight.w800)),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                            decoration: BoxDecoration(color: _color.withValues(alpha: 0.16), borderRadius: BorderRadius.circular(6)),
                            child: Text(idea.kindLabel,
                                style: TextStyle(color: _color, fontSize: 9.5, fontWeight: FontWeight.w800)),
                          ),
                        ],
                      ),
                      if (idea.pitch.isNotEmpty)
                        Text(idea.pitch,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: VoyagoColors.muted, fontSize: 12, height: 1.35)),
                      const SizedBox(height: 2),
                      Text(
                        [
                          '${idea.durationDays} jours',
                          if (idea.bestSeason.isNotEmpty) 'idéal ${idea.bestSeason}',
                        ].join(' · '),
                        style: TextStyle(color: _color, fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: VoyagoColors.muted),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _IdeasLoading extends StatelessWidget {
  const _IdeasLoading();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        for (var i = 0; i < 3; i++)
          Container(
            height: 74,
            margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: VoyagoColors.background, borderRadius: BorderRadius.circular(18)),
            child: Row(
              children: [
                const SizedBox(width: 12),
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(color: VoyagoColors.cardBorder, borderRadius: BorderRadius.circular(14)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text('Voyagooo cherche ta prochaine aventure…',
                      style: TextStyle(color: VoyagoColors.muted, fontSize: 12.5)),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

class _Fallback extends StatelessWidget {
  final VoidCallback onTap;

  const _Fallback({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        onPressed: onTap,
        icon: Image.asset('assets/icons3d/departure.png', width: 20),
        label: const Text('Planifier mon prochain voyage', style: TextStyle(fontWeight: FontWeight.w800)),
        style: ElevatedButton.styleFrom(
          backgroundColor: VoyagoColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 13),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
      ),
    );
  }
}
