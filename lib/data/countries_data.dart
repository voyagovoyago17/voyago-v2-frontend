import 'package:country_state_city/country_state_city.dart' as csc;

class CountryInfo {
  final String name;
  final String frenchName;
  final String code;
  final String flag;
  final List<String> cities;

  const CountryInfo({
    required this.name,
    this.frenchName = '',
    required this.code,
    required this.flag,
    this.cities = const [],
  });

  /// Nom d'affichage préféré (français si disponible, sinon nom international)
  String get displayName => frenchName.isNotEmpty ? frenchName : name;
}

class CountriesData {
  CountriesData._();

  static List<CountryInfo>? _cachedCountries;
  static final Map<String, List<String>> _cachedCitiesByCountryCode = {};

  static const Map<String, String> _frenchCountryNames = {
    'FR': 'France',
    'CI': 'Côte d\'Ivoire',
    'GN': 'Guinée',
    'SN': 'Sénégal',
    'ML': 'Mali',
    'MA': 'Maroc',
    'CM': 'Cameroun',
    'BJ': 'Bénin',
    'TG': 'Togo',
    'DZ': 'Algérie',
    'TN': 'Tunisie',
    'JP': 'Japon',
    'US': 'États-Unis',
    'CA': 'Canada',
    'GB': 'Royaume-Uni',
    'ES': 'Espagne',
    'IT': 'Italie',
    'DE': 'Allemagne',
    'BE': 'Belgique',
    'CH': 'Suisse',
    'PT': 'Portugal',
    'NL': 'Pays-Bas',
    'AE': 'Émirats Arabes Unis',
    'TH': 'Thaïlande',
    'ID': 'Indonésie',
    'BR': 'Brésil',
    'MX': 'Mexique',
    'ZA': 'Afrique du Sud',
    'TR': 'Turquie',
    'GR': 'Grèce',
    'EG': 'Égypte',
    'MG': 'Madagascar',
    'CD': 'RD Congo',
    'CG': 'Congo',
    'GA': 'Gabon',
    'NE': 'Niger',
    'BF': 'Burkina Faso',
    'MR': 'Mauritanie',
    'TD': 'Tchad',
    'RU': 'Russie',
    'CN': 'Chine',
    'KR': 'Corée du Sud',
    'IN': 'Inde',
    'AU': 'Australie',
    'NZ': 'Nouvelle-Zélande',
    'AR': 'Argentine',
    'CO': 'Colombie',
    'CL': 'Chili',
    'PE': 'Pérou',
    'VN': 'Vietnam',
    'PH': 'Philippines',
    'SG': 'Singapour',
    'MY': 'Malaisie',
    'SE': 'Suède',
    'NO': 'Norvège',
    'DK': 'Danemark',
    'FI': 'Finlande',
    'IE': 'Irlande',
    'AT': 'Autriche',
    'PL': 'Pologne',
    'LU': 'Luxembourg',
    'MC': 'Monaco',
    'HT': 'Haïti',
    'LB': 'Liban',
    'RW': 'Rwanda',
    'BI': 'Burundi',
    'DJ': 'Djibouti',
    'KM': 'Comores',
    'SC': 'Seychelles',
    'MU': 'Maurice',
    'CF': 'Centrafrique',
    'GQ': 'Guinée équatoriale',
    'GW': 'Guinée-Bissau',
    'CV': 'Cap-Vert',
    'ST': 'Sao Tomé-et-Principe',
  };

  /// Obtenir tous les pays du monde depuis la librairie Flutter `country_state_city`
  static Future<List<CountryInfo>> getCountries() async {
    if (_cachedCountries != null) {
      return _cachedCountries!;
    }

    try {
      final rawCountries = await csc.getAllCountries();
      final list = rawCountries.map((c) {
        final fr = _frenchCountryNames[c.isoCode] ?? '';
        return CountryInfo(
          name: c.name,
          frenchName: fr,
          code: c.isoCode,
          flag: c.flag.isNotEmpty ? c.flag : '🌍',
        );
      }).toList();

      // Trier : Pays francophones / majeurs en premier, puis ordre alphabétique
      const priorityCodes = [
        'FR', 'CI', 'GN', 'SN', 'ML', 'MA', 'CM', 'BJ', 'TG',
        'DZ', 'TN', 'BE', 'CH', 'CA', 'US', 'JP', 'ES', 'IT', 'DE', 'GB'
      ];

      list.sort((a, b) {
        final aPrio = priorityCodes.indexOf(a.code);
        final bPrio = priorityCodes.indexOf(b.code);
        if (aPrio != -1 && bPrio != -1) return aPrio.compareTo(bPrio);
        if (aPrio != -1) return -1;
        if (bPrio != -1) return 1;
        return a.displayName.compareTo(b.displayName);
      });

      _cachedCountries = list;
      return list;
    } catch (_) {
      // Fallback de secours si le chargement échoue
      return _fallbackCountries;
    }
  }

  /// Retrouve les informations d'un pays par son nom ou code
  static CountryInfo? findCountrySync(String? countryNameOrCode) {
    if (countryNameOrCode == null || countryNameOrCode.trim().isEmpty) return null;
    final clean = countryNameOrCode.trim().toLowerCase();

    final source = _cachedCountries ?? _fallbackCountries;
    for (final c in source) {
      if (c.code.toLowerCase() == clean ||
          c.name.toLowerCase() == clean ||
          c.displayName.toLowerCase() == clean ||
          c.displayName.toLowerCase().contains(clean) ||
          c.name.toLowerCase().contains(clean)) {
        return c;
      }
    }
    return null;
  }

  /// Obtenir le drapeau d'un pays
  static String getFlag(String? countryNameOrCode) {
    final info = findCountrySync(countryNameOrCode);
    return info?.flag ?? '🌍';
  }

  /// Obtenir toutes les villes du monde pour un pays donné via `country_state_city`
  static Future<List<String>> getCitiesForCountry(String? countryNameOrCode) async {
    if (countryNameOrCode == null || countryNameOrCode.trim().isEmpty) {
      return const [];
    }

    // Assurer que les pays sont chargés pour la résolution du code ISO
    await getCountries();
    final country = findCountrySync(countryNameOrCode);
    final isoCode = country?.code ?? countryNameOrCode.trim().toUpperCase();

    // Cache hit
    if (_cachedCitiesByCountryCode.containsKey(isoCode)) {
      return _cachedCitiesByCountryCode[isoCode]!;
    }

    try {
      final cities = await csc.getCountryCities(isoCode);
      final uniqueCities = cities
          .map((c) => c.name.trim())
          .where((name) => name.isNotEmpty)
          .toSet()
          .toList();

      uniqueCities.sort((a, b) => a.compareTo(b));

      _cachedCitiesByCountryCode[isoCode] = uniqueCities;
      return uniqueCities;
    } catch (_) {
      return const [];
    }
  }

  static final Map<String, List<csc.City>> _cachedRawCitiesByCountryCode = {};

  /// Coordonnées (latitude, longitude) d'une ville d'un pays, via `country_state_city`.
  /// Renvoie null si la ville est inconnue ou sans coordonnées.
  static Future<(double, double)?> findCityCoordinates(String? countryNameOrCode, String? cityName) async {
    if (countryNameOrCode == null || cityName == null || cityName.trim().isEmpty) return null;
    try {
      await getCountries();
      final isoCode = findCountrySync(countryNameOrCode)?.code ?? countryNameOrCode.trim().toUpperCase();
      final cities = _cachedRawCitiesByCountryCode[isoCode] ??= await csc.getCountryCities(isoCode);
      final target = cityName.trim().toLowerCase();
      for (final c in cities) {
        if (c.name.trim().toLowerCase() != target) continue;
        final lat = double.tryParse(c.latitude ?? '');
        final lng = double.tryParse(c.longitude ?? '');
        if (lat != null && lng != null) return (lat, lng);
      }
    } catch (_) {}
    return null;
  }

  static const List<CountryInfo> _fallbackCountries = [
    CountryInfo(name: 'France', frenchName: 'France', code: 'FR', flag: '🇫🇷'),
    CountryInfo(name: 'Cote D\'Ivoire (Ivory Coast)', frenchName: 'Côte d\'Ivoire', code: 'CI', flag: '🇨🇮'),
    CountryInfo(name: 'Guinea', frenchName: 'Guinée', code: 'GN', flag: '🇬🇳'),
    CountryInfo(name: 'Senegal', frenchName: 'Sénégal', code: 'SN', flag: '🇸🇳'),
    CountryInfo(name: 'Mali', frenchName: 'Mali', code: 'ML', flag: '🇲🇱'),
    CountryInfo(name: 'Morocco', frenchName: 'Maroc', code: 'MA', flag: '🇲🇦'),
    CountryInfo(name: 'Cameroon', frenchName: 'Cameroun', code: 'CM', flag: '🇨🇲'),
    CountryInfo(name: 'Benin', frenchName: 'Bénin', code: 'BJ', flag: '🇧🇯'),
    CountryInfo(name: 'Togo', frenchName: 'Togo', code: 'TG', flag: '🇹🇬'),
    CountryInfo(name: 'Algeria', frenchName: 'Algérie', code: 'DZ', flag: '🇩🇿'),
    CountryInfo(name: 'Tunisia', frenchName: 'Tunisie', code: 'TN', flag: '🇹🇳'),
    CountryInfo(name: 'Japan', frenchName: 'Japon', code: 'JP', flag: '🇯🇵'),
    CountryInfo(name: 'United States', frenchName: 'États-Unis', code: 'US', flag: '🇺🇸'),
    CountryInfo(name: 'Canada', frenchName: 'Canada', code: 'CA', flag: '🇨🇦'),
    CountryInfo(name: 'United Kingdom', frenchName: 'Royaume-Uni', code: 'GB', flag: '🇬🇧'),
    CountryInfo(name: 'Spain', frenchName: 'Espagne', code: 'ES', flag: '🇪🇸'),
    CountryInfo(name: 'Italy', frenchName: 'Italie', code: 'IT', flag: '🇮🇹'),
    CountryInfo(name: 'Germany', frenchName: 'Allemagne', code: 'DE', flag: '🇩🇪'),
    CountryInfo(name: 'Belgium', frenchName: 'Belgique', code: 'BE', flag: '🇧🇪'),
    CountryInfo(name: 'Switzerland', frenchName: 'Suisse', code: 'CH', flag: '🇨🇭'),
  ];
}
