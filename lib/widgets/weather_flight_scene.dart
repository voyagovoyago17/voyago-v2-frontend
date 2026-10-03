import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';

/// Scène d'attente de la création d'un voyage : le perroquet Voyagooo vole
/// à travers le soleil, les nuages, la pluie et la neige — rien ne l'arrête.
///
/// Performance : un seul AnimationController, le ciel est peint par un CustomPainter
/// branché directement sur l'animation (aucune reconstruction de widget par image),
/// particules calculées sans allocation, le tout isolé dans un RepaintBoundary.
class WeatherFlightScene extends StatefulWidget {
  final double size;

  const WeatherFlightScene({super.key, required this.size});

  @override
  State<WeatherFlightScene> createState() => _WeatherFlightSceneState();
}

/// Durée d'un cycle météo complet (soleil → nuages → pluie → neige)
const double _cycleSeconds = 16;
const double _loopSeconds = 96; // multiple du cycle : bouclage invisible

enum _Weather { sun, clouds, rain, snow }

const _weatherLabels = {
  _Weather.sun: '☀️  Grand soleil',
  _Weather.clouds: '☁️  À travers les nuages',
  _Weather.rain: '🌧️  Même sous la pluie',
  _Weather.snow: '❄️  Même sous la neige',
};

/// Poids de chaque météo à l'instant [t] (somme = 1), avec fondu entre deux phases.
List<double> _weatherWeights(double t) {
  final phaseLength = _cycleSeconds / _Weather.values.length;
  final local = (t % _cycleSeconds) / phaseLength;
  final index = local.floor() % _Weather.values.length;
  final frac = local - local.floor();
  final weights = List<double>.filled(_Weather.values.length, 0);
  const fadeStart = 0.7;
  if (frac <= fadeStart) {
    weights[index] = 1;
  } else {
    final k = Curves.easeInOut.transform((frac - fadeStart) / (1 - fadeStart));
    weights[index] = 1 - k;
    weights[(index + 1) % weights.length] = k;
  }
  return weights;
}

class _WeatherFlightSceneState extends State<WeatherFlightScene> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  final ValueNotifier<_Weather> _weather = ValueNotifier(_Weather.sun);

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: Duration(milliseconds: (_loopSeconds * 1000).round()),
    )
      ..addListener(_syncWeatherLabel)
      ..repeat();
  }

  double get _time => _controller.value * _loopSeconds;

  void _syncWeatherLabel() {
    final w = _weatherWeights(_time);
    var best = 0;
    for (var i = 1; i < w.length; i++) {
      if (w[i] > w[best]) best = i;
    }
    final current = _Weather.values[best];
    if (_weather.value != current) _weather.value = current;
  }

  @override
  void dispose() {
    _controller.dispose();
    _weather.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final parrotSize = size * 0.42;

    return RepaintBoundary(
      child: SizedBox(
        width: size,
        height: size,
        child: Stack(
          clipBehavior: Clip.hardEdge,
          children: [
            Positioned.fill(child: CustomPaint(painter: _SkyPainter(_controller))),
            // Le perroquet en vol (léger roulis, montées et descentes, battements d'ailes)
            AnimatedBuilder(
              animation: _controller,
              builder: (context, child) {
                final t = _time;
                final dx = math.sin(t * 2 * math.pi / 6) * size * 0.11;
                final dy = math.sin(t * 2 * math.pi / 1.7) * size * 0.035 + math.sin(t * 2 * math.pi / 4.8) * size * 0.04;
                final tilt = -0.12 + math.cos(t * 2 * math.pi / 1.7) * 0.05;
                return Positioned(
                  left: (size - parrotSize) / 2 + dx,
                  top: (size - parrotSize) / 2 - size * 0.04 + dy,
                  width: parrotSize,
                  height: parrotSize,
                  child: Transform.rotate(angle: tilt, child: child),
                );
              },
              child: _FlyingParrot(size: parrotSize, animation: _controller),
            ),
            // Étiquette météo
            Positioned(
              left: 0,
              right: 0,
              bottom: size * 0.05,
              child: Center(
                child: ValueListenableBuilder<_Weather>(
                  valueListenable: _weather,
                  builder: (context, weather, _) => AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    transitionBuilder: (child, animation) => FadeTransition(
                      opacity: animation,
                      child: ScaleTransition(scale: Tween(begin: 0.9, end: 1.0).animate(animation), child: child),
                    ),
                    child: Container(
                      key: ValueKey(weather),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.35),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _weatherLabels[weather]!,
                        style: const TextStyle(color: Colors.white, fontSize: 11.5, fontWeight: FontWeight.w700),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Logo Voyagooo + aile qui bat derrière le corps.
class _FlyingParrot extends StatelessWidget {
  final double size;
  final Animation<double> animation;

  const _FlyingParrot({required this.size, required this.animation});

  // Le perroquet occupe la zone (244,106)-(414,300) d'une image 628×397 : on le recadre.
  static const double _imageWidth = 628;
  static const double _imageHeight = 397;
  static const double _parrotBox = 200;
  static const Offset _parrotCenterOffset = Offset(15, 4.5);

  @override
  Widget build(BuildContext context) {
    final scale = size / _parrotBox;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned.fill(child: CustomPaint(painter: _WingPainter(animation))),
        Positioned.fill(
          child: ClipRect(
            child: OverflowBox(
              maxWidth: _imageWidth * scale,
              maxHeight: _imageHeight * scale,
              child: Transform.translate(
                offset: -_parrotCenterOffset * scale,
                child: Image.asset(
                  'assets/logo/voyago_parrot.png',
                  width: _imageWidth * scale,
                  height: _imageHeight * scale,
                  filterQuality: FilterQuality.medium,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WingPainter extends CustomPainter {
  final Animation<double> animation;

  _WingPainter(this.animation) : super(repaint: animation);

  final Paint _back = Paint()..color = const Color(0xFF1E9E4A);
  final Paint _front = Paint()..color = const Color(0xFFA9CC22);

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value * _loopSeconds;
    final flap = math.sin(t * 2 * math.pi * 3.2);
    // Épaule sur le dos du perroquet (il regarde vers la gauche)
    final shoulder = Offset(size.width * 0.56, size.height * 0.46);
    final wingLength = size.width * 0.42;

    canvas.save();
    canvas.translate(shoulder.dx, shoulder.dy);
    canvas.rotate(-0.55 + flap * 0.65);
    final wing = Path()
      ..moveTo(0, 0)
      ..quadraticBezierTo(wingLength * 0.35, -wingLength * 0.42, wingLength, -wingLength * 0.28)
      ..quadraticBezierTo(wingLength * 0.62, -wingLength * 0.02, wingLength * 0.85, wingLength * 0.1)
      ..quadraticBezierTo(wingLength * 0.4, wingLength * 0.2, 0, wingLength * 0.12)
      ..close();
    canvas.drawPath(wing, _back);
    canvas.scale(0.78);
    canvas.drawPath(wing, _front);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _WingPainter oldDelegate) => false;
}

class _Cloud {
  final double x0, y, scale, speed;
  const _Cloud(this.x0, this.y, this.scale, this.speed);
}

/// Ciel, soleil, nuages, collines, pluie, éclairs et neige — peints en une passe.
class _SkyPainter extends CustomPainter {
  final Animation<double> animation;

  _SkyPainter(this.animation) : super(repaint: animation);

  static const _skyTop = [Color(0xFF1B4F7A), Color(0xFF2A3F55), Color(0xFF151F2B), Color(0xFF3A4B63)];
  static const _skyBottom = [Color(0xFF4A9CBF), Color(0xFF51697F), Color(0xFF2B394A), Color(0xFF8396AD)];
  static const _cloudColors = [Color(0xF2FFFFFF), Color(0xFFE6ECF2), Color(0xFF5E6C7D), Color(0xFFCBD5E1)];
  // Nombre de nuages visibles selon la météo
  static const _cloudCounts = [2, 6, 6, 5];

  static const _clouds = [
    _Cloud(0.05, 0.16, 0.85, 0.035),
    _Cloud(0.62, 0.08, 0.65, 0.028),
    _Cloud(0.35, 0.30, 1.0, 0.045),
    _Cloud(0.85, 0.24, 0.75, 0.04),
    _Cloud(0.20, 0.06, 0.6, 0.03),
    _Cloud(0.55, 0.38, 0.9, 0.05),
  ];

  static final _rain = _seeded(90, 1);
  static final _snow = _seeded(70, 2);
  static final Float32List _snowSmall = Float32List(140);
  static final Float32List _snowLarge = Float32List(140);

  /// Positions de départ pseudo-aléatoires mais fixes (x, y, vitesse) dans [0,1]
  static List<double> _seeded(int count, int seed) {
    final r = math.Random(seed);
    return List.generate(count * 3, (_) => r.nextDouble());
  }

  final Paint _paint = Paint()..isAntiAlias = true;
  final Paint _rainPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  final Paint _snowPaint = Paint()..strokeCap = StrokeCap.round;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value * _loopSeconds;
    final w = _weatherWeights(t);
    final rect = Offset.zero & size;

    // Ciel
    _paint
      ..shader = ui.Gradient.linear(rect.topCenter, rect.bottomCenter, [_mix(_skyTop, w), _mix(_skyBottom, w)])
      ..color = Colors.white;
    canvas.drawRect(rect, _paint);
    _paint.shader = null;

    _paintSun(canvas, size, t, w[0] + w[1] * 0.3);
    _paintClouds(canvas, size, t, w, back: true);
    _paintHills(canvas, size, t, w[3]);
    _paintClouds(canvas, size, t, w, back: false);
    if (w[2] > 0.01) _paintRain(canvas, size, t, w[2]);
    if (w[3] > 0.01) _paintSnow(canvas, size, t, w[3]);

    // Éclairs pendant l'orage
    final local = t % _cycleSeconds;
    if (w[2] > 0.5 && ((local > 9.0 && local < 9.12) || (local > 9.3 && local < 9.38))) {
      _paint.color = Colors.white.withValues(alpha: 0.22 * w[2]);
      canvas.drawRect(rect, _paint);
    }
  }

  void _paintSun(Canvas canvas, Size size, double t, double strength) {
    if (strength < 0.01) return;
    final center = Offset(size.width * 0.8, size.height * 0.2);
    final radius = size.width * 0.085;

    _paint
      ..shader = ui.Gradient.radial(center, radius * 3.2, [
        const Color(0xFFFFD166).withValues(alpha: 0.55 * strength),
        const Color(0xFFFFD166).withValues(alpha: 0),
      ])
      ..color = Colors.white;
    canvas.drawCircle(center, radius * 3.2, _paint);
    _paint.shader = null;

    // Rayons qui tournent lentement
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(t * 0.35);
    _paint.color = const Color(0xFFFFE08A).withValues(alpha: 0.75 * strength);
    for (var i = 0; i < 10; i++) {
      canvas.rotate(math.pi / 5);
      canvas.drawRRect(
        RRect.fromRectAndRadius(Rect.fromLTWH(radius * 1.3, -radius * 0.09, radius * 0.55, radius * 0.18), Radius.circular(radius)),
        _paint,
      );
    }
    canvas.restore();

    _paint.color = const Color(0xFFFFC94A).withValues(alpha: strength);
    canvas.drawCircle(center, radius, _paint);
  }

  void _paintClouds(Canvas canvas, Size size, double t, List<double> w, {required bool back}) {
    final color = _mix(_cloudColors, w);
    for (var i = 0; i < _clouds.length; i++) {
      // Nuages du fond : indices pairs ; premier plan : impairs
      if ((i.isEven) != back) continue;
      var alpha = 0.0;
      for (var p = 0; p < w.length; p++) {
        if (i < _cloudCounts[p]) alpha += w[p];
      }
      if (alpha < 0.01) continue;
      final c = _clouds[i];
      // Le perroquet vole vers la gauche : le décor défile vers la droite
      final x = ((c.x0 + t * c.speed) % 1.5) - 0.3;
      final cloudWidth = size.width * 0.34 * c.scale;
      _paint.color = color.withValues(alpha: color.a * alpha * (back ? 0.75 : 0.95));
      canvas.drawPath(_cloudPath(Offset(x * size.width, c.y * size.height), cloudWidth), _paint);
    }
  }

  /// Nuage = union de cercles (une seule forme : pas de superposition de transparence)
  Path _cloudPath(Offset origin, double width) {
    final h = width * 0.42;
    return Path()
      ..addOval(Rect.fromLTWH(origin.dx, origin.dy + h * 0.35, width * 0.45, h * 0.65))
      ..addOval(Rect.fromLTWH(origin.dx + width * 0.18, origin.dy, width * 0.45, h * 0.95))
      ..addOval(Rect.fromLTWH(origin.dx + width * 0.45, origin.dy + h * 0.2, width * 0.4, h * 0.75))
      ..addOval(Rect.fromLTWH(origin.dx + width * 0.62, origin.dy + h * 0.42, width * 0.38, h * 0.58))
      ..addRRect(RRect.fromRectAndRadius(
        Rect.fromLTWH(origin.dx + width * 0.1, origin.dy + h * 0.55, width * 0.8, h * 0.45),
        Radius.circular(h * 0.3),
      ));
  }

  void _paintHills(Canvas canvas, Size size, double t, double snow) {
    _hill(canvas, size, t * 0.02, 0.86, 0.05, 1.6,
        Color.lerp(const Color(0xFF1F5A3A), const Color(0xFFDDE6EF), snow * 0.75)!);
    _hill(canvas, size, t * 0.045 + 0.3, 0.92, 0.04, 2.3,
        Color.lerp(const Color(0xFF17432C), const Color(0xFFF4F7FA), snow * 0.85)!);
  }

  void _hill(Canvas canvas, Size size, double offset, double base, double amplitude, double frequency, Color color) {
    final path = Path()..moveTo(0, size.height);
    const steps = 24;
    for (var i = 0; i <= steps; i++) {
      final x = i / steps;
      final y = base + amplitude * math.sin((x - offset) * 2 * math.pi * frequency);
      path.lineTo(x * size.width, y * size.height);
    }
    path
      ..lineTo(size.width, size.height)
      ..close();
    _paint.color = color;
    canvas.drawPath(path, _paint);
  }

  void _paintRain(Canvas canvas, Size size, double t, double strength) {
    final path = Path();
    final length = size.height * 0.06;
    for (var i = 0; i < _rain.length; i += 3) {
      final speed = 0.9 + _rain[i + 2] * 0.6;
      final y = (_rain[i + 1] + t * speed) % 1.0;
      final x = (_rain[i] + y * 0.18) % 1.0;
      final p = Offset(x * size.width, y * size.height);
      path
        ..moveTo(p.dx, p.dy)
        ..lineTo(p.dx + length * 0.22, p.dy + length);
    }
    _rainPaint
      ..color = const Color(0xFFB8D4F0).withValues(alpha: 0.7 * strength)
      ..strokeWidth = size.width * 0.006;
    canvas.drawPath(path, _rainPaint);
  }

  void _paintSnow(Canvas canvas, Size size, double t, double strength) {
    var small = 0, large = 0;
    for (var i = 0; i < _snow.length; i += 3) {
      final speed = 0.08 + _snow[i + 2] * 0.1;
      final y = (_snow[i + 1] + t * speed) % 1.0;
      final sway = math.sin(t * 1.4 + _snow[i + 2] * 6) * 0.025;
      final x = (_snow[i] + sway + 1) % 1.0;
      if (_snow[i + 2] > 0.6) {
        _snowLarge[large++] = x * size.width;
        _snowLarge[large++] = y * size.height;
      } else {
        _snowSmall[small++] = x * size.width;
        _snowSmall[small++] = y * size.height;
      }
    }
    _snowPaint.color = Colors.white.withValues(alpha: 0.9 * strength);
    _snowPaint.strokeWidth = size.width * 0.016;
    canvas.drawRawPoints(ui.PointMode.points, Float32List.sublistView(_snowSmall, 0, small), _snowPaint);
    _snowPaint.strokeWidth = size.width * 0.026;
    canvas.drawRawPoints(ui.PointMode.points, Float32List.sublistView(_snowLarge, 0, large), _snowPaint);
  }

  static Color _mix(List<Color> colors, List<double> weights) {
    double a = 0, r = 0, g = 0, b = 0;
    for (var i = 0; i < colors.length; i++) {
      a += colors[i].a * weights[i];
      r += colors[i].r * weights[i];
      g += colors[i].g * weights[i];
      b += colors[i].b * weights[i];
    }
    return Color.from(alpha: a, red: r, green: g, blue: b);
  }

  @override
  bool shouldRepaint(covariant _SkyPainter oldDelegate) => false;
}
