import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';

class EmailVerificationPage extends StatefulWidget {
  const EmailVerificationPage({super.key});

  @override
  State<EmailVerificationPage> createState() => _EmailVerificationPageState();
}

class _EmailVerificationPageState extends State<EmailVerificationPage> {
  bool _checking = false;
  bool _resending = false;

  Future<void> _checkStatus() async {
    setState(() => _checking = true);
    final auth = context.read<AuthService>();
    try {
      await auth.reloadUser();
      if (!mounted) return;
      if (auth.isEmailVerified) {
        _showSnack('Email verified. Welcome to FinEase.');
      } else {
        _showSnack(
          'Email is not verified yet. If the link expired, resend a fresh verification email.',
          isError: true,
        );
      }
    } catch (_) {
      if (mounted) {
        _showSnack(
          'Could not refresh verification status. Check your connection and try again.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    try {
      await context.read<AuthService>().sendEmailVerification();
      if (mounted) {
        _showSnack(
          'Verification email sent. Check your inbox and spam folder.',
        );
      }
    } catch (error) {
      if (mounted) {
        _showSnack(_friendlyVerificationError(error.toString()), isError: true);
      }
    } finally {
      if (mounted) setState(() => _resending = false);
    }
  }

  String _friendlyVerificationError(String raw) {
    if (raw.contains('already-verified')) {
      return 'This email is already verified. Tap I Verified My Email to continue.';
    }
    if (raw.contains('invalid-email')) {
      return 'This account email is invalid. Sign out and register with a valid email.';
    }
    if (raw.contains('too-many-requests')) {
      return 'Too many verification emails were requested. Please wait before trying again.';
    }
    if (raw.contains('network')) {
      return 'Network error. Check your internet connection and try again.';
    }
    return 'Could not send verification email. Please try again.';
  }

  void _showSnack(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppTheme.error : AppTheme.success,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final email = auth.user?.email ?? 'your email address';

    return Scaffold(
      backgroundColor: AppTheme.backgroundFor(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: AppTheme.surfaceFor(context),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: AppTheme.borderFor(context)),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(18),
                      ),
                      child: Icon(
                        Icons.mark_email_unread_rounded,
                        color: AppTheme.primary,
                        size: 30,
                      ),
                    ),
                    const SizedBox(height: 22),
                    Text(
                      'Verify your email',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimaryFor(context),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'We sent a verification link to $email. FinEase stays locked until this email is verified.',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondaryFor(context),
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFF7ED),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: const Color(0xFFFED7AA)),
                      ),
                      child: Text(
                        'If your verification link is expired or already used, request a fresh email below.',
                        style: GoogleFonts.inter(
                          color: const Color(0xFF92400E),
                          fontWeight: FontWeight.w600,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        onPressed: _checking ? null : _checkStatus,
                        icon: _checking
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Icon(Icons.verified_rounded),
                        label: Text(
                          _checking ? 'Checking...' : 'I Verified My Email',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: _resending ? null : _resend,
                        icon: _resending
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : Icon(Icons.refresh_rounded),
                        label: Text(
                          _resending
                              ? 'Sending...'
                              : 'Resend Verification Email',
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => auth.signOut(),
                      icon: Icon(Icons.logout_rounded),
                      label: const Text('Use another account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
