import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../api/api_exceptions.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import 'otp_code_field.dart';

/// Vérification de l'adresse e-mail par code à 6 chiffres.
/// [codeAlreadySent] : true juste après l'inscription (le serveur a déjà envoyé le code).
/// Renvoie true si l'adresse a été vérifiée.
Future<bool> showEmailVerificationSheet(BuildContext context, {bool codeAlreadySent = false}) async {
  final verified = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    backgroundColor: VoyagoColors.surface,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
    builder: (_) => _EmailVerificationSheet(codeAlreadySent: codeAlreadySent),
  );
  return verified ?? false;
}

class _EmailVerificationSheet extends ConsumerStatefulWidget {
  final bool codeAlreadySent;

  const _EmailVerificationSheet({required this.codeAlreadySent});

  @override
  ConsumerState<_EmailVerificationSheet> createState() => _EmailVerificationSheetState();
}

class _EmailVerificationSheetState extends ConsumerState<_EmailVerificationSheet> {
  final _otpKey = GlobalKey<OtpCodeFieldState>();
  bool _sending = false;
  bool _verifying = false;
  bool _hasError = false;
  String? _message;
  int _cooldown = 0;
  Timer? _timer;
  int? _xpAwarded; // non null = vérifié

  @override
  void initState() {
    super.initState();
    if (widget.codeAlreadySent) {
      _startCooldown(60);
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) => _sendCode());
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _timer?.cancel();
    setState(() => _cooldown = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown = (_cooldown - 1).clamp(0, 999));
      if (_cooldown == 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    setState(() {
      _sending = true;
      _message = null;
      _hasError = false;
    });
    try {
      final res = await ref.read(authProvider.notifier).sendEmailVerification();
      if (!mounted) return;
      if (res['already_verified'] == true) {
        await ref.read(authProvider.notifier).refreshMe();
        if (mounted) setState(() => _xpAwarded = 0);
        return;
      }
      _startCooldown((res['cooldown_seconds'] as num?)?.toInt() ?? 60);
      if (res['sent'] == false && res['message'] != null) {
        setState(() => _message = res['message'].toString());
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verify(String code) async {
    if (_verifying) return;
    setState(() {
      _verifying = true;
      _hasError = false;
      _message = null;
    });
    try {
      final xp = await ref.read(authProvider.notifier).confirmEmailVerification(code);
      HapticFeedback.mediumImpact();
      if (mounted) setState(() => _xpAwarded = xp);
    } on ApiException catch (e) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _message = e.message;
      });
      Future.delayed(const Duration(milliseconds: 500), () => _otpKey.currentState?.clear());
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final email = ref.watch(currentUserProvider)?.email ?? '';
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 12, 24, 24 + MediaQuery.of(context).viewInsets.bottom),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        child: _xpAwarded != null ? _buildSuccess() : _buildForm(email),
      ),
    );
  }

  Widget _buildForm(String email) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(width: 40, height: 4, decoration: BoxDecoration(color: VoyagoColors.cardBorder, borderRadius: BorderRadius.circular(2))),
        const SizedBox(height: 20),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: VoyagoColors.primary.withValues(alpha: 0.12), shape: BoxShape.circle),
          child: const Icon(Icons.mark_email_unread_rounded, color: VoyagoColors.primary, size: 32),
        ),
        const SizedBox(height: 14),
        const Text('Vérifie ton adresse e-mail',
            style: TextStyle(color: VoyagoColors.text, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text.rich(
          TextSpan(
            children: [
              const TextSpan(text: 'Saisis le code à 6 chiffres envoyé à\n'),
              TextSpan(text: email, style: const TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.w600)),
            ],
          ),
          textAlign: TextAlign.center,
          style: const TextStyle(color: VoyagoColors.muted, fontSize: 14, height: 1.4),
        ),
        const SizedBox(height: 22),
        OtpCodeField(key: _otpKey, onCompleted: _verify, enabled: !_verifying, hasError: _hasError),
        const SizedBox(height: 12),
        SizedBox(
          height: 22,
          child: _verifying
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: VoyagoColors.primary))
              : _message != null
                  ? Text(_message!,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: _hasError ? VoyagoColors.coral : VoyagoColors.muted, fontSize: 13))
                  : const SizedBox.shrink(),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _cooldown > 0 || _sending ? null : _sendCode,
          child: Text(
            _sending
                ? 'Envoi en cours…'
                : _cooldown > 0
                    ? 'Renvoyer le code dans $_cooldown s'
                    : 'Renvoyer le code',
          ),
        ),
        const Text('Pense à regarder dans tes spams 📬', style: TextStyle(color: VoyagoColors.muted, fontSize: 12)),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Plus tard', style: TextStyle(color: VoyagoColors.muted)),
        ),
      ],
    );
  }

  Widget _buildSuccess() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 20),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 600),
          curve: Curves.elasticOut,
          builder: (_, v, child) => Transform.scale(scale: v, child: child),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: const BoxDecoration(color: VoyagoColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.verified_rounded, color: Colors.white, size: 44),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Adresse e-mail vérifiée !',
            style: TextStyle(color: VoyagoColors.text, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        Text(
          _xpAwarded! > 0 ? 'Badge « Compte Vérifié » débloqué · +$_xpAwarded XP' : 'Ton compte est sécurisé.',
          style: const TextStyle(color: VoyagoColors.primary, fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 22),
        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: VoyagoColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: const Text('Continuer', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }
}

/// Badge affiché à côté de l'adresse e-mail : « Vérifié » ou « Vérifier » (cliquable).
class EmailVerifiedBadge extends ConsumerWidget {
  const EmailVerifiedBadge({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null || user.email == null) return const SizedBox.shrink();
    if (user.emailVerified) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: VoyagoColors.primary.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: VoyagoColors.primary.withValues(alpha: 0.5)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.verified_rounded, color: VoyagoColors.primary, size: 13),
            SizedBox(width: 4),
            Text('Vérifié', style: TextStyle(color: VoyagoColors.primary, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      );
    }
    if (!user.needsEmailVerification) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => showEmailVerificationSheet(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: VoyagoColors.orange.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: VoyagoColors.orange.withValues(alpha: 0.6)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline_rounded, color: VoyagoColors.orange, size: 13),
            SizedBox(width: 4),
            Text('Vérifier', style: TextStyle(color: VoyagoColors.orange, fontSize: 11, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}

/// Bandeau d'incitation pour les comptes dont l'e-mail n'est pas encore vérifié.
class EmailVerificationBanner extends ConsumerWidget {
  const EmailVerificationBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(currentUserProvider);
    if (user == null || !user.needsEmailVerification) return const SizedBox.shrink();
    return GestureDetector(
      onTap: () => showEmailVerificationSheet(context),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: VoyagoColors.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: VoyagoColors.orange.withValues(alpha: 0.5)),
        ),
        child: const Row(
          children: [
            Icon(Icons.mark_email_unread_rounded, color: VoyagoColors.orange),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Vérifie ton adresse e-mail',
                      style: TextStyle(color: VoyagoColors.text, fontWeight: FontWeight.bold)),
                  SizedBox(height: 2),
                  Text('Sécurise ton compte et gagne le badge « Compte Vérifié » (+5 XP)',
                      style: TextStyle(color: VoyagoColors.muted, fontSize: 12)),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: VoyagoColors.orange),
          ],
        ),
      ),
    );
  }
}
