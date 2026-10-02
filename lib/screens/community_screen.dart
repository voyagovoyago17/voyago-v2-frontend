import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/api_exceptions.dart';
import '../models/community_circle.dart';
import '../providers/community_provider.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/circle_card.dart';
import '../widgets/create_circle_modal.dart';
import '../widgets/trip_card.dart';

class CommunityScreen extends ConsumerStatefulWidget {
  const CommunityScreen({super.key});

  @override
  ConsumerState<CommunityScreen> createState() => _CommunityScreenState();
}

class _CommunityScreenState extends ConsumerState<CommunityScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  final Map<String, bool> _joiningCircleIds = {};

  final List<Map<String, String>> _categories = const [
    {'id': 'all', 'label': '🌐 Tous'},
    {'id': 'culture', 'label': '🏛️ Culture & Histoire'},
    {'id': 'adventure', 'label': '⛩️ Aventure & Roadtrip'},
    {'id': 'nature', 'label': '🌿 Nature & Bivouac'},
    {'id': 'food', 'label': '🍷 Gastronomie'},
    {'id': 'beach', 'label': '🏖️ Plage & Soleil'},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _handleToggleJoin(CommunityCircle circle) async {
    final authUser = ref.read(currentUserProvider);
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: VoyagoColors.orange,
          content: Text('Veuillez vous connecter pour rejoindre ce cercle'),
        ),
      );
      return;
    }

    setState(() => _joiningCircleIds[circle.id] = true);
    final controller = ref.read(communityControllerProvider);

    try {
      if (circle.isMember) {
        await controller.leaveCircle(circle.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: VoyagoColors.surface,
              content: Text('Vous avez quitté "${circle.name}"'),
            ),
          );
        }
      } else {
        await controller.joinCircle(circle.id);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              backgroundColor: VoyagoColors.primary,
              content: Text('🎉 Bienvenue dans la tribu "${circle.name}" !'),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: VoyagoColors.coral,
            content: Text('Erreur: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _joiningCircleIds.remove(circle.id));
    }
  }

  /// Rejoindre un cercle privé avec le code partagé par son créateur.
  Future<void> _showJoinByCodeDialog() async {
    if (ref.read(currentUserProvider) == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: VoyagoColors.orange,
          content: Text('Veuillez vous connecter pour rejoindre un cercle'),
        ),
      );
      return;
    }

    final codeController = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VoyagoColors.surface,
        title: const Text('Rejoindre un cercle privé', style: TextStyle(color: VoyagoColors.text)),
        content: TextField(
          controller: codeController,
          autofocus: true,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: VoyagoColors.text, letterSpacing: 2),
          decoration: const InputDecoration(hintText: "Code d'invitation"),
          onSubmitted: (v) => Navigator.of(ctx).pop(v),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Annuler', style: TextStyle(color: VoyagoColors.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(codeController.text),
            style: ElevatedButton.styleFrom(backgroundColor: VoyagoColors.primary),
            child: const Text('Rejoindre', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    codeController.dispose();
    if (code == null || code.trim().isEmpty || !mounted) return;

    try {
      final circleId = await ref.read(communityControllerProvider).joinCircleByCode(code);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: VoyagoColors.primary,
          content: Text('🎉 Bienvenue dans ta nouvelle tribu !'),
        ),
      );
      if (circleId.isNotEmpty) context.go('/circle/$circleId');
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)),
      );
    }
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
            Text('🦜', style: TextStyle(fontSize: 20)),
            SizedBox(width: 8),
            Text('Communauté Voyagooo'),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_outlined),
            onPressed: () {
              ref.invalidate(communityCirclesProvider);
              ref.invalidate(communityFeedProvider);
            },
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: VoyagoColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: VoyagoColors.cardBorder),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: VoyagoColors.primary.withOpacity(0.2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: VoyagoColors.primary.withOpacity(0.6)),
              ),
              indicatorSize: TabBarIndicatorSize.tab,
              labelColor: VoyagoColors.primary,
              unselectedLabelColor: VoyagoColors.muted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              tabs: const [
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('🏕️', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 6),
                      Text('Tribus & Cercles'),
                    ],
                  ),
                ),
                Tab(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('✈️', style: TextStyle(fontSize: 14)),
                      SizedBox(width: 6),
                      Text('Voyages Récents'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildCirclesTab(),
          _buildTripsFeedTab(),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 1: TRIBUS & CERCLES (NOUVELLE EXPÉRIENCE DE COMMUNAUTÉ VOYAGOOO)
  // =========================================================================

  Widget _buildCirclesTab() {
    final circlesAsync = ref.watch(communityCirclesProvider);
    final selectedCategory = ref.watch(selectedCircleCategoryProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(communityCirclesProvider.future),
      color: VoyagoColors.primary,
      backgroundColor: VoyagoColors.surface,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        slivers: [
          // Search Bar + Create Button Row
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      height: 46,
                      decoration: BoxDecoration(
                        color: VoyagoColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: VoyagoColors.cardBorder),
                      ),
                      child: TextField(
                        controller: _searchController,
                        style: const TextStyle(color: VoyagoColors.text, fontSize: 14),
                        onChanged: (val) {
                          ref.read(circleSearchQueryProvider.notifier).state = val;
                        },
                        decoration: InputDecoration(
                          hintText: 'Rechercher une destination, un cercle...',
                          hintStyle: const TextStyle(color: VoyagoColors.muted, fontSize: 13),
                          prefixIcon: const Icon(Icons.search_rounded, color: VoyagoColors.muted, size: 20),
                          suffixIcon: _searchController.text.isNotEmpty
                              ? IconButton(
                                  icon: const Icon(Icons.clear_rounded, size: 18, color: VoyagoColors.muted),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref.read(circleSearchQueryProvider.notifier).state = '';
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(vertical: 10),
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    tooltip: 'Rejoindre avec un code',
                    onPressed: _showJoinByCodeDialog,
                    icon: const Icon(Icons.vpn_key_outlined, color: VoyagoColors.primary),
                  ),
                  const SizedBox(width: 2),
                  ElevatedButton.icon(
                    onPressed: () => CreateCircleModal.show(context),
                    icon: const Icon(Icons.add, size: 16),
                    label: const Text('Créer', style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VoyagoColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ],
              ),
            ),
          ),

          // Categories Filter Pills
          SliverToBoxAdapter(
            child: SizedBox(
              height: 46,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                itemCount: _categories.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final cat = _categories[index];
                  final isSelected = selectedCategory == cat['id'];
                  return GestureDetector(
                    onTap: () {
                      ref.read(selectedCircleCategoryProvider.notifier).state = cat['id']!;
                    },
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? VoyagoColors.primary.withOpacity(0.2)
                            : VoyagoColors.surface,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isSelected
                              ? VoyagoColors.primary
                              : VoyagoColors.cardBorder,
                        ),
                      ),
                      child: Center(
                        child: Text(
                          cat['label']!,
                          style: TextStyle(
                            color: isSelected ? VoyagoColors.primary : VoyagoColors.muted,
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 6)),

          // Circles List
          circlesAsync.when(
            data: (circles) {
              if (circles.isEmpty) {
                return SliverFillRemaining(
                  hasScrollBody: false,
                  child: Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('🧭', style: TextStyle(fontSize: 48)),
                          const SizedBox(height: 16),
                          const Text(
                            'Aucune tribu trouvée',
                            style: TextStyle(
                              color: VoyagoColors.text,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Text(
                            'Soyez le premier à fonder une tribu pour cette destination !',
                            style: TextStyle(color: VoyagoColors.muted, fontSize: 13),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 18),
                          ElevatedButton.icon(
                            onPressed: () => CreateCircleModal.show(context),
                            icon: const Icon(Icons.group_add_rounded, size: 18),
                            label: const Text('Fonder une Tribu 🚀'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VoyagoColors.primary,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              }

              return SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final circle = circles[index];
                    final isJoining = _joiningCircleIds[circle.id] == true;

                    return CircleCard(
                      circle: circle,
                      isJoining: isJoining,
                      onTap: () => context.go('/circle/${circle.id}'),
                      onToggleJoin: () => _handleToggleJoin(circle),
                    );
                  },
                  childCount: circles.length,
                ),
              );
            },
            loading: () => const SliverFillRemaining(
              child: Center(
                child: CircularProgressIndicator(color: VoyagoColors.primary),
              ),
            ),
            error: (err, _) => SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('😕', style: TextStyle(fontSize: 44)),
                      const SizedBox(height: 14),
                      Text('Erreur: $err', style: const TextStyle(color: VoyagoColors.muted)),
                      const SizedBox(height: 16),
                      ElevatedButton(
                        onPressed: () => ref.invalidate(communityCirclesProvider),
                        child: const Text('Réessayer'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          const SliverToBoxAdapter(child: SizedBox(height: 32)),
        ],
      ),
    );
  }

  // =========================================================================
  // TAB 2: FLUX DE VOYAGES (LOGIQUE EXISTANTE 100% PRÉSERVÉE)
  // =========================================================================

  Widget _buildTripsFeedTab() {
    final feedAsync = ref.watch(communityFeedProvider);

    return RefreshIndicator(
      onRefresh: () async => ref.refresh(communityFeedProvider.future),
      color: VoyagoColors.primary,
      backgroundColor: VoyagoColors.surface,
      child: feedAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('🦜', style: TextStyle(fontSize: 56)),
                    SizedBox(height: 20),
                    Text(
                      'Aucun voyage partagé pour le moment 🦜',
                      style: TextStyle(
                        color: VoyagoColors.text,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    SizedBox(height: 8),
                    Text(
                      'Soyez le premier explorateur à partager votre aventure avec Voyagooo !',
                      style: TextStyle(color: VoyagoColors.muted),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.only(top: 8, bottom: 32),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              return TripCard(
                trip: item.trip,
                authorInfo: {
                  'name': item.authorName,
                  'pseudo': item.authorPseudo,
                  'avatar_emoji': item.authorAvatarEmoji,
                  'picture': item.authorPicture,
                  'is_pro': item.authorIsPro,
                },
                onTap: () => context.go('/itinerary/${item.trip.id}', extra: item.trip),
              );
            },
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(color: VoyagoColors.primary),
        ),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('😕', style: TextStyle(fontSize: 48)),
                const SizedBox(height: 16),
                Text(
                  e.toString(),
                  style: const TextStyle(color: VoyagoColors.muted),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () => ref.invalidate(communityFeedProvider),
                  child: const Text('Réessayer'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
