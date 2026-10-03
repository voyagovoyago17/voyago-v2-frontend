import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../api/api_exceptions.dart';
import '../../models/circle_access.dart';
import '../../models/community_circle.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../theme.dart';
import '../location_pickers.dart';

// =============================================================================
// Conditions d'accès (carte du cercle, demande d'adhésion)
// =============================================================================

/// Liste des conditions d'accès, avec ✅ / ❌ quand le voyageur est connecté.
class JoinConditionsCard extends StatelessWidget {
  final List<JoinCheck> checks;
  final bool autoApprove;
  final bool compact;

  const JoinConditionsCard({super.key, required this.checks, this.autoApprove = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(compact ? 12 : 14),
      decoration: BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VoyagoColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.verified_user_rounded, size: 16, color: VoyagoColors.yellow),
              SizedBox(width: 6),
              Text("Conditions d'accès",
                  style: TextStyle(color: VoyagoColors.text, fontSize: 13.5, fontWeight: FontWeight.w800)),
            ],
          ),
          const SizedBox(height: 10),
          if (checks.isEmpty)
            const Text('Aucune condition : le fondateur étudie chaque demande.',
                style: TextStyle(color: VoyagoColors.muted, fontSize: 12.5))
          else
            for (final c in checks) _CheckRow(check: c),
          if (autoApprove) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.bolt_rounded, size: 15, color: VoyagoColors.primary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    checks.isEmpty
                        ? 'Entrée immédiate après ta demande'
                        : 'Entrée immédiate si toutes les conditions sont remplies',
                    style: const TextStyle(color: VoyagoColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  final JoinCheck check;

  const _CheckRow({required this.check});

  @override
  Widget build(BuildContext context) {
    final (icon, color) = switch (check.ok) {
      true => (Icons.check_circle_rounded, VoyagoColors.primary),
      false => (Icons.cancel_rounded, VoyagoColors.coral),
      null => (Icons.radio_button_unchecked_rounded, VoyagoColors.muted),
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(check.label,
                    style: const TextStyle(color: VoyagoColors.text, fontSize: 13, fontWeight: FontWeight.w600)),
                if (check.detail != null && check.detail!.isNotEmpty)
                  Text(check.detail!,
                      style: TextStyle(color: check.ok == false ? VoyagoColors.coral : VoyagoColors.muted, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Petites pastilles des conditions (carte de la liste des cercles).
class JoinRuleChips extends StatelessWidget {
  final JoinRules rules;

  /// Nombre de membres actuel : affiche « 18/30 places » au lieu de « 30 places »
  final int? membersCount;

  const JoinRuleChips({super.key, required this.rules, this.membersCount});

  @override
  Widget build(BuildContext context) {
    final chips = [
      for (final c in rules.chips)
        if (rules.maxMembers != null && membersCount != null && c == '${rules.maxMembers} places')
          '$membersCount/${rules.maxMembers} places'
        else
          c,
    ];
    if (chips.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final c in chips)
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: VoyagoColors.yellow.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: VoyagoColors.yellow.withValues(alpha: 0.35)),
            ),
            child: Text(c, style: const TextStyle(color: VoyagoColors.yellow, fontSize: 10.5, fontWeight: FontWeight.w700)),
          ),
      ],
    );
  }
}

// =============================================================================
// Demande d'adhésion (voyageur)
// =============================================================================

/// Ouvre la demande d'adhésion d'un cercle privé (ou annule une demande en attente).
Future<void> requestToJoinCircle(BuildContext context, WidgetRef ref, CommunityCircle circle) async {
  final messenger = ScaffoldMessenger.of(context);
  if (ref.read(currentUserProvider) == null) {
    messenger.showSnackBar(const SnackBar(
      backgroundColor: VoyagoColors.orange,
      content: Text('Connecte-toi pour demander à rejoindre ce cercle'),
    ));
    return;
  }
  if (circle.hasPendingRequest) {
    await _confirmCancelRequest(context, ref, circle);
    return;
  }
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _JoinRequestSheet(circle: circle),
  );
}

Future<void> _confirmCancelRequest(BuildContext context, WidgetRef ref, CommunityCircle circle) async {
  final messenger = ScaffoldMessenger.of(context);
  final cancel = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: VoyagoColors.surface,
      title: const Text('Demande en attente', style: TextStyle(color: VoyagoColors.text)),
      content: Text(
        'Ta demande pour « ${circle.name} » attend la réponse du fondateur. Veux-tu l\'annuler ?',
        style: const TextStyle(color: VoyagoColors.muted),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Garder')),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Annuler la demande', style: TextStyle(color: VoyagoColors.coral)),
        ),
      ],
    ),
  );
  if (cancel != true) return;
  try {
    await ref.read(communityControllerProvider).cancelJoinRequest(circle.id);
    messenger.showSnackBar(const SnackBar(content: Text('Demande annulée')));
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)));
  }
}

class _JoinRequestSheet extends ConsumerStatefulWidget {
  final CommunityCircle circle;

  const _JoinRequestSheet({required this.circle});

  @override
  ConsumerState<_JoinRequestSheet> createState() => _JoinRequestSheetState();
}

class _JoinRequestSheetState extends ConsumerState<_JoinRequestSheet> {
  final _message = TextEditingController();
  bool _sending = false;
  List<JoinCheck>? _refusedChecks;

  @override
  void dispose() {
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    setState(() => _sending = true);
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    try {
      final result = await ref
          .read(communityControllerProvider)
          .requestJoin(widget.circle.id, message: _message.text);
      if (!mounted) return;
      switch (result.status) {
        case 'refused':
          // Refus automatique : on montre ce qui manque, sans fermer
          setState(() {
            _sending = false;
            _refusedChecks = result.checks;
          });
          return;
        case 'joined':
        case 'member':
          Navigator.pop(context);
          messenger.showSnackBar(SnackBar(
            backgroundColor: VoyagoColors.primary,
            content: Text(result.message.isNotEmpty ? result.message : '🎉 Bienvenue dans la tribu !'),
          ));
          router.go('/circle/${widget.circle.id}');
        default:
          Navigator.pop(context);
          messenger.showSnackBar(SnackBar(
            backgroundColor: result.status == 'pending' ? VoyagoColors.surface : VoyagoColors.orange,
            content: Text(result.message),
          ));
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() => _sending = false);
      messenger.showSnackBar(SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final circle = widget.circle;
    final checks = _refusedChecks ?? circle.joinChecks;
    final blocked = _refusedChecks != null || checks.any((c) => c.ok == false);

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        decoration: const BoxDecoration(
          color: VoyagoColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: VoyagoColors.cardBorder, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                _CircleShowcase(circle: circle),
                const SizedBox(height: 16),
                JoinConditionsCard(checks: checks, autoApprove: circle.autoApprove, compact: true),
                const SizedBox(height: 14),
                if (blocked)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: VoyagoColors.coral.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: VoyagoColors.coral.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      refusalAdvice(checks),
                      style: const TextStyle(color: VoyagoColors.text, fontSize: 12.5, height: 1.4),
                    ),
                  )
                else ...[
                  if (circle.joinQuestion.isNotEmpty) ...[
                    Text('❓ ${circle.joinQuestion}',
                        style: const TextStyle(color: VoyagoColors.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                    const SizedBox(height: 8),
                  ],
                  TextField(
                    controller: _message,
                    maxLength: 500,
                    minLines: 2,
                    maxLines: 5,
                    style: const TextStyle(color: VoyagoColors.text, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: circle.joinQuestion.isNotEmpty
                          ? 'Ta réponse…'
                          : 'Présente-toi en quelques mots (facultatif)',
                      hintStyle: const TextStyle(color: VoyagoColors.muted),
                      filled: true,
                      fillColor: VoyagoColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                ],
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: blocked || _sending ? null : _send,
                    icon: _sending
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.send_rounded, size: 18),
                    label: Text(
                      blocked ? 'Conditions non remplies' : 'Envoyer ma demande',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VoyagoColors.primary,
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: VoyagoColors.cardBorder,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      final host = Navigator.of(context, rootNavigator: true).context;
                      Navigator.pop(context);
                      joinCircleWithCode(host, ref);
                    },
                    icon: const Icon(Icons.vpn_key_rounded, size: 17, color: VoyagoColors.primary),
                    label: const Text("J'ai un code d'invitation",
                        style: TextStyle(color: VoyagoColors.primary, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Bouton d'adhésion d'un cercle privé selon l'état de ma demande.
class JoinRequestButton extends ConsumerWidget {
  final CommunityCircle circle;
  final bool dense;

  const JoinRequestButton({super.key, required this.circle, this.dense = false});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (label, icon, color) = switch (circle.myRequestStatus) {
      'pending' => ('Demande envoyée', Icons.hourglass_top_rounded, VoyagoColors.yellow),
      'rejected' => ('Demande refusée', Icons.block_rounded, VoyagoColors.muted),
      _ => (dense ? 'Demander' : 'Demander à rejoindre', Icons.lock_open_rounded, VoyagoColors.primary),
    };
    final enabled = circle.myRequestStatus != 'rejected';
    final filled = circle.myRequestStatus == null;

    return ElevatedButton.icon(
      onPressed: enabled ? () => requestToJoinCircle(context, ref, circle) : null,
      icon: Icon(icon, size: dense ? 14 : 18),
      label: Text(label, style: TextStyle(fontSize: dense ? 12 : 14, fontWeight: FontWeight.bold)),
      style: ElevatedButton.styleFrom(
        backgroundColor: filled ? color : color.withValues(alpha: 0.15),
        foregroundColor: filled ? Colors.white : color,
        disabledBackgroundColor: VoyagoColors.cardBorder,
        disabledForegroundColor: VoyagoColors.muted,
        padding: dense ? const EdgeInsets.symmetric(horizontal: 12, vertical: 8) : const EdgeInsets.symmetric(vertical: 14),
        minimumSize: Size.zero,
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(dense ? 12 : 16),
          side: filled ? BorderSide.none : BorderSide(color: color.withValues(alpha: 0.5)),
        ),
        elevation: 0,
      ),
    );
  }
}

// =============================================================================
// Cercle privé (non-membre) : il ne s'ouvre pas, seule la fenêtre de demande apparaît
// =============================================================================

/// Lien direct vers un cercle privé (notification, partage...) : on n'ouvre pas le cercle,
/// on affiche la fenêtre de demande puis on revient en arrière.
class LockedCircleGate extends ConsumerStatefulWidget {
  final CommunityCircle circle;

  const LockedCircleGate({super.key, required this.circle});

  @override
  ConsumerState<LockedCircleGate> createState() => _LockedCircleGateState();
}

class _LockedCircleGateState extends ConsumerState<LockedCircleGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      await requestToJoinCircle(context, ref, widget.circle);
      if (!mounted) return;
      // Entré entre-temps (code, acceptation auto) : la page du cercle s'affiche normalement
      if (ref.read(circleDetailProvider(widget.circle.id)).valueOrNull?.isLocked == false) return;
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/community');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: VoyagoColors.background,
      alignment: Alignment.center,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: VoyagoColors.surface,
              shape: BoxShape.circle,
              border: Border.all(color: VoyagoColors.cardBorder),
            ),
            child: const Icon(Icons.lock_rounded, color: VoyagoColors.muted, size: 36),
          ),
          const SizedBox(height: 14),
          const Text('Cercle privé', style: TextStyle(color: VoyagoColors.muted, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

/// Vitrine d'un cercle privé dans la fenêtre de demande (sans son contenu ni ses membres).
class _CircleShowcase extends StatelessWidget {
  final CommunityCircle circle;

  const _CircleShowcase({required this.circle});

  @override
  Widget build(BuildContext context) {
    final founder = (circle.creator?['pseudo'] ?? circle.creator?['name'])?.toString();
    final quota = circle.joinRules.maxMembers;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: SizedBox(
            height: 110,
            width: double.infinity,
            child: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: circle.coverImageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: VoyagoColors.cardBorder),
                ),
                Container(color: Colors.black.withValues(alpha: 0.5)),
                Positioned(
                  left: 14,
                  bottom: 12,
                  right: 14,
                  child: Row(
                    children: [
                      Text(circle.avatarEmoji, style: const TextStyle(fontSize: 28)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(circle.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w800)),
                      ),
                      const Icon(Icons.lock_rounded, color: Colors.white70, size: 20),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 12,
          runSpacing: 4,
          children: [
            _Meta(
              icon: Icons.group_rounded,
              label: quota != null
                  ? '${circle.membersCount}/$quota membres'
                  : '${circle.membersCount} membre${circle.membersCount > 1 ? 's' : ''}',
            ),
            _Meta(icon: Icons.location_on_rounded, label: circle.locationDisplay),
            if (founder != null) _Meta(icon: Icons.workspace_premium_rounded, label: 'Fondé par $founder'),
          ],
        ),
        if (circle.description.isNotEmpty) ...[
          const SizedBox(height: 8),
          Text(circle.description,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: VoyagoColors.muted, fontSize: 13, height: 1.4)),
        ],
        const SizedBox(height: 6),
        const Text(
          '🔒 Voyages, moments et membres visibles une fois dans la tribu.',
          style: TextStyle(color: VoyagoColors.muted, fontSize: 11.5),
        ),
      ],
    );
  }
}

class _Meta extends StatelessWidget {
  final IconData icon;
  final String label;

  const _Meta({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: VoyagoColors.muted),
        const SizedBox(width: 4),
        Text(label, style: const TextStyle(color: VoyagoColors.muted, fontSize: 12.5, fontWeight: FontWeight.w600)),
      ],
    );
  }
}

/// Rejoindre avec un code d'invitation (refus éventuel affiché dans une belle fenêtre).
Future<void> joinCircleWithCode(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  final router = GoRouter.of(context);
  if (ref.read(currentUserProvider) == null) {
    messenger.showSnackBar(const SnackBar(
      backgroundColor: VoyagoColors.orange,
      content: Text('Connecte-toi pour rejoindre un cercle'),
    ));
    return;
  }
  final code = await showDialog<String>(context: context, builder: (_) => const _InviteCodeDialog());
  if (code == null || code.trim().isEmpty || !context.mounted) return;
  try {
    final circleId = await ref.read(communityControllerProvider).joinCircleByCode(code);
    messenger.showSnackBar(const SnackBar(
      backgroundColor: VoyagoColors.primary,
      content: Text('🎉 Bienvenue dans ta nouvelle tribu !'),
    ));
    if (circleId.isNotEmpty) router.go('/circle/$circleId');
  } on ApiException catch (e) {
    if (!context.mounted) return;
    if (!await showJoinRefusalIfNeeded(context, e)) {
      messenger.showSnackBar(SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)));
    }
  }
}

// =============================================================================
// Refus d'entrée : fenêtre claire (mineurs, places, niveau...)
// =============================================================================

/// Conseil adapté à ce qui manque pour entrer.
String refusalAdvice(List<JoinCheck> checks) {
  final failed = checks.where((c) => c.ok == false).map((c) => c.key).toSet();
  if (failed.contains('min_age')) {
    return "Ce cercle est réservé aux voyageurs plus âgés. Ta sécurité compte : d'autres tribus t'attendent dans la communauté !";
  }
  if (failed.contains('max_members')) return 'Ce cercle est complet pour le moment. Repasse plus tard, une place se libérera peut-être !';
  if (failed.contains('min_level')) return "Gagne de l'XP en voyageant, en notant des lieux et en partageant tes aventures… et reviens !";
  if (failed.contains('verified_email')) return 'Vérifie ton adresse e-mail depuis ton profil, puis renvoie ta demande.';
  if (failed.contains('pro_only')) return 'Ce cercle est réservé aux membres Voyagooo Pro.';
  return "Tu ne remplis pas encore toutes les conditions d'accès de ce cercle.";
}

/// Affiche la fenêtre de refus si l'erreur vient des conditions d'accès. Renvoie true si affichée.
Future<bool> showJoinRefusalIfNeeded(BuildContext context, Object error) async {
  if (error is! ApiException) return false;
  final details = error.details;
  if (details is! Map || details['code'] != 'JOIN_CONDITIONS') return false;
  final checks = JoinCheck.listFrom(details['join_checks']);
  final underAge = details['under_age'] == true;
  final circleName = details['circle_name']?.toString();
  await showDialog<void>(
    context: context,
    builder: (ctx) => _JoinRefusalDialog(
      underAge: underAge,
      circleName: circleName,
      message: error.message,
      checks: checks,
    ),
  );
  return true;
}

class _JoinRefusalDialog extends StatelessWidget {
  final bool underAge;
  final String? circleName;
  final String message;
  final List<JoinCheck> checks;

  const _JoinRefusalDialog({required this.underAge, this.circleName, required this.message, required this.checks});

  @override
  Widget build(BuildContext context) {
    final failed = checks.where((c) => c.ok == false).toList();
    final accent = underAge ? VoyagoColors.orange : VoyagoColors.coral;
    return Dialog(
      backgroundColor: VoyagoColors.surface,
      insetPadding: const EdgeInsets.symmetric(horizontal: 28),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(22, 26, 22, 18),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.6, end: 1),
              duration: const Duration(milliseconds: 500),
              curve: Curves.elasticOut,
              builder: (_, scale, child) => Transform.scale(scale: scale, child: child),
              child: Container(
                width: 84,
                height: 84,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accent.withValues(alpha: 0.14),
                  border: Border.all(color: accent.withValues(alpha: 0.45), width: 2),
                ),
                child: Text(underAge ? '🔞' : '🔒', style: const TextStyle(fontSize: 38)),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              underAge ? 'Réservé aux majeurs' : 'Accès impossible pour le moment',
              textAlign: TextAlign.center,
              style: const TextStyle(color: VoyagoColors.text, fontSize: 19, fontWeight: FontWeight.w800),
            ),
            if (circleName != null) ...[
              const SizedBox(height: 4),
              Text('« $circleName »',
                  textAlign: TextAlign.center, style: const TextStyle(color: VoyagoColors.muted, fontSize: 13)),
            ],
            const SizedBox(height: 12),
            Text(
              underAge
                  ? "$message. Même avec un code d'invitation, l'âge minimum s'applique pour protéger tous les voyageurs."
                  : refusalAdvice(checks),
              textAlign: TextAlign.center,
              style: const TextStyle(color: VoyagoColors.text, fontSize: 13.5, height: 1.45),
            ),
            if (failed.isNotEmpty && !underAge) ...[
              const SizedBox(height: 14),
              for (final c in failed) _CheckRow(check: c),
            ],
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: VoyagoColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 0,
                ),
                child: Text(underAge ? "D'accord, j'explore ailleurs" : 'Compris',
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Saisie d'un code d'invitation (StatefulWidget : le contrôleur vit autant que le dialogue).
class _InviteCodeDialog extends StatefulWidget {
  const _InviteCodeDialog();

  @override
  State<_InviteCodeDialog> createState() => _InviteCodeDialogState();
}

class _InviteCodeDialogState extends State<_InviteCodeDialog> {
  final _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VoyagoColors.surface,
      title: const Text("Code d'invitation", style: TextStyle(color: VoyagoColors.text)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        style: const TextStyle(color: VoyagoColors.text, letterSpacing: 3, fontWeight: FontWeight.w700),
        decoration: const InputDecoration(hintText: 'EX : K7P2QXMR', hintStyle: TextStyle(color: VoyagoColors.muted)),
        onSubmitted: (v) => Navigator.pop(context, v),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.pop(context, _controller.text), child: const Text('Rejoindre')),
      ],
    );
  }
}

// =============================================================================
// Gestion des accès (fondateur / admins)
// =============================================================================

/// Carte du fondateur : demandes en attente et réglages d'accès.
class CircleAccessManagerCard extends StatelessWidget {
  final CommunityCircle circle;

  const CircleAccessManagerCard({super.key, required this.circle});

  @override
  Widget build(BuildContext context) {
    final pending = circle.pendingRequestsCount;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pending > 0 ? VoyagoColors.yellow.withValues(alpha: 0.5) : VoyagoColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.admin_panel_settings_rounded, size: 18, color: VoyagoColors.yellow),
              SizedBox(width: 8),
              Expanded(
                child: Text('Accès à ta tribu',
                    style: TextStyle(color: VoyagoColors.text, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
            ],
          ),
          const SizedBox(height: 10),
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () => showCircleAccessSettingsSheet(context, circle),
            child: QuotaBar(members: circle.membersCount, quota: circle.joinRules.maxMembers),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              if (!circle.isPublic) ...[
                Expanded(
                  child: _ManagerButton(
                    icon: Icons.person_add_alt_1_rounded,
                    label: pending > 0 ? 'Demandes ($pending)' : 'Demandes',
                    highlight: pending > 0,
                    onTap: () => showJoinRequestsSheet(context, circle),
                  ),
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: _ManagerButton(
                  icon: Icons.tune_rounded,
                  label: 'Conditions',
                  onTap: () => showCircleAccessSettingsSheet(context, circle),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ManagerButton(
                  icon: Icons.confirmation_number_rounded,
                  label: 'Invitations',
                  onTap: () => showCircleInvitesSheet(context, circle),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _ManagerButton(
                  icon: Icons.groups_rounded,
                  label: 'Membres',
                  onTap: () => showCircleMembersSheet(context, circle),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Membre (non gestionnaire) : demandes en attente à parrainer.
class SponsorRequestsCard extends StatelessWidget {
  final CommunityCircle circle;

  const SponsorRequestsCard({super.key, required this.circle});

  @override
  Widget build(BuildContext context) {
    final n = circle.pendingRequestsCount;
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: () => showJoinRequestsSheet(context, circle),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: VoyagoColors.blue.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VoyagoColors.blue.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            const Text('🤝', style: TextStyle(fontSize: 22)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('$n voyageur${n > 1 ? 's' : ''} veu${n > 1 ? 'lent' : 't'} rejoindre la tribu',
                      style: const TextStyle(color: VoyagoColors.text, fontSize: 13.5, fontWeight: FontWeight.w700)),
                  const Text('Tu en connais un ? Porte-toi garant pour l\'aider à entrer.',
                      style: TextStyle(color: VoyagoColors.muted, fontSize: 12)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: VoyagoColors.muted),
          ],
        ),
      ),
    );
  }
}

/// Bandeau de période de découverte (nouveau membre en lecture seule).
class TrialBanner extends StatelessWidget {
  final DateTime until;

  const TrialBanner({super.key, required this.until});

  @override
  Widget build(BuildContext context) {
    final d = until;
    final date = '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoyagoColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VoyagoColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          const Text('🌱', style: TextStyle(fontSize: 22)),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Période de découverte jusqu\'au $date : explore les voyages et les moments de la tribu. '
              'Tu pourras publier et commenter ensuite.',
              style: const TextStyle(color: VoyagoColors.text, fontSize: 12.5, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quota de membres : jauge (quota fixé) ou « libre ».
class QuotaBar extends StatelessWidget {
  final int members;
  final int? quota;

  const QuotaBar({super.key, required this.members, this.quota});

  @override
  Widget build(BuildContext context) {
    final q = quota;
    final ratio = q == null || q == 0 ? 0.0 : (members / q).clamp(0.0, 1.0);
    final color = ratio >= 1 ? VoyagoColors.coral : (ratio >= 0.8 ? VoyagoColors.orange : VoyagoColors.primary);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.groups_rounded, size: 16, color: VoyagoColors.muted),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  q == null
                      ? '$members membre${members > 1 ? 's' : ''} · quota libre'
                      : '$members / $q membres${members >= q ? ' · complet' : ' · ${q - members} place${q - members > 1 ? 's' : ''}'}',
                  style: const TextStyle(color: VoyagoColors.text, fontSize: 12.5, fontWeight: FontWeight.w600),
                ),
              ),
              const Icon(Icons.edit_rounded, size: 14, color: VoyagoColors.muted),
            ],
          ),
          if (q != null) ...[
            const SizedBox(height: 6),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 5,
                backgroundColor: VoyagoColors.cardBorder,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ManagerButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool highlight;
  final VoidCallback onTap;

  const _ManagerButton({required this.icon, required this.label, required this.onTap, this.highlight = false});

  @override
  Widget build(BuildContext context) {
    final color = highlight ? VoyagoColors.yellow : VoyagoColors.primary;
    return OutlinedButton.icon(
      onPressed: onTap,
      icon: Icon(icon, size: 17, color: color),
      label: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
      style: OutlinedButton.styleFrom(
        backgroundColor: color.withValues(alpha: highlight ? 0.12 : 0.06),
        side: BorderSide(color: color.withValues(alpha: 0.45)),
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    );
  }
}

// ----------------------------------------------------------------------------- Demandes reçues

Future<void> showJoinRequestsSheet(BuildContext context, CommunityCircle circle) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => _JoinRequestsSheet(circle: circle, scrollController: scroll),
    ),
  );
}

class _JoinRequestsSheet extends ConsumerWidget {
  final CommunityCircle circle;
  final ScrollController scrollController;

  const _JoinRequestsSheet({required this.circle, required this.scrollController});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(circleJoinRequestsProvider(circle.id));
    return Container(
      decoration: const BoxDecoration(
        color: VoyagoColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: VoyagoColors.cardBorder, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Row(
              children: [
                const Icon(Icons.person_add_alt_1_rounded, color: VoyagoColors.yellow),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                      (async.valueOrNull?.canDecide ?? circle.canManage)
                          ? 'Demandes · ${circle.name}'
                          : 'Parrainer · ${circle.name}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: VoyagoColors.text, fontSize: 17, fontWeight: FontWeight.w800)),
                ),
              ],
            ),
          ),
          Expanded(
            child: async.when(
              loading: () => const Center(child: CircularProgressIndicator(color: VoyagoColors.primary)),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(e.toString(), textAlign: TextAlign.center, style: const TextStyle(color: VoyagoColors.muted)),
                ),
              ),
              data: (data) {
                if (data.requests.isEmpty) {
                  return const Center(
                    child: Padding(
                      padding: EdgeInsets.all(32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('📭', style: TextStyle(fontSize: 42)),
                          SizedBox(height: 10),
                          Text('Aucune demande en attente',
                              style: TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w700)),
                          SizedBox(height: 4),
                          Text('Tu seras notifié à chaque nouvelle demande.',
                              style: TextStyle(color: VoyagoColors.muted, fontSize: 12.5)),
                        ],
                      ),
                    ),
                  );
                }
                return ListView.separated(
                  controller: scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  itemCount: data.requests.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (_, i) =>
                      _JoinRequestCard(
                    circle: circle,
                    request: data.requests[i],
                    question: data.question,
                    canDecide: data.canDecide,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _JoinRequestCard extends ConsumerStatefulWidget {
  final CommunityCircle circle;
  final JoinRequest request;
  final String question;

  final bool canDecide;

  const _JoinRequestCard({required this.circle, required this.request, required this.question, this.canDecide = true});

  @override
  ConsumerState<_JoinRequestCard> createState() => _JoinRequestCardState();
}

class _JoinRequestCardState extends ConsumerState<_JoinRequestCard> {
  bool? _deciding; // true = accepter, false = refuser
  bool _vouching = false;

  Future<void> _toggleVouch() async {
    setState(() => _vouching = true);
    final messenger = ScaffoldMessenger.of(context);
    final on = !widget.request.iVouched;
    try {
      await ref
          .read(communityControllerProvider)
          .vouchJoinRequest(circleId: widget.circle.id, requestId: widget.request.id, on: on);
      messenger.showSnackBar(SnackBar(
        backgroundColor: on ? VoyagoColors.primary : VoyagoColors.surface,
        content: Text(on
            ? '🤝 Tu te portes garant de ${widget.request.user.displayName}'
            : 'Parrainage retiré'),
      ));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _vouching = false);
    }
  }

  Future<void> _decide(bool accept) async {
    setState(() => _deciding = accept);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(communityControllerProvider).decideJoinRequest(
            circleId: widget.circle.id,
            requestId: widget.request.id,
            accept: accept,
          );
      messenger.showSnackBar(SnackBar(
        backgroundColor: accept ? VoyagoColors.primary : VoyagoColors.surface,
        content: Text(accept
            ? '🎉 ${widget.request.user.displayName} a rejoint la tribu'
            : 'Demande de ${widget.request.user.displayName} refusée'),
      ));
    } on ApiException catch (e) {
      if (mounted) setState(() => _deciding = null);
      messenger.showSnackBar(SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final u = r.user;
    final missing = r.checks.where((c) => c.ok == false).toList();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: VoyagoColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context.push('/user/${u.userId}'),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 24,
                  backgroundColor: VoyagoColors.cardBorder,
                  backgroundImage: u.picture != null && u.picture!.isNotEmpty ? CachedNetworkImageProvider(u.picture!) : null,
                  child: u.picture != null && u.picture!.isNotEmpty
                      ? null
                      : Text(u.avatarEmoji, style: const TextStyle(fontSize: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(u.displayName,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(color: VoyagoColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
                          ),
                          if (u.emailVerified) ...[
                            const SizedBox(width: 4),
                            const Icon(Icons.verified_rounded, size: 15, color: VoyagoColors.blue),
                          ],
                          if (u.isPro) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                              decoration: BoxDecoration(
                                color: VoyagoColors.yellow.withValues(alpha: 0.18),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Text('PRO',
                                  style: TextStyle(color: VoyagoColors.yellow, fontSize: 9.5, fontWeight: FontWeight.w900)),
                            ),
                          ],
                        ],
                      ),
                      Text(
                        [
                          if (u.age != null) '${u.age} ans',
                          if (u.location != null) u.location!,
                        ].join(' · ').ifEmpty('Voir le profil'),
                        style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: VoyagoColors.muted),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              _ProfileStat(value: 'Niv. ${u.level}', label: '${u.xp} XP', color: VoyagoColors.primary),
              _ProfileStat(value: '${u.tripsCount}', label: 'voyages', color: VoyagoColors.blue),
              _ProfileStat(value: '${u.badgesCount}', label: 'badges', color: VoyagoColors.yellow),
              if (u.memberSince != null)
                _ProfileStat(
                  value: '${u.memberSince!.year}',
                  label: 'membre depuis',
                  color: VoyagoColors.muted,
                ),
            ],
          ),
          if (r.message.isNotEmpty) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: VoyagoColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (widget.question.isNotEmpty)
                    Text('❓ ${widget.question}',
                        style: const TextStyle(color: VoyagoColors.muted, fontSize: 11.5, fontWeight: FontWeight.w600)),
                  Text('« ${r.message} »',
                      style: const TextStyle(color: VoyagoColors.text, fontSize: 13, height: 1.4, fontStyle: FontStyle.italic)),
                ],
              ),
            ),
          ],
          if (missing.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              '⚠️ Ne remplit plus : ${missing.map((c) => c.label).join(', ')}',
              style: const TextStyle(color: VoyagoColors.coral, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
          if (r.vouches.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: VoyagoColors.blue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '🤝 Parrainé par ${r.vouches.take(3).map((v) => '${v.emoji} ${v.name}').join(', ')}'
                '${r.vouches.length > 3 ? ' et ${r.vouches.length - 3} autre${r.vouches.length - 3 > 1 ? 's' : ''}' : ''}',
                style: const TextStyle(color: VoyagoColors.blue, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            ),
          ],
          const SizedBox(height: 12),
          if (!widget.canDecide)
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _vouching ? null : _toggleVouch,
                icon: Text(r.iVouched ? '✅' : '🤝', style: const TextStyle(fontSize: 16)),
                label: Text(r.iVouched ? 'Tu es son garant · retirer' : 'Je me porte garant',
                    style: TextStyle(
                        color: r.iVouched ? VoyagoColors.muted : VoyagoColors.blue, fontWeight: FontWeight.w700)),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: VoyagoColors.blue.withValues(alpha: 0.5)),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
              ),
            )
          else
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _deciding != null ? null : () => _decide(false),
                  style: OutlinedButton.styleFrom(
                    side: BorderSide(color: VoyagoColors.coral.withValues(alpha: 0.6)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _deciding == false
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: VoyagoColors.coral))
                      : const Text('Refuser', style: TextStyle(color: VoyagoColors.coral, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: _deciding != null ? null : () => _decide(true),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VoyagoColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    elevation: 0,
                  ),
                  child: _deciding == true
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                      : const Text('Accepter', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProfileStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _ProfileStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          Text(value, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w800)),
          Text(label, style: const TextStyle(color: VoyagoColors.muted, fontSize: 10.5)),
        ],
      ),
    );
  }
}

extension on String {
  String ifEmpty(String fallback) => isEmpty ? fallback : this;
}

// ----------------------------------------------------------------------------- Réglages d'accès

Future<void> showCircleAccessSettingsSheet(BuildContext context, CommunityCircle circle) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _AccessSettingsSheet(circle: circle),
  );
}

class _AccessSettingsSheet extends ConsumerStatefulWidget {
  final CommunityCircle circle;

  const _AccessSettingsSheet({required this.circle});

  @override
  ConsumerState<_AccessSettingsSheet> createState() => _AccessSettingsSheetState();
}

class _AccessSettingsSheetState extends ConsumerState<_AccessSettingsSheet> {
  static const _levels = [null, 2, 3, 5, 8, 10, 15, 20];
  static const _ages = [null, 16, 18, 21, 25, 30, 40];
  static const _places = [null, 5, 10, 15, 20, 30, 50, 100];

  /// Valeur « Personnalisé… » de la liste des quotas (jamais envoyée au serveur)
  static const _customQuota = -1;

  Future<int?> _askCustomQuota() => showDialog<int>(context: context, builder: (_) => const _CustomQuotaDialog());

  late JoinRules _rules = widget.circle.joinRules;
  late bool _autoApprove = widget.circle.autoApprove;
  late bool _listed = widget.circle.listed;
  late int _trialDays = widget.circle.trialDays;
  late final TextEditingController _question = TextEditingController(text: widget.circle.joinQuestion);
  bool _saving = false;

  @override
  void dispose() {
    _question.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(communityControllerProvider).updateCircleAccess(
            widget.circle.id,
            rules: _rules,
            autoApprove: _autoApprove,
            joinQuestion: _question.text,
            listed: widget.circle.isPublic ? null : _listed,
            trialDays: _trialDays,
          );
      if (!mounted) return;
      Navigator.pop(context);
      messenger.showSnackBar(const SnackBar(
        backgroundColor: VoyagoColors.primary,
        content: Text("✅ Conditions d'accès enregistrées"),
      ));
    } on ApiException catch (e) {
      if (mounted) setState(() => _saving = false);
      messenger.showSnackBar(SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final isPrivate = !widget.circle.isPublic;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: Container(
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.9),
        decoration: const BoxDecoration(
          color: VoyagoColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        child: SafeArea(
          top: false,
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(color: VoyagoColors.cardBorder, borderRadius: BorderRadius.circular(2)),
                  ),
                ),
                const SizedBox(height: 16),
                const Text("Conditions d'accès",
                    style: TextStyle(color: VoyagoColors.text, fontSize: 19, fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                const Text(
                  'Facultatives. Le système refuse automatiquement les voyageurs qui ne les remplissent pas.',
                  style: TextStyle(color: VoyagoColors.muted, fontSize: 12.5, height: 1.4),
                ),
                const SizedBox(height: 16),
                _SelectRow<int?>(
                  icon: Icons.military_tech_rounded,
                  label: "Niveau d'explorateur minimum",
                  value: _rules.minLevel,
                  options: _levels,
                  display: (v) => v == null ? 'Aucun' : 'Niveau $v+',
                  onChanged: (v) => setState(() => _rules = _rules.copyWith(minLevel: () => v)),
                ),
                _SelectRow<int?>(
                  icon: Icons.cake_rounded,
                  label: 'Âge minimum',
                  value: _rules.minAge,
                  options: _ages,
                  display: (v) => v == null ? 'Aucun' : '$v ans et +',
                  onChanged: (v) => setState(() => _rules = _rules.copyWith(minAge: () => v)),
                ),
                _SelectRow<int?>(
                  icon: Icons.event_seat_rounded,
                  label: 'Quota de membres',
                  value: _rules.maxMembers,
                  options: const [..._places, _customQuota],
                  display: (v) => v == null
                      ? 'Libre'
                      : v == _customQuota
                          ? 'Personnalisé…'
                          : '$v max.',
                  onChanged: (v) async {
                    if (v == _customQuota) {
                      final custom = await _askCustomQuota();
                      if (custom != null) setState(() => _rules = _rules.copyWith(maxMembers: () => custom));
                    } else {
                      setState(() => _rules = _rules.copyWith(maxMembers: () => v));
                    }
                  },
                ),
                if (_rules.maxMembers != null && _rules.maxMembers! < widget.circle.membersCount)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      'Le cercle compte déjà ${widget.circle.membersCount} membres : personne n\'est retiré, '
                      'mais plus aucune entrée tant qu\'il y a plus de ${_rules.maxMembers} membres.',
                      style: const TextStyle(color: VoyagoColors.orange, fontSize: 11.5, height: 1.35),
                    ),
                  ),
                _SwitchRow(
                  icon: Icons.workspace_premium_rounded,
                  label: 'Réservé aux membres Pro',
                  value: _rules.proOnly,
                  onChanged: (v) => setState(() => _rules = _rules.copyWith(proOnly: v)),
                ),
                _SwitchRow(
                  icon: Icons.mark_email_read_rounded,
                  label: 'E-mail vérifié obligatoire',
                  value: _rules.verifiedEmail,
                  onChanged: (v) => setState(() => _rules = _rules.copyWith(verifiedEmail: v)),
                ),
                _CountriesRule(
                  countries: _rules.countries,
                  onChanged: (list) => setState(() => _rules = _rules.copyWith(countries: list)),
                ),
                const Divider(color: VoyagoColors.cardBorder, height: 28),
                const Text("Intégration des nouveaux membres",
                    style: TextStyle(color: VoyagoColors.text, fontSize: 15, fontWeight: FontWeight.w800)),
                const SizedBox(height: 10),
                _SelectRow<int>(
                  icon: Icons.spa_rounded,
                  label: 'Période de découverte',
                  value: _trialDays,
                  options: const [0, 1, 3, 7, 14, 30],
                  display: (v) => v == 0 ? 'Aucune' : '$v jour${v > 1 ? 's' : ''}',
                  onChanged: (v) => setState(() => _trialDays = v),
                ),
                if (_trialDays > 0)
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 10),
                    child: Text(
                      'Les nouveaux membres lisent tout mais ne publient, ne partagent et ne commentent qu\'après cette période.',
                      style: TextStyle(color: VoyagoColors.muted, fontSize: 11.5, height: 1.35),
                    ),
                  ),
                if (isPrivate) ...[
                  const Divider(color: VoyagoColors.cardBorder, height: 28),
                  _SwitchRow(
                    icon: Icons.bolt_rounded,
                    label: 'Acceptation automatique',
                    subtitle: 'Entrée immédiate si toutes les conditions sont remplies',
                    value: _autoApprove,
                    onChanged: (v) => setState(() => _autoApprove = v),
                  ),
                  _SwitchRow(
                    icon: Icons.visibility_off_rounded,
                    label: 'Cercle secret',
                    subtitle: 'Invisible dans la liste : accès uniquement avec le code',
                    value: !_listed,
                    onChanged: (v) => setState(() => _listed = !v),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _question,
                    maxLength: 200,
                    style: const TextStyle(color: VoyagoColors.text, fontSize: 14),
                    decoration: InputDecoration(
                      labelText: "Question d'entrée (facultative)",
                      labelStyle: const TextStyle(color: VoyagoColors.muted),
                      hintText: 'Ex : Quel est ton plus beau souvenir de voyage ?',
                      hintStyle: const TextStyle(color: VoyagoColors.muted, fontSize: 13),
                      filled: true,
                      fillColor: VoyagoColors.surface,
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
                    ),
                  ),
                ],
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VoyagoColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      elevation: 0,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Enregistrer', style: TextStyle(fontWeight: FontWeight.w800)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Pays autorisés : pastilles + ajout via la liste des pays.
class _CountriesRule extends StatelessWidget {
  final List<String> countries;
  final ValueChanged<List<String>> onChanged;

  const _CountriesRule({required this.countries, required this.onChanged});

  Future<void> _add(BuildContext context) async {
    final picked = await pickCountry(context);
    if (picked == null || picked.trim().isEmpty) return;
    if (countries.any((c) => c.toLowerCase() == picked.toLowerCase())) return;
    onChanged([...countries, picked]);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(color: VoyagoColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public_rounded, size: 19, color: VoyagoColors.primary),
              const SizedBox(width: 10),
              const Expanded(
                child: Text('Pays autorisés', style: TextStyle(color: VoyagoColors.text, fontSize: 13.5)),
              ),
              Text(countries.isEmpty ? 'Tous' : '${countries.length} pays',
                  style: const TextStyle(color: VoyagoColors.primary, fontWeight: FontWeight.w700, fontSize: 13.5)),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final c in countries)
                InputChip(
                  label: Text(c, style: const TextStyle(color: VoyagoColors.text, fontSize: 12)),
                  backgroundColor: VoyagoColors.background,
                  side: const BorderSide(color: VoyagoColors.cardBorder),
                  deleteIconColor: VoyagoColors.muted,
                  onDeleted: () => onChanged(countries.where((x) => x != c).toList()),
                ),
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 16, color: VoyagoColors.primary),
                label: const Text('Ajouter un pays',
                    style: TextStyle(color: VoyagoColors.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                backgroundColor: VoyagoColors.primary.withValues(alpha: 0.08),
                side: BorderSide(color: VoyagoColors.primary.withValues(alpha: 0.4)),
                onPressed: () => _add(context),
              ),
            ],
          ),
          if (countries.isNotEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 6),
              child: Text("D'après le pays indiqué dans le profil du voyageur.",
                  style: TextStyle(color: VoyagoColors.muted, fontSize: 11)),
            ),
        ],
      ),
    );
  }
}

class _CustomQuotaDialog extends StatefulWidget {
  const _CustomQuotaDialog();

  @override
  State<_CustomQuotaDialog> createState() => _CustomQuotaDialogState();
}

class _CustomQuotaDialogState extends State<_CustomQuotaDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final value = int.tryParse(_controller.text.trim());
    if (value == null || value < 2 || value > 10000) {
      setState(() => _error = 'Entre un nombre entre 2 et 10 000');
      return;
    }
    Navigator.pop(context, value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VoyagoColors.surface,
      title: const Text('Quota de membres', style: TextStyle(color: VoyagoColors.text)),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: TextInputType.number,
        style: const TextStyle(color: VoyagoColors.text, fontSize: 18, fontWeight: FontWeight.w700),
        decoration: InputDecoration(
          hintText: 'Ex : 12',
          hintStyle: const TextStyle(color: VoyagoColors.muted),
          suffixText: 'membres max.',
          errorText: _error,
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('Annuler')),
        TextButton(onPressed: _submit, child: const Text('Valider')),
      ],
    );
  }
}

class _SelectRow<T> extends StatelessWidget {
  final IconData icon;
  final String label;
  final T value;
  final List<T> options;
  final String Function(T) display;
  final ValueChanged<T> onChanged;

  const _SelectRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.options,
    required this.display,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final items = options.contains(value) ? options : [...options, value];
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: VoyagoColors.surface, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(icon, size: 19, color: VoyagoColors.primary),
            const SizedBox(width: 10),
            Expanded(child: Text(label, style: const TextStyle(color: VoyagoColors.text, fontSize: 13.5))),
            DropdownButton<T>(
              value: value,
              dropdownColor: VoyagoColors.surface,
              underline: const SizedBox.shrink(),
              style: const TextStyle(color: VoyagoColors.primary, fontWeight: FontWeight.w700, fontSize: 13.5),
              items: [for (final o in items) DropdownMenuItem<T>(value: o, child: Text(display(o)))],
              onChanged: (v) => onChanged(v as T),
            ),
          ],
        ),
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  const _SwitchRow({required this.icon, required this.label, this.subtitle, required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
        decoration: BoxDecoration(color: VoyagoColors.surface, borderRadius: BorderRadius.circular(14)),
        child: Row(
          children: [
            Icon(icon, size: 19, color: VoyagoColors.primary),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: VoyagoColors.text, fontSize: 13.5)),
                  if (subtitle != null)
                    Text(subtitle!, style: const TextStyle(color: VoyagoColors.muted, fontSize: 11.5)),
                ],
              ),
            ),
            Switch(value: value, activeThumbColor: VoyagoColors.primary, onChanged: onChanged),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Membres du cercle (réservé aux membres) : profils + gestion par le fondateur
// =============================================================================

Future<void> showCircleMembersSheet(BuildContext context, CommunityCircle circle) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => _CircleMembersSheet(circle: circle, scrollController: scroll),
    ),
  );
}

class _CircleMembersSheet extends ConsumerStatefulWidget {
  final CommunityCircle circle;
  final ScrollController scrollController;

  const _CircleMembersSheet({required this.circle, required this.scrollController});

  @override
  ConsumerState<_CircleMembersSheet> createState() => _CircleMembersSheetState();
}

class _CircleMembersSheetState extends ConsumerState<_CircleMembersSheet> {
  final List<CircleMember> _members = [];
  int _total = 0;
  int? _quota;
  String? _myRole;
  bool _hasMore = true;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.scrollController.addListener(_onScroll);
    _loadMore();
  }

  @override
  void dispose() {
    widget.scrollController.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final position = widget.scrollController.position;
    if (position.pixels > position.maxScrollExtent - 300) _loadMore();
  }

  Future<void> _loadMore() async {
    if (_loading || !_hasMore) return;
    setState(() => _loading = true);
    try {
      final page = await ref.read(communityApiProvider).getCircleMembers(widget.circle.id, skip: _members.length);
      if (!mounted) return;
      setState(() {
        _members.addAll(page.members);
        _total = page.total;
        _quota = page.maxMembers;
        _myRole = page.myRole;
        _hasMore = page.hasMore && page.members.isNotEmpty;
        _loading = false;
        _error = null;
      });
    } on ApiException catch (e) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.message;
        });
      }
    }
  }

  bool _canManage(CircleMember m) {
    if (m.isCreator || _myRole == null) return false;
    if (_myRole == 'creator') return true;
    return _myRole == 'admin' && !m.isAdmin;
  }

  Future<void> _manage(CircleMember m) async {
    final messenger = ScaffoldMessenger.of(context);
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: VoyagoColors.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(Icons.person_rounded, color: VoyagoColors.primary),
              title: Text('Voir le profil de ${m.displayName}', style: const TextStyle(color: VoyagoColors.text)),
              onTap: () => Navigator.pop(ctx, 'profile'),
            ),
            if (_myRole == 'creator')
              ListTile(
                leading: Icon(m.isAdmin ? Icons.remove_moderator_rounded : Icons.add_moderator_rounded,
                    color: VoyagoColors.yellow),
                title: Text(m.isAdmin ? "Retirer le rôle d'admin" : 'Nommer admin',
                    style: const TextStyle(color: VoyagoColors.text)),
                subtitle: const Text('Les admins acceptent les demandes et gèrent les conditions',
                    style: TextStyle(color: VoyagoColors.muted, fontSize: 12)),
                onTap: () => Navigator.pop(ctx, 'role'),
              ),
            ListTile(
              leading: const Icon(Icons.person_remove_rounded, color: VoyagoColors.coral),
              title: const Text('Retirer du cercle', style: TextStyle(color: VoyagoColors.coral)),
              onTap: () => Navigator.pop(ctx, 'remove'),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (!mounted || action == null) return;
    if (action == 'profile') {
      context.push('/user/${m.userId}');
      return;
    }
    if (action == 'remove') {
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: VoyagoColors.surface,
          title: Text('Retirer ${m.displayName} ?', style: const TextStyle(color: VoyagoColors.text)),
          content: const Text('Il ne verra plus le contenu du cercle. Il pourra redemander à le rejoindre.',
              style: TextStyle(color: VoyagoColors.muted)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annuler')),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Retirer', style: TextStyle(color: VoyagoColors.coral)),
            ),
          ],
        ),
      );
      if (ok != true) return;
    }
    try {
      final controller = ref.read(communityControllerProvider);
      if (action == 'remove') {
        await controller.removeCircleMember(widget.circle.id, m.userId);
        setState(() {
          _members.removeWhere((x) => x.userId == m.userId);
          _total = (_total - 1).clamp(0, 1 << 30);
        });
        messenger.showSnackBar(SnackBar(content: Text('${m.displayName} a été retiré du cercle')));
      } else {
        final role = m.isAdmin ? 'explorer' : 'admin';
        await controller.setCircleMemberRole(widget.circle.id, m.userId, role);
        setState(() {
          final i = _members.indexWhere((x) => x.userId == m.userId);
          if (i >= 0) _members[i] = m.withRole(role);
        });
        messenger.showSnackBar(SnackBar(
          backgroundColor: VoyagoColors.primary,
          content: Text(role == 'admin' ? '⭐ ${m.displayName} est maintenant admin' : '${m.displayName} n\'est plus admin'),
        ));
      }
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: VoyagoColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(color: VoyagoColors.cardBorder, borderRadius: BorderRadius.circular(2)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 8),
            child: Row(
              children: [
                const Text('👥', style: TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _quota != null ? 'Membres · $_total / $_quota' : 'Membres · $_total',
                    style: const TextStyle(color: VoyagoColors.text, fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _error != null && _members.isEmpty
                ? Center(child: Text(_error!, style: const TextStyle(color: VoyagoColors.muted)))
                : ListView.builder(
                    controller: widget.scrollController,
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 32),
                    itemCount: _members.length + (_hasMore ? 1 : 0),
                    itemBuilder: (_, i) {
                      if (i >= _members.length) {
                        return const Padding(
                          padding: EdgeInsets.all(20),
                          child: Center(child: CircularProgressIndicator(color: VoyagoColors.primary, strokeWidth: 2)),
                        );
                      }
                      final m = _members[i];
                      final manageable = _canManage(m);
                      return ListTile(
                        onTap: () => context.push('/user/${m.userId}'),
                        onLongPress: manageable ? () => _manage(m) : null,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        leading: CircleAvatar(
                          radius: 22,
                          backgroundColor: VoyagoColors.surface,
                          backgroundImage:
                              m.picture != null && m.picture!.isNotEmpty ? CachedNetworkImageProvider(m.picture!) : null,
                          child: m.picture != null && m.picture!.isNotEmpty
                              ? null
                              : Text(m.avatarEmoji, style: const TextStyle(fontSize: 20)),
                        ),
                        title: Row(
                          children: [
                            Flexible(
                              child: Text(m.displayName,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w700)),
                            ),
                            if (m.emailVerified) ...[
                              const SizedBox(width: 4),
                              const Icon(Icons.verified_rounded, size: 14, color: VoyagoColors.blue),
                            ],
                            if (m.isCreator || m.isAdmin) ...[
                              const SizedBox(width: 6),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                                decoration: BoxDecoration(
                                  color: VoyagoColors.yellow.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(m.isCreator ? '👑 Fondateur' : '⭐ Admin',
                                    style: const TextStyle(color: VoyagoColors.yellow, fontSize: 10, fontWeight: FontWeight.w800)),
                              ),
                            ],
                          ],
                        ),
                        subtitle: Text(
                          [
                            'Niveau ${m.level}',
                            if (m.isPro) 'Pro',
                            if (m.country != null && m.country!.isNotEmpty) m.country!,
                          ].join(' · '),
                          style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
                        ),
                        trailing: manageable
                            ? IconButton(
                                icon: const Icon(Icons.more_vert_rounded, color: VoyagoColors.muted),
                                onPressed: () => _manage(m),
                              )
                            : const Icon(Icons.chevron_right_rounded, color: VoyagoColors.muted),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// Codes d'invitation à usage limité (fondateur / admins)
// =============================================================================

Future<void> showCircleInvitesSheet(BuildContext context, CommunityCircle circle) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (_, scroll) => _InvitesSheet(circle: circle, scrollController: scroll),
    ),
  );
}

class _InvitesSheet extends ConsumerStatefulWidget {
  final CommunityCircle circle;
  final ScrollController scrollController;

  const _InvitesSheet({required this.circle, required this.scrollController});

  @override
  ConsumerState<_InvitesSheet> createState() => _InvitesSheetState();
}

class _InvitesSheetState extends ConsumerState<_InvitesSheet> {
  static const _durations = <int?>[null, 1, 24, 72, 168, 720];
  static const _uses = <int?>[null, 1, 5, 10, 25, 50, 100];

  final _label = TextEditingController();
  int? _hours = 168;
  int? _maxUses = 10;
  bool _creating = false;

  @override
  void dispose() {
    _label.dispose();
    super.dispose();
  }

  static String _durationLabel(int? h) => switch (h) {
        null => 'Sans limite',
        1 => '1 heure',
        24 => '24 heures',
        72 => '3 jours',
        168 => '7 jours',
        720 => '30 jours',
        _ => '$h h',
      };

  Future<void> _create() async {
    setState(() => _creating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final invite = await ref
          .read(communityControllerProvider)
          .createInvite(widget.circle.id, label: _label.text, maxUses: _maxUses, expiresInHours: _hours);
      _label.clear();
      await Clipboard.setData(ClipboardData(text: invite.code));
      messenger.showSnackBar(SnackBar(
        backgroundColor: VoyagoColors.primary,
        content: Text('🎟️ Code ${invite.code} créé et copié'),
      ));
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final async = ref.watch(circleInvitesProvider(widget.circle.id));
    return Container(
      decoration: const BoxDecoration(
        color: VoyagoColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: ListView(
        controller: widget.scrollController,
        padding: EdgeInsets.fromLTRB(18, 12, 18, 24 + MediaQuery.of(context).viewInsets.bottom),
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(color: VoyagoColors.cardBorder, borderRadius: BorderRadius.circular(2)),
            ),
          ),
          const SizedBox(height: 14),
          const Text("Codes d'invitation",
              style: TextStyle(color: VoyagoColors.text, fontSize: 19, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text(
            "Des codes à durée ou à nombre d'utilisations limités, à partager sans risque. "
            "Les conditions d'accès s'appliquent toujours.",
            style: TextStyle(color: VoyagoColors.muted, fontSize: 12.5, height: 1.4),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: VoyagoColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: VoyagoColors.cardBorder),
            ),
            child: Column(
              children: [
                TextField(
                  controller: _label,
                  maxLength: 60,
                  style: const TextStyle(color: VoyagoColors.text, fontSize: 14),
                  decoration: InputDecoration(
                    hintText: 'Libellé (ex : Amis de Lyon)',
                    hintStyle: const TextStyle(color: VoyagoColors.muted, fontSize: 13),
                    counterText: '',
                    isDense: true,
                    filled: true,
                    fillColor: VoyagoColors.background,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 10),
                _SelectRow<int?>(
                  icon: Icons.timer_outlined,
                  label: 'Valable',
                  value: _hours,
                  options: _durations,
                  display: _durationLabel,
                  onChanged: (v) => setState(() => _hours = v),
                ),
                _SelectRow<int?>(
                  icon: Icons.people_alt_outlined,
                  label: 'Utilisations',
                  value: _maxUses,
                  options: _uses,
                  display: (v) => v == null ? 'Illimitées' : '$v max.',
                  onChanged: (v) => setState(() => _maxUses = v),
                ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: _creating ? null : _create,
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Créer un code', style: TextStyle(fontWeight: FontWeight.w800)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: VoyagoColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 13),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      elevation: 0,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          async.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator(color: VoyagoColors.primary)),
            ),
            error: (e, _) => Text(e.toString(), style: const TextStyle(color: VoyagoColors.muted)),
            data: (invites) => invites.isEmpty
                ? const Padding(
                    padding: EdgeInsets.all(20),
                    child: Text('Aucun code pour le moment.',
                        textAlign: TextAlign.center, style: TextStyle(color: VoyagoColors.muted)),
                  )
                : Column(children: [for (final i in invites) _InviteTile(circle: widget.circle, invite: i)]),
          ),
        ],
      ),
    );
  }
}

class _InviteTile extends ConsumerWidget {
  final CommunityCircle circle;
  final CircleInviteCode invite;

  const _InviteTile({required this.circle, required this.invite});

  String get _details {
    final parts = <String>[
      invite.maxUses == null ? '${invite.uses} utilisation${invite.uses > 1 ? 's' : ''}' : '${invite.uses}/${invite.maxUses} utilisations',
    ];
    final e = invite.expiresAt;
    if (e != null) {
      final left = e.difference(DateTime.now());
      parts.add(left.isNegative
          ? 'expiré'
          : left.inHours < 1
              ? 'expire dans ${left.inMinutes} min'
              : left.inHours < 48
                  ? 'expire dans ${left.inHours} h'
                  : 'expire dans ${left.inDays} j');
    } else {
      parts.add('sans expiration');
    }
    return parts.join(' · ');
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (statusLabel, statusColor) = switch (invite.status) {
      'expired' => ('Expiré', VoyagoColors.muted),
      'exhausted' => ('Épuisé', VoyagoColors.orange),
      _ => ('Actif', VoyagoColors.primary),
    };
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
      decoration: BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: invite.isActive ? VoyagoColors.primary.withValues(alpha: 0.3) : VoyagoColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(invite.code,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: invite.isActive ? VoyagoColors.text : VoyagoColors.muted,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 2,
                        )),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(statusLabel,
                          style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w800)),
                    ),
                  ],
                ),
                if (invite.label.isNotEmpty)
                  Text(invite.label, style: const TextStyle(color: VoyagoColors.text, fontSize: 12.5)),
                Text(_details, style: const TextStyle(color: VoyagoColors.muted, fontSize: 11.5)),
              ],
            ),
          ),
          if (invite.isActive) ...[
            IconButton(
              tooltip: 'Copier',
              icon: const Icon(Icons.copy_rounded, size: 19, color: VoyagoColors.muted),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: invite.code));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code copié')));
                }
              },
            ),
            IconButton(
              tooltip: 'Partager',
              icon: const Icon(Icons.ios_share_rounded, size: 19, color: VoyagoColors.primary),
              onPressed: () => SharePlus.instance.share(ShareParams(
                text: 'Rejoins ma tribu « ${circle.name} » sur Voyagooo 🦜\n'
                    'Code d\'invitation : ${invite.code}',
              )),
            ),
          ],
          IconButton(
            tooltip: 'Supprimer',
            icon: const Icon(Icons.delete_outline_rounded, size: 19, color: VoyagoColors.coral),
            onPressed: () async {
              final messenger = ScaffoldMessenger.of(context);
              try {
                await ref.read(communityControllerProvider).revokeInvite(circle.id, invite.code);
                messenger.showSnackBar(SnackBar(content: Text('Code ${invite.code} désactivé')));
              } on ApiException catch (e) {
                messenger.showSnackBar(SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)));
              }
            },
          ),
        ],
      ),
    );
  }
}
