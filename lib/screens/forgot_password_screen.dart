import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/api.dart';
import '../core/utils/form_validators.dart';
import '../providers/auth_provider.dart';
import '../theme.dart';
import '../widgets/otp_code_field.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _emailCtrl = TextEditingController();
  final _newPasswordCtrl = TextEditingController();
  final _confirmPasswordCtrl = TextEditingController();
  final _otpKey = GlobalKey<OtpCodeFieldState>();
  String _code = '';
  bool _isLoading = false;
  String? _error;
  String? _success;
  int _step = 1; // 1 = email, 2 = code + new password
  bool _obscurePassword = true;
  int _cooldown = 0;
  Timer? _cooldownTimer;

  @override
  void dispose() {
    _cooldownTimer?.cancel();
    _emailCtrl.dispose();
    _newPasswordCtrl.dispose();
    _confirmPasswordCtrl.dispose();
    super.dispose();
  }

  void _startCooldown(int seconds) {
    _cooldownTimer?.cancel();
    setState(() => _cooldown = seconds);
    _cooldownTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return t.cancel();
      setState(() => _cooldown = (_cooldown - 1).clamp(0, 999));
      if (_cooldown == 0) t.cancel();
    });
  }

  Future<void> _sendCode() async {
    final emailError = FormValidators.validateEmail(_emailCtrl.text);
    if (emailError != null) {
      setState(() => _error = emailError);
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      final res = await ref.read(authProvider.notifier).forgotPassword(_emailCtrl.text.trim());
      if (mounted) {
        setState(() {
          _step = 2;
          _code = '';
          _success = 'Si un compte existe pour ${_emailCtrl.text.trim()}, un code vient d\'y être envoyé 📬';
        });
        _otpKey.currentState?.clear();
        _startCooldown((res['cooldown_seconds'] as num?)?.toInt() ?? 60);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Erreur lors de l\'envoi du code');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resetPassword() async {
    final otpError = FormValidators.validateOtpCode(_code);
    if (otpError != null) {
      setState(() => _error = otpError);
      return;
    }
    final pwdError = FormValidators.validatePassword(_newPasswordCtrl.text);
    if (pwdError != null) {
      setState(() => _error = pwdError);
      return;
    }
    if (_newPasswordCtrl.text != _confirmPasswordCtrl.text) {
      setState(() => _error = 'Les deux mots de passe ne correspondent pas');
      return;
    }
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).resetPassword(
        email: _emailCtrl.text.trim(),
        code: _code,
        newPassword: _newPasswordCtrl.text,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Mot de passe modifié ! Connecte-toi avec ton nouveau mot de passe 🦜'),
            backgroundColor: VoyagoColors.primary,
          ),
        );
        context.go('/auth');
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Erreur lors de la réinitialisation');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VoyagoColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/auth'),
        ),
        title: const Text('Mot de passe oublié'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            Center(
              child: Image.asset(
                'assets/logo/voyago_parrot.png',
                height: 64,
                fit: BoxFit.contain,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              _step == 1 ? 'Réinitialiser votre mot de passe' : 'Entrez votre code',
              style: const TextStyle(
                color: VoyagoColors.text,
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _step == 1
                  ? 'Saisissez votre email pour recevoir un code de réinitialisation'
                  : 'Saisis le code à 6 chiffres reçu par e-mail, puis ton nouveau mot de passe',
              style: const TextStyle(color: VoyagoColors.muted, fontSize: 14),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),

            // Step indicator
            _StepIndicator(currentStep: _step, totalSteps: 2),
            const SizedBox(height: 32),

            if (_error != null) _ErrorBox(message: _error!),
            if (_success != null) _SuccessBox(message: _success!),

            if (_step == 1) ...[
              TextFormField(
                controller: _emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Adresse email',
                  prefixIcon: Icon(Icons.email_outlined, color: VoyagoColors.muted),
                ),
                keyboardType: TextInputType.emailAddress,
                autocorrect: false,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _sendCode,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Envoyer le code'),
              ),
            ] else ...[
              OtpCodeField(
                key: _otpKey,
                onChanged: (v) => setState(() => _code = v),
                onCompleted: (v) => setState(() => _code = v),
              ),
              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: _cooldown > 0 || _isLoading ? null : _sendCode,
                    child: Text(_cooldown > 0 ? 'Renvoyer dans $_cooldown s' : 'Renvoyer le code'),
                  ),
                  TextButton(
                    onPressed: () => setState(() {
                      _step = 1;
                      _error = null;
                      _success = null;
                    }),
                    child: const Text("Changer d'adresse", style: TextStyle(color: VoyagoColors.muted)),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _newPasswordCtrl,
                decoration: InputDecoration(
                  labelText: 'Nouveau mot de passe',
                  prefixIcon: const Icon(Icons.lock_outline, color: VoyagoColors.muted),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                      color: VoyagoColors.muted,
                    ),
                    onPressed: () =>
                        setState(() => _obscurePassword = !_obscurePassword),
                  ),
                ),
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordCtrl,
                decoration: const InputDecoration(
                  labelText: 'Confirme le mot de passe',
                  prefixIcon: Icon(Icons.lock_reset_rounded, color: VoyagoColors.muted),
                ),
                obscureText: _obscurePassword,
                autofillHints: const [AutofillHints.newPassword],
                onFieldSubmitted: (_) => _resetPassword(),
              ),
              const SizedBox(height: 8),
              const Text(
                'Par sécurité, tu seras déconnecté de tes autres appareils.',
                style: TextStyle(color: VoyagoColors.muted, fontSize: 12),
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: _isLoading ? null : _resetPassword,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('Réinitialiser le mot de passe'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const _StepIndicator({required this.currentStep, required this.totalSteps});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(totalSteps, (i) {
        final isActive = i + 1 == currentStep;
        final isDone = i + 1 < currentStep;
        return Row(
          children: [
            if (i > 0)
              Container(
                width: 40,
                height: 2,
                color: isDone ? VoyagoColors.primary : VoyagoColors.cardBorder,
              ),
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: isActive || isDone
                    ? VoyagoColors.primary
                    : VoyagoColors.surface,
                shape: BoxShape.circle,
                border: Border.all(
                  color: isActive || isDone
                      ? VoyagoColors.primary
                      : VoyagoColors.cardBorder,
                ),
              ),
              alignment: Alignment.center,
              child: isDone
                  ? const Icon(Icons.check, size: 16, color: Colors.white)
                  : Text(
                      '${i + 1}',
                      style: TextStyle(
                        color: isActive ? Colors.white : VoyagoColors.muted,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
            ),
          ],
        );
      }),
    );
  }
}

class _ErrorBox extends StatelessWidget {
  final String message;
  const _ErrorBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
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

class _SuccessBox extends StatelessWidget {
  final String message;
  const _SuccessBox({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: VoyagoColors.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: VoyagoColors.primary.withOpacity(0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.check_circle_outline, color: VoyagoColors.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: const TextStyle(color: VoyagoColors.primary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
