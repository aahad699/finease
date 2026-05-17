import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../services/auth_service.dart';

class SignupPage extends StatefulWidget {
  const SignupPage({super.key});

  @override
  State<SignupPage> createState() => _SignupPageState();
}

class _SignupPageState extends State<SignupPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _nameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _confirmPassCtrl = TextEditingController();

  final _nameFocus = FocusNode();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final _confirmFocus = FocusNode();

  bool _isLoading = false;
  bool _showPass = false;
  bool _showConfirm = false;
  bool _acceptedTerms = false;
  String _password = '';
  bool _emailTouched = false;
  bool _passTouched = false;
  bool _confirmTouched = false;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  static const Color _primary = Color(0xFF2E3192);
  static const Color _dark = Color(0xFF1A1A1A);
  static const Color _error = Color(0xFFEF4444);
  static const Color _success = Color(0xFF10B981);

  // ── Password Rules ──────────────────────────────────────────────────────────
  bool get _hasMinLength => _password.length >= 8;
  bool get _hasUppercase => _password.contains(RegExp(r'[A-Z]'));
  bool get _hasLowercase => _password.contains(RegExp(r'[a-z]'));
  bool get _hasDigit => _password.contains(RegExp(r'[0-9]'));
  bool get _hasSpecial =>
      _password.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>_\-]'));

  int get _strengthScore {
    int score = 0;
    if (_hasMinLength) score++;
    if (_hasUppercase) score++;
    if (_hasLowercase) score++;
    if (_hasDigit) score++;
    if (_hasSpecial) score++;
    return score;
  }

  Color get _strengthColor {
    if (_strengthScore <= 1) return _error;
    if (_strengthScore <= 2) return const Color(0xFFF97316);
    if (_strengthScore <= 3) return const Color(0xFFFACC15);
    if (_strengthScore <= 4) return const Color(0xFF84CC16);
    return _success;
  }

  String get _strengthLabel {
    if (_password.isEmpty) return '';
    if (_strengthScore <= 1) return 'Very Weak';
    if (_strengthScore <= 2) return 'Weak';
    if (_strengthScore <= 3) return 'Fair';
    if (_strengthScore <= 4) return 'Strong';
    return 'Very Strong';
  }

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );
    _shakeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
    _passCtrl.addListener(() {
      setState(() => _password = _passCtrl.text);
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _confirmPassCtrl.dispose();
    _nameFocus.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _confirmFocus.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── Validators ──────────────────────────────────────────────────────────────
  String? _validateName(String? v) {
    if (v == null || v.trim().isEmpty) return 'Full name is required';
    if (v.trim().length < 2) return 'Name must be at least 2 characters';
    if (!RegExp(r"^[a-zA-Z\s'-]+$").hasMatch(v.trim())) {
      return 'Name can only contain letters, spaces, hyphens, apostrophes';
    }
    return null;
  }

  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email address is required';
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(v.trim())) return 'Enter a valid email address';
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (!_hasMinLength) return 'Password must be at least 8 characters';
    if (!_hasUppercase) return 'Include at least one uppercase letter (A-Z)';
    if (!_hasLowercase) return 'Include at least one lowercase letter (a-z)';
    if (!_hasDigit) return 'Include at least one number (0-9)';
    if (!_hasSpecial) {
      return 'Include at least one special character (!@#\$%^&*)';
    }
    return null;
  }

  String? _validateConfirm(String? v) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    if (v != _passCtrl.text) return 'Passwords do not match';
    return null;
  }

  // ── Signup Logic ────────────────────────────────────────────────────────────
  Future<void> _signup() async {
    setState(() {
      _emailTouched = true;
      _passTouched = true;
      _confirmTouched = true;
    });

    if (!_formKey.currentState!.validate()) {
      _shakeCtrl.forward(from: 0);
      HapticFeedback.heavyImpact();
      return;
    }
    if (!_acceptedTerms) {
      _showSnack('Please accept the Terms & Conditions to continue.');
      return;
    }
    setState(() => _isLoading = true);
    try {
      final authService = Provider.of<AuthService>(context, listen: false);
      await authService.signUpWithEmail(
        _emailCtrl.text.trim(),
        _passCtrl.text,
        fullName: _nameCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context);
    } on Exception catch (e) {
      if (mounted) {
        _shakeCtrl.forward(from: 0);
        _showSnack(_friendlyError(e.toString()));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('email-already-in-use')) {
      return 'This email is already registered. Try logging in.';
    }
    if (raw.contains('invalid-email')) return 'Invalid email format.';
    if (raw.contains('weak-password')) {
      return 'Password is too weak. Please follow the requirements.';
    }
    if (raw.contains('network')) {
      return 'No internet connection. Please try again.';
    }
    return 'Sign up failed. Please try again.';
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: GoogleFonts.inter(fontSize: 13))),
          ],
        ),
        backgroundColor: _error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Stack(
        children: [
          // Background decorative circles
          Positioned(
            top: -120,
            left: -80,
            child: _bgCircle(280, _primary.withValues(alpha: 0.05)),
          ),
          Positioned(
            bottom: -60,
            right: -60,
            child: _bgCircle(
              220,
              const Color(0xFF1BFFFF).withValues(alpha: 0.07),
            ),
          ),
          SafeArea(
            child: Column(
              children: [
                // Back button
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: Icon(
                          Icons.arrow_back_ios_new_rounded,
                          color: Theme.of(context).colorScheme.onSurface,
                          size: 20,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(28, 0, 28, 40),
                    child: Form(
                      key: _formKey,
                      child: AnimatedBuilder(
                        animation: _shakeAnim,
                        builder: (context, child) => Transform.translate(
                          offset: Offset(
                            _shakeCtrl.isAnimating
                                ? 8 *
                                      (0.5 - _shakeAnim.value).abs() *
                                      (_shakeAnim.value > 0.5 ? 1 : -1)
                                : 0,
                            0,
                          ),
                          child: child,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Logo
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.surface,
                                borderRadius: BorderRadius.circular(18),
                                boxShadow: [
                                  BoxShadow(
                                    color: _primary.withValues(alpha: 0.3),
                                    blurRadius: 20,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: Image.asset(
                                'assets/logo/logo.png',
                                width: 44,
                                height: 44,
                                fit: BoxFit.contain,
                              ),
                            ),
                            const SizedBox(height: 28),
                            Text(
                              'Create Account',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 30,
                                fontWeight: FontWeight.w800,
                                color: Theme.of(context).colorScheme.onSurface,
                                letterSpacing: -1,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              'Secure your financial future with FinEase.',
                              style: GoogleFonts.inter(
                                fontSize: 14,
                                color: Theme.of(context).textTheme.bodyMedium?.color,
                                height: 1.5,
                              ),
                            ),
                            const SizedBox(height: 32),

                            // ── Full Name ──
                            _fieldLabel(context, 'Full Name'),
                            const SizedBox(height: 8),
                            _buildField(
                              context: context,
                              controller: _nameCtrl,
                              focusNode: _nameFocus,
                              hint: 'e.g. Abdullah Khaleeq',
                              icon: Icons.person_outline_rounded,
                              validator: _validateName,
                              textCapitalization: TextCapitalization.words,
                              onSubmit: () => FocusScope.of(
                                context,
                              ).requestFocus(_emailFocus),
                            ),
                            const SizedBox(height: 20),

                            // ── Email ──
                            _fieldLabel(context, 'Email Address'),
                            const SizedBox(height: 8),
                            _buildField(
                              context: context,
                              controller: _emailCtrl,
                              focusNode: _emailFocus,
                              hint: 'name@example.com',
                              icon: Icons.alternate_email_rounded,
                              keyboardType: TextInputType.emailAddress,
                              validator: _emailTouched ? _validateEmail : null,
                              onChanged: (_) =>
                                  setState(() => _emailTouched = true),
                              onSubmit: () => FocusScope.of(
                                context,
                              ).requestFocus(_passFocus),
                            ),
                            const SizedBox(height: 20),

                            // ── Password ──
                            _fieldLabel(context, 'Password'),
                            const SizedBox(height: 8),
                            _buildField(
                              context: context,
                              controller: _passCtrl,
                              focusNode: _passFocus,
                              hint: 'Min 8 chars, A-Z, 0-9, !@#',
                              icon: Icons.lock_outline_rounded,
                              isPassword: true,
                              showPass: _showPass,
                              onToggle: () =>
                                  setState(() => _showPass = !_showPass),
                              validator: _passTouched
                                  ? _validatePassword
                                  : null,
                              onChanged: (_) =>
                                  setState(() => _passTouched = true),
                              onSubmit: () => FocusScope.of(
                                context,
                              ).requestFocus(_confirmFocus),
                            ),

                            // ── Strength Meter ──
                            if (_password.isNotEmpty) ...[
                              const SizedBox(height: 10),
                              _buildStrengthMeter(),
                            ],

                            const SizedBox(height: 16),

                            // ── Password Requirements ──
                            _buildRequirements(),
                            const SizedBox(height: 20),

                            // ── Confirm Password ──
                            _fieldLabel(context, 'Confirm Password'),
                            const SizedBox(height: 8),
                            _buildField(
                              context: context,
                              controller: _confirmPassCtrl,
                              focusNode: _confirmFocus,
                              hint: 'Re-enter your password',
                              icon: Icons.lock_reset_rounded,
                              isPassword: true,
                              showPass: _showConfirm,
                              onToggle: () =>
                                  setState(() => _showConfirm = !_showConfirm),
                              validator: _confirmTouched
                                  ? _validateConfirm
                                  : null,
                              onChanged: (_) =>
                                  setState(() => _confirmTouched = true),
                              suffixCheckmark:
                                  _confirmPassCtrl.text.isNotEmpty &&
                                  _confirmPassCtrl.text == _passCtrl.text,
                            ),
                            const SizedBox(height: 24),

                            // ── Terms ──
                            _buildTermsRow(),
                            const SizedBox(height: 32),

                            // ── Submit ──
                            _buildSubmitButton(),
                            const SizedBox(height: 28),

                            // ── Login Link ──
                            Center(
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    'Already have an account? ',
                                    style: GoogleFonts.inter(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  GestureDetector(
                                    onTap: () => Navigator.pop(context),
                                    child: Text(
                                      'Login',
                                      style: GoogleFonts.inter(
                                        fontWeight: FontWeight.bold,
                                        color: _primary,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),
                            _buildSecurityBadges(),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── UI Helpers ───────────────────────────────────────────────────────────────

  Widget _bgCircle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  Widget _fieldLabel(BuildContext context, String text) => Text(
    text,
    style: GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );

  Widget _buildField({
    required BuildContext context,
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    bool isPassword = false,
    bool showPass = false,
    VoidCallback? onToggle,
    String? Function(String?)? validator,
    void Function(String)? onChanged,
    void Function()? onSubmit,
    TextInputType? keyboardType,
    TextCapitalization textCapitalization = TextCapitalization.none,
    bool suffixCheckmark = false,
  }) {
    return TextFormField(
      controller: controller,
      focusNode: focusNode,
      obscureText: isPassword && !showPass,
      keyboardType: keyboardType,
      textCapitalization: textCapitalization,
      style: GoogleFonts.inter(
        fontSize: 15,
        color: Theme.of(context).colorScheme.onSurface,
      ),
      autovalidateMode: AutovalidateMode.onUserInteraction,
      validator: validator,
      onChanged: onChanged,
      onFieldSubmitted: (_) => onSubmit?.call(),
      textInputAction: onSubmit != null
          ? TextInputAction.next
          : TextInputAction.done,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
        suffixIcon: isPassword
            ? IconButton(
                icon: Icon(
                  showPass ? Icons.visibility_off : Icons.visibility,
                  color: Colors.grey[400],
                  size: 20,
                ),
                onPressed: onToggle,
              )
            : suffixCheckmark
            ? Icon(Icons.check_circle_rounded, color: _success, size: 20)
            : null,
        filled: true,
        fillColor: Theme.of(context).colorScheme.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Theme.of(context).dividerColor),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _primary, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _error, width: 1.2),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _error, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 16,
        ),
        errorStyle: GoogleFonts.inter(fontSize: 11, color: _error),
      ),
    );
  }

  Widget _buildStrengthMeter() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: List.generate(5, (i) {
            final filled = i < _strengthScore;
            return Expanded(
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                height: 5,
                margin: EdgeInsets.only(right: i < 4 ? 4 : 0),
                decoration: BoxDecoration(
                  color: filled ? _strengthColor : const Color(0xFFEEEEEE),
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            );
          }),
        ),
        const SizedBox(height: 6),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Password Strength',
              style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[500]),
            ),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: Text(
                _strengthLabel,
                key: ValueKey(_strengthLabel),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: _strengthColor,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildRequirements() {
    final rules = [
      (_hasMinLength, 'At least 8 characters'),
      (_hasUppercase, 'One uppercase letter (A-Z)'),
      (_hasLowercase, 'One lowercase letter (a-z)'),
      (_hasDigit, 'One number (0-9)'),
      (_hasSpecial, 'One special character (!@#\$%^&*)'),
    ];
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F9FE),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Password Requirements',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Colors.grey[700],
            ),
          ),
          const SizedBox(height: 10),
          ...rules.map((r) => _requirementRow(r.$1, r.$2)),
        ],
      ),
    );
  }

  Widget _requirementRow(bool met, String text) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            width: 18,
            height: 18,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: met ? _success : const Color(0xFFEEEEEE),
            ),
            child: Icon(
              met ? Icons.check_rounded : Icons.close_rounded,
              size: 11,
              color: met ? Colors.white : Colors.grey[400],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            text,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: met ? _dark : Colors.grey[500],
              fontWeight: met ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTermsRow() {
    return GestureDetector(
      onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 22,
            height: 22,
            decoration: BoxDecoration(
              color: _acceptedTerms ? _primary : Colors.white,
              border: Border.all(
                color: _acceptedTerms ? _primary : Colors.grey[300]!,
                width: 1.5,
              ),
              borderRadius: BorderRadius.circular(6),
            ),
            child: _acceptedTerms
                ? Icon(Icons.check_rounded, color: Colors.white, size: 14)
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text.rich(
              TextSpan(
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: Colors.grey[600],
                  height: 1.5,
                ),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms of Service',
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: const TextStyle(
                      color: _primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubmitButton() {
    return SizedBox(
      width: double.infinity,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: _acceptedTerms
                ? [_primary, const Color(0xFF1565C0)]
                : [Colors.grey[300]!, Colors.grey[400]!],
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: _acceptedTerms
              ? [
                  BoxShadow(
                    color: _primary.withValues(alpha: 0.35),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ]
              : [],
        ),
        child: ElevatedButton(
          onPressed: _isLoading ? null : _signup,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _isLoading
              ? const SizedBox(
                  height: 22,
                  width: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Text(
                  'Create Secure Account',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: _acceptedTerms ? Colors.white : Colors.grey[500],
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSecurityBadges() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _badge(Icons.shield_rounded, '256-bit AES'),
        const SizedBox(width: 20),
        _badge(Icons.verified_user_rounded, 'GDPR Safe'),
        const SizedBox(width: 20),
        _badge(Icons.lock_rounded, 'Encrypted'),
      ],
    );
  }

  Widget _badge(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 13, color: Colors.grey[400]),
        const SizedBox(width: 5),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 11, color: Colors.grey[400]),
        ),
      ],
    );
  }
}
