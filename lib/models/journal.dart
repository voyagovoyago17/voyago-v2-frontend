import 'day_weather.dart';
import 'poi.dart';

DateTime? _date(dynamic v) => DateTime.tryParse(v?.toString() ?? '');

/// Chiffres clés d'un voyage passé.
class JournalStats {
  final double distanceKm;
  final int placesCount;
  final int visitedCount;
  final int reviewsCount;
  final int favoritesCount;
  final double? avgRatingGiven;
  final int hiddenGems;
  final int photosCount;
  final int notesCount;
  final int xpEarned;

  /// Radar : pépites ramassées sur le terrain / proposées
  final int gemsCollected;
  final int gemsTotal;

  const JournalStats({
    this.distanceKm = 0,
    this.placesCount = 0,
    this.visitedCount = 0,
    this.reviewsCount = 0,
    this.favoritesCount = 0,
    this.avgRatingGiven,
    this.hiddenGems = 0,
    this.photosCount = 0,
    this.notesCount = 0,
    this.xpEarned = 0,
    this.gemsCollected = 0,
    this.gemsTotal = 0,
  });

  factory JournalStats.fromJson(Map<String, dynamic>? j) {
    j ??= const {};
    return JournalStats(
      distanceKm: (j['distance_km'] as num?)?.toDouble() ?? 0,
      placesCount: (j['places_count'] as num?)?.toInt() ?? 0,
      visitedCount: (j['visited_count'] as num?)?.toInt() ?? 0,
      reviewsCount: (j['reviews_count'] as num?)?.toInt() ?? 0,
      favoritesCount: (j['favorites_count'] as num?)?.toInt() ?? 0,
      avgRatingGiven: (j['avg_rating_given'] as num?)?.toDouble(),
      hiddenGems: (j['hidden_gems'] as num?)?.toInt() ?? 0,
      photosCount: (j['photos_count'] as num?)?.toInt() ?? 0,
      notesCount: (j['notes_count'] as num?)?.toInt() ?? 0,
      xpEarned: (j['xp_earned'] as num?)?.toInt() ?? 0,
      gemsCollected: (j['gems_collected'] as num?)?.toInt() ?? 0,
      gemsTotal: (j['gems_total'] as num?)?.toInt() ?? 0,
    );
  }

  String get distanceLabel =>
      distanceKm >= 10 ? '${distanceKm.round()} km' : '${distanceKm.toStringAsFixed(1)} km';
}

/// Réservations & Budget, archivé avec le voyage.
class JournalBudget {
  final String currency;
  final int total;
  final int spent;
  final int flightsSpent;
  final bool announcedBudget;
  final Map<String, int> allocation;
  final Map<String, int> spentBy;
  final List<({String category, String label, int amount})> bookings;
  final bool hasData;

  const JournalBudget({
    required this.currency,
    required this.total,
    required this.spent,
    this.flightsSpent = 0,
    this.announcedBudget = false,
    this.allocation = const {},
    this.spentBy = const {},
    this.bookings = const [],
    this.hasData = false,
  });

  static Map<String, int> _ints(dynamic v) =>
      v is Map ? v.map((k, val) => MapEntry('$k', (val as num?)?.round() ?? 0)) : const {};

  factory JournalBudget.fromJson(Map<String, dynamic> j) => JournalBudget(
        currency: j['currency']?.toString() ?? 'EUR',
        total: (j['total'] as num?)?.round() ?? 0,
        spent: (j['spent'] as num?)?.round() ?? 0,
        flightsSpent: (j['flights_spent'] as num?)?.round() ?? 0,
        announcedBudget: j['announced_budget'] == true,
        allocation: _ints(j['allocation']),
        spentBy: _ints(j['spent_by']),
        bookings: (j['bookings'] as List? ?? [])
            .whereType<Map>()
            .map((b) => (
                  category: b['category']?.toString() ?? 'other',
                  label: b['label']?.toString() ?? '',
                  amount: (b['amount'] as num?)?.round() ?? 0,
                ))
            .toList(),
        hasData: j['has_data'] == true || (j['spent'] as num? ?? 0) > 0,
      );

  bool get withinBudget => spent <= total;
}

/// Titre débloqué par le voyage.
class JournalBadge {
  final String title;
  final String icon;

  const JournalBadge({required this.title, required this.icon});

  factory JournalBadge.fromJson(Map<String, dynamic>? j) => JournalBadge(
        title: j?['title']?.toString() ?? 'Explorateur Voyagooo',
        icon: j?['icon']?.toString() ?? 'explore',
      );
}

/// Voyage passé dans la liste du journal.
class JournalTripSummary {
  final String tripId;
  final String destination;
  final String? country;
  final String? coverImageUrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final int durationDays;
  final bool journalShared;
  final JournalBadge badge;
  final JournalStats stats;
  /// Budget en bref (null si rien n'a été suivi)
  final JournalBudget? budget;

  const JournalTripSummary({
    required this.tripId,
    required this.destination,
    this.country,
    this.coverImageUrl,
    this.startDate,
    this.endDate,
    required this.durationDays,
    this.journalShared = false,
    required this.badge,
    required this.stats,
    this.budget,
  });

  factory JournalTripSummary.fromJson(Map<String, dynamic> j) => JournalTripSummary(
        tripId: j['trip_id']?.toString() ?? '',
        destination: j['destination']?.toString() ?? '',
        country: j['country']?.toString(),
        coverImageUrl: j['cover_image_url']?.toString(),
        startDate: _date(j['start_date']),
        endDate: _date(j['end_date']),
        durationDays: (j['duration_days'] as num?)?.toInt() ?? 1,
        journalShared: j['journal_shared'] == true,
        badge: JournalBadge.fromJson(j['badge'] as Map<String, dynamic>?),
        stats: JournalStats.fromJson(j['stats'] as Map<String, dynamic>?),
        budget: j['budget'] is Map ? JournalBudget.fromJson(Map<String, dynamic>.from(j['budget'] as Map)) : null,
      );
}

class JournalPhoto {
  final String url;
  final String key;

  const JournalPhoto({required this.url, required this.key});

  factory JournalPhoto.fromJson(Map<String, dynamic> j) =>
      JournalPhoto(url: j['url']?.toString() ?? '', key: j['key']?.toString() ?? '');
}

/// Souvenir écrit par le voyageur sur un lieu.
class JournalEntry {
  final String poiName;
  final int day;
  final String note;
  final List<String> moodTags;
  final List<JournalPhoto> photos;
  final bool visited;

  const JournalEntry({
    required this.poiName,
    required this.day,
    this.note = '',
    this.moodTags = const [],
    this.photos = const [],
    this.visited = false,
  });

  factory JournalEntry.fromJson(Map<String, dynamic> j) => JournalEntry(
        poiName: j['poi_name']?.toString() ?? '',
        day: (j['day'] as num?)?.toInt() ?? 1,
        note: j['note']?.toString() ?? '',
        moodTags: (j['mood_tags'] as List? ?? []).map((e) => e.toString()).toList(),
        photos: (j['photos'] as List? ?? [])
            .map((e) => JournalPhoto.fromJson(e as Map<String, dynamic>))
            .toList(),
        visited: j['visited'] == true,
      );
}

/// Lieu du journal : étape de l'itinéraire + souvenir + avis donné.
class JournalPlace {
  final POI poi;
  final bool visited;
  final JournalEntry? entry;
  final int? myRating;
  final bool myLiked;

  const JournalPlace({required this.poi, this.visited = false, this.entry, this.myRating, this.myLiked = false});

  factory JournalPlace.fromJson(Map<String, dynamic> j) {
    final review = j['review'] as Map<String, dynamic>?;
    return JournalPlace(
      poi: POI.fromJson(j),
      visited: j['visited'] == true,
      entry: j['entry'] is Map<String, dynamic> ? JournalEntry.fromJson(j['entry'] as Map<String, dynamic>) : null,
      myRating: (review?['rating'] as num?)?.toInt(),
      myLiked: review?['liked'] == true,
    );
  }

  /// Photo à mettre en avant : la sienne d'abord, sinon celle du lieu.
  String? get coverPhoto =>
      (entry?.photos.isNotEmpty ?? false) ? entry!.photos.first.url : poi.imageUrl;
}

class JournalDay {
  final int day;
  final DateTime? date;
  final DayWeather? weather;
  final List<JournalPlace> places;

  const JournalDay({required this.day, this.date, this.weather, this.places = const []});

  factory JournalDay.fromJson(Map<String, dynamic> j) => JournalDay(
        day: (j['day'] as num?)?.toInt() ?? 1,
        date: _date(j['date']),
        weather: j['weather'] is Map<String, dynamic> ? DayWeather.fromJson(j['weather'] as Map<String, dynamic>) : null,
        places: (j['pois'] as List? ?? [])
            .map((e) => JournalPlace.fromJson(e as Map<String, dynamic>))
            .toList(),
      );

  /// Ambiance dominante du jour (catégorie la plus présente).
  String get theme {
    final counts = <String, int>{};
    for (final p in places) {
      if (p.poi.category.isNotEmpty) counts[p.poi.category] = (counts[p.poi.category] ?? 0) + 1;
    }
    if (counts.isEmpty) return 'Exploration';
    final top = counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
    return top[0].toUpperCase() + top.substring(1);
  }
}

/// Journal complet d'un voyage.
class JournalDetail {
  final String tripId;
  final String destination;
  final String? country;
  final String? coverImageUrl;
  final DateTime? startDate;
  final DateTime? endDate;
  final int durationDays;
  final bool completedManually;
  final bool journalShared;
  final JournalBadge badge;
  final JournalStats stats;
  final List<JournalDay> days;
  final JournalBudget? budget;

  const JournalDetail({
    required this.tripId,
    required this.destination,
    this.country,
    this.coverImageUrl,
    this.startDate,
    this.endDate,
    required this.durationDays,
    this.completedManually = false,
    this.journalShared = false,
    required this.badge,
    required this.stats,
    this.days = const [],
    this.budget,
  });

  factory JournalDetail.fromJson(Map<String, dynamic> j) => JournalDetail(
        tripId: j['trip_id']?.toString() ?? '',
        destination: j['destination']?.toString() ?? '',
        country: j['country']?.toString(),
        coverImageUrl: j['cover_image_url']?.toString(),
        startDate: _date(j['start_date']),
        endDate: _date(j['end_date']),
        durationDays: (j['duration_days'] as num?)?.toInt() ?? 1,
        completedManually: j['completed_at'] != null,
        journalShared: j['journal_shared'] == true,
        badge: JournalBadge.fromJson(j['badge'] as Map<String, dynamic>?),
        stats: JournalStats.fromJson(j['stats'] as Map<String, dynamic>?),
        days: (j['days'] as List? ?? []).map((e) => JournalDay.fromJson(e as Map<String, dynamic>)).toList(),
        budget: j['budget'] is Map ? JournalBudget.fromJson(Map<String, dynamic>.from(j['budget'] as Map)) : null,
      );

  String get shortDestination => destination.split(',').first.trim();
}


/// « Et maintenant ? » : idée de prochain voyage.
class NextTripIdea {
  final String destination;
  final String country;
  final String emoji;
  final String kind;
  final String pitch;
  final String bestSeason;
  final int durationDays;
  final List<String> interests;

  const NextTripIdea({
    required this.destination,
    this.country = '',
    this.emoji = '🌍',
    this.kind = 'depaysement',
    this.pitch = '',
    this.bestSeason = '',
    this.durationDays = 5,
    this.interests = const [],
  });

  factory NextTripIdea.fromJson(Map<String, dynamic> j) => NextTripIdea(
        destination: j['destination']?.toString() ?? '',
        country: j['country']?.toString() ?? '',
        emoji: j['emoji']?.toString() ?? '🌍',
        kind: j['kind']?.toString() ?? 'depaysement',
        pitch: j['pitch']?.toString() ?? '',
        bestSeason: j['best_season']?.toString() ?? '',
        durationDays: (j['duration_days'] as num?)?.toInt() ?? 5,
        interests: (j['interests'] as List? ?? []).map((e) => e.toString()).toList(),
      );

  String get kindLabel => switch (kind) {
        'meme_esprit' => 'Même esprit',
        'pas_loin' => 'Pas loin',
        _ => 'Dépaysement',
      };

  String get fullName => country.isNotEmpty ? '$destination, $country' : destination;
}
