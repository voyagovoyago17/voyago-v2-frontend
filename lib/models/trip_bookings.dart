/// Réservations & Budget d'un voyage (GET /api/trip/:id/bookings).
library;

int _int(dynamic v) => v is num ? v.round() : int.tryParse('$v') ?? 0;
int? _intOrNull(dynamic v) => v == null ? null : _int(v);
String? _str(dynamic v) => v == null || '$v'.isEmpty ? null : '$v';

class BudgetSplit {
  final int lodging;
  final int transport;
  final int activities;
  final int meals;
  final int other;

  const BudgetSplit({this.lodging = 0, this.transport = 0, this.activities = 0, this.meals = 0, this.other = 0});

  factory BudgetSplit.fromJson(Map<String, dynamic>? j) => BudgetSplit(
        lodging: _int(j?['lodging']),
        transport: _int(j?['transport']),
        activities: _int(j?['activities']),
        meals: _int(j?['meals']),
        other: _int(j?['other']),
      );
}

class TripBudget {
  final int total;
  final BudgetSplit allocation;
  final int spent;
  final BudgetSplit spentBy;
  final int flightsSpent;
  final int available;
  final BudgetSplit estimatedNeeds;

  const TripBudget({
    required this.total,
    required this.allocation,
    required this.spent,
    required this.spentBy,
    required this.flightsSpent,
    required this.available,
    required this.estimatedNeeds,
  });

  factory TripBudget.fromJson(Map<String, dynamic> j) => TripBudget(
        total: _int(j['total']),
        allocation: BudgetSplit.fromJson(_map(j['allocation'])),
        spent: _int(j['spent']),
        spentBy: BudgetSplit.fromJson(_map(j['spent_by'])),
        flightsSpent: _int(j['flights_spent']),
        available: _int(j['available']),
        estimatedNeeds: BudgetSplit.fromJson(_map(j['estimated_needs'])),
      );
}

Map<String, dynamic>? _map(dynamic v) => v is Map ? Map<String, dynamic>.from(v) : null;
List<Map<String, dynamic>> _list(dynamic v) =>
    v is List ? v.whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList() : const [];

class StayProposal {
  final int index;
  final int fromDay;
  final int toDay;
  final int nights;
  final String area;
  final String? why;
  final String? tip;
  final List<String> near;
  final int? nightlyMin;
  final int? nightlyMax;
  final int nightlyBudget;
  final String? checkin;
  final String? checkout;
  final String? bookingUrl;
  final String? airbnbUrl;

  const StayProposal({
    required this.index,
    required this.fromDay,
    required this.toDay,
    required this.nights,
    required this.area,
    this.why,
    this.tip,
    this.near = const [],
    this.nightlyMin,
    this.nightlyMax,
    required this.nightlyBudget,
    this.checkin,
    this.checkout,
    this.bookingUrl,
    this.airbnbUrl,
  });

  /// Le prix estimé tient-il dans le plafond par nuit ?
  bool get fitsBudget => nightlyMin == null || nightlyBudget <= 0 || nightlyMin! <= nightlyBudget;

  factory StayProposal.fromJson(Map<String, dynamic> j) {
    final links = _map(j['links']) ?? const {};
    return StayProposal(
      index: _int(j['index']),
      fromDay: _int(j['from_day']),
      toDay: _int(j['to_day']),
      nights: _int(j['nights']),
      area: '${j['area'] ?? ''}',
      why: _str(j['why']),
      tip: _str(j['tip']),
      near: (j['near'] as List?)?.map((e) => '$e').toList() ?? const [],
      nightlyMin: _intOrNull(j['nightly_min']),
      nightlyMax: _intOrNull(j['nightly_max']),
      nightlyBudget: _int(j['nightly_budget']),
      checkin: _str(j['checkin']),
      checkout: _str(j['checkout']),
      bookingUrl: _str(links['booking']),
      airbnbUrl: _str(links['airbnb']),
    );
  }
}

class TransportOption {
  /// flight | intercity | pass | car | bike
  final String kind;
  final String title;
  final String subtitle;
  final String? link;
  final int? price;
  final String? priceLabel;
  final bool outsideBudget;

  const TransportOption({
    required this.kind,
    required this.title,
    required this.subtitle,
    this.link,
    this.price,
    this.priceLabel,
    this.outsideBudget = false,
  });

  factory TransportOption.fromJson(Map<String, dynamic> j) => TransportOption(
        kind: '${j['kind'] ?? ''}',
        title: '${j['title'] ?? ''}',
        subtitle: '${j['subtitle'] ?? ''}',
        link: _str(j['link']),
        price: _intOrNull(j['price']),
        priceLabel: _str(j['price_label']),
        outsideBudget: j['outside_budget'] == true,
      );
}

class ActivityProposal {
  final String name;
  final int? day;
  final int priceAdult;
  final int? priceChild;
  final int priceGroup;
  final String? advice;
  final String? imageUrl;
  final String? link;

  const ActivityProposal({
    required this.name,
    this.day,
    required this.priceAdult,
    this.priceChild,
    required this.priceGroup,
    this.advice,
    this.imageUrl,
    this.link,
  });

  factory ActivityProposal.fromJson(Map<String, dynamic> j) => ActivityProposal(
        name: '${j['name'] ?? ''}',
        day: _intOrNull(j['day']),
        priceAdult: _int(j['price_adult']),
        priceChild: _intOrNull(j['price_child']),
        priceGroup: _int(j['price_group']),
        advice: _str(j['advice']),
        imageUrl: _str(j['image_url']),
        link: _str(j['link']),
      );
}

class BookedItem {
  final String id;
  /// lodging | transport | activities | meals | flights | other
  final String category;
  final String label;
  final int amount;
  final String? url;
  final String? date;

  const BookedItem({required this.id, required this.category, required this.label, required this.amount, this.url, this.date});

  factory BookedItem.fromJson(Map<String, dynamic> j) => BookedItem(
        id: '${j['id'] ?? ''}',
        category: '${j['category'] ?? 'other'}',
        label: '${j['label'] ?? ''}',
        amount: _int(j['amount']),
        url: _str(j['url']),
        date: _str(j['date']),
      );
}

class TripBookings {
  final String tripId;
  final String destination;
  final String? coverImageUrl;
  final String currency;
  final String level;
  final bool announcedBudget;
  final bool datesKnown;
  final int adults;
  final List<int> childrenAges;
  final int days;
  final int nights;
  final TripBudget budget;
  final List<StayProposal> stays;
  final List<TransportOption> transport;
  final List<ActivityProposal> activities;
  final List<BookedItem> bookings;
  final bool estimatesAvailable;

  const TripBookings({
    required this.tripId,
    required this.destination,
    this.coverImageUrl,
    required this.currency,
    required this.level,
    required this.announcedBudget,
    required this.datesKnown,
    required this.adults,
    required this.childrenAges,
    required this.days,
    required this.nights,
    required this.budget,
    required this.stays,
    required this.transport,
    required this.activities,
    required this.bookings,
    required this.estimatesAvailable,
  });

  int get travelersCount => adults + childrenAges.length;

  factory TripBookings.fromJson(Map<String, dynamic> j) {
    final travelers = _map(j['travelers']) ?? const {};
    return TripBookings(
      tripId: '${j['trip_id'] ?? ''}',
      destination: '${j['destination'] ?? ''}',
      coverImageUrl: _str(j['cover_image_url']),
      currency: '${j['currency'] ?? 'EUR'}',
      level: '${j['level'] ?? 'moyen'}',
      announcedBudget: j['announced_budget'] == true,
      datesKnown: j['dates_known'] == true,
      adults: _int(travelers['adults'] ?? 1),
      childrenAges: (travelers['children_ages'] as List?)?.map(_int).toList() ?? const [],
      days: _int(j['days']),
      nights: _int(j['nights']),
      budget: TripBudget.fromJson(_map(j['budget']) ?? const {}),
      stays: _list(j['stays']).map(StayProposal.fromJson).toList(),
      transport: _list(j['transport']).map(TransportOption.fromJson).toList(),
      activities: _list(j['activities']).map(ActivityProposal.fromJson).toList(),
      bookings: _list(j['bookings']).map(BookedItem.fromJson).toList(),
      estimatesAvailable: j['estimates_available'] == true,
    );
  }
}
