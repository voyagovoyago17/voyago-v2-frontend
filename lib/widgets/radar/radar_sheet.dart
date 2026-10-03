import 'package:cached_network_image/cached_network_image.dart';
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import '../../models/trip_gem.dart';
import '../../providers/auth_provider.dart';
import '../../providers/profile_provider.dart';
import '../../providers/trips_provider.dart';
import '../../services/app_sounds.dart';
import 'radar_visuals.dart';

const _bg = Color(0xFF10221F);
const _card = Color(0xFF1B2725);
const _border = Color(0xFF283936);
const _muted = Color(0xFF9CBAB5);

/// Feuille « Découvertes en temps réel » : pépites du voyage triées par distance,
/// mises à jour avec ma position. Détour vers une pépite, ou ramassage quand je suis dessus.
Future<void> showRadarSheet(
  BuildContext context, {
  required String tripId,
  required ValueNotifier<LatLng?> position,
  required void Function(TripGem gem) onDetour,
  required Future<void> Function(TripGem gem) onCollect,
}) {
  return showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: _bg,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
    builder: (_) => _RadarSheet(tripId: tripId, position: position, onDetour: onDetour, onCollect: onCollect),
  );
}

class _RadarSheet extends ConsumerWidget {
  final String tripId;
  final ValueNotifier<LatLng?> position;
  final void Function(TripGem gem) onDetour;
  final Future<void> Function(TripGem gem) onCollect;

  const _RadarSheet({required this.tripId, required this.position, required this.onDetour, required this.onCollect});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final gemsAsync = ref.watch(tripGemsProvider(tripId));
    final userId = ref.watch(currentUserProvider)?.userId ?? '';
    final profile = userId.isEmpty ? null : ref.watch(profileProvider(userId)).valueOrNull;

    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.78,
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: _border, borderRadius: BorderRadius.circular(2))),
          // En-tête : niveau, XP et état du radar
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(color: radarColor.withValues(alpha: 0.18), borderRadius: BorderRadius.circular(8)),
                  child: const Icon(Icons.radar_rounded, color: radarColor, size: 22),
                ),
                const SizedBox(width: 10),
                const Expanded(
                  child: Text('Radar à pépites', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.bold)),
                ),
                if (profile != null)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: _card, borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
                    child: Text(
                      'Niv. ${profile.level} · ${profile.xp} XP',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: gemsAsync.when(
              loading: () => const Center(child: CircularProgressIndicator(color: radarColor)),
              error: (_, __) => const _Message(icon: Icons.wifi_off_rounded, text: 'Radar indisponible pour le moment.'),
              data: (data) => ValueListenableBuilder<LatLng?>(
                valueListenable: position,
                builder: (context, pos, _) => _buildBody(context, ref, data, pos),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, WidgetRef ref, TripGems data, LatLng? pos) {
    if (data.gems.isEmpty) {
      return const _Message(icon: Icons.diamond_outlined, text: "Pas de pépites sur ce voyage.\nLes nouveaux itinéraires en contiennent une par jour.");
    }
    if (data.needsStart) {
      return _StartRadar(tripId: tripId, count: data.gems.length, xp: data.xpAvailable);
    }

    final withDistance = data.gems
        .map((g) => (gem: g, distance: pos == null ? null : g.distanceFrom(pos.latitude, pos.longitude)))
        .toList()
      ..sort((a, b) {
        if (a.gem.isCollected != b.gem.isCollected) return a.gem.isCollected ? 1 : -1;
        return (a.distance ?? double.infinity).compareTo(b.distance ?? double.infinity);
      });
    final nearbyCount = withDistance.where((e) => !e.gem.isCollected && (e.distance ?? double.infinity) <= 1000).length;

    final status = data.active
        ? (pos == null ? 'Active ta localisation pour scanner les environs' : '$nearbyCount pépite${nearbyCount > 1 ? 's' : ''} détectée${nearbyCount > 1 ? 's' : ''} à moins de 1 km')
        : data.ended
            ? 'Voyage terminé : ${data.collectedCount}/${data.gems.length} pépites ramassées'
            : data.startsAt != null
                ? 'Le radar s\'active le ${data.startsAt!.day}/${data.startsAt!.month} : les pépites se ramassent sur place'
                : 'Radar en veille';

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        Row(
          children: [
            if (data.active) ...[
              const _LiveDot(),
              const SizedBox(width: 8),
            ],
            Expanded(child: Text(status, style: const TextStyle(color: _muted, fontSize: 13))),
            Text(
              '${data.xpEarned}/${data.xpAvailable} XP',
              style: const TextStyle(color: radarColor, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
        const SizedBox(height: 12),
        for (final e in withDistance)
          _GemCard(
            gem: e.gem,
            distance: e.distance,
            canCollect: data.active && e.distance != null && e.distance! <= data.collectRadiusM * 0.75,
            active: data.active,
            onDetour: () {
              Navigator.of(context).pop();
              onDetour(e.gem);
            },
            onCollect: () => onCollect(e.gem),
          ),
      ],
    );
  }
}

class _GemCard extends StatefulWidget {
  final TripGem gem;
  final double? distance;
  final bool canCollect;
  final bool active;
  final VoidCallback onDetour;
  final Future<void> Function() onCollect;

  const _GemCard({
    required this.gem,
    required this.distance,
    required this.canCollect,
    required this.active,
    required this.onDetour,
    required this.onCollect,
  });

  @override
  State<_GemCard> createState() => _GemCardState();
}

class _GemCardState extends State<_GemCard> {
  bool _collecting = false;

  String get _distanceLabel {
    final d = widget.distance;
    if (d == null) return 'Jour ${widget.gem.day}';
    final label = d < 1000 ? '${d.round()} m' : '${(d / 1000).toStringAsFixed(1)} km';
    return '$label · Jour ${widget.gem.day}';
  }

  @override
  Widget build(BuildContext context) {
    final gem = widget.gem;
    final color = gem.rarityColor;
    final highlighted = widget.canCollect || (!gem.isCollected && (widget.distance ?? double.infinity) <= 400);
    final image = gem.imageUrl;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: highlighted ? color.withValues(alpha: 0.6) : _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: 64,
                  height: 64,
                  child: ColorFiltered(
                    // Pépite lointaine ou ramassée : photo en noir et blanc
                    colorFilter: highlighted
                        ? const ColorFilter.mode(Colors.transparent, BlendMode.dst)
                        : const ColorFilter.matrix([0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0.33, 0.33, 0.33, 0, 0, 0, 0, 0, 1, 0]),
                    child: image != null && image.isNotEmpty
                        ? CachedNetworkImage(imageUrl: image, fit: BoxFit.cover, errorWidget: (_, __, ___) => _placeholder(color))
                        : _placeholder(color),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gem.name, maxLines: 2, overflow: TextOverflow.ellipsis,
                        style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.location_on_rounded, size: 13, color: _muted),
                        const SizedBox(width: 2),
                        Flexible(child: Text(_distanceLabel, style: const TextStyle(color: _muted, fontSize: 12))),
                      ],
                    ),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(gem.isCollected ? '✅' : '+${gem.xp} XP',
                      style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 2),
                  Text(gem.rarityLabel, style: TextStyle(color: color.withValues(alpha: 0.8), fontSize: 11)),
                ],
              ),
            ],
          ),
          if (gem.teaser.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: _bg.withValues(alpha: 0.6), borderRadius: BorderRadius.circular(10), border: Border.all(color: _border)),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.auto_awesome_rounded, color: radarColor, size: 15),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(gem.teaser,
                        style: const TextStyle(color: _muted, fontSize: 13, fontStyle: FontStyle.italic, height: 1.4)),
                  ),
                ],
              ),
            ),
          ],
          if (!gem.isCollected && widget.active) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: widget.canCollect
                  ? ElevatedButton.icon(
                      onPressed: _collecting
                          ? null
                          : () async {
                              setState(() => _collecting = true);
                              await widget.onCollect();
                              if (mounted) setState(() => _collecting = false);
                            },
                      icon: const Icon(Icons.diamond_rounded, size: 18),
                      label: Text('Ramasser +${gem.xp} XP', style: const TextStyle(fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: color,
                        foregroundColor: _bg,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    )
                  : OutlinedButton.icon(
                      onPressed: widget.onDetour,
                      icon: const Icon(Icons.alt_route_rounded, size: 18),
                      label: const Text('Faire le détour', style: TextStyle(fontWeight: FontWeight.w600)),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: highlighted ? color : Colors.white,
                        side: BorderSide(color: highlighted ? color : _border),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _placeholder(Color color) => Container(
        color: _border,
        alignment: Alignment.center,
        child: Icon(Icons.diamond_outlined, color: color),
      );
}

class _StartRadar extends ConsumerStatefulWidget {
  final String tripId;
  final int count;
  final int xp;

  const _StartRadar({required this.tripId, required this.count, required this.xp});

  @override
  ConsumerState<_StartRadar> createState() => _StartRadarState();
}

class _StartRadarState extends ConsumerState<_StartRadar> {
  bool _starting = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const RadarPulse(size: 140),
          const SizedBox(height: 16),
          Text(
            '${widget.count} pépites cachées t\'attendent (${widget.xp} XP)',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            'Ce voyage n\'a pas de dates : démarre-le quand tu es sur place. Le radar restera actif pendant toute la durée du voyage.',
            textAlign: TextAlign.center,
            style: TextStyle(color: _muted, fontSize: 13, height: 1.4),
          ),
          const SizedBox(height: 20),
          ElevatedButton.icon(
            onPressed: _starting
                ? null
                : () async {
                    setState(() => _starting = true);
                    try {
                      await ref.read(tripsApiProvider).startGems(widget.tripId);
                      ref.invalidate(tripGemsProvider(widget.tripId));
                    } finally {
                      if (mounted) setState(() => _starting = false);
                    }
                  },
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('Démarrer mon voyage', style: TextStyle(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: radarColor,
              foregroundColor: _bg,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            ),
          ),
        ],
      ),
    );
  }
}

class _LiveDot extends StatefulWidget {
  const _LiveDot();

  @override
  State<_LiveDot> createState() => _LiveDotState();
}

class _LiveDotState extends State<_LiveDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween(begin: 0.35, end: 1.0).animate(_c),
      child: Container(width: 9, height: 9, decoration: const BoxDecoration(color: radarColor, shape: BoxShape.circle)),
    );
  }
}

class _Message extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Message({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: _muted, size: 40),
            const SizedBox(height: 12),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: _muted, height: 1.4)),
          ],
        ),
      ),
    );
  }
}

/// Célébration d'une pépite ramassée : confettis et XP gagnée.
Future<void> showGemCollected(BuildContext context, TripGem gem, int xp, {int shards = 0, bool perfectDay = false}) {
  if (xp > 0) AppSounds.instance.gem();
  return showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Pépite ramassée',
    barrierColor: Colors.black54,
    transitionDuration: const Duration(milliseconds: 350),
    pageBuilder: (_, __, ___) => _GemCollected(gem: gem, xp: xp, shards: shards, perfectDay: perfectDay),
    transitionBuilder: (_, a, __, child) => ScaleTransition(
      scale: CurvedAnimation(parent: a, curve: Curves.easeOutBack),
      child: FadeTransition(opacity: a, child: child),
    ),
  );
}

class _GemCollected extends StatefulWidget {
  final TripGem gem;
  final int xp;

  /// Éclats gagnés (échangeables contre des modifications)
  final int shards;
  final bool perfectDay;

  const _GemCollected({required this.gem, required this.xp, this.shards = 0, this.perfectDay = false});

  @override
  State<_GemCollected> createState() => _GemCollectedState();
}

class _GemCollectedState extends State<_GemCollected> {
  late final ConfettiController _confetti = ConfettiController(duration: const Duration(milliseconds: 1400))..play();

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2600), () {
      if (mounted) Navigator.of(context).maybePop();
    });
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = widget.gem.rarityColor;
    return Stack(
      alignment: Alignment.center,
      children: [
        Material(
          color: Colors.transparent,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 40),
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(color: _bg, borderRadius: BorderRadius.circular(24), border: Border.all(color: color.withValues(alpha: 0.6))),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.diamond_rounded, color: color, size: 56),
                const SizedBox(height: 10),
                Text('Pépite ${widget.gem.rarityLabel.toLowerCase()} ramassée !',
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text(widget.gem.name, textAlign: TextAlign.center, style: const TextStyle(color: _muted)),
                const SizedBox(height: 14),
                Text(widget.xp > 0 ? '+${widget.xp} XP' : 'Déjà ramassée',
                    style: TextStyle(color: color, fontSize: 30, fontWeight: FontWeight.bold)),
                if (widget.shards > 0) ...[
                  const SizedBox(height: 6),
                  Text('+${widget.shards} Éclats 💎',
                      style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
                  if (widget.perfectDay)
                    const Padding(
                      padding: EdgeInsets.only(top: 4),
                      child: Text('Journée parfaite : bonus inclus !',
                          style: TextStyle(color: _muted, fontSize: 12.5)),
                    ),
                  const SizedBox(height: 4),
                  const Text('Échange tes Éclats contre des modifications de voyage',
                      textAlign: TextAlign.center, style: TextStyle(color: _muted, fontSize: 11.5)),
                ],
              ],
            ),
          ),
        ),
        ConfettiWidget(
          confettiController: _confetti,
          blastDirectionality: BlastDirectionality.explosive,
          numberOfParticles: 24,
          colors: [color, radarColor, Colors.white],
        ),
      ],
    );
  }
}
