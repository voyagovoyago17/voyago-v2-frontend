import 'dart:async';
import 'dart:math' as math;
import 'package:confetti/confetti.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../api/api_exceptions.dart';
import '../../models/packing.dart';
import '../../providers/trips_provider.dart';
import '../../theme.dart';

/// Ouvre la valise du voyage : liste sur mesure à cocher, puis « dernier check » animé.
Future<void> showPackingSheet(BuildContext context, {required String tripId, required String destination}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.92,
      minChildSize: 0.55,
      maxChildSize: 0.97,
      expand: false,
      builder: (_, scroll) => _PackingSheet(tripId: tripId, destination: destination, scrollController: scroll),
    ),
  );
}

class _PackingSheet extends ConsumerStatefulWidget {
  final String tripId;
  final String destination;
  final ScrollController scrollController;

  const _PackingSheet({required this.tripId, required this.destination, required this.scrollController});

  @override
  ConsumerState<_PackingSheet> createState() => _PackingSheetState();
}

class _PackingSheetState extends ConsumerState<_PackingSheet> {
  PackingList? _list;
  String? _error;
  bool _finalCheck = false;
  final _newItem = TextEditingController();
  late final ConfettiController _confetti = ConfettiController(duration: const Duration(milliseconds: 1600));

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _newItem.dispose();
    _confetti.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final list = await ref.read(tripsApiProvider).getPacking(widget.tripId);
      if (mounted) setState(() => _list = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  /// Coche optimiste : l'interface répond tout de suite, le serveur suit.
  Future<void> _toggle(PackingItem item, bool packed) async {
    final before = _list;
    if (before == null) return;
    HapticFeedback.selectionClick();
    final after = before.withItem(item.id, packed);
    setState(() => _list = after);
    if (!before.ready && after.ready) _celebrate();
    try {
      await ref.read(tripsApiProvider).togglePackingItem(widget.tripId, item.id, packed);
      _refreshTrips();
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _list = before);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)));
    }
  }

  void _celebrate() {
    HapticFeedback.heavyImpact();
    _confetti.play();
  }

  void _refreshTrips() {
    // La carte « prochain voyage » de l'accueil affiche l'avancement de la valise
    ref.invalidate(tripDetailProvider(widget.tripId));
  }

  Future<void> _addItem() async {
    final label = _newItem.text.trim();
    if (label.isEmpty) return;
    _newItem.clear();
    try {
      final list = await ref.read(tripsApiProvider).addPackingItem(widget.tripId, label);
      if (mounted) setState(() => _list = list);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)));
      }
    }
  }

  Future<void> _removeItem(PackingItem item) async {
    try {
      final list = await ref.read(tripsApiProvider).removePackingItem(widget.tripId, item.id);
      if (mounted) setState(() => _list = list);
    } on ApiException catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final list = _list;
    return Container(
      decoration: const BoxDecoration(
        color: VoyagoColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Stack(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 450),
            switchInCurve: Curves.easeOutCubic,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(begin: const Offset(0, 0.04), end: Offset.zero).animate(animation),
                child: child,
              ),
            ),
            child: list == null
                ? (_error != null ? _buildError() : const _PackingLoader(key: ValueKey('loading')))
                : _finalCheck
                    ? _FinalCheck(
                        key: const ValueKey('final'),
                        list: list,
                        destination: widget.destination,
                        onPack: (item) => _toggle(item, true),
                        onDone: () => setState(() => _finalCheck = false),
                      )
                    : _buildList(list),
          ),
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confetti,
              blastDirectionality: BlastDirectionality.explosive,
              numberOfParticles: 28,
              gravity: 0.25,
              colors: const [VoyagoColors.primary, VoyagoColors.yellow, VoyagoColors.blue, VoyagoColors.coral],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      key: const ValueKey('error'),
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset('assets/icons3d/suitcase.png', width: 110),
            const SizedBox(height: 14),
            Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: VoyagoColors.muted)),
            const SizedBox(height: 12),
            TextButton(onPressed: _load, child: const Text('Réessayer')),
          ],
        ),
      ),
    );
  }

  Widget _buildList(PackingList list) {
    final essentials = list.items.where((i) => i.essential).toList();
    final essentialsPacked = essentials.where((i) => i.packed).length;
    return ListView(
      key: const ValueKey('list'),
      controller: widget.scrollController,
      padding: EdgeInsets.fromLTRB(18, 10, 18, 24 + MediaQuery.of(context).viewInsets.bottom),
      children: [
        const _Grabber(),
        const SizedBox(height: 6),
        Center(child: _SuitcaseHero(progress: list.progress, packedCount: list.packedCount, ready: list.ready)),
        const SizedBox(height: 8),
        Text(
          list.ready ? 'Valise prête ! 🎉' : 'Ma valise pour ${widget.destination}',
          textAlign: TextAlign.center,
          style: const TextStyle(color: VoyagoColors.text, fontSize: 21, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        Text(
          '${list.packedCount}/${list.total} objets · $essentialsPacked/${essentials.length} essentiels',
          textAlign: TextAlign.center,
          style: const TextStyle(color: VoyagoColors.muted, fontSize: 13),
        ),
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => setState(() => _finalCheck = true),
            icon: Image.asset('assets/icons3d/check.png', width: 22),
            label: Text(list.ready ? 'Revoir le dernier check' : 'Faire le dernier check',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: VoyagoColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 18),
        for (final category in list.categories)
          _CategorySection(
            category: category,
            onToggle: _toggle,
            onRemove: _removeItem,
          ),
        const SizedBox(height: 6),
        TextField(
          controller: _newItem,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _addItem(),
          style: const TextStyle(color: VoyagoColors.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: 'Ajouter un objet perso…',
            hintStyle: const TextStyle(color: VoyagoColors.muted),
            prefixIcon: const Icon(Icons.add_rounded, color: VoyagoColors.primary),
            suffixIcon: IconButton(
              icon: const Icon(Icons.send_rounded, color: VoyagoColors.primary, size: 20),
              onPressed: _addItem,
            ),
            filled: true,
            fillColor: VoyagoColors.surface,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
          ),
        ),
      ],
    );
  }
}

// =============================================================================
// Valise 3D animée (flotte, rebondit à chaque objet, s'illumine quand elle est prête)
// =============================================================================

class _SuitcaseHero extends StatefulWidget {
  final double progress;
  final int packedCount;
  final bool ready;
  final double size;

  const _SuitcaseHero({required this.progress, required this.packedCount, required this.ready, this.size = 150});

  @override
  State<_SuitcaseHero> createState() => _SuitcaseHeroState();
}

class _SuitcaseHeroState extends State<_SuitcaseHero> with SingleTickerProviderStateMixin {
  late final AnimationController _float =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))..repeat(reverse: true);

  @override
  void dispose() {
    _float.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = widget.size;
    final color = widget.ready ? VoyagoColors.primary : VoyagoColors.yellow;
    return SizedBox(
      width: size + 20,
      height: size + 20,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Halo + anneau de progression
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [BoxShadow(color: color.withValues(alpha: widget.ready ? 0.35 : 0.15), blurRadius: 40, spreadRadius: 4)],
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: widget.progress),
            duration: const Duration(milliseconds: 600),
            curve: Curves.easeOutCubic,
            builder: (_, value, __) => SizedBox(
              width: size,
              height: size,
              child: CircularProgressIndicator(
                value: value,
                strokeWidth: 6,
                strokeCap: StrokeCap.round,
                backgroundColor: VoyagoColors.cardBorder,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
          // Rebond à chaque objet ajouté (clé = nombre d'objets prêts)
          TweenAnimationBuilder<double>(
            key: ValueKey(widget.packedCount),
            tween: Tween(begin: 1.14, end: 1),
            duration: const Duration(milliseconds: 650),
            curve: Curves.elasticOut,
            builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
            child: AnimatedBuilder(
              animation: _float,
              builder: (_, child) {
                final t = Curves.easeInOut.transform(_float.value);
                return Transform.translate(
                  offset: Offset(0, -6 + 12 * t),
                  child: Transform.rotate(angle: -0.05 + 0.1 * t, child: child),
                );
              },
              child: Image.asset('assets/icons3d/suitcase.png', width: size * 0.68, filterQuality: FilterQuality.medium),
            ),
          ),
          if (widget.ready)
            Positioned(
              right: 6,
              top: 10,
              child: TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 700),
                curve: Curves.elasticOut,
                builder: (_, s, child) => Transform.scale(scale: s, child: child),
                child: Image.asset('assets/icons3d/check.png', width: 46),
              ),
            ),
        ],
      ),
    );
  }
}

class _Grabber extends StatelessWidget {
  const _Grabber();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 4),
        decoration: BoxDecoration(color: VoyagoColors.cardBorder, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}

/// Préparation par l'IA : la valise saute pendant que les conseils défilent.
class _PackingLoader extends StatefulWidget {
  const _PackingLoader({super.key});

  @override
  State<_PackingLoader> createState() => _PackingLoaderState();
}

class _PackingLoaderState extends State<_PackingLoader> with SingleTickerProviderStateMixin {
  static const _steps = [
    'Je regarde la météo de ton voyage…',
    'Je vérifie les prises électriques du pays…',
    'Je compte les tenues selon la durée…',
    'Je pense à ta trousse de santé…',
    'Dernières vérifications…',
  ];
  late final AnimationController _bounce =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 700))..repeat(reverse: true);
  int _step = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 1600), (_) {
      if (mounted) setState(() => _step = (_step + 1) % _steps.length);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _bounce.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: _bounce,
            builder: (_, child) {
              final t = Curves.easeOut.transform(_bounce.value);
              return Transform.translate(
                offset: Offset(0, -18 * t),
                child: Transform.scale(scaleY: 0.94 + 0.06 * t, child: child),
              );
            },
            child: Image.asset('assets/icons3d/suitcase.png', width: 120),
          ),
          const SizedBox(height: 18),
          const Text('Voyagooo prépare ta valise 🦜',
              style: TextStyle(color: VoyagoColors.text, fontSize: 17, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 350),
            child: Text(_steps[_step],
                key: ValueKey(_step), style: const TextStyle(color: VoyagoColors.muted, fontSize: 13)),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Liste par catégorie
// =============================================================================

class _CategorySection extends StatelessWidget {
  final PackingCategory category;
  final void Function(PackingItem, bool) onToggle;
  final ValueChanged<PackingItem> onRemove;

  const _CategorySection({required this.category, required this.onToggle, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    final done = category.packedCount == category.items.length;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Image.asset(category.icon3d, width: 34, height: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(category.title,
                    style: const TextStyle(color: VoyagoColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
                decoration: BoxDecoration(
                  color: (done ? VoyagoColors.primary : VoyagoColors.cardBorder).withValues(alpha: done ? 0.18 : 1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('${category.packedCount}/${category.items.length}',
                    style: TextStyle(
                        color: done ? VoyagoColors.primary : VoyagoColors.muted, fontSize: 12, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Container(
            decoration: BoxDecoration(
              color: VoyagoColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: VoyagoColors.cardBorder),
            ),
            child: Column(
              children: [
                for (var i = 0; i < category.items.length; i++) ...[
                  if (i > 0) const Divider(height: 1, color: VoyagoColors.cardBorder, indent: 54),
                  _PackingRow(
                    item: category.items[i],
                    onToggle: (v) => onToggle(category.items[i], v),
                    onRemove: category.items[i].custom ? () => onRemove(category.items[i]) : null,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _PackingRow extends StatelessWidget {
  final PackingItem item;
  final ValueChanged<bool> onToggle;
  final VoidCallback? onRemove;

  const _PackingRow({required this.item, required this.onToggle, this.onRemove});

  @override
  Widget build(BuildContext context) {
    final packed = item.packed;
    return InkWell(
      onTap: () => onToggle(!packed),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 10, 6, 10),
        child: Row(
          children: [
            _AnimatedCheck(checked: packed),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 250),
                          style: TextStyle(
                            color: packed ? VoyagoColors.muted : VoyagoColors.text,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: packed ? TextDecoration.lineThrough : TextDecoration.none,
                            decorationColor: VoyagoColors.muted,
                          ),
                          child: Text(item.label),
                        ),
                      ),
                      if (item.essential) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                          decoration: BoxDecoration(
                            color: VoyagoColors.yellow.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Text('Essentiel',
                              style: TextStyle(color: VoyagoColors.yellow, fontSize: 9.5, fontWeight: FontWeight.w800)),
                        ),
                      ],
                    ],
                  ),
                  if (item.reason != null)
                    Text(item.reason!, style: const TextStyle(color: VoyagoColors.muted, fontSize: 11.5)),
                ],
              ),
            ),
            if (onRemove != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18, color: VoyagoColors.muted),
                onPressed: onRemove,
              ),
          ],
        ),
      ),
    );
  }
}

class _AnimatedCheck extends StatelessWidget {
  final bool checked;

  const _AnimatedCheck({required this.checked});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      width: 28,
      height: 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: checked ? VoyagoColors.primary : Colors.transparent,
        border: Border.all(color: checked ? VoyagoColors.primary : VoyagoColors.muted.withValues(alpha: 0.6), width: 2),
        boxShadow: checked ? [BoxShadow(color: VoyagoColors.primary.withValues(alpha: 0.4), blurRadius: 10)] : null,
      ),
      child: AnimatedScale(
        scale: checked ? 1 : 0,
        duration: const Duration(milliseconds: 260),
        curve: Curves.easeOutBack,
        child: const Icon(Icons.check_rounded, color: Colors.white, size: 18),
      ),
    );
  }
}

// =============================================================================
// Dernier check : un objet à la fois, puis la fête
// =============================================================================

class _FinalCheck extends StatefulWidget {
  final PackingList list;
  final String destination;
  final ValueChanged<PackingItem> onPack;
  final VoidCallback onDone;

  const _FinalCheck({
    super.key,
    required this.list,
    required this.destination,
    required this.onPack,
    required this.onDone,
  });

  @override
  State<_FinalCheck> createState() => _FinalCheckState();
}

class _FinalCheckState extends State<_FinalCheck> {
  /// Objets restants au début du check : les essentiels d'abord
  late final List<PackingItem> _queue = [
    ...widget.list.items.where((i) => !i.packed && i.essential),
    ...widget.list.items.where((i) => !i.packed && !i.essential),
  ];
  int _index = 0;
  int _skipped = 0;
  final ConfettiController _confetti = ConfettiController(duration: const Duration(milliseconds: 2200));

  @override
  void initState() {
    super.initState();
    if (_queue.isEmpty) WidgetsBinding.instance.addPostFrameCallback((_) => _confetti.play());
  }

  @override
  void dispose() {
    _confetti.dispose();
    super.dispose();
  }

  void _next({required bool packed}) {
    final item = _queue[_index];
    if (packed) {
      widget.onPack(item);
    } else {
      _skipped++;
      HapticFeedback.lightImpact();
    }
    setState(() => _index++);
    if (_index >= _queue.length && _skipped == 0) _confetti.play();
  }

  @override
  Widget build(BuildContext context) {
    final finished = _index >= _queue.length;
    return Stack(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
          child: Column(
            children: [
              const _Grabber(),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_rounded, color: VoyagoColors.text),
                    onPressed: widget.onDone,
                  ),
                  const Expanded(
                    child: Text('Dernier check',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: VoyagoColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
                  ),
                  const SizedBox(width: 48),
                ],
              ),
              if (!finished && _queue.isNotEmpty) ...[
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: _index / _queue.length,
                    minHeight: 6,
                    backgroundColor: VoyagoColors.cardBorder,
                    valueColor: const AlwaysStoppedAnimation(VoyagoColors.primary),
                  ),
                ),
                const SizedBox(height: 6),
                Text('${_index + 1} / ${_queue.length}', style: const TextStyle(color: VoyagoColors.muted, fontSize: 12)),
              ],
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 420),
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.85, end: 1.0).animate(CurvedAnimation(parent: animation, curve: Curves.easeOutBack)),
                      child: child,
                    ),
                  ),
                  child: finished ? _buildFinale() : _buildCard(_queue[_index]),
                ),
              ),
            ],
          ),
        ),
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _confetti,
            blastDirectionality: BlastDirectionality.explosive,
            numberOfParticles: 40,
            gravity: 0.2,
            colors: const [VoyagoColors.primary, VoyagoColors.yellow, VoyagoColors.blue, VoyagoColors.coral],
          ),
        ),
      ],
    );
  }

  Widget _buildCard(PackingItem item) {
    final category = widget.list.categoryOf(item.id);
    return Column(
      key: ValueKey(item.id),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _Wobble(child: Image.asset(category?.icon3d ?? 'assets/icons3d/backpack.png', width: 130)),
        const SizedBox(height: 24),
        Text(item.essential ? 'Indispensable : as-tu pensé à…' : 'As-tu pensé à…',
            style: TextStyle(
                color: item.essential ? VoyagoColors.yellow : VoyagoColors.muted, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(item.label,
            textAlign: TextAlign.center,
            style: const TextStyle(color: VoyagoColors.text, fontSize: 24, fontWeight: FontWeight.w800, height: 1.2)),
        if (item.reason != null) ...[
          const SizedBox(height: 8),
          Text(item.reason!, textAlign: TextAlign.center, style: const TextStyle(color: VoyagoColors.muted, fontSize: 13.5)),
        ],
        const SizedBox(height: 32),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: () => _next(packed: true),
            icon: const Icon(Icons.check_rounded),
            label: const Text("C'est dans la valise", style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            style: ElevatedButton.styleFrom(
              backgroundColor: VoyagoColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => _next(packed: false),
          child: const Text('Pas encore / pas besoin', style: TextStyle(color: VoyagoColors.muted, fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }

  Widget _buildFinale() {
    final allGood = _skipped == 0;
    return Column(
      key: const ValueKey('finale'),
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            const _SuitcaseHero(progress: 1, packedCount: 999, ready: true, size: 170),
            if (allGood)
              Positioned(
                left: -6,
                bottom: 4,
                child: TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 900),
                  curve: Curves.elasticOut,
                  builder: (_, s, child) => Transform.scale(scale: s, child: child),
                  child: Image.asset('assets/icons3d/party.png', width: 58),
                ),
              ),
          ],
        ),
        const SizedBox(height: 18),
        Text(
          allGood ? 'Valise prête !' : 'Presque prêt !',
          style: const TextStyle(color: VoyagoColors.text, fontSize: 26, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          allGood
              ? 'Tout est dans la valise. Bon voyage à ${widget.destination} 🦜'
              : 'Il te reste $_skipped objet${_skipped > 1 ? 's' : ''} à prévoir : ils restent dans ta liste.',
          textAlign: TextAlign.center,
          style: const TextStyle(color: VoyagoColors.muted, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: allGood ? () => Navigator.of(context).pop() : widget.onDone,
            style: ElevatedButton.styleFrom(
              backgroundColor: VoyagoColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
              elevation: 0,
            ),
            child: Text(allGood ? "C'est parti ! ✈️" : 'Revenir à ma liste',
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          ),
        ),
      ],
    );
  }
}

/// Petit balancement de l'icône 3D du dernier check.
class _Wobble extends StatefulWidget {
  final Widget child;

  const _Wobble({required this.child});

  @override
  State<_Wobble> createState() => _WobbleState();
}

class _WobbleState extends State<_Wobble> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1800))
    ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = _c.value * 2 * math.pi;
        return Transform.translate(
          offset: Offset(0, math.sin(t) * 6),
          child: Transform.rotate(angle: math.sin(t + 0.6) * 0.08, child: child),
        );
      },
      child: widget.child,
    );
  }
}
