import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../models/trip.dart';
import '../providers/auth_provider.dart';
import '../providers/journal_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/trips_provider.dart';
import '../theme.dart';

class TravelerDrawer extends ConsumerWidget {
  final String? currentTripId;
  final ValueChanged<Trip>? onTripSelected;

  const TravelerDrawer({
    super.key,
    this.currentTripId,
    this.onTripSelected,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;
    final profileAsync = user != null ? ref.watch(profileProvider(user.userId)) : null;
    final tripsAsync = user != null ? ref.watch(tripsProvider(user.userId)) : null;
    final pastTripsCount = tripsAsync?.valueOrNull?.where((t) => t.isPast).length ?? 0;

    return Drawer(
      backgroundColor: VoyagoColors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header / Brand
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
              child: Row(
                children: [
                  Container(
                    width: 42,
                    height: 42,
                    decoration: BoxDecoration(
                      color: VoyagoColors.primary.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: VoyagoColors.primary.withValues(alpha: 0.3),
                      ),
                    ),
                    alignment: Alignment.center,
                    child: const Icon(
                      Icons.travel_explore,
                      color: VoyagoColors.primary,
                      size: 26,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Voyagooo',
                          style: TextStyle(
                            color: VoyagoColors.text,
                            fontSize: 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.5,
                          ),
                        ),
                        Text(
                          'TABLEAU DE BORD',
                          style: TextStyle(
                            color: VoyagoColors.muted.withValues(alpha: 0.8),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: VoyagoColors.muted, size: 20),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),

            const Divider(color: VoyagoColors.cardBorder, height: 1),

            // User Info Banner
            if (user != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VoyagoColors.background,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: VoyagoColors.cardBorder),
                ),
                child: Row(
                  children: [
                    Stack(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: VoyagoColors.primary.withValues(alpha: 0.2),
                          backgroundImage: (user.picture != null && user.picture!.isNotEmpty)
                              ? NetworkImage(user.picture!)
                              : null,
                          child: (user.picture == null || user.picture!.isEmpty)
                              ? Text(
                                  user.avatarDisplay,
                                  style: const TextStyle(fontSize: 18),
                                )
                              : null,
                        ),
                        Positioned(
                          right: -2,
                          bottom: -2,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
                            decoration: BoxDecoration(
                              color: VoyagoColors.primary,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: VoyagoColors.surface, width: 1.5),
                            ),
                            child: Text(
                              profileAsync?.valueOrNull != null
                                  ? 'Niv ${profileAsync!.valueOrNull!.level}'
                                  : 'Lvl 1',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            user.name,
                            style: const TextStyle(
                              color: VoyagoColors.text,
                              fontSize: 14,
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            profileAsync?.valueOrNull != null
                                ? '${profileAsync!.valueOrNull!.xp} XP · ${profileAsync.valueOrNull!.streak}j streak'
                                : 'Explorateur',
                            style: const TextStyle(
                              color: VoyagoColors.muted,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Navigation Links
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                children: [
                  _NavTile(
                    icon: Icons.home_outlined,
                    label: 'Accueil',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/');
                    },
                  ),
                  _NavTile(
                    icon: Icons.map_outlined,
                    label: 'Carte & Itinéraire',
                    isActive: currentTripId != null,
                    onTap: () {
                      Navigator.of(context).pop();
                      // Ouvert depuis l'accueil : on rejoint la carte
                      if (currentTripId == null) context.go('/itinerary');
                    },
                  ),
                  _NavTile(
                    icon: Icons.auto_stories_outlined,
                    label: 'Journal de voyage',
                    badge: pastTripsCount > 0 ? '$pastTripsCount' : null,
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/journal');
                    },
                  ),
                  _NavTile(
                    icon: Icons.add_location_alt_outlined,
                    label: 'Créer un voyage',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/swipe');
                    },
                  ),
                  _NavTile(
                    icon: Icons.stars_outlined,
                    label: 'Récompenses & Niveaux',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/xp-rewards');
                    },
                  ),
                  _NavTile(
                    icon: Icons.public_outlined,
                    label: 'Communauté',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/community');
                    },
                  ),
                  _NavTile(
                    icon: Icons.admin_panel_settings_outlined,
                    label: 'Paramètres des tribus',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.push('/tribe-settings');
                    },
                  ),
                  _NavTile(
                    icon: Icons.workspace_premium_outlined,
                    label: 'Voyagooo Pro',
                    badge: 'PRO',
                    onTap: () {
                      Navigator.of(context).pop();
                      context.go('/pricing');
                    },
                  ),

                  const SizedBox(height: 16),
                  const Divider(color: VoyagoColors.cardBorder, height: 1),
                  const SizedBox(height: 12),

                  // "My Trips" section
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'MES VOYAGES',
                          style: TextStyle(
                            color: VoyagoColors.muted.withValues(alpha: 0.8),
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1,
                          ),
                        ),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).pop();
                            context.go('/swipe');
                          },
                          child: const Icon(
                            Icons.add,
                            color: VoyagoColors.primary,
                            size: 18,
                          ),
                        ),
                      ],
                    ),
                  ),

                  if (tripsAsync != null)
                    tripsAsync.when(
                      data: (allTrips) {
                        // Les voyages passés vivent dans le journal, plus sur la carte
                        final trips = activeTrips(allTrips);
                        if (trips.isEmpty) {
                          return Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text(
                              allTrips.isEmpty
                                  ? 'Aucun voyage généré pour le moment'
                                  : 'Aucun voyage en cours. Retrouve les précédents dans ton journal 📖',
                              style: TextStyle(
                                color: VoyagoColors.muted.withValues(alpha: 0.7),
                                fontSize: 12,
                              ),
                            ),
                          );
                        }
                        return Column(
                          children: trips.map((trip) {
                            final isCurrent = trip.id == currentTripId;
                            return Container(
                              margin: const EdgeInsets.symmetric(vertical: 2),
                              decoration: BoxDecoration(
                                color: isCurrent
                                    ? VoyagoColors.primary.withValues(alpha: 0.12)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(10),
                                border: isCurrent
                                    ? Border.all(color: VoyagoColors.primary.withValues(alpha: 0.3))
                                    : null,
                              ),
                              child: ListTile(
                                dense: true,
                                visualDensity: VisualDensity.compact,
                                leading: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isCurrent ? VoyagoColors.green : VoyagoColors.muted.withValues(alpha: 0.4),
                                    boxShadow: isCurrent
                                        ? [
                                            BoxShadow(
                                              color: VoyagoColors.green.withValues(alpha: 0.5),
                                              blurRadius: 6,
                                            ),
                                          ]
                                        : null,
                                  ),
                                ),
                                title: Text(
                                  trip.destination,
                                  style: TextStyle(
                                    color: isCurrent ? VoyagoColors.primary : VoyagoColors.text,
                                    fontWeight: isCurrent ? FontWeight.w700 : FontWeight.w500,
                                    fontSize: 13,
                                  ),
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      '${trip.durationDays}j',
                                      style: const TextStyle(
                                        color: VoyagoColors.muted,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    _TripMenu(trip: trip),
                                  ],
                                ),
                                onTap: () {
                                  Navigator.of(context).pop();
                                  if (onTripSelected != null) {
                                    onTripSelected!(trip);
                                  } else {
                                    context.go('/itinerary/${trip.id}', extra: trip);
                                  }
                                },
                              ),
                            );
                          }).toList(),
                        );
                      },
                      loading: () => const Center(
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      ),
                      error: (_, __) => const SizedBox.shrink(),
                    )
                  else
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Connectez-vous pour voir vos voyages',
                        style: TextStyle(
                          color: VoyagoColors.muted.withValues(alpha: 0.7),
                          fontSize: 12,
                        ),
                      ),
                    ),
                ],
              ),
            ),

            // Footer
            const Divider(color: VoyagoColors.cardBorder, height: 1),
            Padding(
              padding: const EdgeInsets.all(12),
              child: _NavTile(
                icon: Icons.settings_outlined,
                label: 'Profil & Paramètres',
                onTap: () {
                  Navigator.of(context).pop();
                  context.go('/profile');
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Actions d'un voyage du menu : le terminer l'envoie dans le journal.
class _TripMenu extends ConsumerWidget {
  final Trip trip;

  const _TripMenu({required this.trip});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      tooltip: 'Options du voyage',
      padding: EdgeInsets.zero,
      icon: const Icon(Icons.more_vert_rounded, color: VoyagoColors.muted, size: 18),
      color: VoyagoColors.background,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: VoyagoColors.cardBorder),
      ),
      onSelected: (_) => _complete(context, ref),
      itemBuilder: (_) => const [
        PopupMenuItem(
          value: 'complete',
          child: Row(
            children: [
              Icon(Icons.auto_stories_outlined, color: VoyagoColors.yellow, size: 18),
              SizedBox(width: 10),
              Text('Terminer → Journal', style: TextStyle(color: VoyagoColors.text, fontSize: 13)),
            ],
          ),
        ),
      ],
    );
  }

  Future<void> _complete(BuildContext context, WidgetRef ref) async {
    final router = GoRouter.of(context);
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VoyagoColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Terminer ${trip.destination} ?', style: const TextStyle(color: VoyagoColors.text, fontSize: 18)),
        content: const Text(
          'Le voyage quitte la carte et rejoint ton journal, avec tes lieux, tes avis et tes souvenirs. '
          'Tu pourras le remettre sur la carte à tout moment.',
          style: TextStyle(color: VoyagoColors.muted, height: 1.4),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: VoyagoColors.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VoyagoColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text('Ouvrir mon journal', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await setTripCompleted(ref, tripId: trip.id, completed: true);
      if (navigator.canPop()) navigator.pop();
      router.go('/journal/${trip.id}');
    } catch (_) {
      messenger?.showSnackBar(
        const SnackBar(content: Text('Impossible de terminer ce voyage. Réessaie.'), behavior: SnackBarBehavior.floating),
      );
    }
  }
}

class _NavTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final String? badge;
  final VoidCallback onTap;

  const _NavTile({
    required this.icon,
    required this.label,
    this.isActive = false,
    this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 2),
      decoration: BoxDecoration(
        color: isActive ? VoyagoColors.primary.withValues(alpha: 0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: ListTile(
        dense: true,
        leading: Icon(
          icon,
          color: isActive ? VoyagoColors.primary : VoyagoColors.muted,
          size: 22,
        ),
        title: Text(
          label,
          style: TextStyle(
            color: isActive ? VoyagoColors.primary : VoyagoColors.text,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
        trailing: badge != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: VoyagoColors.yellow.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badge!,
                  style: const TextStyle(
                    color: VoyagoColors.yellow,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              )
            : null,
        onTap: onTap,
      ),
    );
  }
}
