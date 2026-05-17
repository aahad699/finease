import 'dart:convert';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import '../app_constants.dart';
import 'firestore_service.dart';

class AuthService extends ChangeNotifier {
  final FirebaseAuth _auth = FirebaseAuth.instance;

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage(
    aOptions: AndroidOptions.biometric(
      enforceBiometrics: false,
      biometricPromptTitle: 'Authenticate to access FinEase',
    ),
  );

  final LocalAuthentication _localAuth = LocalAuthentication();

  User? _user;
  FirestoreService? _firestoreService;

  bool _isBiometricEnabled = false;
  String? _pendingEmailLinkAddress;
  List<BiometricType> _availableBiometrics = const [];

  // =========================
  // Getters
  // =========================

  User? get user => _user;

  FirestoreService? get firestoreService => _firestoreService;

  FirebaseAuth get firebaseAuth => _auth;

  bool get isEmailVerified => _user?.emailVerified ?? false;

  bool get canAccessProtectedFeatures => isAdmin || isEmailVerified;

  bool get isBiometricEnabled => _isBiometricEnabled;

  List<BiometricType> get availableBiometrics => _availableBiometrics;

  bool get isAdmin => _user?.email == AppConstants.adminEmail;

  bool get isDemoAccount => _user?.email == AppConstants.demoEmail;

  // =========================
  // Constructor
  // =========================

  AuthService() {
    _auth.authStateChanges().listen((User? user) async {
      _user = user;

      if (user != null) {
        // Refresh user state
        await user.reload();
        _user = _auth.currentUser;

        _firestoreService = FirestoreService(uid: user.uid);
        if (_user?.emailVerified == true ||
            _user?.email == AppConstants.adminEmail) {
          await _firestoreService?.ensureMonthlySavingsRollover();
        }
      } else {
        _firestoreService = null;
      }

      notifyListeners();
    });

    _loadBiometricState();
    _completeEmailLinkSignInIfPossible();
  }

  // =========================
  // Reload User
  // =========================

  Future<void> reloadUser() async {
    await _user?.reload();
    _user = _auth.currentUser;
    if (_user != null && _user!.emailVerified) {
      await _user!.getIdToken(true);
      await _firestoreService?.saveUserProfile({
        'emailVerified': _user!.emailVerified,
        'emailVerifiedAt': _user!.emailVerified
            ? FieldValue.serverTimestamp()
            : null,
      });
    }
    notifyListeners();
  }

  // =========================
  // Email Verification
  // =========================

  Future<void> sendEmailVerification() async {
    try {
      await _user?.reload();
      _user = _auth.currentUser;
      if (_user == null) {
        throw FirebaseAuthException(
          code: 'requires-recent-login',
          message: 'Please sign in again before requesting verification.',
        );
      }
      if (_user!.emailVerified) {
        throw FirebaseAuthException(
          code: 'already-verified',
          message: 'This email address is already verified.',
        );
      }
      await _user!.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Email verification error [${e.code}]: ${e.message}');
      }
      throw Exception(e.code);
    }
  }

  // =========================
  // Anonymous Sign In
  // =========================

  Future<void> signInAnonymously() async {
    try {
      await _auth.signInAnonymously();
    } catch (e) {
      if (kDebugMode) {
        print('Error signing in anonymously: $e');
      }
      rethrow;
    }
  }

  // =========================
  // Email Sign In
  // =========================

  Future<void> signInWithEmail(String email, String password) async {
    try {
      final credential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );

      final uid = credential.user?.uid;
      await credential.user?.reload();
      _user = _auth.currentUser;

      // Check suspended account
      if (uid != null && email != AppConstants.adminEmail) {
        final profile = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (profile.data()?['accountStatus'] == 'suspended') {
          await _auth.signOut();

          throw FirebaseAuthException(
            code: 'account-suspended',
            message: 'This account has been suspended by FinEase admin.',
          );
        }
        if (_user?.emailVerified == true) {
          await _user!.getIdToken(true);
          await FirebaseFirestore.instance.collection('users').doc(uid).set({
            'emailVerified': true,
            'emailVerifiedAt': FieldValue.serverTimestamp(),
            'lastLoginAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true));
        }
      }
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Login error [${e.code}]: ${e.message}');
      }

      throw Exception(e.code);
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected login error: $e');
      }

      rethrow;
    }
  }

  Future<void> sendPasswordlessSignInLink(String email) async {
    final normalizedEmail = email.trim();
    final settings = ActionCodeSettings(
      url: 'https://finease-27a62.web.app',
      handleCodeInApp: true,
      androidPackageName: 'com.example.finease',
      androidInstallApp: true,
      iOSBundleId: 'com.example.finease',
    );
    try {
      await _auth.sendSignInLinkToEmail(
        email: normalizedEmail,
        actionCodeSettings: settings,
      );
      _pendingEmailLinkAddress = normalizedEmail;
      await _secureStorage.write(
        key: 'pending_email_link_address',
        value: normalizedEmail,
      );
    } on FirebaseAuthException catch (e) {
      throw Exception(e.code);
    }
  }

  Future<bool> signInWithEmailLinkIfValid({
    required String email,
    required String link,
  }) async {
    if (!_auth.isSignInWithEmailLink(link)) {
      return false;
    }
    final credential = await _auth.signInWithEmailLink(
      email: email.trim(),
      emailLink: link,
    );
    await _secureStorage.delete(key: 'pending_email_link_address');
    _pendingEmailLinkAddress = null;
    await _ensureUserProfile(credential.user, email.trim());
    return true;
  }

  Future<void> _completeEmailLinkSignInIfPossible() async {
    final link = Uri.base.toString();
    if (!_auth.isSignInWithEmailLink(link)) {
      return;
    }
    final email =
        _pendingEmailLinkAddress ??
        await _secureStorage.read(key: 'pending_email_link_address');
    if (email == null || email.isEmpty) {
      return;
    }
    await signInWithEmailLinkIfValid(email: email, link: link);
  }

  // =========================
  // Email Sign Up
  // =========================

  Future<void> signUpWithEmail(
    String email,
    String password, {
    String? fullName,
  }) async {
    try {
      final credential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      final name = fullName ?? email.split('@').first;

      await credential.user?.updateDisplayName(name);

      // Refresh current user
      await credential.user?.reload();
      _user = _auth.currentUser;

      // Send verification email
      await credential.user?.sendEmailVerification();

      // Create Firestore profile
      await _ensureUserProfile(credential.user, email, fullName: name);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Signup error [${e.code}]: ${e.message}');
      }

      throw Exception(e.code);
    } catch (e) {
      if (kDebugMode) {
        print('Unexpected signup error: $e');
      }

      rethrow;
    }
  }

  Future<void> _ensureUserProfile(
    User? user,
    String email, {
    String? fullName,
  }) async {
    if (user == null) return;
    final name = fullName ?? user.displayName ?? email.split('@').first;
    await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
      'fullName': name,
      'email': email,
      'role': 'user',
      'accountStatus': 'active',
      'isDemoAccount': false,
      'currencyCode': AppConstants.currencyCode,
      'country': AppConstants.countryName,
      'memberSince': DateTime.now().year.toString(),
      'pushAlerts': true,
      'monthlyReports': true,
      'biometricLogin': false,
      'language': 'English (Pakistan)',
      'emailVerified': user.emailVerified,
      'createdAt': Timestamp.now(),
    }, SetOptions(merge: true));
  }

  // =========================
  // Password Reset
  // =========================

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      if (kDebugMode) {
        print('Reset error [${e.code}]: ${e.message}');
      }

      throw Exception(e.code);
    }
  }

  Future<void> updateProfilePhotoUrl(String photoUrl) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'requires-recent-login',
        message: 'Please sign in before updating your profile picture.',
      );
    }
    await user.updatePhotoURL(photoUrl.trim().isEmpty ? null : photoUrl.trim());
    await user.reload();
    _user = _auth.currentUser;
    await _firestoreService?.saveUserProfile({
      'photoUrl': _user?.photoURL ?? '',
      'photoDataUrl': '',
      'updatedAt': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }

  Future<void> updateProfilePhotoBytes({
    required Uint8List bytes,
    required String fileName,
    String? contentType,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseAuthException(
        code: 'requires-recent-login',
        message: 'Please sign in before updating your profile picture.',
      );
    }
    if (bytes.isEmpty) {
      throw FirebaseAuthException(
        code: 'invalid-photo',
        message: 'Please choose a valid image file.',
      );
    }

    final resolvedContentType =
        contentType ??
        switch (fileName.split('.').last.toLowerCase()) {
          'png' => 'image/png',
          'webp' => 'image/webp',
          _ => 'image/jpeg',
        };

    final photoDataUrl =
        'data:$resolvedContentType;base64,${base64Encode(bytes)}';
    await user.updatePhotoURL(null);
    await user.reload();
    _user = _auth.currentUser;
    await _firestoreService?.saveUserProfile({
      'photoUrl': '',
      'photoDataUrl': photoDataUrl,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    notifyListeners();
  }

  // =========================
  // Sign Out
  // =========================

  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      if (kDebugMode) {
        print('Error signing out: $e');
      }

      rethrow;
    }
  }

  // =========================
  // Enable Biometric Login
  // =========================

  Future<void> enableBiometricLogin({
    required String email,
    required String password,
  }) async {
    final isSupported = await canUseBiometrics();

    if (!isSupported) {
      throw Exception(
        'Biometric authentication is not available on this device.',
      );
    }

    await _secureStorage.write(key: 'biometric_email', value: email);

    await _secureStorage.write(key: 'biometric_password', value: password);

    await _secureStorage.write(key: 'biometric_enabled', value: 'true');

    _isBiometricEnabled = true;

    await _firestoreService?.saveUserProfile({'biometricLogin': true});

    notifyListeners();
  }

  // =========================
  // Disable Biometric Login
  // =========================

  Future<void> disableBiometricLogin() async {
    await _secureStorage.delete(key: 'biometric_email');

    await _secureStorage.delete(key: 'biometric_password');

    await _secureStorage.write(key: 'biometric_enabled', value: 'false');

    _isBiometricEnabled = false;

    await _firestoreService?.saveUserProfile({'biometricLogin': false});

    notifyListeners();
  }

  // =========================
  // Biometrics Available?
  // =========================

  Future<bool> canUseBiometrics() async {
    try {
      return await _localAuth.canCheckBiometrics ||
          await _localAuth.isDeviceSupported();
    } catch (_) {
      return false;
    }
  }

  // =========================
  // Get Available Biometrics
  // =========================

  Future<List<BiometricType>> getAvailableBiometrics() async {
    try {
      _availableBiometrics = await _localAuth.getAvailableBiometrics();

      notifyListeners();

      return _availableBiometrics;
    } catch (_) {
      _availableBiometrics = const [];

      notifyListeners();

      return _availableBiometrics;
    }
  }

  // =========================
  // Authenticate Biometrics
  // =========================

  Future<bool> authenticateWithBiometrics() async {
    final enabled = await _secureStorage.read(key: 'biometric_enabled');

    if (enabled != 'true') {
      return false;
    }

    final email = await _secureStorage.read(key: 'biometric_email');

    final password = await _secureStorage.read(key: 'biometric_password');

    if (email == null || password == null) {
      return false;
    }

    final isSupported = await canUseBiometrics();

    if (!isSupported) {
      return false;
    }

    final didAuthenticate = await _localAuth.authenticate(
      localizedReason:
          'Authenticate with Touch ID or Face ID to unlock FinEase',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );

    if (!didAuthenticate) {
      return false;
    }

    await signInWithEmail(email, password);

    return true;
  }

  // =========================
  // Load Biometric State
  // =========================

  Future<void> _loadBiometricState() async {
    _isBiometricEnabled =
        (await _secureStorage.read(key: 'biometric_enabled')) == 'true';

    _availableBiometrics = await getAvailableBiometrics();

    notifyListeners();
  }
}
