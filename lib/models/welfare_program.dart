// lib/models/welfare_program.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Taxonomy of financial assistance categories used across the welfare module.
enum WelfareCategory {
  emergency(
    'Emergency Support',
    Icons.emergency_outlined,
    Color(0xFFFFEDD5),
    Color(0xFF9A3412),
  ),
  education(
    'Education Funding',
    Icons.school_outlined,
    Color(0xFFDBFCE7),
    Color(0xFF166534),
  ),
  healthcare(
    'Healthcare Support',
    Icons.local_hospital_outlined,
    Color(0xFFFFE4E6),
    Color(0xFF9F1239),
  ),
  business(
    'Business & Loans',
    Icons.account_balance_outlined,
    Color(0xFFE0F2FE),
    Color(0xFF075985),
  ),
  housing(
    'Housing',
    Icons.home_work_outlined,
    Color(0xFFEDE9FE),
    Color(0xFF5B21B6),
  ),
  relief(
    'Relief Programs',
    Icons.volunteer_activism_outlined,
    Color(0xFFFCE7F3),
    Color(0xFF9D174D),
  );

  const WelfareCategory(
    this.displayName,
    this.icon,
    this.badgeColor,
    this.badgeTextColor,
  );

  final String displayName;
  final IconData icon;
  final Color badgeColor;
  final Color badgeTextColor;
}

/// Reflects how complex/difficult the application process is.
enum DifficultyLevel {
  easy('Easy', Color(0xFF059669)),
  moderate('Moderate', Color(0xFFD97706)),
  complex('Complex', Color(0xFFDC2626));

  const DifficultyLevel(this.label, this.color);
  final String label;
  final Color color;
}

/// Application tracking status a user can assign to a program.
enum ApplicationStatus { saved, applied, inReview, approved, rejected }

/// A single step in the application process.
class ApplicationStep {
  const ApplicationStep({
    required this.stepNumber,
    required this.title,
    required this.description,
  });

  final int stepNumber;
  final String title;
  final String description;

  factory ApplicationStep.fromMap(Map<String, dynamic> map) => ApplicationStep(
    stepNumber: (map['stepNumber'] as num?)?.toInt() ?? 0,
    title: map['title'] as String? ?? '',
    description: map['description'] as String? ?? '',
  );

  Map<String, dynamic> toMap() => {
    'stepNumber': stepNumber,
    'title': title,
    'description': description,
  };
}

/// Strongly typed model for a welfare / financial assistance program.
class WelfareProgram {
  const WelfareProgram({
    required this.id,
    required this.title,
    required this.organization,
    required this.description,
    required this.category,
    required this.tags,
    required this.officialUrl,
    required this.eligibilityCriteria,
    required this.requiredDocuments,
    required this.applicationSteps,
    required this.difficulty,
    required this.estimatedSupportValue,
    required this.supportValueLabel,
    required this.helplineNumber,
    required this.helplineEmail,
    this.isVerified = true,
    this.isActive = true,
    this.regionRestriction,
    // Personalisation matching fields
    this.forLowIncome = false,
    this.forStudents = false,
    this.forDisabled = false,
    this.forWidows = false,
    this.forSME = false,
    this.forHealthcare = false,
    this.forEmergency = false,
  });

  final String id;
  final String title;
  final String organization;
  final String description;
  final WelfareCategory category;
  final List<String> tags;
  final String officialUrl;

  // Detail page fields
  final List<String> eligibilityCriteria;
  final List<String> requiredDocuments;
  final List<ApplicationStep> applicationSteps;
  final DifficultyLevel difficulty;
  final String estimatedSupportValue; // e.g. "PKR 2,000/month"
  final String supportValueLabel; // e.g. "Monthly cash transfer"
  final String helplineNumber;
  final String helplineEmail;

  // Metadata
  final bool isVerified;
  final bool isActive;
  final String? regionRestriction; // null = national

  // Personalisation flags
  final bool forLowIncome;
  final bool forStudents;
  final bool forDisabled;
  final bool forWidows;
  final bool forSME;
  final bool forHealthcare;
  final bool forEmergency;

  /// Case-insensitive full-text search across key fields.
  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final q = query.toLowerCase();
    return title.toLowerCase().contains(q) ||
        organization.toLowerCase().contains(q) ||
        description.toLowerCase().contains(q) ||
        tags.any((t) => t.toLowerCase().contains(q)) ||
        category.displayName.toLowerCase().contains(q);
  }

  bool matchesCategory(WelfareCategory? cat) => cat == null || category == cat;

  bool matchesTags(Set<String> tags) {
    if (tags.isEmpty) return true;
    final selected = tags.map((t) => t.toLowerCase()).toSet();
    final programTags = this.tags.map((t) => t.toLowerCase()).toSet();
    return selected.every(
      (tag) => programTags.any(
        (programTag) => programTag.contains(tag) || tag.contains(programTag),
      ),
    );
  }

  // ── Firestore serialisation ─────────────────────────────────────────────────

  factory WelfareProgram.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return WelfareProgram.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory WelfareProgram.fromMap(Map<String, dynamic> m, {String? id}) {
    WelfareCategory cat(String? s) => WelfareCategory.values.firstWhere(
      (c) => c.name == s,
      orElse: () => WelfareCategory.relief,
    );
    DifficultyLevel diff(String? s) => DifficultyLevel.values.firstWhere(
      (d) => d.name == s,
      orElse: () => DifficultyLevel.moderate,
    );
    final rawSteps = (m['applicationSteps'] as List<dynamic>? ?? []);
    return WelfareProgram(
      id: id ?? m['id'] as String? ?? '',
      title: m['title'] as String? ?? '',
      organization: m['organization'] as String? ?? '',
      description: m['description'] as String? ?? '',
      category: cat(m['category'] as String?),
      tags: List<String>.from(m['tags'] as List? ?? []),
      officialUrl: m['officialUrl'] as String? ?? '',
      eligibilityCriteria: List<String>.from(
        m['eligibilityCriteria'] as List? ?? [],
      ),
      requiredDocuments: List<String>.from(
        m['requiredDocuments'] as List? ?? [],
      ),
      applicationSteps: rawSteps
          .map(
            (s) => ApplicationStep.fromMap(Map<String, dynamic>.from(s as Map)),
          )
          .toList(),
      difficulty: diff(m['difficulty'] as String?),
      estimatedSupportValue: m['estimatedSupportValue'] as String? ?? '',
      supportValueLabel: m['supportValueLabel'] as String? ?? '',
      helplineNumber: m['helplineNumber'] as String? ?? '',
      helplineEmail: m['helplineEmail'] as String? ?? '',
      isVerified: m['isVerified'] as bool? ?? true,
      isActive: m['isActive'] as bool? ?? true,
      regionRestriction: m['regionRestriction'] as String?,
      forLowIncome: m['forLowIncome'] as bool? ?? false,
      forStudents: m['forStudents'] as bool? ?? false,
      forDisabled: m['forDisabled'] as bool? ?? false,
      forWidows: m['forWidows'] as bool? ?? false,
      forSME: m['forSME'] as bool? ?? false,
      forHealthcare: m['forHealthcare'] as bool? ?? false,
      forEmergency: m['forEmergency'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'organization': organization,
    'description': description,
    'category': category.name,
    'tags': tags,
    'officialUrl': officialUrl,
    'eligibilityCriteria': eligibilityCriteria,
    'requiredDocuments': requiredDocuments,
    'applicationSteps': applicationSteps.map((s) => s.toMap()).toList(),
    'difficulty': difficulty.name,
    'estimatedSupportValue': estimatedSupportValue,
    'supportValueLabel': supportValueLabel,
    'helplineNumber': helplineNumber,
    'helplineEmail': helplineEmail,
    'isVerified': isVerified,
    'isActive': isActive,
    'regionRestriction': regionRestriction,
    'forLowIncome': forLowIncome,
    'forStudents': forStudents,
    'forDisabled': forDisabled,
    'forWidows': forWidows,
    'forSME': forSME,
    'forHealthcare': forHealthcare,
    'forEmergency': forEmergency,
  };
}
