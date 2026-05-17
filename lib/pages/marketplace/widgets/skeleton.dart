import 'package:flutter/material.dart';
import '../../../widgets/shimmer_loader.dart';
import '../../../theme/app_theme.dart';

class MarketplaceSkeleton extends StatelessWidget {
  const MarketplaceSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceFor(context),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppTheme.borderFor(context)),
            ),
            child: const Column(
              children: [
                ShimmerBox(height: 16, width: 180, borderRadius: 8),
                SizedBox(height: 12),
                ShimmerBox(height: 14, borderRadius: 8),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: ShimmerBox(height: 72, borderRadius: 18)),
                    SizedBox(width: 10),
                    Expanded(child: ShimmerBox(height: 72, borderRadius: 18)),
                    SizedBox(width: 10),
                    Expanded(child: ShimmerBox(height: 72, borderRadius: 18)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AppTheme.surfaceFor(context),
              borderRadius: BorderRadius.circular(26),
              border: Border.all(color: AppTheme.borderFor(context)),
            ),
            child: const Column(
              children: [
                ShimmerBox(height: 52, borderRadius: 18),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: ShimmerBox(height: 34, borderRadius: 999)),
                    SizedBox(width: 8),
                    Expanded(child: ShimmerBox(height: 34, borderRadius: 999)),
                    SizedBox(width: 8),
                    Expanded(child: ShimmerBox(height: 34, borderRadius: 999)),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(child: ShimmerBox(height: 34, borderRadius: 999)),
                    SizedBox(width: 8),
                    Expanded(child: ShimmerBox(height: 34, borderRadius: 999)),
                    SizedBox(width: 8),
                    Expanded(child: ShimmerBox(height: 34, borderRadius: 999)),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          const ShimmerBox(height: 220, borderRadius: 28),
          const SizedBox(height: 14),
          const ShimmerBox(height: 300, borderRadius: 28),
          const SizedBox(height: 14),
          const ShimmerBox(height: 300, borderRadius: 28),
        ],
      ),
    );
  }
}
