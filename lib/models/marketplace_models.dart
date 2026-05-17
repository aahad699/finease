import 'dart:math' as math;

import 'saving_goal.dart';

class MarketplacePartner {
  MarketplacePartner({
    required this.id,
    required this.name,
    required this.description,
    required this.category,
    required this.badge,
    required this.ctaLabel,
    required this.colorHex,
    required this.iconName,
    required this.websiteUrl,
    required this.priority,
    required this.approved,
    required this.latitude,
    required this.longitude,
    required this.rating,
    required this.reviewCount,
    required this.trustScore,
    required this.isVerified,
    required this.isFeatured,
    required this.isTrending,
    required this.tags,
    required this.benefits,
    required this.eligibility,
    required this.requirements,
    required this.safetySignals,
    required this.riskIndicators,
    required this.rateLabel,
    required this.approvalSpeed,
    required this.estimatedBenefit,
    required this.minimumIncome,
    required this.maxAmount,
    required this.shariahCompliant,
    required this.locationLabel,
  });

  factory MarketplacePartner.fromMap(Map<String, dynamic> data) {
    final badge = (data['badge'] as String? ?? '').trim();
    final category = (data['category'] as String? ?? 'General').trim();
    final tags = _stringList(data['tags']);
    final approved = data['approved'] as bool? ?? true;
    final explicitVerified = data['verified'] as bool?;
    final verified =
        explicitVerified ??
        approved ||
            badge.toLowerCase().contains('verified') ||
            tags.any((tag) => tag.toLowerCase() == 'verified');
    final priority = (data['priority'] as num?)?.toInt() ?? 99;
    final featured = data['featured'] as bool? ?? priority <= 2;
    final trending =
        data['trending'] as bool? ??
        badge.toLowerCase().contains('popular') ||
            badge.toLowerCase().contains('new');
    final rating =
        (data['rating'] as num?)?.toDouble() ?? _fallbackRating(priority);
    final reviewCount =
        (data['reviewCount'] as num?)?.toInt() ??
        (100 + ((6 - math.min(priority, 5)) * 28)).toInt();
    final trustScore =
        (data['trustScore'] as num?)?.toDouble() ??
        _fallbackTrustScore(
          priority: priority,
          verified: verified,
          rating: rating,
          reviewCount: reviewCount,
        );

    return MarketplacePartner(
      id: data['id'] as String? ?? '',
      name: data['name'] as String? ?? 'Partner',
      description: data['description'] as String? ?? '',
      category: category.isEmpty ? 'General' : category,
      badge: badge,
      ctaLabel: data['ctaLabel'] as String? ?? 'View details',
      colorHex: (data['colorHex'] as num?)?.toInt() ?? 0xFF2E3192,
      iconName: data['iconName'] as String? ?? 'storefront',
      websiteUrl: data['websiteUrl'] as String?,
      priority: priority,
      approved: approved,
      latitude: (data['latitude'] as num?)?.toDouble(),
      longitude: (data['longitude'] as num?)?.toDouble(),
      rating: rating,
      reviewCount: reviewCount,
      trustScore: trustScore,
      isVerified: verified,
      isFeatured: featured,
      isTrending: trending,
      tags: _mergeTags(
        category: category,
        badge: badge,
        rawTags: tags,
        shariahCompliant: data['shariahCompliant'] as bool? ?? false,
      ),
      benefits: _stringList(
        data['benefits'],
      ).ifEmpty(_fallbackBenefits(category)),
      eligibility: _stringList(
        data['eligibility'],
      ).ifEmpty(_fallbackEligibility(category)),
      requirements: _stringList(data['requirements']),
      safetySignals: _stringList(
        data['safetySignals'],
      ).ifEmpty(_fallbackSafetySignals(verified: verified, rating: rating)),
      riskIndicators: _stringList(
        data['riskIndicators'],
      ).ifEmpty(_fallbackRiskIndicators(category)),
      rateLabel: data['rateLabel'] as String? ?? _fallbackRateLabel(category),
      approvalSpeed:
          data['approvalSpeed'] as String? ?? _fallbackApprovalSpeed(category),
      estimatedBenefit:
          data['estimatedBenefit'] as String? ??
          _fallbackEstimatedBenefit(category),
      minimumIncome: (data['minimumIncome'] as num?)?.toDouble(),
      maxAmount: (data['maxAmount'] as num?)?.toDouble(),
      shariahCompliant: data['shariahCompliant'] as bool? ?? false,
      locationLabel: data['locationLabel'] as String?,
    );
  }

  final String id;
  final String name;
  final String description;
  final String category;
  final String badge;
  final String ctaLabel;
  final int colorHex;
  final String iconName;
  final String? websiteUrl;
  final int priority;
  final bool approved;
  final double? latitude;
  final double? longitude;
  final double rating;
  final int reviewCount;
  final double trustScore;
  final bool isVerified;
  final bool isFeatured;
  final bool isTrending;
  final List<String> tags;
  final List<String> benefits;
  final List<String> eligibility;
  final List<String> requirements;
  final List<String> safetySignals;
  final List<String> riskIndicators;
  final String rateLabel;
  final String approvalSpeed;
  final String estimatedBenefit;
  final double? minimumIncome;
  final double? maxAmount;
  final bool shariahCompliant;
  final String? locationLabel;

  bool get hasLocation => latitude != null && longitude != null;

  bool matchesQuery(String query) {
    if (query.trim().isEmpty) return true;
    final normalized = query.trim().toLowerCase();
    final haystack = <String>[
      name,
      description,
      category,
      badge,
      rateLabel,
      approvalSpeed,
      estimatedBenefit,
      ...tags,
      ...benefits,
      ...eligibility,
    ].join(' ').toLowerCase();
    return haystack.contains(normalized);
  }

  bool matchesCategory(String categoryValue) {
    return categoryValue == 'All' || category == categoryValue;
  }

  bool matchesTags(Set<String> selectedTags) {
    if (selectedTags.isEmpty) return true;
    final normalizedTags = tags.map((tag) => tag.toLowerCase()).toSet();
    return selectedTags.every(
      (tag) => normalizedTags.contains(tag.toLowerCase()),
    );
  }

  int relevanceScore({
    required Map<String, dynamic> profile,
    required List<SavingGoal> goals,
  }) {
    final income = (profile['monthlyIncome'] as num?)?.toDouble() ?? 0;
    final fullName = (profile['fullName'] as String? ?? '').toLowerCase();
    final goalNames = goals
        .map((goal) => '${goal.title} ${goal.category}'.toLowerCase())
        .join(' ');

    var score = 0;
    if (category == 'Loans' && income > 0 && income < 300000) score += 3;
    if (category == 'Insurance' && goalNames.contains('emergency')) score += 3;
    if (category == 'Education' &&
        (goalNames.contains('student') || fullName.contains('student'))) {
      score += 2;
    }
    if (category == 'Utilities' && income > 0) score += 2;
    if (category == 'Jobs' && goalNames.contains('income')) score += 2;
    if (shariahCompliant) score += 1;
    if (isVerified) score += 1;
    if (isFeatured) score += 1;
    return score;
  }

  static List<String> allSuggestedTags(Iterable<MarketplacePartner> partners) {
    final values = <String>{
      'Islamic',
      'Low interest',
      'Fast approval',
      'Verified',
      'Family',
    };
    for (final partner in partners) {
      values.addAll(partner.tags);
    }
    final sorted = values.toList()..sort();
    return sorted;
  }

  static List<String> _stringList(dynamic value) {
    if (value is Iterable) {
      return value
          .map((item) => '$item'.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    if (value is String && value.trim().isNotEmpty) {
      return value
          .split(',')
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toList();
    }
    return const [];
  }

  static List<String> _mergeTags({
    required String category,
    required String badge,
    required List<String> rawTags,
    required bool shariahCompliant,
  }) {
    final tags = <String>{...rawTags};
    if (badge.isNotEmpty) tags.add(badge);
    tags.add(category);
    if (shariahCompliant) tags.add('Islamic');
    if (category == 'Loans') {
      tags.add('Fast approval');
      tags.add('Low interest');
    }
    if (category == 'Insurance') tags.add('Family');
    if (category == 'Utilities') tags.add('Savings');
    if (category == 'Education') tags.add('Eligibility support');
    return tags.toList()..sort();
  }

  static double _fallbackRating(int priority) {
    final normalized = math.max(0, 5 - math.min(priority, 5));
    return (4.1 + (normalized * 0.12)).clamp(4.0, 4.8);
  }

  static double _fallbackTrustScore({
    required int priority,
    required bool verified,
    required double rating,
    required int reviewCount,
  }) {
    final score =
        70 +
        (verified ? 10 : 0) +
        ((rating - 4) * 10) +
        math.min(reviewCount / 40, 8) +
        math.max(0, 6 - priority);
    return score.clamp(72, 98).toDouble();
  }

  static List<String> _fallbackBenefits(String category) {
    switch (category) {
      case 'Loans':
        return const [
          'Shortlist options with simpler documentation',
          'See lenders aligned to first-time borrowers',
          'Estimate approval speed before applying',
        ];
      case 'Insurance':
        return const [
          'Protect family budgets from medical shocks',
          'Understand coverage and exclusions faster',
          'Compare trust and claims signals in one place',
        ];
      case 'Jobs':
        return const [
          'Improve monthly cash flow through verified opportunities',
          'Discover freelance and salaried pathways',
          'Focus on roles with stronger income potential',
        ];
      case 'Utilities':
        return const [
          'Lower recurring bills through installment-based upgrades',
          'Estimate savings impact before committing',
          'Prioritize budget-friendly household improvements',
        ];
      case 'Education':
        return const [
          'Identify scholarships and financing options quickly',
          'Reduce friction with eligibility guidance',
          'Move from interest to application with more confidence',
        ];
      default:
        return const [
          'Browse curated financial opportunities in one flow',
          'Evaluate trust, fit, and upside before leaving FinEase',
        ];
    }
  }

  static List<String> _fallbackEligibility(String category) {
    switch (category) {
      case 'Loans':
        return const [
          'CNIC holder',
          'Stable income signal preferred',
          'Best for first-time or small business borrowers',
        ];
      case 'Insurance':
        return const [
          'Family and individual plans available',
          'Basic identity documentation required',
        ];
      case 'Jobs':
        return const [
          'Suitable for salaried, freelance, and early-career users',
        ];
      case 'Utilities':
        return const ['Homeowner or tenant with service coverage area'];
      case 'Education':
        return const ['Students, graduates, or early-career professionals'];
      default:
        return const ['Eligibility varies by provider'];
    }
  }

  static List<String> _fallbackSafetySignals({
    required bool verified,
    required double rating,
  }) {
    return [
      if (verified) 'Verified by FinEase partner review',
      'Average user rating ${rating.toStringAsFixed(1)} or above',
      'Application handoff happens only after in-app review',
    ];
  }

  static List<String> _fallbackRiskIndicators(String category) {
    switch (category) {
      case 'Loans':
        return const [
          'Review repayment affordability before borrowing',
          'Check fees, markup, and late-payment penalties',
        ];
      case 'Insurance':
        return const ['Confirm waiting periods and exclusions'];
      case 'Jobs':
        return const ['Verify hiring terms before sharing sensitive documents'];
      default:
        return const ['Read full provider terms before proceeding'];
    }
  }

  static String _fallbackRateLabel(String category) {
    switch (category) {
      case 'Loans':
        return 'Rates from 12%-18% APR';
      case 'Insurance':
        return 'Family cover from PKR 2,500/mo';
      case 'Utilities':
        return 'Installments from PKR 8,000/mo';
      case 'Education':
        return 'Funding and scholarships available';
      case 'Jobs':
        return 'Income uplift opportunity';
      default:
        return 'Custom pricing available';
    }
  }

  static String _fallbackApprovalSpeed(String category) {
    switch (category) {
      case 'Loans':
        return 'Indicative decision in 24-72h';
      case 'Insurance':
        return 'Activation in 1-3 business days';
      case 'Jobs':
        return 'Shortlisting begins immediately';
      case 'Utilities':
        return 'Quote in 1-2 business days';
      case 'Education':
        return 'Eligibility review within 3-5 days';
      default:
        return 'Response time varies by partner';
    }
  }

  static String _fallbackEstimatedBenefit(String category) {
    switch (category) {
      case 'Loans':
        return 'Faster shortlist for eligible borrowers';
      case 'Insurance':
        return 'Reduce out-of-pocket health shocks';
      case 'Jobs':
        return 'Potential income growth and skill access';
      case 'Utilities':
        return 'Lower monthly utility spend';
      case 'Education':
        return 'Higher access to funding and upskilling';
      default:
        return 'Curated financial upside for your next step';
    }
  }
}

extension on List<String> {
  List<String> ifEmpty(List<String> fallback) {
    return isEmpty ? fallback : this;
  }
}
