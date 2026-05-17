import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/transaction.dart';
import '../../models/prediction_models.dart';
import '../../services/prediction_service.dart';
import '../../theme/app_theme.dart';

class ForecastScreen extends StatefulWidget {
  final List<FinancialTransaction> transactions;
  final Map<String, double> budgets;
  final double monthlyIncome;

  const ForecastScreen({
    super.key,
    required this.transactions,
    required this.budgets,
    required this.monthlyIncome,
  });

  @override
  State<ForecastScreen> createState() => _ForecastScreenState();
}

class _ForecastScreenState extends State<ForecastScreen>
    with SingleTickerProviderStateMixin {
  late final PredictionService _svc;
  late final ForecastResult _forecast;
  late final ForecastResult _savings;
  late final List<BudgetWarning> _warnings;
  late final AnimationController _anim;
  int? _touchedIndex;

  static const _primary = Color(0xFF2E3192);
  static const _success = Color(0xFF059669);
  static const _danger = Color(0xFFDC2626);
  static const _predColor = Color(0xFF00C2A8); // teal for prediction bar

  @override
  void initState() {
    super.initState();
    _svc = PredictionService();
    _forecast = _svc.predictNextMonthExpenses(widget.transactions);

    final income = widget.monthlyIncome > 0 ? widget.monthlyIncome : 1.0;
    _savings = _svc.forecastSavings(income, _forecast.categoryPredictions);

    final now = DateTime.now();
    final currentMonth = widget.transactions
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .toList();
    _warnings = _svc.getBudgetWarnings(currentMonth, widget.budgets);

    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();
  }

  @override
  void dispose() {
    _anim.dispose();
    super.dispose();
  }

  // Build bar data for last 3 months + 1 prediction bar
  List<_MonthBar> _buildBarData() {
    final now = DateTime.now();
    final months = <_MonthBar>[];
    for (int offset = 3; offset >= 1; offset--) {
      final dt = _monthOffset(now, -offset);
      final total = _svc.getTotalForMonth(
        widget.transactions,
        dt.year,
        dt.month,
      );
      months.add(
        _MonthBar(
          label: _monthAbbr(dt.month),
          amount: total,
          isPrediction: false,
        ),
      );
    }
    months.add(
      _MonthBar(
        label: 'Next\n${_monthAbbr(_monthOffset(now, 1).month)}',
        amount: _forecast.totalPredicted,
        isPrediction: true,
      ),
    );
    return months;
  }

  @override
  Widget build(BuildContext context) {
    final bars = _buildBarData();
    final maxVal = bars.map((b) => b.amount).fold(0.0, (a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: AppTheme.backgroundFor(context),
      body: CustomScrollView(
        slivers: [
          _buildAppBar(),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                const SizedBox(height: 12),

                // ── Savings highlight card ──────────────────────────────
                _buildSavingsCard(),
                const SizedBox(height: 20),

                // ── Monthly bar chart ───────────────────────────────────
                _sectionHeader(
                  Icons.bar_chart_rounded,
                  'Monthly Overview',
                  'Last 3 months + forecast',
                ),
                const SizedBox(height: 12),
                _buildBarChart(bars, maxVal),
                const SizedBox(height: 24),

                // ── Budget warnings ─────────────────────────────────────
                if (_warnings.isNotEmpty) ...[
                  _sectionHeader(
                    Icons.warning_amber_rounded,
                    'Budget Alerts',
                    '${_warnings.length} at risk',
                    iconColor: _danger,
                  ),
                  const SizedBox(height: 12),
                  ..._warnings.map(_buildWarningTile),
                  const SizedBox(height: 24),
                ],

                // ── Category prediction table ───────────────────────────
                _sectionHeader(
                  Icons.table_chart_rounded,
                  'Category Predictions',
                  'Weighted 3-month forecast',
                ),
                const SizedBox(height: 12),
                _buildCategoryTable(),
                const SizedBox(height: 24),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  // ── AppBar ─────────────────────────────────────────────────────────────────
  SliverAppBar _buildAppBar() => SliverAppBar(
    expandedHeight: 120,
    floating: false,
    pinned: true,
    backgroundColor: _primary,
    leading: IconButton(
      icon: Icon(
        Icons.arrow_back_ios_new_rounded,
        color: Colors.white,
        size: 20,
      ),
      onPressed: () => Navigator.pop(context),
    ),
    flexibleSpace: FlexibleSpaceBar(
      titlePadding: const EdgeInsets.fromLTRB(20, 0, 0, 16),
      title: Text(
        'Spending Forecast',
        style: GoogleFonts.plusJakartaSans(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w700,
        ),
      ),
      background: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFF2E3192), Color(0xFF4B5BD6)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Align(
          alignment: Alignment.centerRight,
          child: Padding(
            padding: const EdgeInsets.only(right: 20, top: 20),
            child: Icon(
              Icons.auto_graph_rounded,
              size: 64,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
        ),
      ),
    ),
  );

  // ── Savings Card ───────────────────────────────────────────────────────────
  Widget _buildSavingsCard() {
    final isPositive = _savings.predictedSavings >= 0;
    final color = isPositive ? _success : _danger;
    final pct = _savings.savingsPercentage;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: isPositive
              ? [const Color(0xFF059669), const Color(0xFF047857)]
              : [const Color(0xFFDC2626), const Color(0xFFB91C1C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.30),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Projected Savings',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.8),
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'PKR ${PredictionService.fmt(_savings.predictedSavings.abs())}',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  isPositive
                      ? '${pct.toStringAsFixed(1)}% of your monthly income'
                      : 'You\'re spending more than you earn',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.75),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPositive ? Icons.savings_rounded : Icons.warning_rounded,
              color: Colors.white,
              size: 32,
            ),
          ),
        ],
      ),
    );
  }

  // ── Bar Chart ──────────────────────────────────────────────────────────────
  Widget _buildBarChart(List<_MonthBar> bars, double maxVal) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (_, _) => Container(
        height: 250,
        padding: const EdgeInsets.fromLTRB(8, 20, 8, 8),
        decoration: BoxDecoration(
          color: AppTheme.surfaceFor(context),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Legend
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                _LegendDot(color: _primary, label: 'Historical'),
                const SizedBox(width: 16),
                _LegendDot(color: _predColor, label: 'Predicted'),
              ],
            ),
            const SizedBox(height: 8),
            Expanded(
              child: BarChart(
                BarChartData(
                  maxY: maxVal * 1.3,
                  barTouchData: BarTouchData(
                    touchCallback: (_, resp) {
                      setState(() {
                        _touchedIndex = resp?.spot?.touchedBarGroupIndex;
                      });
                    },
                    touchTooltipData: BarTouchTooltipData(
                      getTooltipColor: (g) => bars[g.x.toInt()].isPrediction
                          ? _predColor
                          : _primary,
                      getTooltipItem: (group, gi, rod, ri) => BarTooltipItem(
                        'PKR ${PredictionService.fmt(rod.toY)}',
                        GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  titlesData: FlTitlesData(
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 50,
                        getTitlesWidget: (v, _) => Text(
                          _fmtK(v),
                          style: const TextStyle(
                            fontSize: 9,
                            color: Color(0xFF94A3B8),
                          ),
                        ),
                      ),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        reservedSize: 36,
                        getTitlesWidget: (v, _) {
                          final i = v.toInt();
                          if (i < 0 || i >= bars.length) {
                            return const SizedBox.shrink();
                          }
                          return Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: Text(
                              bars[i].label,
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: bars[i].isPrediction
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: bars[i].isPrediction
                                    ? _predColor
                                    : const Color(0xFF64748B),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: FlGridData(
                    show: true,
                    drawVerticalLine: false,
                    getDrawingHorizontalLine: (_) => FlLine(
                      color: const Color(0xFFE2E8F0),
                      strokeWidth: 1,
                      dashArray: [4, 4],
                    ),
                  ),
                  borderData: FlBorderData(show: false),
                  barGroups: List.generate(bars.length, (i) {
                    final bar = bars[i];
                    final isTouched = _touchedIndex == i;
                    final animVal = bar.amount * _anim.value;
                    return BarChartGroupData(
                      x: i,
                      barRods: [
                        BarChartRodData(
                          toY: animVal,
                          width: isTouched ? 20 : 16,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(8),
                          ),
                          gradient: LinearGradient(
                            colors: bar.isPrediction
                                ? [
                                    _predColor.withValues(alpha: 0.7),
                                    _predColor,
                                  ]
                                : isTouched
                                ? [
                                    const Color(0xFF4B5BD6),
                                    const Color(0xFF2E3192),
                                  ]
                                : [
                                    const Color(0xFF818CF8),
                                    const Color(0xFF4B5BD6),
                                  ],
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                          ),
                        ),
                      ],
                    );
                  }),
                ),
                duration: Duration.zero,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Warning Tile ───────────────────────────────────────────────────────────
  Widget _buildWarningTile(BudgetWarning w) {
    final progress = (w.currentSpend / w.budget).clamp(0.0, 1.5);
    final isExceeded = w.daysUntilExceed == 0;
    final color = isExceeded ? _danger : const Color(0xFFF59E0B);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: color, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  w.message,
                  style: GoogleFonts.inter(
                    fontSize: 12.5,
                    color: color,
                    fontWeight: FontWeight.w600,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Spent: PKR ${PredictionService.fmt(w.currentSpend)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
              Text(
                'Budget: PKR ${PredictionService.fmt(w.budget)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: const Color(0xFF64748B),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              minHeight: 7,
              backgroundColor: color.withValues(alpha: 0.12),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (w.projectedOverspend > 0)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'Projected overspend: PKR ${PredictionService.fmt(w.projectedOverspend)}',
                style: GoogleFonts.inter(
                  fontSize: 10.5,
                  color: _danger,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // ── Category Table ─────────────────────────────────────────────────────────
  Widget _buildCategoryTable() {
    final entries = _forecast.categoryPredictions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.07),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: AppTheme.surfaceCardFor(context),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Category',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Predicted',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Budget',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Status',
                    textAlign: TextAlign.right,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: _primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Table rows
          ...entries.asMap().entries.map((entry) {
            final i = entry.key;
            final cat = entry.value.key;
            final pred = entry.value.value;
            final budget = widget.budgets[cat];
            final isLast = i == entries.length - 1;
            final isOver = budget != null && pred > budget;

            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: i.isEven
                    ? AppTheme.surfaceFor(context)
                    : AppTheme.surfaceCardFor(context),
                borderRadius: isLast
                    ? const BorderRadius.vertical(bottom: Radius.circular(20))
                    : null,
                border: !isLast
                    ? Border(bottom: BorderSide(color: AppTheme.borderFor(context)))
                    : null,
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      cat,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppTheme.textPrimaryFor(context),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      'PKR ${PredictionService.fmt(pred)}',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: isOver ? _danger : _primary,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      budget != null
                          ? 'PKR ${PredictionService.fmt(budget)}'
                          : '—',
                      textAlign: TextAlign.right,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: const Color(0xFF94A3B8),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Align(
                      alignment: Alignment.centerRight,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: budget == null
                              ? const Color(0xFFF1F5F9)
                              : isOver
                              ? _danger.withValues(alpha: 0.12)
                              : _success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          budget == null
                              ? 'No budget'
                              : isOver
                              ? 'Over'
                              : 'OK',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: budget == null
                                ? const Color(0xFF64748B)
                                : isOver
                                ? _danger
                                : _success,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Widget _sectionHeader(
    IconData icon,
    String title,
    String subtitle, {
    Color iconColor = _primary,
  }) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 20),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryFor(context),
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 12,
                color: const Color(0xFF64748B),
              ),
            ),
          ],
        ),
      ],
    );
  }

  DateTime _monthOffset(DateTime base, int months) {
    int m = base.month + months;
    int y = base.year;
    while (m <= 0) {
      m += 12;
      y--;
    }
    while (m > 12) {
      m -= 12;
      y++;
    }
    final maxDay = DateTime(y, m + 1, 0).day;
    return DateTime(y, m, base.day.clamp(1, maxDay));
  }

  String _monthAbbr(int m) => const [
    'Jan',
    'Feb',
    'Mar',
    'Apr',
    'May',
    'Jun',
    'Jul',
    'Aug',
    'Sep',
    'Oct',
    'Nov',
    'Dec',
  ][m - 1];

  String _fmtK(double v) =>
      v >= 1000 ? '${(v / 1000).toStringAsFixed(0)}k' : v.toStringAsFixed(0);
}

// ── Data classes ─────────────────────────────────────────────────────────────

class _MonthBar {
  final String label;
  final double amount;
  final bool isPrediction;
  const _MonthBar({
    required this.label,
    required this.amount,
    required this.isPrediction,
  });
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
      const SizedBox(width: 5),
      Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          color: const Color(0xFF64748B),
          fontWeight: FontWeight.w500,
        ),
      ),
    ],
  );
}
