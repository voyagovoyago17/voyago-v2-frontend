import 'package:flutter/material.dart';
import '../../models/trip_gem.dart';

/// Couleur signature du radar
const Color radarColor = Color(0xFF0DF2CC);

/// Ondes radar autour de ma position : un seul contrôleur et un seul canevas (léger à animer).
class RadarPulse extends StatefulWidget {
  final double size;

  const RadarPulse({super.key, this.size = 220});

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse> with SingleTickerProviderStateMixin {
  late final AnimationController _controller =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.square(widget.size),
          painter: _RadarPainter(_controller),
        ),
      ),
    );
  }
}

class _RadarPainter extends CustomPainter {
  final Animation<double> progress;

  _RadarPainter(this.progress) : super(repaint: progress);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final maxRadius = size.width / 2;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    // Trois ondes décalées qui s'élargissent en s'estompant
    for (var i = 0; i < 3; i++) {
      final t = (progress.value + i / 3) % 1.0;
      paint.color = radarColor.withValues(alpha: (1 - t) * 0.55);
      canvas.drawCircle(center, maxRadius * (0.2 + 0.8 * t), paint);
    }
    canvas.drawCircle(center, 7, Paint()..color = radarColor);
    canvas.drawCircle(center, 7, Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..color = Colors.white);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) => false;
}

/// Pépite sur la carte : carré arrondi avec un diamant, couleur selon la rareté.
class GemMapMarker extends StatelessWidget {
  final TripGem gem;

  /// Assez proche pour la ramasser : la pépite s'illumine
  final bool inRange;
  final VoidCallback onTap;

  const GemMapMarker({super.key, required this.gem, required this.inRange, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final color = gem.rarityColor;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xE61B2725),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withValues(alpha: inRange ? 1 : 0.6), width: inRange ? 2 : 1.2),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: inRange ? 0.6 : 0.3), blurRadius: inRange ? 16 : 10),
          ],
        ),
        alignment: Alignment.center,
        child: Icon(Icons.diamond_rounded, color: color, size: 18),
      ),
    );
  }
}

/// Bannière d'alerte : une pépite est à proximité (détour) ou à portée (ramasser).
class GemAlertBanner extends StatelessWidget {
  final TripGem gem;
  final double distanceM;
  final bool inRange;
  final bool collecting;
  final VoidCallback onTap;
  final VoidCallback onCollect;
  final VoidCallback onDismiss;

  const GemAlertBanner({
    super.key,
    required this.gem,
    required this.distanceM,
    required this.inRange,
    required this.collecting,
    required this.onTap,
    required this.onCollect,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: inRange ? null : onTap,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 10, 4, 10),
        decoration: BoxDecoration(
          color: const Color(0xE610221F),
          borderRadius: BorderRadius.circular(14),
          border: Border(left: BorderSide(color: gem.rarityColor, width: 4)),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 16, offset: const Offset(0, 6))],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: gem.rarityColor.withValues(alpha: 0.18), shape: BoxShape.circle),
              child: Icon(inRange ? Icons.diamond_rounded : Icons.notifications_active_rounded, color: gem.rarityColor, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    inRange ? 'TU Y ES !' : 'DÉCOUVERTE À PROXIMITÉ',
                    style: TextStyle(color: gem.rarityColor, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 1.2),
                  ),
                  const SizedBox(height: 2),
                  Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(text: gem.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                        TextSpan(
                          text: inRange
                              ? ' · ramasse ta pépite'
                              : ' · ${distanceM < 1000 ? '${distanceM.round()} m' : '${(distanceM / 1000).toStringAsFixed(1)} km'}, '
                                  'gagne ',
                        ),
                        if (!inRange)
                          TextSpan(text: '${gem.xp} XP', style: TextStyle(color: gem.rarityColor, fontWeight: FontWeight.bold)),
                      ],
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.white, fontSize: 13, height: 1.3),
                  ),
                ],
              ),
            ),
            if (inRange)
              Padding(
                padding: const EdgeInsets.only(left: 6, right: 6),
                child: ElevatedButton(
                  onPressed: collecting ? null : onCollect,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: gem.rarityColor,
                    foregroundColor: const Color(0xFF10221F),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  child: collecting
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : Text('+${gem.xp} XP', style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
              )
            else
              IconButton(
                onPressed: onDismiss,
                icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
