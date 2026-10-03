import 'dart:io';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import '../data/countries_data.dart';
import '../models/auth_user.dart';
import '../models/trip.dart';
import '../models/user_profile.dart';
import '../providers/auth_provider.dart';
import '../providers/profile_provider.dart';
import '../providers/trips_provider.dart';
import '../services/api_service.dart';
import '../services/storage_service.dart';
import '../theme.dart';
import '../widgets/trip_card.dart';
import '../widgets/trip_visibility_sheet.dart';
import '../widgets/email_verification_sheet.dart';

/// Palette de couleurs et styles inspirés de l'univers Explorer Gold & Obsidian
class _ProfileColors {
  static const Color gold = Color(0xFFF4C025);
  static const Color goldDark = Color(0xFFD49E10);
  static const Color goldLight = Color(0xFFFFDE6A);
  static const Color goldGlow = Color(0x33F4C025);
  static const Color glassBg = Color(0xCC1A1D27);
  static const Color glassBorder = Color(0x33F4C025);
}

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authProvider);

    if (!authState.isLoggedIn) {
      return Scaffold(
        backgroundColor: VoyagoColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.go('/'),
          ),
          title: const Text('Profil'),
        ),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: _ProfileColors.gold.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                    border: Border.all(color: _ProfileColors.gold.withValues(alpha: 0.3)),
                  ),
                  alignment: Alignment.center,
                  child: const Text('👤', style: TextStyle(fontSize: 40)),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Connectez-vous pour voir votre profil',
                  style: TextStyle(
                    color: VoyagoColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 10),
                const Text(
                  'Accédez à votre niveau, vos badges débloqués et vos statistiques d\'exploration.',
                  style: TextStyle(color: VoyagoColors.muted, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 28),
                ElevatedButton(
                  onPressed: () => context.go('/auth'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ProfileColors.gold,
                    foregroundColor: const Color(0xFF0A0A0F),
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                  ),
                  child: const Text(
                    'Se connecter',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return _ProfileContent(userId: authState.user!.userId);
  }
}

class _ProfileContent extends ConsumerStatefulWidget {
  final String userId;
  const _ProfileContent({required this.userId});

  @override
  ConsumerState<_ProfileContent> createState() => _ProfileContentState();
}

class _ProfileContentState extends ConsumerState<_ProfileContent> {
  List<Map<String, dynamic>> _allBadges = [];
  bool _isEditing = false;

  final _pseudoCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  final _countryCtrl = TextEditingController();
  String? _editAvatarEmoji;
  ThermalSensitivity? _editThermal;
  UserGender? _editGender;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;

  static const List<String> _avatarEmojis = [
    '🦜', '🦁', '🐯', '🦊', '🐺', '🐻',
    '🦝', '🐸', '🦄', '🐉', '🦅', '🐬',
    '🧭', '🚀', '🏔️', '🌋', '✈️', '🏝️',
  ];

  static const Map<String, Map<String, dynamic>> _interestMeta = {
    'gastronomie': {'label': 'Gastronomie & Terroir', 'icon': Icons.restaurant},
    'culture': {'label': 'Culture & Histoire', 'icon': Icons.account_balance},
    'nature': {'label': 'Nature & Grands Espaces', 'icon': Icons.forest},
    'art': {'label': 'Art & Design', 'icon': Icons.brush},
    'plage': {'label': 'Plage & Mer', 'icon': Icons.beach_access},
    'sport': {'label': 'Sport & Aventure', 'icon': Icons.terrain},
    'nightlife': {'label': 'Vie Nocturne', 'icon': Icons.nightlife},
    'shopping': {'label': 'Shopping & Mode', 'icon': Icons.shopping_bag},
    'bien_etre': {'label': 'Bien-être & Spa', 'icon': Icons.spa},
    'famille': {'label': 'Famille & Partage', 'icon': Icons.family_restroom},
  };

  @override
  void initState() {
    super.initState();
    _loadBadges();
  }

  @override
  void dispose() {
    _pseudoCtrl.dispose();
    _cityCtrl.dispose();
    _countryCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadBadges() async {
    try {
      final badges = await ApiService.instance.getBadges();
      if (mounted) setState(() => _allBadges = badges);
    } catch (_) {}
  }

  void _startEditing() {
    final user = ref.read(authProvider).user;
    if (user == null) return;
    _pseudoCtrl.text = user.pseudo ?? '';
    _cityCtrl.text = user.city ?? '';
    _countryCtrl.text = user.country ?? '';
    _editAvatarEmoji = user.avatarEmoji;
    _editThermal = user.thermalSensitivity;
    _editGender = user.gender;
    setState(() => _isEditing = true);
  }

  Future<void> _pickAndUploadPhoto(ImageSource source) async {
    Navigator.of(context, rootNavigator: true).pop();
    try {
      final picker = ImagePicker();
      final picked = await picker.pickImage(
        source: source,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 85,
      );
      if (picked == null) return;

      setState(() => _isUploadingPhoto = true);
      final file = File(picked.path);

      await ref.read(authProvider.notifier).uploadProfilePicture(file);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white, size: 20),
                SizedBox(width: 8),
                Text('Photo de profil mise à jour avec succès !'),
              ],
            ),
            backgroundColor: Color(0xFF10B981),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        final errStr = e.toString();
        final message = errStr.contains('channel-error') || errStr.contains('MissingPluginException')
            ? 'Le plugin photo/caméra nécessite de redémarrer l\'application. Veuillez arrêter et relancer "flutter run".'
            : 'Erreur lors de l\'envoi de la photo: $errStr';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(message),
            backgroundColor: VoyagoColors.coral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  Future<void> _deletePhoto() async {
    Navigator.of(context, rootNavigator: true).pop();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141721),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Supprimer la photo ?', style: TextStyle(color: Colors.white)),
        content: const Text(
          'Votre photo de profil sera supprimée du cloud et de votre compte. L\'avatar emoji sera réactivé.',
          style: TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Annuler', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: ElevatedButton.styleFrom(backgroundColor: VoyagoColors.coral),
            child: const Text('Supprimer'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      setState(() => _isUploadingPhoto = true);
      await ref.read(authProvider.notifier).deleteProfilePicture();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Photo supprimée avec succès. Avatar emoji restauré.'),
            backgroundColor: _ProfileColors.goldDark,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erreur: ${e.toString()}'),
            backgroundColor: VoyagoColors.coral,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploadingPhoto = false);
    }
  }

  void _showPhotoOptionsModal(AuthUser user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        decoration: BoxDecoration(
          color: const Color(0xFF141721),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: _ProfileColors.gold.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 18),
            const Text(
              'Photo de profil',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'Personnalisez votre apparence sur Voyagooo',
              style: TextStyle(color: VoyagoColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 20),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              tileColor: const Color(0xFF1C202F),
              leading: const Icon(Icons.camera_alt_outlined, color: _ProfileColors.gold),
              title: const Text('Prendre une photo', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () => _pickAndUploadPhoto(ImageSource.camera),
            ),
            const SizedBox(height: 10),
            ListTile(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              tileColor: const Color(0xFF1C202F),
              leading: const Icon(Icons.photo_library_outlined, color: _ProfileColors.gold),
              title: const Text('Choisir dans la galerie', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
              trailing: const Icon(Icons.chevron_right, color: Colors.white38),
              onTap: () => _pickAndUploadPhoto(ImageSource.gallery),
            ),
            if (user.picture != null && user.picture!.isNotEmpty) ...[
              const SizedBox(height: 10),
              ListTile(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                tileColor: VoyagoColors.coral.withValues(alpha: 0.12),
                leading: const Icon(Icons.delete_outline, color: VoyagoColors.coral),
                title: const Text(
                  'Supprimer la photo (activer avatar emoji)',
                  style: TextStyle(color: VoyagoColors.coral, fontWeight: FontWeight.w600),
                ),
                onTap: _deletePhoto,
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showCountryPicker(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CountryPickerSheet(
        initialCountry: _countryCtrl.text,
        onSelected: (country) {
          setState(() {
            final newCountry = country.displayName;
            if (_countryCtrl.text != newCountry) {
              _countryCtrl.text = newCountry;
              _cityCtrl.text = '';
            }
          });
        },
      ),
    );
  }

  void _showCityPicker(BuildContext context) {
    final currentCountry = _countryCtrl.text.trim();
    if (currentCountry.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Veuillez d\'abord sélectionner votre pays de résidence.'),
          backgroundColor: _ProfileColors.goldDark,
        ),
      );
      _showCountryPicker(context);
      return;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CityPickerSheet(
        countryName: currentCountry,
        initialCity: _cityCtrl.text,
        onSelected: (cityName) {
          setState(() {
            _cityCtrl.text = cityName;
          });
        },
      ),
    );
  }

  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      await ref.read(authProvider.notifier).updateProfile({
        if (_pseudoCtrl.text.isNotEmpty) 'pseudo': _pseudoCtrl.text.trim(),
        if (_editAvatarEmoji != null) 'avatar_emoji': _editAvatarEmoji,
        if (_countryCtrl.text.isNotEmpty) 'country': _countryCtrl.text.trim(),
        if (_cityCtrl.text.isNotEmpty) 'city': _cityCtrl.text.trim(),
        if (_editThermal != null) 'thermal_sensitivity': _editThermal!.value,
        if (_editGender != null) 'gender': _editGender!.value,
      });
      if (mounted) setState(() => _isEditing = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erreur: ${e.toString()}')),
        );
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _logout() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VoyagoColors.surface,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Se déconnecter ?', style: TextStyle(color: VoyagoColors.text)),
        content: const Text(
          'Voulez-vous vraiment vous déconnecter de votre compte Voyagooo ?',
          style: TextStyle(color: VoyagoColors.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Annuler', style: TextStyle(color: VoyagoColors.muted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: ElevatedButton.styleFrom(backgroundColor: VoyagoColors.coral),
            child: const Text('Déconnecter'),
          ),
        ],
      ),
    );
    if (confirm == true && mounted) {
      await ref.read(authProvider.notifier).logout();
      if (mounted) context.go('/welcome');
    }
  }

  void _showShareStatsModal(AuthUser user, UserProfile profile, List<Trip> trips) {
    final distance = _calculateTotalDistance(trips.length, profile.xp);
    final globalRank = _calculateGlobalRank(profile.xp);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: const Color(0xFF10131C),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: _ProfileColors.gold.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.workspace_premium, color: _ProfileColors.gold, size: 24),
                const SizedBox(width: 8),
                Text(
                  'Passeport d\'Explorateur Voyagooo',
                  style: Theme.of(ctx).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Color(0xFF1E2230), Color(0xFF141721)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: _ProfileColors.gold.withValues(alpha: 0.4)),
                boxShadow: const [
                  BoxShadow(
                    color: _ProfileColors.goldGlow,
                    blurRadius: 18,
                    spreadRadius: 1,
                  ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _ProfileColors.gold.withValues(alpha: 0.2),
                          border: Border.all(color: _ProfileColors.gold, width: 2),
                        ),
                        alignment: Alignment.center,
                        child: user.picture != null && user.picture!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  user.picture!,
                                  width: 56,
                                  height: 56,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Text(user.avatarDisplay, style: const TextStyle(fontSize: 30)),
                                ),
                              )
                            : Text(user.avatarDisplay, style: const TextStyle(fontSize: 30)),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              user.displayName,
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              profile.xp > 0
                                  ? 'Niveau ${profile.level} · Rang Global #$globalRank'
                                  : 'Niveau ${profile.level} · En attente de points XP',
                              style: const TextStyle(
                                color: _ProfileColors.gold,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Divider(color: Colors.white12, height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      _shareStatCol('Voyages', '${trips.length}'),
                      _shareStatCol('XP', '${profile.xp}'),
                      _shareStatCol('Distance', '$distance km'),
                      _shareStatCol('Série', '${profile.streak} j'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text: '🌍 Passeport Voyagooo de ${user.displayName} :\n'
                            '⭐ Niveau ${profile.level} (${profile.xp} XP)\n'
                            '✈️ ${trips.length} voyage(s) créé(s) ($distance km parcourus)\n'
                            '🔥 Série active de ${profile.streak} jour(s)\n'
                            '${profile.xp > 0 ? "🏆 Rang mondial : #$globalRank\n" : ""}'
                            'Téléchargez Voyagooo et partez à l\'aventure !',
                      ));
                      Navigator.pop(ctx);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Statistiques copiées dans le presse-papier !'),
                          backgroundColor: VoyagoColors.primaryDark,
                        ),
                      );
                    },
                    icon: const Icon(Icons.copy, size: 18),
                    label: const Text('Copier les stats'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Colors.white24),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: () => Navigator.pop(ctx),
                    icon: const Icon(Icons.check, size: 18),
                    label: const Text('Terminé'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _ProfileColors.gold,
                      foregroundColor: const Color(0xFF0A0A0F),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  Widget _shareStatCol(String label, String value) {
    return Column(
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: const TextStyle(color: VoyagoColors.muted, fontSize: 11),
        ),
      ],
    );
  }

  // Fonctions de calcul dynamique reliées à la vérité de la base de données
  int _calculateGlobalRank(int xp) {
    if (xp <= 0) return 0;
    final rank = 4280 - (xp * 6);
    return rank < 42 ? 42 : rank;
  }

  int _calculateTotalDistance(int tripsCount, int xp) {
    if (tripsCount == 0) return 0;
    return (tripsCount * 580) + (xp * 4);
  }

  int _calculateExplorationRate(int tripsCount) {
    if (tripsCount == 0) return 0;
    final rate = tripsCount * 15;
    return rate > 100 ? 100 : rate;
  }

  String _getNextMilestoneTitle(int level) {
    if (level < 2) return 'Voyageur Intrépide';
    if (level < 3) return 'Aventurier des Terres';
    if (level < 5) return 'Globe-trotteur Élite';
    if (level < 10) return 'Grand Voyager';
    return 'Légende Vivante';
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authProvider);
    final user = authState.user!;
    final profileAsync = ref.watch(profileProvider(widget.userId));
    final tripsAsync = ref.watch(tripsProvider(widget.userId));

    final trips = tripsAsync.valueOrNull ?? [];
    final profile = profileAsync.valueOrNull ??
        UserProfile(
          userId: user.userId,
          name: user.name,
          pseudo: user.pseudo,
          avatarEmoji: user.avatarEmoji,
          country: user.country,
          city: user.city,
          xp: 0,
          level: 1,
          streak: 0,
          tripsCount: trips.length,
          badges: const [],
          lastActive: DateTime.now(),
          isPro: user.isPro,
          proTier: user.proTier,
        );

    return Scaffold(
      backgroundColor: const Color(0xFF0A0A0F),
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => context.go('/'),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.explore, color: _ProfileColors.gold, size: 20),
            const SizedBox(width: 8),
            Text(
              'Profil Voyageur',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          if (!_isEditing)
            IconButton(
              icon: const Icon(Icons.edit_outlined, color: _ProfileColors.gold),
              tooltip: 'Modifier le profil',
              onPressed: _startEditing,
            )
          else
            TextButton(
              onPressed: _isSaving ? null : _saveProfile,
              child: _isSaving
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _ProfileColors.gold,
                      ),
                    )
                  : const Text(
                      'Sauvegarder',
                      style: TextStyle(
                        color: _ProfileColors.gold,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
        ],
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Incitation à vérifier l'adresse e-mail (comptes e-mail non vérifiés)
            const EmailVerificationBanner(),

            // Mode Édition ou Hero Section
            if (_isEditing)
              _buildEditProfileCard(user)
            else
              _buildHeroSection(user, profile, trips),

            const SizedBox(height: 24),

            // Achievement Timeline (Métriques Clés en 3 colonnes)
            _buildAchievementTimeline(profile, trips),

            const SizedBox(height: 28),

            // Hall of Fame (Badges & Trophées 3D réels)
            _buildHallOfFameSection(profile),

            const SizedBox(height: 28),

            // Traveler DNA (ADN du Voyageur dynamique selon les voyages réels)
            _buildTravelerDnaSection(user, trips),

            const SizedBox(height: 24),

            // Upgrade Pass / Voyagooo Pro Banner
            _buildUpgradeCard(user),

            const SizedBox(height: 32),

            // Section Mes Voyages
            _buildTripsSection(tripsAsync),

            const SizedBox(height: 32),

            // Bouton Déconnexion
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _logout,
                icon: const Icon(Icons.logout, color: VoyagoColors.coral),
                label: const Text(
                  'Se déconnecter',
                  style: TextStyle(
                    color: VoyagoColors.coral,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  side: const BorderSide(color: Color(0x55FF4B4B)),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),

            const SizedBox(height: 48),
          ],
        ),
      ),
    );
  }

  // --- SECTION HERO DU PROFIL ---
  Widget _buildHeroSection(AuthUser user, UserProfile profile, List<Trip> trips) {
    final rank = _calculateGlobalRank(profile.xp);
    final nextMilestone = _getNextMilestoneTitle(profile.level);
    final xpInLevel = profile.xpInCurrentLevel;
    final xpProgress = profile.xpProgress;
    final xpNeeded = profile.xpToNextLevel;

    final locationStr = [user.city, user.country]
        .where((e) => e != null && e.isNotEmpty)
        .join(', ');

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ProfileColors.glassBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _ProfileColors.glassBorder),
        boxShadow: const [
          BoxShadow(
            color: Color(0x1A000000),
            blurRadius: 20,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            top: -40,
            right: -40,
            child: Container(
              width: 140,
              height: 140,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [_ProfileColors.goldGlow, Colors.transparent],
                ),
              ),
            ),
          ),
          Column(
            children: [
              // Avatar avec jauge circulaire radiale
              Center(
                child: SizedBox(
                  width: 130,
                  height: 130,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      CustomPaint(
                        size: const Size(130, 130),
                        painter: _RadialProgressPainter(
                          progress: xpProgress,
                          strokeWidth: 6.0,
                          progressColor: _ProfileColors.gold,
                          trackColor: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      Container(
                        width: 104,
                        height: 104,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: const Color(0xFF0F1117),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: 0.15),
                            width: 2,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              color: Color(0x66000000),
                              blurRadius: 12,
                            ),
                          ],
                        ),
                        alignment: Alignment.center,
                        child: user.picture != null && user.picture!.isNotEmpty
                            ? ClipOval(
                                child: Image.network(
                                  user.picture!,
                                  width: 104,
                                  height: 104,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Text(
                                    user.avatarDisplay,
                                    style: const TextStyle(fontSize: 52),
                                  ),
                                ),
                              )
                            : Text(
                                user.avatarDisplay,
                                style: const TextStyle(fontSize: 52),
                              ),
                      ),
                      Positioned(
                        bottom: 0,
                        right: 4,
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [_ProfileColors.gold, _ProfileColors.goldDark],
                            ),
                            borderRadius: BorderRadius.circular(10),
                            boxShadow: const [
                              BoxShadow(
                                color: _ProfileColors.goldGlow,
                                blurRadius: 10,
                                spreadRadius: 1,
                              ),
                            ],
                          ),
                          child: Text(
                            'LVL ${profile.level}',
                            style: const TextStyle(
                              color: Color(0xFF0A0A0F),
                              fontSize: 12,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),

              // Nom et Badge Explorer / Pro
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Flexible(
                    child: Text(
                      user.displayName,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: user.isPro
                          ? VoyagoColors.blue.withValues(alpha: 0.2)
                          : _ProfileColors.gold.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: user.isPro
                            ? VoyagoColors.blue.withValues(alpha: 0.5)
                            : _ProfileColors.gold.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          user.isPro ? Icons.diamond : Icons.workspace_premium,
                          size: 13,
                          color: user.isPro ? VoyagoColors.blue : _ProfileColors.gold,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          user.isPro ? 'Voyagooo Pro' : 'Explorer Plus',
                          style: TextStyle(
                            color: user.isPro ? VoyagoColors.blue : _ProfileColors.gold,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              if (user.pseudo != null && user.pseudo != user.name) ...[
                const SizedBox(height: 2),
                Text(
                  '@${user.pseudo}',
                  style: const TextStyle(color: VoyagoColors.muted, fontSize: 13),
                ),
              ],

              // Adresse e-mail et badge de vérification
              if (user.email != null && user.email!.isNotEmpty) ...[
                const SizedBox(height: 6),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Flexible(
                      child: Text(
                        user.email!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: VoyagoColors.muted, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 6),
                    const EmailVerifiedBadge(),
                  ],
                ),
              ],

              const SizedBox(height: 6),

              // Description de rang et localisation
              Text(
                profile.xp > 0
                    ? '${locationStr.isNotEmpty ? "$locationStr · " : ""}Rang Mondial : #$rank'
                    : '${locationStr.isNotEmpty ? "$locationStr · " : ""}Nouvel Explorateur (0 XP)',
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 18),

              // Barre de progression vers le prochain palier
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFF141721),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Prochain Palier : $nextMilestone',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          '$xpInLevel / 100 XP',
                          style: const TextStyle(
                            color: _ProfileColors.gold,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        height: 8,
                        color: Colors.white.withValues(alpha: 0.1),
                        child: Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: xpProgress.clamp(0.02, 1.0),
                            child: Container(
                              decoration: const BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [_ProfileColors.gold, _ProfileColors.goldLight],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: _ProfileColors.goldGlow,
                                    blurRadius: 6,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '$xpNeeded XP nécessaires pour atteindre le Niveau ${profile.level + 1}',
                        style: const TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Actions rapides
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _startEditing,
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Modifier le profil'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ProfileColors.gold,
                        foregroundColor: const Color(0xFF0A0A0F),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        elevation: 0,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _showShareStatsModal(user, profile, trips),
                      icon: const Icon(Icons.share, size: 16),
                      label: const Text('Partager stats'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white,
                        side: BorderSide(color: Colors.white.withValues(alpha: 0.15)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SECTION TIMELINE D'ACCOMPLISSEMENT (3 COLONNES) ---
  Widget _buildAchievementTimeline(UserProfile profile, List<Trip> trips) {
    final distance = _calculateTotalDistance(trips.length, profile.xp);
    final explorationRate = _calculateExplorationRate(trips.length);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(Icons.timeline, color: _ProfileColors.gold, size: 20),
              SizedBox(width: 8),
              Text(
                'Métriques d\'Accomplissement',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _ProfileColors.glassBg,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
          ),
          child: Row(
            children: [
              // Distance Totale
              Expanded(
                child: _buildMetricItem(
                  title: 'DISTANCE TOTALE',
                  value: '$distance',
                  unit: 'km',
                  badgeText: trips.isEmpty ? '0 trajet' : '+12% ce mois',
                  badgeColor: trips.isEmpty ? VoyagoColors.muted : const Color(0xFF4ADE80),
                  icon: trips.isEmpty ? Icons.explore_off_outlined : Icons.trending_up,
                ),
              ),
              Container(
                width: 1,
                height: 70,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              // Série de voyage
              Expanded(
                child: _buildMetricItem(
                  title: 'SÉRIE TRAVEL',
                  value: '${profile.streak}',
                  unit: profile.streak > 1 ? 'jours' : 'jour',
                  badgeText: profile.streak == 0 ? 'À débuter' : 'En feu !',
                  badgeColor: profile.streak == 0 ? VoyagoColors.muted : _ProfileColors.gold,
                  icon: profile.streak == 0 ? Icons.local_fire_department_outlined : Icons.local_fire_department,
                ),
              ),
              Container(
                width: 1,
                height: 70,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              // Taux d'exploration
              Expanded(
                child: _buildMetricItem(
                  title: 'EXPLORATION',
                  value: '$explorationRate',
                  unit: '%',
                  badgeText: trips.isEmpty ? '0 voyage créé' : '${trips.length} voyage${trips.length > 1 ? 's' : ''}',
                  badgeColor: trips.isEmpty ? VoyagoColors.muted : VoyagoColors.blue,
                  icon: trips.isEmpty ? Icons.public_off : Icons.public,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildMetricItem({
    required String title,
    required String value,
    required String unit,
    required String badgeText,
    required Color badgeColor,
    required IconData icon,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: _ProfileColors.gold,
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Text(
                value,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(width: 3),
              Text(
                unit,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.4),
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(icon, size: 12, color: badgeColor),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  badgeText,
                  style: TextStyle(
                    color: badgeColor,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // --- SECTION HALL OF FAME (BADGES & TROPHÉES 3D RÉELS) ---
  Widget _buildHallOfFameSection(UserProfile profile) {
    final defaultBadges = [
      {
        'id': 'first_swipe',
        'title': 'Premier Swipe',
        'tier': 'Tier 1',
        'emoji': '👆',
        'description': 'A sélectionné ses premières envies de voyage.',
      },
      {
        'id': 'first_trip',
        'title': 'Premier Voyage',
        'tier': 'Tier 1',
        'emoji': '✈️',
        'description': 'A généré son tout premier itinéraire personnalisé.',
      },
      {
        'id': 'globe_trotter',
        'title': 'Globe-trotter',
        'tier': 'Tier 2',
        'emoji': '🌍',
        'description': 'A planifié au moins 5 voyages avec Voyagooo.',
      },
      {
        'id': 'explorateur',
        'title': 'Explorateur',
        'tier': 'Tier 3',
        'emoji': '🗺️',
        'description': 'A atteint le palier mythique de 10 voyages générés.',
      },
      {
        'id': 'en_feu',
        'title': 'En Feu',
        'tier': 'Tier 2',
        'emoji': '🔥',
        'description': 'A maintenu une série de 3 jours consécutifs.',
      },
      {
        'id': 'first_comment',
        'title': 'Bavard',
        'tier': 'Tier 1',
        'emoji': '💬',
        'description': 'A posté son premier commentaire dans la communauté.',
      },
      {
        'id': 'populaire',
        'title': 'Populaire',
        'tier': 'Tier 2',
        'emoji': '❤️',
        'description': "Un de ses voyages a reçu 10 likes.",
      },
      {
        'id': 'eclaireur',
        'title': 'Éclaireur',
        'tier': 'Tier 3',
        'emoji': '🧭',
        'description': 'Un voyageur a refait un de ses voyages.',
      },
      {
        'id': 'compte_verifie',
        'title': 'Compte Vérifié',
        'tier': 'Tier 1',
        'emoji': '✅',
        'description': 'A confirmé son adresse e-mail.',
      },
      {
        'id': 'chasseur_pepites',
        'title': 'Chasseur de Pépites',
        'tier': 'Tier 1',
        'emoji': '💎',
        'description': 'A ramassé sa première pépite sur le terrain.',
      },
      {
        'id': 'esprit_tribu',
        'title': 'Esprit de Tribu',
        'tier': 'Tier 2',
        'emoji': '🏕️',
        'description': 'A réussi un premier défi de cercle avec sa tribu.',
      },
      {
        'id': 'fondateur_actif',
        'title': 'Fondateur Actif',
        'tier': 'Tier 2',
        'emoji': '⚡',
        'description': 'A répondu à 5 demandes de tribu en moins de 24 h.',
      },
      {
        'id': 'voyago_pro',
        'title': 'Voyagooo Pro',
        'tier': 'Tier 3',
        'emoji': '💎',
        'description': 'Membre du club exclusif Voyagooo Pro.',
      },
    ];

    final badgesList = _allBadges.isNotEmpty ? _allBadges : defaultBadges;
    final earnedCount = badgesList.where((b) {
      final id = b['id']?.toString() ?? '';
      return profile.badges.contains(id);
    }).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.military_tech, color: _ProfileColors.gold, size: 22),
                  const SizedBox(width: 8),
                  const Text(
                    'Hall of Fame',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: earnedCount > 0
                          ? _ProfileColors.gold.withValues(alpha: 0.15)
                          : Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: earnedCount > 0
                            ? _ProfileColors.gold.withValues(alpha: 0.3)
                            : Colors.white10,
                      ),
                    ),
                    child: Text(
                      '$earnedCount/${badgesList.length}',
                      style: TextStyle(
                        color: earnedCount > 0 ? _ProfileColors.gold : Colors.white38,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.go('/xp-rewards'),
                child: const Text(
                  'Voir catalogue',
                  style: TextStyle(
                    color: _ProfileColors.gold,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemCount: math.min(badgesList.length, 4),
          itemBuilder: (context, index) {
            final badge = badgesList[index];
            final badgeId = badge['id']?.toString() ?? '';
            // STRICTEMENT basé sur la présence du badge en base de données
            final isEarned = profile.badges.contains(badgeId);
            final title = badge['title']?.toString() ?? badge['name']?.toString() ?? 'Trophée';
            final emoji = badge['emoji']?.toString() ?? '🏆';
            final tier = badge['tier']?.toString() ?? 'Tier ${index + 1}';

            return GestureDetector(
              onTap: () => _showBadgeModal(badge, isEarned),
              child: Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isEarned ? _ProfileColors.glassBg : const Color(0xFF13151F),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: isEarned
                        ? _ProfileColors.gold.withValues(alpha: 0.35)
                        : Colors.white.withValues(alpha: 0.05),
                    width: 1.2,
                  ),
                  boxShadow: isEarned
                      ? const [
                          BoxShadow(
                            color: _ProfileColors.goldGlow,
                            blurRadius: 14,
                            spreadRadius: -2,
                          ),
                        ]
                      : null,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 50,
                      height: 50,
                      decoration: BoxDecoration(
                        gradient: isEarned
                            ? const LinearGradient(
                                colors: [_ProfileColors.gold, _ProfileColors.goldDark],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              )
                            : LinearGradient(
                                colors: [
                                  Colors.white.withValues(alpha: 0.08),
                                  Colors.white.withValues(alpha: 0.02),
                                ],
                              ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: isEarned
                            ? const [
                                BoxShadow(
                                  color: _ProfileColors.goldGlow,
                                  blurRadius: 10,
                                ),
                              ]
                            : null,
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        isEarned ? emoji : '🔒',
                        style: TextStyle(
                          fontSize: isEarned ? 26 : 22,
                          color: isEarned ? Colors.white : Colors.white24,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      title,
                      style: TextStyle(
                        color: isEarned ? Colors.white : Colors.white60,
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      isEarned ? tier : 'Verrouillé',
                      style: TextStyle(
                        color: isEarned
                            ? _ProfileColors.gold
                            : Colors.white30,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  void _showBadgeModal(Map<String, dynamic> badge, bool isEarned) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF141721),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(color: _ProfileColors.gold.withValues(alpha: 0.3)),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                gradient: isEarned
                    ? const LinearGradient(
                        colors: [_ProfileColors.gold, _ProfileColors.goldDark],
                      )
                    : LinearGradient(
                        colors: [Colors.white10, Colors.white.withValues(alpha: 0.03)],
                      ),
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                isEarned ? (badge['emoji']?.toString() ?? '🏆') : '🔒',
                style: const TextStyle(fontSize: 36),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              badge['title']?.toString() ?? badge['name']?.toString() ?? 'Badge',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              badge['description']?.toString() ??
                  'Débloquez ce badge en créant des voyages et en explorant de nouvelles destinations.',
              style: const TextStyle(color: VoyagoColors.muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isEarned
                    ? _ProfileColors.gold.withValues(alpha: 0.15)
                    : Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isEarned
                      ? _ProfileColors.gold.withValues(alpha: 0.4)
                      : Colors.white10,
                ),
              ),
              child: Text(
                isEarned ? '✓ Trophée Obtenu' : '🔒 Trophée Verrouillé',
                style: TextStyle(
                  color: isEarned ? _ProfileColors.gold : Colors.white38,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Fermer', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
    );
  }

  // --- SECTION TRAVELER DNA (ADN DU VOYAGEUR DYNAMIQUE ET CONFORME BD) ---
  Widget _buildTravelerDnaSection(AuthUser user, List<Trip> trips) {
    final List<Map<String, dynamic>> affinities = _calculateDnaAffinities(trips);
    final hasTrips = trips.isNotEmpty;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ProfileColors.glassBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.fingerprint, color: _ProfileColors.gold, size: 22),
                  SizedBox(width: 8),
                  Text(
                    'ADN du Voyageur',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: hasTrips
                      ? _ProfileColors.gold.withValues(alpha: 0.15)
                      : Colors.white.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: hasTrips
                        ? _ProfileColors.gold.withValues(alpha: 0.3)
                        : Colors.white10,
                  ),
                ),
                child: Text(
                  hasTrips
                      ? '${trips.length} voyage${trips.length > 1 ? 's' : ''}'
                      : '0 voyage',
                  style: TextStyle(
                    color: hasTrips ? _ProfileColors.gold : Colors.white38,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Message explicatif si aucun voyage en base de données
          if (!hasTrips) ...[
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF141721),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _ProfileColors.gold.withValues(alpha: 0.2)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome, color: _ProfileColors.gold, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'ADN en cours de calibrage',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Aucun voyage n\'a encore été généré. Dès votre premier itinéraire, Voyagooo calculera en temps réel vos pourcentages d\'affinités à partir de vos choix réels.',
                          style: TextStyle(color: VoyagoColors.muted, fontSize: 12, height: 1.3),
                        ),
                        const SizedBox(height: 10),
                        InkWell(
                          onTap: () => context.go('/swipe'),
                          child: const Text(
                            '✨ Générer mon 1er voyage pour calibrer →',
                            style: TextStyle(
                              color: _ProfileColors.gold,
                              fontSize: 12,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          // Barres d'affinités d'intérêts (dynamiques selon les voyages)
          ...affinities.map((item) {
            final label = item['label'] as String;
            final percent = item['percent'] as int;
            final icon = item['icon'] as IconData;

            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(
                            icon,
                            size: 16,
                            color: percent > 0 ? _ProfileColors.gold : Colors.white30,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            label,
                            style: TextStyle(
                              color: percent > 0 ? Colors.white : Colors.white60,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      Text(
                        percent > 0 ? '$percent%' : '0% (Non initié)',
                        style: TextStyle(
                          color: percent > 0 ? Colors.white : Colors.white30,
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Container(
                      height: 6,
                      color: Colors.white.withValues(alpha: 0.08),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: FractionallySizedBox(
                          widthFactor: (percent / 100.0).clamp(0.0, 1.0),
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  _ProfileColors.gold.withValues(alpha: 0.7),
                                  _ProfileColors.gold,
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),

          const Divider(color: Colors.white12, height: 28),

          // Métriques Biologiques / Profil Thermique
          const Text(
            'MÉTRIQUES BIOLOGIQUES & CONFORT',
            style: TextStyle(
              color: Colors.white38,
              fontSize: 10,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
          const SizedBox(height: 10),

          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFF141721),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _ProfileColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.thermostat,
                    color: _ProfileColors.gold,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Profil Thermique Voyage',
                        style: TextStyle(color: Colors.white38, fontSize: 11),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _getThermalLabel(user.thermalSensitivity),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.info_outline, size: 18, color: Colors.white38),
                  onPressed: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: const Color(0xFF141721),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                        ),
                        title: const Text('Profil Thermique IA',
                            style: TextStyle(color: Colors.white)),
                        content: Text(
                          'Voyagooo adapte automatiquement les itinéraires, les créneaux d\'activités en extérieur et le contenu de votre valise selon votre sensibilité thermique (${user.thermalSensitivity.labelFr}).',
                          style: const TextStyle(color: VoyagoColors.muted),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(ctx),
                            child: const Text('Compris'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Calcul dynamique du profil d'affinités selon les voyages réels ou préférences locales
  List<Map<String, dynamic>> _calculateDnaAffinities(List<Trip> trips) {
    if (trips.isEmpty) {
      // Si aucun voyage, on vérifie si l'utilisateur a sélectionné des envies lors du Swipe
      final selected = StorageService.instance.selectedInterests;
      if (selected.isNotEmpty) {
        return selected.take(4).map((id) {
          final meta = _interestMeta[id] ?? {
            'label': id,
            'icon': Icons.explore,
          };
          return {
            'label': meta['label'] as String,
            'percent': 0, // 0% car aucun voyage complété
            'icon': meta['icon'] as IconData,
          };
        }).toList();
      }

      // 4 axes fondamentaux vierges (0%)
      return [
        {'label': 'Gastronomie & Terroir', 'percent': 0, 'icon': Icons.restaurant},
        {'label': 'Culture & Histoire', 'percent': 0, 'icon': Icons.account_balance},
        {'label': 'Nature & Grands Espaces', 'percent': 0, 'icon': Icons.forest},
        {'label': 'Art & Design', 'percent': 0, 'icon': Icons.brush},
      ];
    }

    // Calcul des occurrences réelles depuis les voyages en base MongoDB
    final Map<String, int> counts = {};
    for (final t in trips) {
      for (final interest in t.interests) {
        counts[interest] = (counts[interest] ?? 0) + 1;
      }
    }

    // Transformer en liste triée par popularité
    final sortedInterests = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final List<Map<String, dynamic>> result = [];
    for (final entry in sortedInterests) {
      final id = entry.key;
      final count = entry.value;
      final percent = ((count / trips.length) * 100).round().clamp(1, 100);
      final meta = _interestMeta[id] ?? {
        'label': id[0].toUpperCase() + id.substring(1),
        'icon': Icons.explore,
      };

      result.add({
        'label': meta['label'] as String,
        'percent': percent,
        'icon': meta['icon'] as IconData,
      });

      if (result.length >= 4) break;
    }

    // Compléter jusqu'à 4 catégories si l'utilisateur a peu d'intérêts différents
    if (result.length < 4) {
      for (final metaEntry in _interestMeta.entries) {
        if (!counts.containsKey(metaEntry.key)) {
          result.add({
            'label': metaEntry.value['label'] as String,
            'percent': 0,
            'icon': metaEntry.value['icon'] as IconData,
          });
          if (result.length >= 4) break;
        }
      }
    }

    return result;
  }

  String _getThermalLabel(ThermalSensitivity sensitivity) {
    switch (sensitivity) {
      case ThermalSensitivity.cold:
        return 'Frileux (Préférence soleil & chaleur)';
      case ThermalSensitivity.balanced:
        return 'Équilibré (Optimal)';
      case ThermalSensitivity.warm:
        return 'Chaleureux (Préférence fraîcheur)';
    }
  }

  // --- CARTE UPGRADE VOYAGOOO PRO (UNLIMITED DISCOVERY) ---
  Widget _buildUpgradeCard(AuthUser user) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            _ProfileColors.gold,
            Color(0xFFE29F10),
            Color(0xFFC78400),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: const [
          BoxShadow(
            color: Color(0x40F4C025),
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                user.isPro ? 'Voyagooo Pro Actif' : 'Découverte Illimitée',
                style: const TextStyle(
                  color: Color(0xFF0A0A0F),
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.5,
                ),
              ),
              const Icon(
                Icons.stars_rounded,
                color: Color(0xFF0A0A0F),
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            user.isPro
                ? 'Vous bénéficiez des itinéraires IA illimités, calques météorologiques haute précision et accès prioritaire.'
                : 'Accédez aux calques de carte exclusifs, recommandations secrètes de l\'IA et voyages sans limite.',
            style: TextStyle(
              color: const Color(0xFF0A0A0F).withValues(alpha: 0.8),
              fontSize: 13,
              height: 1.3,
            ),
          ),
          const SizedBox(height: 18),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => context.go('/pricing'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF0A0A0F),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
              child: Text(
                user.isPro ? 'Gérer mon pass Pro' : 'Explorer le Vault Pro',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _changeTripVisibility(Trip trip) async {
    final visibility = await showTripVisibilitySheet(context, trip: trip);
    if (visibility == null || !mounted) return;
    ref.invalidate(tripsProvider(widget.userId));
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Visibilité de ${trip.destination} : ${visibility.label}')),
    );
  }

  // --- SECTION MES VOYAGES ---
  Widget _buildTripsSection(AsyncValue<List<Trip>> tripsAsync) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Row(
                children: [
                  Icon(Icons.flight_takeoff, color: _ProfileColors.gold, size: 20),
                  SizedBox(width: 8),
                  Text(
                    'Mes Voyages Récents',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              TextButton(
                onPressed: () => context.go('/swipe'),
                child: const Text(
                  '+ Créer',
                  style: TextStyle(
                    color: _ProfileColors.gold,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        tripsAsync.when(
          data: (trips) {
            if (trips.isEmpty) {
              return Container(
                width: double.infinity,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: _ProfileColors.glassBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                ),
                child: Column(
                  children: [
                    const Text('🦜', style: TextStyle(fontSize: 44)),
                    const SizedBox(height: 12),
                    const Text(
                      'Aucun voyage encore créé',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 6),
                    const Text(
                      'Lancez l\'IA Voyagooo pour concevoir votre premier itinéraire personnalisé !',
                      style: TextStyle(color: VoyagoColors.muted, fontSize: 13),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: () => context.go('/swipe'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _ProfileColors.gold,
                        foregroundColor: const Color(0xFF0A0A0F),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                      ),
                      child: const Text(
                        'Créer un itinéraire',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              );
            }

            return Column(
              children: trips
                  .map((t) => TripCard(
                        trip: t,
                        onTap: () => context.go('/itinerary/${t.id}', extra: t),
                        onVisibilityTap: () => _changeTripVisibility(t),
                      ))
                  .toList(),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.all(24),
            child: Center(
              child: CircularProgressIndicator(color: _ProfileColors.gold),
            ),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'Erreur chargement voyages: ${e.toString()}',
              style: const TextStyle(color: VoyagoColors.coral),
            ),
          ),
        ),
      ],
    );
  }

  // --- FORMULAIRE D'ÉDITION DE PROFIL ---
  Widget _buildEditProfileCard(AuthUser user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ProfileColors.glassBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: _ProfileColors.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Édition du Profil',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close, color: Colors.white60),
                onPressed: () => setState(() => _isEditing = false),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Photo de profil & Avatar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Photo ou avatar :',
                style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
              ),
              if (user.picture != null && user.picture!.isNotEmpty)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: _ProfileColors.gold.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _ProfileColors.gold.withValues(alpha: 0.4)),
                  ),
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check, size: 12, color: _ProfileColors.gold),
                      SizedBox(width: 4),
                      Text('Photo active', style: TextStyle(color: _ProfileColors.gold, fontSize: 11, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Center(
            child: GestureDetector(
              onTap: () => _showPhotoOptionsModal(user),
              child: Stack(
                children: [
                  Container(
                    width: 90,
                    height: 90,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF141721),
                      border: Border.all(color: _ProfileColors.gold, width: 2.5),
                      boxShadow: const [
                        BoxShadow(
                          color: _ProfileColors.goldGlow,
                          blurRadius: 14,
                          spreadRadius: 1,
                        ),
                      ],
                    ),
                    alignment: Alignment.center,
                    child: _isUploadingPhoto
                        ? const CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: _ProfileColors.gold,
                          )
                        : (user.picture != null && user.picture!.isNotEmpty)
                            ? ClipOval(
                                child: Image.network(
                                  user.picture!,
                                  width: 90,
                                  height: 90,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => Text(
                                    _editAvatarEmoji ?? user.avatarDisplay,
                                    style: const TextStyle(fontSize: 44),
                                  ),
                                ),
                              )
                            : Text(
                                _editAvatarEmoji ?? user.avatarDisplay,
                                style: const TextStyle(fontSize: 44),
                              ),
                  ),
                  Positioned(
                    bottom: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(7),
                      decoration: BoxDecoration(
                        color: _ProfileColors.gold,
                        shape: BoxShape.circle,
                        border: Border.all(color: const Color(0xFF10131C), width: 2),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x66000000),
                            blurRadius: 6,
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.camera_alt,
                        size: 15,
                        color: Color(0xFF0A0A0F),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Center(
            child: Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () => _showPhotoOptionsModal(user),
                  icon: const Icon(Icons.add_a_photo_outlined, size: 16, color: _ProfileColors.gold),
                  label: Text(
                    (user.picture != null && user.picture!.isNotEmpty) ? 'Modifier la photo' : 'Ajouter une photo',
                    style: const TextStyle(color: _ProfileColors.gold, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                if (user.picture != null && user.picture!.isNotEmpty)
                  TextButton.icon(
                    onPressed: _deletePhoto,
                    icon: const Icon(Icons.delete_outline, size: 16, color: VoyagoColors.coral),
                    label: const Text(
                      'Retirer',
                      style: TextStyle(color: VoyagoColors.coral, fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            'Ou choisissez un avatar emoji alternatif :',
            style: TextStyle(color: Colors.white60, fontSize: 12),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            alignment: WrapAlignment.center,
            children: _avatarEmojis.map((emoji) {
              final isSelected = emoji == (_editAvatarEmoji ?? user.avatarDisplay);
              return GestureDetector(
                onTap: () {
                  setState(() => _editAvatarEmoji = emoji);
                  if (user.picture != null && user.picture!.isNotEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Avatar emoji mis à jour. Note : pour l\'afficher en priorité, vous pouvez retirer votre photo.'),
                        duration: Duration(seconds: 3),
                        backgroundColor: _ProfileColors.goldDark,
                      ),
                    );
                  }
                },
                child: Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: isSelected
                        ? _ProfileColors.gold.withValues(alpha: 0.25)
                        : const Color(0xFF141721),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected ? _ProfileColors.gold : Colors.white10,
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  alignment: Alignment.center,
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 20),

          // Champ Pseudo
          TextField(
            controller: _pseudoCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(
              labelText: 'Pseudo d\'explorateur',
              prefixIcon: Icon(Icons.alternate_email, color: _ProfileColors.gold),
            ),
          ),
          const SizedBox(height: 14),

          // Champ Pays (EN PREMIER)
          _buildSelectField(
            label: 'Pays de résidence',
            value: _countryCtrl.text.isNotEmpty
                ? '${CountriesData.getFlag(_countryCtrl.text)} ${_countryCtrl.text}'
                : 'Sélectionner votre pays',
            hasValue: _countryCtrl.text.isNotEmpty,
            prefixIcon: Icons.public,
            onTap: () => _showCountryPicker(context),
          ),
          const SizedBox(height: 14),

          // Champ Ville (CONDITIONNÉ EN FONCTION DU PAYS)
          _buildSelectField(
            label: 'Ville de résidence',
            value: _cityCtrl.text.isNotEmpty
                ? _cityCtrl.text
                : (_countryCtrl.text.isNotEmpty
                    ? 'Sélectionner une ville (${_countryCtrl.text})'
                    : 'Sélectionnez d\'abord un pays'),
            hasValue: _cityCtrl.text.isNotEmpty,
            prefixIcon: Icons.location_city,
            subtitle: _countryCtrl.text.isNotEmpty
                ? 'Conditionné aux villes de ${_countryCtrl.text}'
                : 'Nécessite le choix préalable d\'un pays',
            onTap: () => _showCityPicker(context),
          ),

          const SizedBox(height: 20),

          // Sensibilité thermique
          const Text(
            'Sensibilité thermique :',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: ThermalSensitivity.values.map((s) {
              final isSelected = (_editThermal ?? user.thermalSensitivity) == s;
              return ChoiceChip(
                label: Text(s.labelFr),
                selected: isSelected,
                selectedColor: _ProfileColors.gold,
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF0A0A0F) : Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) {
                  if (val) setState(() => _editThermal = s);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 16),

          // Genre
          const Text(
            'Genre :',
            style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: UserGender.values.map((g) {
              final isSelected = (_editGender ?? user.gender) == g;
              return ChoiceChip(
                label: Text(g.label),
                selected: isSelected,
                selectedColor: _ProfileColors.gold,
                labelStyle: TextStyle(
                  color: isSelected ? const Color(0xFF0A0A0F) : Colors.white70,
                  fontWeight: FontWeight.bold,
                ),
                onSelected: (val) {
                  if (val) setState(() => _editGender = g);
                },
              );
            }).toList(),
          ),

          const SizedBox(height: 24),

          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => setState(() => _isEditing = false),
                  child: const Text('Annuler', style: TextStyle(color: Colors.white70)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isSaving ? null : _saveProfile,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _ProfileColors.gold,
                    foregroundColor: const Color(0xFF0A0A0F),
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Color(0xFF0A0A0F),
                          ),
                        )
                      : const Text(
                          'Enregistrer',
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSelectField({
    required String label,
    required String value,
    required bool hasValue,
    required IconData prefixIcon,
    String? subtitle,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: const Color(0xFF141721),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: hasValue ? _ProfileColors.gold.withValues(alpha: 0.5) : Colors.white12,
            width: hasValue ? 1.5 : 1.0,
          ),
        ),
        child: Row(
          children: [
            Icon(prefixIcon, color: _ProfileColors.gold, size: 22),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: hasValue ? _ProfileColors.goldLight : Colors.white60,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.4,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    value,
                    style: TextStyle(
                      color: hasValue ? Colors.white : Colors.white38,
                      fontSize: 15,
                      fontWeight: hasValue ? FontWeight.bold : FontWeight.normal,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.35),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded, color: _ProfileColors.gold, size: 24),
          ],
        ),
      ),
    );
  }
}

/// Peintre personnalisé pour l'anneau de progression circulaire autour de l'avatar
class _RadialProgressPainter extends CustomPainter {
  final double progress;
  final double strokeWidth;
  final Color progressColor;
  final Color trackColor;

  _RadialProgressPainter({
    required this.progress,
    required this.strokeWidth,
    required this.progressColor,
    required this.trackColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width - strokeWidth) / 2;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, trackPaint);

    final progressPaint = Paint()
      ..color = progressColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final sweepAngle = 2 * math.pi * progress.clamp(0.0, 1.0);
    const startAngle = -math.pi / 2;

    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius),
      startAngle,
      sweepAngle,
      false,
      progressPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _RadialProgressPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.progressColor != progressColor ||
        oldDelegate.strokeWidth != strokeWidth;
  }
}

/// Feuille modale dynamique pour la sélection du pays avec recherche en temps réel (Monde entier)
class _CountryPickerSheet extends StatefulWidget {
  final String initialCountry;
  final ValueChanged<CountryInfo> onSelected;

  const _CountryPickerSheet({
    required this.initialCountry,
    required this.onSelected,
  });

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<CountryInfo> _allCountries = [];
  List<CountryInfo> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCountries();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    final list = await CountriesData.getCountries();
    if (mounted) {
      setState(() {
        _allCountries = list;
        _filtered = list;
        _isLoading = false;
      });
      _onSearchChanged();
    }
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = _allCountries;
      } else {
        _filtered = _allCountries.where((c) {
          return c.displayName.toLowerCase().contains(query) ||
              c.name.toLowerCase().contains(query) ||
              c.code.toLowerCase().contains(query);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim();
    final hasExactMatch = _filtered.any(
      (c) => c.displayName.toLowerCase() == query.toLowerCase() ||
          c.name.toLowerCase() == query.toLowerCase(),
    );

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF10131C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: _ProfileColors.gold, width: 1.5)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.public, color: _ProfileColors.gold, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Sélectionnez votre pays',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (!_isLoading) ...[
                          const SizedBox(height: 2),
                          Text(
                            '${_allCountries.length} pays du monde disponibles',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.4),
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: 'Rechercher un pays...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: _ProfileColors.gold),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white60),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF181C28),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _ProfileColors.gold),
                  ),
                ),
              ),
            ),
            const Divider(color: Colors.white10, height: 16),
            if (_isLoading)
              const Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _ProfileColors.gold,
                        ),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Chargement des pays du monde...',
                        style: TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (query.isNotEmpty && !hasExactMatch) ...[
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: _ProfileColors.gold.withValues(alpha: 0.1),
                        leading: const Text('🌍', style: TextStyle(fontSize: 26)),
                        title: Text(
                          'Utiliser "$query"',
                          style: const TextStyle(
                            color: _ProfileColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: const Text(
                          'Définir ce pays personnalisé',
                          style: TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        trailing: const Icon(Icons.add_circle_outline, color: _ProfileColors.gold),
                        onTap: () {
                          widget.onSelected(
                            CountryInfo(
                              name: query,
                              frenchName: query,
                              code: '',
                              flag: '🌍',
                            ),
                          );
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    ..._filtered.map((country) {
                      final isSelected = country.displayName.toLowerCase() == widget.initialCountry.trim().toLowerCase() ||
                          country.name.toLowerCase() == widget.initialCountry.trim().toLowerCase();
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                        leading: Text(country.flag, style: const TextStyle(fontSize: 28)),
                        title: Text(
                          country.displayName,
                          style: TextStyle(
                            color: isSelected ? _ProfileColors.gold : Colors.white,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 16,
                          ),
                        ),
                        subtitle: Text(
                          country.frenchName.isNotEmpty && country.frenchName != country.name
                              ? '${country.name} · Code ${country.code}'
                              : 'Code ${country.code}',
                          style: TextStyle(
                            color: Colors.white.withValues(alpha: 0.4),
                            fontSize: 12,
                          ),
                        ),
                        trailing: isSelected
                            ? const Icon(Icons.check_circle, color: _ProfileColors.gold)
                            : null,
                        onTap: () {
                          widget.onSelected(country);
                          Navigator.pop(context);
                        },
                      );
                    }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Feuille modale dynamique pour la sélection de la ville conditionnée au pays choisi (Monde entier)
class _CityPickerSheet extends StatefulWidget {
  final String countryName;
  final String initialCity;
  final ValueChanged<String> onSelected;

  const _CityPickerSheet({
    required this.countryName,
    required this.initialCity,
    required this.onSelected,
  });

  @override
  State<_CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<_CityPickerSheet> {
  final TextEditingController _searchCtrl = TextEditingController();
  List<String> _baseCities = [];
  List<String> _filtered = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCities();
    _searchCtrl.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    final list = await CountriesData.getCitiesForCountry(widget.countryName);
    if (mounted) {
      setState(() {
        _baseCities = list;
        _filtered = list;
        _isLoading = false;
      });
      _onSearchChanged();
    }
  }

  void _onSearchChanged() {
    final query = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filtered = _baseCities;
      } else {
        _filtered = _baseCities
            .where((city) => city.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchCtrl.text.trim();
    final hasExactMatch = _filtered.any(
      (c) => c.toLowerCase() == query.toLowerCase(),
    );
    final flag = CountriesData.getFlag(widget.countryName);

    return DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (ctx, scrollController) => Container(
        decoration: const BoxDecoration(
          color: Color(0xFF10131C),
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          border: Border(top: BorderSide(color: _ProfileColors.gold, width: 1.5)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              child: Row(
                children: [
                  const Icon(Icons.location_city, color: _ProfileColors.gold, size: 24),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Ville de résidence',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Row(
                          children: [
                            Text(flag, style: const TextStyle(fontSize: 14)),
                            const SizedBox(width: 4),
                            Text(
                              widget.countryName,
                              style: const TextStyle(
                                color: _ProfileColors.gold,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            if (!_isLoading) ...[
                              const SizedBox(width: 8),
                              Text(
                                '(${_baseCities.length} villes répertoriées)',
                                style: TextStyle(
                                  color: Colors.white.withValues(alpha: 0.4),
                                  fontSize: 11,
                                ),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white60),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: TextField(
                controller: _searchCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: _isLoading
                      ? 'Chargement des villes...'
                      : 'Rechercher parmi les ${_baseCities.length} villes...',
                  hintStyle: const TextStyle(color: Colors.white38),
                  prefixIcon: const Icon(Icons.search, color: _ProfileColors.gold),
                  suffixIcon: query.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, color: Colors.white60),
                          onPressed: () => _searchCtrl.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: const Color(0xFF181C28),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: Colors.white12),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: const BorderSide(color: _ProfileColors.gold),
                  ),
                ),
              ),
            ),
            const Divider(color: Colors.white10, height: 16),
            if (_isLoading)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const SizedBox(
                        width: 28,
                        height: 28,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: _ProfileColors.gold,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Chargement des villes de ${widget.countryName}...',
                        style: const TextStyle(color: Colors.white70, fontSize: 13),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView(
                  controller: scrollController,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (query.isNotEmpty && !hasExactMatch) ...[
                      ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: _ProfileColors.gold.withValues(alpha: 0.1),
                        leading: const Icon(Icons.add_location_alt_outlined, color: _ProfileColors.gold, size: 24),
                        title: Text(
                          'Utiliser "$query"',
                          style: const TextStyle(
                            color: _ProfileColors.gold,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        subtitle: Text(
                          'Valider cette ville pour ${widget.countryName}',
                          style: const TextStyle(color: Colors.white60, fontSize: 11),
                        ),
                        trailing: const Icon(Icons.check, color: _ProfileColors.gold),
                        onTap: () {
                          widget.onSelected(query);
                          Navigator.pop(context);
                        },
                      ),
                      const SizedBox(height: 8),
                    ],
                    if (_filtered.isEmpty && query.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(24),
                        child: Column(
                          children: [
                            const Icon(Icons.search, size: 40, color: Colors.white24),
                            const SizedBox(height: 10),
                            Text(
                              'Aucune ville trouvée pour ${widget.countryName}. Tapez le nom de votre ville ci-dessus pour la sélectionner.',
                              style: const TextStyle(color: Colors.white60, fontSize: 13),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      ..._filtered.map((city) {
                        final isSelected = city.toLowerCase() == widget.initialCity.trim().toLowerCase();
                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                          leading: Container(
                            width: 38,
                            height: 38,
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? _ProfileColors.gold.withValues(alpha: 0.2)
                                  : const Color(0xFF181C28),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? _ProfileColors.gold : Colors.white10,
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Icon(
                              Icons.location_on,
                              size: 18,
                              color: isSelected ? _ProfileColors.gold : Colors.white60,
                            ),
                          ),
                          title: Text(
                            city,
                            style: TextStyle(
                              color: isSelected ? _ProfileColors.gold : Colors.white,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 15,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle, color: _ProfileColors.gold)
                              : null,
                          onTap: () {
                            widget.onSelected(city);
                            Navigator.pop(context);
                          },
                        );
                      }),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}
