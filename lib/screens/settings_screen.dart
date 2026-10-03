import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/notifications_api.dart';
import '../services/app_settings.dart';
import '../services/app_sounds.dart';
import '../services/navigation_links.dart';
import '../theme.dart';

/// Réglages : notifications (son, vibration, volume, heures calmes) et navigation (app, péages…).
class SettingsScreen extends StatelessWidget {
  /// Onglet ouvert au départ : « notifications » ou « navigation »
  final String? initialTab;
  const SettingsScreen({super.key, this.initialTab});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      initialIndex: initialTab == 'navigation' ? 1 : 0,
      child: Scaffold(
        backgroundColor: VoyagoColors.background,
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => context.canPop() ? context.pop() : context.go('/profile'),
          ),
          title: const Text('Réglages'),
          bottom: const TabBar(
            indicatorColor: VoyagoColors.primary,
            labelColor: VoyagoColors.text,
            unselectedLabelColor: VoyagoColors.muted,
            labelStyle: TextStyle(fontWeight: FontWeight.w800),
            tabs: [
              Tab(icon: Icon(Icons.notifications_active_rounded), text: 'Notifications'),
              Tab(icon: Icon(Icons.navigation_rounded), text: 'Navigation'),
            ],
          ),
        ),
        body: const TabBarView(children: [_NotificationsTab(), _NavigationTab()]),
      ),
    );
  }
}

// =============================================================================
// Notifications
// =============================================================================

class _NotificationsTab extends ConsumerStatefulWidget {
  const _NotificationsTab();

  @override
  ConsumerState<_NotificationsTab> createState() => _NotificationsTabState();
}

class _NotificationsTabState extends ConsumerState<_NotificationsTab> {
  final _api = NotificationsApi();
  Map<String, dynamic>? _server;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _api.getPrefs().then((p) {
      if (!mounted) return;
      setState(() => _server = p);
      // Le mode enregistré sur le compte fait foi (même réglage sur tous les appareils)
      final mode = NotifMode.fromValue(p['mode']?.toString());
      final notifier = ref.read(appSettingsProvider.notifier);
      notifier.update(ref.read(appSettingsProvider).copyWith(notifMode: mode));
    }).catchError((_) {
      if (mounted) setState(() => _server = {'social': true, 'quiet_hours': true});
    });
  }

  Future<void> _setMode(NotifMode mode) async {
    final notifier = ref.read(appSettingsProvider.notifier);
    await notifier.update(ref.read(appSettingsProvider).copyWith(notifMode: mode));
    AppSounds.instance.notification();
    try {
      await _api.updatePrefs({'mode': mode.value});
    } catch (_) {}
  }

  Future<void> _setServer(String key, bool value) async {
    final before = _server;
    setState(() => _server = {...?_server, key: value});
    try {
      final p = await _api.updatePrefs({key: value});
      if (mounted) setState(() => _server = p);
    } catch (_) {
      if (mounted) setState(() => _server = before);
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      await _api.sendTest();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)
            ?.showSnackBar(const SnackBar(content: Text('Notification de test indisponible pour le moment')));
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = ref.watch(appSettingsProvider);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        const _SectionTitle('QUAND UNE NOTIFICATION ARRIVE'),
        for (final mode in NotifMode.values)
          _ChoiceCard(
            selected: s.notifMode == mode,
            icon: switch (mode) {
              NotifMode.sound => Icons.volume_up_rounded,
              NotifMode.vibrate => Icons.vibration_rounded,
              NotifMode.silent => Icons.notifications_off_rounded,
            },
            title: mode.label,
            subtitle: switch (mode) {
              NotifMode.sound => 'Le gazouillis Voyagooo 🦜 et une vibration',
              NotifMode.vibrate => 'Pas de son, juste une vibration',
              NotifMode.silent => 'Ni son ni vibration : le bandeau et la cloche restent',
            },
            onTap: () => _setMode(mode),
          ),
        const SizedBox(height: 18),
        const _SectionTitle('VOLUME DU SON VOYAGOOO'),
        _Card(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.volume_down_rounded, color: VoyagoColors.muted),
                  Expanded(
                    child: Slider(
                      value: s.soundVolume,
                      divisions: 10,
                      label: '${(s.soundVolume * 100).round()} %',
                      activeColor: VoyagoColors.primary,
                      onChanged: s.notifMode == NotifMode.sound
                          ? (v) => ref.read(appSettingsProvider.notifier).update(s.copyWith(soundVolume: v))
                          : null,
                      onChangeEnd: (v) => AppSounds.instance.preview(v),
                    ),
                  ),
                  const Icon(Icons.volume_up_rounded, color: VoyagoColors.muted),
                ],
              ),
              Text(
                s.notifMode == NotifMode.sound
                    ? 'Dans l’app. Pour les notifications app fermée, c’est le volume de notification du téléphone.'
                    : 'Active « Son + vibration » pour régler le volume.',
                style: const TextStyle(color: VoyagoColors.muted, fontSize: 12, height: 1.35),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton.icon(
                  onPressed: s.notifMode == NotifMode.sound ? () => AppSounds.instance.preview(s.soundVolume) : null,
                  icon: const Icon(Icons.play_arrow_rounded),
                  label: const Text('Écouter'),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        const _SectionTitle('CE QUE TU REÇOIS'),
        _Card(
          child: Column(
            children: [
              _Switch(
                value: _server?['social'] != false,
                enabled: _server != null,
                icon: Icons.forum_rounded,
                title: 'Commentaires et voyages refaits',
                subtitle: 'Regroupés et discrets pour ne pas te déranger',
                onChanged: (v) => _setServer('social', v),
              ),
              const Divider(height: 1),
              _Switch(
                value: _server?['quiet_hours'] != false,
                enabled: _server != null,
                icon: Icons.bedtime_rounded,
                title: 'Heures calmes (22 h – 8 h)',
                subtitle: 'La nuit, les notifications arrivent sans son ni vibration',
                onChanged: (v) => _setServer('quiet_hours', v),
              ),
            ],
          ),
        ),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          onPressed: _testing ? null : _test,
          icon: const Icon(Icons.send_rounded),
          label: Text(_testing ? 'Envoi…' : 'M’envoyer une notification de test'),
        ),
        const SizedBox(height: 10),
        const Text(
          'Les plan B pluie, départs, baisses de prix et itinéraires prêts restent toujours actifs : '
          'ce sont tes alertes de voyage.',
          textAlign: TextAlign.center,
          style: TextStyle(color: VoyagoColors.muted, fontSize: 11.5, height: 1.35),
        ),
      ],
    );
  }
}

// =============================================================================
// Navigation
// =============================================================================

class _NavigationTab extends ConsumerWidget {
  const _NavigationTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(appSettingsProvider);
    final notifier = ref.read(appSettingsProvider.notifier);
    final apps = NavApp.values.where((a) => a != NavApp.apple || NavigationLinks.appleAvailable);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 32),
      children: [
        const _SectionTitle('QUAND JE TOUCHE « Y ALLER »'),
        for (final app in apps)
          _ChoiceCard(
            selected: s.navApp == app,
            icon: switch (app) {
              NavApp.ask => Icons.help_outline_rounded,
              NavApp.voyagooo => Icons.directions_walk_rounded,
              NavApp.waze => Icons.navigation_rounded,
              _ => Icons.map_outlined,
            },
            title: app.label,
            subtitle: switch (app) {
              NavApp.ask => 'Je choisis l’app à chaque trajet',
              NavApp.voyagooo => 'Le tracé s’affiche sur la carte, sans quitter l’app',
              NavApp.waze => 'Trafic en direct, bouchons et radars : idéal en voiture',
              NavApp.google => 'À pied, en transport, à vélo ou en voiture',
              NavApp.apple => 'L’app Plans de ton iPhone',
            },
            onTap: () => notifier.update(s.copyWith(navApp: app)),
          ),
        const SizedBox(height: 18),
        const _SectionTitle('EN VOITURE, ÉVITER'),
        _Card(
          child: Column(
            children: [
              _Switch(
                value: s.avoidTolls,
                icon: Icons.toll_rounded,
                title: 'Les péages',
                subtitle: 'Itinéraire sans route payante',
                onChanged: (v) => notifier.update(s.copyWith(avoidTolls: v)),
              ),
              const Divider(height: 1),
              _Switch(
                value: s.avoidFerries,
                icon: Icons.directions_boat_rounded,
                title: 'Les ferries',
                subtitle: 'Pas de traversée en bateau',
                onChanged: (v) => notifier.update(s.copyWith(avoidFerries: v)),
              ),
              const Divider(height: 1),
              _Switch(
                value: s.avoidFreeways,
                icon: Icons.add_road_rounded,
                title: 'Les autoroutes',
                subtitle: 'Routes secondaires, plus de paysages',
                onChanged: (v) => notifier.update(s.copyWith(avoidFreeways: v)),
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),
        const Text(
          'Ces options s’appliquent aux trajets ouverts dans Waze.',
          textAlign: TextAlign.center,
          style: TextStyle(color: VoyagoColors.muted, fontSize: 11.5),
        ),
      ],
    );
  }
}

// =============================================================================

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4, bottom: 8),
        child: Text(text,
            style: const TextStyle(color: VoyagoColors.muted, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8)),
      );
}

class _Card extends StatelessWidget {
  final Widget child;
  const _Card({required this.child});

  @override
  Widget build(BuildContext context) => Material(
        color: VoyagoColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: VoyagoColors.cardBorder),
        ),
        child: Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: child),
      );
}

class _ChoiceCard extends StatelessWidget {
  final bool selected;
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ChoiceCard({
    required this.selected,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected ? VoyagoColors.primary.withValues(alpha: 0.10) : VoyagoColors.surface,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: selected ? VoyagoColors.primary : VoyagoColors.cardBorder, width: selected ? 1.6 : 1),
        ),
        child: ListTile(
          onTap: onTap,
          leading: Icon(icon, color: selected ? VoyagoColors.primary : VoyagoColors.muted),
          title: Text(title, style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w800)),
          subtitle: Text(subtitle, style: const TextStyle(color: VoyagoColors.muted, fontSize: 12.5)),
          trailing: Icon(
            selected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
            color: selected ? VoyagoColors.primary : VoyagoColors.muted,
          ),
        ),
      ),
    );
  }
}

class _Switch extends StatelessWidget {
  final bool value;
  final bool enabled;
  final IconData icon;
  final String title;
  final String subtitle;
  final ValueChanged<bool> onChanged;

  const _Switch({
    required this.value,
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) => SwitchListTile.adaptive(
        contentPadding: EdgeInsets.zero,
        value: value,
        onChanged: enabled ? onChanged : null,
        activeTrackColor: VoyagoColors.primary,
        secondary: Icon(icon, color: VoyagoColors.primary),
        title: Text(title, style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w700, fontSize: 14)),
        subtitle: Text(subtitle, style: const TextStyle(color: VoyagoColors.muted, fontSize: 12)),
      );
}
