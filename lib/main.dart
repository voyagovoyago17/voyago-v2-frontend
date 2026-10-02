import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:sizer/sizer.dart';
import 'core/config/app_environment.dart';
import 'services/app_rating_service.dart';
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
  runApp(const ProviderScope(child: VoyagoApp()));
}

class VoyagoApp extends ConsumerWidget {
  const VoyagoApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);

    return Sizer(
      builder: (context, orientation, deviceType) {
        return MaterialApp.router(
          title: 'Voyagooo',
          theme: voyagoTheme,
          routerConfig: router,
          debugShowCheckedModeBanner: false,
          builder: (context, child) => _EnvironmentBanner(child: child!),
        );
      },
    );
  }
}

/// Bandeau indiquant l'environnement backend (LOCAL / PROD), masqué en release prod.
class _EnvironmentBanner extends StatelessWidget {
  const _EnvironmentBanner({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (kReleaseMode && AppConfig.isProduction) return child;
    return Banner(
      message: AppConfig.environment.label,
      location: BannerLocation.topEnd,
      color: AppConfig.isProduction ? Colors.red : Colors.blue,
      child: child,
    );
  }
}
