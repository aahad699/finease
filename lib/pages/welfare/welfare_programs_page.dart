import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/welfare_program.dart';
import '../../services/auth_service.dart';
import '../../services/url_launcher_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_config_gate.dart';
import 'welfare_program_detail_page.dart';
import 'welfare_provider.dart';

class WelfareProgramsPage extends StatelessWidget {
  const WelfareProgramsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.read<AuthService>();
    return ChangeNotifierProvider(
      create: (_) => WelfareProvider(
        uid: auth.user?.uid,
        firestoreService: auth.firestoreService,
      ),
      child: AppFeatureGate(
        enabled: (config) => config.welfareEnabled,
        blockedTitle: 'Welfare programs are paused',
        blockedMessage:
            'The welfare directory is temporarily paused by FinEase admin.',
        blockedIcon: Icons.volunteer_activism_outlined,
        child: const _WelfarePageContent(),
      ),
    );
  }
}

class _WelfarePageContent extends StatefulWidget {
  const _WelfarePageContent();
  @override
  State<_WelfarePageContent> createState() => _WelfarePageContentState();
}

class _WelfarePageContentState extends State<_WelfarePageContent> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WelfareProvider>();

    return Scaffold(
      backgroundColor: AppTheme.backgroundFor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundFor(context),
        elevation: 0,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new_rounded,
            color: Colors.black,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Financial Assistance',
          style: GoogleFonts.plusJakartaSans(fontWeight: FontWeight.w800),
        ),
        actions: [
          _BookmarkBadge(count: provider.bookmarkCount),
          const SizedBox(width: 8),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        color: AppTheme.primary,
        child: provider.isLoading
            ? const _LoadingSkeleton()
            : provider.error != null
            ? _ErrorState(message: provider.error!, onRetry: provider.refresh)
            : _ProgramList(searchController: _searchController),
      ),
    );
  }
}

// ── Bookmark badge ──────────────────────────────────────────────────────────

class _BookmarkBadge extends StatelessWidget {
  const _BookmarkBadge({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(Icons.bookmark_outline_rounded, color: Colors.black87),
        if (count > 0)
          Positioned(
            top: -4,
            right: -4,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppTheme.primary,
                shape: BoxShape.circle,
              ),
              alignment: Alignment.center,
              child: Text(
                '$count',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ── Main list ───────────────────────────────────────────────────────────────

class _ProgramList extends StatelessWidget {
  const _ProgramList({required this.searchController});
  final TextEditingController searchController;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WelfareProvider>();
    final filtered = provider.filteredPrograms;
    final recommended = provider.recommendedPrograms;
    final hasFilters = provider.hasActiveFilters;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 40),
      children: [
        const SizedBox(height: 6),
        _HeroHeader(),
        const SizedBox(height: 20),
        _SearchBar(controller: searchController),
        const SizedBox(height: 14),
        _CategoryChips(),
        const SizedBox(height: 10),
        _TagChips(),
        if (hasFilters)
          _ActiveFilterBanner(provider: provider, controller: searchController),
        const SizedBox(height: 20),

        // Recommended section — only shown when no filter active
        if (!hasFilters && recommended.isNotEmpty) ...[
          _SectionHeader(
            title: 'Recommended for You',
            subtitle: 'Based on your profile and eligibility',
            icon: Icons.auto_awesome_rounded,
          ),
          const SizedBox(height: 12),
          ...recommended.map(
            (p) => _ProgramCard(program: p, isHighlighted: true),
          ),
          const SizedBox(height: 8),
          Divider(color: AppTheme.borderFor(context)),
          const SizedBox(height: 12),
          _SectionHeader(
            title: 'All Programs',
            subtitle: '${filtered.length} programs found',
            icon: Icons.list_alt_rounded,
          ),
          const SizedBox(height: 12),
        ],

        if (filtered.isEmpty)
          _EmptyState(onClear: provider.clearFilters)
        else ...[
          ...filtered.map((p) => _ProgramCard(program: p)),
        ],

        const SizedBox(height: 20),
        _ImpactBanner(count: filtered.length),
      ],
    );
  }
}

// ── Hero header ─────────────────────────────────────────────────────────────

class _HeroHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Verified support\nprograms',
          style: GoogleFonts.plusJakartaSans(
            fontSize: 26,
            fontWeight: FontWeight.w800,
            color: AppTheme.primary,
            height: 1.15,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Discover real welfare, scholarship, health and loan programs in Pakistan.',
          style: GoogleFonts.inter(color: AppTheme.textSecondaryFor(context), height: 1.5),
        ),
      ],
    );
  }
}

// ── Search bar ──────────────────────────────────────────────────────────────

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.controller});
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final provider = context.read<WelfareProvider>();
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return TextField(
          controller: controller,
          onChanged: provider.setSearch,
          decoration: InputDecoration(
            hintText: 'Search by title, organization, tags or keywords…',
            prefixIcon: Icon(Icons.search_rounded),
            suffixIcon: value.text.isNotEmpty
                ? IconButton(
                    icon: Icon(Icons.close_rounded),
                    onPressed: () {
                      controller.clear();
                      provider.setSearch('');
                    },
                  )
                : null,
          ),
        );
      },
    );
  }
}

// ── Category chips ──────────────────────────────────────────────────────────

class _CategoryChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WelfareProvider>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _Chip(
            label: 'All',
            selected: provider.selectedCategory == null,
            onTap: () => provider.setCategory(null),
          ),
          ...WelfareCategory.values.map(
            (cat) => _Chip(
              label: cat.displayName,
              selected: provider.selectedCategory == cat,
              onTap: () => provider.setCategory(cat),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Tag chips ───────────────────────────────────────────────────────────────

class _TagChips extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WelfareProvider>();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: kWelfareTags
            .map(
              (tag) => Padding(
                padding: const EdgeInsets.only(right: 6),
                child: GestureDetector(
                  onTap: () => provider.toggleTag(tag),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 7,
                    ),
                    decoration: BoxDecoration(
                      color: provider.selectedTags.contains(tag)
                          ? AppTheme.primary.withValues(alpha: 0.12)
                          : AppTheme.surfaceFor(context),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: provider.selectedTags.contains(tag)
                            ? AppTheme.primary
                            : AppTheme.borderFor(context),
                      ),
                    ),
                    child: Text(
                      '#$tag',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: provider.selectedTags.contains(tag)
                            ? AppTheme.primary
                            : AppTheme.textSecondaryFor(context),
                      ),
                    ),
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

// ── Active filter banner ─────────────────────────────────────────────────────

class _ActiveFilterBanner extends StatelessWidget {
  const _ActiveFilterBanner({required this.provider, required this.controller});
  final WelfareProvider provider;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        children: [
          Icon(
            Icons.filter_list_rounded,
            size: 14,
            color: AppTheme.textSecondaryFor(context),
          ),
          const SizedBox(width: 6),
          Text(
            '${provider.activeFilterCount} filters active',
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondaryFor(context),
            ),
          ),
          const Spacer(),
          GestureDetector(
            onTap: () {
              controller.clear();
              provider.clearFilters();
            },
            child: Text(
              'Clear all',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Generic chip ─────────────────────────────────────────────────────────────

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.surfaceFor(context),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.borderFor(context),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w600,
              fontSize: 13,
              color: selected ? Colors.white : AppTheme.textSecondaryFor(context),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Section header ───────────────────────────────────────────────────────────

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.subtitle,
    required this.icon,
  });
  final String title;
  final String subtitle;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppTheme.primary),
        const SizedBox(width: 8),
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: AppTheme.textPrimaryFor(context),
            fontSize: 16,
          ),
        ),
        const Spacer(),
        Text(
          subtitle,
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryFor(context)),
        ),
      ],
    );
  }
}

// ── Program card ─────────────────────────────────────────────────────────────

class _ProgramCard extends StatelessWidget {
  const _ProgramCard({required this.program, this.isHighlighted = false});
  final WelfareProgram program;
  final bool isHighlighted;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<WelfareProvider>();
    final bookmarked = provider.isBookmarked(program.id);
    final appStatus = provider.applicationStatus(program.id);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: GestureDetector(
        onTap: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ChangeNotifierProvider.value(
              value: provider,
              child: WelfareProgramDetailPage(program: program),
            ),
          ),
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceFor(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isHighlighted
                  ? AppTheme.primary.withValues(alpha: 0.3)
                  : AppTheme.borderFor(context),
              width: isHighlighted ? 1.5 : 1,
            ),
            boxShadow: isHighlighted
                ? AppTheme.cardShadow
                : AppTheme.softShadow,
          ),
          child: Column(
            children: [
              if (isHighlighted)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primary.withValues(alpha: 0.07),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(17),
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.auto_awesome_rounded,
                        size: 12,
                        color: AppTheme.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        'Recommended for you',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: AppTheme.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: BoxDecoration(
                            color: program.category.badgeColor,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            program.category.icon,
                            color: program.category.badgeTextColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 3,
                                ),
                                decoration: BoxDecoration(
                                  color: program.category.badgeColor,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  program.category.displayName,
                                  style: GoogleFonts.inter(
                                    color: program.category.badgeTextColor,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                                ),
                              ),
                              if (appStatus != null)
                                Padding(
                                  padding: const EdgeInsets.only(top: 3),
                                  child: Text(
                                    _statusLabel(appStatus),
                                    style: GoogleFonts.inter(
                                      fontSize: 11,
                                      color: AppTheme.textSecondaryFor(context),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                        GestureDetector(
                          onTap: () => provider.toggleBookmark(program.id),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: Icon(
                              bookmarked
                                  ? Icons.bookmark_rounded
                                  : Icons.bookmark_outline_rounded,
                              key: ValueKey(bookmarked),
                              color: bookmarked
                                  ? AppTheme.primary
                                  : AppTheme.textSecondaryFor(context),
                              size: 22,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      program.title,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      program.organization,
                      style: GoogleFonts.inter(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: AppTheme.textSecondaryFor(context),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      program.description,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondaryFor(context),
                        height: 1.5,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _MetaPill(
                          icon: Icons.payments_outlined,
                          label: program.estimatedSupportValue,
                          color: AppTheme.success,
                        ),
                        const SizedBox(width: 8),
                        _MetaPill(
                          icon: Icons.speed_rounded,
                          label: program.difficulty.label,
                          color: program.difficulty.color,
                        ),
                        if (program.isVerified) ...[
                          const SizedBox(width: 8),
                          _MetaPill(
                            icon: Icons.verified_rounded,
                            label: 'Verified',
                            color: AppTheme.primary,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChangeNotifierProvider.value(
                                  value: provider,
                                  child: WelfareProgramDetailPage(
                                    program: program,
                                  ),
                                ),
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              side: const BorderSide(color: AppTheme.primary),
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'View Details',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.primary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: ElevatedButton(
                            onPressed: () async => await UrlLauncherService
                                .instance
                                .launchExternalUrl(
                                  context,
                                  program.officialUrl,
                                ),
                            style: ElevatedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                            ),
                            child: Text(
                              'Apply Now',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                fontSize: 13,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _statusLabel(ApplicationStatus s) => switch (s) {
    ApplicationStatus.saved => '🔖 Saved',
    ApplicationStatus.applied => '✉️ Applied',
    ApplicationStatus.inReview => '⏳ In Review',
    ApplicationStatus.approved => '✅ Approved',
    ApplicationStatus.rejected => '❌ Not Approved',
  };
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });
  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ── Impact banner ─────────────────────────────────────────────────────────────

class _ImpactBanner extends StatelessWidget {
  const _ImpactBanner({required this.count});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Impact snapshot',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Compare real support pathways before you apply.',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _ImpactStat(value: '$count', label: 'PROGRAMS'),
              _ImpactStat(
                value: '${WelfareCategory.values.length}',
                label: 'CATEGORIES',
              ),
              const _ImpactStat(value: '100%', label: 'OFFICIAL'),
            ],
          ),
        ],
      ),
    );
  }
}

class _ImpactStat extends StatelessWidget {
  const _ImpactStat({required this.value, required this.label});
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w800,
            fontSize: 22,
          ),
        ),
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 10,
          ),
        ),
      ],
    );
  }
}

// ── Loading skeleton ──────────────────────────────────────────────────────────

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: List.generate(4, (_) => const _SkeletonCard()),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  const _SkeletonCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _Bone(width: 42, height: 42, radius: 12),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Bone(width: 80, height: 12),
                  const SizedBox(height: 6),
                  _Bone(width: 140, height: 18),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          _Bone(width: double.infinity, height: 12),
          const SizedBox(height: 6),
          _Bone(width: 200, height: 12),
          const SizedBox(height: 14),
          Row(
            children: [
              _Bone(width: 80, height: 26, radius: 8),
              const SizedBox(width: 8),
              _Bone(width: 70, height: 26, radius: 8),
            ],
          ),
        ],
      ),
    );
  }
}

class _Bone extends StatelessWidget {
  const _Bone({required this.width, required this.height, this.radius = 6});
  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.borderFor(context),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

// ── Empty state ───────────────────────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onClear});
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 60),
      child: Center(
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.search_off_rounded,
                size: 44,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'No programs found',
              style: GoogleFonts.plusJakartaSans(
                fontWeight: FontWeight.w800,
                fontSize: 18,
                color: AppTheme.textPrimaryFor(context),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Try adjusting your search or filters.',
              style: GoogleFonts.inter(color: AppTheme.textSecondaryFor(context)),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: onClear,
              icon: Icon(Icons.refresh_rounded),
              label: const Text('Clear Filters'),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Error state ───────────────────────────────────────────────────────────────

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 52,
              color: AppTheme.textSecondaryFor(context),
            ),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondaryFor(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: Icon(Icons.refresh_rounded),
              label: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
