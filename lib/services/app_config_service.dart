import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/app_config.dart';

class AppConfigService {
  AppConfigService({FirebaseFirestore? firestore})
    : _db = firestore ?? FirebaseFirestore.instance;

  final FirebaseFirestore _db;

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _db.collection('app_config').doc('global');

  Stream<AppConfig> watchConfig() {
    return _configRef.snapshots().map((snapshot) {
      return AppConfig.fromMap(snapshot.data());
    });
  }

  Future<AppConfig> getConfig() async {
    final snapshot = await _configRef.get();
    return AppConfig.fromMap(snapshot.data());
  }

  Future<void> saveConfig(AppConfig config) {
    return _configRef.set({
      ...config.toMap(),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> updateConfig(Map<String, dynamic> data) {
    return _configRef.set({
      ...data,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}
