import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/app_config.dart';
import '../services/app_config_service.dart';
import '../theme/app_theme.dart';

Color appConfigColor(String hex, Color fallback) {
  var value = hex.trim().replaceAll('#', '');
  if (value.startsWith('0x')) {
    value = value.substring(2);
  }
  if (value.length == 6) {
    value = 'FF$value';
  }
  if (value.length != 8) {
    return fallback;
  }
  final parsed = int.tryParse(value, radix: 16);
  return parsed == null ? fallback : Color(parsed);
}

class AppBrandLogo extends StatelessWidget {
  const AppBrandLogo({
    super.key,
    required this.logoUrl,
    this.size = 42,
    this.backgroundColor,
  });

  final String logoUrl;
  final double size;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final hasRemoteLogo = logoUrl.trim().isNotEmpty;
    final child = hasRemoteLogo
        ? Image.network(
            logoUrl.trim(),
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) =>
                Image.asset('assets/logo/logo.png', fit: BoxFit.contain),
          )
        : Image.asset('assets/logo/logo.png', fit: BoxFit.contain);

    return Container(
      width: size,
      height: size,
      padding: EdgeInsets.all(hasRemoteLogo ? 0 : size * 0.16),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: backgroundColor ?? AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
      ),
      child: child,
    );
  }
}

class AppFeatureGate extends StatelessWidget {
  const AppFeatureGate({
    super.key,
    required this.enabled,
    required this.blockedTitle,
    required this.blockedMessage,
    required this.child,
    this.blockedIcon = Icons.lock_clock_rounded,
  });

  final bool Function(AppConfig config) enabled;
  final String blockedTitle;
  final String blockedMessage;
  final IconData blockedIcon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppConfig>(
      stream: AppConfigService().watchConfig(),
      initialData: AppConfig.defaults(),
      builder: (context, snapshot) {
        final config = snapshot.data ?? AppConfig.defaults();
        final primaryColor = appConfigColor(
          config.primaryColorHex,
          AppTheme.primary,
        );
        if (config.maintenanceMode) {
          return AppBlockedScreen(
            title: '${config.brandName} is under maintenance',
            message: config.supportMessage,
            icon: Icons.construction_rounded,
            color: primaryColor,
          );
        }
        if (!enabled(config)) {
          return AppBlockedScreen(
            title: blockedTitle,
            message: blockedMessage,
            icon: blockedIcon,
            color: primaryColor,
          );
        }
        return child;
      },
    );
  }
}

class AppBlockedScreen extends StatelessWidget {
  const AppBlockedScreen({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.color = AppTheme.primary,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.background,
      appBar: Navigator.canPop(context)
          ? AppBar(
              backgroundColor: AppTheme.background,
              elevation: 0,
              leading: IconButton(
                icon: const Icon(Icons.arrow_back_ios_new_rounded),
                color: AppTheme.textPrimary,
                onPressed: () => Navigator.pop(context),
              ),
            )
          : null,
      body: AppBlockedView(
        title: title,
        message: message,
        icon: icon,
        color: color,
      ),
    );
  }
}

class AppBlockedView extends StatelessWidget {
  const AppBlockedView({
    super.key,
    required this.title,
    required this.message,
    required this.icon,
    this.color = AppTheme.primary,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 520),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: color, size: 38),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AppAnnouncementBanner extends StatelessWidget {
  const AppAnnouncementBanner({super.key, required this.config});

  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    if (!config.announcementEnabled) {
      return const SizedBox.shrink();
    }

    final primaryColor = appConfigColor(
      config.primaryColorHex,
      AppTheme.primary,
    );
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      decoration: BoxDecoration(
        color: primaryColor,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          children: [
            const Icon(Icons.campaign_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    config.announcementTitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 13,
                    ),
                  ),
                  Text(
                    config.announcementMessage,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.82),
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
