import 'trip.dart';

/// Voyage déjà programmé : ses jours sont hachurés dans le calendrier.
class BusyRange {
  final String tripId;
  final String destination;
  final DateTime start;
  final DateTime end;

  const BusyRange({required this.tripId, required this.destination, required this.start, required this.end});

  factory BusyRange.fromJson(Map<String, dynamic> json) {
    DateTime day(String? s) {
      final d = DateTime.tryParse(s ?? '') ?? DateTime.now();
      return DateTime(d.year, d.month, d.day);
    }

    return BusyRange(
      tripId: json['trip_id']?.toString() ?? '',
      destination: json['destination']?.toString() ?? '',
      start: day(json['start']?.toString()),
      end: day(json['end']?.toString()),
    );
  }

  /// Même règle que le serveur : le jour de transition est permis
  /// (un voyage peut commencer le jour où le précédent se termine).
  bool overlaps(DateTime s0, DateTime e0) {
    final s = DateTime(s0.year, s0.month, s0.day);
    final e = DateTime(e0.year, e0.month, e0.day);
    return (s.isBefore(end) && start.isBefore(e)) || s == start;
  }
}

/// Premier voyage programmé qui chevauche la période, s'il y en a un.
BusyRange? busyConflict(List<BusyRange> ranges, DateTime start, DateTime end) {
  for (final r in ranges) {
    if (r.overlaps(start, end)) return r;
  }
  return null;
}

class EditCounter {
  final int used;

  /// null = illimité
  final int? limit;

  const EditCounter({this.used = 0, this.limit});

  factory EditCounter.fromJson(Map? json) => EditCounter(
        used: (json?['used'] as num?)?.toInt() ?? 0,
        limit: (json?['limit'] as num?)?.toInt(),
      );

  bool get unlimited => limit == null;
  int get remaining => limit == null ? 1 << 30 : (limit! - used).clamp(0, 1 << 30);
}

/// Ce que le voyageur peut encore modifier sur un voyage, selon sa formule.
class TripEditOptions {
  final String plan; // free | monthly | annual | lifetime
  final bool started;
  final bool finished;
  final int currentDay;
  final bool canCancel;
  final bool canShiftDates;
  final bool canRegenerate;
  final bool canEditPlaces;
  final EditCounter dateChanges;
  final EditCounter swaps;
  final int redosUsed;
  final int redosRemaining;
  final int extraCredits;
  final bool freeTrial;
  final List<int> planBDays;
  /// Éclats : solde, prix d'une modification, échanges faits / permis sur ce voyage
  final int? shardBalance;
  final int shardsPerCredit;
  final int shardCreditsUsed;
  final int shardCreditsLimit;
  final int shardsEarnedOnTrip;

  /// Pépite légendaire ramassée : plan B pluie offert (gratuit)
  final bool planBGift;
  final double packPrice;
  final int packCredits;

  const TripEditOptions({
    this.plan = 'free',
    this.started = false,
    this.finished = false,
    this.currentDay = 0,
    this.canCancel = false,
    this.canShiftDates = false,
    this.canRegenerate = false,
    this.canEditPlaces = true,
    this.dateChanges = const EditCounter(),
    this.swaps = const EditCounter(),
    this.redosUsed = 0,
    this.redosRemaining = 0,
    this.extraCredits = 0,
    this.freeTrial = false,
    this.planBDays = const [],
    this.shardBalance,
    this.shardsPerCredit = 25,
    this.shardCreditsUsed = 0,
    this.shardCreditsLimit = 1,
    this.shardsEarnedOnTrip = 0,
    this.planBGift = false,
    this.packPrice = 0.99,
    this.packCredits = 3,
  });

  bool get isPro => plan != 'free';

  String get planLabel => switch (plan) {
        'monthly' => 'Pro Mensuel',
        'annual' => 'Pro Annuel',
        'lifetime' => 'Pro À vie',
        _ => 'Gratuit',
      };

  factory TripEditOptions.fromJson(Map<String, dynamic> json) {
    final redos = json['redos'] as Map? ?? const {};
    final pack = json['pack'] as Map? ?? const {};
    final shards = json['shards'] as Map? ?? const {};
    final shardCredits = shards['trip_credits'] as Map? ?? const {};
    return TripEditOptions(
      plan: json['plan']?.toString() ?? 'free',
      started: json['started'] == true,
      finished: json['finished'] == true,
      currentDay: (json['current_day'] as num?)?.toInt() ?? 0,
      canCancel: json['can_cancel'] == true,
      canShiftDates: json['can_shift_dates'] == true,
      canRegenerate: json['can_regenerate'] == true,
      canEditPlaces: json['can_edit_places'] != false,
      dateChanges: EditCounter.fromJson(json['date_changes'] as Map?),
      swaps: EditCounter.fromJson(json['swaps'] as Map?),
      redosUsed: (redos['used'] as num?)?.toInt() ?? 0,
      redosRemaining: (redos['remaining'] as num?)?.toInt() ?? 0,
      extraCredits: (redos['extra_credits'] as num?)?.toInt() ?? 0,
      freeTrial: redos['free_trial'] == true,
      planBDays: [for (final d in (json['plan_b_days'] as List? ?? const [])) (d as num).toInt()],
      shardBalance: (shards['balance'] as num?)?.toInt(),
      shardsPerCredit: (shards['per_credit'] as num?)?.toInt() ?? 25,
      shardCreditsUsed: (shardCredits['used'] as num?)?.toInt() ?? 0,
      shardCreditsLimit: (shardCredits['limit'] as num?)?.toInt() ?? 1,
      shardsEarnedOnTrip: (shards['earned_on_trip'] as num?)?.toInt() ?? 0,
      planBGift: json['plan_b_gift'] == true,
      packPrice: (pack['price'] as num?)?.toDouble() ?? 0.99,
      packCredits: (pack['credits'] as num?)?.toInt() ?? 3,
    );
  }
}

/// Lieu réel vérifié proposé pour remplacer une étape.
class PoiAlternative {
  final String name;
  final String? kind;
  final double distanceKm;
  final String? imageUrl;

  const PoiAlternative({required this.name, this.kind, this.distanceKm = 0, this.imageUrl});

  factory PoiAlternative.fromJson(Map<String, dynamic> json) => PoiAlternative(
        name: json['name']?.toString() ?? '',
        kind: json['kind']?.toString(),
        distanceKm: (json['distance_km'] as num?)?.toDouble() ?? 0,
        imageUrl: json['image_url']?.toString(),
      );
}

/// Résultat d'une modification : le voyage à jour et les compteurs restants.
class TripEditResult {
  final Trip trip;
  final TripEditOptions options;

  const TripEditResult(this.trip, this.options);

  factory TripEditResult.fromJson(Map<String, dynamic> json) => TripEditResult(
        Trip.fromJson(Map<String, dynamic>.from(json['trip'] as Map)),
        TripEditOptions.fromJson(Map<String, dynamic>.from(json['options'] as Map)),
      );
}

/// Bourse d'Éclats : gagnés en ramassant des pépites, jamais retirés des XP de niveau.
class ShardWallet {
  final int balance;
  final int earned;
  final int spent;
  final int gemsCollected;
  final int perfectDays;
  final int perCredit;

  const ShardWallet({
    this.balance = 0,
    this.earned = 0,
    this.spent = 0,
    this.gemsCollected = 0,
    this.perfectDays = 0,
    this.perCredit = 25,
  });

  factory ShardWallet.fromJson(Map<String, dynamic> json) => ShardWallet(
        balance: (json['balance'] as num?)?.toInt() ?? 0,
        earned: (json['earned'] as num?)?.toInt() ?? 0,
        spent: (json['spent'] as num?)?.toInt() ?? 0,
        gemsCollected: (json['gems_collected'] as num?)?.toInt() ?? 0,
        perfectDays: (json['perfect_days'] as num?)?.toInt() ?? 0,
        perCredit: (json['per_credit'] as num?)?.toInt() ?? 25,
      );
}
