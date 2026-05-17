import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../models/saving_goal.dart';
import '../../utils/currency_utils.dart';
import 'marketplace_models.dart';

class MarketplaceProvider extends ChangeNotifier {
  MarketplaceProvider({
    required List<MarketplacePartner> partners,
    required Map<String, dynamic> profile,
    required Map<String, dynamic> monthlySummary,
    required List<SavingGoal> goals,
    required Set<String> bookmarkedIds,
    required Set<String> watchlistIds,
    required List<String> recentlyViewedIds,
    required String category,
    required String query,
    required Set<String> selectedTags,
    required MarketplaceSort sort,
  }) : _partners = partners,
       _profile = profile,
       _monthlySummary = monthlySummary,
       _goals = goals,
       _bookmarkedIds = bookmarkedIds,
       _watchlistIds = watchlistIds,
       _recentlyViewedIds = recentlyViewedIds,
       _category = category,
       _query = query,
       _selectedTags = selectedTags,
       _sort = sort {
    _compute();
  }

  final List<MarketplacePartner> _partners;
  final Map<String, dynamic> _profile;
  final Map<String, dynamic> _monthlySummary;
  final List<SavingGoal> _goals;
  final Set<String> _bookmarkedIds;
  final Set<String> _watchlistIds;
  final List<String> _recentlyViewedIds;
  final String _category;
  final String _query;
  final Set<String> _selectedTags;
  final MarketplaceSort _sort;

  List<String> categories = const [];
  List<String> suggestedTags = const [];
  List<String> predictiveSuggestions = const [];
  List<String> trendingQueries = const [];
  List<MarketplacePartner> filtered = const [];
  List<MarketplacePartner> featured = const [];
  List<MarketplacePartner> recommended = const [];
  List<MarketplacePartner> salaryRange = const [];
  List<MarketplacePartner> lowestRisk = const [];
  List<MarketplacePartner> fastestApproval = const [];
  List<MarketplacePartner> trustedBySimilarUsers = const [];
  List<MarketplacePartner> aiGoalPicks = const [];
  List<MarketplacePartner> debtOptimization = const [];
  List<MarketplacePartner> wealthGrowth = const [];
  List<MarketplacePartner> incomeAcceleration = const [];
  List<MarketplacePartner> healthImprovement = const [];
  List<MarketplacePartner> trending = const [];
  List<MarketplacePartner> nearby = const [];
  List<MarketplacePartner> bookmarks = const [];
  List<MarketplacePartner> watchlist = const [];
  List<MarketplacePartner> recentlyViewed = const [];
  late MarketplaceIntelligence intelligence;

  int get verifiedCount =>
      _partners.where((partner) => partner.isVerified).length;

  double get averageTrustScore => _partners.isEmpty
      ? 0
      : _partners.fold<double>(0, (sum, partner) => sum + partner.trustScore) /
            _partners.length;

  String get recommendationReason {
    if (intelligence.savingsPotentialAnnual > 0) {
      return 'AI ranked these by profile fit, trust, approval confidence, and projected savings impact.';
    }
    return 'These partners are ranked using your income profile, active goals, and FinEase trust signals.';
  }

  bool get needsOnboarding =>
      (_profile['marketplaceIntent'] as String?) == null ||
      (_profile['marketplaceRiskProfile'] as String?) == null;

  void _compute() {
    categories = <String>{
      'All',
      ..._partners.map((partner) => partner.category),
    }.toList()..sort((a, b) => a == 'All' ? -1 : a.compareTo(b));

    final searched =
        _partners
            .where((partner) => partner.matchesCategory(_category))
            .where((partner) => partner.matchesTags(_selectedTags))
            .where((partner) => partner.matchesQuery(_query))
            .toList()
          ..sort((a, b) => _compare(a, b));

    filtered = searched;
    suggestedTags = MarketplacePartner.allSuggestedTags(
      searched.isEmpty ? _partners : searched,
    );
    trendingQueries = MarketplacePartner.trendingQueries(_partners);
    predictiveSuggestions = _buildPredictiveSuggestions();

    final scored = [..._partners]
      ..sort(
        (a, b) => b
            .relevanceScore(profile: _profile, goals: _goals)
            .compareTo(a.relevanceScore(profile: _profile, goals: _goals)),
      );
    final byTrust = [..._partners]
      ..sort((a, b) => b.trustScore.compareTo(a.trustScore));
    final byRisk = [..._partners]
      ..sort((a, b) => a.fraudRiskScore.compareTo(b.fraudRiskScore));
    final bySpeed = [..._partners]
      ..sort((a, b) => a.processingDays.compareTo(b.processingDays));

    featured = searched.where((partner) => partner.isFeatured).take(5).toList();
    recommended = scored.take(4).toList();
    salaryRange = _bestForSalaryRange(scored).take(4).toList();
    lowestRisk = byRisk.take(4).toList();
    fastestApproval = bySpeed.take(4).toList();
    trustedBySimilarUsers = byTrust.take(4).toList();
    aiGoalPicks = _bestForGoals(scored).take(4).toList();
    debtOptimization = _byCategories(['Loans']).take(4).toList();
    wealthGrowth = _byCategories(['Education', 'Utilities']).take(4).toList();
    incomeAcceleration = _byCategories(['Jobs', 'Education']).take(4).toList();
    healthImprovement = _byCategories(['Insurance']).take(4).toList();
    trending = searched.where((partner) => partner.isTrending).take(6).toList();
    nearby = searched.where((partner) => partner.hasLocation).take(6).toList();
    bookmarks = _partners
        .where((partner) => _bookmarkedIds.contains(partner.id))
        .toList();
    watchlist = _partners
        .where((partner) => _watchlistIds.contains(partner.id))
        .toList();
    recentlyViewed = _recentlyViewedIds
        .map((id) => _partners.where((partner) => partner.id == id).firstOrNull)
        .whereType<MarketplacePartner>()
        .toList();
    intelligence = _buildIntelligence(scored);
  }

  int _compare(MarketplacePartner a, MarketplacePartner b) {
    switch (_sort) {
      case MarketplaceSort.recommended:
        final semanticDelta = b
            .semanticMatchScore(_query)
            .compareTo(a.semanticMatchScore(_query));
        if (_query.trim().isNotEmpty && semanticDelta != 0) {
          return semanticDelta;
        }
        return b
            .relevanceScore(profile: _profile, goals: _goals)
            .compareTo(a.relevanceScore(profile: _profile, goals: _goals));
      case MarketplaceSort.trust:
        return b.trustScore.compareTo(a.trustScore);
      case MarketplaceSort.monthlyCost:
        return a.monthlyCost.compareTo(b.monthlyCost);
      case MarketplaceSort.approvalProbability:
        return b.approvalProbability.compareTo(a.approvalProbability);
      case MarketplaceSort.processingSpeed:
        return a.processingDays.compareTo(b.processingDays);
      case MarketplaceSort.popularity:
        return b.popularityScore.compareTo(a.popularityScore);
    }
  }

  List<MarketplacePartner> _bestForSalaryRange(
    List<MarketplacePartner> scored,
  ) {
    final income = (_profile['monthlyIncome'] as num?)?.toDouble() ?? 0;
    if (income <= 0) return scored;
    return scored.where((partner) {
      final minimum = partner.minimumIncome;
      if (minimum == null) return true;
      return income >= minimum && income <= minimum * 8;
    }).toList();
  }

  List<MarketplacePartner> _bestForGoals(List<MarketplacePartner> scored) {
    final goalText = _goals
        .map((goal) => '${goal.title} ${goal.category}'.toLowerCase())
        .join(' ');
    if (goalText.isEmpty) return scored;
    return scored.where((partner) {
      final haystack =
          '${partner.category} ${partner.tags.join(' ')} ${partner.benefits.join(' ')}'
              .toLowerCase();
      return goalText
              .split(' ')
              .any((token) => token.length > 3 && haystack.contains(token)) ||
          partner.relevanceScore(profile: _profile, goals: _goals) > 100;
    }).toList();
  }

  List<MarketplacePartner> _byCategories(List<String> categories) {
    return _partners
        .where((partner) => categories.contains(partner.category))
        .toList()
      ..sort(
        (a, b) => b
            .relevanceScore(profile: _profile, goals: _goals)
            .compareTo(a.relevanceScore(profile: _profile, goals: _goals)),
      );
  }

  List<String> _buildPredictiveSuggestions() {
    final intent = (_profile['marketplaceIntent'] as String? ?? '')
        .toLowerCase();
    final suggestions = <String>[
      if (intent.contains('debt')) 'lower my monthly repayment',
      if (intent.contains('save')) 'reduce recurring bills',
      if (intent.contains('income')) 'increase monthly income',
      if (_query.trim().isNotEmpty) 'best match for "${_query.trim()}"',
      ...trendingQueries,
    ];
    return suggestions.take(6).toList();
  }

  MarketplaceIntelligence _buildIntelligence(List<MarketplacePartner> scored) {
    final income =
        (_monthlySummary['monthlyIncome'] as num?)?.toDouble() ??
        (_profile['monthlyIncome'] as num?)?.toDouble() ??
        0;
    final expenses =
        (_monthlySummary['totalExpenses'] as num?)?.toDouble() ?? 0;
    final savingsRate = income <= 0
        ? 0.0
        : ((income - expenses) / income).clamp(0, 1).toDouble();
    final top = scored.isEmpty ? null : scored.first;
    final averageApproval = scored.isEmpty
        ? 0.0
        : scored
                  .take(4)
                  .fold<double>(
                    0,
                    (sum, partner) => sum + partner.approvalProbability,
                  ) /
              math.min(scored.length, 4);
    final savingsPotentialMonthly = math
        .max(0, (income * (savingsRate < 0.18 ? 0.08 : 0.04)).roundToDouble())
        .toDouble();
    final score =
        (averageTrustScore * 0.38 +
                averageApproval * 0.34 +
                (savingsRate * 100) * 0.18 +
                (verifiedCount / math.max(_partners.length, 1) * 100) * 0.10)
            .clamp(0, 100)
            .toDouble();
    final nextBestAction = top == null
        ? 'Answer a few questions to calibrate FinEase recommendations.'
        : 'Review ${top.name}: ${top.estimatedBenefit.toLowerCase()}.';
    return MarketplaceIntelligence(
      opportunityScore: score,
      savingsPotentialMonthly: savingsPotentialMonthly,
      approvalLikelihood: averageApproval,
      nextBestAction: nextBestAction,
      approvalDelta: top == null
          ? 0
          : (top.approvalProbability - 58).clamp(0, 28).toDouble(),
      matchPercent: top == null
          ? 0
          : (top.relevanceScore(profile: _profile, goals: _goals) / 2.4)
                .clamp(55, 96)
                .toDouble(),
      insight: top == null
          ? 'FinEase will personalize offers once your intent profile is ready.'
          : 'You may save ${CurrencyUtils.format(savingsPotentialMonthly * 12)} annually by comparing ${top.category.toLowerCase()} options before handoff.',
    );
  }
}

class MarketplaceIntelligence {
  const MarketplaceIntelligence({
    required this.opportunityScore,
    required this.savingsPotentialMonthly,
    required this.approvalLikelihood,
    required this.nextBestAction,
    required this.approvalDelta,
    required this.matchPercent,
    required this.insight,
  });

  final double opportunityScore;
  final double savingsPotentialMonthly;
  final double approvalLikelihood;
  final String nextBestAction;
  final double approvalDelta;
  final double matchPercent;
  final String insight;

  double get savingsPotentialAnnual => savingsPotentialMonthly * 12;
}

class ComparisonSummary {
  ComparisonSummary(this.partners);

  final List<MarketplacePartner> partners;

  MarketplacePartner? get safest {
    if (partners.isEmpty) return null;
    final sorted = [...partners]
      ..sort((a, b) => a.fraudRiskScore.compareTo(b.fraudRiskScore));
    return sorted.first;
  }

  MarketplacePartner? get bestApproval {
    if (partners.isEmpty) return null;
    final sorted = [...partners]
      ..sort((a, b) => b.approvalProbability.compareTo(a.approvalProbability));
    return sorted.first;
  }

  MarketplacePartner? get lowestCost {
    if (partners.isEmpty) return null;
    final sorted = [...partners]
      ..sort((a, b) => a.monthlyCost.compareTo(b.monthlyCost));
    return sorted.first;
  }

  String get smartSummary {
    if (partners.length < 2) {
      return 'Select at least two partners for FinEase to explain trade-offs.';
    }
    final approval = bestApproval;
    final cost = lowestCost;
    final risk = safest;
    return 'Best approval fit: ${approval?.name ?? 'n/a'}. Lowest cost: ${cost?.name ?? 'n/a'}. Lowest risk: ${risk?.name ?? 'n/a'}. Review hidden fee notes before applying.';
  }
}

extension FirstOrNullExtension<E> on Iterable<E> {
  E? get firstOrNull => isEmpty ? null : first;
}
