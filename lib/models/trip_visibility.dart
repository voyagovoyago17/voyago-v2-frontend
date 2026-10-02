import 'package:flutter/material.dart';

/// Qui peut voir un voyage (miroir du champ `visibility` du backend).
enum TripVisibility {
  private('private', 'Privé', 'Visible uniquement par toi', Icons.lock_outline),
  tribe('tribe', 'Ma tribu', 'Visible par les membres de tes cercles', Icons.groups_outlined),
  public('public', 'Public', 'Visible par toute la communauté : likes et partages', Icons.public);

  const TripVisibility(this.value, this.label, this.description, this.icon);

  final String value;
  final String label;
  final String description;
  final IconData icon;

  /// Les anciens voyages n'ont que `is_public` : on en déduit la visibilité.
  static TripVisibility fromJson(dynamic raw, {bool? isPublic}) {
    for (final v in TripVisibility.values) {
      if (v.value == raw) return v;
    }
    return isPublic == true ? TripVisibility.public : TripVisibility.private;
  }
}
