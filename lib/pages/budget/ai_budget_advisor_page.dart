import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/budget_plan.dart';
import '../../models/saving_goal.dart';
import '../../models/transaction.dart';
import '../../app_constants.dart';
import '../../models/app_config.dart';
import '../../services/app_config_service.dart';
import '../../services/ai_service.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';

class AIBudgetAdvisorPage extends StatefulWidget {
  const AIBudgetAdvisorPage({super.key});

  @override
  State<AIBudgetAdvisorPage> createState() => _AIBudgetAdvisorPageState();
}

class _AIBudgetAdvisorPageState extends State<AIBudgetAdvisorPage> {
  final AIService _aiService = AIService();

  String get _monthKey {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.watch<AuthService>().firestoreService;

    if (firestoreService == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: StreamBuilder<List<FinancialTransaction>>(
        stream: firestoreService.getTransactions(),
        builder: (context, transactionSnapshot) {
          final transactions =
              transactionSnapshot.data ?? const <FinancialTransaction>[];
          final monthlyTransactions = transactions
              .where((txn) => _sameMonth(txn.date, DateTime.now()))
              .toList();

          return StreamBuilder<List<SavingGoal>>(
            stream: firestoreService.getSavingGoals(),
            builder: (context, goalsSnapshot) {
              final goals = goalsSnapshot.data ?? const <SavingGoal>[];

              return StreamBuilder<List<BudgetPlan>>(
                stream: firestoreService.getBudgetPlans(monthKey: _monthKey),
                builder: (context, budgetSnapshot) {
                  final budgets = budgetSnapshot.data ?? const <BudgetPlan>[];
                  final analytics = _BudgetAnalytics.from(
                    budgets,
                    monthlyTransactions,
                    goals,
                  );

                  return SafeArea(
                    child: CustomScrollView(
                      physics: const BouncingScrollPhysics(),
                      slivers: [
                        SliverToBoxAdapter(
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    GestureDetector(
                                      onTap: () => Navigator.pop(context),
                                      child: Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: Colors.white.withValues(
                                            alpha: 0.12,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.white.withValues(
                                              alpha: 0.2,
                                            ),
                                          ),
                                        ),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.arrow_back_ios_new_rounded,
                                            size: 18,
                                          ),
                                          color: Colors.white,
                                          onPressed: () =>
                                              Navigator.pop(context),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),
                                    Text(
                                      'AI Budget Advisor',
                                      style: GoogleFonts.plusJakartaSans(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w800,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  'Create your own budgets, track actual spending, and get AI recommendations in PKR.',
                                  style: GoogleFonts.inter(
                                    color: Colors.white.withValues(alpha: 0.72),
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        SliverPadding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
                          sliver: SliverList(
                            delegate: SliverChildListDelegate([
                              _SummaryCard(analytics: analytics),
                              const SizedBox(height: 24),
                              _SectionTitle(
                                title: 'This Month\'s Budget Plans',
                                action: TextButton.icon(
                                  onPressed: () => _showBudgetEditor(
                                    context,
                                    firestoreService,
                                    budgets: budgets,
                                  ),
                                  icon: const Icon(Icons.add_rounded),
                                  label: const Text('Add Budget'),
                                ),
                              ),
                              const SizedBox(height: 14),
                              if (budgets.isEmpty)
                                _EmptyBudgetState(
                                  onCreate: () => _showBudgetEditor(
                                    context,
                                    firestoreService,
                                    budgets: budgets,
                                  ),
                                )
                              else
                                ...budgets.map(
                                  (budget) => Padding(
                                    padding: const EdgeInsets.only(bottom: 12),
                                    child: _BudgetPlanCard(
                                      budget: budget,
                                      spent: analytics.spentForCategory(
                                        budget.category,
                                      ),
                                      onEdit: () => _showBudgetEditor(
                                        context,
                                        firestoreService,
                                        budgets: budgets,
                                      ),
                                      onDelete: () => firestoreService
                                          .deleteBudgetPlan(budget.id),
                                    ),
                                  ),
                                ),
                              const SizedBox(height: 24),
                              const _SectionTitle(title: 'AI Recommendations'),
                              const SizedBox(height: 14),
                              StreamBuilder<AppConfig>(
                                stream: AppConfigService().watchConfig(),
                                initialData: AppConfig.defaults(),
                                builder: (context, configSnapshot) {
                                  final config =
                                      configSnapshot.data ??
                                      AppConfig.defaults();
                                  if (!config.budgetAiEnabled) {
                                    return Column(
                                      children: [
                                        _InsightCard(
                                          title: 'Budget Plan Coach',
                                          body:
                                              'AI budget recommendations are paused by FinEase admin. You can still create and edit budgets manually.',
                                          icon: Icons.pause_circle_rounded,
                                          color: const Color(0xFF22D3EE),
                                        ),
                                        const SizedBox(height: 12),
                                        _InsightCard(
                                          title: 'Spending Pattern Insights',
                                          body: config.supportMessage,
                                          icon: Icons.insights_rounded,
                                          color: const Color(0xFF818CF8),
                                        ),
                                      ],
                                    );
                                  }

                                  return Column(
                                    children: [
                                      FutureBuilder<String>(
                                        future: _aiService
                                            .getBudgetPlanRecommendations(
                                              budgets,
                                              monthlyTransactions,
                                            ),
                                        builder: (context, snapshot) {
                                          final body = snapshot.hasError
                                              ? 'AI is not running yet: ${snapshot.error}'
                                              : snapshot.data ??
                                                    'Generating budget plan recommendations...';
                                          return _InsightCard(
                                            title: 'Budget Plan Coach',
                                            body: body,
                                            icon: Icons.auto_awesome_rounded,
                                            color: const Color(0xFF22D3EE),
                                          );
                                        },
                                      ),
                                      const SizedBox(height: 12),
                                      FutureBuilder<String>(
                                        future: _aiService.getBudgetAdvice(
                                          monthlyTransactions,
                                        ),
                                        builder: (context, snapshot) {
                                          final body = snapshot.hasError
                                              ? 'AI is not running yet: ${snapshot.error}'
                                              : snapshot.data ??
                                                    'Analyzing your transaction patterns...';
                                          return _InsightCard(
                                            title: 'Spending Pattern Insights',
                                            body: body,
                                            icon: Icons.insights_rounded,
                                            color: const Color(0xFF818CF8),
                                          );
                                        },
                                      ),
                                    ],
                                  );
                                },
                              ),
                              const SizedBox(height: 24),
                              const _SectionTitle(title: 'Budget Health'),
                              const SizedBox(height: 14),
                              Wrap(
                                spacing: 12,
                                runSpacing: 12,
                                children: [
                                  _MetricCard(
                                    title: 'Budgeted',
                                    value: CurrencyUtils.format(
                                      analytics.totalBudgeted,
                                    ),
                                    subtitle: 'Current month allocation',
                                    color: const Color(0xFF22C55E),
                                  ),
                                  _MetricCard(
                                    title: 'Spent',
                                    value: CurrencyUtils.format(
                                      analytics.totalSpent,
                                    ),
                                    subtitle: 'Current month expenses',
                                    color: const Color(0xFFF97316),
                                  ),
                                  _MetricCard(
                                    title: 'Remaining',
                                    value: CurrencyUtils.format(
                                      analytics.remainingBudget,
                                    ),
                                    subtitle: 'Still available',
                                    color: const Color(0xFF38BDF8),
                                  ),
                                  _MetricCard(
                                    title: 'Savings Rate',
                                    value:
                                        '${analytics.savingsRate.toStringAsFixed(0)}%',
                                    subtitle: 'Based on monthly income',
                                    color: const Color(0xFFFACC15),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 24),
                              const _SectionTitle(title: 'Category Breakdown'),
                              const SizedBox(height: 14),
                              _DistributionCard(analytics: analytics),
                              const SizedBox(height: 24),
                              const _SectionTitle(title: 'Goal Alignment'),
                              const SizedBox(height: 14),
                              ...goals
                                  .take(3)
                                  .map(
                                    (goal) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 12,
                                      ),
                                      child: _GoalTile(goal: goal),
                                    ),
                                  ),
                            ]),
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
    );
  }

  bool _sameMonth(DateTime first, DateTime second) {
    return first.year == second.year && first.month == second.month;
  }

  void _showBudgetEditor(
    BuildContext context,
    FirestoreService firestoreService, {
    required List<BudgetPlan> budgets,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryBudgetManagerSheet(
        firestoreService: firestoreService,
        budgets: budgets,
        monthKey: _monthKey,
      ),
    );
  }
}

class _BudgetAnalytics {
  _BudgetAnalytics({
    required this.budgets,
    required this.transactions,
    required this.goals,
    required this.totalBudgeted,
    required this.totalSpent,
    required this.totalIncome,
    required this.categorySpend,
  });

  final List<BudgetPlan> budgets;
  final List<FinancialTransaction> transactions;
  final List<SavingGoal> goals;
  final double totalBudgeted;
  final double totalSpent;
  final double totalIncome;
  final Map<String, double> categorySpend;

  factory _BudgetAnalytics.from(
    List<BudgetPlan> budgets,
    List<FinancialTransaction> transactions,
    List<SavingGoal> goals,
  ) {
    final totalBudgeted = budgets.fold<double>(
      0,
      (sum, budget) => sum + budget.allocatedAmount,
    );
    final totalSpent = transactions
        .where((txn) => txn.type == 'expense')
        .fold<double>(0, (sum, txn) => sum + txn.amount);
    final totalIncome = transactions
        .where((txn) => txn.type == 'income')
        .fold<double>(0, (sum, txn) => sum + txn.amount);
    final categorySpend = <String, double>{};
    for (final txn in transactions.where((txn) => txn.type == 'expense')) {
      categorySpend[txn.category] =
          (categorySpend[txn.category] ?? 0) + txn.amount;
    }

    return _BudgetAnalytics(
      budgets: budgets,
      transactions: transactions,
      goals: goals,
      totalBudgeted: totalBudgeted,
      totalSpent: totalSpent,
      totalIncome: totalIncome,
      categorySpend: categorySpend,
    );
  }

  double get remainingBudget => totalBudgeted - totalSpent;
  double get spendingRatio =>
      totalBudgeted == 0 ? 0 : (totalSpent / totalBudgeted).clamp(0.0, 2.0);
  double get savingsRate {
    if (totalIncome <= 0) {
      return 0;
    }
    final saved = totalIncome - totalSpent;
    return ((saved > 0 ? saved : 0) / totalIncome) * 100;
  }

  double spentForCategory(String category) => categorySpend[category] ?? 0;

  List<MapEntry<String, double>> get topCategories {
    final entries = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.analytics});

  final _BudgetAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2563EB), Color(0xFF22D3EE)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available to allocate',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyUtils.format(analytics.remainingBudget),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: analytics.spendingRatio.clamp(0.0, 1.0),
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.22),
              color: const Color(0xFF0F172A),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryStat(
                label: 'Budgeted',
                value: CurrencyUtils.format(analytics.totalBudgeted),
              ),
              _SummaryStat(
                label: 'Spent',
                value: CurrencyUtils.format(analytics.totalSpent),
              ),
              _SummaryStat(
                label: 'Income',
                value: CurrencyUtils.format(analytics.totalIncome),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.action});

  final String title;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        action ?? const SizedBox.shrink(),
      ],
    );
  }
}

class _BudgetPlanCard extends StatelessWidget {
  const _BudgetPlanCard({
    required this.budget,
    required this.spent,
    required this.onEdit,
    required this.onDelete,
  });

  final BudgetPlan budget;
  final double spent;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final remaining = budget.allocatedAmount - spent;
    final progress = budget.allocatedAmount == 0
        ? 0.0
        : (spent / budget.allocatedAmount).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      budget.title,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      budget.category,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.65),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined, color: Colors.white),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(
                  Icons.delete_outline_rounded,
                  color: Colors.red,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (budget.notes.isNotEmpty)
            Text(
              budget.notes,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.72),
                height: 1.5,
              ),
            ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.1),
              color: remaining < 0 ? Colors.redAccent : const Color(0xFF22D3EE),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _BudgetFigure(
                  label: 'Allocated',
                  value: CurrencyUtils.format(budget.allocatedAmount),
                ),
              ),
              Expanded(
                child: _BudgetFigure(
                  label: 'Spent',
                  value: CurrencyUtils.format(spent),
                ),
              ),
              Expanded(
                child: _BudgetFigure(
                  label: 'Remaining',
                  value: CurrencyUtils.format(remaining),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BudgetFigure extends StatelessWidget {
  const _BudgetFigure({required this.label, required this.value});

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
            color: Colors.white.withValues(alpha: 0.6),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.title,
    required this.body,
    required this.icon,
    required this.color,
  });

  final String title;
  final String body;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  body,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.76),
                    height: 1.55,
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

class _DistributionCard extends StatelessWidget {
  const _DistributionCard({required this.analytics});

  final _BudgetAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final categories = analytics.topCategories;
    final colors = [
      const Color(0xFF38BDF8),
      const Color(0xFF818CF8),
      const Color(0xFF34D399),
      const Color(0xFFF59E0B),
      const Color(0xFFFB7185),
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: categories.isEmpty
          ? Text(
              'Add transactions to see your category breakdown.',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.72),
              ),
            )
          : Column(
              children: [
                SizedBox(
                  height: 220,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 56,
                      sectionsSpace: 3,
                      sections: List.generate(categories.length, (index) {
                        final value = categories[index].value;
                        return PieChartSectionData(
                          value: value,
                          color: colors[index % colors.length],
                          radius: 18,
                          showTitle: false,
                        );
                      }),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                ...List.generate(categories.length, (index) {
                  final entry = categories[index];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Container(
                          width: 10,
                          height: 10,
                          decoration: BoxDecoration(
                            color: colors[index % colors.length],
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            entry.key,
                            style: GoogleFonts.inter(
                              color: Colors.white.withValues(alpha: 0.82),
                            ),
                          ),
                        ),
                        Text(
                          CurrencyUtils.format(entry.value),
                          style: GoogleFonts.plusJakartaSans(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
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
}

class _MetricCard extends StatelessWidget {
  const _MetricCard({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String value;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 165,
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.64),
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: color,
                fontSize: 22,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.56),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal});

  final SavingGoal goal;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${(goal.progress * 100).round()}%',
                style: GoogleFonts.inter(
                  color: const Color(0xFF22D3EE),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 8,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: const Color(0xFF22D3EE),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '${CurrencyUtils.format(goal.currentAmount)} of ${CurrencyUtils.format(goal.targetAmount)} saved, ${goal.daysLeft} days left.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.label, required this.value});

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
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w800,
          ),
        ),
      ],
    );
  }
}

class _EmptyBudgetState extends StatelessWidget {
  const _EmptyBudgetState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 14),
          Text(
            'Create monthly budgets for categories like food, transport, housing, and savings.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.74),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: onCreate,
            child: const Text('Create First Budget'),
          ),
        ],
      ),
    );
  }
}

class _CategoryBudgetManagerSheet extends StatefulWidget {
  const _CategoryBudgetManagerSheet({
    required this.firestoreService,
    required this.monthKey,
    required this.budgets,
  });

  final FirestoreService firestoreService;
  final String monthKey;
  final List<BudgetPlan> budgets;

  @override
  State<_CategoryBudgetManagerSheet> createState() =>
      _CategoryBudgetManagerSheetState();
}

class _CategoryBudgetManagerSheetState
    extends State<_CategoryBudgetManagerSheet> {
  final _inputs = <String, _CategoryBudgetInput>{};
  final _incomeController = TextEditingController();
  bool _incomeSeeded = false;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    for (final category in AppConstants.budgetCategories) {
      final existing = widget.budgets
          .where((budget) => budget.category == category)
          .cast<BudgetPlan?>()
          .firstWhere((budget) => budget != null, orElse: () => null);
      _inputs[category] = _CategoryBudgetInput(existing);
    }
  }

  @override
  void dispose() {
    _incomeController.dispose();
    for (final input in _inputs.values) {
      input.dispose();
    }
    super.dispose();
  }

  double _totalAmount(double monthlyIncome) {
    return _inputs.values.fold<double>(
      0,
      (total, input) => total + input.amount(monthlyIncome),
    );
  }

  double _totalPercent() {
    return _inputs.values.fold<double>(
      0,
      (total, input) => total + input.percent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return FutureBuilder<double>(
      future: widget.firestoreService.monthlyIncomeForCurrentMonth(),
      builder: (context, snapshot) {
        if (!_incomeSeeded && snapshot.hasData) {
          _incomeController.text = snapshot.data == null || snapshot.data == 0
              ? ''
              : snapshot.data!.toStringAsFixed(0);
          _incomeSeeded = true;
        }
        final monthlyIncome =
            double.tryParse(_incomeController.text.trim()) ??
            snapshot.data ??
            0;
        final totalAmount = _totalAmount(monthlyIncome);
        final totalPercent = _totalPercent();
        final remaining = monthlyIncome - totalAmount;
        final hasIncome = monthlyIncome > 0;
        final hasError = !hasIncome || totalPercent > 100 || remaining < 0;

        return Container(
          padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: AppTheme.border,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Category Budgeting',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Allocate monthly income manually or by percentage. Totals update instantly.',
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                      height: 1.4,
                    ),
                  ),
                  const SizedBox(height: 16),
                  _BudgetTotalsPanel(
                    monthlyIncome: monthlyIncome,
                    totalAmount: totalAmount,
                    totalPercent: totalPercent,
                    remaining: remaining,
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _incomeController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Monthly salary / income',
                      prefixText: 'PKR ',
                    ),
                  ),
                  if (hasError) ...[
                    const SizedBox(height: 12),
                    _ValidationBanner(
                      message: !hasIncome
                          ? 'Add monthly income first. Budget percentages are calculated only from monthly income.'
                          : totalPercent > 100
                          ? 'Total percentage cannot exceed 100%.'
                          : 'Allocated budget cannot exceed monthly income.',
                    ),
                  ],
                  const SizedBox(height: 16),
                  ...AppConstants.budgetCategories.map(
                    (category) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CategoryBudgetRow(
                        category: category,
                        input: _inputs[category]!,
                        monthlyIncome: monthlyIncome,
                        onChanged: () => setState(() {}),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _saving || hasError
                          ? null
                          : () => _save(monthlyIncome: monthlyIncome),
                      child: Text(
                        _saving ? 'Saving...' : 'Save Category Budgets',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _save({
    required double monthlyIncome,
    bool allowSavingsAdjustment = false,
  }) async {
    final totalAmount = _totalAmount(monthlyIncome);
    final totalPercent = _totalPercent();
    if (monthlyIncome <= 0) {
      _showError('Monthly income is required before creating budgets.');
      return;
    }
    if (totalPercent > 100) {
      _showError('Total budget percentage cannot exceed 100%.');
      return;
    }
    if (totalAmount > monthlyIncome) {
      _showError('Total allocated budget cannot exceed monthly income.');
      return;
    }

    setState(() => _saving = true);
    try {
      await widget.firestoreService.saveUserProfile({
        'monthlyIncome': monthlyIncome,
      });
      final existingByCategory = {
        for (final budget in widget.budgets) budget.category: budget,
      };

      for (final category in AppConstants.budgetCategories) {
        final input = _inputs[category]!;
        final amount = input.amount(monthlyIncome);
        final existing = existingByCategory[category];
        if (amount <= 0) {
          if (existing != null) {
            await widget.firestoreService.deleteBudgetPlan(existing.id);
          }
          continue;
        }

        final data = {
          'title': category,
          'category': category,
          'allocatedAmount': amount,
          'allocationMode': input.mode,
          'allocationPercent': input.mode == 'percent' ? input.percent : null,
          'notes': input.mode == 'percent'
              ? '${input.percent.toStringAsFixed(2)}% of monthly income'
              : 'Manual category allocation',
          'monthKey': widget.monthKey,
        };

        if (existing == null) {
          await widget.firestoreService.addBudgetPlan(
            BudgetPlan(
              id: '',
              title: category,
              category: category,
              allocatedAmount: amount,
              notes: data['notes'] as String,
              monthKey: widget.monthKey,
              createdAt: DateTime.now(),
              allocationMode: input.mode,
              allocationPercent: input.mode == 'percent' ? input.percent : null,
            ),
            allowSavingsAdjustment: allowSavingsAdjustment,
          );
        } else {
          await widget.firestoreService.updateBudgetPlan(
            existing.id,
            data,
            allowSavingsAdjustment: allowSavingsAdjustment,
          );
        }
      }

      if (!mounted) return;
      Navigator.pop(context);
    } on SavingsUsageRequiredException catch (error) {
      if (!mounted) return;
      final approved = await _confirmSavingsUse(error.requiredAmount);
      if (approved == true) {
        await _save(monthlyIncome: monthlyIncome, allowSavingsAdjustment: true);
      } else if (mounted) {
        setState(() => _saving = false);
      }
    } on FinanceValidationException catch (error) {
      if (mounted) {
        _showError(error.message);
        setState(() => _saving = false);
      }
    } catch (_) {
      if (mounted) {
        _showError('Could not save budgets. Please check your connection.');
        setState(() => _saving = false);
      }
    }
  }

  Future<bool?> _confirmSavingsUse(double amount) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use savings for allocation?'),
        content: Text(
          'This budget increase needs PKR ${amount.toStringAsFixed(0)} from savings. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Use Savings'),
          ),
        ],
      ),
    );
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }
}

class _CategoryBudgetInput {
  _CategoryBudgetInput(BudgetPlan? budget)
    : mode = budget?.allocationMode ?? 'manual',
      amountController = TextEditingController(
        text: budget == null || budget.allocatedAmount == 0
            ? ''
            : budget.allocatedAmount.toStringAsFixed(0),
      ),
      percentController = TextEditingController(
        text: budget?.allocationPercent == null
            ? ''
            : budget!.allocationPercent!.toStringAsFixed(2),
      );

  String mode;
  final TextEditingController amountController;
  final TextEditingController percentController;

  double get percent {
    final value = double.tryParse(percentController.text.trim()) ?? 0;
    return value.isFinite && value > 0 ? value : 0;
  }

  double amount(double monthlyIncome) {
    if (mode == 'percent') {
      if (monthlyIncome <= 0) return 0;
      return monthlyIncome * (percent / 100);
    }
    final value = double.tryParse(amountController.text.trim()) ?? 0;
    return value.isFinite && value > 0 ? value : 0;
  }

  void dispose() {
    amountController.dispose();
    percentController.dispose();
  }
}

class _BudgetTotalsPanel extends StatelessWidget {
  const _BudgetTotalsPanel({
    required this.monthlyIncome,
    required this.totalAmount,
    required this.totalPercent,
    required this.remaining,
  });

  final double monthlyIncome;
  final double totalAmount;
  final double totalPercent;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          _totalRow('Monthly income', CurrencyUtils.format(monthlyIncome)),
          _totalRow('Allocated', CurrencyUtils.format(totalAmount)),
          _totalRow('Percent used', '${totalPercent.toStringAsFixed(1)}%'),
          _totalRow(
            'Remaining salary',
            CurrencyUtils.format(remaining),
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: highlight ? AppTheme.primary : AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ValidationBanner extends StatelessWidget {
  const _ValidationBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF1F2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Text(
        message,
        style: GoogleFonts.inter(
          color: const Color(0xFFBE123C),
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _CategoryBudgetRow extends StatelessWidget {
  const _CategoryBudgetRow({
    required this.category,
    required this.input,
    required this.monthlyIncome,
    required this.onChanged,
  });

  final String category;
  final _CategoryBudgetInput input;
  final double monthlyIncome;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final calculatedAmount = input.amount(monthlyIncome);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
              ),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'manual', label: Text('Amount')),
                  ButtonSegment(value: 'percent', label: Text('%')),
                ],
                selected: {input.mode},
                onSelectionChanged: (value) {
                  input.mode = value.first;
                  onChanged();
                },
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (input.mode == 'manual')
            TextField(
              controller: input.amountController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                labelText: 'Manual amount',
                prefixText: 'PKR ',
              ),
            )
          else
            TextField(
              controller: input.percentController,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged: (_) => onChanged(),
              decoration: const InputDecoration(
                labelText: 'Salary percentage',
                suffixText: '%',
              ),
            ),
          const SizedBox(height: 8),
          Text(
            'Calculated budget: ${CurrencyUtils.format(calculatedAmount)}',
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
