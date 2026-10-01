import 'dart:io';
import 'package:flutter/foundation.dart';

class Endpoints {
  Endpoints._();

  // Configuration dynamique de l'hôte Backend
  static const String _envBackendUrl = String.fromEnvironment('BACKEND_URL');

  // Hôtes Backend (Port NestJS : 3333)
  static const String localNetworkBackendUrl = 'http://192.168.1.81:3333';
  // static const String localNetworkBackendUrl = 'http://10.75.1.6:3333'; // Autre réseau
  static const String androidEmulatorBackendUrl = 'http://10.0.2.2:3333';
  static const String localhostBackendUrl = 'http://127.0.0.1:3333';

  // false = Tunnel USB adb reverse (recommandé en développement avec câble, insensible au pare-feu/Wi-Fi)
  // true = IP locale Wi-Fi (nécessite d'autoriser le port 3333 dans le pare-feu Windows)
  static const bool useLanIpForDevice = false;

  static String get baseUrl {
    if (_envBackendUrl.isNotEmpty) {
      return _envBackendUrl;
    }
    if (kIsWeb) {
      return localhostBackendUrl;
    }
    if (Platform.isAndroid) {
      if (useLanIpForDevice) {
        return localNetworkBackendUrl;
      }
      return localhostBackendUrl;
    }
    return localhostBackendUrl;
  }

  // --- HEALTH & DOCS ---
  static const String health = '/api';
  static const String swagger = '/api/docs';

  // --- AUTH MODULE ---
  static const String signupEmail = '/api/auth/email/signup';
  static const String loginEmail = '/api/auth/email/login';
  static const String googleSession = '/api/auth/google/session';
  static const String guestLogin = '/api/auth/guest';
  static const String forgotPassword = '/api/auth/forgot-password';
  static const String resetPassword = '/api/auth/reset-password';
  static const String authOptions = '/api/auth/options';
  static const String updateProfile = '/api/auth/me';

  // --- UPLOAD MODULE ---
  static const String uploadProfilePicture = '/api/upload/profile-picture';

  // --- TRIPS MODULE ---
  static const String generateTrip = '/api/trips/generate';
  static String userTrips(String userId) => '/api/trips/$userId';
  static String tripDetail(String tripId) => '/api/trip/$tripId';

  // --- COMMUNITY MODULE ---
  static const String publicFeed = '/api/community/feed';
  static String likeTrip(String tripId) => '/api/community/trip/$tripId/like';
  static const String communityCircles = '/api/community/circles';
  static String circleDetail(String circleId) => '/api/community/circles/$circleId';
  static String joinCircle(String circleId) => '/api/community/circles/$circleId/join';
  static String leaveCircle(String circleId) => '/api/community/circles/$circleId/leave';
  static String circlePosts(String circleId) => '/api/community/circles/$circleId/posts';
  static String shareTripToCircle(String circleId) => '/api/community/circles/$circleId/share-trip';
  static String likeCommunityPost(String postId) => '/api/community/posts/$postId/like';

  // --- GAMIFICATION MODULE ---
  static String profile(String userId) => '/api/profile/$userId';
  static const String awardXp = '/api/profile/award-xp';
  static const String xpRewards = '/api/xp-rewards';
  static const String badges = '/api/badges';

  // --- PRO & PAYMENTS MODULE ---
  static const String proCheckout = '/api/pro/checkout';
  static String proStatus(String sessionId) => '/api/pro/status/$sessionId';

  // --- NOTIFICATIONS MODULE ---
  static const String notifications = '/api/notifications';
  static const String notificationsUnreadCount = '/api/notifications/unread-count';
  static const String notificationsReadAll = '/api/notifications/read-all';
  static const String notificationsArrival = '/api/notifications/arrival';
  static String notificationRead(String id) => '/api/notifications/$id/read';

  // --- PLACES (AVIS & ÉTOILES) MODULE ---
  static const String placeReviews = '/api/places/reviews';
  static const String placeStats = '/api/places/stats';

  // --- JOURNAL DE VOYAGE MODULE ---
  static const String journal = '/api/journal';
  static String journalDetail(String tripId) => '/api/journal/$tripId';
  static String journalEntries(String tripId) => '/api/journal/$tripId/entries';
  static String journalPhotos(String tripId) => '/api/journal/$tripId/photos';
  static String journalPhoto(String tripId, String key) => '/api/journal/$tripId/photos/$key';
  static String journalComplete(String tripId) => '/api/journal/$tripId/complete';
  static String journalReopen(String tripId) => '/api/journal/$tripId/reopen';
  static String journalShare(String tripId) => '/api/journal/$tripId/share';

  // --- INTERESTS MODULE ---
  static const String interests = '/api/interests';
}
