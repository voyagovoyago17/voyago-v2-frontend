import 'dart:math' as math;

/// État d'une étape de la journée dans la frise.
enum StopState { done, current, upcoming }

/// Avancement de la journée dans la frise : chaque étape passée devient verte et le trait
/// se remplit au fil de l'heure (fuseau de la destination) et de la position du voyageur.
class DayProgress {
  final List<StopState> stops;

  /// Remplissage du trait pendant la visite de l'étape i (0 à 1)
  final List<double> visitFill;

  /// Remplissage du trajet entre l'étape i et la suivante (0 à 1)
  final List<double> travelFill;

  /// La journée affichée est aujourd'hui sur place
  final bool live;

  const DayProgress({required this.stops, required this.visitFill, required this.travelFill, this.live = false});

  factory DayProgress.idle(int count) => DayProgress(
        stops: List.filled(count, StopState.upcoming),
        visitFill: List.filled(count, 0),
        travelFill: List.filled(math.max(0, count - 1), 0),
      );

  /// [starts] : heure de début (minutes depuis minuit) ; [durations] : durée de visite ;
  /// [dayDate] : date de la journée (null si voyage sans dates) ;
  /// [nowAtDestination] : heure « murale » sur place (champs y/m/j/h/min) ;
  /// [nearStop] : étape où se trouve le voyageur (GPS), sinon null.
  factory DayProgress.compute({
    required List<int> starts,
    required List<int> durations,
    required DateTime? dayDate,
    required DateTime nowAtDestination,
    int? nearStop,
  }) {
    final n = starts.length;
    if (n == 0) return DayProgress.idle(0);
    final today = DateTime(nowAtDestination.year, nowAtDestination.month, nowAtDestination.day);
    final day = dayDate == null ? null : DateTime(dayDate.year, dayDate.month, dayDate.day);

    List<StopState> stops;
    List<double> visit;
    List<double> travel;
    var live = false;

    if (day != null && day.isBefore(today)) {
      // Journée passée : tout est parcouru
      stops = List.filled(n, StopState.done);
      visit = List.filled(n, 1);
      travel = List.filled(n - 1, 1);
    } else if (day != null && day.isAtSameMomentAs(today)) {
      live = true;
      final now = nowAtDestination.hour * 60 + nowAtDestination.minute;
      stops = [];
      visit = [];
      travel = [];
      for (var i = 0; i < n; i++) {
        final start = starts[i];
        final end = start + math.max(1, durations[i]);
        stops.add(now >= end ? StopState.done : (now >= start ? StopState.current : StopState.upcoming));
        visit.add(((now - start) / (end - start)).clamp(0.0, 1.0));
        if (i < n - 1) {
          final next = starts[i + 1];
          travel.add(next <= end ? (now >= end ? 1.0 : 0.0) : ((now - end) / (next - end)).clamp(0.0, 1.0));
        }
      }
    } else {
      final idle = DayProgress.idle(n);
      stops = [...idle.stops];
      visit = [...idle.visitFill];
      travel = [...idle.travelFill];
    }

    // Sur place : la position du voyageur fait foi (en avance ou en retard sur l'horaire)
    if (nearStop != null && nearStop >= 0 && nearStop < n && (live || day == null)) {
      for (var i = 0; i < n; i++) {
        if (i < nearStop) {
          stops[i] = StopState.done;
          visit[i] = 1;
          if (i < n - 1) travel[i] = 1;
        } else if (i == nearStop) {
          stops[i] = StopState.current;
          visit[i] = math.max(visit[i], 0.08);
          if (i < n - 1) travel[i] = 0;
        } else {
          stops[i] = StopState.upcoming;
          visit[i] = 0;
          if (i < n - 1) travel[i] = 0;
        }
      }
      live = true;
    }
    return DayProgress(stops: stops, visitFill: visit, travelFill: travel, live: live);
  }

  int get doneCount => stops.where((s) => s == StopState.done).length;
}
