import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_config_gate.dart';

class MarketplaceScreen extends StatefulWidget {
  const MarketplaceScreen({super.key});

  @override
  State<MarketplaceScreen> createState() => _MarketplaceScreenState();
}

class _MarketplaceScreenState extends State<MarketplaceScreen> {
  String _category = 'All';

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
        body: CustomScrollView(
          slivers: [
            SliverAppBar(
              expandedHeight: 150,
              pinned: true,
              automaticallyImplyLeading: true,
              backgroundColor: AppTheme.primary,
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: const BoxDecoration(
                    gradient: AppTheme.cardGradient,
                  ),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 16, 20, 18),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Text(
                            'Partner Marketplace',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Browse trusted services, financing options, and growth partners sourced for Pakistani users.',
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.8),
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
                      builder: (context, snapshot) {
                        final partners = snapshot.data ?? const [];
                        final categories = {
                          'All',
                          ...partners.map(
                            (partner) =>
                                partner['category'] as String? ?? 'General',
                          ),
                        }.toList();
                        final filtered = _category == 'All'
                            ? partners
                            : partners
                                  .where(
                                    (partner) =>
                                        partner['category'] == _category,
                                  )
                                  .toList();

                        return Padding(
                          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
                          child: Column(
                            children: [
                              SizedBox(
                                height: 46,
                                child: ListView.separated(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: categories.length,
                                  separatorBuilder: (_, index) =>
                                      const SizedBox(width: 8),
                                  itemBuilder: (context, index) {
                                    final value = categories[index];
                                    final selected = value == _category;
                                    return ChoiceChip(
                                      label: Text(value),
                                      selected: selected,
                                      onSelected: (_) =>
                                          setState(() => _category = value),
                                    );
                                  },
                                ),
                              ),
                              const SizedBox(height: 18),
                              _TrustBanner(count: filtered.length),
                              const SizedBox(height: 16),
                              if (filtered.isEmpty)
                                const _EmptyMarketplace()
                              else
                                ...filtered.map(
                                  (partner) => _PartnerCard(partner: partner),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrustBanner extends StatelessWidget {
  const _TrustBanner({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.verified_user_rounded,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              '$count verified opportunities currently available. Finease highlights practical services that can support income, protection, financing, and financial stability.',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                height: 1.5,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PartnerCard extends StatelessWidget {
  const _PartnerCard({required this.partner});

  final Map<String, dynamic> partner;

  @override
  Widget build(BuildContext context) {
    final color = Color(
      (partner['colorHex'] as int?) ?? AppTheme.primary.toARGB32(),
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  _iconFor(partner['iconName'] as String?),
                  color: color,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      partner['name'] as String? ?? 'Partner',
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      partner['category'] as String? ?? 'General',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              if ((partner['badge'] as String?)?.isNotEmpty ?? false)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    partner['badge'] as String,
                    style: GoogleFonts.inter(
                      color: color,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            partner['description'] as String? ?? '',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () =>
                  _openUrl(context, partner['websiteUrl'] as String?),
              child: Text(partner['ctaLabel'] as String? ?? 'Learn More'),
            ),
          ),
          if (partner['latitude'] != null && partner['longitude'] != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: () => _openMap(
                  context,
                  (partner['latitude'] as num).toDouble(),
                  (partner['longitude'] as num).toDouble(),
                  partner['name'] as String? ?? 'Marketplace partner',
                ),
                icon: const Icon(Icons.map_outlined),
                label: const Text('View Location on Map'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openUrl(BuildContext context, String? url) async {
    if (url == null || url.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No live website link is configured.')),
      );
      return;
    }
    final uri = Uri.parse(url);
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open this website.')),
      );
    }
  }

  Future<void> _openMap(
    BuildContext context,
    double latitude,
    double longitude,
    String label,
  ) async {
    final uri = Uri.parse(
      'https://www.google.com/maps/search/?api=1&query=$latitude,$longitude',
    );
    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not open map for $label.')));
    }
  }

  IconData _iconFor(String? name) {
    switch (name) {
      case 'shield':
        return Icons.shield_rounded;
      case 'bank':
        return Icons.account_balance_rounded;
      case 'briefcase':
        return Icons.work_rounded;
      case 'sun':
        return Icons.solar_power_rounded;
      case 'school':
        return Icons.school_rounded;
      default:
        return Icons.storefront_rounded;
    }
  }
}

class _EmptyMarketplace extends StatelessWidget {
  const _EmptyMarketplace();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.storefront_rounded,
            size: 56,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 12),
          Text(
            'No partners in this category yet.',
            style: GoogleFonts.plusJakartaSans(
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
        ],
      ),
    );
  }
}
