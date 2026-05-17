import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_constants.dart';
import '../../models/budget_plan.dart';
import '../../models/saving_goal.dart';
import '../../models/transaction.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';

enum _PeriodMode { daily, weekly, monthly, yearly }

class AIBudgetAdvisorPage extends StatefulWidget {
  const AIBudgetAdvisorPage({super.key});

  @override
  State<AIBudgetAdvisorPage> createState() => _AIBudgetAdvisorPageState();
}

class _AIBudgetAdvisorPageState extends State<AIBudgetAdvisorPage> {
  _PeriodMode _periodMode = _PeriodMode.monthly;
  DateTime _anchorDate = DateTime.now();
  final Set<String> _carryForwardChecks = {};

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.watch<AuthService>().firestoreService;

    if (firestoreService == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final period = _BudgetPeriod.from(_periodMode, _anchorDate);
    _scheduleCarryForward(context, firestoreService, period);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<List<FinancialTransaction>>(
        stream: firestoreService.getTransactions(),
        builder: (context, transactionSnapshot) {
          final transactions =
              transactionSnapshot.data ?? const <FinancialTransaction>[];
          final periodTransactions = transactions
              .where((txn) => period.contains(txn.date))
              .toList();

          return StreamBuilder<List<SavingGoal>>(
            stream: firestoreService.getSavingGoals(),
            builder: (context, goalsSnapshot) {
              final goals = goalsSnapshot.data ?? const <SavingGoal>[];

              return StreamBuilder<Map<String, dynamic>>(
                stream: firestoreService.getUserProfile(),
                builder: (context, profileSnapshot) {
                  final profile = profileSnapshot.data ?? const {};

                  return StreamBuilder<List<BudgetPlan>>(
                    stream: firestoreService.getBudgetPlans(
                      monthKey: period.key,
                    ),
                    builder: (context, budgetSnapshot) {
                      final budgets =
                          budgetSnapshot.data ?? const <BudgetPlan>[];
                      final analytics = _BudgetAnalytics.from(
                        budgets: budgets,
                        periodTransactions: periodTransactions,
                        allTransactions: transactions,
                        goals: goals,
                        profile: profile,
                        period: period,
                      );

                      return SafeArea(
                        child: CustomScrollView(
                          physics: const BouncingScrollPhysics(),
                          slivers: [
                            SliverToBoxAdapter(
                              child: Padding(
                                padding: const EdgeInsets.fromLTRB(
                                  20,
                                  20,
                                  20,
                                  0,
                                ),
                                child: _BudgetHeader(
                                  period: period,
                                  mode: _periodMode,
                                  onBack: () => Navigator.pop(context),
                                  onPrevious: () => setState(
                                    () => _anchorDate = period.shift(
                                      _periodMode,
                                      -1,
                                    ),
                                  ),
                                  onNext: () => setState(
                                    () => _anchorDate = period.shift(
                                      _periodMode,
                                      1,
                                    ),
                                  ),
                                  onModeChanged: (mode) => setState(() {
                                    _periodMode = mode;
                                    _anchorDate = DateTime.now();
                                  }),
                                ),
                              ),
                            ),
                            SliverPadding(
                              padding: const EdgeInsets.fromLTRB(
                                20,
                                20,
                                20,
                                120,
                              ),
                              sliver: SliverList(
                                delegate: SliverChildListDelegate([
                                  _OverviewCard(analytics: analytics),
                                  const SizedBox(height: 14),
                                  if (analytics.isOverBudget)
                                    _BudgetWarningCard(
                                      analytics: analytics,
                                      onAdjust: () => _showBudgetEditor(
                                        context,
                                        firestoreService,
                                        analytics: analytics,
                                        budgets: budgets,
                                      ),
                                      onUseSavings: () => _confirmSavingsPull(
                                        context,
                                        firestoreService,
                                        analytics,
                                      ),
                                    ),
                                  if (analytics.isOverBudget)
                                    const SizedBox(height: 14),
                                  _NarrativeCard(analytics: analytics),
                                  const SizedBox(height: 24),
                                  _QuickActions(
                                    onAddCategory: () => _showBudgetEditor(
                                      context,
                                      firestoreService,
                                      analytics: analytics,
                                      budgets: budgets,
                                    ),
                                    onEditBudget: () => _showBudgetEditor(
                                      context,
                                      firestoreService,
                                      analytics: analytics,
                                      budgets: budgets,
                                    ),
                                    onAutoBudget: () => _showAutoBudgetPreview(
                                      context,
                                      firestoreService,
                                      analytics: analytics,
                                      budgets: budgets,
                                    ),
                                  ),
                                  const SizedBox(height: 24),
                                  _SectionTitle(
                                    title: '${period.modeLabel} Budget Plans',
                                  ),
                                  const SizedBox(height: 14),
                                  if (budgets.isEmpty)
                                    _EmptyBudgetState(
                                      onCreate: () => _showBudgetEditor(
                                        context,
                                        firestoreService,
                                        analytics: analytics,
                                        budgets: budgets,
                                      ),
                                    )
                                  else
                                    ...budgets.map(
                                      (budget) => Padding(
                                        padding: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        child: _BudgetPlanCard(
                                          budget: budget,
                                          analytics: analytics,
                                          onEdit: () => _showBudgetEditor(
                                            context,
                                            firestoreService,
                                            analytics: analytics,
                                            budgets: budgets,
                                          ),
                                          onUseSavings:
                                              analytics.isCategoryOverBudget(
                                                budget.category,
                                              )
                                              ? () => _confirmSavingsPull(
                                                  context,
                                                  firestoreService,
                                                  analytics,
                                                  category: budget.category,
                                                )
                                              : null,
                                          onDelete: () => firestoreService
                                              .deleteBudgetPlan(budget.id),
                                        ),
                                      ),
                                    ),
                                  const SizedBox(height: 24),
                                  const _SectionTitle(title: 'Category Rings'),
                                  const SizedBox(height: 14),
                                  _CategoryRings(analytics: analytics),
                                  const SizedBox(height: 24),
                                  const _SectionTitle(
                                    title: 'Savings & Goal Alignment',
                                  ),
                                  const SizedBox(height: 14),
                                  _GoalAlignmentPanel(analytics: analytics),
                                  const SizedBox(height: 24),
                                  const _SectionTitle(title: 'Budget Brain'),
                                  const SizedBox(height: 14),
                                  _BrainSignals(analytics: analytics),
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
          );
        },
      ),
    );
  }

  void _scheduleCarryForward(
    BuildContext context,
    FirestoreService firestoreService,
    _BudgetPeriod period,
  ) {
    if (!period.isClosed || _carryForwardChecks.contains(period.key)) return;
    _carryForwardChecks.add(period.key);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final leftover = await firestoreService.previewBudgetLeftover(
        periodType: period.modeName,
        periodKey: period.key,
      );
      if (!context.mounted || leftover <= 0) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Move leftover budget to Savings?'),
          content: Text(
            '${CurrencyUtils.format(leftover)} is left from ${period.label}. Move it to Savings now?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Not now'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Move to Savings'),
            ),
          ],
        ),
      );
      if (approved != true) return;
      await firestoreService.carryForwardBudgetLeftover(
        periodType: period.modeName,
        periodKey: period.key,
        periodEnd: period.end,
      );
    });
  }

  Future<void> _confirmSavingsPull(
    BuildContext context,
    FirestoreService firestoreService,
    _BudgetAnalytics analytics, {
    String? category,
  }) async {
    final amount = category == null
        ? analytics.overBudgetAmount
        : analytics.categoryOverage(category);
    if (amount <= 0) return;
    final approved = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use Savings for budget?'),
        content: Text(
          'Expenses are over budget by ${CurrencyUtils.format(amount)}. Pull this amount from Savings to support the ${analytics.period.modeLabel.toLowerCase()} budget?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('No'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Yes'),
          ),
        ],
      ),
    );
    if (approved != true || !mounted) return;
    try {
      await firestoreService.pullSavingsForBudgetOverage(
        amount: amount,
        periodType: analytics.period.modeName,
        periodKey: analytics.period.key,
        reason: category == null
            ? 'Budget overage support for ${analytics.period.label}'
            : '$category overage support for ${analytics.period.label}',
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Savings support transfer recorded'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    } on FinanceValidationException catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.message),
            backgroundColor: const Color(0xFFBA1A1A),
          ),
        );
      }
    }
  }

  void _showBudgetEditor(
    BuildContext context,
    FirestoreService firestoreService, {
    required _BudgetAnalytics analytics,
    required List<BudgetPlan> budgets,
  }) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CategoryBudgetManagerSheet(
        firestoreService: firestoreService,
        budgets: budgets,
        analytics: analytics,
      ),
    );
  }

  void _showAutoBudgetPreview(
    BuildContext context,
    FirestoreService firestoreService, {
    required _BudgetAnalytics analytics,
    required List<BudgetPlan> budgets,
  }) {
    final suggestions = _AutoBudgetGenerator.generate(analytics);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AutoBudgetPreviewSheet(
        suggestions: suggestions,
        analytics: analytics,
        onApply: () async {
          await _applySuggestedBudgets(
            firestoreService,
            analytics,
            budgets,
            suggestions,
          );
          if (context.mounted) {
            Navigator.pop(context);
          }
        },
      ),
    );
  }

  Future<void> _applySuggestedBudgets(
    FirestoreService firestoreService,
    _BudgetAnalytics analytics,
    List<BudgetPlan> budgets,
    List<_BudgetSuggestion> suggestions,
  ) async {
    final existingByCategory = {
      for (final budget in budgets) budget.category: budget,
    };
    for (final suggestion in suggestions) {
      final existing = existingByCategory[suggestion.category];
      final budget = BudgetPlan(
        id: existing?.id ?? '',
        title: suggestion.category,
        category: suggestion.category,
        allocatedAmount: suggestion.amount,
        notes: suggestion.reason,
        monthKey: analytics.period.key,
        periodKey: analytics.period.key,
        periodType: analytics.period.modeName,
        createdAt: DateTime.now(),
        allocationMode: 'ai',
        isDebtPayment: existing?.isDebtPayment ?? false,
        reminderDate: existing?.reminderDate,
      );
      if (existing == null) {
        await firestoreService.addBudgetPlan(budget);
      } else {
        await firestoreService.updateBudgetPlan(existing.id, budget.toMap());
      }
    }
  }
}

class _BudgetPeriod {
  const _BudgetPeriod({
    required this.mode,
    required this.key,
    required this.label,
    required this.start,
    required this.end,
  });

  final _PeriodMode mode;
  final String key;
  final String label;
  final DateTime start;
  final DateTime end;

  factory _BudgetPeriod.from(_PeriodMode mode, DateTime anchor) {
    switch (mode) {
      case _PeriodMode.daily:
        final start = DateTime(anchor.year, anchor.month, anchor.day);
        return _BudgetPeriod(
          mode: mode,
          key:
              '${anchor.year}-${anchor.month.toString().padLeft(2, '0')}-${anchor.day.toString().padLeft(2, '0')}',
          label: DateFormat('MMM dd, yyyy').format(anchor),
          start: start,
          end: start.add(const Duration(days: 1)),
        );
      case _PeriodMode.weekly:
        final start = DateTime(
          anchor.year,
          anchor.month,
          anchor.day,
        ).subtract(Duration(days: anchor.weekday - DateTime.monday));
        final firstDay = DateTime(anchor.year, 1, 1);
        final offset = firstDay.weekday - DateTime.monday;
        final firstMonday = firstDay.subtract(
          Duration(days: offset < 0 ? 6 : offset),
        );
        final week = (start.difference(firstMonday).inDays ~/ 7) + 1;
        return _BudgetPeriod(
          mode: mode,
          key: '${anchor.year}-W${week.toString().padLeft(2, '0')}',
          label:
              '${DateFormat('MMM dd').format(start)} - ${DateFormat('MMM dd').format(start.add(const Duration(days: 6)))}',
          start: start,
          end: start.add(const Duration(days: 7)),
        );
      case _PeriodMode.yearly:
        final start = DateTime(anchor.year);
        return _BudgetPeriod(
          mode: mode,
          key: '${anchor.year}',
          label: '${anchor.year}',
          start: start,
          end: DateTime(anchor.year + 1),
        );
      case _PeriodMode.monthly:
        final start = DateTime(anchor.year, anchor.month);
        return _BudgetPeriod(
          mode: mode,
          key: '${anchor.year}-${anchor.month.toString().padLeft(2, '0')}',
          label: DateFormat('MMMM yyyy').format(anchor),
          start: start,
          end: DateTime(anchor.year, anchor.month + 1),
        );
    }
  }

  bool contains(DateTime date) {
    return !date.isBefore(start) && date.isBefore(end);
  }

  DateTime shift(_PeriodMode mode, int step) {
    switch (mode) {
      case _PeriodMode.daily:
        return start.add(Duration(days: step));
      case _PeriodMode.weekly:
        return start.add(Duration(days: step * 7));
      case _PeriodMode.monthly:
        return DateTime(start.year, start.month + step);
      case _PeriodMode.yearly:
        return DateTime(start.year + step);
    }
  }

  bool get isClosed => DateTime.now().isAfter(end);
  String get modeName => mode.name;
  String get modeLabel => mode.name[0].toUpperCase() + mode.name.substring(1);
}

class _BudgetAnalytics {
  _BudgetAnalytics({
    required this.budgets,
    required this.periodTransactions,
    required this.allTransactions,
    required this.goals,
    required this.period,
    required this.projectedIncome,
    required this.totalBudgeted,
    required this.totalSpent,
    required this.categorySpend,
    required this.profileSavings,
  });

  final List<BudgetPlan> budgets;
  final List<FinancialTransaction> periodTransactions;
  final List<FinancialTransaction> allTransactions;
  final List<SavingGoal> goals;
  final _BudgetPeriod period;
  final double projectedIncome;
  final double totalBudgeted;
  final double totalSpent;
  final Map<String, double> categorySpend;
  final double profileSavings;

  factory _BudgetAnalytics.from({
    required List<BudgetPlan> budgets,
    required List<FinancialTransaction> periodTransactions,
    required List<FinancialTransaction> allTransactions,
    required List<SavingGoal> goals,
    required Map<String, dynamic> profile,
    required _BudgetPeriod period,
  }) {
    final periodIncome = periodTransactions
        .where((txn) => txn.type == 'income')
        .fold<double>(0, (total, txn) => total + txn.amount);
    final monthlyProfileIncome = ((profile['monthlyIncome'] ?? 0) as num)
        .toDouble();
    final projectedIncome = periodIncome > 0
        ? periodIncome
        : _scaledIncome(monthlyProfileIncome, period.mode);
    final totalBudgeted = budgets.fold<double>(
      0,
      (total, budget) => total + budget.allocatedAmount,
    );
    final totalSpent = periodTransactions
        .where((txn) => txn.type == 'expense')
        .fold<double>(0, (total, txn) => total + txn.amount);
    final categorySpend = <String, double>{};
    for (final txn in periodTransactions.where(
      (txn) => txn.type == 'expense',
    )) {
      categorySpend[txn.category] =
          (categorySpend[txn.category] ?? 0) + txn.amount;
    }
    final profileSavings =
        ((profile['savingsBalance'] ?? 0) as num).toDouble() +
        ((profile['extraSavingsBalance'] ?? 0) as num).toDouble();
    return _BudgetAnalytics(
      budgets: budgets,
      periodTransactions: periodTransactions,
      allTransactions: allTransactions,
      goals: goals,
      period: period,
      projectedIncome: projectedIncome,
      totalBudgeted: totalBudgeted,
      totalSpent: totalSpent,
      categorySpend: categorySpend,
      profileSavings: profileSavings,
    );
  }

  static double _scaledIncome(double monthlyIncome, _PeriodMode mode) {
    switch (mode) {
      case _PeriodMode.daily:
        return monthlyIncome / 30;
      case _PeriodMode.weekly:
        return monthlyIncome / 4.345;
      case _PeriodMode.yearly:
        return monthlyIncome * 12;
      case _PeriodMode.monthly:
        return monthlyIncome;
    }
  }

  double get remainingBudget =>
      (totalBudgeted - totalSpent).clamp(0, double.infinity).toDouble();
  double get availableToPlan =>
      (projectedIncome - totalBudgeted).clamp(0, double.infinity).toDouble();
  double get overBudgetAmount =>
      (totalSpent - totalBudgeted).clamp(0, double.infinity).toDouble();
  bool get isOverBudget => overBudgetAmount > 0;
  double get spendingRatio =>
      totalBudgeted == 0 ? 0 : (totalSpent / totalBudgeted).clamp(0.0, 2.0);
  double get planRatio => projectedIncome == 0
      ? 0
      : (totalBudgeted / projectedIncome).clamp(0.0, 2.0);
  double get savingsRate {
    if (projectedIncome <= 0) return 0;
    final saved = projectedIncome - totalSpent;
    return ((saved > 0 ? saved : 0) / projectedIncome) * 100;
  }

  int get healthScore {
    var score = 100;
    if (projectedIncome > 0) {
      score -= ((totalSpent / projectedIncome).clamp(0.0, 1.4) * 32).round();
      score -= ((totalBudgeted / projectedIncome).clamp(0.0, 1.2) * 18).round();
    } else if (totalSpent > 0 || totalBudgeted > 0) {
      score -= 42;
    }
    if (isOverBudget) score -= 18;
    if (goals.where((goal) => goal.remaining > 0).isEmpty) score -= 6;
    if (profileSavings <= 0) score -= 8;
    return score.clamp(0, 100);
  }

  double spentForCategory(String category) => categorySpend[category] ?? 0;

  double allocatedForCategory(String category) => budgets
      .where((budget) => budget.category == category)
      .fold<double>(0, (total, budget) => total + budget.allocatedAmount);

  double categoryOverage(String category) =>
      (spentForCategory(category) - allocatedForCategory(category))
          .clamp(0, double.infinity)
          .toDouble();

  bool isCategoryOverBudget(String category) => categoryOverage(category) > 0;

  double get goalPressure {
    if (goals.isEmpty || projectedIncome <= 0) return 0;
    final target = goals.fold<double>(0, (total, goal) {
      final days = math.max(goal.daysLeft, 1);
      final dailyNeed = goal.remaining / days;
      return total + _periodNeed(dailyNeed);
    });
    return target;
  }

  double _periodNeed(double dailyNeed) {
    switch (period.mode) {
      case _PeriodMode.daily:
        return dailyNeed;
      case _PeriodMode.weekly:
        return dailyNeed * 7;
      case _PeriodMode.yearly:
        return dailyNeed * 365;
      case _PeriodMode.monthly:
        return dailyNeed * 30;
    }
  }

  List<MapEntry<String, double>> get topCategories {
    final entries = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(5).toList();
  }

  int get activeDebtBudgets =>
      budgets.where((budget) => budget.isDebtPayment).length;
}

class _BudgetHeader extends StatelessWidget {
  const _BudgetHeader({
    required this.period,
    required this.mode,
    required this.onBack,
    required this.onPrevious,
    required this.onNext,
    required this.onModeChanged,
  });

  final _BudgetPeriod period;
  final _PeriodMode mode;
  final VoidCallback onBack;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<_PeriodMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Theme.of(context).dividerColor),
              ),
              child: IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                color: AppTheme.primary,
                onPressed: onBack,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Text(
                'AI Budget Advisor',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Budget is the central brain for income, transactions, savings, debt payments, and goals.',
          style: GoogleFonts.inter(
            color:
                (Theme.of(context).textTheme.bodyMedium?.color ??
                AppTheme.textSecondaryFor(context)),
            height: 1.5,
          ),
        ),
        const SizedBox(height: 18),
        _PeriodSwitcher(
          period: period,
          mode: mode,
          onPrevious: onPrevious,
          onNext: onNext,
          onModeChanged: onModeChanged,
        ),
      ],
    );
  }
}

class _PeriodSwitcher extends StatelessWidget {
  const _PeriodSwitcher({
    required this.period,
    required this.mode,
    required this.onPrevious,
    required this.onNext,
    required this.onModeChanged,
  });

  final _BudgetPeriod period;
  final _PeriodMode mode;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<_PeriodMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: Icon(Icons.chevron_left_rounded),
                color: AppTheme.primary,
              ),
              Expanded(
                child: Text(
                  period.label,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.plusJakartaSans(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                    fontSize: 17,
                  ),
                ),
              ),
              IconButton(
                onPressed: onNext,
                icon: Icon(Icons.chevron_right_rounded),
                color: AppTheme.primary,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: _PeriodMode.values
                .map(
                  (item) => Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: GestureDetector(
                        onTap: () => onModeChanged(item),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 180),
                          padding: const EdgeInsets.symmetric(vertical: 9),
                          decoration: BoxDecoration(
                            color: mode == item
                                ? AppTheme.primary
                                : AppTheme.primary.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.name[0].toUpperCase() + item.name.substring(1),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: mode == item
                                  ? Colors.white
                                  : AppTheme.primary,
                              fontSize: 12,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
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

class _OverviewCard extends StatelessWidget {
  const _OverviewCard({required this.analytics});

  final _BudgetAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            analytics.isOverBudget
                ? 'Budget needs attention'
                : 'Available to plan',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.75),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyUtils.format(
              analytics.isOverBudget
                  ? analytics.overBudgetAmount
                  : analytics.availableToPlan,
            ),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 16),
          _WhiteProgress(
            value: analytics.planRatio.clamp(0.0, 1.0),
            label: 'Planned vs projected income',
          ),
          const SizedBox(height: 12),
          _WhiteProgress(
            value: analytics.spendingRatio.clamp(0.0, 1.0),
            label: 'Transactions vs budget',
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _SummaryStat(
                label: 'Income',
                value: CurrencyUtils.format(analytics.projectedIncome),
              ),
              _SummaryStat(
                label: 'Budgeted',
                value: CurrencyUtils.format(analytics.totalBudgeted),
              ),
              _SummaryStat(
                label: 'Health',
                value: '${analytics.healthScore}/100',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _WhiteProgress extends StatelessWidget {
  const _WhiteProgress({required this.value, required this.label});

  final double value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.74),
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value,
            minHeight: 10,
            backgroundColor: Colors.white.withValues(alpha: 0.22),
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }
}

class _BudgetWarningCard extends StatelessWidget {
  const _BudgetWarningCard({
    required this.analytics,
    required this.onAdjust,
    required this.onUseSavings,
  });

  final _BudgetAnalytics analytics;
  final VoidCallback onAdjust;
  final VoidCallback onUseSavings;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Color(0xFFF97316)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Transactions exceeded budget',
                  style: GoogleFonts.plusJakartaSans(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'You are over by ${CurrencyUtils.format(analytics.overBudgetAmount)}. Adjust the budget or confirm a Savings support transfer.',
            style: GoogleFonts.inter(
              color:
                  (Theme.of(context).textTheme.bodyMedium?.color ??
                  AppTheme.textSecondaryFor(context)),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: onAdjust,
                  icon: Icon(Icons.tune_rounded),
                  label: const Text('Adjust Budget'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onUseSavings,
                  icon: Icon(Icons.savings_rounded),
                  label: const Text('Use Savings'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppTheme.primary,
                    side: BorderSide(color: Theme.of(context).dividerColor),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({required this.analytics});

  final _BudgetAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final text = _narrative();
    return _Panel(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.auto_awesome_rounded, color: AppTheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly narrative',
                  style: GoogleFonts.plusJakartaSans(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  text,
                  style: GoogleFonts.inter(
                    color:
                        (Theme.of(context).textTheme.bodyMedium?.color ??
                        AppTheme.textSecondaryFor(context)),
                    height: 1.45,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _narrative() {
    if (analytics.periodTransactions.isEmpty && analytics.budgets.isEmpty) {
      return 'No budget movement yet. Start with Auto-Budget or Add Category and FinEase will sync transactions, savings, and goals here.';
    }
    if (analytics.isOverBudget) {
      return 'Urgency is rising: spending is ahead of the plan. A small budget adjustment or savings support can rebalance this period.';
    }
    if (analytics.spendingRatio < 0.65 && analytics.totalBudgeted > 0) {
      return 'Good control this period. You are staying under budget while keeping room for savings and goals.';
    }
    if (analytics.goalPressure > analytics.projectedIncome * 0.2) {
      return 'Goals need meaningful funding this period. Keep discretionary categories lean so target dates stay realistic.';
    }
    return 'On track for 3 weeks: spending momentum is steady and the budget is still guiding transactions well.';
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onAddCategory,
    required this.onEditBudget,
    required this.onAutoBudget,
  });

  final VoidCallback onAddCategory;
  final VoidCallback onEditBudget;
  final VoidCallback onAutoBudget;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            label: 'Add Category',
            icon: Icons.add_rounded,
            onTap: onAddCategory,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: 'Edit Budget',
            icon: Icons.edit_outlined,
            onTap: onEditBudget,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _ActionButton(
            label: 'Auto-Budget',
            icon: Icons.auto_awesome_rounded,
            onTap: onAutoBudget,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Column(
          children: [
            Icon(icon, color: AppTheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Theme.of(context).colorScheme.onSurface,
                fontWeight: FontWeight.w800,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: GoogleFonts.plusJakartaSans(
        color: Theme.of(context).colorScheme.onSurface,
        fontSize: 20,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _BudgetPlanCard extends StatelessWidget {
  const _BudgetPlanCard({
    required this.budget,
    required this.analytics,
    required this.onEdit,
    required this.onDelete,
    this.onUseSavings,
  });

  final BudgetPlan budget;
  final _BudgetAnalytics analytics;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback? onUseSavings;

  @override
  Widget build(BuildContext context) {
    final spent = analytics.spentForCategory(budget.category);
    final remaining = (budget.allocatedAmount - spent)
        .clamp(0, double.infinity)
        .toDouble();
    final over = analytics.categoryOverage(budget.category);
    final progress = budget.allocatedAmount == 0
        ? 0.0
        : (spent / budget.allocatedAmount).clamp(0.0, 1.0);
    final isUrgent =
        budget.reminderDate != null &&
        budget.reminderDate!.difference(DateTime.now()).inDays <= 3;

    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            budget.title,
                            style: GoogleFonts.plusJakartaSans(
                              color: Theme.of(context).colorScheme.onSurface,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (budget.isDebtPayment)
                          _Tag(label: 'Debt', color: const Color(0xFFF97316)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      budget.category,
                      style: GoogleFonts.inter(
                        color:
                            (Theme.of(context).textTheme.bodyMedium?.color ??
                            AppTheme.textSecondaryFor(context)),
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: Icon(Icons.edit_outlined, color: AppTheme.primary),
              ),
              IconButton(
                onPressed: onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: AppTheme.error,
                ),
              ),
            ],
          ),
          if (budget.notes.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              budget.notes,
              style: GoogleFonts.inter(
                color:
                    (Theme.of(context).textTheme.bodyMedium?.color ??
                    AppTheme.textSecondaryFor(context)),
                height: 1.5,
              ),
            ),
          ],
          if (budget.reminderDate != null) ...[
            const SizedBox(height: 8),
            Text(
              '${isUrgent ? 'Urgent: ' : ''}Reminder ${DateFormat('MMM dd').format(budget.reminderDate!)}',
              style: GoogleFonts.inter(
                color: isUrgent ? const Color(0xFFF97316) : AppTheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Theme.of(context).dividerColor,
              color: over > 0 ? AppTheme.error : AppTheme.primary,
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
                  label: over > 0 ? 'Over' : 'Remaining',
                  value: CurrencyUtils.format(over > 0 ? over : remaining),
                ),
              ),
            ],
          ),
          if (over > 0 && onUseSavings != null) ...[
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onUseSavings,
                icon: Icon(Icons.savings_rounded),
                label: const Text('Pull from Savings'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppTheme.primary,
                  side: BorderSide(color: Theme.of(context).dividerColor),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Tag extends StatelessWidget {
  const _Tag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w800,
        ),
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
            color:
                (Theme.of(context).textTheme.bodyMedium?.color ??
                AppTheme.textSecondaryFor(context)),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.plusJakartaSans(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
        ),
      ],
    );
  }
}

class _CategoryRings extends StatelessWidget {
  const _CategoryRings({required this.analytics});

  final _BudgetAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    if (analytics.budgets.isEmpty) {
      return _Panel(
        child: Text(
          'Create budgets to see category-wise progress rings.',
          style: GoogleFonts.inter(
            color:
                (Theme.of(context).textTheme.bodyMedium?.color ??
                AppTheme.textSecondaryFor(context)),
          ),
        ),
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: analytics.budgets.map((budget) {
        final spent = analytics.spentForCategory(budget.category);
        final progress = budget.allocatedAmount == 0
            ? 0.0
            : (spent / budget.allocatedAmount).clamp(0.0, 1.0);
        final over = analytics.isCategoryOverBudget(budget.category);
        return SizedBox(
          width: 160,
          child: _Panel(
            child: Column(
              children: [
                SizedBox(
                  height: 92,
                  child: PieChart(
                    PieChartData(
                      centerSpaceRadius: 30,
                      sectionsSpace: 0,
                      sections: [
                        PieChartSectionData(
                          value: math.max(progress, 0.02),
                          color: over ? AppTheme.error : AppTheme.primary,
                          radius: 10,
                          showTitle: false,
                        ),
                        PieChartSectionData(
                          value: math.max(1 - progress, 0.02),
                          color: Theme.of(context).dividerColor,
                          radius: 10,
                          showTitle: false,
                        ),
                      ],
                    ),
                  ),
                ),
                Text(
                  budget.category,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '${(progress * 100).round()}% used',
                  style: GoogleFonts.inter(
                    color:
                        (Theme.of(context).textTheme.bodyMedium?.color ??
                        AppTheme.textSecondaryFor(context)),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _GoalAlignmentPanel extends StatelessWidget {
  const _GoalAlignmentPanel({required this.analytics});

  final _BudgetAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SignalRow(
            icon: Icons.savings_rounded,
            title: 'Savings pressure',
            value: CurrencyUtils.format(analytics.goalPressure),
            body:
                'Needed this period to keep active goal target dates realistic.',
          ),
          const SizedBox(height: 14),
          _SignalRow(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Savings balance',
            value: CurrencyUtils.format(analytics.profileSavings),
            body: 'Savings can support budget shocks only with confirmation.',
          ),
          if (analytics.goals.isNotEmpty) ...[
            const SizedBox(height: 16),
            ...analytics.goals
                .take(3)
                .map(
                  (goal) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _GoalMini(goal: goal),
                  ),
                ),
          ],
        ],
      ),
    );
  }
}

class _GoalMini extends StatelessWidget {
  const _GoalMini({required this.goal});

  final SavingGoal goal;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                goal.title,
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              '${(goal.progress * 100).round()}%',
              style: GoogleFonts.inter(
                color: AppTheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: goal.progress,
            minHeight: 7,
            backgroundColor: Theme.of(context).dividerColor,
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }
}

class _BrainSignals extends StatelessWidget {
  const _BrainSignals({required this.analytics});

  final _BudgetAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      child: Column(
        children: [
          _SignalRow(
            icon: Icons.health_and_safety_rounded,
            title: 'Financial Health Score',
            value: '${analytics.healthScore}/100',
            body: analytics.healthScore >= 75
                ? 'Strong planning rhythm.'
                : 'Budget needs a lighter expense load.',
          ),
          const SizedBox(height: 14),
          _SignalRow(
            icon: Icons.trending_up_rounded,
            title: 'Momentum',
            value: analytics.isOverBudget ? 'High risk' : 'On track',
            body: analytics.isOverBudget
                ? 'Spending is moving faster than planned.'
                : 'Positive reinforcement: you are staying under budget.',
          ),
          const SizedBox(height: 14),
          _SignalRow(
            icon: Icons.credit_card_rounded,
            title: 'Debt budgets',
            value: '${analytics.activeDebtBudgets}',
            body:
                'Debt categories can carry reminders so payments stay visible.',
          ),
        ],
      ),
    );
  }
}

class _SignalRow extends StatelessWidget {
  const _SignalRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String value;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AppTheme.primary.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Icon(icon, color: AppTheme.primary),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.primary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                body,
                style: GoogleFonts.inter(
                  color:
                      (Theme.of(context).textTheme.bodyMedium?.color ??
                      AppTheme.textSecondaryFor(context)),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ],
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
            color: AppTheme.primary,
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
    return _Panel(
      child: Column(
        children: [
          Icon(
            Icons.account_balance_wallet_outlined,
            color: Colors.white,
            size: 48,
          ),
          const SizedBox(height: 14),
          Text(
            'Create period budgets for categories, debt payments, savings, and goal protection.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color:
                  (Theme.of(context).textTheme.bodyMedium?.color ??
                  AppTheme.textSecondaryFor(context)),
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

class _Panel extends StatelessWidget {
  const _Panel({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
  }
}

class _CategoryBudgetManagerSheet extends StatefulWidget {
  const _CategoryBudgetManagerSheet({
    required this.firestoreService,
    required this.budgets,
    required this.analytics,
  });

  final FirestoreService firestoreService;
  final List<BudgetPlan> budgets;
  final _BudgetAnalytics analytics;

  @override
  State<_CategoryBudgetManagerSheet> createState() =>
      _CategoryBudgetManagerSheetState();
}

class _CategoryBudgetManagerSheetState
    extends State<_CategoryBudgetManagerSheet> {
  final _inputs = <String, _CategoryBudgetInput>{};
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
    for (final input in _inputs.values) {
      input.dispose();
    }
    super.dispose();
  }

  double get _totalAmount =>
      _inputs.values.fold<double>(0, (total, input) => total + input.amount);

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final income = widget.analytics.projectedIncome;
    final remaining = (income - _totalAmount)
        .clamp(0, double.infinity)
        .toDouble();
    final exceedsIncome = _totalAmount > income;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 16, 20, bottomInset + 20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
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
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '${widget.analytics.period.modeLabel} Category Budgeting',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Projected income is ${CurrencyUtils.format(income)}. Budget total cannot exceed this amount.',
                style: GoogleFonts.inter(
                  color:
                      (Theme.of(context).textTheme.bodyMedium?.color ??
                      AppTheme.textSecondaryFor(context)),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _SheetTotals(
                income: income,
                totalAmount: _totalAmount,
                remaining: remaining,
              ),
              if (exceedsIncome) ...[
                const SizedBox(height: 12),
                const _ValidationBanner(
                  message:
                      'Budget total exceeds projected income. Reduce categories before saving.',
                ),
              ],
              const SizedBox(height: 16),
              ...AppConstants.budgetCategories.map(
                (category) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _CategoryBudgetRow(
                    category: category,
                    input: _inputs[category]!,
                    onChanged: () => setState(() {}),
                    onPickReminder: () => _pickReminder(category),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _saving || exceedsIncome ? null : _save,
                  child: Text(_saving ? 'Saving...' : 'Save Budget Brain'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickReminder(String category) async {
    final input = _inputs[category]!;
    final picked = await showDatePicker(
      context: context,
      initialDate: input.reminderDate ?? DateTime.now(),
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() => input.reminderDate = picked);
  }

  Future<void> _save() async {
    final income = widget.analytics.projectedIncome;
    if (_totalAmount > income) {
      _showError('Budget total cannot exceed projected income.');
      return;
    }
    setState(() => _saving = true);
    try {
      final existingByCategory = {
        for (final budget in widget.budgets) budget.category: budget,
      };
      for (final category in AppConstants.budgetCategories) {
        final input = _inputs[category]!;
        final existing = existingByCategory[category];
        if (input.amount <= 0) {
          if (existing != null) {
            await widget.firestoreService.deleteBudgetPlan(existing.id);
          }
          continue;
        }
        final budget = BudgetPlan(
          id: existing?.id ?? '',
          title: category,
          category: category,
          allocatedAmount: input.amount,
          notes: input.isDebtPayment
              ? 'Debt payment budget with reminder'
              : 'Manual ${widget.analytics.period.modeName} allocation',
          monthKey: widget.analytics.period.key,
          periodKey: widget.analytics.period.key,
          periodType: widget.analytics.period.modeName,
          createdAt: DateTime.now(),
          allocationMode: 'manual',
          isDebtPayment: input.isDebtPayment,
          reminderDate: input.reminderDate,
        );
        if (existing == null) {
          await widget.firestoreService.addBudgetPlan(budget);
        } else {
          await widget.firestoreService.updateBudgetPlan(
            existing.id,
            budget.toMap(),
          );
        }
      }
      if (mounted) Navigator.pop(context);
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

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFBA1A1A),
      ),
    );
  }
}

class _CategoryBudgetInput {
  _CategoryBudgetInput(BudgetPlan? budget)
    : amountController = TextEditingController(
        text: budget == null || budget.allocatedAmount == 0
            ? ''
            : budget.allocatedAmount.toStringAsFixed(0),
      ),
      isDebtPayment = budget?.isDebtPayment ?? false,
      reminderDate = budget?.reminderDate;

  final TextEditingController amountController;
  bool isDebtPayment;
  DateTime? reminderDate;

  double get amount {
    final value = double.tryParse(amountController.text.trim()) ?? 0;
    return value.isFinite && value > 0 ? value : 0;
  }

  void dispose() {
    amountController.dispose();
  }
}

class _SheetTotals extends StatelessWidget {
  const _SheetTotals({
    required this.income,
    required this.totalAmount,
    required this.remaining,
  });

  final double income;
  final double totalAmount;
  final double remaining;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          _totalRow(context, 'Projected income', CurrencyUtils.format(income)),
          _totalRow(context, 'Budget total', CurrencyUtils.format(totalAmount)),
          _totalRow(
            context,
            'Remaining to plan',
            CurrencyUtils.format(remaining),
            highlight: true,
          ),
        ],
      ),
    );
  }

  Widget _totalRow(
    BuildContext context,
    String label,
    String value, {
    bool highlight = false,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color:
                    (Theme.of(context).textTheme.bodyMedium?.color ??
                    AppTheme.textSecondaryFor(context)),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: highlight
                  ? AppTheme.primary
                  : Theme.of(context).colorScheme.onSurface,
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
    required this.onChanged,
    required this.onPickReminder,
  });

  final String category;
  final _CategoryBudgetInput input;
  final VoidCallback onChanged;
  final VoidCallback onPickReminder;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  category,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
              ),
              Switch(
                value: input.isDebtPayment,
                activeThumbColor: AppTheme.primary,
                onChanged: (value) {
                  input.isDebtPayment = value;
                  onChanged();
                },
              ),
              Text(
                'Debt',
                style: GoogleFonts.inter(
                  color:
                      (Theme.of(context).textTheme.bodyMedium?.color ??
                      AppTheme.textSecondaryFor(context)),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: input.amountController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onChanged: (_) => onChanged(),
            decoration: const InputDecoration(
              labelText: 'Budget amount',
              prefixText: 'PKR ',
            ),
          ),
          if (input.isDebtPayment) ...[
            const SizedBox(height: 10),
            InkWell(
              onTap: onPickReminder,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 12,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.notifications_active_rounded,
                      color: AppTheme.primary,
                      size: 18,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      input.reminderDate == null
                          ? 'Add payment reminder'
                          : 'Reminder ${DateFormat('MMM dd, yyyy').format(input.reminderDate!)}',
                      style: GoogleFonts.inter(
                        color: Theme.of(context).colorScheme.onSurface,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AutoBudgetGenerator {
  static List<_BudgetSuggestion> generate(_BudgetAnalytics analytics) {
    final income = analytics.projectedIncome;
    if (income <= 0) return const [];
    final goalReserve = analytics.goalPressure
        .clamp(0, income * 0.25)
        .toDouble();
    final savingsAmount = math.max(income * 0.12, goalReserve);
    final remaining = (income - savingsAmount)
        .clamp(0, double.infinity)
        .toDouble();
    final categories = AppConstants.budgetCategories
        .where((category) => category != 'Savings')
        .toList();
    final historicalSpend = <String, double>{};
    for (final transaction in analytics.allTransactions.where(
      (txn) => txn.type == 'expense',
    )) {
      historicalSpend[transaction.category] =
          (historicalSpend[transaction.category] ?? 0) + transaction.amount;
    }
    final totalHistory = historicalSpend.values.fold<double>(
      0,
      (total, amount) => total + amount,
    );
    final suggestions = <_BudgetSuggestion>[];
    for (final category in categories) {
      final share = totalHistory > 0
          ? (historicalSpend[category] ?? 0) / totalHistory
          : 1 / categories.length;
      final amount = remaining * share;
      if (amount > 0) {
        suggestions.add(
          _BudgetSuggestion(
            category: category,
            amount: amount,
            reason: totalHistory > 0
                ? 'Suggested from past transaction patterns'
                : 'Balanced starter allocation',
          ),
        );
      }
    }
    suggestions.add(
      _BudgetSuggestion(
        category: 'Savings',
        amount: savingsAmount,
        reason: 'Protects active goals and savings rate',
      ),
    );
    return suggestions;
  }
}

class _BudgetSuggestion {
  const _BudgetSuggestion({
    required this.category,
    required this.amount,
    required this.reason,
  });

  final String category;
  final double amount;
  final String reason;
}

class _AutoBudgetPreviewSheet extends StatelessWidget {
  const _AutoBudgetPreviewSheet({
    required this.suggestions,
    required this.analytics,
    required this.onApply,
  });

  final List<_BudgetSuggestion> suggestions;
  final _BudgetAnalytics analytics;
  final Future<void> Function() onApply;

  @override
  Widget build(BuildContext context) {
    final total = suggestions.fold<double>(
      0,
      (total, suggestion) => total + suggestion.amount,
    );
    final isValid = total <= analytics.projectedIncome;
    return Container(
      padding: EdgeInsets.fromLTRB(
        20,
        16,
        20,
        MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
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
                    color: Theme.of(context).dividerColor,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                'AI Auto-Budget Preview',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Generated from projected income, past transactions, and active goals.',
                style: GoogleFonts.inter(
                  color:
                      (Theme.of(context).textTheme.bodyMedium?.color ??
                      AppTheme.textSecondaryFor(context)),
                  height: 1.4,
                ),
              ),
              const SizedBox(height: 16),
              _SheetTotals(
                income: analytics.projectedIncome,
                totalAmount: total,
                remaining: (analytics.projectedIncome - total)
                    .clamp(0, double.infinity)
                    .toDouble(),
              ),
              if (!isValid) ...[
                const SizedBox(height: 12),
                const _ValidationBanner(
                  message:
                      'Suggestions exceed projected income and cannot apply.',
                ),
              ],
              const SizedBox(height: 16),
              if (suggestions.isEmpty)
                Text(
                  'Add income first so FinEase can generate a safe budget.',
                  style: GoogleFonts.inter(
                    color:
                        (Theme.of(context).textTheme.bodyMedium?.color ??
                        AppTheme.textSecondaryFor(context)),
                  ),
                )
              else
                ...suggestions.map(
                  (suggestion) => Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                suggestion.category,
                                style: GoogleFonts.plusJakartaSans(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                              Text(
                                suggestion.reason,
                                style: GoogleFonts.inter(
                                  color: const Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          CurrencyUtils.format(suggestion.amount),
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.primary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: isValid && suggestions.isNotEmpty ? onApply : null,
                  icon: Icon(Icons.check_rounded),
                  label: const Text('Apply Suggested Budget'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
