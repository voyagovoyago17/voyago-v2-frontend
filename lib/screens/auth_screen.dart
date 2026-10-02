import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../api/api.dart';
import '../core/utils/form_validators.dart';
import '../providers/auth_provider.dart';
import '../widgets/email_verification_sheet.dart';
import '../theme.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  String? _prefilledLoginEmail;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  void _switchToLogin(String email) {
    setState(() {
      _prefilledLoginEmail = email;
    });
    _tabController.animateTo(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: VoyagoColors.background,
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Image.asset(
              'assets/logo/voyago_parrot.png',
              height: 28,
              fit: BoxFit.contain,
              errorBuilder: (_, __, ___) => const Text('🦜', style: TextStyle(fontSize: 20)),
            ),
            const SizedBox(width: 8),
            const Text('Voyagooo'),
          ],
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: 'Connexion'),
            Tab(text: 'Inscription'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _LoginTab(
            initialEmail: _prefilledLoginEmail,
            onForgotPassword: () => context.go('/forgot-password'),
            onSuccess: () {
              final user = ref.read(currentUserProvider);
              if (user != null && !user.onboardingCompleted) {
                context.go('/onboarding');
              } else {
                context.go('/');
              }
            },
          ),
          _SignupTab(
            onSwitchToLogin: _switchToLogin,
            onSuccess: () {
              final user = ref.read(currentUserProvider);
              if (user != null && !user.onboardingCompleted) {
                context.go('/onboarding');
              } else {
                context.go('/');
              }
            },
          ),
        ],
      ),
    );
  }
}

class _LoginTab extends ConsumerStatefulWidget {
  final String? initialEmail;
  final VoidCallback onForgotPassword;
  final VoidCallback onSuccess;

  const _LoginTab({
    this.initialEmail,
    required this.onForgotPassword,
    required this.onSuccess,
  });

  @override
  ConsumerState<_LoginTab> createState() => _LoginTabState();
}

class _LoginTabState extends ConsumerState<_LoginTab> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _emailCtrl;
  final _passwordCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _emailCtrl = TextEditingController(text: widget.initialEmail ?? '');
  }

  @override
  void didUpdateWidget(covariant _LoginTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialEmail != null && widget.initialEmail != oldWidget.initialEmail) {
      _emailCtrl.text = widget.initialEmail!;
    }
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });
    try {
      await ref.read(authProvider.notifier).login(
            email: _emailCtrl.text.trim(),
            password: _passwordCtrl.text,
          );
      if (mounted) widget.onSuccess();
    } on ApiException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur de connexion');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Bon retour ! 👋',
              style: TextStyle(
                color: VoyagoColors.text,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Connecte-toi pour continuer tes aventures',
              style: TextStyle(color: VoyagoColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 32),

            if (_error != null)
              _ErrorBox(message: _error!),

            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email',
                prefixIcon: Icon(Icons.email_outlined, color: VoyagoColors.muted),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: FormValidators.validateEmail,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _passwordCtrl,
              decoration: InputDecoration(
                labelText: 'Mot de passe',
                prefixIcon: const Icon(Icons.lock_outline, color: VoyagoColors.muted),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: VoyagoColors.muted,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              validator: FormValidators.validatePassword,
            ),
            const SizedBox(height: 8),

            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: widget.onForgotPassword,
                child: const Text('Mot de passe oublié ?'),
              ),
            ),
            const SizedBox(height: 16),

            ElevatedButton(
              onPressed: _isLoading ? null : _login,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Connexion'),
            ),
            const SizedBox(height: 24),

            _GoogleButton(),
          ],
        ),
      ),
    );
  }
}

class _SignupTab extends ConsumerStatefulWidget {
  final ValueChanged<String> onSwitchToLogin;
  final VoidCallback onSuccess;

  const _SignupTab({
    required this.onSwitchToLogin,
    required this.onSuccess,
  });

  @override
  ConsumerState<_SignupTab> createState() => _SignupTabState();
}

class _SignupTabState extends ConsumerState<_SignupTab> {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _pseudoCtrl = TextEditingController();
  final _cityCtrl = TextEditingController();
  bool _obscurePassword = true;
  bool _isLoading = false;
  String? _error;
  String _selectedEmoji = '🦜';
  DateTime? _dateOfBirth;
  String? _selectedCountry;
  List<String> _countries = [];

  static const List<String> _avatarEmojis = [
    '🦜', '🦁', '🐯', '🦊', '🐺', '🐻',
    '🦝', '🐸', '🦄', '🐉', '🦅', '🐬',
  ];

  @override
  void initState() {
    super.initState();
    _loadCountries();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _pseudoCtrl.dispose();
    _cityCtrl.dispose();
    super.dispose();
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
      widget.onSwitchToLogin(email);
    }
  }

  Future<void> _loadCountries() async {
    try {
      final options = await AuthApi().getAuthOptions();
      final countries = options['countries'] as List? ?? [];
      if (mounted) {
        setState(() {
          _countries = countries.map((c) => c.toString()).toList();
          if (_countries.isNotEmpty && _selectedCountry == null) {
            _selectedCountry = _countries.first;
          }
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _countries = ['France', 'Belgique', 'Suisse', 'Canada', 'Maroc', 'Côte d\'Ivoire', 'Sénégal', 'Autres'];
          _selectedCountry = 'France';
        });
      }
    }
  }

  Future<void> _signup() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final email = _emailCtrl.text.trim();

    try {
      final dobStr = _dateOfBirth != null
          ? DateFormat('yyyy-MM-dd').format(_dateOfBirth!)
          : '2000-01-01';

      await ref.read(authProvider.notifier).signup(
            name: _nameCtrl.text.trim(),
            email: email,
            password: _passwordCtrl.text,
            dateOfBirth: dobStr,
            country: _selectedCountry ?? 'France',
            city: _cityCtrl.text.trim().isNotEmpty ? _cityCtrl.text.trim() : 'Paris',
            pseudo: _pseudoCtrl.text.trim().isEmpty ? null : _pseudoCtrl.text.trim(),
            avatarEmoji: _selectedEmoji,
          );
      // Le code vient d'être envoyé par le serveur : on propose de le saisir tout de suite
      if (mounted) await showEmailVerificationSheet(context, codeAlreadySent: true);
      if (mounted) widget.onSuccess();
    } on ApiException catch (e) {
      if (e.statusCode == 409 || e is ConflictException) {
        if (mounted) {
          setState(() => _isLoading = false);
          await _showAccountExistsDialog(email);
          return;
        }
      }
      if (mounted) setState(() => _error = e.message);
    } catch (e) {
      if (mounted) setState(() => _error = 'Erreur lors de l\'inscription');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(now.year - 20),
      firstDate: DateTime(1920),
      lastDate: DateTime(now.year - 13),
      builder: (ctx, child) => Theme(
        data: Theme.of(ctx).copyWith(
          colorScheme: const ColorScheme.dark(primary: VoyagoColors.primary),
        ),
        child: child!,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _dateOfBirth = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const SizedBox(height: 16),
            const Text(
              'Créer un compte 🚀',
              style: TextStyle(
                color: VoyagoColors.text,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Rejoins des milliers de voyageurs avec Voyagooo 🦜',
              style: TextStyle(color: VoyagoColors.muted, fontSize: 14),
            ),
            const SizedBox(height: 32),

            if (_error != null) _ErrorBox(message: _error!),

            TextFormField(
              controller: _nameCtrl,
              decoration: const InputDecoration(
                labelText: 'Nom complet *',
                prefixIcon: Icon(Icons.person_outline, color: VoyagoColors.muted),
              ),
              validator: FormValidators.validateName,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _emailCtrl,
              decoration: const InputDecoration(
                labelText: 'Email *',
                prefixIcon: Icon(Icons.email_outlined, color: VoyagoColors.muted),
              ),
              keyboardType: TextInputType.emailAddress,
              autocorrect: false,
              validator: FormValidators.validateEmail,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _passwordCtrl,
              decoration: InputDecoration(
                labelText: 'Mot de passe *',
                prefixIcon: const Icon(Icons.lock_outline, color: VoyagoColors.muted),
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                    color: VoyagoColors.muted,
                  ),
                  onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                ),
              ),
              obscureText: _obscurePassword,
              validator: FormValidators.validatePassword,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _pseudoCtrl,
              decoration: const InputDecoration(
                labelText: 'Pseudo (optionnel)',
                prefixIcon: Icon(Icons.alternate_email, color: VoyagoColors.muted),
              ),
              validator: FormValidators.validatePseudo,
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _cityCtrl,
              decoration: const InputDecoration(
                labelText: 'Ville de résidence',
                prefixIcon: Icon(Icons.location_city_outlined, color: VoyagoColors.muted),
              ),
            ),
            const SizedBox(height: 24),

            // Avatar emoji selector
            const Text(
              'Choisir un avatar',
              style: TextStyle(
                color: VoyagoColors.text,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            _AvatarSelector(
              emojis: _avatarEmojis,
              selected: _selectedEmoji,
              onSelect: (e) => setState(() => _selectedEmoji = e),
            ),
            const SizedBox(height: 20),

            // Date of birth
            GestureDetector(
              onTap: _pickDate,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                decoration: BoxDecoration(
                  color: VoyagoColors.surface,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: VoyagoColors.cardBorder),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.cake_outlined, color: VoyagoColors.muted),
                    const SizedBox(width: 12),
                    Text(
                      _dateOfBirth != null
                          ? DateFormat('dd/MM/yyyy').format(_dateOfBirth!)
                          : 'Date de naissance (optionnel)',
                      style: TextStyle(
                        color: _dateOfBirth != null
                            ? VoyagoColors.text
                            : VoyagoColors.muted,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),

            // Country dropdown
            if (_countries.isNotEmpty)
              DropdownButtonFormField<String>(
                value: _selectedCountry,
                decoration: const InputDecoration(
                  labelText: 'Pays (optionnel)',
                  prefixIcon: Icon(Icons.public_outlined, color: VoyagoColors.muted),
                ),
                dropdownColor: VoyagoColors.surface,
                style: const TextStyle(color: VoyagoColors.text),
                items: _countries
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (v) => setState(() => _selectedCountry = v),
              ),
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _isLoading ? null : _signup,
              child: _isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('S\'inscrire'),
            ),
            const SizedBox(height: 24),

            _GoogleButton(),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

class _AvatarSelector extends StatelessWidget {
  final List<String> emojis;
  final String selected;
  final ValueChanged<String> onSelect;

  const _AvatarSelector({
    required this.emojis,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      itemCount: emojis.length,
      itemBuilder: (_, i) {
        final emoji = emojis[i];
        final isSelected = emoji == selected;
        return GestureDetector(
          onTap: () => onSelect(emoji),
          child: Container(
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
    );
  }
}

class _GoogleButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return OutlinedButton.icon(
      onPressed: () {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Google Sign-in bientôt disponible'),
            backgroundColor: VoyagoColors.surface,
          ),
        );
      },
      icon: const Text('G', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
      label: const Text('Continuer avec Google'),
      style: OutlinedButton.styleFrom(
        foregroundColor: VoyagoColors.text,
        side: const BorderSide(color: VoyagoColors.cardBorder),
      ),
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
