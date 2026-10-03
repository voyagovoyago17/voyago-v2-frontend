import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/notifications_api.dart';
import '../models/app_notification.dart';
import '../providers/auth_provider.dart';
import '../providers/notifications_provider.dart';
import '../router.dart';
import '../theme.dart';
import '../widgets/notification_actions.dart';

/// Notifications push (Firebase Cloud Messaging).
///
/// - Le jeton de l'appareil est envoyé au backend à la connexion (et à chaque rotation).
/// - App ouverte : la cloche se met à jour et un bandeau discret s'affiche.
/// - Push touché (app en arrière-plan ou fermée) : on ouvre directement le bon écran.
///
/// Sans configuration Firebase (google-services.json / GoogleService-Info.plist), tout est inactif.
class PushNotifications {
  PushNotifications._();
  static final PushNotifications instance = PushNotifications._();

  /// Pour afficher le bandeau des push reçus app ouverte
  static final GlobalKey<ScaffoldMessengerState> messengerKey = GlobalKey<ScaffoldMessengerState>();

  final NotificationsApi _api = NotificationsApi();
  bool _available = false;
  String? _registeredToken;

  bool get isAvailable => _available;

  /// Au démarrage de l'app, avant runApp. Ne bloque jamais le lancement.
  Future<void> init() async {
    if (kIsWeb || !(Platform.isAndroid || Platform.isIOS)) return;
    try {
      await Firebase.initializeApp().timeout(const Duration(seconds: 5));
      _available = true;
    } catch (e) {
      debugPrint('Push désactivé (Firebase non configuré) : $e');
    }
  }

  FirebaseMessaging get _messaging => FirebaseMessaging.instance;

  /// Demande l'autorisation puis enregistre le jeton de l'appareil auprès du backend.
  Future<void> registerDevice() async {
    if (!_available) return;
    try {
      final settings = await _messaging.requestPermission(alert: true, badge: true, sound: true);
      if (settings.authorizationStatus == AuthorizationStatus.denied) return;

      final token = await _fetchToken();
      if (token == null) return;
      await _api.registerDevice(token: token, platform: Platform.isIOS ? 'ios' : 'android');
      _registeredToken = token;
    } catch (e) {
      debugPrint('Jeton push non enregistré : $e');
    }
  }

  /// Sur iOS, le jeton FCM n'existe qu'une fois le jeton APNs reçu : on l'attend un peu.
  Future<String?> _fetchToken() async {
    if (Platform.isIOS) {
      for (var i = 0; i < 10 && await _messaging.getAPNSToken() == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 500));
      }
      if (await _messaging.getAPNSToken() == null) return null;
    }
    return _messaging.getToken();
  }

  /// À la déconnexion (avant d'invalider la session) : cet appareil ne reçoit plus les push du compte.
  Future<void> unregisterDevice() async {
    if (!_available) return;
    try {
      final token = _registeredToken ?? await _messaging.getToken().timeout(const Duration(seconds: 3));
      if (token == null) return;
      await _api.unregisterDevice(token).timeout(const Duration(seconds: 4));
    } catch (_) {
      // La session expirée ne doit jamais bloquer la déconnexion
    } finally {
      _registeredToken = null;
    }
  }

  Stream<String> get onTokenRefresh => _available ? _messaging.onTokenRefresh : const Stream.empty();

  /// Convertit un push FCM en notification de la cloche (mêmes données que l'API).
  static AppNotification toAppNotification(RemoteMessage message) {
    Map<String, dynamic> payload = const {};
    final raw = message.data['payload'];
    if (raw is String && raw.isNotEmpty) {
      try {
        final decoded = jsonDecode(raw);
        if (decoded is Map) payload = Map<String, dynamic>.from(decoded);
      } catch (_) {}
    }
    return AppNotification(
      id: message.data['notification_id']?.toString() ?? message.messageId ?? '',
      type: message.data['type']?.toString() ?? 'system',
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      data: payload,
      createdAt: message.sentTime ?? DateTime.now(),
    );
  }
}

/// Relie les push à la session : enregistrement du jeton, bandeau app ouverte, ouverture au tap.
/// À regarder une fois depuis la racine de l'app.
final pushNotificationsProvider = Provider<void>((ref) {
  final push = PushNotifications.instance;
  if (!push.isAvailable) return;

  final subscriptions = <StreamSubscription<dynamic>>[];
  AppNotification? pending;

  void open(AppNotification n) {
    if (!ref.read(isAuthenticatedProvider)) {
      pending = n; // ouvert dès que la session est restaurée
      return;
    }
    ref.read(notificationsProvider.notifier).markRead(n);
    // Attend que l'écran d'accueil soit monté (lancement depuis un push)
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = ref.read(routerProvider).routerDelegate.navigatorKey.currentContext;
      if (context != null && context.mounted) openNotificationTarget(context, n);
    });
  }

  ref.listen<bool>(isAuthenticatedProvider, (_, loggedIn) {
    if (!loggedIn) return;
    push.registerDevice();
    final waiting = pending;
    pending = null;
    if (waiting != null) {
      Future<void>.delayed(const Duration(milliseconds: 600), () => open(waiting));
    }
  }, fireImmediately: true);

  subscriptions.add(push.onTokenRefresh.listen((_) {
    if (ref.read(isAuthenticatedProvider)) push.registerDevice();
  }));

  // App au premier plan : la cloche se met à jour et un bandeau s'affiche
  subscriptions.add(FirebaseMessaging.onMessage.listen((message) {
    if (!ref.read(isAuthenticatedProvider)) return;
    ref.read(notificationsProvider.notifier).refresh();
    final n = PushNotifications.toAppNotification(message);
    if (n.title.isEmpty) return;
    _showForegroundBanner(n, onOpen: canOpenNotification(n) ? () => open(n) : null);
  }));

  // Push touché alors que l'app tournait en arrière-plan
  subscriptions.add(FirebaseMessaging.onMessageOpenedApp.listen((message) {
    ref.read(notificationsProvider.notifier).refresh();
    open(PushNotifications.toAppNotification(message));
  }));

  // App lancée en touchant un push
  FirebaseMessaging.instance.getInitialMessage().then((message) {
    if (message != null) open(PushNotifications.toAppNotification(message));
  });

  ref.onDispose(() {
    for (final s in subscriptions) {
      s.cancel();
    }
  });
});

void _showForegroundBanner(AppNotification n, {VoidCallback? onOpen}) {
  final messenger = PushNotifications.messengerKey.currentState;
  if (messenger == null) return;
  final (icon, color) = switch (n.type) {
    'trip_ready' => (Icons.flight_takeoff_rounded, VoyagoColors.blue),
    'comment' => (Icons.mode_comment_rounded, VoyagoColors.primary),
    'trip_remixed' => (Icons.explore_rounded, VoyagoColors.yellow),
    'tribe_trip' => (Icons.groups_rounded, VoyagoColors.primary),
    'circle_request' => (Icons.lock_person_rounded, VoyagoColors.yellow),
    'review_thanks' => (Icons.star_rounded, VoyagoColors.yellow),
    _ => (Icons.notifications_active_rounded, VoyagoColors.orange),
  };

  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        behavior: SnackBarBehavior.floating,
        backgroundColor: VoyagoColors.surface,
        elevation: 6,
        duration: const Duration(seconds: 5),
        margin: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: color.withValues(alpha: 0.4)),
        ),
        content: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(color: color.withValues(alpha: 0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: VoyagoColors.text, fontSize: 13.5, fontWeight: FontWeight.w800),
                  ),
                  if (n.body.isNotEmpty)
                    Text(
                      n.body,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
                    ),
                ],
              ),
            ),
          ],
        ),
        action: onOpen == null ? null : SnackBarAction(label: 'Voir', textColor: color, onPressed: onOpen),
      ),
    );
}
