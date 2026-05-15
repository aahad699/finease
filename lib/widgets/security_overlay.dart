import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import '../services/security_service.dart';

class SecurityOverlay extends StatefulWidget {
  final Widget child;
  const SecurityOverlay({super.key, required this.child});

  @override
  State<SecurityOverlay> createState() => _SecurityOverlayState();
}

class _SecurityOverlayState extends State<SecurityOverlay>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      // Lock the app when it goes to background
      context.read<SecurityService>().lockApp();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SecurityService>(
      builder: (context, security, child) {
        return Stack(
          children: [
            widget.child,
            if (security.isAppLocked)
              Positioned.fill(
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.7),
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.1),
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white24),
                            ),
                            child: const Icon(
                              Icons.lock_rounded,
                              color: Colors.white,
                              size: 64,
                            ),
                          ),
                          const SizedBox(height: 32),
                          Text(
                            'FinEase is Locked',
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Secure access required',
                            style: GoogleFonts.inter(
                              fontSize: 14,
                              color: Colors.white60,
                            ),
                          ),
                          const SizedBox(height: 48),
                          ElevatedButton.icon(
                            onPressed: () => security.unlockApp(),
                            icon: const Icon(Icons.fingerprint_rounded),
                            label: const Text('Unlock with Biometrics'),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2E3192),
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 32,
                                vertical: 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
