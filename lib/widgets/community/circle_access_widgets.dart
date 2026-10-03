import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../api/api_exceptions.dart';
import '../../models/circle_access.dart';
import '../../models/community_circle.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../theme.dart';

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

  const JoinRuleChips({super.key, required this.rules});

  @override
  Widget build(BuildContext context) {
    final chips = rules.chips;
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
                Row(
                  children: [
                    Text(circle.avatarEmoji, style: const TextStyle(fontSize: 30)),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Demander à rejoindre',
                              style: TextStyle(color: VoyagoColors.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                          Text(circle.name,
                              style: const TextStyle(color: VoyagoColors.text, fontSize: 18, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                  ],
                ),
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
                    child: const Text(
                      "Tu ne remplis pas encore toutes les conditions. Gagne de l'XP en voyageant, complète ton profil… et reviens !",
                      style: TextStyle(color: VoyagoColors.text, fontSize: 12.5, height: 1.4),
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
// Vitrine d'un cercle privé (non-membre)
// =============================================================================

class LockedCircleView extends ConsumerWidget {
  final CommunityCircle circle;

  const LockedCircleView({super.key, required this.circle});

  Future<void> _joinWithCode(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    if (ref.read(currentUserProvider) == null) {
      messenger.showSnackBar(const SnackBar(
        backgroundColor: VoyagoColors.orange,
        content: Text('Connecte-toi pour rejoindre ce cercle'),
      ));
      return;
    }
    final code = await showDialog<String>(context: context, builder: (_) => const _InviteCodeDialog());
    if (code == null || code.trim().isEmpty) return;
    try {
      final circleId = await ref.read(communityControllerProvider).joinCircleByCode(code);
      messenger.showSnackBar(const SnackBar(
        backgroundColor: VoyagoColors.primary,
        content: Text('🎉 Bienvenue dans ta nouvelle tribu !'),
      ));
      if (circleId.isNotEmpty) router.go('/circle/$circleId');
    } on ApiException catch (e) {
      messenger.showSnackBar(SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final creator = circle.creator;
    final creatorName = (creator?['pseudo'] ?? creator?['name'])?.toString();

    return CustomScrollView(
      slivers: [
        SliverAppBar(
          expandedHeight: 220,
          pinned: true,
          backgroundColor: VoyagoColors.surface,
          leading: IconButton(
            icon: Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.black.withValues(alpha: 0.55), shape: BoxShape.circle),
              child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
            ),
            onPressed: () => context.canPop() ? context.pop() : context.go('/community'),
          ),
          flexibleSpace: FlexibleSpaceBar(
            background: Stack(
              fit: StackFit.expand,
              children: [
                CachedNetworkImage(
                  imageUrl: circle.coverImageUrl,
                  fit: BoxFit.cover,
                  errorWidget: (_, __, ___) => Container(color: VoyagoColors.cardBorder),
                ),
                // Voile flouté : le contenu reste réservé aux membres
                Container(color: Colors.black.withValues(alpha: 0.55)),
                Center(
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.45),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white.withValues(alpha: 0.25)),
                    ),
                    child: const Icon(Icons.lock_rounded, color: Colors.white, size: 34),
                  ),
                ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 40),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              Row(
                children: [
                  Text(circle.avatarEmoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(circle.name,
                        style: const TextStyle(color: VoyagoColors.text, fontSize: 22, fontWeight: FontWeight.w800)),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 12,
                runSpacing: 6,
                children: [
                  const _Meta(icon: Icons.lock_outline, label: 'Cercle privé · sur demande'),
                  _Meta(icon: Icons.group_rounded, label: '${circle.membersCount} membre${circle.membersCount > 1 ? 's' : ''}'),
                  _Meta(icon: Icons.location_on_rounded, label: circle.locationDisplay),
                  if (creatorName != null) _Meta(icon: Icons.workspace_premium_rounded, label: 'Fondé par $creatorName'),
                ],
              ),
              if (circle.description.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text(circle.description, style: const TextStyle(color: VoyagoColors.muted, fontSize: 14, height: 1.45)),
              ],
              const SizedBox(height: 18),
              JoinConditionsCard(checks: circle.joinChecks, autoApprove: circle.autoApprove),
              const SizedBox(height: 18),
              SizedBox(width: double.infinity, child: JoinRequestButton(circle: circle)),
              if (circle.hasPendingRequest)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: Text(
                    'Tu seras prévenu dès que le fondateur aura répondu. Touche le bouton pour annuler.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: VoyagoColors.muted, fontSize: 12),
                  ),
                ),
              const SizedBox(height: 10),
              Center(
                child: TextButton.icon(
                  onPressed: () => _joinWithCode(context, ref),
                  icon: const Icon(Icons.vpn_key_rounded, size: 18, color: VoyagoColors.primary),
                  label: const Text("J'ai un code d'invitation",
                      style: TextStyle(color: VoyagoColors.primary, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: VoyagoColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: VoyagoColors.cardBorder),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.visibility_off_rounded, color: VoyagoColors.muted, size: 20),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Les voyages, moments et projets de cette tribu sont réservés à ses membres.',
                        style: TextStyle(color: VoyagoColors.muted, fontSize: 12.5, height: 1.4),
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
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
          Row(
            children: [
              const Icon(Icons.admin_panel_settings_rounded, size: 18, color: VoyagoColors.yellow),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Accès à ta tribu',
                    style: TextStyle(color: VoyagoColors.text, fontSize: 14, fontWeight: FontWeight.w800)),
              ),
              if (!circle.joinRules.isEmpty) JoinRuleChips(rules: circle.joinRules),
            ],
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
                  child: Text('Demandes · ${circle.name}',
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
                      _JoinRequestCard(circle: circle, request: data.requests[i], question: data.question),
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

  const _JoinRequestCard({required this.circle, required this.request, required this.question});

  @override
  ConsumerState<_JoinRequestCard> createState() => _JoinRequestCardState();
}

class _JoinRequestCardState extends ConsumerState<_JoinRequestCard> {
  bool? _deciding; // true = accepter, false = refuser

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
          const SizedBox(height: 12),
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

  late JoinRules _rules = widget.circle.joinRules;
  late bool _autoApprove = widget.circle.autoApprove;
  late bool _listed = widget.circle.listed;
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
                  label: 'Nombre de places',
                  value: _rules.maxMembers,
                  options: _places,
                  display: (v) => v == null ? 'Illimité' : '$v membres max.',
                  onChanged: (v) => setState(() => _rules = _rules.copyWith(maxMembers: () => v)),
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
