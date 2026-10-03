import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api.dart';
import '../models/trip.dart';
import '../models/trip_gem.dart';
import '../models/trip_edits.dart';

final tripsApiProvider = Provider<TripsApi>((ref) => TripsApi());

/// Provider pour la liste des voyages de l'utilisateur
final tripsProvider = FutureProvider.family<List<Trip>, String>((ref, userId) async {
  if (userId.isEmpty) return [];
  final api = ref.watch(tripsApiProvider);
  return api.getUserTrips(userId);
});

/// Provider pour le détail d'un voyage spécifique
final tripDetailProvider = FutureProvider.family<Trip, String>((ref, tripId) async {
  if (tripId.isEmpty) throw ApiException(message: 'Identifiant de voyage requis');
  final api = ref.watch(tripsApiProvider);
  return api.getTripById(tripId);
});

/// Radar des pépites d'un voyage (auteur connecté uniquement)
final tripGemsProvider = FutureProvider.family<TripGems, String>((ref, tripId) async {
  if (tripId.isEmpty || tripId.startsWith('demo')) return const TripGems();
  return ref.watch(tripsApiProvider).getGems(tripId);
});

/// Jours déjà pris par mes voyages programmés (paramètre : voyage à ignorer)
final busyDatesProvider = FutureProvider.autoDispose.family<List<BusyRange>, String?>((ref, excludeTripId) async {
  try {
    return await ref.watch(tripsApiProvider).getBusyDates(excludeTripId: excludeTripId);
  } catch (_) {
    return const [];
  }
});

/// Droits et compteurs de modification d'un voyage
final tripEditOptionsProvider = FutureProvider.autoDispose.family<TripEditOptions, String>((ref, tripId) async {
  return ref.watch(tripsApiProvider).getEditOptions(tripId);
});

/// État du générateur d'itinéraires IA
class TripGeneratorState {
  final bool isGenerating;
  final String? progressMessage;
  final Trip? generatedTrip;
  final String? error;

  const TripGeneratorState({
    this.isGenerating = false,
    this.progressMessage,
    this.generatedTrip,
    this.error,
  });

  TripGeneratorState copyWith({
    bool? isGenerating,
    String? progressMessage,
    Trip? generatedTrip,
    String? error,
    bool clearError = false,
  }) {
    return TripGeneratorState(
      isGenerating: isGenerating ?? this.isGenerating,
      progressMessage: progressMessage ?? this.progressMessage,
      generatedTrip: generatedTrip ?? this.generatedTrip,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class TripGeneratorNotifier extends StateNotifier<TripGeneratorState> {
  final TripsApi _tripsApi;
  final Ref _ref;

  TripGeneratorNotifier(this._tripsApi, this._ref) : super(const TripGeneratorState());

  /// Génère un itinéraire IA complet avec Claude / Gemini
  Future<Trip> generate({
    required String destination,
    required int durationDays,
    required String pace,
    required List<String> transports,
    required String budget,
    required List<String> interests,
    String? startDate,
    String? endDate,
    String? city,
    String? country,
    String? countryCode,
    String? userId,
    Map<String, dynamic> extra = const {},
  }) async {
    state = const TripGeneratorState(
      isGenerating: true,
      progressMessage: 'Voyagooo 🦜 analyse vos envies de voyage...',
    );

    try {
      final trip = await _tripsApi.generateTrip(
        destination: destination,
        durationDays: durationDays,
        pace: pace,
        transports: transports,
        budget: budget,
        interests: interests,
        startDate: startDate,
        endDate: endDate,
        city: city,
        country: country,
        countryCode: countryCode,
        extra: extra,
      );

      state = TripGeneratorState(
        isGenerating: false,
        generatedTrip: trip,
        progressMessage: 'Itinéraire prêt ! 🦜✨',
      );

      // Invalider le cache des voyages pour recharger la liste à jour
      if (userId != null && userId.isNotEmpty) {
        _ref.invalidate(tripsProvider(userId));
      }

      return trip;
    } on ApiException catch (e) {
      state = TripGeneratorState(
        isGenerating: false,
        error: e.message,
      );
      rethrow;
    } catch (e) {
      state = TripGeneratorState(
        isGenerating: false,
        error: e.toString(),
      );
      rethrow;
    }
  }

  void reset() {
    state = const TripGeneratorState();
  }
}

final tripGeneratorProvider =
    StateNotifierProvider<TripGeneratorNotifier, TripGeneratorState>((ref) {
  final api = ref.watch(tripsApiProvider);
  return TripGeneratorNotifier(api, ref);
});
