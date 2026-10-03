import 'package:flutter_test/flutter_test.dart';
import 'package:voyagooo/models/day_progress.dart';

void main() {
  final starts = [540, 735, 835]; // 9h00, 12h15, 13h55
  final durations = [180, 90, 60];
  final day = DateTime(2026, 10, 3);

  test('journée en cours : visite puis trajet', () {
    final p = DayProgress.compute(starts: starts, durations: durations, dayDate: day, nowAtDestination: DateTime(2026, 10, 3, 10, 30));
    expect(p.live, isTrue);
    expect(p.stops, [StopState.current, StopState.upcoming, StopState.upcoming]);
    expect(p.visitFill[0], closeTo(0.5, 0.01));
    final q = DayProgress.compute(starts: starts, durations: durations, dayDate: day, nowAtDestination: DateTime(2026, 10, 3, 12, 7));
    expect(q.stops[0], StopState.done);
    expect(q.travelFill[0], closeTo(0.47, 0.02));
  });

  test('journées passées et à venir', () {
    expect(DayProgress.compute(starts: starts, durations: durations, dayDate: day, nowAtDestination: DateTime(2026, 10, 4, 8)).doneCount, 3);
    expect(DayProgress.compute(starts: starts, durations: durations, dayDate: day, nowAtDestination: DateTime(2026, 10, 2, 20)).doneCount, 0);
  });

  test('la position du voyageur fait foi', () {
    final p = DayProgress.compute(starts: starts, durations: durations, dayDate: day, nowAtDestination: DateTime(2026, 10, 3, 9, 10), nearStop: 1);
    expect(p.stops, [StopState.done, StopState.current, StopState.upcoming]);
    final undated = DayProgress.compute(starts: starts, durations: durations, dayDate: null, nowAtDestination: DateTime(2026, 10, 3, 9), nearStop: 2);
    expect(undated.doneCount, 2);
  });
}
