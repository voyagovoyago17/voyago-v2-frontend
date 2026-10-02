import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as ep;
import 'package:animated_emoji/animated_emoji.dart';
import '../providers/community_provider.dart';
import '../data/countries_data.dart';
import '../theme.dart';
import 'location_pickers.dart';

class CreateCircleModal extends ConsumerStatefulWidget {
  const CreateCircleModal({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => const CreateCircleModal(),
    );
  }

  @override
  ConsumerState<CreateCircleModal> createState() => _CreateCircleModalState();
}

class _CreateCircleModalState extends ConsumerState<CreateCircleModal> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();

  String _selectedCountry = '';
  String _selectedCity = '';
  String _selectedEmoji = '🧭';
  String _selectedCategory = 'adventure';
  bool _isLoading = false;
  bool _isPublic = true;
  bool _showEmojiPicker = false;
  int _emojiPanelTab = 0; // 0 = Animés, 1 = Clavier complet

  static const List<AnimatedEmojiData> _animatedEmojisList = [
    AnimatedEmojis.sparkles,
    AnimatedEmojis.airplaneDeparture,
    AnimatedEmojis.airplaneArrival,
    AnimatedEmojis.rocket,
    AnimatedEmojis.cameraFlash,
    AnimatedEmojis.globeShowingEuropeAfrica,
    AnimatedEmojis.sunriseOverMountains,
    AnimatedEmojis.sunglassesFace,
    AnimatedEmojis.sunWithFace,
    AnimatedEmojis.umbrella,
    AnimatedEmojis.fire,
    AnimatedEmojis.partyPopper,
    AnimatedEmojis.partyingFace,
    AnimatedEmojis.heartEyes,
    AnimatedEmojis.starStruck,
    AnimatedEmojis.joy,
    AnimatedEmojis.heartFace,
    AnimatedEmojis.smile,
    AnimatedEmojis.wink,
    AnimatedEmojis.thumbsUp,
    AnimatedEmojis.twoHearts,
    AnimatedEmojis.eyes,
    AnimatedEmojis.trophy,
    AnimatedEmojis.clap,
    AnimatedEmojis.wave,
    AnimatedEmojis.victory,
  ];

  final List<String> _emojiOptions = [
    '🧭', '🏛️', '⛩️', '🚐', '🌊', '⛰️', '🥐', '🍷', '🚲', '⛺', '🏝️', '🎒'
  ];

  final Map<String, String> _categoryOptions = {
    'adventure': '⛩️ Aventure & Roadtrip',
    'culture': '🏛️ Culture & Histoire',
    'nature': '🌿 Nature & Bivouac',
    'food': '🍷 Gastronomie',
    'beach': '🏖️ Plage & Soleil',
  };

  final Map<String, String> _defaultCovers = {
    'adventure': 'https://images.unsplash.com/photo-1503899036084-c55cdd92da26?auto=format&fit=crop&w=1200&q=80',
    'culture': 'https://images.unsplash.com/photo-1552832230-c0197dd311b5?auto=format&fit=crop&w=1200&q=80',
    'nature': 'https://images.unsplash.com/photo-1523987355523-c7b5b0dd90a7?auto=format&fit=crop&w=1200&q=80',
    'food': 'https://images.unsplash.com/photo-1555396273-367ea4eb4db5?auto=format&fit=crop&w=1200&q=80',
    'beach': 'https://images.unsplash.com/photo-1507525428034-b723cf961d3e?auto=format&fit=crop&w=1200&q=80',
  };

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  void _insertEmoji(String emoji) {
    final text = _descriptionController.text;
    final selection = _descriptionController.selection;
    final newText = selection.start >= 0 && selection.end >= 0
        ? text.replaceRange(selection.start, selection.end, emoji)
        : text + emoji;
    final newCursorPos = (selection.start >= 0 ? selection.start : text.length) + emoji.length;
    _descriptionController.value = TextEditingValue(
      text: newText,
      selection: TextSelection.collapsed(offset: newCursorPos),
    );
  }

  Future<void> _openCountryPicker() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CountryPickerSheet(currentCountry: _selectedCountry),
    );

    if (picked != null && mounted) {
      setState(() {
        if (_selectedCountry != picked) {
          _selectedCountry = picked;
          _selectedCity = ''; // Réinitialise la ville pour cohérence géographique
        }
      });
    }
  }

  Future<void> _openCityPicker() async {
    // Si aucun pays n'est encore sélectionné, inviter à le choisir d'abord
    if (_selectedCountry.isEmpty) {
      final countryPicked = await showModalBottomSheet<String>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (ctx) => CountryPickerSheet(currentCountry: _selectedCountry),
      );

      if (countryPicked != null && mounted) {
        setState(() {
          _selectedCountry = countryPicked;
          _selectedCity = '';
        });
        if (mounted) {
          _openCityPicker();
        }
      }
      return;
    }

    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => CityPickerSheet(
        countryName: _selectedCountry,
        currentCity: _selectedCity,
      ),
    );

    if (picked != null && mounted) {
      setState(() {
        _selectedCity = picked;
      });
    }
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final coverUrl = _defaultCovers[_selectedCategory] ?? _defaultCovers['adventure']!;
      final controller = ref.read(communityControllerProvider);

      final circle = await controller.createCircle(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        avatarEmoji: _selectedEmoji,
        category: _selectedCategory,
        destinationCity: _selectedCity.trim().isEmpty ? null : _selectedCity.trim(),
        destinationCountry: _selectedCountry.trim().isEmpty ? null : _selectedCountry.trim(),
        coverImageUrl: coverUrl,
        tags: [
          _selectedCategory,
          if (_selectedCity.isNotEmpty) _selectedCity.trim().toLowerCase(),
          if (_selectedCountry.isNotEmpty) _selectedCountry.trim().toLowerCase(),
        ],
        isPublic: _isPublic,
      );

      if (mounted) {
        final inviteCode = circle.inviteCode;
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger.showSnackBar(
          SnackBar(
            backgroundColor: VoyagoColors.primary,
            duration: Duration(seconds: inviteCode != null ? 8 : 4),
            content: Text(
              inviteCode != null
                  ? '🔒 Cercle privé "${circle.name}" créé ! Code d\'invitation : $inviteCode'
                  : '🎉 Cercle "${circle.name}" créé avec succès !',
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
            ),
            action: inviteCode != null
                ? SnackBarAction(
                    label: 'Copier',
                    textColor: Colors.white,
                    onPressed: () => Clipboard.setData(ClipboardData(text: inviteCode)),
                  )
                : null,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: VoyagoColors.coral,
            content: Text('Erreur: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Widget _privacyOption({
    required bool isPublic,
    required IconData icon,
    required String title,
    required String subtitle,
  }) {
    final selected = _isPublic == isPublic;
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => setState(() => _isPublic = isPublic),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected ? VoyagoColors.primary.withValues(alpha: 0.12) : VoyagoColors.background,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? VoyagoColors.primary : VoyagoColors.cardBorder,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? VoyagoColors.primary : VoyagoColors.muted),
            const SizedBox(height: 6),
            Text(title, style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.bold)),
            const SizedBox(height: 2),
            Text(subtitle, style: const TextStyle(color: VoyagoColors.muted, fontSize: 11)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.9,
      ),
      decoration: const BoxDecoration(
        color: VoyagoColors.surface,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
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

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Créer une Tribu 🧭',
                        style: TextStyle(
                          color: VoyagoColors.text,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Rassemblez les voyageurs autour d\'une passion commune',
                        style: TextStyle(color: VoyagoColors.muted, fontSize: 13),
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

          const Divider(height: 1, color: VoyagoColors.cardBorder),

          // Form Body
          Flexible(
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 16, 20, 20 + bottomInset),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Emoji Selector
                    const Text(
                      'Émoticône de la Tribu',
                      style: TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    SizedBox(
                      height: 52,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _emojiOptions.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final emoji = _emojiOptions[index];
                          final isSelected = emoji == _selectedEmoji;
                          return GestureDetector(
                            onTap: () => setState(() => _selectedEmoji = emoji),
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              width: 48,
                              height: 48,
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? VoyagoColors.primary.withValues(alpha: 0.2)
                                    : VoyagoColors.background,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: isSelected ? VoyagoColors.primary : VoyagoColors.cardBorder,
                                  width: isSelected ? 2 : 1,
                                ),
                              ),
                              child: Center(
                                child: Text(emoji, style: const TextStyle(fontSize: 22)),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    const SizedBox(height: 18),

                    // Nom du cercle
                    const Text(
                      'Nom du Cercle *',
                      style: TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _nameController,
                      style: const TextStyle(color: VoyagoColors.text),
                      decoration: const InputDecoration(
                        hintText: 'Ex: Secrets de Rome & Toscane',
                        prefixIcon: Icon(Icons.stars_rounded, color: VoyagoColors.primary),
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 3) {
                          return 'Au moins 3 caractères requis';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 16),

                    // Catégorie
                    const Text(
                      'Catégorie',
                      style: TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _categoryOptions.entries.map((entry) {
                        final isSelected = _selectedCategory == entry.key;
                        return ChoiceChip(
                          label: Text(entry.value),
                          selected: isSelected,
                          onSelected: (selected) {
                            if (selected) setState(() => _selectedCategory = entry.key);
                          },
                          backgroundColor: VoyagoColors.background,
                          selectedColor: VoyagoColors.primary.withValues(alpha: 0.25),
                          labelStyle: TextStyle(
                            color: isSelected ? VoyagoColors.primary : VoyagoColors.muted,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            fontSize: 12,
                          ),
                          side: BorderSide(
                            color: isSelected ? VoyagoColors.primary : VoyagoColors.cardBorder,
                          ),
                        );
                      }).toList(),
                    ),

                    const SizedBox(height: 16),

                    // Destination (Pays & Ville principale)
                    const Row(
                      children: [
                        Icon(Icons.public_rounded, color: VoyagoColors.muted, size: 14),
                        SizedBox(width: 6),
                        Text(
                          'Destination & Territoire (Optionnel)',
                          style: TextStyle(color: VoyagoColors.muted, fontWeight: FontWeight.w600, fontSize: 12),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        // Sélecteur de Pays
                        Expanded(
                          child: LocationFieldCard(
                            icon: Icons.public_rounded,
                            iconColor: VoyagoColors.blue,
                            label: _selectedCountry.isNotEmpty ? _selectedCountry : 'Pays',
                            sublabel: _selectedCountry.isNotEmpty ? 'Pays sélectionné' : 'Choisir le pays',
                            flag: _selectedCountry.isNotEmpty ? CountriesData.getFlag(_selectedCountry) : null,
                            isSelected: _selectedCountry.isNotEmpty,
                            onTap: _openCountryPicker,
                            onClear: _selectedCountry.isNotEmpty
                                ? () => setState(() {
                                      _selectedCountry = '';
                                      _selectedCity = '';
                                    })
                                : null,
                          ),
                        ),
                        const SizedBox(width: 10),
                        // Sélecteur de Ville principale
                        Expanded(
                          child: LocationFieldCard(
                            icon: Icons.location_city_rounded,
                            iconColor: VoyagoColors.primary,
                            label: _selectedCity.isNotEmpty ? _selectedCity : 'Ville principale',
                            sublabel: _selectedCity.isNotEmpty
                                ? (_selectedCountry.isNotEmpty ? _selectedCountry : 'Ville sélectionnée')
                                : (_selectedCountry.isNotEmpty ? 'Choisir la ville' : 'Préciser le pays d\'abord'),
                            isSelected: _selectedCity.isNotEmpty,
                            onTap: _openCityPicker,
                            onClear: _selectedCity.isNotEmpty
                                ? () => setState(() => _selectedCity = '')
                                : null,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 18),

                    // Description & Esprit de la Tribu
                    Row(
                      children: [
                        const Expanded(
                          child: Text(
                            'Description & Esprit de la Tribu',
                            style: TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ),
                        InkWell(
                          onTap: () {
                            if (_showEmojiPicker) {
                              setState(() => _showEmojiPicker = false);
                            } else {
                              FocusScope.of(context).unfocus();
                              setState(() => _showEmojiPicker = true);
                            }
                          },
                          borderRadius: BorderRadius.circular(16),
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _showEmojiPicker
                                  ? VoyagoColors.primary.withValues(alpha: 0.18)
                                  : Colors.white.withValues(alpha: 0.06),
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                color: _showEmojiPicker ? VoyagoColors.primary : VoyagoColors.cardBorder,
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  _showEmojiPicker ? Icons.keyboard_rounded : Icons.emoji_emotions_outlined,
                                  size: 15,
                                  color: _showEmojiPicker ? VoyagoColors.primary : VoyagoColors.muted,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  _showEmojiPicker ? 'Clavier' : 'Émojis',
                                  style: TextStyle(
                                    color: _showEmojiPicker ? VoyagoColors.primary : VoyagoColors.muted,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 3,
                      style: const TextStyle(color: VoyagoColors.text),
                      onTap: () {
                        if (_showEmojiPicker) setState(() => _showEmojiPicker = false);
                      },
                      decoration: const InputDecoration(
                        hintText: 'Partagez vos astuces, itinéraires et meilleurs spots secrets...',
                      ),
                      validator: (value) {
                        if (value == null || value.trim().length < 10) {
                          return 'Au moins 10 caractères pour décrire la tribu';
                        }
                        return null;
                      },
                    ),
                    const SizedBox(height: 8),

                    // Bandeau des émojis animés rapides
                    SizedBox(
                      height: 38,
                      child: ListView.separated(
                        scrollDirection: Axis.horizontal,
                        itemCount: _animatedEmojisList.length,
                        separatorBuilder: (_, __) => const SizedBox(width: 8),
                        itemBuilder: (context, index) {
                          final emoji = _animatedEmojisList[index];
                          return Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => _insertEmoji(emoji.toUnicodeEmoji()),
                              borderRadius: BorderRadius.circular(10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: VoyagoColors.background,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: VoyagoColors.cardBorder),
                                ),
                                child: Center(
                                  child: AnimatedEmoji(
                                    emoji,
                                    size: 22,
                                    repeat: true,
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),

                    // Tiroir émoji dépliable (Animés + Clavier complet)
                    if (_showEmojiPicker) ...[
                      const SizedBox(height: 12),
                      Container(
                        height: 260,
                        decoration: BoxDecoration(
                          color: VoyagoColors.background,
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(color: VoyagoColors.cardBorder),
                        ),
                        child: Column(
                          children: [
                            Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
                              child: Row(
                                children: [
                                  ChoiceChip(
                                    label: const Text('✨ Émojis Animés'),
                                    selected: _emojiPanelTab == 0,
                                    onSelected: (val) {
                                      if (val) setState(() => _emojiPanelTab = 0);
                                    },
                                    backgroundColor: VoyagoColors.surface,
                                    selectedColor: VoyagoColors.primary.withValues(alpha: 0.2),
                                    labelStyle: TextStyle(
                                      color: _emojiPanelTab == 0 ? VoyagoColors.primary : VoyagoColors.muted,
                                      fontWeight: _emojiPanelTab == 0 ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                    side: BorderSide(
                                      color: _emojiPanelTab == 0 ? VoyagoColors.primary : VoyagoColors.cardBorder,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  ChoiceChip(
                                    label: const Text('😀 Clavier Complet'),
                                    selected: _emojiPanelTab == 1,
                                    onSelected: (val) {
                                      if (val) setState(() => _emojiPanelTab = 1);
                                    },
                                    backgroundColor: VoyagoColors.surface,
                                    selectedColor: VoyagoColors.primary.withValues(alpha: 0.2),
                                    labelStyle: TextStyle(
                                      color: _emojiPanelTab == 1 ? VoyagoColors.primary : VoyagoColors.muted,
                                      fontWeight: _emojiPanelTab == 1 ? FontWeight.bold : FontWeight.normal,
                                      fontSize: 12,
                                    ),
                                    side: BorderSide(
                                      color: _emojiPanelTab == 1 ? VoyagoColors.primary : VoyagoColors.cardBorder,
                                    ),
                                  ),
                                  const Spacer(),
                                  IconButton(
                                    icon: const Icon(Icons.close_rounded, size: 18, color: VoyagoColors.muted),
                                    onPressed: () => setState(() => _showEmojiPicker = false),
                                    padding: EdgeInsets.zero,
                                    constraints: const BoxConstraints(),
                                  ),
                                ],
                              ),
                            ),
                            const Divider(height: 1, color: VoyagoColors.cardBorder),
                            Expanded(
                              child: _emojiPanelTab == 0
                                  ? GridView.builder(
                                      padding: const EdgeInsets.all(12),
                                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 6,
                                        mainAxisSpacing: 10,
                                        crossAxisSpacing: 10,
                                      ),
                                      itemCount: _animatedEmojisList.length,
                                      itemBuilder: (context, index) {
                                        final emoji = _animatedEmojisList[index];
                                        return Material(
                                          color: Colors.transparent,
                                          child: InkWell(
                                            onTap: () => _insertEmoji(emoji.toUnicodeEmoji()),
                                            borderRadius: BorderRadius.circular(12),
                                            child: Container(
                                              decoration: BoxDecoration(
                                                color: VoyagoColors.surface,
                                                borderRadius: BorderRadius.circular(12),
                                                border: Border.all(color: VoyagoColors.cardBorder),
                                              ),
                                              child: Center(
                                                child: AnimatedEmoji(
                                                  emoji,
                                                  size: 30,
                                                  repeat: true,
                                                ),
                                              ),
                                            ),
                                          ),
                                        );
                                      },
                                    )
                                  : ep.EmojiPicker(
                                      textEditingController: _descriptionController,
                                      config: const ep.Config(
                                        height: 220,
                                        checkPlatformCompatibility: false,
                                        emojiViewConfig: ep.EmojiViewConfig(
                                          columns: 8,
                                          emojiSizeMax: 26,
                                          backgroundColor: VoyagoColors.background,
                                          buttonMode: ep.ButtonMode.MATERIAL,
                                        ),
                                        categoryViewConfig: ep.CategoryViewConfig(
                                          backgroundColor: VoyagoColors.surface,
                                          indicatorColor: VoyagoColors.primary,
                                          iconColorSelected: VoyagoColors.primary,
                                          iconColor: VoyagoColors.muted,
                                          backspaceColor: VoyagoColors.coral,
                                          tabBarHeight: 38,
                                        ),
                                        bottomActionBarConfig: ep.BottomActionBarConfig(
                                          backgroundColor: VoyagoColors.surface,
                                          buttonColor: VoyagoColors.surface,
                                          buttonIconColor: VoyagoColors.muted,
                                          showSearchViewButton: true,
                                          showBackspaceButton: true,
                                        ),
                                        searchViewConfig: ep.SearchViewConfig(
                                          backgroundColor: VoyagoColors.background,
                                          buttonIconColor: VoyagoColors.primary,
                                        ),
                                      ),
                                    ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: 16),

                    // Confidentialité
                    const Text(
                      'Confidentialité',
                      style: TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: _privacyOption(
                            isPublic: true,
                            icon: Icons.public,
                            title: 'Public',
                            subtitle: 'Visible par tous, chacun peut rejoindre',
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _privacyOption(
                            isPublic: false,
                            icon: Icons.lock_outline,
                            title: 'Privé',
                            subtitle: 'Sur invitation, avec un code',
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 52,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _submit,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: VoyagoColors.primary,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isLoading
                            ? const SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                              )
                            : const Text(
                                'Fonder ma Tribu 🚀',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
