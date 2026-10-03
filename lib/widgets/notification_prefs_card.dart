import 'package:flutter/material.dart';
import '../api/notifications_api.dart';
import '../services/app_sounds.dart';
import '../theme.dart';

/// Réglages des notifications : son signature, interactions sociales, heures calmes.
class NotificationPrefsCard extends StatefulWidget {
  const NotificationPrefsCard({super.key});

  @override
  State<NotificationPrefsCard> createState() => _NotificationPrefsCardState();
}

class _NotificationPrefsCardState extends State<NotificationPrefsCard> {
  final _api = NotificationsApi();
  Map<String, bool>? _prefs;
  bool _testing = false;

  @override
  void initState() {
    super.initState();
    _api.getPrefs().then((p) {
      if (mounted) setState(() => _prefs = p);
    }).catchError((_) {
      if (mounted) setState(() => _prefs = {'sound': true, 'social': true, 'quiet_hours': true});
    });
  }

  Future<void> _set(String key, bool value) async {
    final before = _prefs;
    setState(() => _prefs = {...?_prefs, key: value});
    if (key == 'sound' && value) AppSounds.instance.notification();
    try {
      final p = await _api.updatePrefs({key: value});
      if (mounted) setState(() => _prefs = p);
    } catch (_) {
      if (mounted) setState(() => _prefs = before);
    }
  }

  Future<void> _test() async {
    setState(() => _testing = true);
    try {
      await _api.sendTest();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.maybeOf(context)?.showSnackBar(
          const SnackBar(content: Text('Notification de test indisponible pour le moment')),
        );
      }
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Widget _switch(String key, String title, String subtitle, IconData icon) {
    return SwitchListTile.adaptive(
      contentPadding: EdgeInsets.zero,
      value: _prefs?[key] ?? true,
      onChanged: _prefs == null ? null : (v) => _set(key, v),
      activeTrackColor: VoyagoColors.primary,
      secondary: Icon(icon, color: VoyagoColors.primary),
      title: Text(title, style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w700, fontSize: 14)),
      subtitle: Text(subtitle, style: const TextStyle(color: VoyagoColors.muted, fontSize: 12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
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
              const Expanded(
                child: Text('🔔 Notifications',
                    style: TextStyle(color: VoyagoColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
              ),
              TextButton(
                onPressed: _testing ? null : _test,
                child: Text(_testing ? 'Envoi…' : 'Tester'),
              ),
            ],
          ),
          _switch('sound', 'Son Voyagooo', 'Le gazouillis signature à chaque notification importante',
              Icons.music_note_rounded),
          _switch('social', 'Commentaires et voyages refaits', 'Regroupés et discrets pour ne pas te déranger',
              Icons.forum_rounded),
          _switch('quiet_hours', 'Heures calmes (22 h – 8 h)', 'Les notifications arrivent sans son la nuit',
              Icons.bedtime_rounded),
        ],
      ),
    );
  }
}
