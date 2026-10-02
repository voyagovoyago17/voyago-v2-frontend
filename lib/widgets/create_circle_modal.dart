import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart' as ep;
import 'package:animated_emoji/animated_emoji.dart';
import '../providers/community_provider.dart';
import '../data/countries_data.dart';
import '../services/destination_service.dart';
import '../theme.dart';

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
      builder: (ctx) => _CountryPickerSheet(currentCountry: _selectedCountry),
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
        builder: (ctx) => _CountryPickerSheet(currentCountry: _selectedCountry),
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
      builder: (ctx) => _CircleCityPickerSheet(
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
                          child: _SelectFieldCard(
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
                          child: _SelectFieldCard(
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

// =========================================================================
// WIDGETS SÉLECTEURS DE PAYS ET DE VILLE POUR LA CRÉATION DE TRIBU
// =========================================================================

class _SelectFieldCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String sublabel;
  final String? flag;
  final bool isSelected;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _SelectFieldCard({
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

class _CountryPickerSheet extends StatefulWidget {
  final String currentCountry;

  const _CountryPickerSheet({required this.currentCountry});

  @override
  State<_CountryPickerSheet> createState() => _CountryPickerSheetState();
}

class _CountryPickerSheetState extends State<_CountryPickerSheet> {
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

class _CircleCityPickerSheet extends StatefulWidget {
  final String? countryName;
  final String currentCity;

  const _CircleCityPickerSheet({
    this.countryName,
    required this.currentCity,
  });

  @override
  State<_CircleCityPickerSheet> createState() => _CircleCityPickerSheetState();
}

class _CircleCityPickerSheetState extends State<_CircleCityPickerSheet> {
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



