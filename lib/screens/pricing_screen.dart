import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../services/api_service.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/pro_tier_card.dart';
import '../widgets/free_plan_card.dart';

class PricingScreen extends ConsumerStatefulWidget {
  const PricingScreen({super.key});

  @override
  ConsumerState<PricingScreen> createState() => _PricingScreenState();
}

class _PricingScreenState extends ConsumerState<PricingScreen> {
  bool _isLoadingTiers = true;
  List<Map<String, dynamic>> _tiers = [];
  Map<String, dynamic> _freePlan = FreePlanCard.fallback;
  String? _loadingTierId;
  String? _error;
  String? _checkoutStatus; // 'success', 'pending', 'cancelled'
  Timer? _pollTimer;
  int _pollCount = 0;

  // Fallback tiers if API fails
  static const List<Map<String, dynamic>> _defaultTiers = [
    {
      'id': 'monthly',
      'name': 'Mensuel',
      'price': '4.99',
      'currency': '€',
      'period': 'mois',
      'tagline': 'Pour un voyage qui arrive bientôt',
      'benefits': [
        'Voyages illimités',
        '2 journées refaites par voyage (IA, lieux vérifiés)',
        'Lieux remplacés à volonté',
        'Dates décalées sans limite avant le départ',
        'Plan B pluie en un geste',
        'Météo étendue 16 jours',
        'Badge Pro 💎',
      ],
      'edit_quota': {'redos': 2},
      'is_best': false,
    },
    {
      'id': 'annual',
      'name': 'Annuel',
      'price': '39.99',
      'currency': '€',
      'period': 'an',
      'tagline': 'Le meilleur rapport : −33 % vs mensuel',
      'savings_percent': 33,
      'benefits': [
        'Voyages illimités toute l’année',
        '4 journées refaites par voyage (IA, lieux vérifiés)',
        'Lieux remplacés à volonté',
        'Dates décalées sans limite avant le départ',
        'Plan B pluie en un geste',
        'Météo étendue 16 jours',
        'Badge Pro 💎 et accès anticipé',
        '4 mois offerts par rapport au mensuel',
      ],
      'edit_quota': {'redos': 4},
      'is_best': true,
    },
    {
      'id': 'lifetime',
      'name': 'À vie',
      'price': '79.99',
      'currency': '€',
      'period': '',
      'tagline': 'Un seul paiement, pour toujours',
      'benefits': [
        'Voyages illimités, pour toujours',
        '6 journées refaites par voyage (IA, lieux vérifiés)',
        'Lieux remplacés à volonté',
        'Dates décalées sans limite avant le départ',
        'Plan B pluie en un geste',
        'Météo étendue 16 jours',
        'Badge Pro 💎, accès anticipé',
        'Toutes les futures fonctionnalités',
      ],
      'edit_quota': {'redos': 6},
      'is_best': false,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadTiers();
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadTiers() async {
    ApiService.instance.getFreePlan().then((plan) {
      if (mounted && (plan['included'] as List?)?.isNotEmpty == true) setState(() => _freePlan = plan);
    }).catchError((_) {});
    try {
      final tiers = await ApiService.instance.getProTiers();
      if (mounted) {
        setState(() {
          _tiers = tiers.isNotEmpty ? tiers : _defaultTiers;
          _isLoadingTiers = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _tiers = _defaultTiers;
          _isLoadingTiers = false;
        });
      }
    }
  }

  Future<void> _selectTier(String tierId) async {
    setState(() {
      _loadingTierId = tierId;
      _error = null;
    });

    try {
      final result = await ApiService.instance.createCheckout(tierId);
      final checkoutUrl = result['checkout_url']?.toString() ?? '';
      final sessionId = result['session_id']?.toString() ?? '';

      if (checkoutUrl.isNotEmpty) {
        final uri = Uri.parse(checkoutUrl);
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
          // Start polling for status
          if (sessionId.isNotEmpty) {
            _startPolling(sessionId);
          }
        } else {
          if (mounted) setState(() => _error = 'Impossible d\'ouvrir la page de paiement');
        }
      } else {
        if (mounted) setState(() => _error = 'URL de paiement invalide');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Erreur lors de la création du paiement');
    } finally {
      if (mounted) setState(() => _loadingTierId = null);
    }
  }

  void _startPolling(String sessionId) {
    _pollCount = 0;
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      _pollCount++;
      if (_pollCount > 10) {
        timer.cancel();
        if (mounted) setState(() => _checkoutStatus = 'pending');
        return;
      }

      try {
        final status = await ApiService.instance.getProStatus(sessionId);
        final statusStr = status['status']?.toString() ?? '';

        if (statusStr == 'complete' || statusStr == 'success') {
          timer.cancel();
          if (mounted) {
            setState(() => _checkoutStatus = 'success');
            // Refresh auth state to get new pro status
            await ref.read(authProvider.notifier).loadSession();
          }
        } else if (statusStr == 'cancelled' || statusStr == 'canceled') {
          timer.cancel();
          if (mounted) setState(() => _checkoutStatus = 'cancelled');
        }
      } catch (_) {
        // Keep polling
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VoyagoColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('💎', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Voyagooo Pro'),
          ],
        ),
      ),
      body: _checkoutStatus != null
          ? _buildStatusScreen()
          : _buildPricingContent(),
    );
  }

  Widget _buildStatusScreen() {
    final isSuccess = _checkoutStatus == 'success';
    final isPending = _checkoutStatus == 'pending';

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              isSuccess ? '🎉' : isPending ? '⏳' : '😔',
              style: const TextStyle(fontSize: 64),
            ),
            const SizedBox(height: 20),
            Text(
              isSuccess
                  ? 'Paiement réussi !'
                  : isPending
                      ? 'Paiement en attente'
                      : 'Paiement annulé',
              style: const TextStyle(
                color: VoyagoColors.text,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              isSuccess
                  ? 'Bienvenue dans Voyagooo Pro ! Profitez de tous les avantages premium.'
                  : isPending
                      ? 'Votre paiement est en cours de traitement. Nous vous contacterons par email.'
                      : 'Votre paiement a été annulé. Vous pouvez réessayer quand vous le souhaitez.',
              style: const TextStyle(color: VoyagoColors.muted, fontSize: 15),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => context.go('/'),
                child: const Text('Retour à l\'accueil'),
              ),
            ),
            if (!isSuccess) ...[
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => setState(() => _checkoutStatus = null),
                child: const Text('Voir les offres'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPricingContent() {
    return SingleChildScrollView(
      child: Column(
        children: [
          // Hero
          Container(
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 28),
            child: Column(
              children: [
                const Text('💎', style: TextStyle(fontSize: 56)),
                const SizedBox(height: 16),
                const Text(
                  'Passez à Voyagooo Pro',
                  style: TextStyle(
                    color: VoyagoColors.text,
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 8),
                const Text(
                  'Voyages illimités, itinéraires modifiables à volonté et plan B pluie : ton voyage s’adapte à toi.',
                  style: TextStyle(color: VoyagoColors.muted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VoyagoColors.coral.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: VoyagoColors.coral.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: VoyagoColors.coral, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: VoyagoColors.coral, fontSize: 13),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: VoyagoColors.muted, size: 18),
                      onPressed: () => setState(() => _error = null),
                      constraints: const BoxConstraints(),
                      padding: EdgeInsets.zero,
                    ),
                  ],
                ),
              ),
            ),

          const SizedBox(height: 8),

          if (_isLoadingTiers)
            const Padding(
              padding: EdgeInsets.all(40),
              child: CircularProgressIndicator(color: VoyagoColors.primary),
            )
          else
            ..._tiers.asMap().entries.map((entry) {
              final tier = entry.value;
              final isBest = tier['is_best'] == true;
              return ProTierCard(
                tier: tier,
                isBestOffer: isBest,
                isLoading: _loadingTierId == tier['id'],
                onSelect: () => _selectTier(tier['id'].toString()),
              );
            }),

          // Formule gratuite : ce qui est inclus et ce qui manque
          if (!_isLoadingTiers)
            FreePlanCard(
              plan: _freePlan,
              isCurrent: !(ref.watch(authProvider).user?.isProActive ?? false),
            ),

          const SizedBox(height: 24),

          // Benefits summary
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: VoyagoColors.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: VoyagoColors.cardBorder),
              ),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Pourquoi Pro ?',
                    style: TextStyle(
                      color: VoyagoColors.text,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 12),
                  _BenefitRow(emoji: '🗺', text: 'Voyages illimités, lieux réels vérifiés'),
                  _BenefitRow(emoji: '✨', text: 'Refais une journée ou tout le voyage (2, 4 ou 6 fois par voyage)'),
                  _BenefitRow(emoji: '🔁', text: 'Remplace les lieux à volonté'),
                  _BenefitRow(emoji: '📅', text: 'Décale tes dates sans limite avant le départ'),
                  _BenefitRow(emoji: '☔', text: 'Plan B pluie : ta journée à l’abri en un geste'),
                  _BenefitRow(emoji: '🗳️', text: 'Planifie des voyages avec ta tribu'),
                  _BenefitRow(emoji: '🔒', text: 'Paiement sécurisé via Stripe'),
                ],
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final String emoji;
  final String text;

  const _BenefitRow({required this.emoji, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: VoyagoColors.text, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }
}
