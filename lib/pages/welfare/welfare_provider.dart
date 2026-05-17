// lib/pages/welfare/welfare_provider.dart
//
// Provider-based state management for the welfare module.
// Handles: data fetching, search, category filtering, tag filtering,
// bookmarking, and application status tracking.
//
// Persistence strategy:
//   • SharedPreferences  → fast local cache (works offline)
//   • Firestore          → sync across devices when authenticated

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../data/welfare_program_repository.dart';
import '../../models/welfare_program.dart';
import '../../services/firestore_service.dart';

/// Employment status values used for future personalization rules.
enum EmploymentStatus {
  employed,
  selfEmployed,
  unemployed,
  student,
  retired,
  other,
}

/// Simple user profile snapshot used for personalised recommendations.
class UserProfile {
  const UserProfile({
    this.region = '',
    this.employmentStatus = EmploymentStatus.other,
    this.isLowIncome = false,
    this.isStudent = false,
    this.isDisabled = false,
    this.isWidow = false,
    this.isSMEOwner = false,
    this.needsHealthcare = false,
    this.needsEmergency = false,
  });

  final String region;
  final EmploymentStatus employmentStatus;
  final bool isLowIncome;
  final bool isStudent;
  final bool isDisabled;
  final bool isWidow;
  final bool isSMEOwner;
  final bool needsHealthcare;
  final bool needsEmergency;

  /// Build a UserProfile from a Firestore user document.
  factory UserProfile.fromFirestoreData(Map<String, dynamic> data) {
    final income = (data['monthlyIncome'] as num?)?.toDouble() ?? 0;
    final employmentString =
        (data['employmentStatus'] as String?)?.toLowerCase() ?? '';
    EmploymentStatus employmentStatus = EmploymentStatus.other;
    switch (employmentString) {
      case 'employed':
      case 'salaried':
        employmentStatus = EmploymentStatus.employed;
        break;
      case 'self-employed':
      case 'self employed':
        employmentStatus = EmploymentStatus.selfEmployed;
        break;
      case 'unemployed':
        employmentStatus = EmploymentStatus.unemployed;
        break;
      case 'student':
        employmentStatus = EmploymentStatus.student;
        break;
      case 'retired':
        employmentStatus = EmploymentStatus.retired;
        break;
      default:
        employmentStatus = EmploymentStatus.other;
    }
    return UserProfile(
      region: data['region'] as String? ?? '',
      employmentStatus: employmentStatus,
      // Income under 45k/month is considered low-income for recommendation engine
      isLowIncome: income > 0 && income < 45000,
      isStudent: data['isStudent'] as bool? ?? false,
      isDisabled: data['isDisabled'] as bool? ?? false,
      isWidow: data['isWidow'] as bool? ?? false,
      isSMEOwner: data['isSMEOwner'] as bool? ?? false,
      needsHealthcare: data['needsHealthcare'] as bool? ?? false,
      needsEmergency: data['needsEmergency'] as bool? ?? false,
    );
  }
}

class WelfareProvider extends ChangeNotifier {
  WelfareProvider({this.uid, this.firestoreService}) {
    _init();
  }

  /// Authenticated user UID — null when not signed in.
  final String? uid;

  /// Shared FirestoreService from AuthService.
  final FirestoreService? firestoreService;

  // ── State ────────────────────────────────────────────────────────────────
  bool _isLoading = true;
  String? _error;
  List<WelfareProgram> _allPrograms = [];
  String _searchQuery = '';
  WelfareCategory? _selectedCategory; // null = All
  final Set<String> _selectedTags = <String>{};

  // Persistence keys (SharedPreferences)
  static const _kBookmarks = 'welfare_bookmarks_v1';
  static const _kAppStatuses = 'welfare_app_status_v1';

  final Map<String, bool> _bookmarks = {};
  final Map<String, ApplicationStatus> _appStatuses = {};

  // Default profile — overwritten by Firestore data after login
  UserProfile _userProfile = const UserProfile();

  // ── Getters ──────────────────────────────────────────────────────────────
  bool get isLoading => _isLoading;
  String? get error => _error;
  String get searchQuery => _searchQuery;
  WelfareCategory? get selectedCategory => _selectedCategory;
  Set<String> get selectedTags => _selectedTags;
  UserProfile get userProfile => _userProfile;
  bool get hasActiveFilters =>
      _searchQuery.isNotEmpty ||
      _selectedCategory != null ||
      _selectedTags.isNotEmpty;
  int get activeFilterCount =>
      (_searchQuery.isNotEmpty ? 1 : 0) +
      (_selectedCategory != null ? 1 : 0) +
      (_selectedTags.isNotEmpty ? _selectedTags.length : 0);

  List<WelfareProgram> get filteredPrograms {
    return _allPrograms.where((p) {
      if (!p.isActive) return false;
      final matchSearch = p.matchesQuery(_searchQuery);
      final matchCat = p.matchesCategory(_selectedCategory);
      final matchTags = p.matchesTags(_selectedTags);
      return matchSearch && matchCat && matchTags;
    }).toList();
  }

  /// Programs relevant to the current user profile for the "Recommended" section.
  List<WelfareProgram> get recommendedPrograms {
    final scoredPrograms = _allPrograms
        .where((program) => program.isActive)
        .map((program) => MapEntry(program, _recommendationScore(program)))
        .where((entry) => entry.value > 0)
        .toList();

    scoredPrograms.sort((a, b) => b.value.compareTo(a.value));
    return scoredPrograms.take(3).map((entry) => entry.key).toList();
  }

  bool isBookmarked(String id) => _bookmarks[id] == true;
  ApplicationStatus? applicationStatus(String id) => _appStatuses[id];
  int get bookmarkCount => _bookmarks.values.where((v) => v).length;

  List<WelfareProgram> get bookmarkedPrograms =>
      _allPrograms.where((p) => isBookmarked(p.id)).toList();

  int _recommendationScore(WelfareProgram program) {
    var score = 0;
    if (_userProfile.isLowIncome && program.forLowIncome) score += 6;
    if (_userProfile.isStudent && program.forStudents) score += 6;
    if (_userProfile.isDisabled && program.forDisabled) score += 5;
    if (_userProfile.isWidow && program.forWidows) score += 5;
    if (_userProfile.isSMEOwner && program.forSME) score += 4;
    if (_userProfile.needsHealthcare && program.forHealthcare) score += 4;
    if (_userProfile.needsEmergency && program.forEmergency) score += 4;
    if (_userProfile.region.isNotEmpty && program.regionRestriction != null) {
      if (program.regionRestriction!.toLowerCase().contains(
        _userProfile.region.toLowerCase(),
      )) {
        score += 2;
      } else {
        score -= 3;
      }
    }
    if (program.isVerified) score += 1;
    return score;
  }

  // ── Actions ──────────────────────────────────────────────────────────────
  void setSearch(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setCategory(WelfareCategory? category) {
    _selectedCategory = category;
    notifyListeners();
  }

  void toggleTag(String tag) {
    if (_selectedTags.contains(tag)) {
      _selectedTags.remove(tag);
    } else {
      _selectedTags.add(tag);
    }
    notifyListeners();
  }

  void clearFilters() {
    _searchQuery = '';
    _selectedCategory = null;
    _selectedTags.clear();
    notifyListeners();
  }

  Future<void> toggleBookmark(String id) async {
    _bookmarks[id] = !(_bookmarks[id] ?? false);
    notifyListeners();
    await Future.wait([_persistBookmarksLocal(), _persistBookmarksFirestore()]);
  }

  Future<void> setApplicationStatus(String id, ApplicationStatus status) async {
    _appStatuses[id] = status;
    notifyListeners();
    await Future.wait([_persistStatusesLocal(), _persistStatusesFirestore()]);
  }

  void updateUserProfile(UserProfile profile) {
    _userProfile = profile;
    notifyListeners();
  }

  Future<void> refresh() async {
    _isLoading = true;
    _error = null;
    notifyListeners();
    await _loadPrograms();
  }

  // ── Private init ─────────────────────────────────────────────────────────
  Future<void> _init() async {
    // Load persisted data and user profile in parallel with programs
    await Future.wait([_loadPersistedData(), _loadUserProfile()]);
    await _loadPrograms();
  }

  Future<void> _loadPrograms() async {
    try {
      _allPrograms = await WelfareProgramRepository.instance.fetchPrograms();
      _error = null;
    } catch (e) {
      _error =
          'Failed to load programs. Please check your connection and try again.';
      debugPrint('[WelfareProvider] $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Loads the real user profile from Firestore and maps it to UserProfile flags.
  Future<void> _loadUserProfile() async {
    if (uid == null || firestoreService == null) return;
    try {
      final data = await firestoreService!.getUserProfile().first;
      _userProfile = UserProfile.fromFirestoreData(data);
    } catch (e) {
      debugPrint('[WelfareProvider] Could not load user profile: $e');
    }
  }

  // ── Local persistence (SharedPreferences) ────────────────────────────────
  Future<void> _loadPersistedData() async {
    final prefs = await SharedPreferences.getInstance();

    // Bookmarks
    final bookmarkKeys = prefs.getStringList(_kBookmarks) ?? [];
    for (final k in bookmarkKeys) {
      _bookmarks[k] = true;
    }

    // Application statuses
    final statusJson = prefs.getStringList(_kAppStatuses) ?? [];
    for (final entry in statusJson) {
      final parts = entry.split(':');
      if (parts.length == 2) {
        final idx = int.tryParse(parts[1]);
        if (idx != null && idx < ApplicationStatus.values.length) {
          _appStatuses[parts[0]] = ApplicationStatus.values[idx];
        }
      }
    }

    // Also merge from Firestore (cross-device sync)
    await _loadFirestorePersistedData();
  }

  Future<void> _persistBookmarksLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final keys = _bookmarks.entries
        .where((e) => e.value)
        .map((e) => e.key)
        .toList();
    await prefs.setStringList(_kBookmarks, keys);
  }

  Future<void> _persistStatusesLocal() async {
    final prefs = await SharedPreferences.getInstance();
    final entries = _appStatuses.entries
        .map((e) => '${e.key}:${e.value.index}')
        .toList();
    await prefs.setStringList(_kAppStatuses, entries);
  }

  // ── Firestore persistence (cross-device sync) ─────────────────────────────
  static final _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>>? get _bookmarkRef => uid == null
      ? null
      : _db.collection('users').doc(uid).collection('welfare_bookmarks');

  CollectionReference<Map<String, dynamic>>? get _statusRef => uid == null
      ? null
      : _db.collection('users').doc(uid).collection('welfare_statuses');

  /// Load bookmarks/statuses from Firestore on startup (merge on top of local cache).
  Future<void> _loadFirestorePersistedData() async {
    if (uid == null) return;
    try {
      final bookmarkSnap = await _bookmarkRef!.get();
      for (final doc in bookmarkSnap.docs) {
        _bookmarks[doc.id] = doc.data()['bookmarked'] as bool? ?? true;
      }

      final statusSnap = await _statusRef!.get();
      for (final doc in statusSnap.docs) {
        final idx = doc.data()['statusIndex'] as int?;
        if (idx != null && idx < ApplicationStatus.values.length) {
          _appStatuses[doc.id] = ApplicationStatus.values[idx];
        }
      }
    } catch (e) {
      debugPrint('[WelfareProvider] Firestore load skipped (offline?): $e');
    }
  }

  Future<void> _persistBookmarksFirestore() async {
    if (_bookmarkRef == null) return;
    try {
      final batch = _db.batch();
      for (final entry in _bookmarks.entries) {
        final ref = _bookmarkRef!.doc(entry.key);
        if (entry.value) {
          batch.set(ref, {
            'bookmarked': true,
            'updatedAt': FieldValue.serverTimestamp(),
          });
        } else {
          batch.delete(ref);
        }
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[WelfareProvider] Bookmark Firestore sync failed: $e');
    }
  }

  Future<void> _persistStatusesFirestore() async {
    if (_statusRef == null) return;
    try {
      final batch = _db.batch();
      for (final entry in _appStatuses.entries) {
        batch.set(_statusRef!.doc(entry.key), {
          'statusIndex': entry.value.index,
          'statusName': entry.value.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {
      debugPrint('[WelfareProvider] Status Firestore sync failed: $e');
    }
  }
}

/// All filter tags shown in the secondary tag filter bar.
const List<String> kWelfareTags = [
  'student',
  'low-income',
  'healthcare',
  'emergency',
  'loan',
  'loans',
  'scholarship',
  'youth',
  'disabled',
  'widow',
  'SME',
  'housing',
  'government',
];
