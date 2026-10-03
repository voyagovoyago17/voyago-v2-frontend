import 'package:flutter/material.dart';
import '../theme.dart';

class ProTierCard extends StatelessWidget {
  final Map<String, dynamic> tier;
  final bool isBestOffer;
  final bool isLoading;
  final VoidCallback onSelect;

  const ProTierCard({
    super.key,
    required this.tier,
    required this.onSelect,
    this.isBestOffer = false,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    final name = tier['name']?.toString() ?? '';
    final price = tier['price']?.toString() ?? '';
    final currency = tier['currency']?.toString() ?? '€';
    final period = tier['period']?.toString() ?? '';
    final benefits = tier['benefits'] as List? ?? [];
    final tagline = tier['tagline']?.toString();
    final quota = tier['edit_quota'] as Map?;
    final redos = (quota?['redos'] as num?)?.toInt();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: VoyagoColors.surface,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: isBestOffer ? VoyagoColors.primary : VoyagoColors.cardBorder,
              width: isBestOffer ? 2 : 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  children: [
                    const Text('💎', style: TextStyle(fontSize: 24)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            name,
                            style: const TextStyle(
                              color: VoyagoColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          if (period.isNotEmpty)
                            Text(
                              period,
                              style: const TextStyle(
                                color: VoyagoColors.muted,
                                fontSize: 13,
                              ),
                            ),
                        ],
                      ),
                    ),
                    // Price
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                text: price,
                                style: const TextStyle(
                                  color: VoyagoColors.primary,
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              TextSpan(
                                text: currency,
                                style: const TextStyle(
                                  color: VoyagoColors.muted,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (period.isNotEmpty)
                          Text(
                            '/ $period',
                            style: const TextStyle(
                              color: VoyagoColors.muted,
                              fontSize: 11,
                            ),
                          ),
                      ],
                    ),
                  ],
                ),

                if (tagline != null && tagline.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    tagline,
                    style: TextStyle(
                      color: isBestOffer ? VoyagoColors.primaryLight : VoyagoColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (redos != null) ...[
                  const SizedBox(height: 12),
                  // L'essentiel en un coup d'œil : modifications par voyage
                  Row(
                    children: [
                      _QuotaPill(value: '$redos', label: 'journées refaites\npar voyage'),
                      const SizedBox(width: 8),
                      const _QuotaPill(value: '∞', label: 'lieux\nremplacés'),
                      const SizedBox(width: 8),
                      const _QuotaPill(value: '☔', label: 'plan B\npluie'),
                    ],
                  ),
                ],
                if (benefits.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Divider(),
                  const SizedBox(height: 12),
                  ...benefits.map(
                    (b) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        children: [
                          const Text(
                            '✓',
                            style: TextStyle(
                              color: VoyagoColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              b.toString(),
                              style: const TextStyle(
                                color: VoyagoColors.text,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: isLoading ? null : onSelect,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isBestOffer
                          ? VoyagoColors.primary
                          : VoyagoColors.surface,
                      foregroundColor: isBestOffer
                          ? Colors.white
                          : VoyagoColors.primary,
                      side: isBestOffer
                          ? null
                          : const BorderSide(color: VoyagoColors.primary, width: 2),
                    ),
                    child: isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Text('Choisir ce plan'),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Best offer badge
        if (isBestOffer || tier['savings_percent'] != null)
          Positioned(
            top: 0,
            left: 32,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: VoyagoColors.yellow,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                tier['savings_percent'] != null
                    ? '⭐ Meilleure offre · −${tier['savings_percent']} %'
                    : '⭐ Meilleure offre',
                style: TextStyle(
                  color: Colors.black,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _QuotaPill extends StatelessWidget {
  final String value;
  final String label;

  const _QuotaPill({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
        decoration: BoxDecoration(
          color: VoyagoColors.primary.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: VoyagoColors.primary.withValues(alpha: 0.25)),
        ),
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: VoyagoColors.primary, fontSize: 18, fontWeight: FontWeight.w900)),
            const SizedBox(height: 2),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(color: VoyagoColors.muted, fontSize: 10.5, height: 1.2),
            ),
          ],
        ),
      ),
    );
  }
}
