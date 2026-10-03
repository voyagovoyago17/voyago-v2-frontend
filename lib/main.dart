import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sizer/sizer.dart';
import 'core/config/app_environment.dart';
import 'services/app_rating_service.dart';
import 'services/push_notifications.dart';
import 'services/live_notifications.dart';
import 'services/app_settings.dart';
import 'services/storage_service.dart';
import 'router.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('fr_FR', null);
  await initializeDateFormatting('fr', null);
  await StorageService.instance.init();
  // Purge la session si on a changé de backend (local <-> prod) depuis le dernier lancement
  await AppConfig.ensureSessionMatchesBackend();
  // Compte les lancements pour la demande de note sur le store (sans bloquer le démarrage)
  AppRatingService.instance.init();
  // Notifications push (inactives tant que Firebase n'est pas configuré)
  await PushNotifications.instance.init();
  runApp(const ProviderScope(child: VoyagoApp()));
}

class VoyagoApp extends ConsumerWidget {
  const VoyagoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    ref.watch(pushNotificationsProvider);
    ref.watch(liveNotificationsProvider);
    // Réglages locaux (volume, mode, navigation) chargés dès le lancement
    ref.watch(appSettingsProvider);

    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp.router(
          title: 'Voyagooo',
          theme: voyagoTheme,
          routerConfig: router,
          scaffoldMessengerKey: PushNotifications.messengerKey,
          debugShowCheckedModeBanner: false,
          builder: (context, child) => _EnvironmentBanner(child: child!),
        );
      },
    );
  }
}

/// Bandeau LOCAL affiché uniquement hors prod (aucun bandeau en prod).
class _EnvironmentBanner extends StatelessWidget {
  const _EnvironmentBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (AppConfig.isProduction) return child;
    return Banner(
      message: AppConfig.environment.label,
      location: BannerLocation.topEnd,
      color: Colors.blue,
      child: child,
    );
  }
}
