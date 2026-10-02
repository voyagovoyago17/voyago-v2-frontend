import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../api/api.dart';
import '../../models/trip.dart';
import '../../providers/auth_provider.dart';
import '../../providers/community_provider.dart';
import '../../providers/trips_provider.dart';
import '../../theme.dart';
import 'comments_sheet.dart';

/// Demande confirmation puis bloque le voyageur. Renvoie true si le blocage a eu lieu.
Future<bool> confirmBlockUser(
  BuildContext context,
  WidgetRef ref, {
  required String userId,
  required String name,
}) async {
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: VoyagoColors.surface,
      title: Text('Bloquer $name ?', style: const TextStyle(color: VoyagoColors.text)),
      content: const Text(
        "Vous ne verrez plus vos voyages, publications et commentaires respectifs. "
        "Tu pourras le débloquer depuis Communauté → Utilisateurs bloqués.",
        style: TextStyle(color: VoyagoColors.muted),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('Annuler')),
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(true),
          child: const Text('Bloquer', style: TextStyle(color: VoyagoColors.coral)),
        ),
      ],
    ),
  );
  if (confirmed != true || !context.mounted) return false;

  final messenger = ScaffoldMessenger.of(context);
  try {
    await ref.read(communityControllerProvider).blockUser(userId);
    messenger.showSnackBar(SnackBar(content: Text('$name est bloqué')));
    return true;
  } on ApiException catch (e) {
    messenger.showSnackBar(SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)));
    return false;
  }
}

/// « Refaire ce voyage » : choisit une date de départ (facultative), copie l'itinéraire
/// dans mes voyages puis l'ouvre.
Future<void> remixTrip(BuildContext context, WidgetRef ref, Trip trip) async {
  if (ref.read(currentUserProvider) == null) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Connecte-toi pour refaire ce voyage')),
    );
    return;
  }

  final choice = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: VoyagoColors.surface,
      title: Text('Refaire ${trip.destination} ?', style: const TextStyle(color: VoyagoColors.text)),
      content: Text(
        "L'itinéraire de ${trip.durationDays} jour${trip.durationDays > 1 ? 's' : ''} "
        "(${trip.pois.length} lieux) sera copié dans tes voyages, en privé. "
        'Choisis ta date de départ pour avoir la bonne météo.',
        style: const TextStyle(color: VoyagoColors.muted),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Annuler')),
        TextButton(onPressed: () => Navigator.of(ctx).pop('no_date'), child: const Text('Sans date')),
        ElevatedButton(
          onPressed: () => Navigator.of(ctx).pop('date'),
          style: ElevatedButton.styleFrom(backgroundColor: VoyagoColors.primary),
          child: const Text('Choisir la date', style: TextStyle(color: Colors.white)),
        ),
      ],
    ),
  );
  if (choice == null || !context.mounted) return;

  DateTime? startDate;
  if (choice == 'date') {
    final now = DateTime.now();
    startDate = await showDatePicker(
      context: context,
      initialDate: now.add(const Duration(days: 7)),
      firstDate: now,
      lastDate: now.add(const Duration(days: 365 * 2)),
    );
    if (startDate == null || !context.mounted) return;
  }

  final messenger = ScaffoldMessenger.of(context);
  try {
    final newTrip = await ref.read(tripsApiProvider).remixTrip(trip.id, startDate: startDate);
    ref.invalidate(tripsProvider);
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: VoyagoColors.primary,
        content: Text('🧭 ${trip.destination} ajouté à tes voyages !'),
      ),
    );
    if (context.mounted) context.go('/itinerary/${newTrip.id}', extra: newTrip);
  } on ApiException catch (e) {
    final isQuota = e.statusCode == 402;
    messenger.showSnackBar(
      SnackBar(
        backgroundColor: isQuota ? VoyagoColors.orange : VoyagoColors.coral,
        content: Text(e.message),
        action: isQuota && context.mounted
            ? SnackBarAction(label: 'Passer Pro', onPressed: () => context.go('/pricing'))
            : null,
      ),
    );
  }
}

/// Liste des voyageurs bloqués, avec la possibilité de les débloquer.
Future<void> showBlockedUsersSheet(BuildContext context) {
  return showModalBottomSheet(
    context: context,
    backgroundColor: VoyagoColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => const _BlockedUsersSheet(),
  );
}

class _BlockedUsersSheet extends ConsumerStatefulWidget {
  const _BlockedUsersSheet();

  @override
  ConsumerState<_BlockedUsersSheet> createState() => _BlockedUsersSheetState();
}

class _BlockedUsersSheetState extends ConsumerState<_BlockedUsersSheet> {
  List<Map<String, dynamic>>? _users;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final users = await ref.read(communityApiProvider).getBlockedUsers();
      if (mounted) setState(() => _users = users);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    }
  }

  Future<void> _unblock(Map<String, dynamic> user) async {
    final userId = user['user_id']?.toString() ?? '';
    try {
      await ref.read(communityControllerProvider).unblockUser(userId);
      if (mounted) {
        setState(() => _users = _users?.where((u) => u['user_id'] != userId).toList());
      }
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(backgroundColor: VoyagoColors.coral, content: Text(e.message)),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final users = _users;
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.5,
        child: Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                'Utilisateurs bloqués',
                style: TextStyle(color: VoyagoColors.text, fontSize: 17, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: VoyagoColors.muted)))
                  : users == null
                      ? const Center(child: CircularProgressIndicator(color: VoyagoColors.primary))
                      : users.isEmpty
                          ? const Center(
                              child: Text("Tu n'as bloqué personne.", style: TextStyle(color: VoyagoColors.muted)),
                            )
                          : ListView(
                              children: [
                                for (final u in users)
                                  ListTile(
                                    leading: AuthorAvatar(
                                      picture: u['picture']?.toString(),
                                      emoji: u['avatar_emoji']?.toString() ?? '🧭',
                                    ),
                                    title: Text(
                                      (u['pseudo']?.toString().isNotEmpty ?? false)
                                          ? u['pseudo'].toString()
                                          : u['name']?.toString() ?? 'Voyageur',
                                      style: const TextStyle(color: VoyagoColors.text),
                                    ),
                                    trailing: TextButton(
                                      onPressed: () => _unblock(u),
                                      child: const Text('Débloquer'),
                                    ),
                                  ),
                              ],
                            ),
            ),
          ],
        ),
      ),
    );
  }
}
