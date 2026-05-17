import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/firestore_service.dart';
import '../../services/url_launcher_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';
import '../../models/marketplace_models.dart';

class PartnerDetailScreen extends StatelessWidget {
  const PartnerDetailScreen({
    super.key,
    required this.partner,
    required this.firestoreService,
    required this.isCompared,
    required this.onToggleCompare,
  });

  final MarketplacePartner partner;
  final FirestoreService firestoreService;
  final bool isCompared;
  final ValueChanged<MarketplacePartner> onToggleCompare;

  @override
  Widget build(BuildContext context) {
    final color = Color(partner.colorHex);

    return Scaffold(
      backgroundColor: AppTheme.backgroundFor(context),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            pinned: true,
            expandedHeight: 260,
            backgroundColor: AppTheme.primary,
            actions: [
              IconButton(
                tooltip: isCompared ? 'Remove from compare' : 'Add to compare',
                onPressed: () {
                  onToggleCompare(partner);
                  firestoreService.logMarketplaceEvent(
                    isCompared ? 'compare_remove' : 'compare_add',
                    payload: {'partnerId': partner.id, 'source': 'detail'},
                  );
                },
                icon: Icon(
                  isCompared
                      ? Icons.check_circle_rounded
                      : Icons.compare_arrows_rounded,
                ),
              ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [color, AppTheme.primary, const Color(0xFF0F172A)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 72, 20, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _TopChip(label: partner.category),
                            if (partner.isVerified)
                              const _TopChip(label: 'Verified'),
                            _TopChip(
                              label:
                                  'Trust ${partner.trustScore.toStringAsFixed(0)}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          partner.name,
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          partner.description,
                          style: GoogleFonts.inter(
                            color: Colors.white.withValues(alpha: 0.82),
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Row(
                          children: [
                            Expanded(
                              child: _HeroMetric(
                                label: 'Estimated benefit',
                                value: partner.estimatedBenefit,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: _HeroMetric(
                                label: 'Approval speed',
                                value: partner.approvalSpeed,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
              child: Column(
                children: [
                  _TrustLayerCard(partner: partner),
                  const SizedBox(height: 16),
                  _ActionCard(
                    partner: partner,
                    onPrimaryTap: () async {
                      await firestoreService.logMarketplaceEvent(
                        'partner_apply_cta_clicked',
                        payload: {'partnerId': partner.id},
                      );
                      if (!context.mounted) return;
                      _showApplyOptions(context, partner, firestoreService);
                    },
                    onSecondaryTap: () {
                      onToggleCompare(partner);
                      firestoreService.logMarketplaceEvent(
                        isCompared ? 'compare_remove' : 'compare_add',
                        payload: {
                          'partnerId': partner.id,
                          'source': 'detail_cta',
                        },
                      );
                    },
                    isCompared: isCompared,
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Product snapshot',
                    child: Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        _SnapshotItem(label: 'Rates', value: partner.rateLabel),
                        _SnapshotItem(
                          label: 'Approval',
                          value: partner.approvalSpeed,
                        ),
                        _SnapshotItem(
                          label: 'Minimum income',
                          value: partner.minimumIncome == null
                              ? 'Not specified'
                              : CurrencyUtils.format(partner.minimumIncome!),
                        ),
                        _SnapshotItem(
                          label: 'Ceiling',
                          value: partner.maxAmount == null
                              ? 'Varies'
                              : CurrencyUtils.format(partner.maxAmount!),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Benefits and eligibility',
                    child: Column(
                      children: [
                        _BulletList(title: 'Benefits', items: partner.benefits),
                        const SizedBox(height: 14),
                        _BulletList(
                          title: 'Eligibility hints',
                          items: partner.eligibility,
                        ),
                        if (partner.requirements.isNotEmpty) ...[
                          const SizedBox(height: 14),
                          _BulletList(
                            title: 'Typical requirements',
                            items: partner.requirements,
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  _SectionCard(
                    title: 'Safety and risk',
                    child: Column(
                      children: [
                        _BulletList(
                          title: 'Safety signals',
                          items: partner.safetySignals,
                        ),
                        const SizedBox(height: 14),
                        _BulletList(
                          title: 'What to review',
                          items: partner.riskIndicators,
                        ),
                      ],
                    ),
                  ),
                  if (partner.tags.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    _SectionCard(
                      title: 'Tags',
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: partner.tags
                            .map(
                              (tag) => Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                decoration: BoxDecoration(
                                  color: AppTheme.surfaceCardFor(context),
                                  borderRadius: BorderRadius.circular(999),
                                  border: Border.all(color: AppTheme.borderFor(context)),
                                ),
                                child: Text(
                                  tag,
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textPrimaryFor(context),
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                ),
                              ),
                            )
                            .toList(),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

void _showApplyOptions(
  BuildContext context,
  MarketplacePartner partner,
  FirestoreService firestoreService,
) {
  final rootContext = context;
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) {
      final hasWebsite = partner.websiteUrl?.trim().isNotEmpty ?? false;
      return Container(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
        ),
        child: Container(
          decoration: BoxDecoration(
            color: AppTheme.backgroundFor(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.all(18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'How would you like to proceed?',
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimaryFor(context),
                  fontWeight: FontWeight.w800,
                  fontSize: 16,
                ),
              ),
              const SizedBox(height: 12),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: hasWebsite
                      ? () async {
                          Navigator.pop(sheetContext);
                          await firestoreService.logMarketplaceEvent(
                            'partner_apply_continue_external',
                            payload: {'partnerId': partner.id},
                          );
                          if (!rootContext.mounted) return;
                          final success = await UrlLauncherService.instance
                              .launchExternalUrl(
                                rootContext,
                                partner.websiteUrl!.trim(),
                                failMessage:
                                    'Could not open the partner website.',
                              );
                          await firestoreService.logMarketplaceEvent(
                            'partner_apply_external_launched',
                            payload: {
                              'partnerId': partner.id,
                              'launched': success,
                            },
                          );
                        }
                      : null,
                  child: Text(
                    hasWebsite
                        ? 'Continue to partner website'
                        : 'Partner website unavailable',
                  ),
                ),
              ),
              const SizedBox(height: 14),
            ],
          ),
        ),
      );
    },
  );
}

class _TopChip extends StatelessWidget {
  const _TopChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: Colors.white,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.66),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TrustLayerCard extends StatelessWidget {
  const _TrustLayerCard({required this.partner});

  final MarketplacePartner partner;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderFor(context)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Trust layer',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textPrimaryFor(context),
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _TrustMetric(
                  label: 'Trust score',
                  value: '${partner.trustScore.toStringAsFixed(0)}/100',
                ),
              ),
              Expanded(
                child: _TrustMetric(
                  label: 'User rating',
                  value: '${partner.rating.toStringAsFixed(1)} / 5',
                ),
              ),
              Expanded(
                child: _TrustMetric(
                  label: 'Reviews',
                  value: '${partner.reviewCount}+',
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: partner.safetySignals
                .map(
                  (signal) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF0FDF4),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      signal,
                      style: GoogleFonts.inter(
                        color: AppTheme.success,
                        fontWeight: FontWeight.w600,
                        fontSize: 12,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
        ],
      ),
    );
  }
}

class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.partner,
    required this.onPrimaryTap,
    required this.onSecondaryTap,
    required this.isCompared,
  });

  final MarketplacePartner partner;
  final VoidCallback onPrimaryTap;
  final VoidCallback onSecondaryTap;
  final bool isCompared;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Next step',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Review the fit here first, then continue to the partner when you are ready. This keeps FinEase in the decision loop for future lead tracking.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: onPrimaryTap,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0F172A),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(partner.ctaLabel),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton(
                  onPressed: onSecondaryTap,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.white,
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.24),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(isCompared ? 'Added to compare' : 'Compare'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.borderFor(context)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textPrimaryFor(context),
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _SnapshotItem extends StatelessWidget {
  const _SnapshotItem({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: MediaQuery.of(context).size.width > 420 ? 160 : double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCardFor(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondaryFor(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textPrimaryFor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  const _BulletList({required this.title, required this.items});

  final String title;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimaryFor(context),
            fontWeight: FontWeight.w700,
            fontSize: 15,
          ),
        ),
        const SizedBox(height: 10),
        ...items.map(
          (item) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  margin: const EdgeInsets.only(top: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.primary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item,
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondaryFor(context),
                      height: 1.45,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TrustMetric extends StatelessWidget {
  const _TrustMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCardFor(context),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondaryFor(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textPrimaryFor(context),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
