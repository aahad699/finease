import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../models/budget_plan.dart';
import '../../models/saving_goal.dart';
import '../../models/transaction.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';
import '../budget/ai_budget_advisor_page.dart';
import 'add_transaction_page.dart';

enum _PeriodMode { daily, weekly, monthly, yearly }

class AllTransactionsPage extends StatefulWidget {
  const AllTransactionsPage({super.key});

  @override
  State<AllTransactionsPage> createState() => _AllTransactionsPageState();
}

class _AllTransactionsPageState extends State<AllTransactionsPage> {
  String _typeFilter = 'all';
  String _categoryFilter = 'all';
  String _searchQuery = '';
  _PeriodMode _periodMode = _PeriodMode.monthly;
  DateTime _anchorDate = DateTime.now();
  final _searchCtrl = TextEditingController();

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);
    final fs = authService.firestoreService;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'Transactions',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: AppTheme.primary,
          onPressed: () => Navigator.pop(context),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(builder: (context) => const AddTransactionPage()),
        ),
        backgroundColor: AppTheme.primary,
        child: Icon(Icons.add_rounded, color: Colors.white),
      ),
      body: fs == null
          ? const Center(child: Text('Please log in'))
          : StreamBuilder<List<FinancialTransaction>>(
              stream: fs.getTransactions(),
              builder: (ctx, transactionSnap) {
                if (transactionSnap.connectionState ==
                    ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final allTransactions =
                    transactionSnap.data ?? const <FinancialTransaction>[];
                return StreamBuilder<List<SavingGoal>>(
                  stream: fs.getSavingGoals(),
                  builder: (context, goalSnap) {
                    return StreamBuilder<List<BudgetPlan>>(
                      stream: fs.getBudgetPlans(
                        monthKey: _monthKey(_anchorDate),
                      ),
                      builder: (context, budgetSnap) {
                        final goals = goalSnap.data ?? const <SavingGoal>[];
                        final budgets = budgetSnap.data ?? const <BudgetPlan>[];
                        final periodTransactions = allTransactions
                            .where((item) => _isInPeriod(item.date))
                            .toList();
                        final analytics = _TransactionAnalytics.from(
                          periodTransactions,
                          allTransactions,
                          budgets,
                          goals,
                          _periodMode,
                        );
                        final visibleTransactions = _applyFilters(
                          periodTransactions,
                        );
                        final categories = {
                          for (final txn in periodTransactions) txn.category,
                        }.where((item) => item.isNotEmpty).toList()..sort();

                        return Column(
                          children: [
                            Expanded(
                              child: CustomScrollView(
                                physics: const BouncingScrollPhysics(),
                                slivers: [
                                  SliverToBoxAdapter(
                                    child: Padding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        4,
                                        20,
                                        12,
                                      ),
                                      child: Column(
                                        children: [
                                          _PeriodSwitcher(
                                            mode: _periodMode,
                                            anchorDate: _anchorDate,
                                            onModeChanged: (mode) => setState(
                                              () => _periodMode = mode,
                                            ),
                                            onPrevious: () => setState(
                                              () => _anchorDate = _shiftPeriod(
                                                -1,
                                              ),
                                            ),
                                            onNext: () => setState(
                                              () =>
                                                  _anchorDate = _shiftPeriod(1),
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          _SummaryCards(analytics: analytics),
                                          const SizedBox(height: 14),
                                          _NarrativeCard(
                                            analytics: analytics,
                                            periodLabel: _periodLabel(),
                                          ),
                                          const SizedBox(height: 12),
                                          _AutoBudgetShortcut(
                                            onTap: () => Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    const AIBudgetAdvisorPage(),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(height: 14),
                                          TextField(
                                            controller: _searchCtrl,
                                            onChanged: (v) => setState(
                                              () => _searchQuery = v
                                                  .toLowerCase(),
                                            ),
                                            decoration: InputDecoration(
                                              hintText:
                                                  'Search transactions...',
                                              prefixIcon: Icon(
                                                Icons.search_rounded,
                                                color:
                                                    (Theme.of(context)
                                                        .textTheme
                                                        .bodyMedium
                                                        ?.color ??
                                                    AppTheme.textSecondaryFor(context)),
                                              ),
                                              suffixIcon:
                                                  _searchQuery.isNotEmpty
                                                  ? IconButton(
                                                      icon: Icon(
                                                        Icons.close_rounded,
                                                        size: 18,
                                                      ),
                                                      onPressed: () {
                                                        _searchCtrl.clear();
                                                        setState(
                                                          () =>
                                                              _searchQuery = '',
                                                        );
                                                      },
                                                    )
                                                  : null,
                                            ),
                                          ),
                                          const SizedBox(height: 12),
                                          _FilterBar(
                                            typeFilter: _typeFilter,
                                            categoryFilter: _categoryFilter,
                                            categories: categories,
                                            onTypeChanged: (value) => setState(
                                              () => _typeFilter = value,
                                            ),
                                            onCategoryChanged: (value) =>
                                                setState(
                                                  () => _categoryFilter = value,
                                                ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  if (visibleTransactions.isEmpty)
                                    SliverFillRemaining(
                                      hasScrollBody: false,
                                      child: Center(
                                        child: Text(
                                          'No transactions found',
                                          style: GoogleFonts.inter(
                                            color:
                                                (Theme.of(
                                                  context,
                                                ).textTheme.bodyMedium?.color ??
                                                AppTheme.textSecondaryFor(context)),
                                          ),
                                        ),
                                      ),
                                    )
                                  else
                                    SliverPadding(
                                      padding: const EdgeInsets.fromLTRB(
                                        20,
                                        0,
                                        20,
                                        96,
                                      ),
                                      sliver: SliverList.separated(
                                        itemCount: visibleTransactions.length,
                                        separatorBuilder: (context, index) =>
                                            const SizedBox(height: 8),
                                        itemBuilder: (context, index) =>
                                            _TransactionTile(
                                              transaction:
                                                  visibleTransactions[index],
                                              analytics: analytics,
                                            ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ],
                        );
                      },
                    );
                  },
                );
              },
            ),
    );
  }

  List<FinancialTransaction> _applyFilters(List<FinancialTransaction> txns) {
    var filtered = txns;
    if (_typeFilter != 'all') {
      filtered = filtered.where((t) => t.type == _typeFilter).toList();
    }
    if (_categoryFilter != 'all') {
      filtered = filtered.where((t) => t.category == _categoryFilter).toList();
    }
    if (_searchQuery.isNotEmpty) {
      filtered = filtered
          .where(
            (t) =>
                t.title.toLowerCase().contains(_searchQuery) ||
                t.category.toLowerCase().contains(_searchQuery) ||
                t.note.toLowerCase().contains(_searchQuery),
          )
          .toList();
    }
    return filtered;
  }

  bool _isInPeriod(DateTime date) {
    switch (_periodMode) {
      case _PeriodMode.daily:
        return date.year == _anchorDate.year &&
            date.month == _anchorDate.month &&
            date.day == _anchorDate.day;
      case _PeriodMode.weekly:
        final range = _weekRange(_anchorDate);
        return !date.isBefore(range.$1) && date.isBefore(range.$2);
      case _PeriodMode.monthly:
        return date.year == _anchorDate.year && date.month == _anchorDate.month;
      case _PeriodMode.yearly:
        return date.year == _anchorDate.year;
    }
  }

  DateTime _shiftPeriod(int step) {
    switch (_periodMode) {
      case _PeriodMode.daily:
        return _anchorDate.add(Duration(days: step));
      case _PeriodMode.weekly:
        return _anchorDate.add(Duration(days: 7 * step));
      case _PeriodMode.monthly:
        return DateTime(_anchorDate.year, _anchorDate.month + step);
      case _PeriodMode.yearly:
        return DateTime(_anchorDate.year + step);
    }
  }

  String _periodLabel() {
    switch (_periodMode) {
      case _PeriodMode.daily:
        return DateFormat('MMM dd, yyyy').format(_anchorDate);
      case _PeriodMode.weekly:
        final range = _weekRange(_anchorDate);
        return '${DateFormat('MMM dd').format(range.$1)} - ${DateFormat('MMM dd').format(range.$2.subtract(const Duration(days: 1)))}';
      case _PeriodMode.monthly:
        return DateFormat('MMMM yyyy').format(_anchorDate);
      case _PeriodMode.yearly:
        return '${_anchorDate.year}';
    }
  }

  (DateTime, DateTime) _weekRange(DateTime date) {
    final start = DateTime(
      date.year,
      date.month,
      date.day,
    ).subtract(Duration(days: date.weekday - DateTime.monday));
    return (start, start.add(const Duration(days: 7)));
  }

  String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }
}

class _TransactionAnalytics {
  const _TransactionAnalytics({
    required this.transactions,
    required this.allTransactions,
    required this.budgets,
    required this.goals,
    required this.mode,
    required this.income,
    required this.expenses,
    required this.transfers,
    required this.budgeted,
    required this.categorySpend,
    required this.healthScore,
  });

  final List<FinancialTransaction> transactions;
  final List<FinancialTransaction> allTransactions;
  final List<BudgetPlan> budgets;
  final List<SavingGoal> goals;
  final _PeriodMode mode;
  final double income;
  final double expenses;
  final double transfers;
  final double budgeted;
  final Map<String, double> categorySpend;
  final int healthScore;

  factory _TransactionAnalytics.from(
    List<FinancialTransaction> transactions,
    List<FinancialTransaction> allTransactions,
    List<BudgetPlan> budgets,
    List<SavingGoal> goals,
    _PeriodMode mode,
  ) {
    final income = transactions
        .where((txn) => txn.type == 'income')
        .fold<double>(0, (sum, txn) => sum + txn.amount);
    final expenses = transactions
        .where((txn) => txn.type == 'expense')
        .fold<double>(0, (sum, txn) => sum + txn.amount);
    final transfers = transactions
        .where((txn) => txn.type == 'transfer')
        .fold<double>(0, (sum, txn) => sum + txn.amount);
    final budgeted = budgets.fold<double>(
      0,
      (sum, budget) => sum + budget.allocatedAmount,
    );
    final categorySpend = <String, double>{};
    for (final txn in transactions.where((txn) => txn.type == 'expense')) {
      categorySpend[txn.category] =
          (categorySpend[txn.category] ?? 0) + txn.amount;
    }
    return _TransactionAnalytics(
      transactions: transactions,
      allTransactions: allTransactions,
      budgets: budgets,
      goals: goals,
      mode: mode,
      income: income,
      expenses: expenses,
      transfers: transfers,
      budgeted: budgeted,
      categorySpend: categorySpend,
      healthScore: _score(income, expenses, budgeted, goals),
    );
  }

  double get remainingBudget => (budgeted - expenses).clamp(0, double.infinity);
  double get balance => income - expenses;
  double get budgetProgress =>
      budgeted <= 0 ? 0 : (expenses / budgeted).clamp(0.0, 1.0);
  double get incomeProgress =>
      income <= 0 ? 0 : (expenses / income).clamp(0.0, 1.0);
  String get topCategory {
    if (categorySpend.isEmpty) return 'None yet';
    final entries = categorySpend.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.first.key;
  }

  bool overspentCategory(String category) {
    final budget = budgets
        .where((item) => item.category == category)
        .fold<double>(0, (total, item) => total + item.allocatedAmount);
    return budget > 0 && (categorySpend[category] ?? 0) > budget;
  }

  static int _score(
    double income,
    double expenses,
    double budget,
    List<SavingGoal> goals,
  ) {
    var score = 100;
    if (income > 0) {
      score -= ((expenses / income).clamp(0.0, 1.4) * 35).round();
    } else if (expenses > 0) {
      score -= 35;
    }
    if (budget > 0) {
      score -= ((expenses / budget).clamp(0.0, 1.4) * 25).round();
    }
    final activeGoals = goals.where((goal) => goal.remaining > 0).length;
    if (activeGoals == 0) score -= 8;
    return score.clamp(0, 100);
  }
}

class _PeriodSwitcher extends StatelessWidget {
  const _PeriodSwitcher({
    required this.mode,
    required this.anchorDate,
    required this.onModeChanged,
    required this.onPrevious,
    required this.onNext,
  });

  final _PeriodMode mode;
  final DateTime anchorDate;
  final ValueChanged<_PeriodMode> onModeChanged;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Column(
        children: [
          Row(
            children: [
              IconButton(
                onPressed: onPrevious,
                icon: Icon(Icons.chevron_left_rounded),
              ),
              Expanded(
                child: Text(
                  _label(),
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
                      child: _PeriodButton(
                        label:
                            item.name[0].toUpperCase() + item.name.substring(1),
                        selected: mode == item,
                        onTap: () => onModeChanged(item),
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

  String _label() {
    switch (mode) {
      case _PeriodMode.daily:
        return DateFormat('MMM dd, yyyy').format(anchorDate);
      case _PeriodMode.weekly:
        final start = DateTime(
          anchorDate.year,
          anchorDate.month,
          anchorDate.day,
        ).subtract(Duration(days: anchorDate.weekday - DateTime.monday));
        final end = start.add(const Duration(days: 6));
        return '${DateFormat('MMM dd').format(start)} - ${DateFormat('MMM dd').format(end)}';
      case _PeriodMode.monthly:
        return DateFormat('MMMM yyyy').format(anchorDate);
      case _PeriodMode.yearly:
        return '${anchorDate.year}';
    }
  }
}

class _PeriodButton extends StatelessWidget {
  const _PeriodButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(vertical: 9),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary
              : Theme.of(context).colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w700,
            color: selected
                ? Colors.white
                : (Theme.of(context).textTheme.bodyMedium?.color ??
                      AppTheme.textSecondaryFor(context)),
          ),
        ),
      ),
    );
  }
}

class _SummaryCards extends StatelessWidget {
  const _SummaryCards({required this.analytics});

  final _TransactionAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              _SummaryItem(
                label: 'Income',
                value: CurrencyUtils.format(analytics.income),
                color: AppTheme.success,
              ),
              _SummaryItem(
                label: 'Expenses',
                value: CurrencyUtils.format(analytics.expenses),
                color: AppTheme.error,
              ),
              _SummaryItem(
                label: 'Balance',
                value: CurrencyUtils.format(analytics.balance),
                color: analytics.balance >= 0
                    ? AppTheme.primary
                    : AppTheme.error,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _ProgressLine(
            label: 'Income vs Expenses',
            value: analytics.incomeProgress,
            color: analytics.incomeProgress >= 0.95
                ? AppTheme.error
                : AppTheme.primary,
          ),
          const SizedBox(height: 10),
          _ProgressLine(
            label:
                'Budget remaining ${CurrencyUtils.format(analytics.remainingBudget)}',
            value: analytics.budgetProgress,
            color: analytics.budgetProgress >= 0.95
                ? AppTheme.error
                : analytics.budgetProgress >= 0.85
                ? AppTheme.warning
                : AppTheme.success,
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color:
                  (Theme.of(context).textTheme.bodyMedium?.color ??
                  AppTheme.textSecondaryFor(context)),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressLine extends StatelessWidget {
  const _ProgressLine({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 9,
            backgroundColor: Theme.of(context).dividerColor,
            color: color,
          ),
        ),
      ],
    );
  }
}

class _NarrativeCard extends StatelessWidget {
  const _NarrativeCard({required this.analytics, required this.periodLabel});

  final _TransactionAnalytics analytics;
  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    final message = _message();
    final trigger = _trigger();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.12)),
      ),
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
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '$periodLabel: $message',
                  style: GoogleFonts.inter(
                    color:
                        (Theme.of(context).textTheme.bodyMedium?.color ??
                        AppTheme.textSecondaryFor(context)),
                    height: 1.4,
                  ),
                ),
                if (trigger != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    trigger,
                    style: GoogleFonts.inter(
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _message() {
    if (analytics.transactions.isEmpty) {
      return 'No movement yet. Your budget and savings are ready when you add one.';
    }
    if (analytics.income > 0 && analytics.expenses <= analytics.income * 0.65) {
      return 'Good control this week. Spending is staying comfortably below income.';
    }
    if (analytics.budgetProgress >= 1) {
      return 'Spending momentum is high. Let\'s adjust before it touches savings again.';
    }
    if (analytics.incomeProgress >= 0.9) {
      return 'You are close to using the full income for this period. A smaller next expense helps.';
    }
    return 'Spending momentum is slowing down. Budget, savings, and goals are still connected.';
  }

  String? _trigger() {
    final repeated = analytics.categorySpend.entries
        .where((entry) => analytics.overspentCategory(entry.key))
        .map((entry) => entry.key)
        .toList();
    if (repeated.isEmpty) return null;
    return 'Gentle nudge: ${repeated.first} is over budget again. Try a smaller cap next period.';
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.typeFilter,
    required this.categoryFilter,
    required this.categories,
    required this.onTypeChanged,
    required this.onCategoryChanged,
  });

  final String typeFilter;
  final String categoryFilter;
  final List<String> categories;
  final ValueChanged<String> onTypeChanged;
  final ValueChanged<String> onCategoryChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            _Chip(
              label: 'All',
              value: 'all',
              selected: typeFilter == 'all',
              onTap: onTypeChanged,
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Income',
              value: 'income',
              selected: typeFilter == 'income',
              onTap: onTypeChanged,
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Expense',
              value: 'expense',
              selected: typeFilter == 'expense',
              onTap: onTypeChanged,
            ),
            const SizedBox(width: 8),
            _Chip(
              label: 'Transfers',
              value: 'transfer',
              selected: typeFilter == 'transfer',
              onTap: onTypeChanged,
            ),
          ],
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 38,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _Chip(
                label: 'All categories',
                value: 'all',
                selected: categoryFilter == 'all',
                onTap: onCategoryChanged,
              ),
              const SizedBox(width: 8),
              ...categories.map(
                (category) => Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: _Chip(
                    label: category,
                    value: category,
                    selected: categoryFilter == category,
                    onTap: onCategoryChanged,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _AutoBudgetShortcut extends StatelessWidget {
  const _AutoBudgetShortcut({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
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
                Icons.auto_awesome_rounded,
                color: AppTheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'AI Auto-Budget Generator',
                    style: GoogleFonts.plusJakartaSans(
                      color: Theme.of(context).colorScheme.onSurface,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    'Use income, transactions, and journeys to rebalance budgets.',
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
            Icon(Icons.chevron_right_rounded, color: AppTheme.primary),
          ],
        ),
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.label,
    required this.value,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String value;
  final bool selected;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => onTap(value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primary
              : Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? AppTheme.primary : Theme.of(context).dividerColor,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: selected
                ? Colors.white
                : (Theme.of(context).textTheme.bodyMedium?.color ??
                      AppTheme.textSecondaryFor(context)),
          ),
        ),
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.transaction, required this.analytics});

  final FinancialTransaction transaction;
  final _TransactionAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    final color = transaction.type == 'income'
        ? AppTheme.success
        : transaction.type == 'transfer'
        ? AppTheme.primary
        : AppTheme.error;
    final sign = transaction.type == 'income'
        ? '+'
        : transaction.type == 'transfer'
        ? ''
        : '-';
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: analytics.overspentCategory(transaction.category)
              ? AppTheme.warning.withValues(alpha: 0.45)
              : Theme.of(context).dividerColor,
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_icon(), color: color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        transaction.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: Theme.of(context).colorScheme.onSurface,
                        ),
                      ),
                    ),
                    if (transaction.deadline != null)
                      Icon(
                        Icons.notifications_active_rounded,
                        size: 16,
                        color: AppTheme.warning,
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  '${transaction.category} - ${DateFormat('MMM dd, yyyy').format(transaction.date)}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color:
                        (Theme.of(context).textTheme.bodyMedium?.color ??
                        AppTheme.textSecondaryFor(context)),
                  ),
                ),
                if (transaction.deadline != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Deadline ${DateFormat('MMM dd').format(transaction.deadline!)} linked to budget',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      color: AppTheme.warning,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(
            '$sign${CurrencyUtils.format(transaction.amount)}',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  IconData _icon() {
    switch (transaction.type) {
      case 'income':
        return Icons.arrow_downward_rounded;
      case 'transfer':
        return Icons.swap_horiz_rounded;
      default:
        return Icons.arrow_upward_rounded;
    }
  }
}
