import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers/auth_provider.dart';
import 'models/trip.dart';
import 'screens/settings_screen.dart';
import 'screens/home_screen.dart';
import 'screens/auth_screen.dart';
import 'screens/forgot_password_screen.dart';
import 'screens/swipe_screen.dart';
import 'screens/configure_screen.dart';
import 'screens/itinerary_screen.dart';
import 'screens/pricing_screen.dart';
import 'screens/profile_screen.dart';
import 'screens/community_screen.dart';
import 'screens/xp_rewards_screen.dart';
import 'screens/public_user_screen.dart';
import 'screens/circle_detail_screen.dart';
import 'screens/tribe_plan_screen.dart';
import 'screens/onboarding_screen.dart';
import 'screens/welcome_screen.dart';
import 'screens/journal_screen.dart';
import 'screens/journal_detail_screen.dart';
import 'screens/tribe_settings_screen.dart';
import 'screens/bookings_budget_screen.dart';

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen<AuthState>(
      authProvider,
      (_, __) => notifyListeners(),
    );
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authProvider);
    final user = authState.user;
    final uriPath = state.uri.path;
    final matchedPath = state.matchedLocation;
    final isOnboarding = uriPath == '/onboarding' || matchedPath == '/onboarding';
    final isWelcome = uriPath == '/welcome' || matchedPath == '/welcome';

    if (!authState.sessionLoaded) return null;

    // Si l'utilisateur existe et n'a pas encore complété son onboarding obligatoire
    if (user != null && !user.onboardingCompleted) {
      if (!isOnboarding) {
        return '/onboarding';
      }
      return null;
    }

    // Si l'utilisateur a déjà complété l'onboarding et tente d'y retourner
    if (isOnboarding) {
      if (user == null || user.onboardingCompleted) {
        return '/';
      }
    }

    // Si l'utilisateur est connecté et tente d'aller sur la page d'accueil de bienvenue
    if (user != null && isWelcome) {
      return '/';
    }

    return null;
  }
}

final routerNotifierProvider = Provider<RouterNotifier>((ref) {
  return RouterNotifier(ref);
});

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);

  return GoRouter(
    refreshListenable: notifier,
    initialLocation: '/welcome',
    redirect: notifier.redirect,
    routes: [
      GoRoute(
        path: '/welcome',
        builder: (context, state) => const WelcomeScreen(),
      ),
      GoRoute(
        path: '/',
        builder: (context, state) => const HomeScreen(),
      ),
      GoRoute(
        path: '/onboarding',
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        path: '/auth',
        builder: (context, state) => const AuthScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      GoRoute(
        path: '/swipe',
        builder: (context, state) => const SwipeScreen(),
      ),
      GoRoute(
        path: '/configure',
        builder: (context, state) {
          final extra = state.extra;
          // Liste d'intérêts (vibes de l'accueil) ou idée de voyage {destination, interests}
          final List<String> interests = extra is List
              ? extra.map((e) => e.toString()).toList()
              : extra is Map && extra['interests'] is List
                  ? (extra['interests'] as List).map((e) => e.toString()).toList()
                  : [];
          final destination = extra is Map ? extra['destination']?.toString() : null;
          return ConfigureScreen(selectedInterests: interests, initialDestination: destination);
        },
      ),
      GoRoute(
        path: '/itinerary',
        builder: (context, state) {
          final trip = state.extra is Trip ? state.extra as Trip : null;
          return ItineraryScreen(tripId: '', trip: trip);
        },
      ),
      GoRoute(
        path: '/itinerary/:tripId',
        builder: (context, state) {
          final tripId = state.pathParameters['tripId'] ?? '';
          final trip = state.extra is Trip ? state.extra as Trip : null;
          return ItineraryScreen(tripId: tripId, trip: trip);
        },
      ),
      // Réservations & Budget d'un voyage
      GoRoute(
        path: '/trip/:tripId/bookings',
        builder: (context, state) => BookingsBudgetScreen(tripId: state.pathParameters['tripId'] ?? ''),
      ),
      GoRoute(
        path: '/pricing',
        builder: (context, state) => const PricingScreen(),
      ),
      GoRoute(
        path: '/profile',
        builder: (context, state) => const ProfileScreen(),
      ),
      GoRoute(
        path: '/settings',
        builder: (context, state) => SettingsScreen(initialTab: state.uri.queryParameters['tab']),
      ),
      GoRoute(
        path: '/community',
        builder: (context, state) => const CommunityScreen(),
      ),
      GoRoute(
        path: '/circle/:circleId',
        builder: (context, state) {
          final circleId = state.pathParameters['circleId'] ?? '';
          return CircleDetailScreen(circleId: circleId);
        },
      ),
      GoRoute(
        path: '/circle/:circleId/plan/:planId',
        builder: (context, state) => TribePlanScreen(
          circleId: state.pathParameters['circleId'] ?? '',
          planId: state.pathParameters['planId'] ?? '',
        ),
      ),
      // Paramètres des tribus (sidebar) : accès et vie privée des cercles
      GoRoute(
        path: '/tribe-settings',
        builder: (context, state) => const TribeSettingsScreen(),
      ),
      GoRoute(
        path: '/tribe-settings/:circleId',
        builder: (context, state) => CircleSettingsScreen(circleId: state.pathParameters['circleId']!),
      ),
      GoRoute(
        path: '/journal',
        builder: (context, state) => const JournalScreen(),
      ),
      GoRoute(
        path: '/journal/:tripId',
        builder: (context, state) => JournalDetailScreen(tripId: state.pathParameters['tripId'] ?? ''),
      ),
      GoRoute(
        path: '/xp-rewards',
        builder: (context, state) => const XpRewardsScreen(),
      ),
      GoRoute(
        path: '/user/:id',
        builder: (context, state) {
          final userId = state.pathParameters['id'] ?? '';
          return PublicUserScreen(userId: userId);
        },
      ),
    ],
    errorBuilder: (context, state) => Scaffold(
      backgroundColor: const Color(0xFF0F1117),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🦜', style: TextStyle(fontSize: 48)),
            const SizedBox(height: 16),
            Text(
              'Page introuvable',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 8),
            Text(
              state.error?.message ?? 'Cette page n\'existe pas.',
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: () => context.go('/'),
              child: const Text('Retour à l\'accueil'),
            ),
          ],
        ),
      ),
    ),
  );
});
