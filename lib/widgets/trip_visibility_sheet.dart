import 'package:flutter/material.dart';
import '../api/api.dart';
import '../models/trip.dart';
import '../theme.dart';

/// Feuille de choix de la visibilité d'un voyage (Privé / Ma tribu / Public).
/// Renvoie la nouvelle visibilité une fois enregistrée, ou null si annulé.
Future<TripVisibility?> showTripVisibilitySheet(
  BuildContext context, {
  required Trip trip,
  TripsApi? api,
}) {
  return showModalBottomSheet<TripVisibility>(
    context: context,
    backgroundColor: VoyagoColors.surface,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _TripVisibilitySheet(trip: trip, api: api ?? TripsApi()),
  );
}

class _TripVisibilitySheet extends StatefulWidget {
  final Trip trip;
  final TripsApi api;

  const _TripVisibilitySheet({required this.trip, required this.api});

  @override
  State<_TripVisibilitySheet> createState() => _TripVisibilitySheetState();
}

class _TripVisibilitySheetState extends State<_TripVisibilitySheet> {
  TripVisibility? _saving;
  String? _error;

  Future<void> _select(TripVisibility visibility) async {
    if (_saving != null) return;
    if (visibility == widget.trip.visibility) {
      Navigator.of(context).pop();
      return;
    }
    setState(() {
      _saving = visibility;
      _error = null;
    });
    try {
      final saved = await widget.api.updateVisibility(widget.trip.id, visibility);
      if (mounted) Navigator.of(context).pop(saved);
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Impossible de modifier la visibilité');
    } finally {
      if (mounted) setState(() => _saving = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: VoyagoColors.cardBorder,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Qui peut voir ${widget.trip.destination} ?',
              style: const TextStyle(
                color: VoyagoColors.text,
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Seuls les voyages visibles peuvent être likés et partagés.',
              style: TextStyle(color: VoyagoColors.muted, fontSize: 13),
            ),
            const SizedBox(height: 16),
            for (final v in TripVisibility.values) _option(v),
            if (_error != null) ...[
              const SizedBox(height: 8),
              Text(_error!, style: const TextStyle(color: VoyagoColors.coral, fontSize: 13)),
            ],
          ],
        ),
      ),
    );
  }

  Widget _option(TripVisibility v) {
    final selected = v == widget.trip.visibility;
    final color = selected ? VoyagoColors.primary : VoyagoColors.muted;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => _select(v),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? VoyagoColors.primary : VoyagoColors.cardBorder,
              width: selected ? 2 : 1,
            ),
          ),
          child: Row(
            children: [
              Icon(v.icon, color: color),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      v.label,
                      style: const TextStyle(
                        color: VoyagoColors.text,
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(v.description, style: const TextStyle(color: VoyagoColors.muted, fontSize: 12)),
                  ],
                ),
              ),
              if (_saving == v)
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2, color: VoyagoColors.primary),
                )
              else if (selected)
                const Icon(Icons.check_circle, color: VoyagoColors.primary),
            ],
          ),
        ),
      ),
    );
  }
}
