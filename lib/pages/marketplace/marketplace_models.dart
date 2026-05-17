import 'dart:math' as math;

import '../../models/saving_goal.dart';

enum MarketplaceSort {
  recommended,
  trust,
  monthlyCost,
  approvalProbability,
  processingSpeed,
  popularity,
}

extension MarketplaceSortLabel on MarketplaceSort {
  String get label {
    switch (this) {
      case MarketplaceSort.recommended:
        return 'Recommended';
      case MarketplaceSort.trust:
        return 'Trust score';
      case MarketplaceSort.monthlyCost:
        return 'Monthly cost';
      case MarketplaceSort.approvalProbability:
        return 'Approval odds';
      case MarketplaceSort.processingSpeed:
        return 'Fastest';
      case MarketplaceSort.popularity:
        return 'Popularity';
    }
  }
}

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
    required this.monthlyCost,
    required this.approvalProbability,
    required this.processingDays,
    required this.popularityScore,
    required this.fraudRiskScore,
    required this.complianceBadges,
    required this.reviewSentiment,
    required this.branchVerified,
    required this.serviceRegion,
    required this.idealCustomerType,
    required this.hiddenFeeNotes,
    required this.rateChangeDays,
    required this.comparedToday,
    required this.shariahCompliant,
    required this.locationLabel,
  });

  factory MarketplacePartner.fromMap(Map<String, dynamic> data) {
    final badge = (data['badge'] as String? ?? '').trim();
    final category = (data['category'] as String? ?? 'General').trim();
    final tags = _stringList(data['tags']);
    final approved = data['approved'] as bool? ?? true;
    final priority = (data['priority'] as num?)?.toInt() ?? 99;
    final explicitVerified = data['verified'] as bool?;
    final shariah = data['shariahCompliant'] as bool? ?? false;
    final verified =
        explicitVerified ??
        approved ||
            badge.toLowerCase().contains('verified') ||
            tags.any((tag) => tag.toLowerCase() == 'verified');
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
    final processingDays =
        (data['processingDays'] as num?)?.toInt() ??
        _fallbackProcessingDays(category);
    final monthlyCost =
        (data['monthlyCost'] as num?)?.toDouble() ??
        _fallbackMonthlyCost(category);
    final fraudRiskScore =
        (data['fraudRiskScore'] as num?)?.toDouble() ??
        _fallbackFraudRisk(verified: verified, trustScore: trustScore);

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
      trustScore: trustScore.clamp(0, 100).toDouble(),
      isVerified: verified,
      isFeatured: data['featured'] as bool? ?? priority <= 2,
      isTrending:
          data['trending'] as bool? ??
          badge.toLowerCase().contains('popular') ||
              badge.toLowerCase().contains('new'),
      tags: _mergeTags(
        category: category,
        badge: badge,
        rawTags: tags,
        shariahCompliant: shariah,
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
      monthlyCost: monthlyCost,
      approvalProbability:
          ((data['approvalProbability'] as num?)?.toDouble() ??
                  _fallbackApprovalProbability(
                    category: category,
                    trustScore: trustScore,
                    processingDays: processingDays,
                  ))
              .clamp(0, 100)
              .toDouble(),
      processingDays: processingDays,
      popularityScore:
          ((data['popularityScore'] as num?)?.toDouble() ??
                  math.min(
                    100,
                    reviewCount / 4 + (data['trending'] == true ? 18 : 0),
                  ))
              .clamp(0, 100)
              .toDouble(),
      fraudRiskScore: fraudRiskScore.clamp(0, 100).toDouble(),
      complianceBadges: _stringList(data['complianceBadges']).ifEmpty(
        verified
            ? const ['KYC reviewed', 'Terms visible']
            : const ['Terms visible'],
      ),
      reviewSentiment:
          data['reviewSentiment'] as String? ??
          _fallbackReviewSentiment(rating),
      branchVerified: data['branchVerified'] as bool? ?? verified,
      serviceRegion: data['serviceRegion'] as String? ?? 'Pakistan',
      idealCustomerType:
          data['idealCustomerType'] as String? ?? _fallbackIdealUser(category),
      hiddenFeeNotes:
          data['hiddenFeeNotes'] as String? ?? _fallbackHiddenFees(category),
      rateChangeDays:
          (data['rateChangeDays'] as num?)?.toInt() ?? (priority <= 2 ? 2 : 5),
      comparedToday:
          (data['comparedToday'] as num?)?.toInt() ??
          math.max(8, reviewCount ~/ 18),
      shariahCompliant: shariah,
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
  final double monthlyCost;
  final double approvalProbability;
  final int processingDays;
  final double popularityScore;
  final double fraudRiskScore;
  final List<String> complianceBadges;
  final String reviewSentiment;
  final bool branchVerified;
  final String serviceRegion;
  final String idealCustomerType;
  final String hiddenFeeNotes;
  final int rateChangeDays;
  final int comparedToday;
  final bool shariahCompliant;
  final String? locationLabel;

  bool get hasLocation => latitude != null && longitude != null;

  String get aiSummary {
    final risk = fraudRiskScore <= 20
        ? 'low observed fraud risk'
        : fraudRiskScore <= 45
        ? 'moderate verification risk'
        : 'higher review risk';
    return '$name is best for $idealCustomerType. Expect $approvalSpeed with ${approvalProbability.toStringAsFixed(0)}% indicative approval confidence. Key risk: ${riskIndicators.first}. Hidden fee note: $hiddenFeeNotes. Current trust layer shows ${trustScore.toStringAsFixed(0)}/100 trust and $risk.';
  }

  String get urgencySignal =>
      'Rate may change in $rateChangeDays days - $comparedToday users compared this today';

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

  bool matchesQuery(String query) {
    return semanticMatchScore(query) > 0;
  }

  int semanticMatchScore(String query) {
    final normalized = query.trim().toLowerCase();
    if (normalized.isEmpty) return 1;
    final tokens = _expandQuery(normalized);
    final haystack = <String>[
      name,
      description,
      category,
      badge,
      rateLabel,
      approvalSpeed,
      estimatedBenefit,
      idealCustomerType,
      hiddenFeeNotes,
      reviewSentiment,
      ...tags,
      ...benefits,
      ...eligibility,
      ...riskIndicators,
      ...complianceBadges,
    ].join(' ').toLowerCase();
    var score = 0;
    for (final token in tokens) {
      if (haystack.contains(token)) {
        score += token.length > 4 ? 3 : 2;
      } else if (_hasNearToken(haystack, token)) {
        score += 1;
      }
    }
    return score;
  }

  int relevanceScore({
    required Map<String, dynamic> profile,
    required List<SavingGoal> goals,
  }) {
    final income = (profile['monthlyIncome'] as num?)?.toDouble() ?? 0;
    final fullName = (profile['fullName'] as String? ?? '').toLowerCase();
    final riskProfile = (profile['marketplaceRiskProfile'] as String? ?? '')
        .toLowerCase();
    final goalNames = goals
        .map((goal) => '${goal.title} ${goal.category}'.toLowerCase())
        .join(' ');

    var score = trustScore.round() + approvalProbability.round();
    if (category == 'Loans' && income > 0 && income < 300000) score += 22;
    if (category == 'Insurance' && goalNames.contains('emergency')) score += 24;
    if (category == 'Education' &&
        (goalNames.contains('student') || fullName.contains('student'))) {
      score += 18;
    }
    if (category == 'Utilities' && income > 0) score += 15;
    if (category == 'Jobs' && goalNames.contains('income')) score += 18;
    if (riskProfile.contains('low') && fraudRiskScore < 25) score += 16;
    if (shariahCompliant) score += 8;
    if (isVerified) score += 8;
    if (isFeatured) score += 6;
    return score;
  }

  static List<String> allSuggestedTags(Iterable<MarketplacePartner> partners) {
    final values = <String>{
      'Islamic',
      'Low interest',
      'Fast approval',
      'Verified',
      'Lowest risk',
      'Salary fit',
      'Debt help',
      'Wealth growth',
      'Income growth',
    };
    for (final partner in partners) {
      values.addAll(partner.tags);
    }
    final sorted = values.toList()..sort();
    return sorted;
  }

  static List<String> trendingQueries(Iterable<MarketplacePartner> partners) {
    final categories = partners.map((partner) => partner.category).toSet();
    return [
      if (categories.contains('Loans')) 'fast loan with low markup',
      if (categories.contains('Insurance')) 'family health cover',
      if (categories.contains('Utilities')) 'lower electricity bill',
      if (categories.contains('Jobs')) 'increase monthly income',
      if (categories.contains('Education')) 'student scholarship',
      'verified low risk options',
    ];
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
      tags.add('Debt help');
    }
    if (category == 'Insurance') tags.add('Family');
    if (category == 'Utilities') tags.add('Savings');
    if (category == 'Education') tags.add('Eligibility support');
    if (category == 'Jobs') tags.add('Income growth');
    return tags.toList()..sort();
  }

  static Set<String> _expandQuery(String query) {
    final words = query
        .split(RegExp(r'[^a-z0-9]+'))
        .where((word) => word.isNotEmpty)
        .toSet();
    final expanded = <String>{...words};
    const synonyms = {
      'cheap': ['low', 'affordable', 'cost'],
      'quick': ['fast', 'approval', 'instant'],
      'urgent': ['fast', 'today', 'approval'],
      'halal': ['islamic', 'shariah'],
      'medical': ['health', 'insurance'],
      'job': ['income', 'career', 'roles'],
      'save': ['savings', 'lower', 'reduce'],
      'bill': ['utilities', 'electricity'],
      'student': ['education', 'scholarship'],
    };
    for (final word in words) {
      expanded.addAll(synonyms[word] ?? const []);
    }
    return expanded;
  }

  static bool _hasNearToken(String haystack, String token) {
    if (token.length < 4) return false;
    final words = haystack.split(RegExp(r'[^a-z0-9]+'));
    return words.any((word) => _levenshtein(word, token) <= 1);
  }

  static int _levenshtein(String a, String b) {
    if ((a.length - b.length).abs() > 1) return 3;
    final dp = List.generate(
      a.length + 1,
      (_) => List<int>.filled(b.length + 1, 0),
    );
    for (var i = 0; i <= a.length; i++) {
      dp[i][0] = i;
    }
    for (var j = 0; j <= b.length; j++) {
      dp[0][j] = j;
    }
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = math.min(
          math.min(dp[i - 1][j] + 1, dp[i][j - 1] + 1),
          dp[i - 1][j - 1] + cost,
        );
      }
    }
    return dp[a.length][b.length];
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

  static int _fallbackProcessingDays(String category) {
    switch (category) {
      case 'Loans':
        return 3;
      case 'Jobs':
        return 1;
      case 'Utilities':
        return 2;
      case 'Insurance':
        return 3;
      default:
        return 5;
    }
  }

  static double _fallbackMonthlyCost(String category) {
    switch (category) {
      case 'Loans':
        return 18000;
      case 'Insurance':
        return 2500;
      case 'Utilities':
        return 8000;
      default:
        return 0;
    }
  }

  static double _fallbackApprovalProbability({
    required String category,
    required double trustScore,
    required int processingDays,
  }) {
    final categoryLift = category == 'Jobs' || category == 'Education' ? 8 : 0;
    return (58 + (trustScore - 70) * 0.6 + categoryLift - processingDays)
        .clamp(45, 92)
        .toDouble();
  }

  static double _fallbackFraudRisk({
    required bool verified,
    required double trustScore,
  }) {
    return (42 - (verified ? 14 : 0) - ((trustScore - 70) * 0.4))
        .clamp(5, 65)
        .toDouble();
  }

  static List<String> _fallbackBenefits(String category) {
    switch (category) {
      case 'Loans':
        return const [
          'Shortlist options with simpler documentation',
          'Estimate approval speed before applying',
        ];
      case 'Insurance':
        return const [
          'Protect family budgets from medical shocks',
          'Compare trust and claims signals in one place',
        ];
      case 'Jobs':
        return const [
          'Improve monthly cash flow through verified opportunities',
          'Focus on roles with stronger income potential',
        ];
      case 'Utilities':
        return const [
          'Lower recurring bills through installment-based upgrades',
          'Estimate savings impact before committing',
        ];
      case 'Education':
        return const [
          'Identify scholarships and financing options quickly',
          'Reduce friction with eligibility guidance',
        ];
      default:
        return const ['Evaluate trust, fit, and upside before leaving FinEase'];
    }
  }

  static List<String> _fallbackEligibility(String category) {
    switch (category) {
      case 'Loans':
        return const ['CNIC holder', 'Stable income signal preferred'];
      case 'Insurance':
        return const ['Family and individual plans available'];
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

  static String _fallbackReviewSentiment(double rating) {
    if (rating >= 4.6) return 'Very positive: clarity and speed score highly';
    if (rating >= 4.3) return 'Positive: users value trust and guidance';
    return 'Mixed-positive: review terms carefully before applying';
  }

  static String _fallbackIdealUser(String category) {
    switch (category) {
      case 'Loans':
        return 'borrowers with stable income and short-term capital needs';
      case 'Insurance':
        return 'families protecting monthly budgets from health shocks';
      case 'Jobs':
        return 'users trying to increase monthly cash flow';
      case 'Utilities':
        return 'households reducing recurring electricity costs';
      case 'Education':
        return 'students and early professionals seeking funding';
      default:
        return 'users comparing trusted financial opportunities';
    }
  }

  static String _fallbackHiddenFees(String category) {
    switch (category) {
      case 'Loans':
        return 'Ask about processing fees, late fees, and early settlement rules.';
      case 'Insurance':
        return 'Check exclusions, waiting periods, and co-pay conditions.';
      case 'Utilities':
        return 'Confirm installation, warranty, and service visit costs.';
      default:
        return 'Review provider terms before sharing documents or payment.';
    }
  }
}

extension on List<String> {
  List<String> ifEmpty(List<String> fallback) => isEmpty ? fallback : this;
}
