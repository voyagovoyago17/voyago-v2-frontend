import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../api/api.dart';
import '../core/utils/form_validators.dart';
import '../providers/auth_provider.dart';
import '../providers/trips_provider.dart';
import '../services/destination_service.dart';
import '../theme.dart';
import '../widgets/auth_bottom_sheet.dart';
import '../widgets/travel_calendar_picker.dart';
import '../widgets/weather_flight_scene.dart';

class ConfigureScreen extends ConsumerStatefulWidget {
  final List<String> selectedInterests;

  const ConfigureScreen({super.key, required this.selectedInterests});

  @override
  ConsumerState<ConfigureScreen> createState() => _ConfigureScreenState();
}

class _ConfigureScreenState extends ConsumerState<ConfigureScreen> {
  final _destinationCtrl = TextEditingController();
  final _focusNode = FocusNode();

  // Selected destination metadata
  String? _selectedCity;
  String? _selectedCountry;
  String? _selectedCountryCode;

  // Autocomplete state
  List<DestinationItem> _suggestions = [];
  bool _isSearchingDestinations = false;
  Timer? _debounceTimer;
  bool _showSuggestions = false;

  // Travel dates & duration
  DateTime? _startDate;
  DateTime? _endDate;
  int _durationDays = 5;

  // Pace: 1 = tranquille, 2 = equilibre, 3 = intensif
  int _paceStep = 2; // default = equilibre

  // Transports & Budget
  final Set<String> _transports = {'marche'};
  String _budget = 'moyen';

  // State
  bool _isGenerating = false;
  String? _error;

  static const _paceQuotes = {
    1: '« Tranquille : Rythme doux, visites contemplatives et pauses détente régulières. »',
    2: '« Équilibré : Le savant dosage entre visites incontournables et moments de flânerie. »',
    3: '« Intensif : Un itinéraire dynamique pour explorer un maximum de merveilles sans temps mort. »',
  };

  static const _paceLabels = {
    1: 'Tranquille',
    2: 'Équilibré',
    3: 'Intensif',
  };

  static const _transportOptions = [
    ('marche', 'Marche', '🚶'),
    ('velo', 'Vélo', '🚲'),
    ('transport', 'Transport', '🚌'),
    ('voiture', 'Voiture', '🚗'),
    ('bateau', 'Bateau', '⛵'),
  ];

  static const _budgets = [
    ('economique', 'Économique', '💰'),
    ('moyen', 'Moyen', '💳'),
    ('luxe', 'Luxe', '💎'),
  ];

  @override
  void initState() {
    super.initState();
    _suggestions = DestinationService.popularDestinations;

    _destinationCtrl.addListener(_onDestinationChanged);
    _focusNode.addListener(() {
      setState(() {
        _showSuggestions = _focusNode.hasFocus;
      });
    });
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _destinationCtrl.removeListener(_onDestinationChanged);
    _destinationCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _onDestinationChanged() {
    _debounceTimer?.cancel();
    final query = _destinationCtrl.text.trim();

    _debounceTimer = Timer(const Duration(milliseconds: 250), () async {
      if (!mounted) return;
      setState(() => _isSearchingDestinations = true);
      try {
        final results = await DestinationService.instance.search(query);
        if (mounted) {
          setState(() {
            _suggestions = results;
            _isSearchingDestinations = false;
          });
        }
      } catch (_) {
        if (mounted) setState(() => _isSearchingDestinations = false);
      }
    });
  }

  void _selectDestination(DestinationItem item) {
    setState(() {
      _destinationCtrl.text = item.fullTitle;
      _selectedCity = item.name;
      _selectedCountry = item.country;
      _selectedCountryCode = item.countryCode;
      _showSuggestions = false;
      _focusNode.unfocus();
    });
  }

  String get _currentPaceKey {
    switch (_paceStep) {
      case 1:
        return 'tranquille';
      case 3:
        return 'intensif';
      default:
        return 'equilibre';
    }
  }

  Future<void> _generate() async {
    final destinationText = _destinationCtrl.text.trim();
    final destError = FormValidators.validateDestination(destinationText);
    if (destError != null) {
      setState(() => _error = destError);
      return;
    }
    if (_transports.isEmpty) {
      setState(() => _error = 'Veuillez sélectionner au moins un moyen de transport');
      return;
    }

    // Auth check modal if user is not logged in
    final authState = ref.read(authProvider);
    if (!authState.isLoggedIn) {
      final loggedIn = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => const AuthBottomSheet(
          title: 'Finalisez votre voyage avec Voyagooo ! 🦜',
          subtitle: 'Connectez-vous ou créez votre compte pour sauvegarder cet itinéraire sur votre profil.',
        ),
      );

      if (loggedIn != true || !mounted) {
        return;
      }
    }

    setState(() {
      _isGenerating = true;
      _error = null;
    });

    try {
      final currentAuth = ref.read(authProvider);
      final userId = currentAuth.user?.userId;

      final startDateStr = _startDate != null
          ? DateFormat('yyyy-MM-dd').format(_startDate!)
          : null;
      final endDateStr = _endDate != null
          ? DateFormat('yyyy-MM-dd').format(_endDate!)
          : null;

      final trip = await ref.read(tripGeneratorProvider.notifier).generate(
            destination: destinationText,
            durationDays: _durationDays,
            pace: _currentPaceKey,
            budget: _budget,
            transports: _transports.toList(),
            interests: widget.selectedInterests,
            startDate: startDateStr,
            endDate: endDateStr,
            city: _selectedCity,
            country: _selectedCountry,
            countryCode: _selectedCountryCode,
            userId: userId,
          );

      if (mounted) {
        context.go('/itinerary/${trip.id}', extra: trip);
      }
    } on ApiException catch (e) {
      if (e.statusCode == 402) {
        if (mounted) context.go('/pricing');
        return;
      }
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) {
        setState(() => _error = 'Erreur lors de la génération: ${e.toString()}');
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWide = MediaQuery.of(context).size.width >= 860;

    return Scaffold(
      backgroundColor: VoyagoColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/swipe'),
        ),
        title: const Text('Configurez votre voyage'),
      ),
      body: _isGenerating
          ? _buildLoading()
          : GestureDetector(
              onTap: () {
                if (_showSuggestions) {
                  setState(() => _showSuggestions = false);
                  _focusNode.unfocus();
                }
              },
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 960),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        // Headline matching mockup
                        _buildHeadline(),
                        const SizedBox(height: 24),

                        if (_error != null) ...[
                          _ErrorBox(message: _error!),
                          const SizedBox(height: 20),
                        ],

                        // Main Card
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: VoyagoColors.surface,
                            borderRadius: BorderRadius.circular(24),
                            border: Border.all(color: VoyagoColors.cardBorder),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withOpacity(0.3),
                                blurRadius: 20,
                                offset: const Offset(0, 10),
                              ),
                            ],
                          ),
                          child: isWide
                              ? Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(child: _buildLeftColumn()),
                                    const SizedBox(width: 32),
                                    Expanded(child: _buildRightColumn()),
                                  ],
                                )
                              : Column(
                                  crossAxisAlignment: CrossAxisAlignment.stretch,
                                  children: [
                                    _buildLeftColumn(),
                                    const SizedBox(height: 32),
                                    const Divider(color: VoyagoColors.cardBorder),
                                    const SizedBox(height: 24),
                                    _buildRightColumn(),
                                  ],
                                ),
                        ),
                        const SizedBox(height: 36),

                        // Glowing Magic Generate Button
                        _buildGenerateButton(),
                        const SizedBox(height: 12),
                        const Text(
                          'Prend environ 5 secondes pour créer votre aventure sur mesure.',
                          style: TextStyle(
                            color: VoyagoColors.muted,
                            fontSize: 12,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),

                        // Trust Badges matching mockup footer
                        _buildTrustBadges(),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }

  Widget _buildHeadline() {
    return Column(
      children: [
        if (widget.selectedInterests.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: VoyagoColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: VoyagoColors.primary.withOpacity(0.3)),
            ),
            child: Text(
              '✨ ${widget.selectedInterests.length} intérêt${widget.selectedInterests.length > 1 ? 's' : ''} sélectionné${widget.selectedInterests.length > 1 ? 's' : ''}',
              style: const TextStyle(
                color: VoyagoColors.primaryLight,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        const Text(
          'Planifiez votre prochaine aventure',
          style: TextStyle(
            color: VoyagoColors.text,
            fontSize: 28,
            fontWeight: FontWeight.w900,
            letterSpacing: -0.5,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        const Text(
          'Définissez votre destination et vos dates pour obtenir un itinéraire IA en quelques secondes.',
          style: TextStyle(
            color: VoyagoColors.muted,
            fontSize: 15,
            height: 1.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildLeftColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Destination Search Section
        const _FieldLabel('OÙ PARTEZ-VOUS ?'),
        const SizedBox(height: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _destinationCtrl,
              focusNode: _focusNode,
              style: const TextStyle(color: VoyagoColors.text, fontSize: 15),
              decoration: InputDecoration(
                hintText: 'Entrez une ville ou un pays (ex: Conakry, Paris, Tokyo...)',
                hintStyle: const TextStyle(color: VoyagoColors.muted, fontSize: 14),
                prefixIcon: const Icon(
                  Icons.location_on,
                  color: VoyagoColors.primary,
                  size: 22,
                ),
                suffixIcon: _isSearchingDestinations
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: Padding(
                          padding: EdgeInsets.all(12),
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: VoyagoColors.primary,
                          ),
                        ),
                      )
                    : _destinationCtrl.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear, color: VoyagoColors.muted, size: 18),
                            onPressed: () {
                              _destinationCtrl.clear();
                              setState(() {
                                _selectedCity = null;
                                _selectedCountry = null;
                                _selectedCountryCode = null;
                              });
                            },
                          )
                        : null,
              ),
            ),

            // Liste de suggestions d'autocomplétion (parfaitement visible, sans coupure)
            if (_showSuggestions && _suggestions.isNotEmpty) ...[
              const SizedBox(height: 8),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF1E2230),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: VoyagoColors.primary, width: 1.5),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                constraints: const BoxConstraints(maxHeight: 260),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(15),
                  child: ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    shrinkWrap: true,
                    itemCount: _suggestions.length,
                    separatorBuilder: (ctx, i) => Divider(
                      color: VoyagoColors.cardBorder.withValues(alpha: 0.5),
                      height: 1,
                    ),
                    itemBuilder: (context, index) {
                      final item = _suggestions[index];
                      return ListTile(
                        dense: true,
                        leading: Container(
                          width: 36,
                          height: 36,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.06),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            item.flagEmoji,
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        title: Text(
                          item.name,
                          style: const TextStyle(
                            color: VoyagoColors.text,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        subtitle: Text(
                          item.subtitle,
                          style: const TextStyle(
                            color: VoyagoColors.muted,
                            fontSize: 12,
                          ),
                        ),
                        trailing: const Icon(
                          Icons.north_west,
                          size: 14,
                          color: VoyagoColors.primary,
                        ),
                        onTap: () => _selectDestination(item),
                      );
                    },
                  ),
                ),
              ),
            ],

            // Popular Quick Chips
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Text(
                  'Populaire : ',
                  style: TextStyle(
                    color: VoyagoColors.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: DestinationService.popularDestinations.map((dest) {
                        final isCurrent = _destinationCtrl.text.toLowerCase().contains(dest.name.toLowerCase());
                        return GestureDetector(
                          onTap: () => _selectDestination(dest),
                          child: Container(
                            margin: const EdgeInsets.only(right: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: isCurrent
                                  ? VoyagoColors.primary.withValues(alpha: 0.2)
                                  : VoyagoColors.background,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: isCurrent
                                    ? VoyagoColors.primary
                                    : VoyagoColors.cardBorder,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(dest.flagEmoji, style: const TextStyle(fontSize: 12)),
                                const SizedBox(width: 4),
                                Text(
                                  dest.name,
                                  style: TextStyle(
                                    color: isCurrent
                                        ? VoyagoColors.primaryLight
                                        : VoyagoColors.text,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 28),

        // Pace Section with Slider & Dynamic Quote
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _FieldLabel('RYTHME DU VOYAGE'),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: VoyagoColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: VoyagoColors.primary.withOpacity(0.3)),
              ),
              child: Text(
                _paceLabels[_paceStep]!,
                style: const TextStyle(
                  color: VoyagoColors.primaryLight,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: VoyagoColors.primary,
            inactiveTrackColor: VoyagoColors.cardBorder,
            thumbColor: VoyagoColors.primary,
            overlayColor: VoyagoColors.primary.withOpacity(0.2),
            trackHeight: 6,
          ),
          child: Slider(
            value: _paceStep.toDouble(),
            min: 1,
            max: 3,
            divisions: 2,
            onChanged: (val) => setState(() => _paceStep = val.round()),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () => setState(() => _paceStep = 1),
                child: Text(
                  'Tranquille',
                  style: TextStyle(
                    color: _paceStep == 1 ? VoyagoColors.primaryLight : VoyagoColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _paceStep = 2),
                child: Text(
                  'Équilibré',
                  style: TextStyle(
                    color: _paceStep == 2 ? VoyagoColors.primaryLight : VoyagoColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _paceStep = 3),
                child: Text(
                  'Intensif',
                  style: TextStyle(
                    color: _paceStep == 3 ? VoyagoColors.primaryLight : VoyagoColors.muted,
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: VoyagoColors.background.withOpacity(0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: VoyagoColors.cardBorder.withOpacity(0.5)),
          ),
          child: Text(
            _paceQuotes[_paceStep]!,
            style: const TextStyle(
              color: VoyagoColors.muted,
              fontSize: 12,
              fontStyle: FontStyle.italic,
              height: 1.3,
            ),
          ),
        ),
        const SizedBox(height: 28),

        // Transports Section
        const _FieldLabel('MOYENS DE TRANSPORT'),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _transportOptions.map((t) {
            final (id, label, emoji) = t;
            final isSelected = _transports.contains(id);
            return FilterChip(
              label: Text('$emoji $label'),
              selected: isSelected,
              onSelected: (v) {
                setState(() {
                  if (v) {
                    _transports.add(id);
                  } else {
                    _transports.remove(id);
                  }
                });
              },
              selectedColor: VoyagoColors.primary.withOpacity(0.2),
              checkmarkColor: VoyagoColors.primary,
              backgroundColor: VoyagoColors.background,
              side: BorderSide(
                color: isSelected ? VoyagoColors.primary : VoyagoColors.cardBorder,
                width: isSelected ? 1.5 : 1,
              ),
              labelStyle: TextStyle(
                color: isSelected ? VoyagoColors.primaryLight : VoyagoColors.muted,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 13,
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 28),

        // Budget Section
        const _FieldLabel('BUDGET'),
        const SizedBox(height: 10),
        Row(
          children: _budgets.map((b) {
            final (id, label, emoji) = b;
            final isSelected = _budget == id;
            return Expanded(
              child: GestureDetector(
                onTap: () => setState(() => _budget = id),
                child: Container(
                  margin: const EdgeInsets.only(right: 8),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? VoyagoColors.primary.withOpacity(0.15)
                        : VoyagoColors.background,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isSelected
                          ? VoyagoColors.primary
                          : VoyagoColors.cardBorder,
                      width: isSelected ? 1.5 : 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(emoji, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(
                        label,
                        style: TextStyle(
                          color: isSelected
                              ? VoyagoColors.primaryLight
                              : VoyagoColors.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildRightColumn() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _FieldLabel('DATES DU VOYAGE'),
        const SizedBox(height: 10),

        // Interactive Calendar Date Range Picker
        TravelCalendarPicker(
          initialStartDate: _startDate,
          initialEndDate: _endDate,
          onRangeChanged: (start, end, duration) {
            setState(() {
              _startDate = start;
              _endDate = end;
              _durationDays = duration;
            });
          },
        ),
        const SizedBox(height: 20),

        // Quick Duration fallback/slider
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Durée estimée',
              style: TextStyle(
                color: VoyagoColors.muted,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: VoyagoColors.primary.withOpacity(0.15),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: VoyagoColors.primary.withOpacity(0.3)),
              ),
              child: Text(
                '$_durationDays jour${_durationDays > 1 ? 's' : ''}',
                style: const TextStyle(
                  color: VoyagoColors.primaryLight,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: VoyagoColors.primary,
            inactiveTrackColor: VoyagoColors.cardBorder,
            thumbColor: VoyagoColors.primary,
            trackHeight: 4,
          ),
          child: Slider(
            value: _durationDays.toDouble(),
            min: 1,
            max: 30,
            divisions: 29,
            onChanged: (v) {
              setState(() {
                _durationDays = v.round();
                if (_startDate != null) {
                  _endDate = _startDate!.add(Duration(days: _durationDays - 1));
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGenerateButton() {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        boxShadow: [
          BoxShadow(
            color: VoyagoColors.primary.withOpacity(0.4),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _generate,
        style: ElevatedButton.styleFrom(
          backgroundColor: VoyagoColors.primary,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 44, vertical: 18),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(30),
          ),
          elevation: 0,
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.auto_awesome, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              'Générer avec l\'IA ✨',
              style: TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTrustBadges() {
    return const Wrap(
      spacing: 24,
      runSpacing: 12,
      alignment: WrapAlignment.center,
      children: [
        _TrustItem(icon: Icons.verified_user, label: 'Sécurisé & Fiable'),
        _TrustItem(icon: Icons.public, label: '150+ Pays supportés'),
        _TrustItem(icon: Icons.bolt, label: 'Ultra-rapide'),
      ],
    );
  }

  Widget _buildLoading() {
    final state = ref.watch(tripGeneratorProvider);
    return _TripGenerationLoader(
      progressMessage: state.progressMessage,
    );
  }
}

class _TravelFact {
  final String category;
  final IconData icon;
  final Color color;
  final String text;

  const _TravelFact({
    required this.category,
    required this.icon,
    required this.color,
    required this.text,
  });
}

class _TripGenerationLoader extends StatefulWidget {
  final String? progressMessage;

  const _TripGenerationLoader({this.progressMessage});

  @override
  State<_TripGenerationLoader> createState() => _TripGenerationLoaderState();
}

class _TripGenerationLoaderState extends State<_TripGenerationLoader> {
  Timer? _factTimer;
  final Random _random = Random();
  int _currentFactIndex = 0;

  static const List<_TravelFact> _travelFacts = [
    _TravelFact(
      category: 'Intelligence Artificielle',
      icon: Icons.auto_awesome,
      color: Color(0xFF10B981),
      text: 'Analyse fine de votre profil et affinage de votre carnet d’aventure personnalisé...',
    ),
    _TravelFact(
      category: 'Itinéraire Intelligent',
      icon: Icons.alt_route_rounded,
      color: Color(0xFF3B82F6),
      text: 'Calcul des trajets optimaux pour vous faire profiter au maximum de chaque journée.',
    ),
    _TravelFact(
      category: 'Pépites & Secrets Locaux',
      icon: Icons.diamond_outlined,
      color: Color(0xFFF59E0B),
      text: 'Dénichage d’adresses confidentielles et de trésors cachés hors des sentiers battus.',
    ),
    _TravelFact(
      category: 'Gastronomie Authentique',
      icon: Icons.restaurant_rounded,
      color: Color(0xFFEC4899),
      text: 'Repérage des spécialités locales et des meilleures tables recommandées par les habitants.',
    ),
    _TravelFact(
      category: 'Climat & Ensoleillement',
      icon: Icons.wb_sunny_rounded,
      color: Color(0xFFF59E0B),
      text: 'Synchronisation des activités suggérées avec les conditions météorologiques idéales.',
    ),
    _TravelFact(
      category: 'Panoramas & Spots Photos',
      icon: Icons.photo_camera_rounded,
      color: Color(0xFF8B5CF6),
      text: 'Identification des plus beaux points de vue aux heures dorées pour vos souvenirs.',
    ),
    _TravelFact(
      category: 'Rythme & Sérénité',
      icon: Icons.spa_rounded,
      color: Color(0xFF10B981),
      text: 'Équilibrage des découvertes culturelles et des pauses détente pour un séjour sans stress.',
    ),
    _TravelFact(
      category: 'Le Saviez-Vous ?',
      icon: Icons.lightbulb_outline_rounded,
      color: Color(0xFFEAB308),
      text: 'Planifier un voyage stimule la production de dopamine et booste le moral instantanément !',
    ),
    _TravelFact(
      category: 'Astuces & Mobilité',
      icon: Icons.explore_rounded,
      color: Color(0xFF06B6D4),
      text: 'Sélection des transports les plus agréables et astuces pour vous déplacer sereinement.',
    ),
    _TravelFact(
      category: 'Budget Optimisé',
      icon: Icons.savings_outlined,
      color: Color(0xFF10B981),
      text: 'Ajustement des suggestions pour tirer le meilleur parti de votre budget de voyage.',
    ),
    _TravelFact(
      category: 'Finitions de l’Aventure',
      icon: Icons.flight_takeoff_rounded,
      color: Color(0xFF3B82F6),
      text: 'Voyagooo assemble vos étapes dans un carnet de voyage dynamique et interactif...',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _currentFactIndex = _random.nextInt(_travelFacts.length);
    _startFactTimer();
  }

  void _startFactTimer() {
    _factTimer = Timer.periodic(const Duration(milliseconds: 3200), (timer) {
      if (!mounted) return;
      setState(() {
        int nextIndex;
        do {
          nextIndex = _random.nextInt(_travelFacts.length);
        } while (nextIndex == _currentFactIndex && _travelFacts.length > 1);
        _currentFactIndex = nextIndex;
      });
    });
  }

  @override
  void dispose() {
    _factTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fact = _travelFacts[_currentFactIndex];
    final screenWidth = MediaQuery.of(context).size.width;
    final videoBoxSize = (screenWidth * 0.58).clamp(190.0, 250.0);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Carte animée : le perroquet vole à travers la météo
              Container(
                width: videoBoxSize,
                height: videoBoxSize,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C1611),
                  borderRadius: BorderRadius.circular(28),
                  border: Border.all(
                    color: VoyagoColors.primary.withOpacity(0.35),
                    width: 1.5,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: VoyagoColors.primary.withOpacity(0.22),
                      blurRadius: 36,
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: Colors.black.withOpacity(0.55),
                      blurRadius: 20,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                clipBehavior: Clip.antiAlias,
                child: WeatherFlightScene(size: videoBoxSize),
              ),

              const SizedBox(height: 28),

              // Status Pill
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: VoyagoColors.primary.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: VoyagoColors.primary.withOpacity(0.3),
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(
                      width: 8,
                      height: 8,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: VoyagoColors.primary,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: VoyagoColors.primary.withOpacity(0.8),
                              blurRadius: 6,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    const Text(
                      'Création de votre voyage...',
                      style: TextStyle(
                        color: VoyagoColors.primary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 14),

              // Main Heading
              const Text(
                'Voyagooo prépare votre aventure ! 🦜',
                style: TextStyle(
                  color: VoyagoColors.text,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  letterSpacing: -0.3,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 8),

              if (widget.progressMessage != null &&
                  widget.progressMessage!.isNotEmpty) ...[
                Text(
                  widget.progressMessage!,
                  style: const TextStyle(
                    color: VoyagoColors.muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),
              ] else
                const SizedBox(height: 12),

              // Dynamic Randomized Travel Fact / Tip Card
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 450),
                transitionBuilder: (child, animation) {
                  return FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.0, 0.15),
                        end: Offset.zero,
                      ).animate(CurvedAnimation(
                        parent: animation,
                        curve: Curves.easeOutCubic,
                      )),
                      child: child,
                    ),
                  );
                },
                child: Container(
                  key: ValueKey<int>(_currentFactIndex),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: VoyagoColors.surface.withOpacity(0.75),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: fact.color.withOpacity(0.28),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: fact.color.withOpacity(0.06),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(fact.icon, size: 16, color: fact.color),
                          const SizedBox(width: 6),
                          Text(
                            fact.category.toUpperCase(),
                            style: TextStyle(
                              color: fact.color,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        fact.text,
                        style: const TextStyle(
                          color: VoyagoColors.text,
                          fontSize: 13,
                          height: 1.45,
                          fontWeight: FontWeight.w400,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // Indeterminate Mini Progress Bar
              SizedBox(
                width: 140,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: const LinearProgressIndicator(
                    backgroundColor: Color(0xFF1E2E25),
                    valueColor: AlwaysStoppedAnimation<Color>(VoyagoColors.primary),
                    minHeight: 3,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: VoyagoColors.text,
        fontSize: 12,
        fontWeight: FontWeight.w800,
        letterSpacing: 1.0,
      ),
    );
  }
}

class _TrustItem extends StatelessWidget {
  final IconData icon;
  final String label;

  const _TrustItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: VoyagoColors.muted, size: 16),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: VoyagoColors.muted,
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoyagoColors.coral.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoyagoColors.coral.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: VoyagoColors.coral, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: VoyagoColors.coral, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
