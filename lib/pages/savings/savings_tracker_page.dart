import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/budget_plan.dart';
import '../../models/saving_goal.dart';
import '../../models/transaction.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';
import '../budget/ai_budget_advisor_page.dart';

enum _SavingsPeriodMode { daily, weekly, monthly, yearly }

class SavingsTrackerPage extends StatefulWidget {
  const SavingsTrackerPage({super.key});

  @override
  State<SavingsTrackerPage> createState() => _SavingsTrackerPageState();
}

class _SavingsTrackerPageState extends State<SavingsTrackerPage> {
  bool _rolloverChecked = false;
  _SavingsPeriodMode _periodMode = _SavingsPeriodMode.monthly;
  DateTime _anchorDate = DateTime.now();

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.watch<AuthService>().firestoreService;
    const primaryColor = AppTheme.primary;

    if (firestoreService == null) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    _scheduleRollover(context, firestoreService);
    final period = _SavingsPeriod.from(_periodMode, _anchorDate);

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: StreamBuilder<List<SavingGoal>>(
        stream: firestoreService.getSavingGoals(),
        builder: (context, goalSnapshot) {
          final goals = goalSnapshot.data ?? const <SavingGoal>[];
          return StreamBuilder<List<FinancialTransaction>>(
            stream: firestoreService.getTransactions(),
            builder: (context, transactionSnapshot) {
              final transactions =
                  transactionSnapshot.data ?? const <FinancialTransaction>[];
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
                      final analytics = _SavingsAnalytics.from(
                        goals: goals,
                        transactions: transactions,
                        profile: profile,
                        budgets: budgets,
                        period: period,
                      );

                      return CustomScrollView(
                        physics: const BouncingScrollPhysics(),
                        slivers: [
                          const _SavingsAppBar(),
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(20, 24, 20, 120),
                            sliver: SliverList(
                              delegate: SliverChildListDelegate([
                                _TotalSavingsCard(analytics: analytics),
                                const SizedBox(height: 16),
                                _SavingsPeriodSwitcher(
                                  period: period,
                                  mode: _periodMode,
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
                                const SizedBox(height: 16),
                                _HealthBreakdownCard(analytics: analytics),
                                const SizedBox(height: 16),
                                _NarrativeCard(analytics: analytics),
                                const SizedBox(height: 16),
                                _QuickActions(
                                  onNewJourney: () => _showGoalEditor(
                                    context,
                                    firestoreService: firestoreService,
                                    analytics: analytics,
                                  ),
                                  onWhatIf: () => _showWhatIfSheet(
                                    context,
                                    analytics: analytics,
                                  ),
                                  onAutoBudget: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) =>
                                          const AIBudgetAdvisorPage(),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _SectionHeader(
                                  title: 'Progress Charts',
                                  actionLabel: 'Timeline',
                                  onTap: () => _showTimelineSheet(
                                    context,
                                    analytics: analytics,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                _MomentumChart(analytics: analytics),
                                const SizedBox(height: 24),
                                _SectionHeader(
                                  title: 'Active Journeys',
                                  actionLabel: 'Add Journey',
                                  onTap: () => _showGoalEditor(
                                    context,
                                    firestoreService: firestoreService,
                                    analytics: analytics,
                                  ),
                                ),
                                const SizedBox(height: 12),
                                if (goals.isEmpty)
                                  _EmptyState(
                                    onPressed: () => _showGoalEditor(
                                      context,
                                      firestoreService: firestoreService,
                                      analytics: analytics,
                                    ),
                                  )
                                else
                                  ...goals.map(
                                    (goal) => Padding(
                                      padding: const EdgeInsets.only(
                                        bottom: 16,
                                      ),
                                      child: _JourneyCard(
                                        goal: goal,
                                        analytics: analytics,
                                        onEdit: () => _showGoalEditor(
                                          context,
                                          firestoreService: firestoreService,
                                          analytics: analytics,
                                          existingGoal: goal,
                                        ),
                                        onDelete: () => firestoreService
                                            .deleteSavingGoal(goal.id),
                                        onContribute: () =>
                                            _showContributionDialog(
                                              context,
                                              firestoreService,
                                              goal,
                                              analytics,
                                            ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 8),
                                _BehaviorTriggers(analytics: analytics),
                              ]),
                            ),
                          ),
                        ],
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final goals = await firestoreService.getSavingGoals().first;
          final txns = await firestoreService.getTransactions().first;
          final profile = await firestoreService.getUserProfile().first;
          final budgets = await firestoreService
              .getBudgetPlans(monthKey: _monthKey(DateTime.now()))
              .first;
          final period = _SavingsPeriod.from(_periodMode, _anchorDate);
          if (!context.mounted) return;
          _showGoalEditor(
            context,
            firestoreService: firestoreService,
            analytics: _SavingsAnalytics.from(
              goals: goals,
              transactions: txns,
              profile: profile,
              budgets: budgets,
              period: period,
            ),
          );
        },
        backgroundColor: primaryColor,
        icon: Icon(Icons.add_rounded, color: Colors.white),
        label: Text(
          'New Journey',
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  void _scheduleRollover(
    BuildContext context,
    FirestoreService firestoreService,
  ) {
    if (_rolloverChecked) return;
    _rolloverChecked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      firestoreService.ensureMonthlySavingsRollover();
      final now = DateTime.now();
      final previous = DateTime(now.year, now.month - 1);
      final periodKey = _monthKey(previous);
      final leftover = await firestoreService.previewBudgetLeftover(
        periodType: 'monthly',
        periodKey: periodKey,
      );
      if (!context.mounted || leftover <= 0) return;
      final approved = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Carry leftover budget into Savings?'),
          content: Text(
            '${CurrencyUtils.format(leftover)} is left from last month. Move it to Savings and log the transfer?',
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
        periodType: 'monthly',
        periodKey: periodKey,
        periodEnd: DateTime(now.year, now.month),
      );
    });
  }
}

String _monthKey(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}';
}

class _SavingsPeriod {
  const _SavingsPeriod({
    required this.mode,
    required this.key,
    required this.label,
    required this.start,
    required this.end,
  });

  final _SavingsPeriodMode mode;
  final String key;
  final String label;
  final DateTime start;
  final DateTime end;

  factory _SavingsPeriod.from(_SavingsPeriodMode mode, DateTime anchor) {
    switch (mode) {
      case _SavingsPeriodMode.daily:
        final start = DateTime(anchor.year, anchor.month, anchor.day);
        return _SavingsPeriod(
          mode: mode,
          key:
              '${anchor.year}-${anchor.month.toString().padLeft(2, '0')}-${anchor.day.toString().padLeft(2, '0')}',
          label: DateFormat('MMM dd, yyyy').format(anchor),
          start: start,
          end: start.add(const Duration(days: 1)),
        );
      case _SavingsPeriodMode.weekly:
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
        return _SavingsPeriod(
          mode: mode,
          key: '${anchor.year}-W${week.toString().padLeft(2, '0')}',
          label:
              '${DateFormat('MMM dd').format(start)} - ${DateFormat('MMM dd').format(start.add(const Duration(days: 6)))}',
          start: start,
          end: start.add(const Duration(days: 7)),
        );
      case _SavingsPeriodMode.yearly:
        final start = DateTime(anchor.year);
        return _SavingsPeriod(
          mode: mode,
          key: '${anchor.year}',
          label: '${anchor.year}',
          start: start,
          end: DateTime(anchor.year + 1),
        );
      case _SavingsPeriodMode.monthly:
        final start = DateTime(anchor.year, anchor.month);
        return _SavingsPeriod(
          mode: mode,
          key: _monthKey(anchor),
          label: DateFormat('MMMM yyyy').format(anchor),
          start: start,
          end: DateTime(anchor.year, anchor.month + 1),
        );
    }
  }

  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);

  DateTime shift(_SavingsPeriodMode mode, int step) {
    switch (mode) {
      case _SavingsPeriodMode.daily:
        return start.add(Duration(days: step));
      case _SavingsPeriodMode.weekly:
        return start.add(Duration(days: step * 7));
      case _SavingsPeriodMode.monthly:
        return DateTime(start.year, start.month + step);
      case _SavingsPeriodMode.yearly:
        return DateTime(start.year + step);
    }
  }
}

class _SavingsAnalytics {
  const _SavingsAnalytics({
    required this.goals,
    required this.transactions,
    required this.budgets,
    required this.profileSavings,
    required this.monthlyIncome,
    required this.totalBudgeted,
    required this.totalExpenses,
    required this.totalSaved,
    required this.totalTarget,
    required this.monthlyNeed,
    required this.monthlySavingsTransfers,
    required this.period,
  });

  final List<SavingGoal> goals;
  final List<FinancialTransaction> transactions;
  final List<BudgetPlan> budgets;
  final double profileSavings;
  final double monthlyIncome;
  final double totalBudgeted;
  final double totalExpenses;
  final double totalSaved;
  final double totalTarget;
  final double monthlyNeed;
  final double monthlySavingsTransfers;
  final _SavingsPeriod period;

  factory _SavingsAnalytics.from({
    required List<SavingGoal> goals,
    required List<FinancialTransaction> transactions,
    required Map<String, dynamic> profile,
    required List<BudgetPlan> budgets,
    required _SavingsPeriod period,
  }) {
    final periodTransactions = transactions
        .where((txn) => period.contains(txn.date))
        .toList();
    final totalSaved = goals.fold<double>(
      0,
      (total, goal) => total + goal.currentAmount,
    );
    final totalTarget = goals.fold<double>(
      0,
      (total, goal) => total + goal.targetAmount,
    );
    final monthlyNeed = goals.fold<double>(
      0,
      (total, goal) => total + goal.monthlyTarget,
    );
    final totalBudgeted = budgets.fold<double>(
      0,
      (total, budget) => total + budget.allocatedAmount,
    );
    final totalExpenses = periodTransactions
        .where((txn) => txn.type == 'expense')
        .fold<double>(0, (total, txn) => total + txn.amount);
    final periodIncome = periodTransactions
        .where((txn) => txn.type == 'income')
        .fold<double>(0, (total, txn) => total + txn.amount);
    final profileIncome = ((profile['monthlyIncome'] ?? 0) as num).toDouble();
    final profileSavings =
        ((profile['savingsBalance'] ?? 0) as num).toDouble() +
        ((profile['extraSavingsBalance'] ?? 0) as num).toDouble();
    final monthlySavingsTransfers = periodTransactions
        .where(
          (txn) =>
              txn.type == 'transfer' &&
              (txn.category == 'Savings' ||
                  (txn.transferDirection ?? '').contains('savings')),
        )
        .fold<double>(0, (total, txn) => total + txn.amount);
    return _SavingsAnalytics(
      goals: goals,
      transactions: transactions,
      budgets: budgets,
      profileSavings: profileSavings,
      monthlyIncome: periodIncome > 0
          ? periodIncome
          : _scaledIncome(profileIncome, period.mode),
      totalBudgeted: totalBudgeted,
      totalExpenses: totalExpenses,
      totalSaved: totalSaved,
      totalTarget: totalTarget,
      monthlyNeed: monthlyNeed,
      monthlySavingsTransfers: monthlySavingsTransfers,
      period: period,
    );
  }

  static double _scaledIncome(double monthlyIncome, _SavingsPeriodMode mode) {
    switch (mode) {
      case _SavingsPeriodMode.daily:
        return monthlyIncome / 30;
      case _SavingsPeriodMode.weekly:
        return monthlyIncome / 4.345;
      case _SavingsPeriodMode.yearly:
        return monthlyIncome * 12;
      case _SavingsPeriodMode.monthly:
        return monthlyIncome;
    }
  }

  double get overallProgress =>
      totalTarget <= 0 ? 0 : (totalSaved / totalTarget).clamp(0.0, 1.0);
  double get remainingBudget => (monthlyIncome - totalBudgeted - totalExpenses)
      .clamp(0, double.infinity)
      .toDouble();
  double get savingsCapacity =>
      math.min(profileSavings, remainingBudget + profileSavings);
  bool get isOverAllocated =>
      profileSavings > 0 && totalSaved > profileSavings + 0.01;
  bool get goalPlanTooAggressive =>
      remainingBudget > 0 && monthlyNeed > remainingBudget;
  double get recommendedSavingsRate =>
      monthlyIncome <= 0 ? 0 : (monthlyNeed / monthlyIncome) * 100;
  int get activeJourneys => goals.where((goal) => goal.remaining > 0).length;
  int get debtJourneys => goals.where((goal) => goal.isDebtGoal).length;
  double get velocity {
    final cutoff = DateTime.now().subtract(const Duration(days: 30));
    final recent = transactions
        .where(
          (txn) =>
              txn.date.isAfter(cutoff) &&
              txn.type == 'transfer' &&
              (txn.transferDirection ?? '').contains('goal'),
        )
        .fold<double>(0, (total, txn) => total + txn.amount);
    return recent;
  }

  int get healthScore {
    var score = 100;
    if (isOverAllocated) score -= 25;
    if (goalPlanTooAggressive) score -= 18;
    if (monthlyIncome > 0) {
      score -= ((totalExpenses / monthlyIncome).clamp(0.0, 1.3) * 25).round();
      score += (recommendedSavingsRate.clamp(0, 20) / 2).round();
    }
    if (activeJourneys == 0) score -= 8;
    if (velocity <= 0 && activeJourneys > 0) score -= 8;
    return score.clamp(0, 100);
  }

  List<FlSpot> get momentumSpots {
    final now = DateTime.now();
    final spots = <FlSpot>[];
    for (var i = 5; i >= 0; i--) {
      final date = DateTime(now.year, now.month - i);
      final amount = transactions
          .where(
            (txn) =>
                txn.date.year == date.year &&
                txn.date.month == date.month &&
                txn.type == 'transfer' &&
                (txn.transferDirection ?? '').contains('goal'),
          )
          .fold<double>(0, (total, txn) => total + txn.amount);
      spots.add(FlSpot((5 - i).toDouble(), amount));
    }
    return spots;
  }
}

class _SavingsAppBar extends StatelessWidget {
  const _SavingsAppBar();

  @override
  Widget build(BuildContext context) {
    const primaryColor = AppTheme.primary;
    const accentColor = AppTheme.secondary;
    return SliverAppBar(
      expandedHeight: 150,
      pinned: true,
      backgroundColor: primaryColor,
      flexibleSpace: FlexibleSpaceBar(
        titlePadding: const EdgeInsets.only(left: 20, bottom: 18),
        title: Text(
          'Savings Journeys',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w800,
            color: Colors.white,
          ),
        ),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Container(color: primaryColor),
            Positioned(
              right: -24,
              top: -24,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: accentColor.withValues(alpha: 0.12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SavingsPeriodSwitcher extends StatelessWidget {
  const _SavingsPeriodSwitcher({
    required this.period,
    required this.mode,
    required this.onPrevious,
    required this.onNext,
    required this.onModeChanged,
  });

  final _SavingsPeriod period;
  final _SavingsPeriodMode mode;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<_SavingsPeriodMode> onModeChanged;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
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
                    fontSize: 16,
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
            children: _SavingsPeriodMode.values
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
                                : Theme.of(
                                    context,
                                  ).colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            item.name[0].toUpperCase() + item.name.substring(1),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.inter(
                              color: mode == item
                                  ? Colors.white
                                  : (Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color ??
                                        AppTheme.textSecondaryFor(context)),
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

class _TotalSavingsCard extends StatelessWidget {
  const _TotalSavingsCard({required this.analytics});

  final _SavingsAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.onSurface,
        borderRadius: BorderRadius.circular(30),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saved across financial journeys',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.7),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            CurrencyUtils.format(analytics.totalSaved),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 36,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: analytics.overallProgress,
              minHeight: 10,
              backgroundColor: Colors.white.withValues(alpha: 0.08),
              color: const Color(0xFF1BFFFF),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            '${(analytics.overallProgress * 100).round()}% of ${CurrencyUtils.format(analytics.totalTarget)} total journey targets funded.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _SummaryPill(
                  label: 'Active journeys',
                  value: '${analytics.activeJourneys}',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _SummaryPill(
                  label: 'Monthly need',
                  value: CurrencyUtils.format(analytics.monthlyNeed),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HealthBreakdownCard extends StatelessWidget {
  const _HealthBreakdownCard({required this.analytics});

  final _SavingsAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return _InfoCard(
      child: Column(
        children: [
          _SignalRow(
            icon: Icons.health_and_safety_rounded,
            title: 'Financial Health Score',
            value: '${analytics.healthScore}/100',
            body:
                'Savings, budget capacity, spending load, and journey velocity combined.',
          ),
          const SizedBox(height: 14),
          _SignalRow(
            icon: Icons.account_balance_wallet_rounded,
            title: 'Remaining Budget',
            value: CurrencyUtils.format(analytics.remainingBudget),
            body: 'Used to validate whether new journeys are feasible.',
          ),
          const SizedBox(height: 14),
          _SignalRow(
            icon: Icons.savings_rounded,
            title: 'Savings Pool',
            value: CurrencyUtils.format(analytics.profileSavings),
            body: analytics.isOverAllocated
                ? 'Savings are over-allocated. Pause new allocations.'
                : 'Available savings are within journey allocation limits.',
          ),
        ],
      ),
    );
  }
}

class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({required this.analytics});

  final _SavingsAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final warning =
        analytics.isOverAllocated || analytics.goalPlanTooAggressive;
    return _InfoCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            warning ? Icons.warning_amber_rounded : Icons.auto_awesome_rounded,
            color: warning ? const Color(0xFFF97316) : AppTheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Weekly savings narrative',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _message(),
                  style: GoogleFonts.inter(
                    color: const Color(0xFF475569),
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

  String _message() {
    if (analytics.activeJourneys == 0) {
      return 'Start a journey and FinEase will split it into monthly milestones that stay connected to your budget.';
    }
    if (analytics.isOverAllocated) {
      return 'Savings are stretched across too many allocations. Rebalance journeys before adding more contributions.';
    }
    if (analytics.goalPlanTooAggressive) {
      return 'Your dreams are ambitious. Extend a deadline or reduce a category budget to keep the plan calm.';
    }
    if (analytics.velocity > 0) {
      return 'Momentum is alive. Recent contributions are moving journeys forward and keeping your timeline realistic.';
    }
    return 'A small contribution this week would restart momentum and keep milestones within reach.';
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.onNewJourney,
    required this.onWhatIf,
    required this.onAutoBudget,
  });

  final VoidCallback onNewJourney;
  final VoidCallback onWhatIf;
  final VoidCallback onAutoBudget;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionButton(
            icon: Icons.add_rounded,
            label: 'New Journey',
            onTap: onNewJourney,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.psychology_rounded,
            label: 'What If',
            onTap: onWhatIf,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionButton(
            icon: Icons.auto_awesome_rounded,
            label: 'Auto-Budget',
            onTap: onAutoBudget,
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppTheme.surfaceFor(context),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.primary),
            const SizedBox(width: 8),
            Flexible(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    required this.actionLabel,
    required this.onTap,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        TextButton(onPressed: onTap, child: Text(actionLabel)),
      ],
    );
  }
}

class _MomentumChart extends StatelessWidget {
  const _MomentumChart({required this.analytics});

  final _SavingsAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final spots = analytics.momentumSpots;
    final maxY = math.max(
      1,
      spots.fold<double>(0, (max, spot) => math.max(max, spot.y)),
    );
    return _InfoCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Saving Momentum',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 170,
            child: LineChart(
              LineChartData(
                minY: 0,
                maxY: maxY * 1.2,
                gridData: FlGridData(
                  drawVerticalLine: false,
                  getDrawingHorizontalLine: (_) => FlLine(
                    color: Theme.of(context).dividerColor,
                    strokeWidth: 1,
                  ),
                ),
                titlesData: const FlTitlesData(show: false),
                borderData: FlBorderData(show: false),
                lineBarsData: [
                  LineChartBarData(
                    spots: spots,
                    isCurved: true,
                    color: AppTheme.primary,
                    barWidth: 4,
                    dotData: const FlDotData(show: true),
                    belowBarData: BarAreaData(
                      show: true,
                      color: AppTheme.primary.withValues(alpha: 0.10),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  const _JourneyCard({
    required this.goal,
    required this.analytics,
    required this.onEdit,
    required this.onDelete,
    required this.onContribute,
  });

  final SavingGoal goal;
  final _SavingsAnalytics analytics;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onContribute;

  @override
  Widget build(BuildContext context) {
    final urgent =
        goal.reminderDate != null &&
        goal.reminderDate!.difference(DateTime.now()).inDays <= 5;
    final milestoneText = goal.milestones.isEmpty
        ? 'Milestones will appear after saving.'
        : '${goal.completedMilestones}/${goal.milestones.length} milestones complete';
    return _InfoCard(
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
                            goal.title,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ),
                        if (goal.isDebtGoal)
                          const _MiniTag(
                            label: 'Debt',
                            color: Color(0xFFF97316),
                          ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Text(
                      '${goal.goalType} - ${goal.daysLeft} days left',
                      style: GoogleFonts.inter(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (value) {
                  if (value == 'edit') onEdit();
                  if (value == 'delete') onDelete();
                  if (value == 'contribute') onContribute();
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: 'contribute',
                    child: Text('Add Contribution'),
                  ),
                  PopupMenuItem(value: 'edit', child: Text('Edit Journey')),
                  PopupMenuItem(value: 'delete', child: Text('Delete Journey')),
                ],
              ),
            ],
          ),
          if (goal.reminderDate != null) ...[
            const SizedBox(height: 10),
            Text(
              '${urgent ? 'Urgent: ' : ''}Reminder ${DateFormat('MMM dd').format(goal.reminderDate!)}',
              style: GoogleFonts.inter(
                color: urgent ? const Color(0xFFF97316) : AppTheme.primary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                '${CurrencyUtils.format(goal.currentAmount)} saved',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppTheme.primary,
                ),
              ),
              Text(
                'Target ${CurrencyUtils.format(goal.targetAmount)}',
                style: GoogleFonts.inter(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF334155),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 8,
              backgroundColor: const Color(0xFFF1F5F9),
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            milestoneText,
            style: GoogleFonts.inter(
              color: const Color(0xFF059669),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _journeyMessage(goal, analytics),
            style: GoogleFonts.inter(
              color: const Color(0xFF475569),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 14),
          ElevatedButton.icon(
            onPressed: onContribute,
            icon: Icon(Icons.savings_rounded),
            label: const Text('Add Contribution'),
          ),
        ],
      ),
    );
  }

  String _journeyMessage(SavingGoal goal, _SavingsAnalytics analytics) {
    if (goal.progress >= 1) {
      return 'Milestone complete. Celebrate this win and choose the next journey.';
    }
    if (goal.monthlyTarget > analytics.remainingBudget &&
        analytics.remainingBudget > 0) {
      return 'This journey is tight against the current budget. Extend the date or free up budget room.';
    }
    if (goal.isDebtGoal) {
      return 'Debt payoff strategy: ${goal.payoffStrategy}. Keep reminders active to avoid missed payments.';
    }
    return 'Monthly target ${CurrencyUtils.format(goal.monthlyTarget)} keeps this journey on schedule.';
  }
}

class _BehaviorTriggers extends StatelessWidget {
  const _BehaviorTriggers({required this.analytics});

  final _SavingsAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final messages = <String>[
      if (analytics.isOverAllocated)
        'Savings cannot be over-allocated. Rebalance journeys before contributing more.',
      if (analytics.goalPlanTooAggressive)
        'Gentle nudge: journey targets are above remaining budget. A later deadline can make this easier.',
      if (analytics.velocity <= 0 && analytics.activeJourneys > 0)
        'A small contribution this week would restart your saving streak.',
      if (analytics.monthlySavingsTransfers > 0)
        'Nice movement: Savings-related transactions are flowing into your journey system.',
    ];
    if (messages.isEmpty) return const SizedBox.shrink();
    return Column(
      children: messages
          .map(
            (message) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _InfoCard(
                child: Text(
                  message,
                  style: GoogleFonts.inter(
                    color: const Color(0xFF475569),
                    height: 1.45,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ),
          )
          .toList(),
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
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFEEF2FF),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(icon, color: AppTheme.primary),
        ),
        const SizedBox(width: 16),
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
                        fontSize: 16,
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
              const SizedBox(height: 6),
              Text(
                body,
                style: GoogleFonts.inter(
                  color: const Color(0xFF475569),
                  height: 1.45,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: child,
    );
  }
}

class _MiniTag extends StatelessWidget {
  const _MiniTag({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
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

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(30),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Icon(Icons.savings_rounded, size: 56, color: AppTheme.primary),
          const SizedBox(height: 16),
          Text(
            'No financial journeys yet',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 22,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Create a journey to track milestones, projected timelines, savings velocity, and budget feasibility.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: Colors.grey[600], height: 1.5),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: onPressed,
            child: const Text('Create Journey'),
          ),
        ],
      ),
    );
  }
}

Future<void> _showGoalEditor(
  BuildContext context, {
  required FirestoreService firestoreService,
  required _SavingsAnalytics analytics,
  SavingGoal? existingGoal,
}) async {
  final titleController = TextEditingController(
    text: existingGoal?.title ?? '',
  );
  final targetController = TextEditingController(
    text: existingGoal?.targetAmount.toStringAsFixed(0) ?? '',
  );
  final currentController = TextEditingController(
    text: existingGoal?.currentAmount.toStringAsFixed(0) ?? '0',
  );
  var targetDate =
      existingGoal?.targetDate ?? DateTime.now().add(const Duration(days: 180));
  var goalType = existingGoal?.goalType ?? 'Emergency Fund';
  var payoffStrategy = existingGoal?.payoffStrategy ?? 'steady';
  var isDebtGoal = existingGoal?.isDebtGoal ?? false;
  DateTime? reminderDate = existingGoal?.reminderDate;
  final goalTypes = [
    'Emergency Fund',
    'Vacation',
    'Debt Payoff',
    'House',
    'Education',
    'Investment',
    'General',
  ];

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) {
      return StatefulBuilder(
        builder: (context, setModalState) {
          final target = double.tryParse(targetController.text.trim()) ?? 0;
          final current = double.tryParse(currentController.text.trim()) ?? 0;
          final draft = SavingGoal(
            id: existingGoal?.id ?? '',
            title: titleController.text.trim(),
            targetAmount: target,
            currentAmount: current,
            targetDate: targetDate,
            category: goalType,
            goalType: goalType,
            isDebtGoal: isDebtGoal || goalType == 'Debt Payoff',
            payoffStrategy: payoffStrategy,
            reminderDate: reminderDate,
          );
          final monthlyTarget = draft.monthlyTarget;
          final allocationWarning =
              analytics.profileSavings > 0 &&
              analytics.totalSaved -
                      (existingGoal?.currentAmount ?? 0) +
                      current >
                  analytics.profileSavings;
          final budgetWarning =
              analytics.remainingBudget > 0 &&
              monthlyTarget > analytics.remainingBudget;
          final invalid =
              target <= 0 ||
              current < 0 ||
              current > target ||
              allocationWarning ||
              budgetWarning;

          return Container(
            padding: EdgeInsets.fromLTRB(
              24,
              20,
              24,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            decoration: BoxDecoration(
              color: AppTheme.surfaceFor(context),
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    existingGoal == null ? 'Create Journey' : 'Edit Journey',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 24,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SheetMetricPanel(
                    income: analytics.monthlyIncome,
                    remainingBudget: analytics.remainingBudget,
                    monthlyTarget: monthlyTarget,
                  ),
                  const SizedBox(height: 14),
                  _field(
                    titleController,
                    'Journey title',
                    onChanged: () {
                      setModalState(() {});
                    },
                  ),
                  const SizedBox(height: 12),
                  _field(
                    targetController,
                    'Target amount',
                    isNumber: true,
                    onChanged: () => setModalState(() {}),
                  ),
                  const SizedBox(height: 12),
                  _field(
                    currentController,
                    'Current allocation',
                    isNumber: true,
                    onChanged: () => setModalState(() {}),
                  ),
                  const SizedBox(height: 12),
                  InkWell(
                    onTap: () async {
                      final picked = await showDatePicker(
                        context: context,
                        initialDate: targetDate,
                        firstDate: DateTime.now(),
                        lastDate: DateTime(2100),
                      );
                      if (picked != null) {
                        setModalState(() => targetDate = picked);
                      }
                    },
                    child: _PickerBox(
                      label:
                          'Target ${DateFormat('MMM dd, yyyy').format(targetDate)}',
                    ),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: goalTypes.map((item) {
                      final selected = item == goalType;
                      return ChoiceChip(
                        label: Text(item),
                        selected: selected,
                        onSelected: (_) => setModalState(() {
                          goalType = item;
                          isDebtGoal = item == 'Debt Payoff';
                        }),
                      );
                    }).toList(),
                  ),
                  const SizedBox(height: 12),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    value: isDebtGoal,
                    activeThumbColor: AppTheme.primary,
                    title: const Text('Debt management journey'),
                    onChanged: (value) => setModalState(() {
                      isDebtGoal = value;
                      if (value) goalType = 'Debt Payoff';
                    }),
                  ),
                  if (isDebtGoal) ...[
                    Wrap(
                      spacing: 8,
                      children: ['steady', 'snowball', 'avalanche'].map((item) {
                        return ChoiceChip(
                          label: Text(item),
                          selected: payoffStrategy == item,
                          onSelected: (_) =>
                              setModalState(() => payoffStrategy = item),
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 12),
                    InkWell(
                      onTap: () async {
                        final picked = await showDatePicker(
                          context: context,
                          initialDate: reminderDate ?? DateTime.now(),
                          firstDate: DateTime.now(),
                          lastDate: DateTime(2100),
                        );
                        if (picked != null) {
                          setModalState(() => reminderDate = picked);
                        }
                      },
                      child: _PickerBox(
                        label: reminderDate == null
                            ? 'Add debt payment reminder'
                            : 'Reminder ${DateFormat('MMM dd, yyyy').format(reminderDate!)}',
                      ),
                    ),
                  ],
                  if (allocationWarning || budgetWarning) ...[
                    const SizedBox(height: 12),
                    _ValidationBanner(
                      message: allocationWarning
                          ? 'Savings cannot be over-allocated. Reduce current allocation or add savings first.'
                          : 'Monthly target is above remaining budget. Adjust budget or choose a later date.',
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: invalid
                          ? null
                          : () async {
                              final goal = draft.copyWith(
                                milestones: JourneyMilestone.generate(
                                  targetAmount: target,
                                  currentAmount: current,
                                  targetDate: targetDate,
                                ),
                              );
                              try {
                                if (existingGoal == null) {
                                  await firestoreService.addSavingGoal(goal);
                                } else {
                                  await firestoreService.updateSavingGoal(
                                    existingGoal.id,
                                    goal.toMap(),
                                  );
                                }
                                if (context.mounted) Navigator.pop(context);
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
                            },
                      child: Text(
                        existingGoal == null
                            ? 'Save Journey'
                            : 'Update Journey',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    },
  );
}

Future<void> _showContributionDialog(
  BuildContext context,
  FirestoreService firestoreService,
  SavingGoal goal,
  _SavingsAnalytics analytics,
) async {
  final controller = TextEditingController();
  await showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Add contribution to ${goal.title}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available savings pool: ${CurrencyUtils.format(analytics.profileSavings)}',
          ),
          const SizedBox(height: 12),
          TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Amount in PKR'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () async {
            try {
              await firestoreService.addContribution(
                goal.id,
                double.tryParse(controller.text.trim()) ?? 0,
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      goal.progress >= 1
                          ? 'Milestone celebrated'
                          : 'Contribution added to journey',
                    ),
                    backgroundColor: const Color(0xFF059669),
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
          },
          child: const Text('Add'),
        ),
      ],
    ),
  );
}

void _showWhatIfSheet(
  BuildContext context, {
  required _SavingsAnalytics analytics,
}) {
  final incomeCtrl = TextEditingController();
  final expenseCtrl = TextEditingController();
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (context) => StatefulBuilder(
      builder: (context, setModalState) {
        final extraIncome = double.tryParse(incomeCtrl.text.trim()) ?? 0;
        final extraExpense = double.tryParse(expenseCtrl.text.trim()) ?? 0;
        final futureIncome = analytics.monthlyIncome + extraIncome;
        final futureBudget =
            (analytics.remainingBudget + extraIncome - extraExpense)
                .clamp(0, double.infinity)
                .toDouble();
        final futureRate = futureIncome <= 0
            ? 0.0
            : (analytics.monthlyNeed / futureIncome) * 100;
        return Container(
          padding: EdgeInsets.fromLTRB(
            24,
            20,
            24,
            MediaQuery.of(context).viewInsets.bottom + 24,
          ),
          decoration: BoxDecoration(
            color: AppTheme.surfaceFor(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'What If Simulation',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 24,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 14),
                _field(
                  incomeCtrl,
                  'Income increase',
                  isNumber: true,
                  onChanged: () => setModalState(() {}),
                ),
                const SizedBox(height: 12),
                _field(
                  expenseCtrl,
                  'Extra expense',
                  isNumber: true,
                  onChanged: () => setModalState(() {}),
                ),
                const SizedBox(height: 16),
                _SheetMetricPanel(
                  income: futureIncome,
                  remainingBudget: futureBudget,
                  monthlyTarget: analytics.monthlyNeed,
                  savingsRate: futureRate,
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}

void _showTimelineSheet(
  BuildContext context, {
  required _SavingsAnalytics analytics,
}) {
  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    builder: (context) => Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Financial Timeline',
              style: GoogleFonts.plusJakartaSans(
                fontSize: 24,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            if (analytics.goals.isEmpty)
              Text(
                'Create journeys to see projected milestones.',
                style: GoogleFonts.inter(color: const Color(0xFF475569)),
              )
            else
              ...analytics.goals
                  .take(6)
                  .map(
                    (goal) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _SignalRow(
                        icon: goal.isDebtGoal
                            ? Icons.credit_card_rounded
                            : Icons.flag_rounded,
                        title: goal.title,
                        value: DateFormat('MMM yyyy').format(goal.targetDate),
                        body:
                            '${CurrencyUtils.format(goal.remaining)} remaining, ${CurrencyUtils.format(goal.monthlyTarget)} monthly target.',
                      ),
                    ),
                  ),
          ],
        ),
      ),
    ),
  );
}

Widget _field(
  TextEditingController controller,
  String label, {
  bool isNumber = false,
  VoidCallback? onChanged,
}) {
  return TextField(
    controller: controller,
    keyboardType: isNumber ? TextInputType.number : TextInputType.text,
    onChanged: (_) => onChanged?.call(),
    decoration: InputDecoration(labelText: label),
  );
}

class _PickerBox extends StatelessWidget {
  const _PickerBox({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Icon(
            Icons.calendar_month_rounded,
            color: AppTheme.primary,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _SheetMetricPanel extends StatelessWidget {
  const _SheetMetricPanel({
    required this.income,
    required this.remainingBudget,
    required this.monthlyTarget,
    this.savingsRate,
  });

  final double income;
  final double remainingBudget;
  final double monthlyTarget;
  final double? savingsRate;

  @override
  Widget build(BuildContext context) {
    final rate =
        savingsRate ?? (income <= 0 ? 0 : (monthlyTarget / income) * 100);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          _metric('Income', CurrencyUtils.format(income)),
          _metric('Remaining budget', CurrencyUtils.format(remainingBudget)),
          _metric('Monthly target', CurrencyUtils.format(monthlyTarget)),
          _metric('Savings rate', '${rate.toStringAsFixed(0)}%'),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: GoogleFonts.inter(
                color: const Color(0xFF475569),
                fontWeight: FontWeight.w600,
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

class _SummaryPill extends StatelessWidget {
  const _SummaryPill({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
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
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
