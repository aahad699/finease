import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

// ─── Core shimmer widget ───────────────────────────────────────────────────────

/// A lightweight shimmer skeleton that animates between two grey tones.
/// No external package required.
class ShimmerBox extends StatefulWidget {
  const ShimmerBox({
    super.key,
    this.height = 48,
    this.width,
    this.borderRadius = 12,
  });

  final double height;
  final double? width;
  final double borderRadius;

  @override
  State<ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<ShimmerBox>
    with SingleTickerProviderStateMixin {
  late AnimationController _ctrl;
  late Animation<double> _anim;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1100),
    )..repeat(reverse: true);
    _anim = CurvedAnimation(parent: _ctrl, curve: Curves.easeInOut);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, child) => Container(
        height: widget.height,
        width: widget.width ?? double.infinity,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.borderRadius),
          color: Color.lerp(
            const Color(0xFFE8EDF3),
            const Color(0xFFF5F7FA),
            _anim.value,
          ),
        ),
      ),
    );
  }
}

// ─── Composed skeleton cards ───────────────────────────────────────────────────

/// Hero balance card skeleton — matches `_BalanceCard` dimensions.
class BalanceCardShimmer extends StatelessWidget {
  const BalanceCardShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const ShimmerBox(height: 12, width: 100, borderRadius: 6),
          const SizedBox(height: 12),
          const ShimmerBox(height: 36, width: 200, borderRadius: 8),
          const SizedBox(height: 24),
          Container(height: 1, color: Colors.white12),
          const SizedBox(height: 18),
          Row(
            children: const [
              Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
              SizedBox(width: 12),
              Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
              SizedBox(width: 12),
              Expanded(child: ShimmerBox(height: 36, borderRadius: 8)),
            ],
          ),
        ],
      ),
    );
  }
}

/// Horizontal row of quick-action skeleton chips.
class QuickActionsShimmer extends StatelessWidget {
  const QuickActionsShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: 5,
        separatorBuilder: (context, index) => const SizedBox(width: 12),
        itemBuilder: (context, index) => Column(
          children: const [
            ShimmerBox(height: 52, width: 52, borderRadius: 16),
            SizedBox(height: 6),
            ShimmerBox(height: 10, width: 40, borderRadius: 4),
          ],
        ),
      ),
    );
  }
}

/// Single transaction row skeleton.
class TransactionTileShimmer extends StatelessWidget {
  const TransactionTileShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.borderFor(context)),
      ),
      child: Row(
        children: [
          const ShimmerBox(height: 44, width: 44, borderRadius: 13),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const [
                ShimmerBox(height: 13, borderRadius: 6),
                SizedBox(height: 6),
                ShimmerBox(height: 10, width: 80, borderRadius: 4),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: const [
              ShimmerBox(height: 14, width: 70, borderRadius: 6),
              SizedBox(height: 4),
              ShimmerBox(height: 10, width: 40, borderRadius: 4),
            ],
          ),
        ],
      ),
    );
  }
}

/// A list of [count] `TransactionTileShimmer` widgets.
class TransactionListShimmer extends StatelessWidget {
  const TransactionListShimmer({super.key, this.count = 4});
  final int count;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(count, (index) => const TransactionTileShimmer()),
    );
  }
}

/// Chart area skeleton — used in analytics while loading.
class ChartShimmer extends StatelessWidget {
  const ChartShimmer({super.key, this.height = 200});
  final double height;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderFor(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: const [
              ShimmerBox(height: 36, width: 36, borderRadius: 10),
              SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ShimmerBox(height: 14, borderRadius: 6),
                    SizedBox(height: 4),
                    ShimmerBox(height: 10, width: 100, borderRadius: 4),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ShimmerBox(height: 160, borderRadius: 12),
        ],
      ),
    );
  }
}
