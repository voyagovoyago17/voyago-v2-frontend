import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_earth_globe/flutter_earth_globe.dart';
import 'package:flutter_earth_globe/flutter_earth_globe_controller.dart';
import 'package:flutter_earth_globe/globe_coordinates.dart';
import 'package:flutter_earth_globe/point.dart';
import '../../api/api_exceptions.dart';
import '../../models/tribe.dart';
import '../../theme.dart';

/// Lancement immersif d'un voyage de tribu : le globe tourne pendant que les lieux se
/// préparent, puis pivote et zoome sur la destination. Renvoie le voyage créé quand
/// l'utilisateur appuie sur « Voter maintenant », ou null s'il ferme (ou en cas d'erreur).
Future<TribeTripPlan?> showTribeLaunchGlobe(
  BuildContext context, {
  required Future<TribeTripPlan> planFuture,
  required String placeLabel,
  String flag = '🌍',
  (double, double)? approxCoordinates,
}) {
  return showGeneralDialog<TribeTripPlan>(
    context: context,
    barrierDismissible: false,
    barrierLabel: 'Voyage de tribu',
    barrierColor: Colors.black,
    transitionDuration: const Duration(milliseconds: 450),
    pageBuilder: (_, __, ___) => _TribeLaunchGlobe(
      planFuture: planFuture,
      placeLabel: placeLabel,
      flag: flag,
      approxCoordinates: approxCoordinates,
    ),
    transitionBuilder: (_, animation, __, child) {
      final curved = CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(scale: Tween(begin: 1.08, end: 1.0).animate(curved), child: child),
      );
    },
  );
}

class _TribeLaunchGlobe extends StatefulWidget {
  final Future<TribeTripPlan> planFuture;
  final String placeLabel;
  final String flag;
  final (double, double)? approxCoordinates;

  const _TribeLaunchGlobe({
    required this.planFuture,
    required this.placeLabel,
    required this.flag,
    this.approxCoordinates,
  });

  @override
  State<_TribeLaunchGlobe> createState() => _TribeLaunchGlobeState();
}

class _TribeLaunchGlobeState extends State<_TribeLaunchGlobe> with TickerProviderStateMixin {
  late final FlutterEarthGlobeController _globe;
  late final AnimationController _zoom;
  late final AnimationController _reveal;
  bool _globeLoaded = false;
  TribeTripPlan? _plan;
  String? _error;
  int _messageIndex = 0;
  Timer? _messageTimer;

  static const _loadingMessages = [
    'Exploration des quartiers…',
    'Repérage des pépites secrètes…',
    'Sélection des adresses gourmandes…',
    'Préparation du vote de la tribu…',
  ];

  @override
  void initState() {
    super.initState();
    _globe = FlutterEarthGlobeController(
      rotationSpeed: 0.12,
      isRotating: true,
      isZoomEnabled: false,
      zoom: -0.2,
      surface: const AssetImage('assets/globe/2k_earth-day.jpg'),
      nightSurface: const AssetImage('assets/globe/2k_earth-night.jpg'),
      // Pas d'atmosphère : globe net, sans halo coloré autour
      showAtmosphere: false,
      surfaceLightingEnabled: true,
      lightIntensity: 0.9,
      ambientLight: 0.6,
    );
    _zoom = AnimationController(vsync: this, duration: const Duration(milliseconds: 1600))
      ..addListener(() => _globe.setZoom(-0.2 + 1.0 * Curves.easeInOutCubic.transform(_zoom.value)));
    _reveal = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));

    _globe.onLoaded = () {
      if (!mounted) return;
      _globeLoaded = true;
      final approx = widget.approxCoordinates;
      if (_plan != null) {
        _focusOnPlan();
      } else if (approx != null) {
        // La ville est connue : on la pointe déjà pendant que les lieux se préparent
        _addMarker(approx.$1, approx.$2);
      }
    };

    _messageTimer = Timer.periodic(const Duration(milliseconds: 2400), (_) {
      if (mounted && _plan == null && _error == null) {
        setState(() => _messageIndex = (_messageIndex + 1) % _loadingMessages.length);
      }
    });

    widget.planFuture.then((plan) {
      if (!mounted) return;
      setState(() => _plan = plan);
      _messageTimer?.cancel();
      if (_globeLoaded) _focusOnPlan();
    }).catchError((Object e) {
      if (!mounted) return;
      _messageTimer?.cancel();
      setState(() => _error = e is ApiException ? e.message : 'Impossible de préparer ce voyage, réessaie.');
    });
  }

  @override
  void dispose() {
    _messageTimer?.cancel();
    _zoom.dispose();
    _reveal.dispose();
    try {
      _globe.dispose();
    } catch (_) {}
    super.dispose();
  }

  void _addMarker(double lat, double lng) {
    _globe.removePoint('destination');
    _globe.addPoint(
      Point(
        id: 'destination',
        coordinates: GlobeCoordinates(lat, lng),
        style: const PointStyle(color: VoyagoColors.yellow, size: 7),
        label: widget.placeLabel,
        isLabelVisible: true,
        labelOffset: const Offset(10, -6),
        labelTextStyle: const TextStyle(
          color: Colors.white,
          fontSize: 13,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black87, blurRadius: 6)],
        ),
      ),
    );
  }

  /// Centre des lieux proposés (plus précis que la ville), sinon la ville choisie.
  (double, double)? _planCenter() {
    final coords = _plan?.candidates.map((c) => c.poi).where((p) => p.lat != 0 && p.lng != 0).toList() ?? [];
    if (coords.isEmpty) return widget.approxCoordinates;
    final lat = coords.map((p) => p.lat).reduce((a, b) => a + b) / coords.length;
    final lng = coords.map((p) => p.lng).reduce((a, b) => a + b) / coords.length;
    return (lat, lng);
  }

  void _focusOnPlan() {
    final center = _planCenter();
    _globe.stopRotation();
    if (center != null) {
      _addMarker(center.$1, center.$2);
      _globe.focusOnCoordinates(
        GlobeCoordinates(center.$1, center.$2),
        animate: true,
        duration: const Duration(milliseconds: 1600),
        curve: Curves.easeInOutCubic,
      );
      _zoom.forward();
    }
    Future.delayed(const Duration(milliseconds: 900), () {
      if (mounted) _reveal.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final globeSize = size.width * 1.05;

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0, -0.25),
            radius: 1.1,
            colors: [Color(0xFF16213A), Color(0xFF0A0D16), Colors.black],
            stops: [0, 0.55, 1],
          ),
        ),
        child: SafeArea(
          child: Stack(
            children: [
              // Globe plein écran
              Align(
                alignment: const Alignment(0, -0.35),
                child: SizedBox(
                  width: globeSize,
                  height: globeSize,
                  child: IgnorePointer(
                    child: MediaQuery(
                      data: MediaQuery.of(context).copyWith(size: Size(globeSize, globeSize)),
                      child: FlutterEarthGlobe(controller: _globe, radius: globeSize * 0.36),
                    ),
                  ),
                ),
              ),
              // Fermer
              Positioned(
                top: 8,
                right: 8,
                child: IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: Colors.white70),
                ),
              ),
              // Titre
              Positioned(
                top: 24,
                left: 24,
                right: 64,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'VOYAGE DE TRIBU',
                      style: TextStyle(color: Colors.white54, fontSize: 12, letterSpacing: 2, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${widget.flag}  ${widget.placeLabel}',
                      style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
              // Bas : progression, erreur ou carte de résultat
              Positioned(
                left: 20,
                right: 20,
                bottom: 24,
                child: _error != null
                    ? _buildError()
                    : _plan == null
                        ? _buildLoading()
                        : FadeTransition(
                            opacity: _reveal,
                            child: SlideTransition(
                              position: Tween(begin: const Offset(0, 0.25), end: Offset.zero)
                                  .animate(CurvedAnimation(parent: _reveal, curve: Curves.easeOutCubic)),
                              child: _buildResult(_plan!),
                            ),
                          ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(
          width: 26,
          height: 26,
          child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
        ),
        const SizedBox(height: 14),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 400),
          child: Text(
            _loadingMessages[_messageIndex],
            key: ValueKey(_messageIndex),
            style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w600),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Cela peut prendre jusqu\'à une minute',
          style: TextStyle(color: Colors.white54, fontSize: 12),
        ),
      ],
    );
  }

  Widget _buildError() {
    return _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.error_outline_rounded, color: VoyagoColors.coral, size: 32),
          const SizedBox(height: 10),
          Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.white, height: 1.35)),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: OutlinedButton.styleFrom(
                foregroundColor: Colors.white,
                side: const BorderSide(color: Colors.white24),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Fermer'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResult(TribeTripPlan plan) {
    final days = plan.durationDays;
    return _Panel(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            plan.aiGenerated ? '✨ Nouvel itinéraire prêt' : '🔁 Parcours déjà connu, prêt instantanément',
            style: const TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Text(
            plan.destination,
            style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Text(
            '${plan.candidates.length} lieux à départager • $days jour${days > 1 ? 's' : ''}',
            style: const TextStyle(color: Colors.white70, fontSize: 14),
          ),
          const SizedBox(height: 4),
          const Text(
            'Swipe pour voter, ta tribu fera de même : les favoris formeront l\'itinéraire.',
            style: TextStyle(color: Colors.white54, fontSize: 12, height: 1.35),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => Navigator.of(context).pop(plan),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: const Color(0xFF0A0D16),
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: const Text('Voter maintenant 🗳️', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panneau sombre translucide, sans lueur ni bordure colorée.
class _Panel extends StatelessWidget {
  final Widget child;

  const _Panel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xCC111624),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }
}
