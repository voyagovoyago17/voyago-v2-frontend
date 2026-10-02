import 'package:flutter/material.dart';
import '../data/countries_data.dart';
import '../services/destination_service.dart';
import '../theme.dart';

// =========================================================================
// SÉLECTEURS DE PAYS ET DE VILLE (création de tribu, voyage de tribu...)
// =========================================================================

/// Ouvre la liste des pays ; renvoie le nom affiché du pays choisi (ou null).
Future<String?> pickCountry(BuildContext context, {String currentCountry = ''}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CountryPickerSheet(currentCountry: currentCountry),
  );
}

/// Ouvre la liste des villes du pays ; renvoie la ville choisie (ou null).
Future<String?> pickCity(BuildContext context, {required String countryName, String currentCity = ''}) {
  return showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => CityPickerSheet(countryName: countryName, currentCity: currentCity),
  );
}

class LocationFieldCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;
  final String? flag;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const LocationFieldCard({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.sublabel,
    this.flag,
    required this.isSelected,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? iconColor.withValues(alpha: 0.1) : VoyagoColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? iconColor.withValues(alpha: 0.5) : VoyagoColors.cardBorder,
              width: 1.2,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: isSelected ? iconColor.withValues(alpha: 0.2) : Colors.white.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: flag != null && flag!.isNotEmpty
                      ? Text(flag!, style: const TextStyle(fontSize: 16))
                      : Icon(icon, color: isSelected ? iconColor : VoyagoColors.muted, size: 16),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? VoyagoColors.text : VoyagoColors.muted,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sublabel,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: isSelected ? iconColor : VoyagoColors.muted.withValues(alpha: 0.7),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              ),
              if (isSelected && onClear != null)
                GestureDetector(
                  onTap: onClear,
                  behavior: HitTestBehavior.opaque,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.1),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close_rounded, size: 14, color: VoyagoColors.muted),
                  ),
                )
              else
                Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 18,
                  color: VoyagoColors.muted.withValues(alpha: 0.7),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class CountryPickerSheet extends StatefulWidget {
  final String currentCountry;

  const CountryPickerSheet({super.key, required this.currentCountry});

  @override
  State<CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<CountryPickerSheet> {
  final _searchController = TextEditingController();
  List<CountryInfo> _allCountries = [];
  List<CountryInfo> _filteredCountries = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCountries();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCountries() async {
    try {
      final list = await CountriesData.getCountries();
      if (mounted) {
        setState(() {
          _allCountries = list;
          _filteredCountries = list;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final q = _searchController.text.trim().toLowerCase();
    setState(() {
      if (q.isEmpty) {
        _filteredCountries = _allCountries;
      } else {
        _filteredCountries = _allCountries.where((c) {
          return c.displayName.toLowerCase().contains(q) ||
              c.name.toLowerCase().contains(q) ||
              c.code.toLowerCase().contains(q);
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VoyagoColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sélectionner le Pays 🌍',
                        style: TextStyle(
                          color: VoyagoColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        _isLoading ? 'Chargement des pays...' : '${_allCountries.length} pays répertoriés',
                        style: const TextStyle(color: VoyagoColors.blue, fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: VoyagoColors.muted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: VoyagoColors.text),
              decoration: InputDecoration(
                hintText: 'Rechercher un pays...',
                hintStyle: TextStyle(color: VoyagoColors.muted.withValues(alpha: 0.7)),
                prefixIcon: const Icon(Icons.search_rounded, color: VoyagoColors.blue, size: 20),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: VoyagoColors.muted, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: VoyagoColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: VoyagoColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: VoyagoColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: VoyagoColors.blue, width: 1.5),
                ),
              ),
            ),
          ),
          const Divider(height: 16, color: VoyagoColors.cardBorder),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: VoyagoColors.blue, strokeWidth: 2),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: _filteredCountries.length,
                    itemBuilder: (context, index) {
                      final country = _filteredCountries[index];
                      final isSelected = widget.currentCountry.toLowerCase() == country.displayName.toLowerCase() ||
                          widget.currentCountry.toLowerCase() == country.name.toLowerCase();
                      return ListTile(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        tileColor: isSelected ? VoyagoColors.blue.withValues(alpha: 0.12) : null,
                        leading: Text(country.flag, style: const TextStyle(fontSize: 22)),
                        title: Text(
                          country.displayName,
                          style: TextStyle(
                            color: isSelected ? VoyagoColors.blue : VoyagoColors.text,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: country.frenchName.isNotEmpty && country.frenchName != country.name
                            ? Text(country.name, style: const TextStyle(color: VoyagoColors.muted, fontSize: 11))
                            : null,
                        trailing: isSelected
                            ? const Icon(Icons.check_circle_rounded, color: VoyagoColors.blue, size: 20)
                            : null,
                        onTap: () => Navigator.of(context).pop(country.displayName),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class CityPickerSheet extends StatefulWidget {
  final String? countryName;
  final String currentCity;

  const CityPickerSheet({
    super.key,
    this.countryName,
    required this.currentCity,
  });

  @override
  State<CityPickerSheet> createState() => _CityPickerSheetState();
}

class _CityPickerSheetState extends State<CityPickerSheet> {
  final _searchController = TextEditingController();
  List<String> _allCities = [];
  List<String> _filteredCities = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCities();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadCities() async {
    try {
      List<String> cities = [];
      if (widget.countryName != null && widget.countryName!.trim().isNotEmpty) {
        cities = await CountriesData.getCitiesForCountry(widget.countryName);
      }

      if (cities.isEmpty) {
        cities = DestinationService.popularDestinations.map((d) => d.name).toList();
      }

      if (mounted) {
        setState(() {
          _allCities = cities;
          _filteredCities = cities;
          _isLoading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _allCities = DestinationService.popularDestinations.map((d) => d.name).toList();
          _filteredCities = _allCities;
          _isLoading = false;
        });
      }
    }
  }

  void _onSearchChanged() {
    final query = _searchController.text.trim().toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredCities = _allCities;
      } else {
        _filteredCities = _allCities
            .where((city) => city.toLowerCase().contains(query))
            .toList();
      }
    });
  }

  String _cleanInput(String input) {
    final trimmed = input.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (trimmed.isEmpty) return '';
    return trimmed.split(' ').map((w) {
      if (w.isEmpty) return '';
      return w[0].toUpperCase() + w.substring(1).toLowerCase();
    }).join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final query = _searchController.text.trim();
    final clean = _cleanInput(query);
    final hasExactMatch = _filteredCities.any(
      (c) => c.toLowerCase() == clean.toLowerCase(),
    );
    final flag = widget.countryName != null ? CountriesData.getFlag(widget.countryName) : '🌍';

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      decoration: const BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        children: [
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: VoyagoColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 12, 12),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Sélectionner la Ville principale 🏢',
                        style: TextStyle(
                          color: VoyagoColors.text,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Row(
                        children: [
                          Text(flag, style: const TextStyle(fontSize: 13)),
                          const SizedBox(width: 4),
                          Text(
                            widget.countryName != null && widget.countryName!.isNotEmpty
                                ? '${widget.countryName!} · Villes officielles'
                                : 'Villes répertoriées',
                            style: const TextStyle(color: VoyagoColors.primary, fontSize: 12, fontWeight: FontWeight.w600),
                          ),
                          if (!_isLoading) ...[
                            const SizedBox(width: 6),
                            Text(
                              '(${_allCities.length})',
                              style: TextStyle(color: VoyagoColors.muted.withValues(alpha: 0.7), fontSize: 11),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded, color: VoyagoColors.muted),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: VoyagoColors.text),
              decoration: InputDecoration(
                hintText: _isLoading ? 'Chargement des villes...' : 'Rechercher une ville...',
                hintStyle: TextStyle(color: VoyagoColors.muted.withValues(alpha: 0.7)),
                prefixIcon: const Icon(Icons.search_rounded, color: VoyagoColors.primary, size: 20),
                suffixIcon: query.isNotEmpty
                    ? IconButton(
                        icon: const Icon(Icons.clear_rounded, color: VoyagoColors.muted, size: 18),
                        onPressed: () => _searchController.clear(),
                      )
                    : null,
                filled: true,
                fillColor: VoyagoColors.background,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: VoyagoColors.cardBorder),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: VoyagoColors.cardBorder),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: VoyagoColors.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const Divider(height: 16, color: VoyagoColors.cardBorder),
          Expanded(
            child: _isLoading
                ? const Center(
                    child: CircularProgressIndicator(color: VoyagoColors.primary, strokeWidth: 2),
                  )
                : ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    children: [
                      if (clean.length >= 2 && !hasExactMatch) ...[
                        ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                          tileColor: VoyagoColors.primary.withValues(alpha: 0.1),
                          leading: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: VoyagoColors.primary.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Icon(Icons.add_location_alt_rounded, color: VoyagoColors.primary, size: 18),
                          ),
                          title: Text(
                            'Utiliser "$clean"',
                            style: const TextStyle(color: VoyagoColors.primary, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                          subtitle: const Text(
                            'Ville personnalisée (orthographe nettoyée)',
                            style: TextStyle(color: VoyagoColors.muted, fontSize: 11),
                          ),
                          onTap: () => Navigator.of(context).pop(clean),
                        ),
                        const SizedBox(height: 6),
                      ],
                      if (_filteredCities.isEmpty && clean.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 32),
                          child: Center(
                            child: Text(
                              'Aucune ville trouvée',
                              style: TextStyle(color: VoyagoColors.muted),
                            ),
                          ),
                        ),
                      ..._filteredCities.map((city) {
                        final isSelected = widget.currentCity.toLowerCase() == city.toLowerCase();
                        return ListTile(
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          tileColor: isSelected ? VoyagoColors.primary.withValues(alpha: 0.12) : null,
                          leading: Icon(
                            Icons.location_city_rounded,
                            color: isSelected ? VoyagoColors.primary : VoyagoColors.muted,
                            size: 20,
                          ),
                          title: Text(
                            city,
                            style: TextStyle(
                              color: isSelected ? VoyagoColors.primary : VoyagoColors.text,
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                          trailing: isSelected
                              ? const Icon(Icons.check_circle_rounded, color: VoyagoColors.primary, size: 20)
                              : null,
                          onTap: () => Navigator.of(context).pop(city),
                        );
                      }),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}
