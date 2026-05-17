import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

import '../../models/transaction.dart';
import '../../models/spending_analytics.dart';
import '../../services/auth_service.dart';
import '../../services/spending_analytics_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';
import '../../widgets/shimmer_loader.dart';

class AnalyticsScreen extends StatelessWidget {
  const AnalyticsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Use the cached FirestoreService from AuthService — avoids a force-unwrap
    // crash and reuses the same instance that the rest of the app shares.
    final fs = context.watch<AuthService>().firestoreService;

    if (fs == null) {
      return Scaffold(
        backgroundColor: AppTheme.backgroundFor(context),
        body: Center(
          child: CircularProgressIndicator(color: AppTheme.primary),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppTheme.backgroundFor(context),
      body: StreamBuilder<List<FinancialTransaction>>(
        stream: fs.getTransactions(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return ListView(
              padding: const EdgeInsets.fromLTRB(20, 100, 20, 40),
              children: const [
                ChartShimmer(),
                SizedBox(height: 16),
                ChartShimmer(),
                SizedBox(height: 16),
                ChartShimmer(),
              ],
            );
          }
          final transactions = snap.data ?? [];
          final svc = SpendingAnalyticsService();
          final weeklyTrends = svc.getWeeklyTrends(transactions);
          final anomalies = svc.detectAnomalies(transactions);
          final recurring = svc.detectRecurringExpenses(transactions);

          final now = DateTime.now();
          final monthTxns = transactions.where(
            (t) => t.date.year == now.year && t.date.month == now.month,
          ).toList();
          final totalIncome = monthTxns
              .where((t) => t.type == 'income')
              .fold<double>(0, (s, t) => s + t.amount);
          final totalExpense = monthTxns
              .where((t) => t.type == 'expense')
              .fold<double>(0, (s, t) => s + t.amount);
          final categorySpending = _computeCategorySpending(monthTxns);
          final monthlyComparison = _computeMonthlyComparison(transactions);

          return CustomScrollView(
            physics: const BouncingScrollPhysics(),
            slivers: [
              _buildAppBar(context),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 110),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    const SizedBox(height: 8),

                    // ── Month Summary Cards ──────────────────────────────
                    _MonthlySummaryRow(
                      income: totalIncome,
                      expense: totalExpense,
                      net: totalIncome - totalExpense,
                    ),
                    const SizedBox(height: 24),

                    // ── Category Donut Chart ─────────────────────────────
                    if (categorySpending.isNotEmpty) ...[
                      _ChartCard(
                        title: 'Spending Breakdown',
                        subtitle: 'By category this month',
                        icon: Icons.donut_large_rounded,
                        child: _CategoryDonutChart(data: categorySpending),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Income vs Expense Bar Chart ──────────────────────
                    if (monthlyComparison.isNotEmpty) ...[
                      _ChartCard(
                        title: 'Income vs Expenses',
                        subtitle: 'Last 6 months',
                        icon: Icons.bar_chart_rounded,
                        child: _IncomeExpenseChart(data: monthlyComparison),
                      ),
                      const SizedBox(height: 20),
                    ],

                    // ── Weekly Spending Trend ────────────────────────────
                    _ChartCard(
                      title: 'Weekly Spending',
                      subtitle: 'Last 8 weeks',
                      icon: Icons.timeline_rounded,
                      child: _WeeklyBarChart(trends: weeklyTrends),
                    ),
                    const SizedBox(height: 24),

                    // ── Spending Alerts ──────────────────────────────────
                    if (anomalies.isNotEmpty) ...[
                      _AnalyticsSectionHeader(
                        icon: Icons.warning_amber_rounded,
                        title: 'Spending Alerts',
                        subtitle:
                            '${anomalies.length} categor${anomalies.length == 1 ? 'y' : 'ies'} flagged',
                        iconColor: AppTheme.warning,
                      ),
                      const SizedBox(height: 12),
                      ...anomalies.map((a) => _AnomalyCard(anomaly: a)),
                      const SizedBox(height: 24),
                    ],

                    // ── Recurring Expenses ───────────────────────────────
                    _AnalyticsSectionHeader(
                      icon: Icons.repeat_rounded,
                      title: 'Recurring Expenses',
                      subtitle: recurring.isEmpty
                          ? 'None detected yet'
                          : '${recurring.length} detected',
                    ),
                    const SizedBox(height: 12),
                    if (recurring.isEmpty)
                      _AnalyticsEmptyState(
                        icon: Icons.repeat_outlined,
                        message:
                            'No recurring expenses detected yet.\nAdd more transactions to see patterns.',
                      )
                    else
                      ...recurring.map((r) => _RecurringCard(expense: r)),
                  ]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  SliverAppBar _buildAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 100,
      floating: false,
      pinned: true,
      backgroundColor: AppTheme.surfaceFor(context),
      elevation: 0,
      leading: IconButton(
        icon: Icon(
          Icons.arrow_back_ios_new_rounded,
          size: 18,
          color: AppTheme.textPrimaryFor(context),
        ),
        onPressed: () => Navigator.maybePop(context),
      ),
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.fromLTRB(20, 0, 0, 16),
        title: Text(
          'Analytics',
          style: GoogleFonts.inter(
            color: AppTheme.textPrimaryFor(context),
            fontSize: 22,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        background: Container(color: AppTheme.surfaceFor(context)),
      ),
    );
  }

  static Map<String, double> _computeCategorySpending(
    List<FinancialTransaction> txns,
  ) {
    final map = <String, double>{};
    for (final t in txns.where((t) => t.type == 'expense')) {
      map[t.category] = (map[t.category] ?? 0) + t.amount;
    }
    return map;
  }

  static List<_MonthData> _computeMonthlyComparison(
    List<FinancialTransaction> txns,
  ) {
    final now = DateTime.now();
    final result = <String, _MonthData>{};
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i);
      final key = DateFormat('MMM yy').format(m);
      result[key] = _MonthData(month: key, income: 0, expense: 0);
    }
    for (final t in txns) {
      final key = DateFormat('MMM yy').format(t.date);
      if (result.containsKey(key)) {
        final d = result[key]!;
        result[key] = t.type == 'income'
            ? _MonthData(
                month: d.month,
                income: d.income + t.amount,
                expense: d.expense,
              )
            : _MonthData(
                month: d.month,
                income: d.income,
                expense: d.expense + t.amount,
              );
      }
    }
    return result.values.toList();
  }
}

class _MonthData {
  const _MonthData({
    required this.month,
    required this.income,
    required this.expense,
  });
  final String month;
  final double income;
  final double expense;
}

// ─── Monthly Summary Row ──────────────────────────────────────────────────────

class _MonthlySummaryRow extends StatelessWidget {
  const _MonthlySummaryRow({
    required this.income,
    required this.expense,
    required this.net,
  });
  final double income;
  final double expense;
  final double net;

  @override
  Widget build(BuildContext context) {
    final month = DateFormat('MMMM').format(DateTime.now());
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$month Overview',
          style: GoogleFonts.inter(
            fontSize: 13,
            color: AppTheme.textSecondaryFor(context),
            fontWeight: FontWeight.w500,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _SummaryChip(
                label: 'Income',
                value: income,
                color: AppTheme.success,
                icon: Icons.arrow_downward_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryChip(
                label: 'Expenses',
                value: expense,
                color: AppTheme.error,
                icon: Icons.arrow_upward_rounded,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _SummaryChip(
                label: 'Net',
                value: net,
                color: net >= 0 ? AppTheme.primary : AppTheme.error,
                icon: net >= 0
                    ? Icons.trending_up_rounded
                    : Icons.trending_down_rounded,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({
    required this.label,
    required this.value,
    required this.color,
    required this.icon,
  });
  final String label;
  final double value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderFor(context)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 14),
          ),
          const SizedBox(height: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 11,
              color: AppTheme.textSecondaryFor(context),
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 3),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              CurrencyUtils.format(value.abs()),
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: color,
                letterSpacing: -0.3,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Chart Card Wrapper ────────────────────────────────────────────────────────

class _ChartCard extends StatelessWidget {
  const _ChartCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderFor(context)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 18),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryFor(context),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.textSecondaryFor(context),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

// ─── Category Donut Chart ─────────────────────────────────────────────────────

const _kDonutColors = [
  Color(0xFF0B6B68),
  Color(0xFF00C9A7),
  Color(0xFF4F46E5),
  Color(0xFFD97706),
  Color(0xFF0EA5E9),
  Color(0xFF8B5CF6),
  Color(0xFFE5534B),
  Color(0xFF6B7A8D),
];

class _CategoryDonutChart extends StatefulWidget {
  const _CategoryDonutChart({required this.data});
  final Map<String, double> data;

  @override
  State<_CategoryDonutChart> createState() => _CategoryDonutChartState();
}

class _CategoryDonutChartState extends State<_CategoryDonutChart> {
  int _touchedIndex = -1;

  @override
  Widget build(BuildContext context) {
    final entries = widget.data.entries.toList();
    final total = entries.fold<double>(0, (s, e) => s + e.value);

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: Row(
            children: [
              Expanded(
                flex: 5,
                child: PieChart(
                  PieChartData(
                    pieTouchData: PieTouchData(
                      touchCallback: (event, response) {
                        setState(() {
                          if (!event.isInterestedForInteractions ||
                              response == null ||
                              response.touchedSection == null) {
                            _touchedIndex = -1;
                          } else {
                            _touchedIndex = response
                                .touchedSection!.touchedSectionIndex;
                          }
                        });
                      },
                    ),
                    sections: List.generate(entries.length, (i) {
                      final isTouched = i == _touchedIndex;
                      final color =
                          _kDonutColors[i % _kDonutColors.length];
                      final pct = total > 0
                          ? (entries[i].value / total * 100)
                          : 0.0;
                      return PieChartSectionData(
                        value: entries[i].value,
                        color: color,
                        radius: isTouched ? 64 : 55,
                        title: isTouched
                            ? '${pct.toStringAsFixed(0)}%'
                            : '',
                        titleStyle: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w800,
                          color: Colors.white,
                        ),
                      );
                    }),
                    centerSpaceRadius: 44,
                    sectionsSpace: 3,
                  ),
                ),
              ),
              Expanded(
                flex: 4,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: List.generate(entries.length, (i) {
                    final color =
                        _kDonutColors[i % _kDonutColors.length];
                    final pct = total > 0
                        ? (entries[i].value / total * 100)
                        : 0.0;
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: color,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              entries[i].key,
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: AppTheme.textSecondaryFor(context),
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            '${pct.toStringAsFixed(0)}%',
                            style: GoogleFonts.inter(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: color,
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total Spent this Month',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  color: AppTheme.textSecondaryFor(context),
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                CurrencyUtils.format(total),
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Income vs Expense Bar Chart ──────────────────────────────────────────────

class _IncomeExpenseChart extends StatefulWidget {
  const _IncomeExpenseChart({required this.data});
  final List<_MonthData> data;

  @override
  State<_IncomeExpenseChart> createState() => _IncomeExpenseChartState();
}

class _IncomeExpenseChartState extends State<_IncomeExpenseChart> {
  int? _touchedGroupIndex;

  @override
  Widget build(BuildContext context) {
    final allVals = widget.data.expand((d) => [d.income, d.expense]).toList();
    final maxY = allVals.isEmpty
        ? 1000.0
        : allVals.reduce((a, b) => a > b ? a : b);
    final effectiveMax = maxY <= 0 ? 1000.0 : maxY * 1.3;

    return Column(
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: effectiveMax,
              groupsSpace: 16,
              barTouchData: BarTouchData(
                touchCallback: (event, response) {
                  setState(() {
                    _touchedGroupIndex =
                        response?.spot?.touchedBarGroupIndex;
                  });
                },
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => AppTheme.charcoal,
                  getTooltipItem: (group, _, rod, rodIndex) {
                    final label = rodIndex == 0 ? 'Income' : 'Expense';
                    return BarTooltipItem(
                      '$label\nPKR ${_fmtK(rod.toY)}',
                      GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    );
                  },
                ),
              ),
              titlesData: FlTitlesData(
                show: true,
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 28,
                    getTitlesWidget: (value, meta) {
                      final idx = value.toInt();
                      if (idx < 0 || idx >= widget.data.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          widget.data[idx].month.split(' ').first,
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            color: AppTheme.textSecondaryFor(context),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    },
                  ),
                ),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 44,
                    getTitlesWidget: (value, meta) => Text(
                      _fmtK(value),
                      style: GoogleFonts.inter(
                        fontSize: 9,
                        color: AppTheme.textHintFor(context),
                      ),
                    ),
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
                  color: AppTheme.borderFor(context),
                  strokeWidth: 1,
                  dashArray: [4, 4],
                ),
              ),
              borderData: FlBorderData(show: false),
              barGroups: List.generate(widget.data.length, (i) {
                final isTouched = _touchedGroupIndex == i;
                final d = widget.data[i];
                return BarChartGroupData(
                  x: i,
                  groupVertically: false,
                  barRods: [
                    BarChartRodData(
                      toY: d.income,
                      width: isTouched ? 13 : 10,
                      color: AppTheme.secondary,
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                    ),
                    BarChartRodData(
                      toY: d.expense,
                      width: isTouched ? 13 : 10,
                      color: const Color(0xFFFF8080),
                      borderRadius: const BorderRadius.vertical(
                        top: Radius.circular(5),
                      ),
                    ),
                  ],
                  barsSpace: 4,
                );
              }),
            ),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeInOut,
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _Legend(color: AppTheme.secondary, label: 'Income'),
            const SizedBox(width: 20),
            _Legend(color: Color(0xFFFF8080), label: 'Expenses'),
          ],
        ),
      ],
    );
  }

  String _fmtK(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
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
            fontSize: 12,
            color: AppTheme.textSecondaryFor(context),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

// ─── Weekly Bar Chart ──────────────────────────────────────────────────────────

class _WeeklyBarChart extends StatefulWidget {
  const _WeeklyBarChart({required this.trends});
  final Map<String, double> trends;

  @override
  State<_WeeklyBarChart> createState() => _WeeklyBarChartState();
}

class _WeeklyBarChartState extends State<_WeeklyBarChart> {
  int? _touchedIndex;

  @override
  Widget build(BuildContext context) {
    final entries = widget.trends.entries.toList();
    final maxVal = entries.isEmpty
        ? 100.0
        : entries.map((e) => e.value).reduce((a, b) => a > b ? a : b);

    return SizedBox(
      height: 200,
      child: BarChart(
        BarChartData(
          maxY: maxVal <= 0 ? 100 : maxVal * 1.3,
          barTouchData: BarTouchData(
            touchCallback: (event, response) {
              setState(() {
                _touchedIndex = response?.spot?.touchedBarGroupIndex;
              });
            },
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppTheme.charcoal,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                return BarTooltipItem(
                  'PKR ${_fmtK(rod.toY)}',
                  GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                );
              },
            ),
          ),
          titlesData: FlTitlesData(
            show: true,
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 44,
                getTitlesWidget: (value, meta) => Text(
                  _fmtK(value),
                  style: GoogleFonts.inter(
                    fontSize: 9,
                    color: AppTheme.textHintFor(context),
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 28,
                getTitlesWidget: (value, meta) {
                  final idx = value.toInt();
                  if (idx < 0 || idx >= entries.length) {
                    return const SizedBox.shrink();
                  }
                  final label = entries[idx].key.replaceFirst('Week of ', '');
                  return Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 8,
                        color: AppTheme.textHintFor(context),
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
              color: AppTheme.borderFor(context),
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(entries.length, (i) {
            final isTouched = _touchedIndex == i;
            return BarChartGroupData(
              x: i,
              barRods: [
                BarChartRodData(
                  toY: entries[i].value,
                  width: isTouched ? 16 : 12,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(5),
                  ),
                  gradient: LinearGradient(
                    colors: isTouched
                        ? [AppTheme.secondary, AppTheme.primary]
                        : [
                            AppTheme.secondary.withValues(alpha: 0.7),
                            AppTheme.primary.withValues(alpha: 0.8),
                          ],
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                  ),
                ),
              ],
            );
          }),
        ),
        duration: const Duration(milliseconds: 600),
        curve: Curves.easeInOut,
      ),
    );
  }

  String _fmtK(double v) {
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(0)}k';
    return v.toStringAsFixed(0);
  }
}

// ─── Analytics Section Header ─────────────────────────────────────────────────

class _AnalyticsSectionHeader extends StatelessWidget {
  const _AnalyticsSectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.iconColor = AppTheme.primary,
  });
  final IconData icon;
  final String title;
  final String subtitle;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: iconColor.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: iconColor, size: 18),
        ),
        const SizedBox(width: 12),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.textPrimaryFor(context),
              ),
            ),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                fontSize: 11,
                color: AppTheme.textSecondaryFor(context),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ─── Anomaly Card ──────────────────────────────────────────────────────────────

class _AnomalyCard extends StatelessWidget {
  const _AnomalyCard({required this.anomaly});
  final SpendingAnomaly anomaly;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppTheme.warning.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppTheme.warning.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.warning_amber_rounded,
              color: AppTheme.warning,
              size: 18,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      anomaly.category,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryFor(context),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.warning,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '+${anomaly.percentageIncrease.toStringAsFixed(0)}%',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  anomaly.message,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: AppTheme.textSecondaryFor(context),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Recurring Expense Card ───────────────────────────────────────────────────

class _RecurringCard extends StatelessWidget {
  const _RecurringCard({required this.expense});
  final RecurringExpense expense;

  @override
  Widget build(BuildContext context) {
    final d = expense.lastDetectedDate;
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateStr = '${d.day} ${months[d.month - 1]} ${d.year}';

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderFor(context)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              Icons.repeat_rounded,
              color: AppTheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  expense.name,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.textPrimaryFor(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${expense.category} · Last: $dateStr',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: AppTheme.textSecondaryFor(context),
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'PKR ${_fmtNum(expense.estimatedMonthlyAmount)}',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              Text(
                '/month',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: AppTheme.textHintFor(context),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _fmtNum(double v) => v
      .toStringAsFixed(0)
      .replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
}

// ─── Empty State ──────────────────────────────────────────────────────────────

class _AnalyticsEmptyState extends StatelessWidget {
  const _AnalyticsEmptyState({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 28),
      alignment: Alignment.center,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.borderFor(context),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 28, color: AppTheme.textHintFor(context)),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textHintFor(context),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
