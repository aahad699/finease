import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/transaction.dart';
import '../../models/prediction_models.dart';
import '../../services/prediction_service.dart';
import '../pages/forecast/forecast_screen.dart';
import '../theme/app_theme.dart';

/// A home-screen card showing next-month predicted spending,
/// per-category progress bars, and a red warning banner if any
/// budget is projected to be exceeded.
class PredictionCard extends StatelessWidget {
  final List<FinancialTransaction> transactions;

  /// Optional budget map {category → budget amount}. If null, progress bars
  /// compare against predicted spend only (no overshoot detection).
  final Map<String, double>? budgets;

  /// Monthly income used for savings forecast; if null savings row is hidden.
  final double? monthlyIncome;

  const PredictionCard({
    super.key,
    required this.transactions,
    this.budgets,
    this.monthlyIncome,
  });

  static const _primary = Color(0xFF2E3192);
  static const _success = Color(0xFF059669);
  static const _danger = Color(0xFFDC2626);
  static const _warning = Color(0xFFF59E0B);

  @override
  Widget build(BuildContext context) {
    final svc = PredictionService();
    final forecast = svc.predictNextMonthExpenses(transactions);
    final predictions = forecast.categoryPredictions;
    final total = forecast.totalPredicted;

    // Savings forecast
    ForecastResult? savingsForecast;
    if (monthlyIncome != null && monthlyIncome! > 0) {
      savingsForecast = svc.forecastSavings(monthlyIncome!, predictions);
    }

    // Budget warnings
    final warnings = budgets != null
        ? svc.getBudgetWarnings(
            transactions
                .where(
                  (t) =>
                      t.date.year == DateTime.now().year &&
                      t.date.month == DateTime.now().month,
                )
                .toList(),
            budgets!,
          )
        : <BudgetWarning>[];

    final hasWarnings = warnings.isNotEmpty;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ForecastScreen(
            transactions: transactions,
            budgets: budgets ?? {},
            monthlyIncome: monthlyIncome ?? 0,
          ),
        ),
      ),
      child: Container(
        margin: const EdgeInsets.fromLTRB(20, 0, 20, 0),
        decoration: BoxDecoration(
          color: AppTheme.surfaceFor(context),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: hasWarnings
                ? _danger.withValues(alpha: 0.3)
                : _primary.withValues(alpha: 0.12),
            width: 1.5,
          ),
          boxShadow: [
            BoxShadow(
              color: _primary.withValues(alpha: 0.07),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Header ──────────────────────────────────────────────────
            _buildHeader(total, hasWarnings),

            // ── Warning banner ───────────────────────────────────────────
            if (hasWarnings) _buildWarningBanner(warnings.first),

            // ── Savings highlight ────────────────────────────────────────
            if (savingsForecast != null) _buildSavingsRow(savingsForecast),

            // ── Category progress bars ───────────────────────────────────
            if (predictions.isNotEmpty)
              _buildCategoryBars(predictions, budgets),

            // ── Tap hint ─────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    'View full forecast',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: _primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 12,
                    color: _primary,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Sub-widgets ────────────────────────────────────────────────────────────

  Widget _buildHeader(double total, bool hasWarnings) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: hasWarnings
              ? [const Color(0xFFFEF2F2), const Color(0xFFFFF7ED)]
              : [const Color(0xFFEEF2FF), const Color(0xFFF5F3FF)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: hasWarnings
                  ? _danger.withValues(alpha: 0.12)
                  : _primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              hasWarnings
                  ? Icons.trending_up_rounded
                  : Icons.auto_graph_rounded,
              color: hasWarnings ? _danger : _primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Next Month Estimate',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: const Color(0xFF64748B),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'PKR ${PredictionService.fmt(total)}',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: hasWarnings ? _danger : _primary,
                    letterSpacing: -0.5,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(
              color: hasWarnings
                  ? _warning.withValues(alpha: 0.15)
                  : _primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.science_rounded,
                  size: 11,
                  color: hasWarnings ? _warning : _primary,
                ),
                const SizedBox(width: 4),
                Text(
                  'AI Forecast',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    color: hasWarnings ? _warning : _primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWarningBanner(BudgetWarning w) {
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 0),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: _danger.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _danger.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.warning_amber_rounded, color: _danger, size: 16),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              w.message,
              style: GoogleFonts.inter(
                fontSize: 11.5,
                color: _danger,
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSavingsRow(ForecastResult f) {
    final isPositive = f.predictedSavings >= 0;
    final color = isPositive ? _success : _danger;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isPositive ? Icons.savings_rounded : Icons.trending_down_rounded,
              color: color,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Text(
            'Projected Savings',
            style: GoogleFonts.inter(
              fontSize: 13,
              color: const Color(0xFF475569),
              fontWeight: FontWeight.w500,
            ),
          ),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${isPositive ? '+' : ''}PKR ${PredictionService.fmt(f.predictedSavings.abs())}',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
              Text(
                '${f.savingsPercentage.toStringAsFixed(1)}% of income',
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: color.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryBars(
    Map<String, double> predictions,
    Map<String, double>? budgets,
  ) {
    final sorted = predictions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sorted.take(4).toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Column(
        children: topCategories.map((e) {
          final category = e.key;
          final predicted = e.value;
          final budget = budgets?[category];
          final ratio = budget != null && budget > 0
              ? (predicted / budget).clamp(0.0, 1.5)
              : null;
          final isOver = ratio != null && ratio > 1.0;
          final barColor = isOver ? _danger : _primary;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        _CategoryDot(color: _categoryColor(category)),
                        const SizedBox(width: 6),
                        Text(
                          category,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF374151),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (isOver) ...[
                          const SizedBox(width: 5),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 5,
                              vertical: 1,
                            ),
                            decoration: BoxDecoration(
                              color: _danger.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              'OVER',
                              style: GoogleFonts.inter(
                                fontSize: 8,
                                fontWeight: FontWeight.w800,
                                color: _danger,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          'PKR ${PredictionService.fmt(predicted)}',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: barColor,
                          ),
                        ),
                        if (budget != null)
                          Text(
                            'Budget: PKR ${PredictionService.fmt(budget)}',
                            style: GoogleFonts.inter(
                              fontSize: 9,
                              color: const Color(0xFF94A3B8),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                if (ratio != null)
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      minHeight: 6,
                      backgroundColor: barColor.withValues(alpha: 0.10),
                      valueColor: AlwaysStoppedAnimation<Color>(barColor),
                    ),
                  )
                else
                  // Show relative bar compared to max in top categories
                  Builder(
                    builder: (context) {
                      final maxVal = topCategories
                          .map((e) => e.value)
                          .reduce((a, b) => a > b ? a : b);
                      final relRatio = maxVal > 0
                          ? (predicted / maxVal).clamp(0.0, 1.0)
                          : 0.0;
                      return ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: relRatio,
                          minHeight: 6,
                          backgroundColor: barColor.withValues(alpha: 0.10),
                          valueColor: AlwaysStoppedAnimation<Color>(barColor),
                        ),
                      );
                    },
                  ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }

  Color _categoryColor(String cat) {
    final map = {
      'Groceries': const Color(0xFFEF4444),
      'Transport': const Color(0xFF3B82F6),
      'Healthcare': const Color(0xFF10B981),
      'Entertainment': const Color(0xFFF59E0B),
      'Education': const Color(0xFF06B6D4),
      'Electricity': const Color(0xFF6366F1),
      'Savings': const Color(0xFF14B8A6),
      'Others': const Color(0xFF94A3B8),
    };
    return map[cat] ?? const Color(0xFF2E3192);
  }
}

class _CategoryDot extends StatelessWidget {
  final Color color;
  const _CategoryDot({required this.color});

  @override
  Widget build(BuildContext context) => Container(
    width: 8,
    height: 8,
    decoration: BoxDecoration(color: color, shape: BoxShape.circle),
  );
}
