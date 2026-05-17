import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/saving_goal.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';
import '../../widgets/app_config_gate.dart';
import '../../models/marketplace_models.dart';
import 'partner_detail_screen.dart';
import 'widgets/search_filter_card.dart';
import 'widgets/insights_banner.dart';
import 'widgets/skeleton.dart';
import 'widgets/empty_state.dart';
import 'widgets/partner_product_card.dart';
import 'widgets/featured_partner_card.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  static const _searchDebounce = Duration(milliseconds: 450);

  final TextEditingController _searchController = TextEditingController();
  final Set<String> _selectedTags = <String>{};
  final Set<String> _comparedPartnerIds = <String>{};
  final Set<String> _impressionLoggedIds = <String>{};

  String _category = 'All';
  Timer? _searchTimer;

  @override
  void dispose() {
    _searchTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.watch<AuthService>().firestoreService;

    return AppFeatureGate(
      enabled: (config) => config.marketplaceEnabled,
      blockedTitle: 'Marketplace is paused',
      blockedMessage:
          'Partner marketplace access is temporarily paused by FinEase admin.',
      blockedIcon: Icons.storefront_outlined,
      child: Scaffold(
        backgroundColor: AppTheme.background,
        bottomNavigationBar: _CompareTray(
          count: _comparedPartnerIds.length,
          onCompare: firestoreService == null
              ? null
              : () => _openComparisonSheet(context, firestoreService),
          onClear: _comparedPartnerIds.isEmpty
              ? null
              : () => setState(_comparedPartnerIds.clear),
        ),
        body: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            SliverAppBar(
              expandedHeight: 235,
              pinned: true,
              backgroundColor: const Color(0xFF0F172A),
              flexibleSpace: FlexibleSpaceBar(
                background: DecoratedBox(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        Color(0xFF0F172A),
                        AppTheme.primary,
                        Color(0xFF0EA5A4),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 22, 20, 24),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            child: Text(
                              'FinEase marketplace intelligence',
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'Financial opportunities built for trust and action.',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 28,
                              height: 1.15,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Discover curated financing, insurance, education, and income partners. Compare the fit in-app before you continue anywhere else.',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.78),
                              height: 1.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: firestoreService == null
                  ? const SizedBox.shrink()
                  : StreamBuilder<List<Map<String, dynamic>>>(
                      stream: firestoreService.getMarketplacePartners(),
                      builder: (context, partnerSnapshot) {
                        if (partnerSnapshot.connectionState ==
                                ConnectionState.waiting &&
                            !partnerSnapshot.hasData) {
                          return const MarketplaceSkeleton();
                        }

                        final rawPartners = partnerSnapshot.data ?? const [];
                        final partners = rawPartners
                            .map(MarketplacePartner.fromMap)
                            .toList();

                        return StreamBuilder<Map<String, dynamic>>(
                          stream: firestoreService.getUserProfile(),
                          builder: (context, profileSnapshot) {
                            final profile =
                                profileSnapshot.data ??
                                const <String, dynamic>{};
                            return StreamBuilder<List<SavingGoal>>(
                              stream: firestoreService.getSavingGoals(),
                              builder: (context, goalsSnapshot) {
                                final goals =
                                    goalsSnapshot.data ?? const <SavingGoal>[];
                                final viewModel = _MarketplaceViewModel.build(
                                  partners: partners,
                                  profile: profile,
                                  goals: goals,
                                  category: _category,
                                  query: _searchController.text,
                                  selectedTags: _selectedTags,
                                );

                                _logVisibleImpressions(
                                  firestoreService: firestoreService,
                                  partners: viewModel.filtered,
                                );

                                return Padding(
                                  padding: const EdgeInsets.fromLTRB(
                                    16,
                                    16,
                                    16,
                                    140,
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      MarketplaceInsightsBanner(
                                        verifiedCount: viewModel.verifiedCount,
                                        averageTrustScore:
                                            viewModel.averageTrustScore,
                                        liveCount: viewModel.filtered.length,
                                      ),
                                      const SizedBox(height: 16),
                                      SearchAndFilterCard(
                                        queryController: _searchController,
                                        categories: viewModel.categories,
                                        selectedCategory: _category,
                                        selectedTags: _selectedTags,
                                        suggestedTags: viewModel.suggestedTags,
                                        onCategorySelected: (value) {
                                          setState(() => _category = value);
                                          firestoreService.logMarketplaceEvent(
                                            'marketplace_category_selected',
                                            payload: {'category': value},
                                          );
                                        },
                                        onTagToggle: (tag) {
                                          setState(() {
                                            if (_selectedTags.contains(tag)) {
                                              _selectedTags.remove(tag);
                                            } else {
                                              _selectedTags.add(tag);
                                            }
                                          });
                                          firestoreService.logMarketplaceEvent(
                                            'marketplace_tag_toggled',
                                            payload: {
                                              'tag': tag,
                                              'selected': _selectedTags
                                                  .contains(tag),
                                            },
                                          );
                                        },
                                        onQueryChanged: (value) {
                                          setState(() {});
                                          _searchTimer?.cancel();
                                          _searchTimer = Timer(
                                            _searchDebounce,
                                            () {
                                              firestoreService
                                                  .logMarketplaceEvent(
                                                    'marketplace_search',
                                                    payload: {
                                                      'query': value.trim(),
                                                    },
                                                  );
                                            },
                                          );
                                        },
                                        onClearFilters: () {
                                          setState(() {
                                            _category = 'All';
                                            _selectedTags.clear();
                                            _searchController.clear();
                                          });
                                          firestoreService.logMarketplaceEvent(
                                            'marketplace_filters_cleared',
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 24),
                                      if (viewModel.featured.isNotEmpty) ...[
                                        _SectionHeader(
                                          title: 'Featured opportunities',
                                          subtitle:
                                              'High-trust offers with the strongest upside signals.',
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          height: 248,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemCount:
                                                viewModel.featured.length,
                                            separatorBuilder: (_, index) =>
                                                const SizedBox(width: 14),
                                            itemBuilder: (context, index) {
                                              final partner =
                                                  viewModel.featured[index];
                                              return FeaturedPartnerCard(
                                                partner: partner,
                                                onTap: () => _openDetail(
                                                  context,
                                                  firestoreService,
                                                  partner,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                      ],
                                      if (viewModel.recommended.isNotEmpty) ...[
                                        _SectionHeader(
                                          title: 'Recommended for you',
                                          subtitle:
                                              viewModel.recommendationReason,
                                        ),
                                        const SizedBox(height: 12),
                                        ...viewModel.recommended.map(
                                          (partner) => Padding(
                                            padding: const EdgeInsets.only(
                                              bottom: 14,
                                            ),
                                            child: PartnerProductCard(
                                              partner: partner,
                                              isCompared: _comparedPartnerIds
                                                  .contains(partner.id),
                                              onTap: () => _openDetail(
                                                context,
                                                firestoreService,
                                                partner,
                                              ),
                                              onCompareToggle: () =>
                                                  _toggleCompare(
                                                    firestoreService,
                                                    partner,
                                                  ),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(height: 10),
                                      ],
                                      if (viewModel.trending.isNotEmpty) ...[
                                        _SectionHeader(
                                          title: 'Trending partners',
                                          subtitle:
                                              'Popular options users are reviewing most often.',
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          height: 170,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemCount:
                                                viewModel.trending.length,
                                            separatorBuilder: (_, index) =>
                                                const SizedBox(width: 12),
                                            itemBuilder: (context, index) {
                                              final partner =
                                                  viewModel.trending[index];
                                              return _CompactOpportunityCard(
                                                partner: partner,
                                                onTap: () => _openDetail(
                                                  context,
                                                  firestoreService,
                                                  partner,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                      ],
                                      if (viewModel.nearby.isNotEmpty) ...[
                                        _SectionHeader(
                                          title:
                                              'Nearby and location-based offers',
                                          subtitle:
                                              'Partners with branch or service coordinates available.',
                                        ),
                                        const SizedBox(height: 12),
                                        SizedBox(
                                          height: 180,
                                          child: ListView.separated(
                                            scrollDirection: Axis.horizontal,
                                            itemCount: viewModel.nearby.length,
                                            separatorBuilder: (_, index) =>
                                                const SizedBox(width: 12),
                                            itemBuilder: (context, index) {
                                              final partner =
                                                  viewModel.nearby[index];
                                              return _LocationOfferCard(
                                                partner: partner,
                                                onTap: () => _openDetail(
                                                  context,
                                                  firestoreService,
                                                  partner,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(height: 24),
                                      ],
                                      _SectionHeader(
                                        title: 'All opportunities',
                                        subtitle:
                                            '${viewModel.filtered.length} results across search, category, and trust filters.',
                                      ),
                                      const SizedBox(height: 12),
                                      AnimatedSwitcher(
                                        duration: const Duration(
                                          milliseconds: 250,
                                        ),
                                        child: viewModel.filtered.isEmpty
                                            ? const MarketplaceEmptyState()
                                            : Column(
                                                key: ValueKey(
                                                  '${viewModel.filtered.length}-$_category-${_selectedTags.length}-${_searchController.text}',
                                                ),
                                                children: viewModel.filtered
                                                    .map(
                                                      (partner) => Padding(
                                                        padding:
                                                            const EdgeInsets.only(
                                                              bottom: 14,
                                                            ),
                                                        child: PartnerProductCard(
                                                          partner: partner,
                                                          isCompared:
                                                              _comparedPartnerIds
                                                                  .contains(
                                                                    partner.id,
                                                                  ),
                                                          onTap: () =>
                                                              _openDetail(
                                                                context,
                                                                firestoreService,
                                                                partner,
                                                              ),
                                                          onCompareToggle: () =>
                                                              _toggleCompare(
                                                                firestoreService,
                                                                partner,
                                                              ),
                                                        ),
                                                      ),
                                                    )
                                                    .toList(),
                                              ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            );
                          },
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _openDetail(
    BuildContext context,
    FirestoreService firestoreService,
    MarketplacePartner partner,
  ) {
    firestoreService.logMarketplaceEvent(
      'partner_detail_opened',
      payload: {'partnerId': partner.id, 'category': partner.category},
    );
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PartnerDetailScreen(
          partner: partner,
          firestoreService: firestoreService,
          isCompared: _comparedPartnerIds.contains(partner.id),
          onToggleCompare: (value) => _toggleCompare(firestoreService, value),
        ),
      ),
    );
  }

  void _toggleCompare(
    FirestoreService firestoreService,
    MarketplacePartner partner,
  ) {
    final alreadySelected = _comparedPartnerIds.contains(partner.id);
    if (!alreadySelected && _comparedPartnerIds.length >= 3) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('You can compare up to 3 partners at once.'),
        ),
      );
      return;
    }

    setState(() {
      if (alreadySelected) {
        _comparedPartnerIds.remove(partner.id);
      } else {
        _comparedPartnerIds.add(partner.id);
      }
    });

    firestoreService.logMarketplaceEvent(
      alreadySelected ? 'compare_remove' : 'compare_add',
      payload: {'partnerId': partner.id, 'category': partner.category},
    );
  }

  void _logVisibleImpressions({
    required FirestoreService firestoreService,
    required List<MarketplacePartner> partners,
  }) {
    final toLog = partners
        .take(6)
        .where((partner) => !_impressionLoggedIds.contains(partner.id))
        .toList();
    if (toLog.isEmpty) return;
    _impressionLoggedIds.addAll(toLog.map((partner) => partner.id));
    WidgetsBinding.instance.addPostFrameCallback((_) {
      for (final partner in toLog) {
        firestoreService.logMarketplaceEvent(
          'partner_impression',
          payload: {'partnerId': partner.id, 'category': partner.category},
        );
      }
    });
  }

  void _openComparisonSheet(
    BuildContext context,
    FirestoreService firestoreService,
  ) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return StreamBuilder<List<Map<String, dynamic>>>(
          stream: firestoreService.getMarketplacePartners(),
          builder: (context, snapshot) {
            final partners = (snapshot.data ?? const [])
                .map(MarketplacePartner.fromMap)
                .where((partner) => _comparedPartnerIds.contains(partner.id))
                .toList();

            return _ComparisonSheet(
              partners: partners,
              onRemove: (partner) => _toggleCompare(firestoreService, partner),
            );
          },
        );
      },
    );
    firestoreService.logMarketplaceEvent(
      'comparison_opened',
      payload: {'count': _comparedPartnerIds.length},
    );
  }
}

class _MarketplaceViewModel {
  _MarketplaceViewModel({
    required this.categories,
    required this.suggestedTags,
    required this.filtered,
    required this.featured,
    required this.recommended,
    required this.trending,
    required this.nearby,
    required this.recommendationReason,
    required this.averageTrustScore,
    required this.verifiedCount,
  });

  factory _MarketplaceViewModel.build({
    required List<MarketplacePartner> partners,
    required Map<String, dynamic> profile,
    required List<SavingGoal> goals,
    required String category,
    required String query,
    required Set<String> selectedTags,
  }) {
    final categories = <String>{
      'All',
      ...partners.map((partner) => partner.category),
    }.toList()..sort((a, b) => a == 'All' ? -1 : a.compareTo(b));

    final filtered =
        partners
            .where((partner) => partner.matchesCategory(category))
            .where((partner) => partner.matchesQuery(query))
            .where((partner) => partner.matchesTags(selectedTags))
            .toList()
          ..sort((a, b) => a.priority.compareTo(b.priority));

    final featured = filtered
        .where((partner) => partner.isFeatured)
        .take(5)
        .toList();
    final trending = filtered
        .where((partner) => partner.isTrending)
        .take(6)
        .toList();
    final nearby = filtered
        .where((partner) => partner.hasLocation)
        .take(6)
        .toList();

    final recommended = [...filtered]
      ..sort(
        (a, b) => b
            .relevanceScore(profile: profile, goals: goals)
            .compareTo(a.relevanceScore(profile: profile, goals: goals)),
      );

    final avgTrust = partners.isEmpty
        ? 0.0
        : partners.fold<double>(0, (sum, partner) => sum + partner.trustScore) /
              partners.length;
    final verifiedCount = partners
        .where((partner) => partner.isVerified)
        .length;

    return _MarketplaceViewModel(
      categories: categories,
      suggestedTags: MarketplacePartner.allSuggestedTags(
        filtered.isEmpty ? partners : filtered,
      ),
      filtered: filtered,
      featured: featured,
      recommended: recommended.take(3).toList(),
      trending: trending,
      nearby: nearby,
      recommendationReason: _buildRecommendationReason(profile, goals),
      averageTrustScore: avgTrust,
      verifiedCount: verifiedCount,
    );
  }

  final List<String> categories;
  final List<String> suggestedTags;
  final List<MarketplacePartner> filtered;
  final List<MarketplacePartner> featured;
  final List<MarketplacePartner> recommended;
  final List<MarketplacePartner> trending;
  final List<MarketplacePartner> nearby;
  final String recommendationReason;
  final double averageTrustScore;
  final int verifiedCount;

  static String _buildRecommendationReason(
    Map<String, dynamic> profile,
    List<SavingGoal> goals,
  ) {
    final income = (profile['monthlyIncome'] as num?)?.toDouble() ?? 0;
    final goalCategories = goals
        .map((goal) => goal.category.toLowerCase())
        .toSet();

    if (goalCategories.contains('emergency')) {
      return 'Based on your emergency savings focus, FinEase is prioritizing resilience, protection, and faster-access options.';
    }
    if (income > 0 && income < 250000) {
      return 'Your current income profile suggests options with clearer approval paths, practical rates, and simpler onboarding.';
    }
    if (goalCategories.contains('travel') ||
        goalCategories.contains('education')) {
      return 'Your active goals point toward funding and growth opportunities that can improve flexibility over the next few months.';
    }
    return 'These partners are ranked using your current profile, active goals, and FinEase trust signals.';
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: GoogleFonts.inter(color: AppTheme.textSecondary, height: 1.45),
        ),
      ],
    );
  }
}

class _CompactOpportunityCard extends StatelessWidget {
  const _CompactOpportunityCard({required this.partner, required this.onTap});

  final MarketplacePartner partner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 220,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.border),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              partner.name,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              partner.estimatedBenefit,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.45,
              ),
            ),
            const Spacer(),
            Row(
              children: [
                const Icon(
                  Icons.local_fire_department_rounded,
                  color: Color(0xFFD97706),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '${partner.reviewCount}+ reviews',
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LocationOfferCard extends StatelessWidget {
  const _LocationOfferCard({required this.partner, required this.onTap});

  final MarketplacePartner partner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Container(
        width: 250,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: const Color(0xFF0F172A),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.location_on_rounded, color: Colors.white),
            const SizedBox(height: 12),
            Text(
              partner.name,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              partner.locationLabel ??
                  'Coordinates available for branch or service area',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.72),
                height: 1.45,
              ),
            ),
            const Spacer(),
            Text(
              partner.approvalSpeed,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CompareTray extends StatelessWidget {
  const _CompareTray({
    required this.count,
    required this.onCompare,
    required this.onClear,
  });

  final int count;
  final VoidCallback? onCompare;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      height: count == 0 ? 0 : 96,
      child: count == 0
          ? const SizedBox.shrink()
          : SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFF0F172A),
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: AppTheme.cardShadow,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '$count partner${count == 1 ? '' : 's'} ready to compare',
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: onClear,
                        child: const Text('Clear'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: count >= 2 ? onCompare : null,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.white,
                          foregroundColor: const Color(0xFF0F172A),
                        ),
                        child: const Text('Compare'),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }
}

class _ComparisonSheet extends StatelessWidget {
  const _ComparisonSheet({required this.partners, required this.onRemove});

  final List<MarketplacePartner> partners;
  final ValueChanged<MarketplacePartner> onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.78,
      decoration: const BoxDecoration(
        color: AppTheme.background,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            width: 48,
            height: 5,
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    'Compare partners',
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                Text(
                  '${partners.length}/3 selected',
                  style: GoogleFonts.inter(color: AppTheme.textSecondary),
                ),
              ],
            ),
          ),
          Expanded(
            child: partners.length < 2
                ? Center(
                    child: Text(
                      'Select at least two partners to compare key details side by side.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(color: AppTheme.textSecondary),
                    ),
                  )
                : SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    scrollDirection: Axis.horizontal,
                    child: DataTable(
                      headingTextStyle: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                      dataTextStyle: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                      columns: [
                        const DataColumn(label: Text('Attribute')),
                        ...partners.map(
                          (partner) => DataColumn(
                            label: SizedBox(
                              width: 150,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(partner.name),
                                  TextButton(
                                    onPressed: () => onRemove(partner),
                                    child: const Text('Remove'),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                      rows: [
                        _comparisonRow(
                          'Category',
                          partners,
                          (partner) => partner.category,
                        ),
                        _comparisonRow(
                          'Rates',
                          partners,
                          (partner) => partner.rateLabel,
                        ),
                        _comparisonRow(
                          'Approval speed',
                          partners,
                          (partner) => partner.approvalSpeed,
                        ),
                        _comparisonRow(
                          'Trust score',
                          partners,
                          (partner) =>
                              '${partner.trustScore.toStringAsFixed(0)}/100',
                        ),
                        _comparisonRow(
                          'User rating',
                          partners,
                          (partner) =>
                              '${partner.rating.toStringAsFixed(1)} / 5',
                        ),
                        _comparisonRow(
                          'Minimum income',
                          partners,
                          (partner) => partner.minimumIncome == null
                              ? 'Not specified'
                              : CurrencyUtils.format(partner.minimumIncome!),
                        ),
                        _comparisonRow(
                          'Estimated benefit',
                          partners,
                          (partner) => partner.estimatedBenefit,
                        ),
                        _comparisonRow(
                          'Eligibility',
                          partners,
                          (partner) => partner.eligibility.first,
                        ),
                        _comparisonRow(
                          'Risk signal',
                          partners,
                          (partner) => partner.riskIndicators.first,
                        ),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  DataRow _comparisonRow(
    String label,
    List<MarketplacePartner> partners,
    String Function(MarketplacePartner partner) valueBuilder,
  ) {
    return DataRow(
      cells: [
        DataCell(Text(label)),
        ...partners.map(
          (partner) => DataCell(
            SizedBox(width: 150, child: Text(valueBuilder(partner))),
          ),
        ),
      ],
    );
  }
}
