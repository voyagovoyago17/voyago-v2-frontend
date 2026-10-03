/// Valise du voyage : objets à emporter, cochés par le voyageur.
class PackingItem {
  final String id;
  final String label;
  final bool essential;
  final String? reason;
  final bool packed;
  final bool custom;

  const PackingItem({
    required this.id,
    required this.label,
    this.essential = false,
    this.reason,
    this.packed = false,
    this.custom = false,
  });

  factory PackingItem.fromJson(Map<String, dynamic> json) => PackingItem(
        id: json['id']?.toString() ?? '',
        label: json['label']?.toString() ?? '',
        essential: json['essential'] == true,
        reason: (json['reason']?.toString().trim().isEmpty ?? true) ? null : json['reason'].toString(),
        packed: json['packed'] == true,
        custom: json['custom'] == true,
      );

  PackingItem copyWith({bool? packed}) =>
      PackingItem(id: id, label: label, essential: essential, reason: reason, packed: packed ?? this.packed, custom: custom);
}

class PackingCategory {
  final String key;
  final String title;
  final List<PackingItem> items;

  const PackingCategory({required this.key, required this.title, required this.items});

  factory PackingCategory.fromJson(Map<String, dynamic> json) => PackingCategory(
        key: json['key']?.toString() ?? 'divers',
        title: json['title']?.toString() ?? 'Divers',
        items: (json['items'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PackingItem.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  int get packedCount => items.where((i) => i.packed).length;

  /// Icône 3D de la catégorie (assets/icons3d)
  String get icon3d => switch (key) {
        'documents' => 'assets/icons3d/id_card.png',
        'argent' => 'assets/icons3d/credit_card.png',
        'vetements' => 'assets/icons3d/tshirt.png',
        'chaussures' => 'assets/icons3d/hiking_boot.png',
        'hygiene' => 'assets/icons3d/toothbrush.png',
        'sante' => 'assets/icons3d/pill.png',
        'electronique' => 'assets/icons3d/plug.png',
        'meteo' => 'assets/icons3d/umbrella.png',
        'activites' => 'assets/icons3d/camera.png',
        _ => 'assets/icons3d/backpack.png',
      };
}

class PackingList {
  final String tripId;
  final List<PackingCategory> categories;

  const PackingList({required this.tripId, required this.categories});

  factory PackingList.fromJson(Map<String, dynamic> json) => PackingList(
        tripId: json['trip_id']?.toString() ?? '',
        categories: (json['categories'] as List? ?? [])
            .whereType<Map>()
            .map((e) => PackingCategory.fromJson(Map<String, dynamic>.from(e)))
            .toList(),
      );

  List<PackingItem> get items => [for (final c in categories) ...c.items];
  int get total => items.length;
  int get packedCount => items.where((i) => i.packed).length;
  bool get ready => total > 0 && packedCount == total;
  double get progress => total == 0 ? 0 : packedCount / total;

  PackingList withItem(String itemId, bool packed) => PackingList(
        tripId: tripId,
        categories: [
          for (final c in categories)
            PackingCategory(
              key: c.key,
              title: c.title,
              items: [for (final i in c.items) i.id == itemId ? i.copyWith(packed: packed) : i],
            ),
        ],
      );

  /// Catégorie d'un objet (icône du « dernier check »)
  PackingCategory? categoryOf(String itemId) {
    for (final c in categories) {
      if (c.items.any((i) => i.id == itemId)) return c;
    }
    return null;
  }
}
