import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_animations/flutter_map_animations.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../models/trip.dart';
import '../models/poi.dart';
import '../models/day_weather.dart';
import '../providers/auth_provider.dart';
import '../providers/trips_provider.dart';
import '../providers/notifications_provider.dart';
import '../providers/journal_provider.dart';
import '../services/arrival_detector.dart';
import '../services/live_weather_service.dart';
import '../services/map_ambiance_service.dart';
import '../services/route_service.dart';
import '../services/cached_tile_provider.dart';
import '../theme.dart';
import '../widgets/weather_overlay.dart';
import '../widgets/poi_spotlight_card.dart';
import '../widgets/itinerary_bottom_sheet.dart';
import '../widgets/map_poi_pin.dart';
import '../widgets/traveler_drawer.dart';
import '../widgets/map_ambiance_overlay.dart';
import '../widgets/place_review_sheet.dart';

class ItineraryScreen extends ConsumerStatefulWidget {
  final String tripId;
  final Trip? trip;

  const ItineraryScreen({super.key, required this.tripId, this.trip});

  @override
  ConsumerState<ItineraryScreen> createState() => _ItineraryScreenState();
}

class _ItineraryScreenState extends ConsumerState<ItineraryScreen>
    with TickerProviderStateMixin {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  late final AnimatedMapController _animatedMapController;
  // Cache disque des tuiles : affichage instantané des zones déjà visitées
  final CachedTileProvider _tileProvider = CachedTileProvider();
  final TextEditingController _searchCtrl = TextEditingController();
  final FocusNode _searchFocus = FocusNode();

  int _selectedDay = 1;
  int? _activePoiIndex;
  Trip? _currentTrip;
  String _activeCityName = '';
  List<DayWeather>? _dynamicWeather;
  List<CityLocation> _searchResults = [];
  bool _isSearching = false;
  bool _showWeatherCard = true;
  bool _isWeatherMinimized = false;
  bool _forceDayMap = false;
  LatLng? _currentCenter;
  LatLng? _liveUserPosition;
  StreamSubscription<Position>? _userPositionSub;
  Timer? _ambianceRefreshTimer;
  Timer? _mapMoveDebounce;
  LatLng? _lastWeatherFetchCenter;

  // === ROUTING & DISTANCE TRACKING ===
  Map<int, RouteResult>? _poiDistances;       // user -> each POI
  Map<int, RouteResult>? _transitRoutes;      // POI[i] -> POI[i+1]
  RouteResult? _navigationRoute;              // route from user to selected/next POI
  int? _navigationTargetIndex;                // which POI we're navigating to
  Timer? _routeRecalcDebounce;
  LatLng? _lastRouteCalcPosition;             // avoid re-calc on micro-moves
  String? _transitRoutesKey;                  // "<tripId>|<day>" des trajets inter-POIs calculés

  @override
  void initState() {
    super.initState();
    _animatedMapController = AnimatedMapController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeInOutCubic,
    );
    if (widget.trip != null) {
      _currentTrip = widget.trip;
      _activeCityName = widget.trip!.destination;
    }
    // Mise à jour automatique minute par minute de l'ambiance solaire (comme hellobarber)
    _ambianceRefreshTimer = Timer.periodic(
      const Duration(minutes: 1),
      (_) {
        if (mounted) setState(() {});
      },
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initLiveLocationAndWeather();
      _bootstrapLiveWeather();
    });
  }

  @override
  void didUpdateWidget(covariant ItineraryScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.trip != null && widget.trip != oldWidget.trip) {
      setState(() {
        _currentTrip = widget.trip;
        _activeCityName = widget.trip!.destination;
        _selectedDay = 1;
        _activePoiIndex = null;
        _dynamicWeather = null;
        _currentCenter = null;
      });
      _bootstrapLiveWeather();
    } else if (widget.tripId.isNotEmpty && widget.tripId != oldWidget.tripId) {
      setState(() {
        _currentTrip = null;
        _selectedDay = 1;
        _activePoiIndex = null;
        _dynamicWeather = null;
        _currentCenter = null;
      });
    }
  }

  void _showSafeSnackBar(SnackBar snackBar) {
    if (!mounted) return;
    try {
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.hideCurrentSnackBar();
      messenger?.showSnackBar(snackBar);
    } catch (_) {}
  }

  /// Initialise la géolocalisation en temps réel de l'utilisateur (comme sur hellobarber)
  /// et récupère automatiquement la météo dynamique correspondant à sa position réelle.
  Future<void> _initLiveLocationAndWeather({bool centerOnUser = false}) async {
    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (centerOnUser) {
          _showSafeSnackBar(
            const SnackBar(
              content: Text('Veuillez activer le GPS pour vous localiser.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          if (centerOnUser) {
            _showSafeSnackBar(
              const SnackBar(
                content: Text('Permission de localisation requise pour la position en temps réel.'),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        if (centerOnUser) {
          _showSafeSnackBar(
            const SnackBar(
              content: Text('La localisation est désactivée dans les paramètres de votre appareil.'),
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }

      // 1. Tenter la dernière position connue pour une réactivité instantanée
      Position? position;
      try {
        position = await Geolocator.getLastKnownPosition();
      } catch (_) {}

      // 2. Obtenir la position actuelle précise
      position ??= await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.medium,
          timeLimit: Duration(seconds: 8),
        ),
      );

      final userCoords = LatLng(position.latitude, position.longitude);
      if (!mounted) return;

      setState(() {
        _liveUserPosition = userCoords;
      });

      // Si l'utilisateur clique sur le bouton de position, ou si aucun voyage n'a encore fixé le centre
      if (centerOnUser || (_currentTrip == null && _currentCenter == null)) {
        setState(() {
          _currentCenter = userCoords;
        });
        _animatedMapController.animateTo(dest: userCoords, zoom: 15.5);
      }

      // 3. Écouter les mises à jour en continu en temps réel (comme hellobarber)
      _subscribeUserPositionUpdates();

      // 4. Charger la météo dynamique en direct selon la position GPS exacte
      await _updateWeatherForPosition(
        userCoords.latitude,
        userCoords.longitude,
        autoUpdateCity: _currentTrip == null || _activeCityName.isEmpty,
      );

      // 5. Calculer les distances et itinéraires en temps réel
      _computeRoutesForCurrentDay();
    } catch (e) {
      debugPrint('Erreur lors de l\'initialisation GPS : $e');
    }
  }

  void _subscribeUserPositionUpdates() {
    _userPositionSub?.cancel();
    _userPositionSub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(
        accuracy: LocationAccuracy.medium,
        distanceFilter: 15,
      ),
    ).listen(
      (Position p) {
        if (!mounted) return;
        final newPos = LatLng(p.latitude, p.longitude);
        setState(() {
          _liveUserPosition = newPos;
        });
        // Recalculer les distances si l'utilisateur a bougé de plus de 100m
        _onUserPositionChangedForRoutes(newPos);
        // Arrivée sur un lieu de l'itinéraire → demande d'avis
        _checkArrival(newPos, p.accuracy);
      },
      onError: (_) {},
    );
  }

  bool _arrivalCheckInFlight = false;

  /// Détecte l'arrivée sur un lieu du voyage (position GPS en direct uniquement) :
  /// notification dans la cloche + bannière proposant de noter le lieu.
  Future<void> _checkArrival(LatLng position, double accuracy) async {
    final trip = _currentTrip;
    if (trip == null || trip.id.startsWith('demo') || _arrivalCheckInFlight) return;
    if (!ref.read(isAuthenticatedProvider)) return;

    _arrivalCheckInFlight = true;
    try {
      final poi = await ArrivalDetector.instance.detect(
        trip: trip,
        position: position,
        accuracyMeters: accuracy,
        selectedDay: _selectedDay,
      );
      if (poi == null || !mounted) return;
      await ArrivalDetector.instance.markPrompted(trip, poi);

      final destination = _activeCityName.isNotEmpty ? _activeCityName : trip.destination;
      ref.read(notificationsProvider.notifier).recordArrival(
            placeName: poi.name,
            lat: poi.lat,
            lng: poi.lng,
            tripId: trip.id,
            destination: destination,
            day: poi.day,
            imageUrl: poi.imageUrl,
          );
      HapticFeedback.heavyImpact();

      _showSafeSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 10),
          backgroundColor: VoyagoColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(color: VoyagoColors.primary.withValues(alpha: 0.4)),
          ),
          content: Row(
            children: [
              const Text('📍', style: TextStyle(fontSize: 22)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Bienvenue à ${poi.name} !',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w800, fontSize: 13),
                    ),
                    const Text(
                      'Note ta visite pour guider les prochains voyageurs',
                      style: TextStyle(color: VoyagoColors.muted, fontSize: 11),
                    ),
                  ],
                ),
              ),
            ],
          ),
          action: SnackBarAction(
            label: 'NOTER ⭐',
            textColor: VoyagoColors.yellow,
            onPressed: () {
              if (!mounted) return;
              showPlaceReviewSheet(
                context,
                ReviewTarget.fromPoi(poi, destination: destination, tripId: trip.id),
                fromArrival: true,
              );
            },
          ),
        ),
      );
    } catch (e) {
      debugPrint('Arrival detection error: $e');
    } finally {
      _arrivalCheckInFlight = false;
    }
  }

  /// Recalcule les distances/routes quand l'utilisateur bouge significativement (>100m).
  void _onUserPositionChangedForRoutes(LatLng pos) {
    if (_lastRouteCalcPosition != null) {
      final dist = RouteService.straightLineDistance(pos, _lastRouteCalcPosition!);
      if (dist < 100) return; // Ignore micro-moves < 100m
    }
    _routeRecalcDebounce?.cancel();
    _routeRecalcDebounce = Timer(const Duration(milliseconds: 800), () {
      _computeRoutesForCurrentDay();
    });
  }

  /// Calcule les trajets entre étapes consécutives du jour selon les transports du voyage.
  /// Indépendant du GPS : les temps de trajet s'affichent même sans localisation.
  Future<void> _computeTransitRoutesForDay() async {
    final trip = _currentTrip;
    if (trip == null || !mounted) return;
    final day = _selectedDay;
    final key = '${trip.id}|$day';
    _transitRoutesKey = key;

    final dayPois = trip.poisForDay(day);
    if (dayPois.length < 2) return;

    try {
      final futures = <Future<RouteResult>>[];
      for (int i = 0; i < dayPois.length - 1; i++) {
        final from = LatLng(dayPois[i].lat, dayPois[i].lng);
        final to = LatLng(dayPois[i + 1].lat, dayPois[i + 1].lng);
        final mode = TravelMode.forTrip(trip.transports, RouteService.straightLineDistance(from, to));
        futures.add(RouteService.instance.getRoute(from, to, mode: mode));
      }
      final results = await Future.wait(futures);
      // Ignorer un résultat arrivé après un changement de jour ou de voyage
      if (!mounted || _transitRoutesKey != key) return;
      setState(() {
        _transitRoutes = {for (int i = 0; i < results.length; i++) i: results[i]};
      });
    } catch (e) {
      debugPrint('Transit routes error: $e');
    }
  }

  /// Calcule les distances depuis l'utilisateur vers chaque POI du jour + routes inter-POIs.
  Future<void> _computeRoutesForCurrentDay() async {
    final trip = _currentTrip;
    final userPos = _liveUserPosition;
    if (trip == null || userPos == null || !mounted) return;

    final dayPois = trip.poisForDay(_selectedDay);
    if (dayPois.isEmpty) return;

    _lastRouteCalcPosition = userPos;

    try {
      // Distances user -> chaque POI (parallèle), selon les transports du voyage
      final poiPositions = dayPois.map((p) => LatLng(p.lat, p.lng)).toList();
      final distances = await RouteService.instance.getDistancesToPois(
        userPos,
        poiPositions,
        transports: trip.transports,
      );

      if (!mounted) return;
      setState(() {
        _poiDistances = distances;
      });
      // Les routes entre POIs consécutifs sont calculées par _computeTransitRoutesForDay (sans GPS)

      // Si navigation active, recalculer aussi la route de navigation
      if (_navigationTargetIndex != null && _navigationTargetIndex! < dayPois.length) {
        _computeNavigationRoute(dayPois[_navigationTargetIndex!]);
      }
    } catch (e) {
      debugPrint('Route calculation error: $e');
    }
  }

  /// Calcule la route de navigation depuis l'utilisateur vers un POI spécifique.
  Future<void> _computeNavigationRoute(POI targetPoi) async {
    final userPos = _liveUserPosition;
    if (userPos == null || !mounted) return;

    try {
      final target = LatLng(targetPoi.lat, targetPoi.lng);
      final route = await RouteService.instance.getRoute(
        userPos,
        target,
        mode: TravelMode.forTrip(
          _currentTrip?.transports ?? const [],
          RouteService.straightLineDistance(userPos, target),
        ),
      );
      if (!mounted) return;
      setState(() {
        _navigationRoute = route;
      });
    } catch (_) {}
  }

  /// Lance la navigation vers un POI (affiche le tracé + propose l'app externe).
  void _navigateToPoi(POI poi) {
    final trip = _currentTrip;
    if (trip == null) return;
    final dayPois = trip.poisForDay(_selectedDay);
    final idx = dayPois.indexOf(poi);

    setState(() {
      _navigationTargetIndex = idx >= 0 ? idx : 0;
      _activePoiIndex = idx >= 0 ? idx : null;
    });

    _computeNavigationRoute(poi);
    _animatedMapController.animateTo(dest: LatLng(poi.lat, poi.lng), zoom: 15.5);

    // Proposer d'ouvrir dans une app externe (Google Maps / Apple Maps)
    _showNavigationChoiceSheet(poi);
  }

  /// Affiche un bottom sheet pour choisir l'app de navigation externe.
  void _showNavigationChoiceSheet(POI poi) {
    if (!mounted) return;
    final userPos = _liveUserPosition;
    showModalBottomSheet(
      context: context,
      backgroundColor: VoyagoColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40, height: 4,
                  decoration: BoxDecoration(
                    color: VoyagoColors.muted.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                '📍 Naviguer vers ${poi.name}',
                style: const TextStyle(
                  color: VoyagoColors.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_navigationRoute != null) ...[
                const SizedBox(height: 6),
                Text(
                  '${_navigationRoute!.durationLabel} à pied · ${_navigationRoute!.distanceLabel}',
                  style: TextStyle(
                    color: VoyagoColors.muted.withValues(alpha: 0.8),
                    fontSize: 13,
                  ),
                ),
              ],
              const SizedBox(height: 16),
              _NavOption(
                icon: Icons.directions_walk,
                label: 'Suivre sur Voyagooo',
                subtitle: 'Itinéraire affiché sur la carte',
                onTap: () => Navigator.pop(ctx),
              ),
              const SizedBox(height: 8),
              _NavOption(
                icon: Icons.map_outlined,
                label: 'Google Maps',
                subtitle: 'Navigation vocale guidée',
                onTap: () {
                  Navigator.pop(ctx);
                  final origin = userPos != null
                      ? '${userPos.latitude},${userPos.longitude}'
                      : '';
                  final dest = '${poi.lat},${poi.lng}';
                  final url = 'https://www.google.com/maps/dir/$origin/$dest/@${poi.lat},${poi.lng},15z/data=!4m2!4m1!3e2';
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                },
              ),
              const SizedBox(height: 8),
              _NavOption(
                icon: Icons.navigation_rounded,
                label: 'Waze',
                subtitle: 'Navigation en temps réel',
                onTap: () {
                  Navigator.pop(ctx);
                  final url = 'https://waze.com/ul?ll=${poi.lat},${poi.lng}&navigate=yes';
                  launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _updateWeatherForPosition(
    double lat,
    double lng, {
    bool autoUpdateCity = false,
  }) async {
    final results = await Future.wait([
      LiveWeatherService.instance.fetchWeather(lat, lng),
      if (autoUpdateCity)
        LiveWeatherService.instance.reverseGeocode(lat, lng)
      else
        Future.value(null),
    ]);
    final weatherList = results[0] as List<DayWeather>;
    final city = results[1] as String?;

    if (!mounted) return;
    setState(() {
      if (weatherList.isNotEmpty) {
        _dynamicWeather = weatherList;
        _showWeatherCard = true;
      }
      if (city != null && city.isNotEmpty) {
        _activeCityName = city.split(',').first.trim();
        _searchCtrl.text = city;
      }
    });
  }

  Future<void> _bootstrapLiveWeather() async {
    final trip = _currentTrip;
    if (trip != null) {
      final pois = trip.poisForDay(1);
      final lat = pois.isNotEmpty ? pois.first.lat : (_liveUserPosition?.latitude ?? 48.8566);
      final lng = pois.isNotEmpty ? pois.first.lng : (_liveUserPosition?.longitude ?? 2.3522);
      final weather = await LiveWeatherService.instance.fetchWeather(lat, lng);
      if (mounted) {
        setState(() => _dynamicWeather = weather);
      }
    } else if (_liveUserPosition != null) {
      await _updateWeatherForPosition(
        _liveUserPosition!.latitude,
        _liveUserPosition!.longitude,
        autoUpdateCity: true,
      );
    }
  }

  void _onMapMovedDebounced(LatLng newCenter) {
    _mapMoveDebounce?.cancel();
    _mapMoveDebounce = Timer(const Duration(milliseconds: 550), () async {
      if (!mounted) return;

      // Seuil de distance : évite les requêtes inutiles lors de micro-mouvements (< 4.5 km)
      if (_lastWeatherFetchCenter != null) {
        final dLat = (newCenter.latitude - _lastWeatherFetchCenter!.latitude).abs();
        final dLng = (newCenter.longitude - _lastWeatherFetchCenter!.longitude).abs();
        if (dLat < 0.04 && dLng < 0.04) {
          return;
        }
      }

      _lastWeatherFetchCenter = newCenter;

      // Exécution parallèle pour performance maximale et synchronisation simultanée
      final results = await Future.wait([
        LiveWeatherService.instance.fetchWeather(
          newCenter.latitude,
          newCenter.longitude,
        ),
        LiveWeatherService.instance.reverseGeocode(
          newCenter.latitude,
          newCenter.longitude,
        ),
      ]);

      final weatherList = results[0] as List<DayWeather>;
      final detectedCity = results[1] as String?;

      if (!mounted) return;
      setState(() {
        _currentCenter = newCenter;
        if (weatherList.isNotEmpty) {
          _dynamicWeather = weatherList;
          _showWeatherCard = true;
        }
        if (detectedCity != null && detectedCity.isNotEmpty) {
          _activeCityName = detectedCity.split(',').first.trim();
          _searchCtrl.text = detectedCity;
        }
      });
    });
  }

  @override
  void dispose() {
    _mapMoveDebounce?.cancel();
    _ambianceRefreshTimer?.cancel();
    _routeRecalcDebounce?.cancel();
    _userPositionSub?.cancel();
    _animatedMapController.dispose();
    _searchCtrl.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  Future<void> _onSearchChanged(String query) async {
    if (query.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    final results = await LiveWeatherService.instance.searchCities(query);
    if (mounted) {
      setState(() {
        _searchResults = results;
        _isSearching = false;
      });
    }
  }

  Future<void> _selectCity(CityLocation city) async {
    final target = LatLng(city.lat, city.lng);
    _lastWeatherFetchCenter = target;
    setState(() {
      _currentCenter = target;
      _activeCityName = city.name;
      _searchResults = [];
      _isSearching = false;
      _forceDayMap = false; // Réinitialise pour appliquer l'ambiance astronomique réelle du lieu recherché
      _searchCtrl.text = city.displayName;
    });

    // Move map to city coordinates
    _animatedMapController.animateTo(dest: target, zoom: 13.5);

    // Fetch dynamic live weather
    final weatherList = await LiveWeatherService.instance.fetchWeather(city.lat, city.lng);
    if (mounted) {
      setState(() {
        _dynamicWeather = weatherList;
        _showWeatherCard = true;
      });
      _showSafeSnackBar(
        SnackBar(
          content: Row(
            children: [
              Text(
                weatherList.isNotEmpty ? weatherList.first.icon : '🌤️',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  weatherList.isNotEmpty
                      ? '${city.name} · ${weatherList.first.summary} ${weatherList.first.tempMax.round()}°C'
                      : 'Météo actualisée pour ${city.name}',
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          duration: const Duration(seconds: 2),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_currentTrip != null) {
      return _buildScreen(_currentTrip!);
    }

    final authState = ref.watch(authProvider);
    final user = authState.user;

    // Si aucun tripId n'est fourni, charger dynamiquement le dernier voyage créé de l'utilisateur connecté
    if (widget.tripId.isEmpty) {
      if (user != null) {
        final userTripsAsync = ref.watch(tripsProvider(user.userId));
        return userTripsAsync.when(
          data: (allTrips) {
            // Les voyages passés ont rejoint le journal : la carte montre le voyage en cours
            final trips = activeTrips(allTrips);
            if (trips.isNotEmpty) {
              _currentTrip ??= trips.first;
              if (_activeCityName.isEmpty) _activeCityName = trips.first.destination;
              return _buildScreen(trips.first);
            }
            return _buildScreen(_createDemoTrip());
          },
          loading: () => _buildLoadingScreen(),
          error: (_, __) => _buildScreen(_createDemoTrip()),
        );
      }
      return _buildScreen(_createDemoTrip());
    }

    final tripAsync = ref.watch(tripDetailProvider(widget.tripId));
    return tripAsync.when(
      data: (trip) {
        _currentTrip = trip;
        if (_activeCityName.isEmpty) _activeCityName = trip.destination;
        return _buildScreen(trip);
      },
      loading: () => _buildLoadingScreen(),
      error: (e, _) => _buildErrorScreen(e),
    );
  }

  Widget _buildLoadingScreen() {
    return Scaffold(
      backgroundColor: VoyagoColors.background,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color: VoyagoColors.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: VoyagoColors.primary,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Chargement de l\'itinéraire...',
              style: TextStyle(
                color: VoyagoColors.muted,
                fontSize: 15,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorScreen(Object e) {
    return Scaffold(
      backgroundColor: VoyagoColors.background,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('🧭', style: TextStyle(fontSize: 48)),
              const SizedBox(height: 16),
              const Text(
                'Impossible de charger l\'itinéraire',
                style: TextStyle(
                  color: VoyagoColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                e.toString(),
                style: const TextStyle(
                  color: VoyagoColors.muted,
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () => ref.invalidate(tripDetailProvider(widget.tripId)),
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Réessayer'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () {
                  setState(() => _currentTrip = _createDemoTrip());
                },
                child: const Text('Explorer la carte en mode démo'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildScreen(Trip trip) {
    final dayPois = trip.poisForDay(_selectedDay);

    // Trajets inter-étapes du jour affiché : (re)calculés à chaque changement de voyage ou de jour
    if (_transitRoutesKey != '${trip.id}|$_selectedDay') {
      _transitRoutesKey = '${trip.id}|$_selectedDay';
      _transitRoutes = null; // pas de trajets d'un autre jour / voyage pendant le calcul
      WidgetsBinding.instance.addPostFrameCallback((_) => _computeTransitRoutesForDay());
    }
    final center = _currentCenter ??
        (dayPois.isNotEmpty
            ? LatLng(dayPois.first.lat, dayPois.first.lng)
            : (_liveUserPosition ?? const LatLng(48.8566, 2.3522)));

    // Dynamic weather if city was searched, else trip's weather
    DayWeather? activeWeather;
    if (_dynamicWeather != null && _dynamicWeather!.isNotEmpty) {
      activeWeather = _dynamicWeather![
          (_selectedDay - 1).clamp(0, _dynamicWeather!.length - 1)];
    } else if (trip.weather.isNotEmpty) {
      activeWeather = trip.weather[
          (_selectedDay - 1).clamp(0, trip.weather.length - 1)];
    }

    // Résolution 100% automatique Jour / Nuit / Heure Dorée / Crépuscule (comme hellobarber)
    final ambiance = MapAmbiance.resolve(
      center: center,
      weatherCode: activeWeather?.weatherCode,
    );

    final authState = ref.watch(authProvider);
    final user = authState.user;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: VoyagoColors.background,
      drawer: TravelerDrawer(
        currentTripId: trip.id,
        onTripSelected: (newTrip) {
          setState(() {
            _currentTrip = newTrip;
            _activeCityName = newTrip.destination;
            _selectedDay = 1;
            _activePoiIndex = null;
            _dynamicWeather = null;
            _searchCtrl.clear();
          });
          final pois = newTrip.poisForDay(1);
          if (pois.isNotEmpty) {
            final target = LatLng(pois.first.lat, pois.first.lng);
            setState(() => _currentCenter = target);
            _animatedMapController.animateTo(dest: target, zoom: 13.5);
          }
        },
      ),
      body: Stack(
        children: [
          // === 1. FULL-SCREEN LEAFLET MAP (DYNAMIQUE JOUR / NUIT 100% GRATUIT) ===
          Positioned.fill(
            child: FlutterMap(
              mapController: _animatedMapController.mapController,
              options: MapOptions(
                initialCenter: center,
                initialZoom: 13.5,
                maxZoom: 18,
                minZoom: 3,
                onPositionChanged: (pos, hasGesture) {
                  if (hasGesture) {
                    _onMapMovedDebounced(pos.center);
                  }
                },
                onTap: (_, __) {
                  setState(() {
                    _activePoiIndex = null;
                    _searchResults = [];
                    _isSearching = false;
                  });
                  _searchFocus.unfocus();
                },
              ),
              children: [
                // Tuiles OpenStreetMap 100% gratuites sans API Key ni filigrane (haute définition, rues, édifices)
                TileLayer(
                  key: ValueKey('${ambiance.phase}_${ambiance.tileUrlTemplate}_$_forceDayMap'),
                  urlTemplate: ambiance.tileUrlTemplate,
                  userAgentPackageName: 'com.voyagooo.voyagooo',
                  tileProvider: _tileProvider,
                  maxNativeZoom: 19,
                  panBuffer: 1,
                  tileBuilder: (_forceDayMap || ambiance.tileColorFilter == null)
                      ? null
                      : (context, tileWidget, tile) => ColorFiltered(
                          colorFilter: ambiance.tileColorFilter!,
                          child: tileWidget,
                        ),
                ),
                RichAttributionWidget(
                  attributions: [
                    TextSourceAttribution(ambiance.attribution),
                  ],
                ),

                // Route polylines connecting the day's POIs (vraies routes OSRM ou fallback dotted)
                PolylineLayer(
                  polylines: [
                    // Polylines inter-POIs (routes OSRM réelles si disponibles)
                    if (_transitRoutes != null)
                      for (final entry in _transitRoutes!.entries)
                        if (entry.value.geometry.length >= 2)
                          Polyline(
                            points: entry.value.geometry,
                            strokeWidth: 3.5,
                            color: ambiance.isNight
                                ? VoyagoColors.primary.withValues(alpha: 0.8)
                                : VoyagoColors.primary.withValues(alpha: 0.7),
                            pattern: const StrokePattern.dotted(),
                          ),

                    // Fallback: ligne simple entre POIs si pas encore de routes calculées
                    if (_transitRoutes == null && dayPois.length >= 2)
                      Polyline(
                        points: dayPois
                            .map((p) => LatLng(p.lat, p.lng))
                            .toList(),
                        strokeWidth: 3.5,
                        color: ambiance.isNight
                            ? VoyagoColors.primary.withValues(alpha: 0.9)
                            : VoyagoColors.primary,
                        pattern: const StrokePattern.dotted(),
                      ),

                    // === POLYLINE DE NAVIGATION : User → POI cible (bleu vif, route réelle) ===
                    if (_navigationRoute != null && _navigationRoute!.geometry.length >= 2)
                      Polyline(
                        points: _navigationRoute!.geometry,
                        strokeWidth: 4.5,
                        color: const Color(0xFF2196F3),
                        borderStrokeWidth: 1.5,
                        borderColor: const Color(0xFF1565C0),
                      ),
                  ],
                ),

                // POI pins on map
                MarkerLayer(
                  markers: dayPois.asMap().entries.map((entry) {
                    final i = entry.key;
                    final poi = entry.value;
                    return Marker(
                      point: LatLng(poi.lat, poi.lng),
                      width: _activePoiIndex == i ? 180 : 46,
                      height: _activePoiIndex == i ? 80 : 46,
                      child: MapPoiPin(
                        poi: poi,
                        index: i,
                        isActive: _activePoiIndex == i,
                        onTap: () {
                          setState(() {
                            _activePoiIndex =
                                _activePoiIndex == i ? null : i;
                          });
                          _animatedMapController.animateTo(
                            dest: LatLng(poi.lat, poi.lng),
                            zoom: 15,
                          );
                        },
                      ),
                    );
                  }).toList(),
                ),

                // === POSITION GPS EN TEMPS RÉEL DE L'UTILISATEUR ===
                CurrentLocationLayer(
                  alignPositionOnUpdate: AlignOnUpdate.never,
                  alignDirectionOnUpdate: AlignOnUpdate.never,
                  style: LocationMarkerStyle(
                    marker: const DefaultLocationMarker(
                      color: VoyagoColors.primary,
                      child: Icon(Icons.navigation_rounded, color: Colors.white, size: 14),
                    ),
                    markerSize: const Size.square(32),
                    accuracyCircleColor: VoyagoColors.primary.withValues(alpha: 0.12),
                    headingSectorColor: VoyagoColors.primary.withValues(alpha: 0.5),
                    headingSectorRadius: 60,
                  ),
                ),
              ],
            ),
          ),

          // === CALQUE ATMOSPHÉRIQUE D'AMBIANCE (COMME HELLOBARBER, 100% IGNOREPOINTER) ===
          Positioned.fill(
            child: MapAmbianceOverlay(
              ambiance: ambiance,
              weather: activeWeather,
              topInset: MediaQuery.of(context).padding.top,
              forceDay: _forceDayMap,
            ),
          ),

          // === 2. TOP FLOATING SEARCH & MENU BAR ===
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 8,
                left: 12,
                right: 12,
                bottom: 8,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    VoyagoColors.background.withValues(alpha: 0.95),
                    VoyagoColors.background.withValues(alpha: 0.0),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      // 3-bars hamburger menu button (menu en 3 traits en haut à gauche)
                      _MapButton(
                        icon: Icons.menu,
                        onTap: () {
                          _scaffoldKey.currentState?.openDrawer();
                        },
                      ),
                      const SizedBox(width: 8),

                      // Floating Search Bar (from HTML template)
                      Expanded(
                        child: Container(
                          height: 44,
                          decoration: BoxDecoration(
                            color: VoyagoColors.surface.withValues(alpha: 0.95),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: VoyagoColors.cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 10,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: Row(
                            children: [
                              const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 10),
                                child: Icon(
                                  Icons.search,
                                  color: VoyagoColors.muted,
                                  size: 20,
                                ),
                              ),
                              Expanded(
                                child: TextField(
                                  controller: _searchCtrl,
                                  focusNode: _searchFocus,
                                  onChanged: _onSearchChanged,
                                  onSubmitted: (q) async {
                                    if (_searchResults.isNotEmpty) {
                                      _selectCity(_searchResults.first);
                                    } else if (q.trim().isNotEmpty) {
                                      final list = await LiveWeatherService.instance.searchCities(q);
                                      if (list.isNotEmpty) _selectCity(list.first);
                                    }
                                  },
                                  style: const TextStyle(
                                    color: VoyagoColors.text,
                                    fontSize: 13,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: _activeCityName.isNotEmpty
                                        ? 'Rechercher lieu à $_activeCityName...'
                                        : 'Rechercher une ville, lieu...',
                                    hintStyle: TextStyle(
                                      color: VoyagoColors.muted.withValues(alpha: 0.7),
                                      fontSize: 13,
                                    ),
                                    border: InputBorder.none,
                                    isDense: true,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                                  ),
                                ),
                              ),
                              if (_isSearching)
                                const Padding(
                                  padding: EdgeInsets.symmetric(horizontal: 10),
                                  child: SizedBox(
                                    width: 14,
                                    height: 14,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: VoyagoColors.primary,
                                    ),
                                  ),
                                )
                              else if (_searchCtrl.text.isNotEmpty)
                                GestureDetector(
                                  onTap: () {
                                    _searchCtrl.clear();
                                    setState(() {
                                      _searchResults = [];
                                      _isSearching = false;
                                    });
                                  },
                                  child: const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 8),
                                    child: Icon(Icons.close, color: VoyagoColors.muted, size: 18),
                                  ),
                                )
                              else
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8),
                                  child: Icon(
                                    Icons.tune,
                                    color: VoyagoColors.primary.withValues(alpha: 0.8),
                                    size: 18,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // User profile button / avatar
                      GestureDetector(
                        onTap: () => context.go('/profile'),
                        child: Container(
                          width: 40,
                          height: 40,
                          decoration: BoxDecoration(
                            color: VoyagoColors.surface.withValues(alpha: 0.95),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: VoyagoColors.primary.withValues(alpha: 0.6),
                              width: 1.5,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.25),
                                blurRadius: 8,
                              ),
                            ],
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            user?.avatarDisplay ?? '👤',
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Search Suggestions Dropdown
                  if (_searchResults.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: VoyagoColors.surface,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: VoyagoColors.cardBorder),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: _searchResults.take(4).map((city) {
                          return ListTile(
                            dense: true,
                            leading: const Icon(
                              Icons.location_city,
                              color: VoyagoColors.primary,
                              size: 18,
                            ),
                            title: Text(
                              city.displayName,
                              style: const TextStyle(
                                color: VoyagoColors.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            trailing: const Icon(
                              Icons.arrow_forward_ios,
                              color: VoyagoColors.muted,
                              size: 12,
                            ),
                            onTap: () => _selectCity(city),
                          );
                        }).toList(),
                      ),
                    ),
                ],
              ),
            ),
          ),

          // === 3. DYNAMIC WEATHER OVERLAY (TRANSPARENT, SANS FOND OPAQUE, MINIFIABLE) ===
          // Masquée tant qu'une fiche de lieu est ouverte (même emplacement)
          if (activeWeather != null && _showWeatherCard && _activePoiIndex == null)
            Positioned(
              top: MediaQuery.of(context).padding.top + 68,
              left: 0,
              right: 0,
              child: WeatherOverlay(
                weather: activeWeather,
                cityName: _activeCityName,
                dayNumber: _selectedDay,
                ambianceLabel: ambiance.phaseLabel,
                ambianceIcon: ambiance.phaseIcon,
                isMinimized: _isWeatherMinimized,
                onToggleMinimize: () {
                  setState(() => _isWeatherMinimized = !_isWeatherMinimized);
                },
                aiTip: getWeatherAiTip(
                  activeWeather,
                  ref.watch(currentUserProvider)?.thermalSensitivity,
                ),
              ),
            ),

          // === 3 bis. FICHE DU LIEU TOUCHÉ SUR LA CARTE (photo, infos, résumé) ===
          Positioned(
            top: MediaQuery.of(context).padding.top + 68,
            left: 0,
            right: 0,
            child: AnimatedSwitcher(
              duration: const Duration(milliseconds: 420),
              reverseDuration: const Duration(milliseconds: 200),
              transitionBuilder: poiSpotlightTransition,
              child: _activePoiIndex != null && _activePoiIndex! < dayPois.length
                  ? PoiSpotlightCard(
                      key: ValueKey('spotlight-${dayPois[_activePoiIndex!].name}'),
                      poi: dayPois[_activePoiIndex!],
                      index: _activePoiIndex!,
                      routeFromMe: _poiDistances?[_activePoiIndex!],
                      onClose: () => setState(() => _activePoiIndex = null),
                      onNavigate: () => _navigateToPoi(dayPois[_activePoiIndex!]),
                    )
                  : const SizedBox.shrink(key: ValueKey('spotlight-none')),
            ),
          ),

          // === 4. MAP CONTROLS (Right Side) ===
          Positioned(
            right: 16,
            bottom: MediaQuery.of(context).size.height * 0.46 + 12,
            child: Column(
              children: [
                // Bascule Style Carte : Plein Jour forcé ou Ambiance Réelle Dynamique (comme hellobarber)
                _MapButton(
                  icon: _forceDayMap ? Icons.wb_sunny_rounded : ambiance.phaseIcon,
                  onTap: () {
                    setState(() => _forceDayMap = !_forceDayMap);
                    _showSafeSnackBar(
                      SnackBar(
                        content: Text(
                          _forceDayMap
                              ? '☀️ Mode Plein Jour forcé'
                              : '✨ Ambiance solaire dynamique rétablie (${ambiance.phaseLabel})',
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        duration: const Duration(seconds: 2),
                        behavior: SnackBarBehavior.floating,
                      ),
                    );
                  },
                ),
                const SizedBox(height: 8),
                _MapButton(
                  icon: Icons.my_location,
                  onTap: () async {
                    setState(() => _forceDayMap = false); // Rétablit l'ambiance réelle de la position utilisateur
                    if (_liveUserPosition != null) {
                      _lastWeatherFetchCenter = _liveUserPosition;
                      _animatedMapController.animateTo(
                        dest: _liveUserPosition!,
                        zoom: 16.0,
                      );
                      _updateWeatherForPosition(
                        _liveUserPosition!.latitude,
                        _liveUserPosition!.longitude,
                        autoUpdateCity: true,
                      );
                      _showSafeSnackBar(
                        const SnackBar(
                          content: Row(
                            children: [
                              Icon(Icons.gps_fixed, color: VoyagoColors.primary, size: 18),
                              SizedBox(width: 8),
                              Text('Centré sur votre position GPS en temps réel'),
                            ],
                          ),
                          duration: Duration(seconds: 2),
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    } else {
                      // Demande et acquisition en direct de la position GPS
                      await _initLiveLocationAndWeather(centerOnUser: true);
                    }
                  },
                ),
                const SizedBox(height: 8),
                Container(
                  decoration: BoxDecoration(
                    color: VoyagoColors.surface.withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: VoyagoColors.cardBorder),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.25),
                        blurRadius: 8,
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      _MapButton(
                        icon: Icons.add,
                        onTap: () {
                          final zoom = _animatedMapController.mapController.camera.zoom;
                          _animatedMapController.animateTo(
                            dest: _animatedMapController.mapController.camera.center,
                            zoom: (zoom + 1).clamp(3, 18).toDouble(),
                          );
                        },
                        noBg: true,
                      ),
                      Container(
                        width: 28,
                        height: 1,
                        color: VoyagoColors.cardBorder,
                      ),
                      _MapButton(
                        icon: Icons.remove,
                        onTap: () {
                          final zoom = _animatedMapController.mapController.camera.zoom;
                          _animatedMapController.animateTo(
                            dest: _animatedMapController.mapController.camera.center,
                            zoom: (zoom - 1).clamp(3, 18).toDouble(),
                          );
                        },
                        noBg: true,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // === 5. ITINERARY BOTTOM SHEET ===
          ItineraryBottomSheet(
            pois: dayPois,
            selectedDay: _selectedDay,
            totalDays: trip.durationDays,
            destination: _activeCityName.isNotEmpty ? _activeCityName : trip.destination,
            userPosition: _liveUserPosition,
            poiDistances: _poiDistances,
            transitRoutes: _transitRoutes,
            transports: trip.transports,
            tripId: trip.id,
            onNavigateToPoi: _navigateToPoi,
            onDayChanged: (day) {
              setState(() {
                _selectedDay = day;
                _activePoiIndex = null;
                _navigationRoute = null;
                _navigationTargetIndex = null;
                _poiDistances = null;
                _transitRoutes = null;
              });
              final newPois = trip.poisForDay(day);
              if (newPois.isNotEmpty) {
                final target = LatLng(newPois.first.lat, newPois.first.lng);
                setState(() => _currentCenter = target);
                _animatedMapController.animateTo(dest: target, zoom: 13.5);
              }
              // Recalculer les distances pour le nouveau jour
              _computeRoutesForCurrentDay();
            },
            onPoiTap: (poi) {
              final idx = dayPois.indexOf(poi);
              setState(() => _activePoiIndex = idx >= 0 ? idx : null);
              _animatedMapController.animateTo(dest: LatLng(poi.lat, poi.lng), zoom: 15);
            },
          ),
        ],
      ),
    );
  }

  Trip _createDemoTrip() {
    return Trip(
      id: 'demo-paris',
      userId: 'guest',
      destination: 'Paris',
      durationDays: 3,
      pace: 'modéré',
      budget: 'moyen',
      transports: ['marche', 'métro'],
      interests: ['gastronomie', 'culture', 'art'],
      pois: [
        const POI(
          name: 'Café de Flore',
          description: 'Café littéraire historique de Saint-Germain-des-Prés.',
          category: 'gastronomie',
          imageQuery: 'Cafe de Flore',
          lat: 48.8541,
          lng: 2.3328,
          day: 1,
          order: 1,
          durationMinutes: 45,
          rating: 4.8,
          reviewsCount: 2400,
          insiderTip: 'Dégustez leur fameux chocolat chaud à l\'ancienne.',
          imageUrl:
              'https://images.unsplash.com/photo-1550966871-3ed3cdb5ed0c?w=600&auto=format&fit=crop&q=80',
        ),
        const POI(
          name: 'Musée du Louvre',
          description: 'Le plus grand musée d\'art et d\'antiquités du monde.',
          category: 'culture',
          imageQuery: 'Louvre Museum',
          lat: 48.8606,
          lng: 2.3376,
          day: 1,
          order: 2,
          durationMinutes: 120,
          rating: 4.9,
          reviewsCount: 12400,
          insiderTip: 'Entrez par le Carrousel du Louvre pour éviter la file principale.',
          imageUrl:
              'https://images.unsplash.com/photo-1499856871958-5b9627545d1a?w=600&auto=format&fit=crop&q=80',
        ),
        const POI(
          name: 'Jardin des Tuileries',
          description: 'Flânerie royale au cœur de la capitale.',
          category: 'nature',
          imageQuery: 'Tuileries Garden',
          lat: 48.8634,
          lng: 2.3275,
          day: 1,
          order: 3,
          durationMinutes: 60,
          rating: 4.7,
          reviewsCount: 5600,
          insiderTip: 'Profitez des chaises vertes au bord du grand bassin octogonal.',
          imageUrl:
              'https://images.unsplash.com/photo-1502602898657-3e91760cbb34?w=600&auto=format&fit=crop&q=80',
        ),
      ],
      weather: [
        const DayWeather(
          date: 'Jour 1',
          icon: '⛅',
          summary: 'Partiellement nuageux',
          weatherCode: 1,
          tempMax: 18.0,
          tempMin: 12.0,
        ),
        const DayWeather(
          date: 'Jour 2',
          icon: '☀️',
          summary: 'Ensoleillé',
          weatherCode: 0,
          tempMax: 21.0,
          tempMin: 14.0,
        ),
        const DayWeather(
          date: 'Jour 3',
          icon: '🌦️',
          summary: 'Averses éparses',
          weatherCode: 61,
          tempMax: 17.0,
          tempMin: 13.0,
        ),
      ],
      likes: 42,
      isPublic: false,
      createdAt: DateTime.now(),
    );
  }
}

/// Circular floating map button
class _MapButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final bool noBg;

  const _MapButton({
    required this.icon,
    required this.onTap,
    this.noBg = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: noBg
            ? null
            : BoxDecoration(
                color: VoyagoColors.surface.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VoyagoColors.cardBorder),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.25),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
        alignment: Alignment.center,
        child: Icon(icon, color: VoyagoColors.text, size: 20),
      ),
    );
  }
}

/// Option de navigation dans le bottom sheet de choix d'app.
class _NavOption extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final VoidCallback onTap;

  const _NavOption({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: VoyagoColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: VoyagoColors.cardBorder),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: VoyagoColors.primary.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: VoyagoColors.primary, size: 20),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      color: VoyagoColors.text,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: VoyagoColors.muted.withValues(alpha: 0.7),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.arrow_forward_ios_rounded,
              color: VoyagoColors.muted.withValues(alpha: 0.5),
              size: 14,
            ),
          ],
        ),
      ),
    );
  }
}
