import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../models/marketplace_models.dart';
import '../../../theme/app_theme.dart';

class FeaturedPartnerCard extends StatelessWidget {
  const FeaturedPartnerCard({
    required this.partner,
    required this.onTap,
    super.key,
  });

  final MarketplacePartner partner;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = Color(partner.colorHex);
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 290,
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              color,
              color.withValues(alpha: 0.76),
              const Color(0xFF0F172A),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(28),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    partner.badge.isEmpty ? 'Featured' : partner.badge,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const Spacer(),
                Icon(Icons.north_east_rounded, color: Colors.white),
              ],
            ),
            const Spacer(),
            Text(
              partner.name,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              partner.estimatedBenefit,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.78),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _FeaturedMetric(
                    label: 'Trust',
                    value: '${partner.trustScore.toStringAsFixed(0)}/100',
                  ),
                ),
                Expanded(
                  child: _FeaturedMetric(
                    label: 'Rate',
                    value: partner.rateLabel,
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

class _FeaturedMetric extends StatelessWidget {
  const _FeaturedMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.62),
            fontSize: 11,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
