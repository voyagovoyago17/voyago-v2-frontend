import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../theme.dart';

/// Saisie d'un code à 6 chiffres en cases : clavier numérique, collage du code entier,
/// validation automatique au dernier chiffre et tremblement en cas d'erreur.
class OtpCodeField extends StatefulWidget {
  final int length;
  final ValueChanged<String> onCompleted;
  final ValueChanged<String>? onChanged;
  final bool enabled;
  final bool hasError;

  const OtpCodeField({
    super.key,
    this.length = 6,
    required this.onCompleted,
    this.onChanged,
    this.enabled = true,
    this.hasError = false,
  });

  @override
  State<OtpCodeField> createState() => OtpCodeFieldState();
}

class OtpCodeFieldState extends State<OtpCodeField> with SingleTickerProviderStateMixin {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  late final AnimationController _shake =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 420));

  /// Vide les cases et remet le curseur (après une erreur ou un renvoi de code)
  void clear() {
    _controller.clear();
    _focus.requestFocus();
    setState(() {});
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && widget.enabled) _focus.requestFocus();
    });
  }

  @override
  void didUpdateWidget(covariant OtpCodeField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.hasError && !oldWidget.hasError) {
      _shake.forward(from: 0);
      HapticFeedback.heavyImpact();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    _shake.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final code = _controller.text;
    return AnimatedBuilder(
      animation: _shake,
      builder: (context, child) => Transform.translate(
        offset: Offset(math.sin(_shake.value * math.pi * 6) * 10 * (1 - _shake.value), 0),
        child: child,
      ),
      child: GestureDetector(
        onTap: () => _focus.requestFocus(),
        child: Stack(
          children: [
            // Champ réel invisible : gère le clavier, le collage et l'autoremplissage SMS/e-mail
            Opacity(
              opacity: 0,
              child: TextField(
                controller: _controller,
                focusNode: _focus,
                enabled: widget.enabled,
                keyboardType: TextInputType.number,
                autofillHints: const [AutofillHints.oneTimeCode],
                maxLength: widget.length,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                onChanged: (value) {
                  setState(() {});
                  widget.onChanged?.call(value);
                  if (value.length == widget.length) widget.onCompleted(value);
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (var i = 0; i < widget.length; i++) _box(i, code),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _box(int i, String code) {
    final filled = i < code.length;
    final active = _focus.hasFocus && i == code.length.clamp(0, widget.length - 1);
    final borderColor = widget.hasError
        ? VoyagoColors.coral
        : active
            ? VoyagoColors.primary
            : filled
                ? VoyagoColors.primary.withValues(alpha: 0.5)
                : VoyagoColors.cardBorder;
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 46,
      height: 56,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: VoyagoColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderColor, width: active ? 2 : 1.2),
      ),
      child: Text(
        filled ? code[i] : '',
        style: const TextStyle(color: VoyagoColors.text, fontSize: 24, fontWeight: FontWeight.bold),
      ),
    );
  }
}
