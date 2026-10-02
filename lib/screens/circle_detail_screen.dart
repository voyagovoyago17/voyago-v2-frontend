import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../api/api_exceptions.dart';
import '../models/community_circle.dart';
import '../models/community_post.dart';
import '../models/trip.dart';
import '../providers/community_provider.dart';
import '../providers/auth_provider.dart';
import '../providers/trips_provider.dart';
import '../data/countries_data.dart';
import '../services/destination_service.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as ep;
import 'package:animated_emoji/animated_emoji.dart';
import '../theme.dart';

class CircleDetailScreen extends ConsumerStatefulWidget {
  final String circleId;

  const CircleDetailScreen({super.key, required this.circleId});

  @override
  ConsumerState<CircleDetailScreen> createState() => _CircleDetailScreenState();
}

class _CircleDetailScreenState extends ConsumerState<CircleDetailScreen> {
  bool _isTogglingMembership = false;
  String _selectedFeedFilter = 'all'; // 'all', 'trips', 'moments'

  Future<void> _handleToggleMembership(CommunityCircle circle) async {
    final authUser = ref.read(currentUserProvider);
    final messenger = ScaffoldMessenger.of(context);
    if (authUser == null) {
      messenger.showSnackBar(
        const SnackBar(
          backgroundColor: VoyagoColors.orange,
          content: Text('Veuillez vous connecter pour rejoindre ce cercle'),
        ),
      );
      return;
    }

    setState(() => _isTogglingMembership = true);
    final controller = ref.read(communityControllerProvider);

    try {
      if (circle.isMember) {
        await controller.leaveCircle(circle.id);
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: VoyagoColors.surface,
              content: Text('Vous avez quitté "${circle.name}"'),
            ),
          );
        }
        ref.invalidate(circleDetailProvider(widget.circleId));
        ref.invalidate(communityCirclesProvider);
      } else {
        await controller.joinCircle(circle.id);
        if (mounted) {
          messenger.showSnackBar(
            SnackBar(
              backgroundColor: VoyagoColors.primary,
              content: Text('🎉 Bienvenue dans la tribu "${circle.name}" !'),
            ),
          );
        }
        ref.invalidate(circleDetailProvider(widget.circleId));
        ref.invalidate(communityCirclesProvider);
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: VoyagoColors.coral,
            content: Text('Erreur: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isTogglingMembership = false);
    }
  }

  void _showShareTripModal(CommunityCircle circle) {
    final authUser = ref.read(currentUserProvider);
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: VoyagoColors.orange,
          content: Text('Connectez-vous pour partager un voyage'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _ShareTripSheet(
        circle: circle,
        userId: authUser.userId,
        onSuccess: () {
          ref.invalidate(circleDetailProvider(widget.circleId));
          ref.invalidate(circlePostsProvider(widget.circleId));
          ref.invalidate(communityCirclesProvider);
        },
      ),
    );
  }

  void _showCreatePostModal(CommunityCircle circle) {
    final authUser = ref.read(currentUserProvider);
    if (authUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: VoyagoColors.orange,
          content: Text('Connectez-vous pour publier un moment'),
        ),
      );
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreatePostSheet(
        circle: circle,
        onSuccess: () {
          ref.invalidate(circleDetailProvider(widget.circleId));
          ref.invalidate(circlePostsProvider(widget.circleId));
          ref.invalidate(communityCirclesProvider);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final circleAsync = ref.watch(circleDetailProvider(widget.circleId));
    final postsAsync = ref.watch(circlePostsProvider(widget.circleId));

    return Scaffold(
      backgroundColor: VoyagoColors.background,
      body: circleAsync.when(
        data: (circle) => RefreshIndicator(
          onRefresh: () async {
            await Future.wait([
              ref.refresh(circleDetailProvider(widget.circleId).future),
              ref.refresh(circlePostsProvider(widget.circleId).future),
            ]);
          },
          color: VoyagoColors.primary,
          backgroundColor: VoyagoColors.surface,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
            slivers: [
              // 1. Sliver Header with Cover & Hero back button
              SliverAppBar(
                expandedHeight: 250,
                pinned: true,
                backgroundColor: VoyagoColors.surface,
                leading: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.55),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  ),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/community');
                    }
                  },
                ),
                actions: [
                  if (circle.isMember)
                    PopupMenuButton<String>(
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.55),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(Icons.more_vert, color: Colors.white, size: 20),
                      ),
                      color: VoyagoColors.surface,
                      onSelected: (val) {
                        if (val == 'leave') {
                          _handleToggleMembership(circle);
                        }
                      },
                      itemBuilder: (context) => [
                        const PopupMenuItem(
                          value: 'leave',
                          child: Row(
                            children: [
                              Icon(Icons.exit_to_app_rounded, color: VoyagoColors.coral, size: 18),
                              SizedBox(width: 8),
                              Text('Quitter la tribu', style: TextStyle(color: VoyagoColors.coral)),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      CachedNetworkImage(
                        imageUrl: circle.coverImageUrl,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Container(color: VoyagoColors.surface),
                        errorWidget: (_, __, ___) => Container(color: VoyagoColors.cardBorder),
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.black.withOpacity(0.35),
                              Colors.transparent,
                              VoyagoColors.background.withOpacity(0.92),
                              VoyagoColors.background,
                            ],
                            stops: const [0.0, 0.35, 0.85, 1.0],
                          ),
                        ),
                      ),
                      // Floating Avatar Emoji
                      Positioned(
                        bottom: 16,
                        left: 20,
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: VoyagoColors.surface,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: VoyagoColors.cardBorder, width: 2),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.4),
                                blurRadius: 16,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: Text(circle.avatarEmoji, style: const TextStyle(fontSize: 36)),
                        ),
                      ),
                      // Category Chip
                      Positioned(
                        bottom: 24,
                        right: 20,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.65),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white.withOpacity(0.2)),
                          ),
                          child: Text(
                            circle.categoryLabel,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // 2. Main Details & Real Dynamic Metrics
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title
                      Text(
                        circle.name,
                        style: const TextStyle(
                          color: VoyagoColors.text,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.3,
                        ),
                      ),

                      const SizedBox(height: 6),

                      // Location tag
                      Row(
                        children: [
                          const Icon(Icons.location_on_rounded, size: 16, color: VoyagoColors.primary),
                          const SizedBox(width: 6),
                          Text(
                            circle.locationDisplay,
                            style: const TextStyle(
                              color: VoyagoColors.primary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (!circle.isPublic) ...[
                            const SizedBox(width: 12),
                            const Icon(Icons.lock_outline, size: 15, color: VoyagoColors.muted),
                            const SizedBox(width: 4),
                            const Text(
                              'Cercle privé',
                              style: TextStyle(color: VoyagoColors.muted, fontSize: 13, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ],
                      ),

                      if (circle.description.isNotEmpty) ...[
                        const SizedBox(height: 12),
                        Text(
                          circle.description,
                          style: const TextStyle(
                            color: VoyagoColors.muted,
                            fontSize: 14,
                            height: 1.45,
                          ),
                        ),
                      ],

                      const SizedBox(height: 18),

                      // REAL DYNAMIC STATS BAR (CHIFFRES RÉELS DE LA BASE)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: VoyagoColors.surface,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: VoyagoColors.cardBorder),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _RealStatColumn(
                              icon: Icons.group_rounded,
                              value: '${circle.membersCount}',
                              label: circle.membersCount > 1 ? 'Membres' : 'Membre',
                              color: VoyagoColors.blue,
                            ),
                            Container(width: 1, height: 32, color: VoyagoColors.cardBorder),
                            _RealStatColumn(
                              icon: Icons.flight_takeoff_rounded,
                              value: '${circle.tripsCount}',
                              label: circle.tripsCount > 1 ? 'Voyages' : 'Voyage',
                              color: VoyagoColors.yellow,
                            ),
                            Container(width: 1, height: 32, color: VoyagoColors.cardBorder),
                            _RealStatColumn(
                              icon: Icons.forum_rounded,
                              value: '${circle.postsCount}',
                              label: circle.postsCount > 1 ? 'Moments' : 'Moment',
                              color: VoyagoColors.primary,
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Membership Status Badge if joined
                      if (circle.isMember) ...[
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: VoyagoColors.primary.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: VoyagoColors.primary.withOpacity(0.4)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.check_circle_rounded, color: VoyagoColors.primary, size: 18),
                              SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Vous êtes membre de cette tribu !',
                                  style: TextStyle(
                                    color: VoyagoColors.primary,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Code d'invitation (créateur / admins d'un cercle privé)
                      if (circle.inviteCode != null) ...[
                        _InviteCodeCard(circle: circle),
                        const SizedBox(height: 14),
                      ],

                      // ACTION BUTTONS BAR
                      Row(
                        children: [
                          if (!circle.isMember) ...[
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                onPressed: _isTogglingMembership
                                    ? null
                                    : () => _handleToggleMembership(circle),
                                icon: _isTogglingMembership
                                    ? const SizedBox(
                                        width: 18,
                                        height: 18,
                                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                      )
                                    : const Icon(Icons.group_add_rounded, size: 18),
                                label: const Text(
                                  'Rejoindre la Tribu',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: VoyagoColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ] else ...[
                            Expanded(
                              flex: 3,
                              child: ElevatedButton.icon(
                                onPressed: () => _showShareTripModal(circle),
                                icon: const Icon(Icons.flight_takeoff_rounded, size: 18),
                                label: const Text(
                                  'Partager un voyage (+1 XP)',
                                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: VoyagoColors.primary,
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 0,
                                ),
                              ),
                            ),
                            const SizedBox(width: 10),
                          ],

                          // Secondary Button: Post a moment
                          ElevatedButton(
                            onPressed: () => _showCreatePostModal(circle),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: VoyagoColors.surface,
                              foregroundColor: VoyagoColors.text,
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: const BorderSide(color: VoyagoColors.cardBorder),
                              ),
                              elevation: 0,
                            ),
                            child: const Row(
                              children: [
                                Icon(Icons.edit_note_rounded, size: 18, color: VoyagoColors.primary),
                                SizedBox(width: 6),
                                Text('Moment', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                              ],
                            ),
                          ),
                        ],
                      ),

                      // 3. REAL JOINED MEMBERS SECTION ("Les membres qui ont rejoint")
                      const SizedBox(height: 24),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Text('👥', style: TextStyle(fontSize: 16)),
                              const SizedBox(width: 6),
                              Text(
                                'Explorateurs de la tribu (${circle.membersCount})',
                                style: const TextStyle(
                                  color: VoyagoColors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      if (circle.membersSample.isNotEmpty) ...[
                        SizedBox(
                          height: 90,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: circle.membersSample.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 14),
                            itemBuilder: (context, index) {
                              final m = circle.membersSample[index];
                              final isCreator = m.role == 'creator';

                              return GestureDetector(
                                onTap: () => context.go('/user/${m.userId}'),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    // Avatar Stack (Picture or Emoji)
                                    Stack(
                                      clipBehavior: Clip.none,
                                      children: [
                                        Container(
                                          width: 48,
                                          height: 48,
                                          decoration: BoxDecoration(
                                            color: VoyagoColors.surface,
                                            shape: BoxShape.circle,
                                            border: Border.all(
                                              color: isCreator ? VoyagoColors.yellow : VoyagoColors.primary,
                                              width: 2,
                                            ),
                                          ),
                                          clipBehavior: Clip.antiAlias,
                                          child: m.picture != null && m.picture!.isNotEmpty
                                              ? CachedNetworkImage(
                                                  imageUrl: m.picture!,
                                                  fit: BoxFit.cover,
                                                  placeholder: (_, __) => Center(
                                                    child: Text(m.avatarEmoji, style: const TextStyle(fontSize: 22)),
                                                  ),
                                                  errorWidget: (_, __, ___) => Center(
                                                    child: Text(m.avatarEmoji, style: const TextStyle(fontSize: 22)),
                                                  ),
                                                )
                                              : Center(
                                                  child: Text(m.avatarEmoji, style: const TextStyle(fontSize: 22)),
                                                ),
                                        ),
                                        if (isCreator)
                                          Positioned(
                                            bottom: -2,
                                            right: -2,
                                            child: Container(
                                              padding: const EdgeInsets.all(2),
                                              decoration: const BoxDecoration(
                                                color: VoyagoColors.yellow,
                                                shape: BoxShape.circle,
                                              ),
                                              child: const Text('👑', style: TextStyle(fontSize: 10)),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 6),
                                    SizedBox(
                                      width: 68,
                                      child: Text(
                                        m.displayName,
                                        style: const TextStyle(
                                          color: VoyagoColors.text,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        textAlign: TextAlign.center,
                                      ),
                                    ),
                                    Text(
                                      isCreator ? 'Fondateur' : 'Explorateur',
                                      style: TextStyle(
                                        color: isCreator ? VoyagoColors.yellow : VoyagoColors.muted,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                        ),
                      ] else ...[
                        // Empty members state with quick invite/join
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: VoyagoColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: VoyagoColors.cardBorder),
                          ),
                          child: Row(
                            children: [
                              const Text('🧭', style: TextStyle(fontSize: 28)),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Aucun membre pour le moment',
                                      style: TextStyle(
                                        color: VoyagoColors.text,
                                        fontWeight: FontWeight.bold,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      'Soyez le premier à rejoindre la tribu "${circle.name}" !',
                                      style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                              if (!circle.isMember)
                                TextButton(
                                  onPressed: () => _handleToggleMembership(circle),
                                  child: const Text('Rejoindre', style: TextStyle(fontWeight: FontWeight.bold)),
                                ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 24),
                      const Divider(color: VoyagoColors.cardBorder),
                      const SizedBox(height: 14),

                      // 4. FEED HEADER & FILTERS
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Row(
                            children: [
                              Text('💬', style: TextStyle(fontSize: 16)),
                              SizedBox(width: 6),
                              Text(
                                'Flux de la Tribu',
                                style: TextStyle(
                                  color: VoyagoColors.text,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          TextButton.icon(
                            onPressed: () => _showShareTripModal(circle),
                            icon: const Icon(Icons.add, size: 16),
                            label: const Text('Partager', style: TextStyle(fontSize: 13)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),

                      // Filter Pills for Posts
                      Row(
                        children: [
                          _FeedFilterChip(
                            label: 'Tout (${circle.postsCount})',
                            isSelected: _selectedFeedFilter == 'all',
                            onTap: () => setState(() => _selectedFeedFilter = 'all'),
                          ),
                          const SizedBox(width: 8),
                          _FeedFilterChip(
                            label: '✈️ Voyages (${circle.tripsCount})',
                            isSelected: _selectedFeedFilter == 'trips',
                            onTap: () => setState(() => _selectedFeedFilter = 'trips'),
                          ),
                          const SizedBox(width: 8),
                          _FeedFilterChip(
                            label: '💬 Moments',
                            isSelected: _selectedFeedFilter == 'moments',
                            onTap: () => setState(() => _selectedFeedFilter = 'moments'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),

              // 5. POSTS & MOMENTS STREAM
              postsAsync.when(
                data: (allPosts) {
                  final filteredPosts = allPosts.where((p) {
                    if (_selectedFeedFilter == 'trips') return p.tripId != null;
                    if (_selectedFeedFilter == 'moments') return p.tripId == null;
                    return true;
                  }).toList();

                  if (filteredPosts.isEmpty) {
                    return SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              const Text('🏕️', style: TextStyle(fontSize: 48)),
                              const SizedBox(height: 14),
                              Text(
                                _selectedFeedFilter == 'trips'
                                    ? 'Aucun voyage partagé pour l\'instant'
                                    : 'Aucun moment partagé pour l\'instant',
                                style: const TextStyle(
                                  color: VoyagoColors.text,
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 6),
                              const Text(
                                'Soyez le premier explorateur à inspirer la communauté !',
                                style: TextStyle(color: VoyagoColors.muted, fontSize: 13),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 18),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 10,
                                runSpacing: 10,
                                children: [
                                  ElevatedButton.icon(
                                    onPressed: () => _showShareTripModal(circle),
                                    icon: const Icon(Icons.flight_takeoff_rounded, size: 16),
                                    label: const Text('Partager un voyage (+1 XP)'),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: VoyagoColors.primary,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => _showCreatePostModal(circle),
                                    icon: const Icon(Icons.edit_note_rounded, size: 16),
                                    label: const Text('Astuce'),
                                    style: OutlinedButton.styleFrom(
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                                    ),
                                  ),
                                ],
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
                        final post = filteredPosts[index];
                        return _PostCard(
                          post: post,
                          circleId: circle.id,
                          onTapTrip: (trip) => context.go('/itinerary/${trip.id}', extra: trip),
                        );
                      },
                      childCount: filteredPosts.length,
                    ),
                  );
                },
                loading: () => const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: CircularProgressIndicator(color: VoyagoColors.primary),
                    ),
                  ),
                ),
                error: (err, _) => SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text('Erreur: $err', style: const TextStyle(color: VoyagoColors.coral)),
                    ),
                  ),
                ),
              ),

              const SliverToBoxAdapter(child: SizedBox(height: 60)),
            ],
          ),
        ),
        loading: () => const Center(
          child: CircularProgressIndicator(color: VoyagoColors.primary),
        ),
        error: (err, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('😕', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              Text(
                err is ApiException && err.statusCode == 404
                    ? "Ce cercle est privé ou n'existe plus.\nDemande un code d'invitation à son créateur."
                    : 'Impossible de charger ce cercle\n$err',
                textAlign: TextAlign.center,
                style: const TextStyle(color: VoyagoColors.muted),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => ref.invalidate(circleDetailProvider(widget.circleId)),
                child: const Text('Réessayer'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InviteCodeCard extends ConsumerStatefulWidget {
  final CommunityCircle circle;

  const _InviteCodeCard({required this.circle});

  @override
  ConsumerState<_InviteCodeCard> createState() => _InviteCodeCardState();
}

class _InviteCodeCardState extends ConsumerState<_InviteCodeCard> {
  bool _regenerating = false;

  String get _code => widget.circle.inviteCode ?? '';

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: _code));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Code d'invitation copié")),
    );
  }

  Future<void> _share() async {
    await SharePlus.instance.share(ShareParams(
      text: 'Rejoins ma tribu "${widget.circle.name}" sur Voyagooo 🦜\n'
          "Communauté → 🔑 Rejoindre avec un code : $_code",
    ));
  }

  Future<void> _regenerate() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VoyagoColors.surface,
        title: const Text('Nouveau code ?', style: TextStyle(color: VoyagoColors.text)),
        content: const Text(
          "L'ancien code ne fonctionnera plus. Les membres actuels restent dans le cercle.",
          style: TextStyle(color: VoyagoColors.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
          TextButton(onPressed: () => Navigator.of(ctx).pop(true), child: const Text('Générer')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() => _regenerating = true);
    try {
      await ref.read(communityControllerProvider).regenerateInviteCode(widget.circle.id);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)),
        );
      }
    } finally {
      if (mounted) setState(() => _regenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VoyagoColors.cardBorder),
      ),
      child: Row(
        children: [
          const Icon(Icons.vpn_key_outlined, color: VoyagoColors.yellow, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Code d'invitation", style: TextStyle(color: VoyagoColors.muted, fontSize: 12)),
                const SizedBox(height: 2),
                SelectableText(
                  _code,
                  style: const TextStyle(
                    color: VoyagoColors.text,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 3,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Copier',
            onPressed: _copy,
            icon: const Icon(Icons.copy_rounded, color: VoyagoColors.muted, size: 20),
          ),
          IconButton(
            tooltip: 'Partager',
            onPressed: _share,
            icon: const Icon(Icons.ios_share_rounded, color: VoyagoColors.muted, size: 20),
          ),
          IconButton(
            tooltip: 'Nouveau code',
            onPressed: _regenerating ? null : _regenerate,
            icon: _regenerating
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2, color: VoyagoColors.muted),
                  )
                : const Icon(Icons.refresh_rounded, color: VoyagoColors.muted, size: 20),
          ),
        ],
      ),
    );
  }
}

class _FeedFilterChip extends StatelessWidget {
  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  const _FeedFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? VoyagoColors.primary.withOpacity(0.2) : VoyagoColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isSelected ? VoyagoColors.primary : VoyagoColors.cardBorder,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? VoyagoColors.primary : VoyagoColors.muted,
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

class _RealStatColumn extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _RealStatColumn({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 5),
            Text(
              value,
              style: const TextStyle(
                color: VoyagoColors.text,
                fontSize: 17,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 3),
        Text(
          label,
          style: const TextStyle(
            color: VoyagoColors.muted,
            fontSize: 11,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _PostCard extends ConsumerWidget {
  final CommunityPost post;
  final String circleId;
  final void Function(Trip trip) onTapTrip;

  const _PostCard({
    required this.post,
    required this.circleId,
    required this.onTapTrip,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authUser = ref.watch(currentUserProvider);
    final isLiked = post.isLikedBy(authUser?.userId);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VoyagoColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Author Header
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: VoyagoColors.background,
                  shape: BoxShape.circle,
                  border: Border.all(color: VoyagoColors.cardBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: post.authorPicture != null && post.authorPicture!.isNotEmpty
                    ? CachedNetworkImage(
                        imageUrl: post.authorPicture!,
                        fit: BoxFit.cover,
                        placeholder: (_, __) => Center(
                          child: Text(post.authorEmoji, style: const TextStyle(fontSize: 20)),
                        ),
                        errorWidget: (_, __, ___) => Center(
                          child: Text(post.authorEmoji, style: const TextStyle(fontSize: 20)),
                        ),
                      )
                    : Center(
                        child: Text(post.authorEmoji, style: const TextStyle(fontSize: 20)),
                      ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            post.authorDisplayName,
                            style: const TextStyle(
                              color: VoyagoColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (post.authorIsPro) ...[
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: VoyagoColors.blue.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'PRO',
                              style: TextStyle(
                                color: VoyagoColors.blue,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Text(
                      _formatDate(post.createdAt),
                      style: const TextStyle(color: VoyagoColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
              // Like Button
              InkWell(
                onTap: () {
                  if (authUser == null) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Connectez-vous pour aimer ce post')),
                    );
                    return;
                  }
                  ref.read(communityControllerProvider).toggleLikePost(
                        postId: post.id,
                        circleId: circleId,
                      );
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: isLiked ? VoyagoColors.coral.withOpacity(0.15) : VoyagoColors.background,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isLiked ? VoyagoColors.coral.withOpacity(0.5) : VoyagoColors.cardBorder,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isLiked ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                        color: isLiked ? VoyagoColors.coral : VoyagoColors.muted,
                        size: 15,
                      ),
                      if (post.likesCount > 0) ...[
                        const SizedBox(width: 4),
                        Text(
                          '${post.likesCount}',
                          style: TextStyle(
                            color: isLiked ? VoyagoColors.coral : VoyagoColors.muted,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Content Text
          if (post.content.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              post.content,
              style: const TextStyle(
                color: VoyagoColors.text,
                fontSize: 14,
                height: 1.4,
              ),
            ),
          ],

          // POI Location pill
          if (post.poiTitle != null && post.poiTitle!.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: VoyagoColors.primary.withOpacity(0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.place_rounded, size: 14, color: VoyagoColors.primary),
                  const SizedBox(width: 4),
                  Text(
                    '${post.poiTitle}${post.poiCity != null ? " • ${post.poiCity}" : ""}',
                    style: const TextStyle(
                      color: VoyagoColors.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Attached Trip Preview Card
          if (post.trip != null) ...[
            const SizedBox(height: 14),
            GestureDetector(
              onTap: () => onTapTrip(post.trip!),
              child: Container(
                decoration: BoxDecoration(
                  color: VoyagoColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: VoyagoColors.cardBorder),
                ),
                clipBehavior: Clip.antiAlias,
                child: Row(
                  children: [
                    if (post.trip!.displayCoverImage != null)
                      SizedBox(
                        width: 90,
                        height: 80,
                        child: CachedNetworkImage(
                          imageUrl: post.trip!.displayCoverImage!,
                          fit: BoxFit.cover,
                          placeholder: (_, __) => Container(color: VoyagoColors.cardBorder),
                          errorWidget: (_, __, ___) => Container(color: VoyagoColors.cardBorder),
                        ),
                      ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              post.trip!.destination,
                              style: const TextStyle(
                                color: VoyagoColors.text,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${post.trip!.durationDays} jours • ${post.trip!.pois.length} étapes',
                              style: const TextStyle(
                                color: VoyagoColors.muted,
                                fontSize: 11,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Padding(
                      padding: EdgeInsets.only(right: 12),
                      child: Icon(Icons.arrow_forward_ios_rounded, size: 14, color: VoyagoColors.primary),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatDate(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 60) {
      return 'Il y a ${diff.inMinutes <= 0 ? 1 : diff.inMinutes} min';
    } else if (diff.inHours < 24) {
      return 'Il y a ${diff.inHours}h';
    } else if (diff.inDays < 7) {
      return 'Il y a ${diff.inDays}j';
    }
    return DateFormat('d MMM yyyy', 'fr').format(dt);
  }
}

// =========================================================================
// MODAL: PARTAGER UN VOYAGE DANS LE CERCLE
// =========================================================================

class _ShareTripSheet extends ConsumerStatefulWidget {
  final CommunityCircle circle;
  final String userId;
  final VoidCallback onSuccess;

  const _ShareTripSheet({
    required this.circle,
    required this.userId,
    required this.onSuccess,
  });

  @override
  ConsumerState<_ShareTripSheet> createState() => _ShareTripSheetState();
}

class _ShareTripSheetState extends ConsumerState<_ShareTripSheet> {
  String? _selectedTripId;
  final _commentController = TextEditingController();
  bool _isSharing = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    if (_selectedTripId == null) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Veuillez sélectionner un voyage à partager')),
      );
      return;
    }

    setState(() => _isSharing = true);

    try {
      final controller = ref.read(communityControllerProvider);
      await controller.shareTripToCircle(
        circleId: widget.circle.id,
        tripId: _selectedTripId!,
        comment: _commentController.text.trim().isEmpty ? null : _commentController.text.trim(),
      );

      widget.onSuccess();

      if (mounted) {
        nav.pop();
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: VoyagoColors.primary,
            content: Text('🎉 Voyage partagé dans la tribu ! (+1 XP obtenu 🌟)'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: VoyagoColors.coral,
            content: Text('Erreur lors du partage: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tripsAsync = ref.watch(tripsProvider(widget.userId));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VoyagoColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Partager dans "${widget.circle.name}" ✈️',
                        style: const TextStyle(
                          color: VoyagoColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        'Gagnez +1 XP et inspirez les membres de la tribu',
                        style: TextStyle(color: VoyagoColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: VoyagoColors.muted),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: VoyagoColors.cardBorder),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Choisissez un voyage',
                    style: TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 10),
                  tripsAsync.when(
                    data: (trips) {
                      if (trips.isEmpty) {
                        return Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: VoyagoColors.background,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: VoyagoColors.cardBorder),
                          ),
                          child: const Center(
                            child: Text(
                              'Vous n\'avez pas encore créé de voyage.\nGénérez un itinéraire sur l\'accueil d\'abord !',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: VoyagoColors.muted, fontSize: 13),
                            ),
                          ),
                        );
                      }

                      return Column(
                        children: trips.map((trip) {
                          final isSelected = trip.id == _selectedTripId;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedTripId = trip.id),
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? VoyagoColors.primary.withOpacity(0.15)
                                    : VoyagoColors.background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? VoyagoColors.primary : VoyagoColors.cardBorder,
                                  width: isSelected ? 1.5 : 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isSelected
                                        ? Icons.check_circle_rounded
                                        : Icons.radio_button_unchecked_rounded,
                                    color: isSelected ? VoyagoColors.primary : VoyagoColors.muted,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      trip.destination,
                                      style: TextStyle(
                                        color: VoyagoColors.text,
                                        fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                  Text(
                                    '${trip.durationDays}j',
                                    style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
                                  ),
                                ],
                              ),
                            ),
                          );
                        }).toList(),
                      );
                    },
                    loading: () => const Center(
                      child: CircularProgressIndicator(color: VoyagoColors.primary),
                    ),
                    error: (err, _) => Text('Erreur: $err', style: const TextStyle(color: VoyagoColors.coral)),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Un mot d\'accompagnement (facultatif)',
                    style: TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _commentController,
                    maxLines: 2,
                    style: const TextStyle(color: VoyagoColors.text),
                    decoration: const InputDecoration(
                      hintText: 'Ex: Mes 4 jours inoubliables, à faire absolument !',
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSharing ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VoyagoColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSharing
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : const Text(
                              'Partager dans la Tribu 🚀',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// MODAL: POSTER UN MOMENT DANS LE CERCLE
// =========================================================================

class _CreatePostSheet extends ConsumerStatefulWidget {
  final CommunityCircle circle;
  final VoidCallback onSuccess;

  const _CreatePostSheet({
    required this.circle,
    required this.onSuccess,
  });

  @override
  ConsumerState<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends ConsumerState<_CreatePostSheet> {
  final _contentController = TextEditingController();
  String _selectedCity = '';
  String _selectedPoi = '';
  bool _isSubmitting = false;
  bool _showEmojiPicker = false;
  int _emojiPanelTab = 0; // 0 = Animés, 1 = Clavier complet

  static const List<AnimatedEmojiData> _animatedEmojisList = [
    AnimatedEmojis.sparkles,
    AnimatedEmojis.airplaneDeparture,
    AnimatedEmojis.airplaneArrival,
    AnimatedEmojis.rocket,
    AnimatedEmojis.cameraFlash,
    AnimatedEmojis.globeShowingEuropeAfrica,
    AnimatedEmojis.sunriseOverMountains,
    AnimatedEmojis.sunglassesFace,
    AnimatedEmojis.sunWithFace,
    AnimatedEmojis.umbrella,
    AnimatedEmojis.fire,
    AnimatedEmojis.partyPopper,
    AnimatedEmojis.partyingFace,
    AnimatedEmojis.heartEyes,
    AnimatedEmojis.starStruck,
    AnimatedEmojis.joy,
    AnimatedEmojis.heartFace,
    AnimatedEmojis.smile,
    AnimatedEmojis.wink,
    AnimatedEmojis.thumbsUp,
    AnimatedEmojis.twoHearts,
    AnimatedEmojis.eyes,
    AnimatedEmojis.trophy,
    AnimatedEmojis.clap,
    AnimatedEmojis.wave,
    AnimatedEmojis.victory,
  ];

  @override
  void initState() {
    super.initState();
    _selectedCity = widget.circle.destinationCity?.trim() ?? '';
  }

  @override
  void dispose() {
    _contentController.dispose();
    super.dispose();
  }

  void _insertEmoji(String emoji) {
    final text = _contentController.text;
    final selection = _contentController.selection;
    final newText = selection.start >= 0 && selection.end >= 0
        ? text.replaceRange(selection.start, selection.end, emoji)
        : text + emoji;
    final newCursorPos = (selection.start >= 0 ? selection.start : text.length) + emoji.length;
    _contentController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }

  Future<void> _submit() async {
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);

    final content = _contentController.text.trim();
    if (content.isEmpty) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Veuillez écrire un message')),
      );
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final controller = ref.read(communityControllerProvider);
      await controller.createPost(
        circleId: widget.circle.id,
        content: content,
        poiTitle: _selectedPoi.trim().isEmpty ? null : _selectedPoi.trim(),
        poiCity: _selectedCity.trim().isEmpty ? null : _selectedCity.trim(),
      );

      widget.onSuccess();

      if (mounted) {
        nav.pop();
        messenger.showSnackBar(
          const SnackBar(
            backgroundColor: VoyagoColors.primary,
            content: Text('🎉 Moment publié avec succès !'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: VoyagoColors.coral,
            content: Text('Erreur: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _openCityPicker() async {
    final pickedCity = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CityPickerSheet(
        countryName: widget.circle.destinationCountry,
        currentCity: _selectedCity,
      ),
    );

    if (pickedCity != null && mounted) {
      setState(() {
        _selectedCity = pickedCity;
      });
    }
  }

  Future<void> _openPoiPicker(List<String> communitySpots) async {
    final pickedPoi = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _PoiPickerSheet(
        currentCity: _selectedCity,
        currentPoi: _selectedPoi,
        communitySpots: communitySpots,
      ),
    );

    if (pickedPoi != null && mounted) {
      setState(() {
        _selectedPoi = pickedPoi;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    // Récupérer les spots recommandés par les membres de la tribu
    final postsAsync = ref.watch(circlePostsProvider(widget.circle.id));
    final communitySpots = postsAsync.maybeWhen(
      data: (posts) => posts
          .where((p) => p.poiTitle != null && p.poiTitle!.trim().isNotEmpty)
          .map((p) => p.poiTitle!.trim())
          .toSet()
          .toList(),
      orElse: () => <String>[],
    );

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VoyagoColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Publier un moment 💬',
                        style: TextStyle(
                          color: VoyagoColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Dans "${widget.circle.name}"',
                        style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: VoyagoColors.muted),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: VoyagoColors.cardBorder),
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Expanded(
                        child: Text(
                          'Votre astuce ou retour d\'expérience',
                          style: TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                      ),
                      InkWell(
                        onTap: () {
                          if (_showEmojiPicker) {
                            setState(() => _showEmojiPicker = false);
                          } else {
                            FocusScope.of(context).unfocus();
                            setState(() => _showEmojiPicker = true);
                          }
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: _showEmojiPicker
                                ? VoyagoColors.primary.withValues(alpha: 0.18)
                                : Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: _showEmojiPicker ? VoyagoColors.primary : VoyagoColors.cardBorder,
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _showEmojiPicker ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                                size: 15,
                                color: _showEmojiPicker ? VoyagoColors.primary : VoyagoColors.muted,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                _showEmojiPicker ? 'Clavier' : 'Émojis',
                                style: TextStyle(
                                  color: _showEmojiPicker ? VoyagoColors.primary : VoyagoColors.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _contentController,
                    maxLines: 4,
                    style: const TextStyle(color: VoyagoColors.text),
                    onTap: () {
                      if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
                    },
                    decoration: const InputDecoration(
                      hintText: 'Partagez une bonne adresse, une vue secrète, un conseil pratique...',
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Bandeau horizontal des émojis animés rapides
                  SizedBox(
                    height: 38,
                    child: ListView.separated(
                      scrollDirection: Axis.horizontal,
                      itemCount: _animatedEmojisList.length,
                      separatorBuilder: (_, __) => const SizedBox(width: 8),
                      itemBuilder: (context, index) {
                        final emoji = _animatedEmojisList[index];
                        return Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _insertEmoji(emoji.toUnicodeEmoji()),
                            borderRadius: BorderRadius.circular(10),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: VoyagoColors.background,
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: VoyagoColors.cardBorder),
                              ),
                              child: Center(
                                child: AnimatedEmoji(
                                  emoji,
                                  size: 22,
                                  repeat: true,
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),

                  // Tiroir émoji complet & animé
                  if (_showEmojiPicker) ...[
                    const SizedBox(height: 12),
                    Container(
                      height: 260,
                      decoration: BoxDecoration(
                        color: VoyagoColors.background,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: VoyagoColors.cardBorder),
                      ),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                            child: Row(
                              children: [
                                ChoiceChip(
                                  label: const Text('✨ Émojis Animés'),
                                  selected: _emojiPanelTab == 0,
                                  onSelected: (val) {
                                    if (val) setState(() => _emojiPanelTab = 0);
                                  },
                                  backgroundColor: VoyagoColors.surface,
                                  selectedColor: VoyagoColors.primary.withValues(alpha: 0.2),
                                  labelStyle: TextStyle(
                                    color: _emojiPanelTab == 0 ? VoyagoColors.primary : VoyagoColors.muted,
                                    fontWeight: _emojiPanelTab == 0 ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                  side: BorderSide(
                                    color: _emojiPanelTab == 0 ? VoyagoColors.primary : VoyagoColors.cardBorder,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                ChoiceChip(
                                  label: const Text('😀 Clavier Complet'),
                                  selected: _emojiPanelTab == 1,
                                  onSelected: (val) {
                                    if (val) setState(() => _emojiPanelTab = 1);
                                  },
                                  backgroundColor: VoyagoColors.surface,
                                  selectedColor: VoyagoColors.primary.withValues(alpha: 0.2),
                                  labelStyle: TextStyle(
                                    color: _emojiPanelTab == 1 ? VoyagoColors.primary : VoyagoColors.muted,
                                    fontWeight: _emojiPanelTab == 1 ? FontWeight.bold : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                  side: BorderSide(
                                    color: _emojiPanelTab == 1 ? VoyagoColors.primary : VoyagoColors.cardBorder,
                                  ),
                                ),
                                const Spacer(),
                                IconButton(
                                  icon: const Icon(Icons.close_rounded, size: 18, color: VoyagoColors.muted),
                                  onPressed: () => setState(() => _showEmojiPicker = false),
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                ),
                              ],
                            ),
                          ),
                          const Divider(height: 1, color: VoyagoColors.cardBorder),
                          Expanded(
                            child: _emojiPanelTab == 0
                                ? GridView.builder(
                                    padding: const EdgeInsets.all(12),
                                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 6,
                                      mainAxisSpacing: 10,
                                      crossAxisSpacing: 10,
                                    ),
                                    itemCount: _animatedEmojisList.length,
                                    itemBuilder: (context, index) {
                                      final emoji = _animatedEmojisList[index];
                                      return Material(
                                        color: Colors.transparent,
                                        child: InkWell(
                                          onTap: () => _insertEmoji(emoji.toUnicodeEmoji()),
                                          borderRadius: BorderRadius.circular(12),
                                          child: Container(
                                            decoration: BoxDecoration(
                                              color: VoyagoColors.surface,
                                              borderRadius: BorderRadius.circular(12),
                                              border: Border.all(color: VoyagoColors.cardBorder),
                                            ),
                                            child: Center(
                                              child: AnimatedEmoji(
                                                emoji,
                                                size: 30,
                                                repeat: true,
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                : ep.EmojiPicker(
                                    textEditingController: _contentController,
                                    config: const ep.Config(
                                      height: 220,
                                      checkPlatformCompatibility: false,
                                      emojiViewConfig: ep.EmojiViewConfig(
                                        columns: 8,
                                        emojiSizeMax: 26,
                                        backgroundColor: VoyagoColors.background,
                                        buttonMode: ep.ButtonMode.MATERIAL,
                                      ),
                                      categoryViewConfig: ep.CategoryViewConfig(
                                        backgroundColor: VoyagoColors.surface,
                                        indicatorColor: VoyagoColors.primary,
                                        iconColorSelected: VoyagoColors.primary,
                                        iconColor: VoyagoColors.muted,
                                        backspaceColor: VoyagoColors.coral,
                                        tabBarHeight: 38,
                                      ),
                                      bottomActionBarConfig: ep.BottomActionBarConfig(
                                        backgroundColor: VoyagoColors.surface,
                                        buttonColor: VoyagoColors.surface,
                                        buttonIconColor: VoyagoColors.muted,
                                        showSearchViewButton: true,
                                        showBackspaceButton: true,
                                      ),
                                      searchViewConfig: ep.SearchViewConfig(
                                        backgroundColor: VoyagoColors.background,
                                        buttonIconColor: VoyagoColors.primary,
                                      ),
                                    ),
                                  ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  const Row(
                    children: [
                      Icon(Icons.explore_outlined, color: VoyagoColors.muted, size: 14),
                      SizedBox(width: 6),
                      Text(
                        'Localisation & Spot (Optionnel)',
                        style: TextStyle(color: VoyagoColors.muted, fontWeight: FontWeight.w600, fontSize: 12),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      // Sélecteur de Lieu / Spot
                      Expanded(
                        child: _LocationSelectCard(
                          icon: Icons.place_rounded,
                          iconColor: VoyagoColors.primary,
                          title: _selectedPoi.isNotEmpty ? _selectedPoi : 'Lieu / Spot',
                          subtitle: _selectedPoi.isNotEmpty ? 'Lieu sélectionné' : 'Choisir un spot',
                          isSelected: _selectedPoi.isNotEmpty,
                          onTap: () => _openPoiPicker(communitySpots),
                          onClear: _selectedPoi.isNotEmpty ? () => setState(() => _selectedPoi = '') : null,
                        ),
                      ),
                      const SizedBox(width: 10),
                      // Sélecteur de Ville
                      Expanded(
                        child: _LocationSelectCard(
                          icon: Icons.location_city_rounded,
                          iconColor: VoyagoColors.blue,
                          title: _selectedCity.isNotEmpty ? _selectedCity : 'Ville',
                          subtitle: _selectedCity.isNotEmpty
                              ? (widget.circle.destinationCountry ?? 'Ville validée')
                              : 'Choisir la ville',
                          isSelected: _selectedCity.isNotEmpty,
                          onTap: _openCityPicker,
                          onClear: _selectedCity.isNotEmpty ? () => setState(() {
                            _selectedCity = '';
                          }) : null,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isSubmitting ? null : _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VoyagoColors.primary,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: _isSubmitting
                          ? const CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          : const Text(
                              'Publier le moment 💬',
                              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: Colors.white),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// =========================================================================
// WIDGETS SÉLECTEURS DE LIEU ET DE VILLE (UI / UX GUIDÉE)
// =========================================================================

class _LocationSelectCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _LocationSelectCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.isSelected,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? iconColor.withValues(alpha: 0.1) : VoyagoColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? iconColor.withValues(alpha: 0.5) : VoyagoColors.cardBorder,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? iconColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isSelected ? iconColor : VoyagoColors.muted,
                  size: 16,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? VoyagoColors.text : VoyagoColors.muted,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? iconColor : VoyagoColors.muted.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected && onClear != null)
                GestureDetector(
                  onTap: onClear,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 14, color: VoyagoColors.muted),
                  ),
                )
              else
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: VoyagoColors.muted.withValues(alpha: 0.7),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CityPickerSheet extends StatefulWidget {
  final String? countryName;
  final String currentCity;

  const _CityPickerSheet({
    this.countryName,
    required this.currentCity,
  });

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  final _searchController = TextEditingController();
  List<String> _allCities = [];
  List<String> _filteredCities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCities();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      List<String> cities = [];
      if (widget.countryName != null && widget.countryName!.trim().isNotEmpty) {
        cities = await CountriesData.getCitiesForCountry(widget.countryName);
      }

      if (cities.isEmpty) {
        cities = DestinationService.popularDestinations.map((d) => d.name).toList();
      }

      if (mounted) {
        setState(() {
          _allCities = cities;
          _filteredCities = cities;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _allCities = DestinationService.popularDestinations.map((d) => d.name).toList();
          _filteredCities = _allCities;
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCities = _allCities;
      } else {
        _filteredCities = _allCities
            .where((city) => city.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  String _cleanInput(String input) {
    final trimmed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return '';
    return trimmed.split(' ').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final clean = _cleanInput(query);
    final hasExactMatch = _filteredCities.any(
      (c) => c.toLowerCase() == clean.toLowerCase(),
    );
    final flag = widget.countryName != null ? CountriesData.getFlag(widget.countryName) : '🌍';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VoyagoColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sélectionner la Ville 🏢',
                        style: TextStyle(
                          color: VoyagoColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(flag, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(
                            widget.countryName != null && widget.countryName!.isNotEmpty
                                ? '${widget.countryName!} · Base officielle'
                                : 'Villes répertoriées',
                            style: const TextStyle(color: VoyagoColors.blue, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          if (!_isLoading) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${_allCities.length})',
                              style: TextStyle(color: VoyagoColors.muted.withValues(alpha: 0.7), fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: VoyagoColors.muted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: VoyagoColors.text),
              decoration: InputDecoration(
                hintText: _isLoading ? 'Chargement des villes...' : 'Rechercher une ville...',
                hintStyle: TextStyle(color: VoyagoColors.muted.withValues(alpha: 0.7)),
                prefixIcon: const Icon(Icons.search_rounded, color: VoyagoColors.blue, size: 20),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: VoyagoColors.muted, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: VoyagoColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: VoyagoColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: VoyagoColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: VoyagoColors.blue, width: 1.5),
                ),
              ),
            ),
          ),
          const Divider(height: 16, color: VoyagoColors.cardBorder),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: VoyagoColors.blue, strokeWidth: 2),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    children: [
                      if (clean.length >= 2 && !hasExactMatch) ...[
                        ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          tileColor: VoyagoColors.blue.withValues(alpha: 0.1),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: VoyagoColors.blue.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_location_alt_rounded, color: VoyagoColors.blue, size: 18),
                          ),
                          title: Text(
                            'Utiliser "$clean"',
                            style: const TextStyle(color: VoyagoColors.blue, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'Ville personnalisée (orthographe nettoyée)',
                            style: TextStyle(color: VoyagoColors.muted, fontSize: 11),
                          ),
                          onTap: () => Navigator.of(context).pop(clean),
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (_filteredCities.isEmpty && clean.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              'Aucune ville trouvée',
                              style: TextStyle(color: VoyagoColors.muted),
                            ),
                          ),
                        ),
                      ..._filteredCities.map((city) {
                        final isSelected = widget.currentCity.toLowerCase() == city.toLowerCase();
                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: isSelected ? VoyagoColors.blue.withValues(alpha: 0.12) : null,
                          leading: Icon(
                            Icons.location_city_rounded,
                            color: isSelected ? VoyagoColors.blue : VoyagoColors.muted,
                            size: 20,
                          ),
                          title: Text(
                            city,
                            style: TextStyle(
                              color: isSelected ? VoyagoColors.blue : VoyagoColors.text,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: VoyagoColors.blue, size: 20)
                              : null,
                          onTap: () => Navigator.of(context).pop(city),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _PoiPickerSheet extends StatefulWidget {
  final String currentCity;
  final String currentPoi;
  final List<String> communitySpots;

  const _PoiPickerSheet({
    required this.currentCity,
    required this.currentPoi,
    required this.communitySpots,
  });

  @override
  State<_PoiPickerSheet> createState() => _PoiPickerSheetState();
}

class _PoiPickerSheetState extends State<_PoiPickerSheet> {
  final _searchController = TextEditingController();

  static const Map<String, List<Map<String, String>>> _curatedSpotsByCity = {
    'tokyo': [
      {'name': 'Shibuya Crossing', 'category': 'Carrefour mythique & Shopping', 'icon': '🚶‍♂️'},
      {'name': 'Temple Senso-ji', 'category': 'Temple historique & Asakusa', 'icon': '⛩️'},
      {'name': 'Akihabara Electric Town', 'category': 'Manga, Gaming & High-tech', 'icon': '🎮'},
      {'name': 'Tour de Tokyo', 'category': 'Panorama & Monument emblématique', 'icon': '🗼'},
      {'name': 'Shinjuku Gyoen', 'category': 'Parc & Cerisiers en fleurs', 'icon': '🌸'},
      {'name': 'Meiji Jingu', 'category': 'Sanctuaire Shinto & Forêt sacrée', 'icon': '🌲'},
      {'name': 'Quartier Harajuku (Takeshita)', 'category': 'Mode & Street culture', 'icon': '👗'},
      {'name': 'TeamLab Planets', 'category': 'Art immersif & Expérience visuelle', 'icon': '✨'},
      {'name': 'Marché de Tsukiji', 'category': 'Street food & Poissons frais', 'icon': '🍣'},
      {'name': 'Roppongi Hills Mori Tower', 'category': 'Vue panoramique 360°', 'icon': '🏙️'},
      {'name': 'Parc d\'Ueno', 'category': 'Culture, Balade & Musées', 'icon': '🏛️'},
      {'name': 'Ginza', 'category': 'Boutiques de luxe & Architecture', 'icon': '🛍️'},
    ],
    'kyoto': [
      {'name': 'Fushimi Inari-Taisha', 'category': 'Sanctuaire aux 10 000 Torii', 'icon': '⛩️'},
      {'name': 'Temple Kinkaku-ji (Pavillon d\'Or)', 'category': 'Chef-d\'œuvre doré', 'icon': '🏯'},
      {'name': 'Bambouseraie d\'Arashiyama', 'category': 'Forêt de bambous féerique', 'icon': '🎋'},
      {'name': 'Quartier Gion', 'category': 'Geishas & Maisons de thé', 'icon': '🏮'},
      {'name': 'Temple Kiyomizu-dera', 'category': 'Terrasse en bois sur pilotis', 'icon': '🌄'},
      {'name': 'Marché Nishiki', 'category': 'Cuisine traditionnelle de Kyoto', 'icon': '🍢'},
    ],
    'osaka': [
      {'name': 'Château d\'Osaka', 'category': 'Forteresse historique & Parc', 'icon': '🏯'},
      {'name': 'Dotonbori', 'category': 'Enseignes néon & Street food', 'icon': '🐙'},
      {'name': 'Quartier Shinsekai', 'category': 'Ambiance rétro & Tour Tsutenkaku', 'icon': '🗼'},
      {'name': 'Umeda Sky Building', 'category': 'Observatoire flottant', 'icon': '🏙️'},
    ],
    'paris': [
      {'name': 'Tour Eiffel', 'category': 'Monument mondial incontournable', 'icon': '🗼'},
      {'name': 'Musée du Louvre', 'category': 'Art, Histoire & Pyramide', 'icon': '🎨'},
      {'name': 'Montmartre & Sacré-Cœur', 'category': 'Village bohème & Vue sur Paris', 'icon': '⛪'},
      {'name': 'Cathédrale Notre-Dame', 'category': 'Joyau gothique & Île de la Cité', 'icon': '🔔'},
      {'name': 'Le Marais', 'category': 'Rues piétonnes, Boutiques & Cafés', 'icon': '🥐'},
      {'name': 'Jardin du Luxembourg', 'category': 'Palais & Détente au vert', 'icon': '🌳'},
      {'name': 'Champs-Élysées & Arc de Triomphe', 'category': 'Avenue mythique', 'icon': '🏛️'},
      {'name': 'Quartier Latin & Panthéon', 'category': 'Librairies & Esprit étudiant', 'icon': '☕'},
    ],
    'rome': [
      {'name': 'Colisée & Forum Romain', 'category': 'Arène antique & Histoire des Césars', 'icon': '🏛️'},
      {'name': 'Fontaine de Trevi', 'category': 'Vœux & Chef-d\'œuvre baroque', 'icon': '🪙'},
      {'name': 'Panthéon de Rome', 'category': 'Dôme percé millénaire', 'icon': '🏛️'},
      {'name': 'Quartier Trastevere', 'category': 'Charme pavé, Trattorias & Vieille ville', 'icon': '🍝'},
      {'name': 'Place Navone (Piazza Navona)', 'category': 'Fontaines du Bernin & Artistes', 'icon': '⛲'},
      {'name': 'Basilique Saint-Pierre & Vatican', 'category': 'Chapelle Sixtine & Trésors', 'icon': '⛪'},
      {'name': 'Villa Borghèse', 'category': 'Grand poumon vert & Jardins', 'icon': '🌿'},
      {'name': 'Place d\'Espagne (Piazza di Spagna)', 'category': 'Escaliers monumentaux & Fleurs', 'icon': '🌸'},
    ],
    'new york': [
      {'name': 'Central Park', 'category': 'Oasis urbaine & Balades', 'icon': '🌳'},
      {'name': 'Times Square', 'category': 'Écrans géants & Énergie Broadway', 'icon': '✨'},
      {'name': 'Pont de Brooklyn', 'category': 'Traversée à pied avec vue skyline', 'icon': '🌉'},
      {'name': 'Statue de la Liberté', 'category': 'Symbole légendaire & Baie', 'icon': '🗽'},
      {'name': 'The High Line', 'category': 'Parc suspendu sur d\'anciens rails', 'icon': '🌿'},
      {'name': 'SoHo & Greenwich Village', 'category': 'Cast-iron buildings & Cafés', 'icon': '☕'},
      {'name': 'Summit One Vanderbilt', 'category': 'Miroirs immersifs & Vue Empire State', 'icon': '🏙️'},
    ],
    'barcelone': [
      {'name': 'Sagrada Família', 'category': 'Chef-d\'œuvre inachevé de Gaudí', 'icon': '⛪'},
      {'name': 'Parc Güell', 'category': 'Sculptures de mosaïque & Vue mer', 'icon': '🦎'},
      {'name': 'Quartier Gothique (Barri Gòtic)', 'category': 'Ruelles médiévales & Cathédrale', 'icon': '🏰'},
      {'name': 'Marché de la Boqueria & Rambla', 'category': 'Fruits frais & Tapas authentiques', 'icon': '🍓'},
      {'name': 'Plage de la Barceloneta', 'category': 'Mer Méditerranée & Bars de plage', 'icon': '🏖️'},
    ],
    'londres': [
      {'name': 'Big Ben & Westminster', 'category': 'Parlement britannique & Tamise', 'icon': '🕰️'},
      {'name': 'Tower Bridge', 'category': 'Pont basculant historique', 'icon': '🌉'},
      {'name': 'British Museum', 'category': 'Trésors de l\'humanité gratuits', 'icon': '🏛️'},
      {'name': 'Camden Market', 'category': 'Vintage, Rock & Street food monde', 'icon': '🎸'},
      {'name': 'Covent Garden', 'category': 'Marché couvert & Artistes de rue', 'icon': '🎭'},
      {'name': 'Hyde Park', 'category': 'Balade royale & Serpentine', 'icon': '🌳'},
    ],
    'abidjan': [
      {'name': 'Le Plateau', 'category': 'Gratte-ciels & Vue lagune Ébrié', 'icon': '🏙️'},
      {'name': 'Cathédrale Saint-Paul', 'category': 'Architecture moderne spectaculaire', 'icon': '⛪'},
      {'name': 'Zone 4 (Marcory)', 'category': 'Gastronomie, Bars & Vie nocturne', 'icon': '🍽️'},
      {'name': 'Parc National du Banco', 'category': 'Forêt tropicale au cœur de la ville', 'icon': '🌳'},
      {'name': 'Marché de Treichville', 'category': 'Tissus wax, Épices & Artisanat', 'icon': '🛍️'},
      {'name': 'Blockhaus & Lagune', 'category': 'Maquis au bord de l\'eau & Poissons braisés', 'icon': '🐟'},
      {'name': 'Grand-Bassam', 'category': 'Ville coloniale Unesco & Plages de sable', 'icon': '🏖️'},
    ],
    'conakry': [
      {'name': 'Îles de Los (Kassa & Roume)', 'category': 'Plages dorées, Pirogues & Calme', 'icon': '🏝️'},
      {'name': 'Grande Mosquée Fayçal', 'category': 'Plus grand monument religieux', 'icon': '🕌'},
      {'name': 'Corniche Nord & Sud', 'category': 'Coucher de soleil sur l\'Atlantique', 'icon': '🌊'},
      {'name': 'Marché Madina', 'category': 'Plein d\'énergie & Grand marché guinéen', 'icon': '🛍️'},
      {'name': 'Jardin de Camayenne', 'category': 'Arbres centenaires & Fraîcheur', 'icon': '🌿'},
    ],
    'dakar': [
      {'name': 'Monument de la Renaissance', 'category': 'Statue monumentale sur les collines', 'icon': '🗿'},
      {'name': 'Île de Gorée', 'category': 'Maisons pastel & Histoire inoubliable', 'icon': '⛵'},
      {'name': 'Les Almadies', 'category': 'Pointe Ouest de l\'Afrique & Fruits de mer', 'icon': '🌅'},
      {'name': 'Phare des Mamelles', 'category': 'Vue sur la presqu\'île & Soirées live', 'icon': '🗼'},
      {'name': 'Marché Kermel', 'category': 'Halle ronde artisanale & Couleurs', 'icon': '🧺'},
    ],
    'marrakech': [
      {'name': 'Place Jemaa el-Fna', 'category': 'Ambiance magique le soir & Jus d\'orange', 'icon': '🎪'},
      {'name': 'Jardin Majorelle & Musée YSL', 'category': 'Bleu Majorelle, Palmiers & Cactus', 'icon': '🌵'},
      {'name': 'Médina & Souks', 'category': 'Lanternes, Cuir & Babouches artisanales', 'icon': '🏺'},
      {'name': 'Palais de la Bahia', 'category': 'Mosaïques Zellige & Jardins andalous', 'icon': '🏰'},
      {'name': 'La Koutoubia', 'category': 'Minaret emblématique de Marrakech', 'icon': '🕌'},
    ],
    'bali': [
      {'name': 'Forêt des Singes d\'Ubud', 'category': 'Sanctuaire naturel sacré', 'icon': '🐒'},
      {'name': 'Temple d\'Uluwatu', 'category': 'Falaise océanique & Danse Kecak', 'icon': '🌊'},
      {'name': 'Rizières de Tegallalang', 'category': 'Terrasses verdoyantes en cascades', 'icon': '🌾'},
      {'name': 'Plage de Canggu', 'category': 'Surf, Couchers de soleil & Cafés branchés', 'icon': '🏄‍♂️'},
      {'name': 'Temple de Tanah Lot', 'category': 'Temple sur rocher marin', 'icon': '⛩️'},
    ],
    'bangkok': [
      {'name': 'Grand Palais & Wat Phra Kaew', 'category': 'Résidence royale & Bouddha d\'Émeraude', 'icon': '👑'},
      {'name': 'Wat Arun (Temple de l\'Aube)', 'category': 'Flèche en porcelaine au bord du fleuve', 'icon': '🛕'},
      {'name': 'Marché de Chatuchak', 'category': 'Le plus grand marché du monde le week-end', 'icon': '🛍️'},
      {'name': 'Khaosan Road', 'category': 'Street food thaïe & Ambiance backpacker', 'icon': '🍜'},
    ],
    'dubai': [
      {'name': 'Burj Khalifa', 'category': 'Plus haute tour de la planète', 'icon': '🏙️'},
      {'name': 'The Dubai Mall & Fontaines', 'category': 'Spectacle aquatique & Shopping démesuré', 'icon': '⛲'},
      {'name': 'Dubai Marina', 'category': 'Yachts & Promenade bordée de tours', 'icon': '🛥️'},
      {'name': 'Vieux Dubaï & Souk de l\'Or', 'category': 'Traversée en abra traditionnel', 'icon': '🪙'},
    ],
    'berlin': [
      {'name': 'Porte de Brandebourg', 'category': 'Symbole de l\'unité allemande', 'icon': '🏛️'},
      {'name': 'East Side Gallery', 'category': 'Graffitis & Vestiges du Mur de Berlin', 'icon': '🎨'},
      {'name': 'Alexanderplatz & Tour TV', 'category': 'Cœur moderne & Vue à 360°', 'icon': '🗼'},
      {'name': 'Quartier Kreuzberg', 'category': 'Street food internationale & Bars alternatifs', 'icon': '🍻'},
    ],
    'madrid': [
      {'name': 'Plaza Mayor', 'category': 'Grande place historique & Sandwiches calamar', 'icon': '🏰'},
      {'name': 'Parc du Retiro', 'category': 'Palais de Cristal & Barque sur le lac', 'icon': '🌳'},
      {'name': 'Musée du Prado', 'category': 'Velázquez, Goya & Peinture classique', 'icon': '🖼️'},
      {'name': 'Gran Vía', 'category': 'Théâtres, Façades splendides & Commerces', 'icon': '🎭'},
    ],
    'lisbonne': [
      {'name': 'Tour de Belém & Pastéis', 'category': 'Embouchure du Tage & Pâtisserie mythique', 'icon': '🏰'},
      {'name': 'Tram 28 & Alfama', 'category': 'Rues sinueuses, Azulejos & Fado', 'icon': '🚋'},
      {'name': 'Miradouro de Santa Luzia', 'category': 'Panorama spectaculaire sur les toits', 'icon': '🌺'},
      {'name': 'Bairro Alto & Cais do Sodré', 'category': 'Ruelles animées & Soirées lisboètes', 'icon': '🍷'},
    ],
  };

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _cleanInput(String input) {
    final trimmed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return '';
    return trimmed.split(' ').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  List<Map<String, String>> _getCuratedSpots() {
    final cityKey = widget.currentCity.trim().toLowerCase();
    for (final entry in _curatedSpotsByCity.entries) {
      if (cityKey.contains(entry.key) || entry.key.contains(cityKey)) {
        return entry.value;
      }
    }
    return const [];
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final clean = _cleanInput(query);
    final curated = _getCuratedSpots();

    final filteredCurated = query.isEmpty
        ? curated
        : curated.where((s) {
            final name = (s['name'] ?? '').toLowerCase();
            final cat = (s['category'] ?? '').toLowerCase();
            final q = query.toLowerCase();
            return name.contains(q) || cat.contains(q);
          }).toList();

    final filteredCommunity = query.isEmpty
        ? widget.communitySpots
        : widget.communitySpots.where((s) => s.toLowerCase().contains(query.toLowerCase())).toList();

    final hasExactCurated = curated.any((s) => (s['name'] ?? '').toLowerCase() == clean.toLowerCase());
    final hasExactCommunity = widget.communitySpots.any((s) => s.toLowerCase() == clean.toLowerCase());
    final hasExactMatch = hasExactCurated || hasExactCommunity;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VoyagoColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Choisir un Lieu ou Spot 📍',
                        style: TextStyle(
                          color: VoyagoColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        widget.currentCity.isNotEmpty
                            ? 'Spots recommandés à ${widget.currentCity}'
                            : 'Sélectionnez un point d\'intérêt',
                        style: const TextStyle(color: VoyagoColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: VoyagoColors.muted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: VoyagoColors.text),
              decoration: InputDecoration(
                hintText: 'Rechercher ou ajouter un lieu...',
                hintStyle: TextStyle(color: VoyagoColors.muted.withValues(alpha: 0.7)),
                prefixIcon: const Icon(Icons.search_rounded, color: VoyagoColors.primary, size: 20),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: VoyagoColors.muted, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: VoyagoColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: VoyagoColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: VoyagoColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: VoyagoColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const Divider(height: 16, color: VoyagoColors.cardBorder),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              children: [
                if (clean.length >= 2 && !hasExactMatch) ...[
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    tileColor: VoyagoColors.primary.withValues(alpha: 0.12),
                    leading: Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: VoyagoColors.primary.withValues(alpha: 0.25),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(Icons.add_location_alt_rounded, color: VoyagoColors.primary, size: 20),
                    ),
                    title: Text(
                      'Utiliser "$clean"',
                      style: const TextStyle(color: VoyagoColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Valider ce lieu personnalisé (mise en forme soignée)',
                      style: TextStyle(color: VoyagoColors.muted, fontSize: 11),
                    ),
                    onTap: () => Navigator.of(context).pop(clean),
                  ),
                  const SizedBox(height: 8),
                ],
                if (filteredCommunity.isNotEmpty) ...[
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        Icon(Icons.local_fire_department_rounded, color: VoyagoColors.orange, size: 16),
                        SizedBox(width: 6),
                        Text(
                          'Partagés par la tribu',
                          style: TextStyle(color: VoyagoColors.orange, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  ...filteredCommunity.map((spot) {
                    final isSelected = widget.currentPoi.toLowerCase() == spot.toLowerCase();
                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: isSelected ? VoyagoColors.primary.withValues(alpha: 0.12) : null,
                      leading: Container(
                        padding: const EdgeInsets.all(7),
                        decoration: BoxDecoration(
                          color: VoyagoColors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text('🔥', style: TextStyle(fontSize: 14)),
                      ),
                      title: Text(
                        spot,
                        style: TextStyle(
                          color: isSelected ? VoyagoColors.primary : VoyagoColors.text,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: const Text(
                        'Recommandé par un membre',
                        style: TextStyle(color: VoyagoColors.muted, fontSize: 11),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: VoyagoColors.primary, size: 20)
                          : null,
                      onTap: () => Navigator.of(context).pop(spot),
                    );
                  }),
                  const SizedBox(height: 8),
                ],
                if (filteredCurated.isNotEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.stars_rounded, color: VoyagoColors.primary, size: 16),
                        const SizedBox(width: 6),
                        Text(
                          widget.currentCity.isNotEmpty
                              ? 'Incontournables à ${widget.currentCity}'
                              : 'Spots incontournables',
                          style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                  ...filteredCurated.map((spot) {
                    final name = spot['name'] ?? '';
                    final cat = spot['category'] ?? '';
                    final icon = spot['icon'] ?? '📍';
                    final isSelected = widget.currentPoi.toLowerCase() == name.toLowerCase();

                    return ListTile(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      tileColor: isSelected ? VoyagoColors.primary.withValues(alpha: 0.12) : null,
                      leading: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.06),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(icon, style: const TextStyle(fontSize: 16)),
                      ),
                      title: Text(
                        name,
                        style: TextStyle(
                          color: isSelected ? VoyagoColors.primary : VoyagoColors.text,
                          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          fontSize: 14,
                        ),
                      ),
                      subtitle: Text(
                        cat,
                        style: const TextStyle(color: VoyagoColors.muted, fontSize: 11),
                      ),
                      trailing: isSelected
                          ? const Icon(Icons.check_circle_rounded, color: VoyagoColors.primary, size: 20)
                          : null,
                      onTap: () => Navigator.of(context).pop(name),
                    );
                  }),
                ],
                if (filteredCurated.isEmpty && filteredCommunity.isEmpty && clean.isEmpty) ...[
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 16),
                    child: Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: VoyagoColors.primary.withValues(alpha: 0.15),
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.place_outlined, color: VoyagoColors.primary, size: 28),
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'Entrez le nom d\'une adresse ou d\'un spot',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Ex: Restaurant, musée, panorama, parc secret...',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: VoyagoColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}


