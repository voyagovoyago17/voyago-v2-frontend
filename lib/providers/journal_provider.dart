import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api.dart';
import '../models/journal.dart';
import '../models/trip.dart';
import 'auth_provider.dart';
import 'trips_provider.dart';

final journalApiProvider = Provider<JournalApi>((ref) => JournalApi());

/// Voyages passés (journal de voyage).
final journalListProvider = FutureProvider.autoDispose<List<JournalTripSummary>>((ref) async {
  if (!ref.watch(isAuthenticatedProvider)) return [];
  return ref.watch(journalApiProvider).list();
});

/// Journal détaillé d'un voyage.
/// « Et maintenant ? » : idées de prochain voyage pour un voyage terminé
final journalNextIdeasProvider = FutureProvider.autoDispose.family<List<NextTripIdea>, String>((ref, tripId) {
  return ref.watch(journalApiProvider).nextIdeas(tripId);
});

final journalDetailProvider = FutureProvider.autoDispose.family<JournalDetail, String>((ref, tripId) async {
  return ref.watch(journalApiProvider).detail(tripId);
});

/// Voyages en cours ou à venir : les seuls affichés sur la carte.
List<Trip> activeTrips(List<Trip> trips) => trips.where((t) => !t.isPast).toList();

/// Termine / rouvre un voyage puis rafraîchit carte et journal.
Future<void> setTripCompleted(WidgetRef ref, {required String tripId, required bool completed}) async {
  final api = ref.read(journalApiProvider);
  if (completed) {
    await api.complete(tripId);
  } else {
    await api.reopen(tripId);
  }
  final user = ref.read(currentUserProvider);
  if (user != null) ref.invalidate(tripsProvider(user.userId));
  ref.invalidate(journalListProvider);
  ref.invalidate(journalDetailProvider(tripId));
}
