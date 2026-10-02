import 'dart:math' as math;
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

/// Taille du marqueur de pépite sur la carte (à utiliser pour le Marker)
const double gemMarkerWidth = 76;
const double gemMarkerHeight = 92;

/// Pépite sur la carte : diamant qui flotte, onde lumineuse et XP à gagner.
/// Verrouillée (grisée, cadenas) tant que le voyage n'a pas commencé ;
/// à portée, elle s'illumine et pulse plus vite pour inviter à la toucher.
class GemMapMarker extends StatefulWidget {
  final TripGem gem;
  final bool inRange;
  final bool locked;
  final bool selected;
  final VoidCallback onTap;

  const GemMapMarker({
    super.key,
    required this.gem,
    required this.inRange,
    required this.onTap,
    this.locked = false,
    this.selected = false,
  });

  @override
  State<GemMapMarker> createState() => _GemMapMarkerState();
}

class _GemMapMarkerState extends State<GemMapMarker> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: _duration)..repeat();

  Duration get _duration => Duration(milliseconds: widget.inRange ? 1100 : 2200);

  @override
  void didUpdateWidget(covariant GemMapMarker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.inRange != widget.inRange) {
      _c
        ..duration = _duration
        ..repeat();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.locked ? const Color(0xFF8A8A9B) : widget.gem.rarityColor;
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            final bob = math.sin(t * 2 * math.pi) * (widget.locked ? 2 : 4);
            final scale = widget.selected ? 1.15 : 1.0;
            return Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: gemMarkerWidth,
                  height: 64,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      // Onde lumineuse qui s'élargit
                      if (!widget.locked)
                        Container(
                          width: 30 + 40 * t,
                          height: 30 + 40 * t,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: color.withValues(alpha: (1 - t) * 0.8), width: 2),
                          ),
                        ),
                      Transform.translate(
                        offset: Offset(0, bob),
                        child: Transform.scale(
                          scale: scale,
                          child: Transform.rotate(
                            angle: math.pi / 4,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [Color.lerp(color, Colors.white, 0.45)!, color],
                                ),
                                borderRadius: BorderRadius.circular(7),
                                border: Border.all(color: Colors.white, width: 2),
                                boxShadow: [
                                  BoxShadow(
                                    color: color.withValues(alpha: widget.locked ? 0.25 : (widget.inRange ? 0.9 : 0.6)),
                                    blurRadius: widget.inRange ? 22 : 14,
                                    spreadRadius: widget.inRange ? 3 : 1,
                                  ),
                                ],
                              ),
                              alignment: Alignment.center,
                              child: Transform.rotate(
                                angle: -math.pi / 4,
                                child: Icon(
                                  widget.locked ? Icons.lock_rounded : Icons.diamond_rounded,
                                  color: Colors.white,
                                  size: 15,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                // Étiquette : XP à gagner, ou appel à l'action quand on est dessus
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: widget.inRange ? color : const Color(0xE610221F),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: color.withValues(alpha: 0.8)),
                  ),
                  child: Text(
                    widget.inRange ? 'Touche !' : '+${widget.gem.xp} XP',
                    style: TextStyle(
                      color: widget.inRange ? const Color(0xFF10221F) : Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// Fiche d'une pépite touchée sur la carte : photo, rareté, distance, indice et action.
class GemSpotlightCard extends StatelessWidget {
  final TripGem gem;
  final double? distanceM;
  final bool canCollect;
  final bool collecting;

  /// Message quand le radar n'est pas encore actif (dates, démarrage)
  final String? lockedMessage;
  final VoidCallback onClose;
  final VoidCallback onCollect;
  final VoidCallback onDetour;
  final VoidCallback onOpenRadar;

  const GemSpotlightCard({
    super.key,
    required this.gem,
    required this.distanceM,
    required this.canCollect,
    required this.collecting,
    this.lockedMessage,
    required this.onClose,
    required this.onCollect,
    required this.onDetour,
    required this.onOpenRadar,
  });

  @override
  Widget build(BuildContext context) {
    final color = gem.rarityColor;
    final d = distanceM;
    final distance = d == null ? null : (d < 1000 ? '${d.round()} m' : '${(d / 1000).toStringAsFixed(1)} km');
    final image = gem.imageUrl;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Material(
        color: Colors.transparent,
        child: Container(
          decoration: BoxDecoration(
            color: const Color(0xF210221F),
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: color.withValues(alpha: 0.55)),
            boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.45), blurRadius: 22, offset: const Offset(0, 10))],
          ),
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SizedBox(
                      width: 70,
                      height: 70,
                      child: image != null && image.isNotEmpty
                          ? Image.network(image, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _placeholder(color))
                          : _placeholder(color),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '💎 PÉPITE ${gem.rarityLabel.toUpperCase()} · +${gem.xp} XP',
                          style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.bold, letterSpacing: 0.8),
                        ),
                        const SizedBox(height: 3),
                        Text(gem.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 3),
                        Text(
                          [if (distance != null) '📍 $distance', 'Jour ${gem.day}'].join(' · '),
                          style: const TextStyle(color: Color(0xFF9CBAB5), fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, color: Colors.white54, size: 20),
                  ),
                ],
              ),
              if (gem.teaser.isNotEmpty) ...[
                const SizedBox(height: 10),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome_rounded, color: radarColor, size: 15),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(gem.teaser,
                          style: const TextStyle(color: Color(0xFF9CBAB5), fontSize: 13, fontStyle: FontStyle.italic, height: 1.35)),
                    ),
                  ],
                ),
              ],
              if (lockedMessage != null) ...[
                const SizedBox(height: 10),
                Row(
                  children: [
                    const Icon(Icons.lock_clock_rounded, color: Colors.white54, size: 15),
                    const SizedBox(width: 6),
                    Expanded(child: Text(lockedMessage!, style: const TextStyle(color: Colors.white70, fontSize: 12))),
                  ],
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: canCollect
                        ? ElevatedButton.icon(
                            onPressed: collecting ? null : onCollect,
                            icon: collecting
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.diamond_rounded, size: 18),
                            label: Text('Ramasser +${gem.xp} XP', style: const TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: color,
                              foregroundColor: const Color(0xFF10221F),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          )
                        : ElevatedButton.icon(
                            onPressed: onDetour,
                            icon: const Icon(Icons.alt_route_rounded, size: 18),
                            label: Text(distance != null ? 'Détour · $distance' : 'Faire le détour',
                                style: const TextStyle(fontWeight: FontWeight.bold)),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: radarColor,
                              foregroundColor: const Color(0xFF10221F),
                              elevation: 0,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: onOpenRadar,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.white,
                      side: const BorderSide(color: Color(0xFF283936)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                    ),
                    child: const Icon(Icons.radar_rounded, size: 20),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _placeholder(Color color) => Container(
        color: const Color(0xFF283936),
        alignment: Alignment.center,
        child: Icon(Icons.diamond_outlined, color: color, size: 28),
      );
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
