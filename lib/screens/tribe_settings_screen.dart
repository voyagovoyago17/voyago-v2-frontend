import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/api_exceptions.dart';
import '../models/circle_access.dart';
import '../models/community_circle.dart';
import '../providers/auth_provider.dart';
import '../providers/community_provider.dart';
import '../theme.dart';
import '../widgets/community/circle_access_widgets.dart';

/// Paramètres des tribus : tout ce qui touche à l'accès et à la vie privée des cercles,
/// regroupé en un seul endroit (sidebar → Paramètres des tribus).
class TribeSettingsScreen extends ConsumerWidget {
  const TribeSettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loggedIn = ref.watch(isAuthenticatedProvider);
    return Scaffold(
      backgroundColor: VoyagoColors.background,
      appBar: AppBar(
        backgroundColor: VoyagoColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: VoyagoColors.text),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
        title: const Text('Paramètres des tribus',
            style: TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: !loggedIn
          ? const _Empty(emoji: '🔐', title: 'Connecte-toi', text: 'Tes tribus et tes demandes apparaîtront ici.')
          : RefreshIndicator(
              color: VoyagoColors.primary,
              onRefresh: () async {
                ref.invalidate(myCirclesProvider);
                ref.invalidate(myJoinRequestsProvider);
                await ref.read(myCirclesProvider.future);
              },
              child: const _SettingsBody(),
            ),
    );
  }
}

class _SettingsBody extends ConsumerWidget {
  const _SettingsBody();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final circlesAsync = ref.watch(myCirclesProvider);
    final requestsAsync = ref.watch(myJoinRequestsProvider);

    final circles = circlesAsync.valueOrNull ?? const <MyCircle>[];
    final managed = circles.where((c) => c.canManage).toList();
    final joined = circles.where((c) => !c.canManage).toList();
    final requests = requestsAsync.valueOrNull ?? const <MyJoinRequest>[];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        const _SectionTitle(
          icon: Icons.admin_panel_settings_rounded,
          title: 'Tribus que je gère',
          subtitle: 'Accès, conditions, demandes, invitations et membres',
        ),
        if (circlesAsync.isLoading && circles.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: CircularProgressIndicator(color: VoyagoColors.primary)),
          )
        else if (circlesAsync.hasError && circles.isEmpty)
          _ErrorTile(message: circlesAsync.error.toString(), onRetry: () => ref.invalidate(myCirclesProvider))
        else if (managed.isEmpty)
          _CreateHint(onTap: () => context.go('/community'))
        else
          for (final c in managed) _ManagedCircleCard(circle: c),
        const SizedBox(height: 22),
        const _SectionTitle(
          icon: Icons.hourglass_top_rounded,
          title: "Mes demandes d'adhésion",
          subtitle: 'Cercles privés que tu as demandé à rejoindre',
        ),
        if (requestsAsync.hasError && requests.isEmpty)
          _ErrorTile(message: requestsAsync.error.toString(), onRetry: () => ref.invalidate(myJoinRequestsProvider))
        else if (requests.isEmpty)
          const _InfoTile(text: 'Aucune demande en cours.')
        else
          for (final r in requests) _MyRequestTile(request: r),
        const SizedBox(height: 22),
        const _SectionTitle(
          icon: Icons.groups_rounded,
          title: 'Tribus rejointes',
          subtitle: 'Ton rôle et ta période de découverte',
        ),
        if (circlesAsync.hasError && circles.isEmpty)
          const _InfoTile(text: 'Impossible de charger tes tribus pour le moment.')
        else if (joined.isEmpty)
          const _InfoTile(text: 'Tu ne fais encore partie d\'aucune autre tribu.')
        else
          for (final c in joined) _JoinedCircleTile(circle: c),
        const SizedBox(height: 22),
        const _GoodToKnow(),
      ],
    );
  }
}

// ----------------------------------------------------------------------------- Tribus gérées

class _ManagedCircleCard extends StatelessWidget {
  final MyCircle circle;

  const _ManagedCircleCard({required this.circle});

  @override
  Widget build(BuildContext context) {
    final pending = circle.pendingRequestsCount;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => context.push('/tribe-settings/${circle.id}'),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border:
                  Border.all(color: pending > 0 ? VoyagoColors.yellow.withValues(alpha: 0.5) : VoyagoColors.cardBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(circle.avatarEmoji, style: const TextStyle(fontSize: 26)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(circle.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: VoyagoColors.text, fontSize: 15.5, fontWeight: FontWeight.w800)),
                          Text(
                            '${circle.myRole == 'creator' ? '👑 Fondateur' : '⭐ Admin'} · ${circle.visibilityLabel}',
                            style: const TextStyle(color: VoyagoColors.muted, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                    if (pending > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
                        decoration: BoxDecoration(color: VoyagoColors.yellow, borderRadius: BorderRadius.circular(12)),
                        child: Text('$pending',
                            style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12)),
                      ),
                    const SizedBox(width: 4),
                    const Icon(Icons.chevron_right_rounded, color: VoyagoColors.muted),
                  ],
                ),
                const SizedBox(height: 10),
                QuotaBar(members: circle.membersCount, quota: circle.joinRules.maxMembers),
                if (!circle.joinRules.isEmpty || circle.autoApprove || circle.trialDays > 0) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      JoinRuleChips(rules: circle.joinRules, membersCount: circle.membersCount),
                      if (circle.autoApprove) const _Tag('⚡ Accès auto'),
                      if (circle.trialDays > 0) _Tag('🌱 Découverte ${circle.trialDays} j'),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  final String label;

  const _Tag(this.label);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: VoyagoColors.primary.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: VoyagoColors.primary.withValues(alpha: 0.35)),
      ),
      child:
          Text(label, style: const TextStyle(color: VoyagoColors.primary, fontSize: 10.5, fontWeight: FontWeight.w700)),
    );
  }
}

// ----------------------------------------------------------------------------- Mes demandes

class _MyRequestTile extends ConsumerWidget {
  final MyJoinRequest request;

  const _MyRequestTile({required this.request});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pending = request.status == 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
      decoration: BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VoyagoColors.cardBorder),
      ),
      child: Row(
        children: [
          Text(request.circleEmoji, style: const TextStyle(fontSize: 22)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(request.circleName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w700)),
                Text(
                  pending
                      ? '⏳ En attente${request.vouchesCount > 0 ? ' · 🤝 ${request.vouchesCount} garant${request.vouchesCount > 1 ? 's' : ''}' : ''}'
                      : '✋ Non retenue · nouvelle demande possible sous 7 jours',
                  style: TextStyle(color: pending ? VoyagoColors.yellow : VoyagoColors.muted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (pending)
            TextButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                try {
                  await ref.read(communityControllerProvider).cancelJoinRequest(request.circleId);
                  messenger.showSnackBar(const SnackBar(content: Text('Demande annulée')));
                } on ApiException catch (e) {
                  messenger.showSnackBar(SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)));
                }
              },
              child: const Text('Annuler', style: TextStyle(color: VoyagoColors.coral, fontWeight: FontWeight.w700)),
            ),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------------------- Tribus rejointes

class _JoinedCircleTile extends StatelessWidget {
  final MyCircle circle;

  const _JoinedCircleTile({required this.circle});

  @override
  Widget build(BuildContext context) {
    final trial = circle.trialUntil;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: VoyagoColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: VoyagoColors.cardBorder),
        ),
        child: ListTile(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          onTap: () => context.push('/circle/${circle.id}'),
          leading: Text(circle.avatarEmoji, style: const TextStyle(fontSize: 24)),
          title: Text(circle.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w700)),
          subtitle: Text(
            trial != null
                ? '🌱 Découverte jusqu\'au ${trial.day.toString().padLeft(2, '0')}/${trial.month.toString().padLeft(2, '0')}'
                : '${circle.visibilityLabel} · ${circle.membersCount} membres',
            style: TextStyle(color: trial != null ? VoyagoColors.primary : VoyagoColors.muted, fontSize: 12),
          ),
          trailing: const Icon(Icons.chevron_right_rounded, color: VoyagoColors.muted),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------------------- Divers

class _SectionTitle extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionTitle({required this.icon, required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Row(
        children: [
          Icon(icon, color: VoyagoColors.primary, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(color: VoyagoColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
                Text(subtitle, style: const TextStyle(color: VoyagoColors.muted, fontSize: 12)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _InfoTile extends StatelessWidget {
  final String text;

  const _InfoTile({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: VoyagoColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Text(text, style: const TextStyle(color: VoyagoColors.muted, fontSize: 13)),
    );
  }
}

class _ErrorTile extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorTile({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: VoyagoColors.surface, borderRadius: BorderRadius.circular(14)),
      child: Row(
        children: [
          Expanded(child: Text(message, style: const TextStyle(color: VoyagoColors.muted, fontSize: 13))),
          TextButton(onPressed: onRetry, child: const Text('Réessayer')),
        ],
      ),
    );
  }
}

class _CreateHint extends StatelessWidget {
  final VoidCallback onTap;

  const _CreateHint({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: VoyagoColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VoyagoColors.cardBorder),
        ),
        child: const Row(
          children: [
            Text('🏕️', style: TextStyle(fontSize: 26)),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                "Tu ne gères aucune tribu. Crée la tienne depuis la Communauté pour choisir qui peut la rejoindre.",
                style: TextStyle(color: VoyagoColors.text, fontSize: 13, height: 1.4),
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: VoyagoColors.muted),
          ],
        ),
      ),
    );
  }
}

class _GoodToKnow extends StatelessWidget {
  const _GoodToKnow();

  @override
  Widget build(BuildContext context) {
    const items = [
      ('🔒', 'Privé', 'visible dans la liste avec un cadenas : on y entre sur demande ou avec un code.'),
      ('🕶️', 'Secret', 'invisible dans la liste : uniquement avec un code d\'invitation.'),
      ('🎟️', 'Codes limités', 'expirent après une durée ou un nombre d\'utilisations.'),
      ('🤝', 'Parrainage', 'les membres se portent garants des voyageurs qu\'ils connaissent.'),
      ('🌱', 'Découverte', 'les nouveaux membres lisent avant de publier.'),
      ('⚡', 'Fondateur actif', 'réponds aux demandes en moins de 24 h pour gagner de l\'XP et un badge.'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: VoyagoColors.cardBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Bon à savoir',
              style: TextStyle(color: VoyagoColors.text, fontSize: 14, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          for (final (emoji, title, text) in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text.rich(
                TextSpan(children: [
                  TextSpan(text: '$emoji  '),
                  TextSpan(
                      text: '$title : ', style: const TextStyle(fontWeight: FontWeight.w800, color: VoyagoColors.text)),
                  TextSpan(text: text),
                ]),
                style: const TextStyle(color: VoyagoColors.muted, fontSize: 12.5, height: 1.4),
              ),
            ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  final String emoji;
  final String title;
  final String text;

  const _Empty({required this.emoji, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 44)),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(color: VoyagoColors.text, fontSize: 17, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(text, textAlign: TextAlign.center, style: const TextStyle(color: VoyagoColors.muted)),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// Réglages d'une tribu : sections séparées
// =============================================================================

class CircleSettingsScreen extends ConsumerWidget {
  final String circleId;

  const CircleSettingsScreen({super.key, required this.circleId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(circleDetailProvider(circleId));
    return Scaffold(
      backgroundColor: VoyagoColors.background,
      appBar: AppBar(
        backgroundColor: VoyagoColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: VoyagoColors.text),
          onPressed: () => context.canPop() ? context.pop() : context.go('/tribe-settings'),
        ),
        title: Text(async.valueOrNull?.name ?? 'Réglages de la tribu',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w800, fontSize: 18)),
      ),
      body: async.when(
        loading: () => const Center(child: CircularProgressIndicator(color: VoyagoColors.primary)),
        error: (e, _) => _Empty(emoji: '🧭', title: 'Tribu introuvable', text: e.toString()),
        data: (circle) => !circle.canManage
            ? const _Empty(
                emoji: '🔐',
                title: 'Réservé au fondateur',
                text: 'Seuls le fondateur et les admins règlent cette tribu.',
              )
            : RefreshIndicator(
                color: VoyagoColors.primary,
                onRefresh: () => ref.refresh(circleDetailProvider(circleId).future),
                child: _CircleSettingsBody(circle: circle),
              ),
      ),
    );
  }
}

class _CircleSettingsBody extends StatelessWidget {
  final CommunityCircle circle;

  const _CircleSettingsBody({required this.circle});

  String get _visibility => circle.isPublic ? 'Public' : (circle.listed ? 'Privé · sur demande' : 'Secret · sur code');

  String get _conditionsSummary {
    final chips = circle.joinRules.chips;
    if (chips.isEmpty) return 'Aucune condition';
    return chips.join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final pending = circle.pendingRequestsCount;
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: VoyagoColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: VoyagoColors.cardBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text(circle.avatarEmoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(circle.name,
                            style:
                                const TextStyle(color: VoyagoColors.text, fontSize: 17, fontWeight: FontWeight.w800)),
                        Text('${circle.myRole == 'creator' ? '👑 Fondateur' : '⭐ Admin'} · $_visibility',
                            style: const TextStyle(color: VoyagoColors.muted, fontSize: 12.5)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              QuotaBar(members: circle.membersCount, quota: circle.joinRules.maxMembers),
            ],
          ),
        ),
        const _Group(title: 'Accès'),
        _SettingTile(
          icon: Icons.tune_rounded,
          color: VoyagoColors.primary,
          title: "Conditions d'accès & quota",
          subtitle: _conditionsSummary,
          onTap: () => showCircleAccessSettingsSheet(context, circle),
        ),
        if (!circle.isPublic)
          _SettingTile(
            icon: Icons.person_add_alt_1_rounded,
            color: VoyagoColors.yellow,
            title: "Demandes d'adhésion",
            subtitle: pending > 0
                ? '$pending en attente${circle.autoApprove ? ' · acceptation auto' : ''}'
                : circle.autoApprove
                    ? 'Acceptation automatique activée'
                    : 'Aucune demande en attente',
            badge: pending,
            onTap: () => showJoinRequestsSheet(context, circle),
          ),
        _SettingTile(
          icon: Icons.confirmation_number_rounded,
          color: VoyagoColors.blue,
          title: "Codes d'invitation",
          subtitle: 'Codes limités en durée ou en nombre d\'utilisations',
          onTap: () => showCircleInvitesSheet(context, circle),
        ),
        const _Group(title: 'Communauté'),
        _SettingTile(
          icon: Icons.groups_rounded,
          color: VoyagoColors.primary,
          title: 'Membres & rôles',
          subtitle: 'Voir les profils, nommer des admins, retirer un membre',
          onTap: () => showCircleMembersSheet(context, circle),
        ),
        _SettingTile(
          icon: Icons.spa_rounded,
          color: VoyagoColors.primary,
          title: 'Intégration des nouveaux',
          subtitle: circle.trialDays > 0
              ? 'Période de découverte : ${circle.trialDays} jour${circle.trialDays > 1 ? 's' : ''}'
              : 'Pas de période de découverte',
          onTap: () => showCircleAccessSettingsSheet(context, circle),
        ),
        const _Group(title: 'Raccourcis'),
        _SettingTile(
          icon: Icons.open_in_new_rounded,
          color: VoyagoColors.muted,
          title: 'Ouvrir la tribu',
          subtitle: 'Voyages, moments et projets',
          onTap: () => context.push('/circle/${circle.id}'),
        ),
      ],
    );
  }
}

class _Group extends StatelessWidget {
  final String title;

  const _Group({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Text(title.toUpperCase(),
          style: const TextStyle(
              color: VoyagoColors.muted, fontSize: 11.5, fontWeight: FontWeight.w800, letterSpacing: 1)),
    );
  }
}

class _SettingTile extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final int badge;
  final VoidCallback onTap;

  const _SettingTile({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge = 0,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.circular(16),
        child: ListTile(
          onTap: onTap,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          leading: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: color.withValues(alpha: 0.14), borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          title:
              Text(title, style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w700, fontSize: 14)),
          subtitle: Text(subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: VoyagoColors.muted, fontSize: 12)),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: VoyagoColors.yellow, borderRadius: BorderRadius.circular(10)),
                  child: Text('$badge',
                      style: const TextStyle(color: Colors.black, fontSize: 11.5, fontWeight: FontWeight.w900)),
                ),
              const Icon(Icons.chevron_right_rounded, color: VoyagoColors.muted),
            ],
          ),
        ),
      ),
    );
  }
}
