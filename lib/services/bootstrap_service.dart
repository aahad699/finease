import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';

import '../app_constants.dart';
import '../data/demo_finance_data.dart';
import '../models/app_config.dart';

class BootstrapService {
  static Future<void> ensureSpecialAccounts() async {
    final bootstrapApp = await Firebase.initializeApp(
      name: 'finease-bootstrap',
      options: Firebase.app().options,
    );
    final auth = FirebaseAuth.instanceFor(app: bootstrapApp);
    final db = FirebaseFirestore.instanceFor(app: bootstrapApp);

    try {
      await _ensureAccount(
        auth: auth,
        db: db,
        email: AppConstants.demoEmail,
        password: AppConstants.demoPassword,
        profile: {
          'fullName': 'FinEase Demo',
          'email': AppConstants.demoEmail,
          'role': 'demo',
          'isDemoAccount': true,
          'currencyCode': AppConstants.currencyCode,
          'country': AppConstants.countryName,
          'memberSince': '2026',
          'monthlyIncome': 180000.0,
          'targetSavingsRate': 0.15,
          'pushAlerts': true,
          'monthlyReports': true,
          'biometricLogin': false,
          'language': 'English (Pakistan)',
        },
        seedDemoData: true,
      );

      await _ensureAccount(
        auth: auth,
        db: db,
        email: AppConstants.adminEmail,
        password: AppConstants.adminPassword,
        profile: {
          'fullName': 'FinEase Admin',
          'email': AppConstants.adminEmail,
          'role': 'admin',
          'isDemoAccount': false,
          'currencyCode': AppConstants.currencyCode,
          'country': AppConstants.countryName,
          'memberSince': '2026',
          'pushAlerts': true,
          'monthlyReports': true,
          'biometricLogin': false,
          'language': 'English (Pakistan)',
        },
      );

      await _seedMarketplace(db);
      await _seedSystemMetrics(db);
      await _seedAppConfig(db);
    } finally {
      await auth.signOut();
      await bootstrapApp.delete();
    }
  }

  static Future<void> _ensureAccount({
    required FirebaseAuth auth,
    required FirebaseFirestore db,
    required String email,
    required String password,
    required Map<String, dynamic> profile,
    bool seedDemoData = false,
  }) async {
    UserCredential credential;
    try {
      credential = await auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      if (e.code != 'user-not-found' && e.code != 'invalid-credential') {
        rethrow;
      }
      credential = await auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    }

    final user = credential.user;
    if (user == null) {
      return;
    }

    await user.updateDisplayName(profile['fullName'] as String? ?? 'FinEase');

    final userRef = db.collection('users').doc(user.uid);
    final profileSnapshot = await userRef.get();
    await userRef.set(profile, SetOptions(merge: true));

    if (seedDemoData && !profileSnapshot.exists) {
      await _seedDemoUserData(userRef);
    }

    await auth.signOut();
  }

  static Future<void> _seedDemoUserData(
    DocumentReference<Map<String, dynamic>> userRef,
  ) async {
    final batch = userRef.firestore.batch();

    for (final transaction in DemoFinanceData.sampleTransactions()) {
      batch.set(userRef.collection('transactions').doc(), transaction.toMap());
    }

    for (final budget in DemoFinanceData.sampleBudgetPlans()) {
      final map = budget.toMap();
      map['createdAt'] = FieldValue.serverTimestamp();
      batch.set(userRef.collection('budget_plans').doc(), map);
    }

    for (final goal in DemoFinanceData.sampleGoals()) {
      final map = goal.toMap();
      map['createdAt'] = FieldValue.serverTimestamp();
      batch.set(userRef.collection('saving_goals').doc(), map);
    }

    batch.set(userRef, DemoFinanceData.sampleProfile, SetOptions(merge: true));
    await batch.commit();
  }

  static Future<void> _seedMarketplace(FirebaseFirestore db) async {
    final partnersRef = db.collection('marketplace_partners');
    final batch = db.batch();
    for (final partner in DemoFinanceData.marketplacePartners) {
      batch.set(
        partnersRef.doc(partner['id'] as String),
        partner,
        SetOptions(merge: true),
      );
    }
    await batch.commit();
  }

  static Future<void> _seedSystemMetrics(FirebaseFirestore db) async {
    await db.collection('system_metrics').doc('overview').set({
      'activeUsers': 12842,
      'latencyMs': 12,
      'pendingWelfare': 42,
      'urgentReviews': 12,
    }, SetOptions(merge: true));
  }

  static Future<void> _seedAppConfig(FirebaseFirestore db) async {
    await db.collection('app_config').doc('global').set({
      ...AppConfig.defaults().toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
