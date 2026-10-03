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

/// Un partenaire de réservation et son lien pré-rempli (affilié quand la marque l'a validé)
class PartnerChoice {
  final String partner;
  final String label;
  final String url;
  final String? note;

  const PartnerChoice({required this.partner, required this.label, required this.url, this.note});

  factory PartnerChoice.fromJson(Map<String, dynamic> j) => PartnerChoice(
        partner: '${j['partner'] ?? ''}',
        label: '${j['label'] ?? ''}',
        url: '${j['url'] ?? ''}',
        note: _str(j['note']),
      );
}

List<PartnerChoice> _choices(dynamic v) =>
    _list(v).map(PartnerChoice.fromJson).where((c) => c.url.startsWith('http')).toList();

/// Autre façon de dormir sur une étape (type, quartier, prix pour le groupe)
class StayOption {
  final String kind;
  final String area;
  final String? why;
  final int nightlyMin;
  final int nightlyMax;
  final bool fitsBudget;
  final List<PartnerChoice> choices;

  const StayOption({
    required this.kind,
    required this.area,
    this.why,
    required this.nightlyMin,
    required this.nightlyMax,
    required this.fitsBudget,
    required this.choices,
  });

  factory StayOption.fromJson(Map<String, dynamic> j) => StayOption(
        kind: '${j['kind'] ?? ''}',
        area: '${j['area'] ?? ''}',
        why: _str(j['why']),
        nightlyMin: _int(j['nightly_min']),
        nightlyMax: _int(j['nightly_max']),
        fitsBudget: j['fits_budget'] == true,
        choices: _choices(j['choices']),
      );
}

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
  final List<PartnerChoice> choices;
  final List<StayOption> options;

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
    this.choices = const [],
    this.options = const [],
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
      choices: _choices(j['choices']),
      options: _list(j['options']).map(StayOption.fromJson).toList(),
    );
  }
}

/// Vol réel (prix Aviasales via Travelpayouts), par personne aller-retour
class FlightOffer {
  final int price;
  final String? airline;
  final String? departureAt;
  final String? returnAt;
  final int transfers;
  final int? returnTransfers;
  final int? durationTo;
  final int? duration;
  final int? saving;
  final String link;

  const FlightOffer({
    required this.price,
    this.airline,
    this.departureAt,
    this.returnAt,
    this.transfers = 0,
    this.returnTransfers,
    this.durationTo,
    this.duration,
    this.saving,
    required this.link,
  });

  factory FlightOffer.fromJson(Map<String, dynamic> j) => FlightOffer(
        price: _int(j['price']),
        airline: _str(j['airline']),
        departureAt: _str(j['departure_at']),
        returnAt: _str(j['return_at']),
        transfers: _int(j['transfers']),
        returnTransfers: _intOrNull(j['return_transfers']),
        durationTo: _intOrNull(j['duration_to']),
        duration: _intOrNull(j['duration']),
        saving: _intOrNull(j['saving']),
        link: '${j['link'] ?? ''}',
      );
}

/// Un repère du comparatif de vols : le moins cher, direct, le plus rapide, le meilleur rapport
class FlightHighlight {
  final String kind;
  final FlightOffer offer;

  const FlightHighlight({required this.kind, required this.offer});
}

/// Un jour de départ voisin (± 3 jours) ou un aéroport proche, avec l'économie pour le groupe
class FlightAlternative {
  final String? origin;
  final String? destination;
  final String departure;
  final String? returnDate;
  final int price;
  final int? saving;
  final int transfers;
  final String link;

  const FlightAlternative({
    this.origin,
    this.destination,
    required this.departure,
    this.returnDate,
    required this.price,
    this.saving,
    this.transfers = 0,
    required this.link,
  });

  factory FlightAlternative.fromJson(Map<String, dynamic> j) => FlightAlternative(
        origin: _str(j['origin']),
        destination: _str(j['destination']),
        departure: '${j['departure'] ?? ''}',
        returnDate: _str(j['return']),
        price: _int(j['price']),
        saving: _intOrNull(j['saving']),
        transfers: _int(j['transfers']),
        link: '${j['link'] ?? ''}',
      );
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
  final bool livePrices;
  final List<FlightOffer> offers;
  final List<FlightOffer> cheaperDates;
  final List<PartnerChoice> choices;
  final List<FlightHighlight> highlights;
  final List<FlightAlternative> flexible;
  final List<FlightAlternative> nearby;
  /// good | average | high : le meilleur prix face aux prix du mois
  final String? priceVerdict;
  final int? monthMedian;
  final int passengers;

  const TransportOption({
    required this.kind,
    required this.title,
    required this.subtitle,
    this.link,
    this.price,
    this.priceLabel,
    this.outsideBudget = false,
    this.livePrices = false,
    this.offers = const [],
    this.cheaperDates = const [],
    this.choices = const [],
    this.highlights = const [],
    this.flexible = const [],
    this.nearby = const [],
    this.priceVerdict,
    this.monthMedian,
    this.passengers = 1,
  });

  factory TransportOption.fromJson(Map<String, dynamic> j) => TransportOption(
        kind: '${j['kind'] ?? ''}',
        title: '${j['title'] ?? ''}',
        subtitle: '${j['subtitle'] ?? ''}',
        link: _str(j['link']),
        price: _intOrNull(j['price']),
        priceLabel: _str(j['price_label']),
        outsideBudget: j['outside_budget'] == true,
        livePrices: j['live_prices'] == true,
        offers: _list(j['offers']).map(FlightOffer.fromJson).toList(),
        cheaperDates: _list(j['cheaper_dates']).map(FlightOffer.fromJson).toList(),
        choices: _choices(j['choices']),
        highlights: _list(j['highlights'])
            .where((h) => h['offer'] is Map)
            .map((h) => FlightHighlight(
                  kind: '${h['kind'] ?? ''}',
                  offer: FlightOffer.fromJson(Map<String, dynamic>.from(h['offer'] as Map)),
                ))
            .toList(),
        flexible: _list(j['flexible']).map(FlightAlternative.fromJson).toList(),
        nearby: _list(j['nearby']).map(FlightAlternative.fromJson).toList(),
        priceVerdict: _str(_map(j['insight'])?['verdict']),
        monthMedian: _intOrNull(_map(j['insight'])?['median']),
        passengers: _int(j['passengers'] ?? 1),
      );
}

/// Pass touristique comparé aux billets à l'unité
class PassCompare {
  final String name;
  final int priceGroup;
  final List<String> covers;
  final int individualTotal;
  final int saving;
  final bool worthIt;
  final String? tip;

  const PassCompare({
    required this.name,
    required this.priceGroup,
    required this.covers,
    required this.individualTotal,
    required this.saving,
    required this.worthIt,
    this.tip,
  });

  factory PassCompare.fromJson(Map<String, dynamic> j) => PassCompare(
        name: '${j['name'] ?? ''}',
        priceGroup: _int(j['price_group']),
        covers: (j['covers'] as List?)?.map((e) => '$e').toList() ?? const [],
        individualTotal: _int(j['individual_total']),
        saving: _int(j['saving']),
        worthIt: j['worth_it'] == true,
        tip: _str(j['tip']),
      );
}

/// Une économie possible, avec l'onglet où la concrétiser
class PlanSaving {
  final String kind;
  final String title;
  final String detail;
  final int amount;
  final int tab;

  const PlanSaving({required this.kind, required this.title, required this.detail, required this.amount, required this.tab});

  factory PlanSaving.fromJson(Map<String, dynamic> j) => PlanSaving(
        kind: '${j['kind'] ?? ''}',
        title: '${j['title'] ?? ''}',
        detail: '${j['detail'] ?? ''}',
        amount: _int(j['amount']),
        tab: _int(j['tab']),
      );
}

/// Le meilleur plan : coût estimé sur place, vols et économies classées
class TripPlan {
  final int costOnSite;
  final int budgetTotal;
  final bool fits;
  final int gap;
  final int? flightsGroup;
  final int? totalWithFlights;
  final List<PlanSaving> savings;
  final List<String> moneyTips;
  final String? bookingWindow;

  const TripPlan({
    required this.costOnSite,
    required this.budgetTotal,
    required this.fits,
    required this.gap,
    this.flightsGroup,
    this.totalWithFlights,
    this.savings = const [],
    this.moneyTips = const [],
    this.bookingWindow,
  });

  factory TripPlan.fromJson(Map<String, dynamic> j) => TripPlan(
        costOnSite: _int(j['cost_on_site']),
        budgetTotal: _int(j['budget_total']),
        fits: j['fits'] == true,
        gap: _int(j['gap']),
        flightsGroup: _intOrNull(j['flights_group']),
        totalWithFlights: _intOrNull(j['total_with_flights']),
        savings: _list(j['savings']).map(PlanSaving.fromJson).toList(),
        moneyTips: (j['money_tips'] as List?)?.map((e) => '$e').toList() ?? const [],
        bookingWindow: _str(j['booking_window']),
      );
}

/// Une journée du voyage : nuit, visites et dépenses prévues
class DayPlan {
  final int day;
  final String? date;
  final String? area;
  final bool sleeps;
  final String? weatherIcon;
  final int? tempMax;
  final List<({String name, int price})> places;
  final int lodging;
  final int activities;
  final int meals;
  final int transport;
  final int total;
  final int budget;

  const DayPlan({
    required this.day,
    this.date,
    this.area,
    required this.sleeps,
    this.weatherIcon,
    this.tempMax,
    required this.places,
    required this.lodging,
    required this.activities,
    required this.meals,
    required this.transport,
    required this.total,
    required this.budget,
  });

  factory DayPlan.fromJson(Map<String, dynamic> j) {
    final costs = _map(j['costs']) ?? const {};
    final weather = _map(j['weather']);
    return DayPlan(
      day: _int(j['day']),
      date: _str(j['date']),
      area: _str(j['area']),
      sleeps: j['sleeps'] == true,
      weatherIcon: _str(weather?['icon']),
      tempMax: _intOrNull(weather?['temp_max']),
      places: _list(j['places']).map((p) => (name: '${p['name'] ?? ''}', price: _int(p['price']))).toList(),
      lodging: _int(costs['lodging']),
      activities: _int(costs['activities']),
      meals: _int(costs['meals']),
      transport: _int(costs['transport']),
      total: _int(j['total']),
      budget: _int(j['budget']),
    );
  }
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
  final List<PartnerChoice> choices;

  const ActivityProposal({
    required this.name,
    this.day,
    required this.priceAdult,
    this.priceChild,
    required this.priceGroup,
    this.advice,
    this.imageUrl,
    this.link,
    this.choices = const [],
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
        choices: _choices(j['choices']),
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
  final List<DayPlan> daily;
  final List<TransportOption> transport;
  final List<ActivityProposal> activities;
  final List<BookedItem> bookings;
  final PassCompare? passCompare;
  final TripPlan? plan;
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
    this.daily = const [],
    required this.transport,
    required this.activities,
    required this.bookings,
    this.passCompare,
    this.plan,
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
      daily: _list(j['daily']).map(DayPlan.fromJson).toList(),
      transport: _list(j['transport']).map(TransportOption.fromJson).toList(),
      activities: _list(j['activities']).map(ActivityProposal.fromJson).toList(),
      bookings: _list(j['bookings']).map(BookedItem.fromJson).toList(),
      passCompare: _map(j['pass_compare']) == null ? null : PassCompare.fromJson(_map(j['pass_compare'])!),
      plan: _map(j['plan']) == null ? null : TripPlan.fromJson(_map(j['plan'])!),
      estimatesAvailable: j['estimates_available'] == true,
    );
  }
}
