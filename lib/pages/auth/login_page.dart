import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:local_auth/local_auth.dart';
import '../../services/auth_service.dart';
import 'signup_page.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _emailFocus = FocusNode();
  final _passFocus = FocusNode();
  final LocalAuthentication _localAuth = LocalAuthentication();

  bool _isLoading = false;
  bool _showPass = false;
  bool _emailTouched = false;
  bool _passTouched = false;

  // Track failed attempts to prevent brute-force
  int _failedAttempts = 0;
  bool _isLockedOut = false;
  DateTime? _lockoutEnd;

  late AnimationController _shakeCtrl;
  late Animation<double> _shakeAnim;

  static const Color _primary = Color(0xFF2E3192);
  static const Color _dark = Color(0xFF1A1A1A);
  static const Color _error = Color(0xFFEF4444);

  @override
  void initState() {
    super.initState();
    _shakeCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _shakeAnim = Tween<double>(
      begin: 0,
      end: 1,
    ).animate(CurvedAnimation(parent: _shakeCtrl, curve: Curves.elasticIn));
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _emailFocus.dispose();
    _passFocus.dispose();
    _shakeCtrl.dispose();
    super.dispose();
  }

  // ── Validators ──────────────────────────────────────────────────────────────
  String? _validateEmail(String? v) {
    if (v == null || v.trim().isEmpty) return 'Email address is required';
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$',
    );
    if (!emailRegex.hasMatch(v.trim())) {
      return 'Enter a valid email address (e.g. name@example.com)';
    }
    return null;
  }

  String? _validatePassword(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    if (v.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  // ── Lockout check ────────────────────────────────────────────────────────────
  bool get _isCurrentlyLockedOut {
    if (!_isLockedOut) return false;
    if (_lockoutEnd != null && DateTime.now().isAfter(_lockoutEnd!)) {
      _isLockedOut = false;
      _failedAttempts = 0;
      return false;
    }
    return true;
  }

  String get _lockoutRemaining {
    if (_lockoutEnd == null) return '';
    final remaining = _lockoutEnd!.difference(DateTime.now()).inSeconds;
    return '${remaining}s';
  }

  // ── Login Logic ─────────────────────────────────────────────────────────────
  Future<void> _login() async {
    setState(() {
      _emailTouched = true;
      _passTouched = true;
    });

    if (_isCurrentlyLockedOut) {
      _showSnack(
        '🔒 Too many failed attempts. Try again in $_lockoutRemaining.',
        isError: true,
      );
      HapticFeedback.heavyImpact();
      return;
    }

    if (!_formKey.currentState!.validate()) {
      _shakeCtrl.forward(from: 0);
      HapticFeedback.mediumImpact();
      return;
    }

    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthService>(
        context,
        listen: false,
      ).signInWithEmail(_emailCtrl.text.trim(), _passCtrl.text);
      // Reset on success
      _failedAttempts = 0;
    } on Exception catch (e) {
      if (mounted) {
        _failedAttempts++;
        // Lock out after 5 failed attempts for 30 seconds
        if (_failedAttempts >= 5) {
          setState(() {
            _isLockedOut = true;
            _lockoutEnd = DateTime.now().add(const Duration(seconds: 30));
          });
          _showSnack(
            '🔒 Account temporarily locked after $_failedAttempts failed attempts. Wait 30s.',
            isError: true,
          );
        } else {
          _shakeCtrl.forward(from: 0);
          HapticFeedback.heavyImpact();
          _showSnack(_friendlyError(e.toString()), isError: true);
          // Show remaining attempts warning
          if (_failedAttempts >= 3) {
            _showSnack(
              '⚠️ Warning: ${5 - _failedAttempts} attempt(s) remaining before lockout.',
              isError: true,
            );
          }
        }
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _friendlyError(String raw) {
    if (raw.contains('user-not-found') || raw.contains('invalid-credential')) {
      return 'No account found with this email. Check your details or sign up.';
    }
    if (raw.contains('wrong-password') || raw.contains('invalid-credential')) {
      return 'Incorrect password. Please try again.';
    }
    if (raw.contains('too-many-requests')) {
      return 'Too many login attempts. Please wait and try again.';
    }
    if (raw.contains('user-disabled')) {
      return 'This account has been disabled. Contact support.';
    }
    if (raw.contains('network')) {
      return 'No internet connection. Please check your network.';
    }
    return 'Login failed. Please check your credentials and try again.';
  }

  void _showSnack(String msg, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(
              isError
                  ? Icons.error_outline_rounded
                  : Icons.check_circle_outline_rounded,
              color: Colors.white,
              size: 18,
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(msg, style: GoogleFonts.inter(fontSize: 12))),
          ],
        ),
        backgroundColor: isError ? _error : const Color(0xFF10B981),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  Future<void> _forgotPassword() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || _validateEmail(email) != null) {
      _showSnack(
        'Enter a valid email above first, then tap Forgot Password.',
        isError: true,
      );
      return;
    }
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          'Reset Password',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            fontSize: 18,
          ),
        ),
        content: Text(
          'A secure password reset link will be sent to:\n\n$email',
          style: GoogleFonts.inter(fontSize: 13, height: 1.6),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: Colors.grey[600]),
            ),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await Provider.of<AuthService>(
                  context,
                  listen: false,
                ).sendPasswordResetEmail(email);
                _showSnack('✅ Reset email sent to $email. Check your inbox.');
              } catch (_) {
                _showSnack(
                  'Could not send reset email. Verify the address and try again.',
                  isError: true,
                );
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Text(
              'Send Reset Link',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendEmailLink() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || _validateEmail(email) != null) {
      _showSnack(
        'Enter a valid email first to receive a password-less login link.',
        isError: true,
      );
      return;
    }
    setState(() => _isLoading = true);
    try {
      await Provider.of<AuthService>(
        context,
        listen: false,
      ).sendPasswordlessSignInLink(email);
      if (mounted) {
        _showSnack(
          'Password-less sign-in link sent to $email. Open it on this device.',
        );
      }
    } catch (error) {
      if (mounted) {
        _showSnack('Could not send email link: $error', isError: true);
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _biometricLogin() async {
    try {
      final canAuth =
          await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
      if (!canAuth) {
        _showSnack(
          'Biometric authentication not available on this device.',
          isError: true,
        );
        return;
      }
      final didAuth = await _localAuth.authenticate(
        localizedReason: 'Authenticate to login to FinEase',
      );
      if (didAuth && mounted) {
        _showSnack('✅ Biometric authentication successful!');
      }
    } catch (e) {
      if (mounted) {
        _showSnack(
          'Biometric authentication failed: ${e.toString()}',
          isError: true,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background blobs
          Positioned(
            top: -100,
            right: -100,
            child: _bgCircle(300, _primary.withValues(alpha: 0.05)),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _bgCircle(
              200,
              const Color(0xFF1BFFFF).withValues(alpha: 0.08),
            ),
          ),
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(
                horizontal: 28.0,
                vertical: 40.0,
              ),
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
                      const SizedBox(height: 30),
                      // Logo
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: [
                            BoxShadow(
                              color: _primary.withValues(alpha: 0.35),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
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
                        'Welcome back',
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          color: _dark,
                          letterSpacing: -1,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Securely access your financial world.',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          color: Colors.grey[600],
                          height: 1.5,
                        ),
                      ),

                      // Lockout warning banner
                      if (_isCurrentlyLockedOut) ...[
                        const SizedBox(height: 20),
                        _buildLockoutBanner(),
                      ],

                      const SizedBox(height: 36),

                      // ── Email ──
                      _fieldLabel('Email Address'),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _emailCtrl,
                        focusNode: _emailFocus,
                        keyboardType: TextInputType.emailAddress,
                        style: GoogleFonts.inter(fontSize: 15, color: _dark),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: _emailTouched ? _validateEmail : null,
                        onChanged: (_) => setState(() => _emailTouched = true),
                        onFieldSubmitted: (_) =>
                            FocusScope.of(context).requestFocus(_passFocus),
                        textInputAction: TextInputAction.next,
                        decoration: _fieldDeco(
                          'name@example.com',
                          Icons.alternate_email_rounded,
                        ),
                      ),
                      const SizedBox(height: 20),

                      // ── Password ──
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _fieldLabel('Password'),
                          TextButton(
                            onPressed: _forgotPassword,
                            style: TextButton.styleFrom(
                              padding: EdgeInsets.zero,
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            child: Text(
                              'Forgot Password?',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: _primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _passCtrl,
                        focusNode: _passFocus,
                        obscureText: !_showPass,
                        style: GoogleFonts.inter(fontSize: 15, color: _dark),
                        autovalidateMode: AutovalidateMode.onUserInteraction,
                        validator: _passTouched ? _validatePassword : null,
                        onChanged: (_) => setState(() => _passTouched = true),
                        onFieldSubmitted: (_) => _login(),
                        textInputAction: TextInputAction.done,
                        decoration: _fieldDeco(
                          '••••••••',
                          Icons.lock_outline_rounded,
                          suffix: IconButton(
                            icon: Icon(
                              _showPass
                                  ? Icons.visibility_off
                                  : Icons.visibility,
                              color: Colors.grey[400],
                              size: 20,
                            ),
                            onPressed: () =>
                                setState(() => _showPass = !_showPass),
                          ),
                        ),
                      ),

                      // Failed attempts indicator
                      if (_failedAttempts > 0 && _failedAttempts < 5) ...[
                        const SizedBox(height: 8),
                        _buildAttemptsWarning(),
                      ],

                      const SizedBox(height: 32),

                      // ── Login Button ──
                      _buildLoginButton(),
                      const SizedBox(height: 12),
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton.icon(
                          onPressed: _isLoading ? null : _sendEmailLink,
                          icon: const Icon(Icons.link_rounded),
                          label: Text(
                            'Email Me a Password-less Link',
                            style: GoogleFonts.plusJakartaSans(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),

                      // ── Divider ──
                      Row(
                        children: [
                          const Expanded(child: Divider()),
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: Text(
                              'OR QUICK ACCESS',
                              style: GoogleFonts.plusJakartaSans(
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                color: Colors.grey[400],
                                letterSpacing: 1.5,
                              ),
                            ),
                          ),
                          const Expanded(child: Divider()),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // ── Biometric Buttons ──
                      Row(
                        children: [
                          Expanded(
                            child: _buildBioButton(
                              Icons.fingerprint_rounded,
                              'Touch ID',
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: _buildBioButton(
                              Icons.face_unlock_rounded,
                              'Face ID',
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 40),

                      // ── Sign Up Link ──
                      Center(
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  'New to FinEase? ',
                                  style: GoogleFonts.inter(
                                    color: Colors.grey[600],
                                    fontSize: 13,
                                  ),
                                ),
                                GestureDetector(
                                  onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const SignupPage(),
                                    ),
                                  ),
                                  child: Text(
                                    'Create an account',
                                    style: GoogleFonts.inter(
                                      fontWeight: FontWeight.bold,
                                      color: _primary,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 28),
                            _buildSecurityBadges(),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Helpers ──────────────────────────────────────────────────────────────────

  Widget _bgCircle(double size, Color color) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
  );

  Widget _fieldLabel(String text) => Text(
    text,
    style: GoogleFonts.plusJakartaSans(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: _dark,
    ),
  );

  InputDecoration _fieldDeco(String hint, IconData icon, {Widget? suffix}) =>
      InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: Colors.grey[400], fontSize: 14),
        prefixIcon: Icon(icon, color: Colors.grey[400], size: 20),
        suffixIcon: suffix,
        filled: true,
        fillColor: const Color(0xFFF8F9FE),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFEEEEEE)),
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
      );

  Widget _buildLockoutBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: _error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.lock_rounded, color: _error, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Account temporarily locked. Try again in $_lockoutRemaining.',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAttemptsWarning() {
    final remaining = 5 - _failedAttempts;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFFED7AA)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Color(0xFFF97316),
            size: 16,
          ),
          const SizedBox(width: 8),
          Text(
            '$remaining attempt${remaining == 1 ? '' : 's'} remaining before lockout',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: const Color(0xFF92400E),
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [_primary, Color(0xFF1565C0)]),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.35),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading || _isCurrentlyLockedOut ? null : _login,
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
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(
                    Icons.lock_open_rounded,
                    color: Colors.white,
                    size: 18,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Login to Account',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _buildBioButton(IconData icon, String label) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFEEEEEE)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: InkWell(
        onTap: _biometricLogin,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Column(
            children: [
              Icon(icon, color: _dark, size: 28),
              const SizedBox(height: 8),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: _dark,
                ),
              ),
            ],
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
        _badge(Icons.lock_clock_rounded, 'Auto Lockout'),
        const SizedBox(width: 20),
        _badge(Icons.verified_user_rounded, 'Secure'),
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
