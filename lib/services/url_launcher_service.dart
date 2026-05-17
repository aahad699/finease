// lib/services/url_launcher_service.dart
//
// Dedicated service for launching external URLs, with proper error handling,
// logging, and user-facing fallback feedback.

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

class UrlLauncherService {
  UrlLauncherService._();
  static final UrlLauncherService instance = UrlLauncherService._();

  /// Opens [url] in an external browser.
  ///
  /// If the launch fails, a snackbar is shown via [scaffoldContext].
  Future<bool> launchExternalUrl(
    BuildContext scaffoldContext,
    String url, {
    String failMessage = 'Could not open the official website. Please try again.',
  }) async {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme) {
      _showError(scaffoldContext, 'Invalid URL: $url');
      debugPrint('[UrlLauncherService] Invalid URL provided: $url');
      return false;
    }

    try {
      final canLaunch = await canLaunchUrl(uri);
      if (!canLaunch) {
        if (scaffoldContext.mounted) _showError(scaffoldContext, failMessage);
        debugPrint('[UrlLauncherService] Cannot launch URL: $uri');
        return false;
      }

      final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched) {
        if (scaffoldContext.mounted) _showError(scaffoldContext, failMessage);
        debugPrint('[UrlLauncherService] Launch returned false for: $uri');
        return false;
      }
      return true;
    } catch (e, stack) {
      debugPrint('[UrlLauncherService] Error launching $uri — $e\n$stack');
      if (scaffoldContext.mounted) _showError(scaffoldContext, failMessage);
      return false;
    }
  }

  /// Opens a phone dialler with [phoneNumber].
  Future<void> launchPhoneDialer(BuildContext scaffoldContext, String phoneNumber) async {
    final uri = Uri.parse('tel:$phoneNumber');
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('[UrlLauncherService] Dialler error: $e');
      if (scaffoldContext.mounted) {
        _showError(scaffoldContext, 'Could not open phone dialler.');
      }
    }
  }

  /// Opens the default email client.
  Future<void> launchEmail(BuildContext scaffoldContext, String email) async {
    final uri = Uri.parse('mailto:$email');
    try {
      await launchUrl(uri);
    } catch (e) {
      debugPrint('[UrlLauncherService] Email error: $e');
      if (scaffoldContext.mounted) {
        _showError(scaffoldContext, 'Could not open email client.');
      }
    }
  }

  void _showError(BuildContext context, String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}
