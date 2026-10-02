import '../core/config/app_environment.dart';

class Endpoints {
  Endpoints._();

  // URL du backend selon l'environnement (local / prod), voir AppConfig
  static String get baseUrl => AppConfig.backendUrl;

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
  static const String me = '/api/auth/me';
  static const String emailVerificationSend = '/api/auth/email/verification/send';
  static const String emailVerificationConfirm = '/api/auth/email/verification/confirm';

  // --- UPLOAD MODULE ---
  static const String uploadProfilePicture = '/api/upload/profile-picture';

  // --- TRIPS MODULE ---
  static const String generateTrip = '/api/trips/generate';
  static String userTrips(String userId) => '/api/trips/$userId';
  static String tripDetail(String tripId) => '/api/trip/$tripId';
  static String tripVisibility(String tripId) => '/api/trip/$tripId/visibility';
  static String tripRemix(String tripId) => '/api/trip/$tripId/remix';
  static String tripGems(String tripId) => '/api/trip/$tripId/gems';
  static String tripGemsStart(String tripId) => '/api/trip/$tripId/gems/start';
  static String tripGemCollect(String tripId, String gemId) => '/api/trip/$tripId/gems/$gemId/collect';

  // --- COMMUNITY MODULE ---
  static const String publicFeed = '/api/community/feed';
  static String likeTrip(String tripId) => '/api/community/trip/$tripId/like';
  static const String communityCircles = '/api/community/circles';
  static String circleDetail(String circleId) => '/api/community/circles/$circleId';
  static const String joinCircleByCode = '/api/community/circles/join-by-code';
  static String circleInviteCode(String circleId) => '/api/community/circles/$circleId/invite-code';
  static String circleChallenges(String circleId) => '/api/community/circles/$circleId/challenges';
  static String circleTripPlans(String circleId) => '/api/community/circles/$circleId/trip-plans';
  static String tripPlan(String planId) => '/api/community/trip-plans/$planId';
  static String tripPlanVotes(String planId) => '/api/community/trip-plans/$planId/votes';
  static String tripPlanFinalize(String planId) => '/api/community/trip-plans/$planId/finalize';
  static String tripPlanJoin(String planId) => '/api/community/trip-plans/$planId/join';
  static String joinCircle(String circleId) => '/api/community/circles/$circleId/join';
  static String leaveCircle(String circleId) => '/api/community/circles/$circleId/leave';
  static String circlePosts(String circleId) => '/api/community/circles/$circleId/posts';
  static String shareTripToCircle(String circleId) => '/api/community/circles/$circleId/share-trip';
  static String likeCommunityPost(String postId) => '/api/community/posts/$postId/like';
  static String communityPost(String postId) => '/api/community/posts/$postId';
  static const String homeFeed = '/api/community/home-feed';
  static const String communityComments = '/api/community/comments';
  static String communityComment(String commentId) => '/api/community/comments/$commentId';
  static const String communityReports = '/api/community/reports';
  static const String blockedUsers = '/api/community/blocks';
  static String blockUser(String userId) => '/api/community/users/$userId/block';

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
  static const String notificationDevices = '/api/notifications/devices';

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
