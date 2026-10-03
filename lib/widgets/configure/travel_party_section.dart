import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../theme.dart';

/// Qui part et avec quel budget : informations facultatives qui rendent
/// l'itinéraire (lieux, activités, jeux) et la valise plus pertinents.
class TravelPartyValue {
  final String? party; // solo | couple | amis | famille
  final int adults;
  final List<int> childrenAges;
  final double? budgetAmount;
  final String currency;

  const TravelPartyValue({
    this.party,
    this.adults = 1,
    this.childrenAges = const [],
    this.budgetAmount,
    this.currency = 'EUR',
  });

  TravelPartyValue copyWith({
    String? party,
    int? adults,
    List<int>? childrenAges,
    double? Function()? budgetAmount,
    String? currency,
  }) =>
      TravelPartyValue(
        party: party ?? this.party,
        adults: adults ?? this.adults,
        childrenAges: childrenAges ?? this.childrenAges,
        budgetAmount: budgetAmount != null ? budgetAmount() : this.budgetAmount,
        currency: currency ?? this.currency,
      );

  /// Champs envoyés à la génération (seulement ce qui a été renseigné)
  Map<String, dynamic> toPayload() => {
        if (party != null) 'travel_party': party,
        if (party != null) 'adults': adults,
        if (party == 'famille' && childrenAges.isNotEmpty) 'children_ages': childrenAges,
        if (budgetAmount != null && budgetAmount! > 0) 'budget_amount': budgetAmount,
        if (budgetAmount != null && budgetAmount! > 0) 'currency': currency,
      };
}

class TravelPartySection extends StatefulWidget {
  final TravelPartyValue value;
  final ValueChanged<TravelPartyValue> onChanged;

  const TravelPartySection({super.key, required this.value, required this.onChanged});

  @override
  State<TravelPartySection> createState() => _TravelPartySectionState();
}

class _TravelPartySectionState extends State<TravelPartySection> {
  static const _parties = [
    ('solo', 'Solo', '🧍'),
    ('couple', 'Couple', '💑'),
    ('amis', 'Amis', '👯'),
    ('famille', 'Famille', '👨‍👩‍👧'),
  ];
  static const _currencies = ['EUR', 'XOF', 'XAF', 'USD', 'MAD', 'GBP', 'CAD', 'CHF'];

  late final TextEditingController _amount = TextEditingController(
    text: widget.value.budgetAmount != null ? widget.value.budgetAmount!.round().toString() : '',
  );

  TravelPartyValue get v => widget.value;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  void _selectParty(String id) {
    final adults = switch (id) {
      'solo' => 1,
      'couple' => 2,
      _ => v.party == id ? v.adults : 2,
    };
    widget.onChanged(v.copyWith(
      party: id,
      adults: adults,
      childrenAges: id == 'famille' ? (v.childrenAges.isEmpty ? [6] : v.childrenAges) : const [],
    ));
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _Label('QUI PART ?'),
        const SizedBox(height: 10),
        Row(
          children: [
            for (final (id, label, emoji) in _parties)
              Expanded(
                child: GestureDetector(
                  onTap: () => _selectParty(id),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    decoration: BoxDecoration(
                      color: v.party == id ? VoyagoColors.primary.withValues(alpha: 0.15) : VoyagoColors.background,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: v.party == id ? VoyagoColors.primary : VoyagoColors.cardBorder,
                        width: v.party == id ? 1.5 : 1,
                      ),
                    ),
                    child: Column(
                      children: [
                        Text(emoji, style: const TextStyle(fontSize: 20)),
                        const SizedBox(height: 4),
                        Text(label,
                            style: TextStyle(
                              color: v.party == id ? VoyagoColors.primaryLight : VoyagoColors.muted,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            )),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
        AnimatedSize(
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOutCubic,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (v.party == 'amis' || v.party == 'famille') ...[
                const SizedBox(height: 12),
                _Stepper(
                  label: 'Adultes',
                  value: v.adults,
                  min: 1,
                  max: 20,
                  onChanged: (n) => widget.onChanged(v.copyWith(adults: n)),
                ),
              ],
              if (v.party == 'famille') ...[
                const SizedBox(height: 8),
                _Stepper(
                  label: 'Enfants',
                  value: v.childrenAges.length,
                  min: 0,
                  max: 10,
                  onChanged: (n) {
                    final ages = [...v.childrenAges];
                    while (ages.length < n) {
                      ages.add(6);
                    }
                    widget.onChanged(v.copyWith(childrenAges: ages.take(n).toList()));
                  },
                ),
                if (v.childrenAges.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  const Text('Âge des enfants : on adapte les lieux, les activités et les jeux',
                      style: TextStyle(color: VoyagoColors.muted, fontSize: 11.5)),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (var i = 0; i < v.childrenAges.length; i++)
                        _AgeChip(
                          index: i,
                          age: v.childrenAges[i],
                          onChanged: (age) {
                            final ages = [...v.childrenAges]..[i] = age;
                            widget.onChanged(v.copyWith(childrenAges: ages));
                          },
                        ),
                    ],
                  ),
                ],
              ],
            ],
          ),
        ),
        const SizedBox(height: 22),
        const _Label('MON BUDGET (FACULTATIF)'),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _amount,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
                style: const TextStyle(color: VoyagoColors.text, fontSize: 15, fontWeight: FontWeight.w700),
                decoration: InputDecoration(
                  hintText: 'Ex : 1500',
                  hintStyle: const TextStyle(color: VoyagoColors.muted, fontWeight: FontWeight.w400),
                  helperText: 'Pour tout le voyage, hors billets aller-retour',
                  helperStyle: const TextStyle(color: VoyagoColors.muted, fontSize: 11),
                  filled: true,
                  fillColor: VoyagoColors.background,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: VoyagoColors.cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: VoyagoColors.cardBorder),
                  ),
                ),
                onChanged: (text) {
                  final amount = double.tryParse(text);
                  widget.onChanged(v.copyWith(budgetAmount: () => amount));
                },
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              margin: const EdgeInsets.only(bottom: 22),
              decoration: BoxDecoration(
                color: VoyagoColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: VoyagoColors.cardBorder),
              ),
              child: DropdownButton<String>(
                value: v.currency,
                underline: const SizedBox.shrink(),
                dropdownColor: VoyagoColors.surface,
                style: const TextStyle(color: VoyagoColors.primary, fontWeight: FontWeight.w800),
                items: [for (final c in _currencies) DropdownMenuItem(value: c, child: Text(c))],
                onChanged: (c) => widget.onChanged(v.copyWith(currency: c)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Label extends StatelessWidget {
  final String text;

  const _Label(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text,
        style: const TextStyle(color: VoyagoColors.muted, fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 1));
  }
}

class _Stepper extends StatelessWidget {
  final String label;
  final int value;
  final int min;
  final int max;
  final ValueChanged<int> onChanged;

  const _Stepper({required this.label, required this.value, required this.min, required this.max, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: VoyagoColors.background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: VoyagoColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: VoyagoColors.text, fontSize: 14, fontWeight: FontWeight.w600))),
          IconButton(
            onPressed: value > min ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline_rounded),
            color: VoyagoColors.primary,
            disabledColor: VoyagoColors.cardBorder,
          ),
          SizedBox(
            width: 26,
            child: Text('$value',
                textAlign: TextAlign.center,
                style: const TextStyle(color: VoyagoColors.text, fontSize: 16, fontWeight: FontWeight.w800)),
          ),
          IconButton(
            onPressed: value < max ? () => onChanged(value + 1) : null,
            icon: const Icon(Icons.add_circle_outline_rounded),
            color: VoyagoColors.primary,
            disabledColor: VoyagoColors.cardBorder,
          ),
        ],
      ),
    );
  }
}

class _AgeChip extends StatelessWidget {
  final int index;
  final int age;
  final ValueChanged<int> onChanged;

  const _AgeChip({required this.index, required this.age, required this.onChanged});

  static String label(int a) => a == 0 ? 'Bébé (- 1 an)' : '$a an${a > 1 ? 's' : ''}';

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(left: 10, right: 4),
      decoration: BoxDecoration(
        color: VoyagoColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoyagoColors.primary.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Enfant ${index + 1} : ', style: const TextStyle(color: VoyagoColors.muted, fontSize: 12)),
          DropdownButton<int>(
            value: age,
            underline: const SizedBox.shrink(),
            isDense: true,
            dropdownColor: VoyagoColors.surface,
            style: const TextStyle(color: VoyagoColors.primary, fontSize: 12.5, fontWeight: FontWeight.w800),
            items: [for (var a = 0; a <= 17; a++) DropdownMenuItem(value: a, child: Text(label(a)))],
            onChanged: (a) {
              if (a != null) onChanged(a);
            },
          ),
        ],
      ),
    );
  }
}
