import 'poi.dart';
import 'day_weather.dart';
import 'trip_visibility.dart';

export 'trip_visibility.dart';

class Trip {
  final String id;
  final String userId;
  final String destination;
  final String pace;
  final String budget;
  final int durationDays;
  final List<String> transports;
  final List<String> interests;
  final List<POI> pois;
  final List<DayWeather> weather;
  final String? city;
  final String? country;
  final String? countryCode;
  final String? coverImageUrl;
  final String? startDate;
  final String? endDate;
  final bool isPublic;
  final TripVisibility visibility;
  final int likes;

  /// Nombre de voyageurs ayant refait ce voyage
  final int remixCount;

  /// Destination du voyage d'origine si celui-ci a été refait depuis la communauté
  final String? remixedFromDestination;
  final DateTime createdAt;

  /// Voyage terminé manuellement (il rejoint alors le journal).
  final DateTime? completedAt;

  /// Valise : objets prêts / total (0 / 0 si pas encore préparée)
  final int packingPacked;
  final int packingTotal;

  const Trip({
    required this.id,
    required this.userId,
    required this.destination,
    required this.pace,
    required this.budget,
    required this.durationDays,
    required this.transports,
    required this.interests,
    required this.pois,
    required this.weather,
    this.city,
    this.country,
    this.countryCode,
    this.coverImageUrl,
    this.startDate,
    this.endDate,
    required this.isPublic,
    this.visibility = TripVisibility.private,
    required this.likes,
    this.remixCount = 0,
    this.remixedFromDestination,
    required this.createdAt,
    this.packingPacked = 0,
    this.packingTotal = 0,
    this.completedAt,
  });

  factory Trip.fromJson(Map<String, dynamic> json) {
    List<POI> parsePois(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw.map((e) => POI.fromJson(e as Map<String, dynamic>)).toList();
      }
      return [];
    }

    List<DayWeather> parseWeather(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) {
        return raw
            .map((e) => DayWeather.fromJson(e as Map<String, dynamic>))
            .toList();
      }
      return [];
    }

    List<String> parseStringList(dynamic raw) {
      if (raw == null) return [];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return [];
    }

    final packingItems = [
      for (final c in ((json['packing_list'] as Map?)?['categories'] as List? ?? const []))
        if (c is Map) ...((c['items'] as List?) ?? const []),
    ];
    return Trip(
      id: json['id']?.toString() ?? json['_id']?.toString() ?? '',
      userId:
          json['user_id']?.toString() ?? json['userId']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      city: json['city']?.toString(),
      country: json['country']?.toString(),
      countryCode: json['country_code']?.toString() ?? json['countryCode']?.toString(),
      coverImageUrl: json['cover_image_url']?.toString() ?? json['coverImageUrl']?.toString(),
      startDate: json['start_date']?.toString() ?? json['startDate']?.toString(),
      endDate: json['end_date']?.toString() ?? json['endDate']?.toString(),
      pace: json['pace']?.toString() ?? '',
      budget: json['budget']?.toString() ?? '',
      durationDays: (json['duration_days'] as num?)?.toInt() ??
          (json['durationDays'] as num?)?.toInt() ??
          1,
      transports: parseStringList(json['transports']),
      interests: parseStringList(json['interests']),
      pois: parsePois(json['pois']),
      weather: parseWeather(json['weather']),
      isPublic: json['is_public'] as bool? ?? json['isPublic'] as bool? ?? false,
      visibility: TripVisibility.fromJson(
        json['visibility'],
        isPublic: json['is_public'] as bool? ?? json['isPublic'] as bool?,
      ),
      likes: (json['likes'] as num?)?.toInt() ?? 0,
      remixCount: (json['remix_count'] as num?)?.toInt() ?? 0,
      remixedFromDestination: (json['remixed_from'] as Map<String, dynamic>?)?['destination']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : json['createdAt'] != null
              ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
              : DateTime.now(),
      completedAt: DateTime.tryParse(json['completed_at']?.toString() ?? '')?.toLocal(),
      packingPacked: packingItems.where((e) => e is Map && e['packed'] == true).length,
      packingTotal: packingItems.length,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'destination': destination,
      if (city != null) 'city': city,
      if (country != null) 'country': country,
      if (countryCode != null) 'country_code': countryCode,
      if (coverImageUrl != null) 'cover_image_url': coverImageUrl,
      if (startDate != null) 'start_date': startDate,
      if (endDate != null) 'end_date': endDate,
      'pace': pace,
      'budget': budget,
      'duration_days': durationDays,
      'transports': transports,
      'interests': interests,
      'pois': pois.map((p) => p.toJson()).toList(),
      'weather': weather.map((w) => w.toJson()).toList(),
      'is_public': isPublic,
      'visibility': visibility.value,
      'likes': likes,
      'created_at': createdAt.toIso8601String(),
      if (completedAt != null) 'completed_at': completedAt!.toIso8601String(),
    };
  }

  /// Dernier jour du voyage : end_date, sinon start_date + durée. Null si non daté.
  DateTime? get lastDay {
    final end = DateTime.tryParse(endDate ?? '');
    if (end != null) return end;
    final start = DateTime.tryParse(startDate ?? '');
    if (start == null) return null;
    return start.add(Duration(days: (durationDays - 1).clamp(0, 365)));
  }

  /// Voyage passé (même règle que le serveur) : terminé manuellement ou dernier
  /// jour écoulé. Il quitte alors la carte pour le journal de voyage.
  bool get isPast {
    if (completedAt != null) return true;
    final last = lastDay;
    if (last == null) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return DateTime(last.year, last.month, last.day).isBefore(today);
  }

  List<POI> poisForDay(int day) {
    final filtered = pois.where((p) => p.day == day).toList();
    filtered.sort((a, b) => a.order.compareTo(b.order));
    return filtered;
  }

  POI? get firstPoiWithImage {
    try {
      return pois.firstWhere((p) => p.imageUrl != null && p.imageUrl!.isNotEmpty);
    } catch (_) {
      return pois.isNotEmpty ? pois.first : null;
    }
  }

  String? get displayCoverImage {
    if (coverImageUrl != null && coverImageUrl!.isNotEmpty) {
      return coverImageUrl;
    }
    return firstPoiWithImage?.imageUrl;
  }
}
