import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../providers/trips_provider.dart';
import '../widgets/community/social_actions.dart';
import '../services/api_service.dart';
import '../theme.dart';
import '../widgets/trip_card.dart';
import '../widgets/badge_grid.dart';
import '../widgets/xp_progress_bar.dart';

class PublicUserScreen extends ConsumerStatefulWidget {
  final String userId;

  const PublicUserScreen({super.key, required this.userId});

  @override
  ConsumerState<PublicUserScreen> createState() => _PublicUserScreenState();
}

class _PublicUserScreenState extends ConsumerState<PublicUserScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _userData;
  String? _error;
  List<Map<String, dynamic>> _allBadges = [];

  @override
  void initState() {
    super.initState();
    _loadUser();
    _loadBadges();
  }

  Future<void> _loadUser() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final data = await ApiService.instance.getPublicUser(widget.userId);
      if (mounted) setState(() => _userData = data);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Utilisateur introuvable');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _loadBadges() async {
    try {
      final badges = await ApiService.instance.getBadges();
      if (mounted) setState(() => _allBadges = badges);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VoyagoColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/community');
            }
          },
        ),
        title: Text(_userData?['name']?.toString() ?? 'Profil'),
        actions: [
          if (ref.watch(currentUserProvider) != null && ref.watch(currentUserProvider)?.userId != widget.userId)
            PopupMenuButton<String>(
              color: VoyagoColors.surface,
              onSelected: (_) async {
                final blocked = await confirmBlockUser(
                  context,
                  ref,
                  userId: widget.userId,
                  name: _userData?['pseudo']?.toString() ?? _userData?['name']?.toString() ?? 'ce voyageur',
                );
                if (blocked && context.mounted) {
                  context.canPop() ? context.pop() : context.go('/community');
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(
                  value: 'block',
                  child: Text('Bloquer', style: TextStyle(color: VoyagoColors.coral)),
                ),
              ],
            ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: VoyagoColors.primary))
          : _error != null
              ? _buildError()
              : _buildContent(),
    );
  }

  Widget _buildError() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('😕', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: const TextStyle(color: VoyagoColors.muted),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _loadUser,
              child: const Text('Réessayer'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent() {
    final data = _userData!;
    final name = data['name']?.toString() ?? 'Voyageur';
    final pseudo = data['pseudo']?.toString();
    final avatarEmoji = data['avatar_emoji']?.toString() ?? '🦜';
    final xp = (data['xp'] as num?)?.toInt() ?? 0;
    final level = (data['level'] as num?)?.toInt() ?? 1;
    final isPro = data['is_pro'] as bool? ?? false;
    final proTier = data['pro_tier']?.toString();
    final badges = (data['badges'] as List? ?? []).map((e) => e.toString()).toList();
    final tripsAsync = ref.watch(tripsProvider(widget.userId));

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(28),
            child: Column(
              children: [
                Text(avatarEmoji, style: const TextStyle(fontSize: 72)),
                const SizedBox(height: 12),
                Text(
                  name,
                  style: const TextStyle(
                    color: VoyagoColors.text,
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (pseudo != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '@$pseudo',
                    style: const TextStyle(color: VoyagoColors.muted, fontSize: 14),
                  ),
                ],
                if (isPro) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
                    decoration: BoxDecoration(
                      color: VoyagoColors.blue.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: VoyagoColors.blue.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Text('💎', style: TextStyle(fontSize: 14)),
                        const SizedBox(width: 6),
                        Text(
                          'Voyagooo Pro${proTier != null ? ' · $proTier' : ''}',
                          style: const TextStyle(
                            color: VoyagoColors.blue,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),

          // XP bar
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: XpProgressBar(xp: xp, level: level, streak: 0),
          ),
          const SizedBox(height: 24),

          // Badges
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Badges',
              style: TextStyle(
                color: VoyagoColors.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          BadgeGrid(earnedBadges: badges, allBadges: _allBadges),
          const SizedBox(height: 24),

          // Trips
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Voyages',
              style: TextStyle(
                color: VoyagoColors.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(height: 8),
          tripsAsync.when(
            data: (trips) {
              if (trips.isEmpty) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(
                    child: Text(
                      'Aucun voyage public',
                      style: TextStyle(color: VoyagoColors.muted),
                    ),
                  ),
                );
              }
              return Column(
                children: trips
                    .map((t) => TripCard(
                          trip: t,
                          onTap: () => context.go('/itinerary/${t.id}', extra: t),
                        ))
                    .toList(),
              );
            },
            loading: () => const Padding(
              padding: EdgeInsets.all(16),
              child: LinearProgressIndicator(),
            ),
            error: (e, _) => Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Impossible de charger les voyages',
                style: const TextStyle(color: VoyagoColors.muted),
              ),
            ),
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
