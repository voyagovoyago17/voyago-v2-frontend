import 'poi.dart';

/// Lieu proposé au vote dans un voyage de tribu.
class PlanCandidate {
  final String key;
  final POI poi;
  final int up;
  final int down;

  /// 'up', 'down' ou null si je n'ai pas encore voté
  final String? myVote;

  const PlanCandidate({required this.key, required this.poi, this.up = 0, this.down = 0, this.myVote});

  factory PlanCandidate.fromJson(Map<String, dynamic> json) {
    return PlanCandidate(
      key: json['key']?.toString() ?? '',
      poi: POI.fromJson(json),
      up: (json['up'] as num?)?.toInt() ?? 0,
      down: (json['down'] as num?)?.toInt() ?? 0,
      myVote: json['my_vote']?.toString(),
    );
  }

  int get score => up - down;

  PlanCandidate withMyVote(String vote, {int? up, int? down}) =>
      PlanCandidate(key: key, poi: poi, up: up ?? this.up, down: down ?? this.down, myVote: vote);
}

/// Voyage de tribu : lieux proposés par l'IA, votés par les membres du cercle.
class TribeTripPlan {
  final String id;
  final String circleId;
  final String createdBy;
  final String destination;
  final String? coverImageUrl;
  final int durationDays;
  final String? startDate;
  final String pace;
  final String status; // 'voting' | 'finalized'
  final List<PlanCandidate> candidates;
  final List<POI> finalPois;
  final int votersCount;
  final int myVotesCount;
  final int joinedCount;
  final bool joinedByMe;
  final bool canFinalize;
  final Map<String, dynamic>? creator;
  final DateTime createdAt;

  const TribeTripPlan({
    required this.id,
    required this.circleId,
    required this.createdBy,
    required this.destination,
    this.coverImageUrl,
    required this.durationDays,
    this.startDate,
    this.pace = 'equilibre',
    this.status = 'voting',
    this.candidates = const [],
    this.finalPois = const [],
    this.votersCount = 0,
    this.myVotesCount = 0,
    this.joinedCount = 0,
    this.joinedByMe = false,
    this.canFinalize = false,
    this.creator,
    required this.createdAt,
  });

  bool get isVoting => status == 'voting';
  bool get isFinalized => status == 'finalized';

  /// Lieux sur lesquels je n'ai pas encore voté
  List<PlanCandidate> get toVote => candidates.where((c) => c.myVote == null).toList();

  String get creatorName {
    final pseudo = creator?['pseudo']?.toString();
    if (pseudo != null && pseudo.isNotEmpty) return pseudo;
    return creator?['name']?.toString() ?? 'Un membre';
  }

  factory TribeTripPlan.fromJson(Map<String, dynamic> json) {
    List<T> parse<T>(dynamic raw, T Function(Map<String, dynamic>) f) =>
        raw is List ? raw.whereType<Map<String, dynamic>>().map(f).toList() : <T>[];
    return TribeTripPlan(
      id: json['id']?.toString() ?? '',
      circleId: json['circle_id']?.toString() ?? '',
      createdBy: json['created_by']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      coverImageUrl: json['cover_image_url']?.toString(),
      durationDays: (json['duration_days'] as num?)?.toInt() ?? 1,
      startDate: json['start_date']?.toString(),
      pace: json['pace']?.toString() ?? 'equilibre',
      status: json['status']?.toString() ?? 'voting',
      candidates: parse(json['candidates'], PlanCandidate.fromJson),
      finalPois: parse(json['final_pois'], POI.fromJson),
      votersCount: (json['voters_count'] as num?)?.toInt() ?? 0,
      myVotesCount: (json['my_votes_count'] as num?)?.toInt() ?? 0,
      joinedCount: (json['joined_count'] as num?)?.toInt() ?? 0,
      joinedByMe: json['joined_by_me'] as bool? ?? false,
      canFinalize: json['can_finalize'] as bool? ?? false,
      creator: json['creator'] as Map<String, dynamic>?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '')?.toLocal() ?? DateTime.now(),
    );
  }
}

/// Défi mensuel collectif d'un cercle.
class CircleChallenge {
  final String id;
  final String emoji;
  final String title;
  final String description;
  final int target;
  final int progress;
  final bool completed;
  final int contributorsCount;
  final int myContribution;

  const CircleChallenge({
    required this.id,
    required this.emoji,
    required this.title,
    required this.description,
    required this.target,
    required this.progress,
    required this.completed,
    this.contributorsCount = 0,
    this.myContribution = 0,
  });

  double get ratio => target <= 0 ? 0 : (progress / target).clamp(0, 1).toDouble();

  factory CircleChallenge.fromJson(Map<String, dynamic> json) {
    return CircleChallenge(
      id: json['id']?.toString() ?? '',
      emoji: json['emoji']?.toString() ?? '🎯',
      title: json['title']?.toString() ?? '',
      description: json['description']?.toString() ?? '',
      target: (json['target'] as num?)?.toInt() ?? 1,
      progress: (json['progress'] as num?)?.toInt() ?? 0,
      completed: json['completed'] as bool? ?? false,
      contributorsCount: (json['contributors_count'] as num?)?.toInt() ?? 0,
      myContribution: (json['my_contribution'] as num?)?.toInt() ?? 0,
    );
  }
}

/// Défis du mois d'un cercle.
class CircleChallenges {
  final DateTime? endsAt;
  final List<CircleChallenge> challenges;

  const CircleChallenges({this.endsAt, this.challenges = const []});

  factory CircleChallenges.fromJson(Map<String, dynamic> json) {
    return CircleChallenges(
      endsAt: DateTime.tryParse(json['ends_at']?.toString() ?? '')?.toLocal(),
      challenges: (json['challenges'] as List? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(CircleChallenge.fromJson)
          .toList(),
    );
  }
}
