import 'package:flutter/material.dart';
import '../theme.dart';

/// Carte « Gratuit » : ce qui est inclus et ce qui manque, pour comparer avec Pro.
class FreePlanCard extends StatelessWidget {
  final Map<String, dynamic> plan;

  /// Le voyageur est actuellement en gratuit
  final bool isCurrent;

  const FreePlanCard({super.key, required this.plan, this.isCurrent = false});

  /// Repli si le serveur ne répond pas (mêmes règles que le serveur)
  static const Map<String, dynamic> fallback = {
    'name': 'Gratuit',
    'included': [
      '2 voyages créés par mois',
      'Itinéraire IA avec lieux réels vérifiés',
      'Pépites à collectionner, XP et badges',
      'Journal, réservations et budget',
      'Annuler un voyage à tout moment (il rejoint tes idées)',
      'Décaler les dates 1 fois par voyage',
      'Remplacer 2 lieux par voyage',
      '1 journée refaite offerte (une seule fois)',
      '1 modification par voyage contre 25 Éclats (pépites ramassées)',
      'Pépite légendaire ramassée : 1 plan B pluie offert',
    ],
    'missing': [
      'Voyages illimités',
      'Journées refaites à chaque voyage (2, 4 ou 6 selon la formule)',
      'Lieux remplacés à volonté',
      'Dates décalées sans limite',
      'Plan B pluie à chaque averse',
      'Jusqu’à 3 modifications par voyage avec tes Éclats',
      'Météo étendue 16 jours',
      'Planifier un voyage de tribu',
      'Badge Pro 💎',
    ],
  };

  @override
  Widget build(BuildContext context) {
    final included = (plan['included'] as List? ?? const []).map((e) => e.toString()).toList();
    final missing = (plan['missing'] as List? ?? const []).map((e) => e.toString()).toList();

    Widget row(String text, {required bool ok}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                ok ? Icons.check_rounded : Icons.lock_outline_rounded,
                size: 17,
                color: ok ? VoyagoColors.primary : VoyagoColors.muted,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  text,
                  style: TextStyle(color: ok ? VoyagoColors.text : VoyagoColors.muted, fontSize: 13.5, height: 1.3),
                ),
              ),
            ],
          ),
        );

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(22),
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
              const Text('🎒', style: TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  plan['name']?.toString() ?? 'Gratuit',
                  style: const TextStyle(color: VoyagoColors.text, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              const Text('0 €',
                  style: TextStyle(color: VoyagoColors.muted, fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
          if (isCurrent) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(
                color: VoyagoColors.muted.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Ta formule actuelle',
                  style: TextStyle(color: VoyagoColors.muted, fontSize: 11.5, fontWeight: FontWeight.w800)),
            ),
          ],
          const SizedBox(height: 14),
          const Text('CE À QUOI TU AS DROIT',
              style: TextStyle(color: VoyagoColors.primary, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
          const SizedBox(height: 6),
          for (final t in included) row(t, ok: true),
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 14),
            const Divider(),
            const SizedBox(height: 8),
            const Text('CE QUE TU RATES SANS PRO',
                style: TextStyle(color: VoyagoColors.orange, fontSize: 11, fontWeight: FontWeight.w900, letterSpacing: 0.6)),
            const SizedBox(height: 6),
            for (final t in missing) row(t, ok: false),
          ],
        ],
      ),
    );
  }
}
