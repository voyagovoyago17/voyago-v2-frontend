import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../api/api.dart';
import '../core/utils/form_validators.dart';
import '../providers/auth_provider.dart';
import 'email_verification_sheet.dart';
import '../theme.dart';

class AuthBottomSheet extends ConsumerStatefulWidget {
  final String title;
  final String subtitle;

  const AuthBottomSheet({
    super.key,
    this.title = 'Finalisez votre voyage avec Voyagooo ! 🦜',
    this.subtitle = 'Connectez-vous ou créez votre compte pour sauvegarder cet itinéraire sur votre profil.',
  });

  @override
  ConsumerState<AuthBottomSheet> createState() => _AuthBottomSheetState();
}

class _AuthBottomSheetState extends ConsumerState<AuthBottomSheet>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // Login form
  final _loginFormKey = GlobalKey<FormState>();
  final _loginEmailCtrl = TextEditingController();
  final _loginPasswordCtrl = TextEditingController();
  bool _loginObscure = true;

  // Signup form
  final _signupFormKey = GlobalKey<FormState>();
  final _signupNameCtrl = TextEditingController();
  final _signupEmailCtrl = TextEditingController();
  final _signupPasswordCtrl = TextEditingController();
  final _signupPseudoCtrl = TextEditingController();
  bool _signupObscure = true;
  String _selectedEmoji = '🦜';

  static const List<String> _avatarEmojis = [
    '🦜', '🦁', '🐯', '🦊', '🐺', '🐻',
    '🦝', '🐸', '🦄', '🐉', '🦅', '🐬',
  ];

  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailCtrl.dispose();
    _loginPasswordCtrl.dispose();
    _signupNameCtrl.dispose();
    _signupEmailCtrl.dispose();
    _signupPasswordCtrl.dispose();
    _signupPseudoCtrl.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_loginFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(authProvider.notifier).login(
            email: _loginEmailCtrl.text.trim(),
            password: _loginPasswordCtrl.text,
          );
      if (mounted) {
        Navigator.of(context).pop(true);
        final user = ref.read(currentUserProvider);
        if (user != null && !user.onboardingCompleted) {
          context.go('/onboarding');
        }
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Identifiants invalides');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _showAccountExistsDialog(String email) async {
    final action = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: VoyagoColors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: const BorderSide(color: VoyagoColors.cardBorder),
        ),
        title: const Row(
          children: [
            Text('🦜', style: TextStyle(fontSize: 28)),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Compte déjà existant !',
                style: TextStyle(
                  color: VoyagoColors.text,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            RichText(
              text: TextSpan(
                style: const TextStyle(
                  color: VoyagoColors.muted,
                  fontSize: 14,
                  height: 1.5,
                ),
                children: [
                  const TextSpan(
                    text: 'Un compte Voyagooo existe déjà avec l\'adresse :\n',
                  ),
                  TextSpan(
                    text: email,
                    style: const TextStyle(
                      color: VoyagoColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const TextSpan(
                    text: '.\n\nVoulez-vous vous connecter directement avec ce compte ?',
                  ),
                ],
              ),
            ),
          ],
        ),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(ctx).pop('cancel'),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: VoyagoColors.cardBorder),
                    foregroundColor: VoyagoColors.muted,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Annuler', style: TextStyle(fontSize: 13)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(ctx).pop('login'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text('Se connecter', style: TextStyle(fontSize: 13)),
                ),
              ),
            ],
          ),
        ],
      ),
    );

    if (action == 'login' && mounted) {
      _loginEmailCtrl.text = email;
      _loginPasswordCtrl.clear();
      setState(() => _error = null);
      _tabController.animateTo(0);
    }
  }

  Future<void> _handleSignup() async {
    if (!_signupFormKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final email = _signupEmailCtrl.text.trim();

    try {
      await ref.read(authProvider.notifier).signup(
            name: _signupNameCtrl.text.trim(),
            email: email,
            password: _signupPasswordCtrl.text,
            dateOfBirth: '2000-01-01',
            country: 'France',
            city: 'Paris',
            pseudo: _signupPseudoCtrl.text.trim().isEmpty
                ? null
                : _signupPseudoCtrl.text.trim(),
            avatarEmoji: _selectedEmoji,
          );
      if (mounted) {
        // Le code vient d'être envoyé par le serveur : on propose de le saisir tout de suite
        await showEmailVerificationSheet(context, codeAlreadySent: true);
      }
      if (mounted) {
        Navigator.of(context).pop(true);
        final user = ref.read(currentUserProvider);
        if (user != null && !user.onboardingCompleted) {
          context.go('/onboarding');
        }
      }
    } on ApiException catch (e) {
      if (e.statusCode == 409 || e is ConflictException) {
        if (mounted) {
          setState(() => _isLoading = false);
          await _showAccountExistsDialog(email);
          return;
        }
      }
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Erreur lors de l\'inscription');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGuest() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(authProvider.notifier).loginGuest();
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (_) {
      if (mounted) setState(() => _error = 'Erreur lors de la session invité');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.88,
      ),
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: const BoxDecoration(
        color: VoyagoColors.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        border: Border(
          top: BorderSide(color: VoyagoColors.cardBorder, width: 1.5),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Drag handle
          Center(
            child: Container(
              margin: const EdgeInsets.only(top: 12, bottom: 8),
              width: 44,
              height: 4,
              decoration: BoxDecoration(
                color: VoyagoColors.cardBorder,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),

          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 12),
            child: Column(
              children: [
                const Text('🦜', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 8),
                Text(
                  widget.title,
                  style: const TextStyle(
                    color: VoyagoColors.text,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  widget.subtitle,
                  style: const TextStyle(
                    color: VoyagoColors.muted,
                    fontSize: 13,
                    height: 1.4,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),

          // TabBar
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 24),
            decoration: BoxDecoration(
              color: VoyagoColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: VoyagoColors.cardBorder),
            ),
            child: TabBar(
              controller: _tabController,
              indicator: BoxDecoration(
                color: VoyagoColors.primary,
                borderRadius: BorderRadius.circular(14),
              ),
              labelColor: Colors.white,
              unselectedLabelColor: VoyagoColors.muted,
              labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
              tabs: const [
                Tab(text: 'Connexion'),
                Tab(text: 'Inscription'),
              ],
            ),
          ),

          if (_error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: VoyagoColors.coral.withOpacity(0.12),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: VoyagoColors.coral.withOpacity(0.4)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error_outline, color: VoyagoColors.coral, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _error!,
                        style: const TextStyle(color: VoyagoColors.coral, fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),

          // Forms
          Flexible(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: SizedBox(
                height: 380,
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildLoginTab(),
                    _buildSignupTab(),
                  ],
                ),
              ),
            ),
          ),

          // Guest quick link
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: TextButton.icon(
              onPressed: _isLoading ? null : _handleGuest,
              icon: const Text('✨', style: TextStyle(fontSize: 16)),
              label: const Text(
                'Continuer en tant qu\'invité (temporaire)',
                style: TextStyle(color: VoyagoColors.muted, fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginTab() {
    return Form(
      key: _loginFormKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextFormField(
            controller: _loginEmailCtrl,
            decoration: const InputDecoration(
              labelText: 'Email',
              prefixIcon: Icon(Icons.email_outlined, color: VoyagoColors.muted),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: FormValidators.validateEmail,
          ),
          const SizedBox(height: 14),
          TextFormField(
            controller: _loginPasswordCtrl,
            decoration: InputDecoration(
              labelText: 'Mot de passe',
              prefixIcon: const Icon(Icons.lock_outline, color: VoyagoColors.muted),
              suffixIcon: IconButton(
                icon: Icon(
                  _loginObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                  color: VoyagoColors.muted,
                ),
                onPressed: () => setState(() => _loginObscure = !_loginObscure),
              ),
            ),
            obscureText: _loginObscure,
            validator: FormValidators.validatePassword,
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _handleLogin,
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                  )
                : const Text('Se connecter & Générer l\'itinéraire 🦜'),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupTab() {
    return Form(
      key: _signupFormKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              controller: _signupNameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom complet',
                prefixIcon: Icon(Icons.person_outline, color: VoyagoColors.muted),
              ),
              validator: FormValidators.validateName,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signupEmailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined, color: VoyagoColors.muted),
              ),
              keyboardType: TextInputType.emailAddress,
              validator: FormValidators.validateEmail,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signupPasswordCtrl,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline, color: VoyagoColors.muted),
                suffixIcon: IconButton(
                  icon: Icon(
                    _signupObscure ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: VoyagoColors.muted,
                  ),
                  onPressed: () => setState(() => _signupObscure = !_signupObscure),
                ),
              ),
              obscureText: _signupObscure,
              validator: FormValidators.validatePassword,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _signupPseudoCtrl,
              decoration: const InputDecoration(
                labelText: 'Pseudo (optionnel)',
                prefixIcon: Icon(Icons.alternate_email, color: VoyagoColors.muted),
              ),
              validator: FormValidators.validatePseudo,
            ),
            const SizedBox(height: 16),
            const Text(
              'Avatar',
              style: TextStyle(color: VoyagoColors.text, fontSize: 13, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                itemCount: _avatarEmojis.length,
                itemBuilder: (_, i) {
                  final emoji = _avatarEmojis[i];
                  final isSelected = emoji == _selectedEmoji;
                  return GestureDetector(
                    onTap: () => setState(() => _selectedEmoji = emoji),
                    child: Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 44,
                      decoration: BoxDecoration(
                        color: isSelected
                            ? VoyagoColors.primary.withOpacity(0.2)
                            : VoyagoColors.surface,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSelected ? VoyagoColors.primary : VoyagoColors.cardBorder,
                          width: isSelected ? 2 : 1,
                        ),
                      ),
                      alignment: Alignment.center,
                      child: Text(emoji, style: const TextStyle(fontSize: 22)),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              onPressed: _isLoading ? null : _handleSignup,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Créer mon compte & Générer 🦜'),
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}
