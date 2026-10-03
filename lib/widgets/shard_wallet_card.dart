import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/trips_provider.dart';
import '../theme.dart';

/// Bourse d'Éclats 💎 : gagnés en ramassant des pépites, échangeables contre des
/// modifications de voyage. Indépendante des XP (le niveau ne baisse jamais).
class ShardWalletCard extends ConsumerWidget {
  const ShardWalletCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final wallet = ref.watch(shardWalletProvider).valueOrNull;
    if (wallet == null) return const SizedBox.shrink();
    final toNext = wallet.perCredit - (wallet.balance % wallet.perCredit);
    final credits = wallet.balance ~/ wallet.perCredit;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VoyagoColors.blue.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: VoyagoColors.blue.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('💎', style: TextStyle(fontSize: 26)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${wallet.balance} Éclats',
                        style: const TextStyle(color: VoyagoColors.text, fontSize: 18, fontWeight: FontWeight.w900)),
                    Text(
                      '${wallet.gemsCollected} pépite${wallet.gemsCollected > 1 ? 's' : ''} ramassée${wallet.gemsCollected > 1 ? 's' : ''}'
                      '${wallet.perfectDays > 0 ? ' · ${wallet.perfectDays} journée${wallet.perfectDays > 1 ? 's' : ''} parfaite${wallet.perfectDays > 1 ? 's' : ''}' : ''}',
                      style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
                    ),
                  ],
                ),
              ),
              if (credits > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: VoyagoColors.blue, borderRadius: BorderRadius.circular(10)),
                  child: Text('$credits modif${credits > 1 ? 's' : ''}',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w800)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: (wallet.balance % wallet.perCredit) / wallet.perCredit,
              minHeight: 6,
              backgroundColor: VoyagoColors.cardBorder,
              color: VoyagoColors.blue,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Encore $toNext Éclats pour une modification de voyage. Ramasse des pépites pendant tes voyages : '
            'tes XP et ton niveau ne bougent pas quand tu échanges.',
            style: const TextStyle(color: VoyagoColors.muted, fontSize: 11.5, height: 1.35),
          ),
        ],
      ),
    );
  }
}
