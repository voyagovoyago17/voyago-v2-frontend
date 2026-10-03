import 'package:animated_text_kit/animated_text_kit.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:sizer/sizer.dart';
import '../models/auth_user.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../theme.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import 'package:flutter_earth_globe/point_connection.dart';
import 'package:flutter_earth_globe/point_connection_style.dart';
import '../widgets/crystal_nav_bar.dart';
import '../widgets/next_trip_card.dart';
import '../widgets/traveler_drawer.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);
    final user = authState.user;

    // Redirection automatique pour tout utilisateur connecté qui n'a pas validé l'onboarding
    if (authState.sessionLoaded && user != null && !user.onboardingCompleted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) {
          context.go('/onboarding');
        }
      });
    }

    // Adaptabilité multi-écrans (Mobile, Tablette, Desktop, Web)
    final isTabletOrWeb = Device.screenType == ScreenType.tablet || Device.screenType == ScreenType.desktop;
    final horizontalPadding = isTabletOrWeb ? 6.w : 4.5.w.clamp(16.0, 22.0);

    return Scaffold(
      backgroundColor: VoyagoColors.background,
      extendBody: true,
      drawer: user != null ? const TravelerDrawer() : null,
      bottomNavigationBar: VoyagoCrystalNavBar(
        currentIndex: 0,
        onPlusTap: () => context.go('/swipe'),
      ),
      body: SafeArea(
        bottom: false,
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 640, // Centrage et maintien d'un ratio Dribbble parfait sur grand écran / web
            ),
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(height: 1.5.h.clamp(10.0, 16.0)),

                  // En-tête Dribbble moderne avec salutation et profil
                  _HeaderSection(user: user),

                  SizedBox(height: 2.h.clamp(16.0, 22.0)),

                  // Barre de recherche & inspiration de destination
                  _SearchInspirationBar(
                    onTap: () => context.go('/swipe'),
                  ),

                  SizedBox(height: 1.8.h.clamp(12.0, 18.0)),

                  // Filtres / Vibes de voyage rapides
                  _TravelVibesList(
                    onSelectVibe: (vibe) {
                      context.go('/configure', extra: [vibe]);
                    },
                  ),

                  SizedBox(height: 2.2.h.clamp(18.0, 24.0)),

                  // Bannière XP / Gamification ou Connexion
                  if (user != null)
                    _UserBanner(userId: user.userId)
                  else
                    _AuthBanner(onTap: () => context.go('/auth')),

                  // Prochain voyage : compte à rebours, valise, ou dates à ajouter
                  if (user != null) ...[
                    SizedBox(height: 1.8.h.clamp(12.0, 18.0)),
                    NextTripCard(userId: user.userId),
                  ],

                  SizedBox(height: 2.2.h.clamp(18.0, 24.0)),

                  // Section Hero IA d'inspiration Dribbble
                  _HeroSection(onStart: () => context.go('/swipe')),

                  SizedBox(height: 2.h.clamp(16.0, 20.0)),

                  // Bannière Tableau de Bord & Carte Leaflet interactive
                  _DashboardMapCard(onTap: () => context.go('/itinerary')),

                  SizedBox(height: 2.5.h.clamp(20.0, 28.0)),

                  // Section Explorer avec cartes modernes
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Explorer',
                            style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 16.sp.clamp(19.0, 24.0),
                                  letterSpacing: -0.5,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Tous les outils & univers de voyage',
                            style: TextStyle(
                              color: VoyagoColors.muted,
                              fontSize: 11.sp.clamp(12.0, 14.0),
                            ),
                          ),
                        ],
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 2.5.w.clamp(8.0, 12.0),
                          vertical: 0.6.h.clamp(4.0, 7.0),
                        ),
                        decoration: BoxDecoration(
                          color: VoyagoColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: VoyagoColors.cardBorder),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(Icons.tune_rounded, size: 14, color: VoyagoColors.primary),
                            const SizedBox(width: 4),
                            Text(
                              'Voyagooo 2.0',
                              style: TextStyle(
                                color: VoyagoColors.primary,
                                fontSize: 10.sp.clamp(11.0, 12.0),
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.8.h.clamp(14.0, 18.0)),

                  // Grille des cartes Explorer responsive
                  Row(
                    children: [
                      Expanded(
                        child: _ExplorerCard(
                          icon: Icons.public_rounded,
                          title: 'Communauté',
                          subtitle: 'Voyages partagés & avis',
                          badge: 'Social',
                          color: VoyagoColors.blue,
                          onTap: () => context.go('/community'),
                        ),
                      ),
                      SizedBox(width: 3.w.clamp(10.0, 16.0)),
                      Expanded(
                        child: _ExplorerCard(
                          icon: Icons.stars_rounded,
                          title: 'Récompenses',
                          subtitle: 'Niveaux, badges & défis',
                          badge: 'XP x2',
                          color: VoyagoColors.yellow,
                          onTap: () => context.go('/xp-rewards'),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 1.6.h.clamp(12.0, 16.0)),
                  Row(
                    children: [
                      Expanded(
                        child: _ExplorerCard(
                          icon: Icons.diamond_rounded,
                          title: 'Voyagooo Pro',
                          subtitle: 'IA illimitée & exclusivités',
                          badge: 'VIP',
                          color: VoyagoColors.primary,
                          onTap: () => context.go('/pricing'),
                        ),
                      ),
                      SizedBox(width: 3.w.clamp(10.0, 16.0)),
                      Expanded(
                        child: _ExplorerCard(
                          icon: Icons.person_pin_rounded,
                          title: 'Mon Espace',
                          subtitle: user != null ? 'Mes voyages sauvegardés' : 'Se connecter',
                          badge: 'Profil',
                          color: VoyagoColors.coral,
                          onTap: () => context.go(user != null ? '/profile' : '/auth'),
                        ),
                      ),
                    ],
                  ),

                  // Espace pour ne pas chevaucher la barre de navigation crystal flottante
                  SizedBox(height: 14.h.clamp(110.0, 130.0)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// En-tête personnalisé inspiré des applications de voyage Dribbble
class _HeaderSection extends ConsumerWidget {
  final AuthUser? user;
  const _HeaderSection({required this.user});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final firstName = user?.displayName.split(' ').first ?? 'Voyageur';
    final avatarSize = 12.w.clamp(44.0, 52.0);

    return Row(
      children: [
        // Avatar utilisateur avec anneau lumineux
        GestureDetector(
          // Connecté : la photo de profil ouvre le menu (toutes les options de l'app)
          onTap: () => user != null ? Scaffold.of(context).openDrawer() : context.go('/auth'),
          child: Container(
            width: avatarSize,
            height: avatarSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: VoyagoColors.surface,
              border: Border.all(
                color: VoyagoColors.primary.withValues(alpha: 0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: VoyagoColors.primary.withValues(alpha: 0.25),
                  blurRadius: 10,
                ),
              ],
            ),
            child: ClipOval(
              child: user != null && user!.picture != null && user!.picture!.isNotEmpty
                  ? CachedNetworkImage(
                      imageUrl: user!.picture!,
                      fit: BoxFit.cover,
                      placeholder: (_, __) => Center(
                        child: Text(user!.avatarDisplay, style: TextStyle(fontSize: 16.sp.clamp(18.0, 22.0))),
                      ),
                      errorWidget: (_, __, ___) => Center(
                        child: Text(user!.avatarDisplay, style: TextStyle(fontSize: 16.sp.clamp(18.0, 22.0))),
                      ),
                    )
                  : Center(
                      child: Text(
                        user?.avatarDisplay ?? '🦜',
                        style: TextStyle(fontSize: 18.sp.clamp(20.0, 26.0)),
                      ),
                    ),
            ),
          ),
        ),
        SizedBox(width: 3.5.w.clamp(12.0, 16.0)),

        // Salutations et sous-titre
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      'Bonjour $firstName 👋',
                      style: TextStyle(
                        color: VoyagoColors.text,
                        fontSize: 15.sp.clamp(17.0, 21.0),
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.3,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                'Où partons-nous explorer aujourd\'hui ?',
                style: TextStyle(
                  color: VoyagoColors.muted,
                  fontSize: 10.5.sp.clamp(12.0, 13.5),
                  fontWeight: FontWeight.w400,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),

        // Bouton Connexion (connecté : l'avatar ouvre le menu)
        if (user == null)
          ElevatedButton(
            onPressed: () => context.go('/auth'),
            style: ElevatedButton.styleFrom(
              padding: EdgeInsets.symmetric(
                horizontal: 3.5.w.clamp(12.0, 16.0),
                vertical: 1.h.clamp(7.0, 10.0),
              ),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Connexion', style: TextStyle(fontSize: 10.5.sp.clamp(12.0, 13.0))),
          ),
      ],
    );
  }
}

/// Barre de recherche et d'inspiration moderne
class _SearchInspirationBar extends StatelessWidget {
  final VoidCallback onTap;
  const _SearchInspirationBar({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 4.w.clamp(14.0, 18.0),
          vertical: 1.6.h.clamp(12.0, 16.0),
        ),
        decoration: BoxDecoration(
          color: VoyagoColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.08),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VoyagoColors.primary.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.search_rounded,
                color: VoyagoColors.primary,
                size: 20,
              ),
            ),
            SizedBox(width: 3.w.clamp(10.0, 14.0)),
            Expanded(
              child: Text(
                'Rechercher une destination, ville, envie...',
                style: TextStyle(
                  color: VoyagoColors.muted,
                  fontSize: 11.5.sp.clamp(13.0, 14.5),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(
                Icons.tune_rounded,
                color: VoyagoColors.muted,
                size: 18,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chips horizontaux de vibes de voyage
class _TravelVibesList extends StatelessWidget {
  final Function(String) onSelectVibe;

  const _TravelVibesList({required this.onSelectVibe});

  static const List<Map<String, String>> vibes = [
    {'emoji': '🏖️', 'label': 'Plage & Soleil', 'id': 'Plage'},
    {'emoji': '🏔️', 'label': 'Aventure Montagne', 'id': 'Aventure'},
    {'emoji': '🏛️', 'label': 'Culture & Histoire', 'id': 'Culture'},
    {'emoji': '🌿', 'label': 'Nature & Détente', 'id': 'Nature'},
    {'emoji': '🍕', 'label': 'Gastronomie', 'id': 'Gastronomie'},
    {'emoji': '⚡', 'label': 'City Break Express', 'id': 'CityBreak'},
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 4.8.h.clamp(36.0, 42.0),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        itemCount: vibes.length,
        separatorBuilder: (_, __) => SizedBox(width: 2.w.clamp(7.0, 10.0)),
        itemBuilder: (context, index) {
          final item = vibes[index];
          return GestureDetector(
            onTap: () => onSelectVibe(item['id']!),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: 3.5.w.clamp(12.0, 16.0),
                vertical: 0.8.h.clamp(6.0, 9.0),
              ),
              decoration: BoxDecoration(
                color: VoyagoColors.surface,
                borderRadius: BorderRadius.circular(19),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.07),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(item['emoji']!, style: TextStyle(fontSize: 11.5.sp.clamp(13.0, 15.0))),
                  const SizedBox(width: 6),
                  Text(
                    item['label']!,
                    style: TextStyle(
                      color: VoyagoColors.text,
                      fontSize: 10.sp.clamp(11.5, 13.0),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Bannière XP de l'utilisateur avec design épuré Dribbble
class _UserBanner extends ConsumerWidget {
  final String userId;
  const _UserBanner({required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(profileProvider(userId));
    final badgeSize = 11.w.clamp(40.0, 46.0);

    return profileAsync.when(
      data: (profile) {
        final xpInLevel = profile.xp % 100;
        final progress = (xpInLevel / 100.0).clamp(0.0, 1.0);

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => context.go('/xp-rewards'),
          child: Container(
            padding: EdgeInsets.all(4.w.clamp(14.0, 18.0)),
            decoration: BoxDecoration(
              color: VoyagoColors.surface,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: VoyagoColors.primary.withValues(alpha: 0.25),
              ),
              boxShadow: [
                BoxShadow(
                  color: VoyagoColors.primary.withValues(alpha: 0.05),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    // Badge Niveau
                    Container(
                      width: badgeSize,
                      height: badgeSize,
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [VoyagoColors.primaryLight, VoyagoColors.primary],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(13),
                        boxShadow: [
                          BoxShadow(
                            color: VoyagoColors.primary.withValues(alpha: 0.4),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        '${profile.level}',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 14.sp.clamp(16.0, 20.0),
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    SizedBox(width: 3.w.clamp(10.0, 14.0)),

                    // Détails niveau & XP
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                'Niveau ${profile.level}',
                                style: TextStyle(
                                  color: VoyagoColors.text,
                                  fontSize: 12.sp.clamp(14.0, 16.0),
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                '$xpInLevel / 100 XP',
                                style: TextStyle(
                                  color: VoyagoColors.primary,
                                  fontSize: 10.5.sp.clamp(12.0, 13.0),
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            '${100 - xpInLevel} XP restants pour le niveau ${profile.level + 1}',
                            style: TextStyle(
                              color: VoyagoColors.muted,
                              fontSize: 10.sp.clamp(11.0, 12.5),
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Badge Streak si actif
                    if (profile.streak > 0) ...[
                      SizedBox(width: 2.5.w.clamp(8.0, 12.0)),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 2.5.w.clamp(8.0, 12.0),
                          vertical: 0.7.h.clamp(5.0, 8.0),
                        ),
                        decoration: BoxDecoration(
                          color: VoyagoColors.orange.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: VoyagoColors.orange.withValues(alpha: 0.35),
                          ),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text('🔥', style: TextStyle(fontSize: 13)),
                            const SizedBox(width: 4),
                            Text(
                              '${profile.streak} j',
                              style: TextStyle(
                                color: VoyagoColors.orange,
                                fontSize: 10.sp.clamp(11.0, 13.0),
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
                SizedBox(height: 1.4.h.clamp(10.0, 14.0)),

                // Barre de progression dégradée
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 1.h.clamp(7.0, 9.0),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    valueColor: const AlwaysStoppedAnimation<Color>(
                      VoyagoColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
      loading: () => Container(
        height: 8.h.clamp(68.0, 78.0),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VoyagoColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: VoyagoColors.cardBorder),
        ),
        child: const Center(
          child: SizedBox(
            height: 4,
            child: LinearProgressIndicator(),
          ),
        ),
      ),
      error: (_, __) => const SizedBox.shrink(),
    );
  }
}

/// Bannière de connexion pour utilisateur non authentifié
class _AuthBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _AuthBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(4.w.clamp(14.0, 20.0)),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            VoyagoColors.primaryDark.withValues(alpha: 0.9),
            VoyagoColors.primary.withValues(alpha: 0.75),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: VoyagoColors.primary.withValues(alpha: 0.3),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 11.w.clamp(40.0, 48.0),
            height: 11.w.clamp(40.0, 48.0),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: const Text('🦜', style: TextStyle(fontSize: 24)),
          ),
          SizedBox(width: 3.5.w.clamp(12.0, 16.0)),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Sauvegardez vos voyages !',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 12.sp.clamp(14.0, 16.0),
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Connectez-vous pour débloquer l\'XP et les badges',
                  style: TextStyle(color: Colors.white70, fontSize: 10.sp.clamp(11.0, 12.5)),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          ElevatedButton(
            onPressed: onTap,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: VoyagoColors.primaryDark,
              elevation: 0,
              padding: EdgeInsets.symmetric(
                horizontal: 3.w.clamp(10.0, 14.0),
                vertical: 1.h.clamp(8.0, 11.0),
              ),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: Text(
              'Connexion',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 10.5.sp.clamp(12.0, 13.0),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Carte Héro IA principale avec design Dribbble pro & épuré
/// Carte Héro IA avec Globe 3D terrestre en rotation continue dans l'angle supérieur
class _HeroSection extends StatefulWidget {
  final VoidCallback onStart;
  const _HeroSection({required this.onStart});

  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> {
  late FlutterEarthGlobeController _globeController;

  @override
  void initState() {
    super.initState();

    _globeController = FlutterEarthGlobeController(
      rotationSpeed: 0.08,
      isRotating: true,
      isZoomEnabled: false,
      zoom: 0.0,
      surface: const AssetImage('assets/globe/2k_earth-day.jpg'),
      nightSurface: const AssetImage('assets/globe/2k_earth-night.jpg'),
      showAtmosphere: false,
      surfaceLightingEnabled: true,
      lightIntensity: 0.85,
      ambientLight: 0.55,
    );

    _globeController.onLoaded = () {
      if (mounted) {
        _globeController.addPoint(
          Point(
            id: 'paris',
            coordinates: const GlobeCoordinates(48.8566, 2.3522),
            style: const PointStyle(color: Color(0xFF58CC02), size: 5),
          ),
        );
        _globeController.addPoint(
          Point(
            id: 'tokyo',
            coordinates: const GlobeCoordinates(35.6762, 139.6503),
            style: const PointStyle(color: Color(0xFF1CB0F6), size: 5),
          ),
        );
        _globeController.addPointConnection(
          PointConnection(
            id: 'route_globe',
            start: const GlobeCoordinates(48.8566, 2.3522),
            end: const GlobeCoordinates(35.6762, 139.6503),
            isMoving: true,
            style: const PointConnectionStyle(
              color: Color(0xFF58CC02),
              lineWidth: 2.0,
            ),
          ),
          animateDraw: true,
          animateDrawDuration: const Duration(seconds: 3),
        );
        _globeController.startRotation();
      }
    };
  }

  @override
  void dispose() {
    try {
      _globeController.dispose();
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mascotSize = 18.w.clamp(70.0, 84.0);
    // Globe 3D agrandi pour descendre jusqu'au bouton 'Commencer un voyage'
    final globeBoxSize = 92.w.clamp(350.0, 420.0);
    final globeRadius = (globeBoxSize * 0.45).clamp(155.0, 190.0);

    return Container(
      decoration: BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: VoyagoColors.primary.withValues(alpha: 0.35),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: VoyagoColors.primary.withValues(alpha: 0.12),
            blurRadius: 28,
            offset: const Offset(0, 8),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Couche 1 : Globe 3D terrestre interactif en rotation descendant jusqu'au bouton CTA
            Positioned(
              top: -50,
              right: -50,
              width: globeBoxSize,
              height: globeBoxSize,
              child: IgnorePointer(
                child: MediaQuery(
                  data: MediaQuery.of(context).copyWith(
                    size: Size(globeBoxSize, globeBoxSize),
                  ),
                  child: FlutterEarthGlobe(
                    controller: _globeController,
                    radius: globeRadius,
                  ),
                ),
              ),
            ),

            // Couche 2 : Dégradé doux préservant la netteté de l'angle tout en protégeant les textes
            Positioned.fill(
              child: IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        VoyagoColors.surface.withValues(alpha: 0.25),
                        VoyagoColors.surface.withValues(alpha: 0.88),
                      ],
                      stops: const [0.0, 0.52, 0.90],
                    ),
                  ),
                ),
              ),
            ),

            // Contenu principal au premier plan
            Padding(
              padding: EdgeInsets.all(5.5.w.clamp(20.0, 26.0)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  // Mascotte / Symbole avec halo en verre dépoli devant le globe
                  Container(
                    width: mascotSize,
                    height: mascotSize,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xCC1A1D27),
                      border: Border.all(
                        color: VoyagoColors.primary.withValues(alpha: 0.35),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: VoyagoColors.primary.withValues(alpha: 0.35),
                          blurRadius: 20,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: Text('🦜', style: TextStyle(fontSize: 28.sp.clamp(40.0, 50.0))),
                  ),
                  SizedBox(height: 1.8.h.clamp(14.0, 18.0)),

                  // Titre animé avec AnimatedTextKit (Typewriter)
                  Container(
                    constraints: BoxConstraints(minHeight: 4.h.clamp(30.0, 36.0)),
                    alignment: Alignment.center,
                    child: AnimatedTextKit(
                      repeatForever: true,
                      pause: const Duration(milliseconds: 2400),
                      displayFullTextOnTap: true,
                      stopPauseOnTap: false,
                      animatedTexts: [
                        TypewriterAnimatedText(
                          'Voyage. Joue. Découvre.',
                          textAlign: TextAlign.center,
                          textStyle: TextStyle(
                            color: VoyagoColors.text,
                            fontSize: 18.sp.clamp(22.0, 26.0),
                            fontWeight: FontWeight.w900,
                            letterSpacing: -0.5,
                            height: 1.2,
                            shadows: [
                              Shadow(
                                color: Colors.black.withValues(alpha: 0.8),
                                blurRadius: 12,
                              ),
                            ],
                          ),
                          speed: const Duration(milliseconds: 85),
                          cursor: '|',
                        ),
                      ],
                    ),
                  ),
                  SizedBox(height: 1.h.clamp(6.0, 10.0)),

                  // Sous-titre épuré
                  Text(
                    'Laissez l\'IA concevoir votre itinéraire personnalisé, météo en direct et étapes interactives en quelques secondes.',
                    style: TextStyle(
                      color: VoyagoColors.muted,
                      fontSize: 11.sp.clamp(12.5, 14.0),
                      height: 1.5,
                      shadows: [
                        Shadow(
                          color: Colors.black.withValues(alpha: 0.8),
                          blurRadius: 8,
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 2.2.h.clamp(18.0, 24.0)),

                  // Bouton principal d'action
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: widget.onStart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: VoyagoColors.primary,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(vertical: 1.8.h.clamp(14.0, 18.0)),
                        elevation: 4,
                        shadowColor: VoyagoColors.primary.withValues(alpha: 0.5),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.explore_rounded, size: 20),
                          const SizedBox(width: 8),
                          Text(
                            'Commencer un voyage',
                            style: TextStyle(
                              fontSize: 12.5.sp.clamp(15.0, 17.0),
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(height: 1.5.h.clamp(12.0, 16.0)),

                  // Caractéristiques sous forme de pills
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      _HeroFeatureTag(icon: Icons.speed_rounded, text: 'Ultra rapide'),
                      SizedBox(width: 12),
                      _HeroFeatureTag(icon: Icons.map_outlined, text: 'Carte interactive'),
                      SizedBox(width: 12),
                      _HeroFeatureTag(icon: Icons.wb_sunny_outlined, text: 'Météo en direct'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroFeatureTag extends StatelessWidget {
  final IconData icon;
  final String text;
  const _HeroFeatureTag({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 12, color: VoyagoColors.muted),
        const SizedBox(width: 4),
        Text(
          text,
          style: TextStyle(
            color: VoyagoColors.muted,
            fontSize: 9.5.sp.clamp(10.5, 12.0),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

/// Carte Tableau de Bord & Carte Leaflet interactive
class _DashboardMapCard extends StatelessWidget {
  final VoidCallback onTap;
  const _DashboardMapCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    final mapIconSize = 12.w.clamp(44.0, 52.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(4.w.clamp(14.0, 18.0)),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              VoyagoColors.primary.withValues(alpha: 0.16),
              VoyagoColors.blue.withValues(alpha: 0.08),
              VoyagoColors.surface,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: VoyagoColors.primary.withValues(alpha: 0.35),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: VoyagoColors.primary.withValues(alpha: 0.06),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icône avec badge radar
            Container(
              width: mapIconSize,
              height: mapIconSize,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [VoyagoColors.primaryLight, VoyagoColors.primary],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: VoyagoColors.primary.withValues(alpha: 0.45),
                    blurRadius: 10,
                  ),
                ],
              ),
              alignment: Alignment.center,
              child: const Icon(Icons.map_rounded, color: Colors.white, size: 26),
            ),
            SizedBox(width: 3.5.w.clamp(12.0, 16.0)),

            // Titre & Sous-titre
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'Tableau de Bord & Carte',
                        style: TextStyle(
                          color: VoyagoColors.text,
                          fontSize: 12.sp.clamp(14.0, 16.0),
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: VoyagoColors.primary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(
                            color: VoyagoColors.primaryLight,
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Carte Leaflet interactive, météo en direct et itinéraire',
                    style: TextStyle(
                      color: VoyagoColors.muted,
                      fontSize: 10.sp.clamp(11.0, 12.5),
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),

            // Flèche d'accès
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: VoyagoColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.arrow_forward_ios_rounded,
                color: VoyagoColors.primary,
                size: 14,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Carte Explorer moderne avec badge, icône lumineuse et dégradé subtil
class _ExplorerCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final String badge;
  final Color color;
  final VoidCallback onTap;

  const _ExplorerCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final iconBoxSize = 11.w.clamp(40.0, 46.0);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: EdgeInsets.all(4.w.clamp(14.0, 18.0)),
        decoration: BoxDecoration(
          color: VoyagoColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: color.withValues(alpha: 0.25),
            width: 1.2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.05),
              blurRadius: 14,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Conteneur d'icône avec halo lumineux
                Container(
                  width: iconBoxSize,
                  height: iconBoxSize,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: color.withValues(alpha: 0.2),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Icon(icon, color: color, size: 22),
                ),

                // Badge de catégorie
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: color.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Text(
                    badge,
                    style: TextStyle(
                      color: color,
                      fontSize: 9.sp.clamp(10.0, 11.5),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 1.5.h.clamp(10.0, 14.0)),
            Text(
              title,
              style: TextStyle(
                color: VoyagoColors.text,
                fontSize: 12.sp.clamp(14.0, 16.0),
                fontWeight: FontWeight.w800,
                letterSpacing: -0.2,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(
                color: VoyagoColors.muted,
                fontSize: 9.5.sp.clamp(11.0, 12.5),
                height: 1.3,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }
}
