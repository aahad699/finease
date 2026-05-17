import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/app_config.dart';
import '../../models/budget_plan.dart';
import '../../models/saving_goal.dart';
import '../../models/transaction.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';
import '../../widgets/app_config_gate.dart';
import '../budget/ai_budget_advisor_page.dart';
import '../chatbot/chatbot_page.dart';
import '../forum/community_forum_page.dart';
import '../analytics/analytics_screen.dart';
import '../literacy/literacy_hub_page.dart';
import '../loans/loan_simulator_page.dart';
import '../marketplace/marketplace_screen.dart';
import '../profile/profile_page.dart';
import '../savings/savings_tracker_page.dart';
import '../transactions/add_transaction_page.dart';
import '../transactions/all_transactions_page.dart';
import '../welfare/welfare_programs_page.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.appConfig});

  final AppConfig? appConfig;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final GlobalKey<RefreshIndicatorState> _refreshKey =
      GlobalKey<RefreshIndicatorState>();
  bool _isRefreshing = false;

  Future<void> _handleRefresh() async {
    setState(() => _isRefreshing = true);
    // Small delay to let streams re-emit
    await Future.delayed(const Duration(milliseconds: 800));
    if (mounted) setState(() => _isRefreshing = false);
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final firestoreService = authService.firestoreService;
    final user = authService.user;
    final photoUrl = user?.photoURL;
    final appConfig = widget.appConfig ?? AppConfig.defaults();
    final primaryColor = appConfigColor(
      appConfig.primaryColorHex,
      AppTheme.primary,
    );
    final secondaryColor = appConfigColor(
      appConfig.secondaryColorHex,
      AppTheme.secondary,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          key: _refreshKey,
          onRefresh: _handleRefresh,
          color: AppTheme.primary,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(
              parent: BouncingScrollPhysics(),
            ),
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                  child: _TopBar(
                    appConfig: appConfig,
                    primaryColor: primaryColor,
                    photoUrl: photoUrl,
                    isRefreshing: _isRefreshing,
                    onRefresh: () => _refreshKey.currentState?.show(),
                    onProfileTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const ProfilePage()),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: firestoreService == null
                      ? const SizedBox.shrink()
                      : StreamBuilder<List<FinancialTransaction>>(
                          stream: firestoreService.getTransactions(),
                          builder: (context, snapshot) {
                            final txns = snapshot.data ?? const [];
                            final now = DateTime.now();
                            final monthlyTxns = txns
                                .where(
                                  (t) =>
                                      t.date.year == now.year &&
                                      t.date.month == now.month,
                                )
                                .toList();
                            final income = monthlyTxns
                                .where((t) => t.type == 'income')
                                .fold<double>(0, (sum, t) => sum + t.amount);
                            final expense = monthlyTxns
                                .where((t) => t.type == 'expense')
                                .fold<double>(0, (sum, t) => sum + t.amount);
                            return StreamBuilder<Map<String, dynamic>>(
                              stream: firestoreService.getMonthlySummary(),
                              builder: (context, summarySnapshot) {
                                final summary = summarySnapshot.data ?? {};
                                final balance =
                                    (summary['totalBalance'] as num?)
                                        ?.toDouble() ??
                                    income - expense;
                                return _BalanceCard(
                                  title: appConfig.homeHeroTitle,
                                  message: appConfig.homeHeroMessage,
                                  primaryColor: primaryColor,
                                  secondaryColor: secondaryColor,
                                  balance: balance,
                                  income:
                                      (summary['monthlyIncome'] as num?)
                                          ?.toDouble() ??
                                      income,
                                  expense:
                                      (summary['totalExpenses'] as num?)
                                          ?.toDouble() ??
                                      expense,
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: firestoreService == null
                      ? const SizedBox.shrink()
                      : _HomeIntelligenceDashboard(
                          firestoreService: firestoreService,
                          onAddTransaction: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AddTransactionPage(),
                            ),
                          ),
                          onCreateBudget: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AIBudgetAdvisorPage(),
                            ),
                          ),
                          onNewGoal: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const SavingsTrackerPage(),
                            ),
                          ),
                          onViewTransactions: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const AllTransactionsPage(),
                            ),
                          ),
                        ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Core Tools',
                    actionLabel: 'Open Budget Planer',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AIBudgetAdvisorPage(),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _FeatureGrid(
                    items: [
                      _FeatureItem(
                        label: 'Marketplace',
                        icon: Icons.storefront_rounded,
                        color: AppTheme.primary,
                        background: const Color(0xFFEEF2FF),
                        enabled: appConfig.marketplaceEnabled,
                        onTap: () => _openFeature(
                          enabled: appConfig.marketplaceEnabled,
                          title: 'Marketplace is paused',
                          message: appConfig.supportMessage,
                          page: const MarketplaceScreen(),
                        ),
                      ),
                      _FeatureItem(
                        label: 'Budget',
                        icon: Icons.account_balance_wallet_rounded,
                        color: const Color(0xFF0EA5A4),
                        background: const Color(0xFFECFEFF),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AIBudgetAdvisorPage(),
                          ),
                        ),
                      ),
                      _FeatureItem(
                        label: 'Analysis',
                        icon: Icons.query_stats_rounded,
                        color: const Color(0xFF4F46E5),
                        background: const Color(0xFFEEF2FF),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const AnalyticsScreen(),
                          ),
                        ),
                      ),
                      _FeatureItem(
                        label: 'Loans',
                        icon: Icons.calculate_rounded,
                        color: const Color(0xFFD97706),
                        background: const Color(0xFFFFF7ED),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LoanSimulatorPage(),
                          ),
                        ),
                      ),
                      _FeatureItem(
                        label: 'Chatbot',
                        icon: Icons.smart_toy_rounded,
                        color: const Color(0xFF475569),
                        background: const Color(0xFFF1F5F9),
                        enabled: appConfig.chatbotEnabled,
                        onTap: () => _openFeature(
                          enabled: appConfig.chatbotEnabled,
                          title: 'AI chatbot is paused',
                          message: appConfig.supportMessage,
                          page: const ChatbotPage(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Explore FinEase',
                    actionLabel: 'Open Savings Plan',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SavingsTrackerPage(),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _FeatureGrid(
                    items: [
                      _FeatureItem(
                        label: 'Savings',
                        icon: Icons.savings_rounded,
                        color: const Color(0xFF0EA5A4),
                        background: const Color(0xFFECFEFF),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const SavingsTrackerPage(),
                          ),
                        ),
                      ),
                      _FeatureItem(
                        label: 'Literacy Hub',
                        icon: Icons.school_rounded,
                        color: const Color(0xFF4F46E5),
                        background: const Color(0xFFEEF2FF),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const LiteracyHubPage(),
                          ),
                        ),
                      ),
                      _FeatureItem(
                        label: 'Welfare',
                        icon: Icons.volunteer_activism_rounded,
                        color: const Color(0xFFD97706),
                        background: const Color(0xFFFFF7ED),
                        enabled: appConfig.welfareEnabled,
                        onTap: () => _openFeature(
                          enabled: appConfig.welfareEnabled,
                          title: 'Welfare programs are paused',
                          message: appConfig.supportMessage,
                          page: const WelfareProgramsPage(),
                        ),
                      ),
                      _FeatureItem(
                        label: 'Forum',
                        icon: Icons.forum_rounded,
                        color: const Color(0xFF475569),
                        background: const Color(0xFFF1F5F9),
                        enabled: appConfig.forumEnabled,
                        onTap: () => _openFeature(
                          enabled: appConfig.forumEnabled,
                          title: 'Community forum is paused',
                          message: appConfig.supportMessage,
                          page: const CommunityForumPage(),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Your Progress',
                    actionLabel: '',
                    onTap: () {},
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: firestoreService == null
                      ? const SizedBox.shrink()
                      : StreamBuilder<List<SavingGoal>>(
                          stream: firestoreService.getSavingGoals(),
                          builder: (context, goalSnapshot) {
                            return StreamBuilder<List<FinancialTransaction>>(
                              stream: firestoreService.getTransactions(),
                              builder: (context, txnSnapshot) {
                                final goals = goalSnapshot.data ?? const [];
                                final txns = txnSnapshot.data ?? const [];
                                final saved = goals.fold<double>(
                                  0,
                                  (sum, goal) => sum + goal.currentAmount,
                                );
                                return FutureBuilder<int>(
                                  future: _completedLessonCount(
                                    firestoreService,
                                  ),
                                  builder: (context, lessonSnapshot) {
                                    final completedLessons =
                                        lessonSnapshot.data ?? 0;
                                    return _ProgressPanel(
                                      totalSaved: saved,
                                      goalCount: goals.length,
                                      transactionCount: txns.length,
                                      completedLessons: completedLessons,
                                    );
                                  },
                                );
                              },
                            );
                          },
                        ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                sliver: SliverToBoxAdapter(
                  child: _SectionHeader(
                    title: 'Recent Transactions',
                    actionLabel: 'See all',
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const AllTransactionsPage(),
                      ),
                    ),
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                sliver: firestoreService == null
                    ? const SliverToBoxAdapter(child: SizedBox.shrink())
                    : StreamBuilder<List<FinancialTransaction>>(
                        stream: firestoreService.getTransactions(),
                        builder: (context, snapshot) {
                          final txns = (snapshot.data ?? const [])
                              .take(5)
                              .toList();
                          if (txns.isEmpty) {
                            return const SliverToBoxAdapter(
                              child: _EmptyState(),
                            );
                          }
                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _DismissibleTransactionTile(
                                txn: txns[index],
                                firestoreService: firestoreService,
                              ),
                              childCount: txns.length,
                            ),
                          );
                        },
                      ),
              ),
              const SliverToBoxAdapter(child: SizedBox(height: 120)),
            ],
          ),
        ),
      ),
      floatingActionButton: Container(
        margin: const EdgeInsets.only(bottom: 90),
        child: FloatingActionButton.extended(
          onPressed: () => Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const AddTransactionPage()),
          ),
          backgroundColor: AppTheme.primary,
          icon: Icon(Icons.add_rounded, color: Colors.white),
          label: Text(
            'Add Transaction',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }

  Future<int> _completedLessonCount(dynamic firestoreService) async {
    const courseIds = [
      'budget-foundations',
      'smart-investing',
      'credit-and-debt',
      'pakistan-finance-playbook',
    ];
    var total = 0;
    for (final courseId in courseIds) {
      final progress = await firestoreService.getCourseProgress(courseId).first;
      final completed = List<String>.from(
        progress['completedLessonIds'] ?? const [],
      );
      total += completed.length;
    }
    return total;
  }

  void _openFeature({
    required bool enabled,
    required String title,
    required String message,
    required Widget page,
  }) {
    if (!enabled) {
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('$title. $message')));
      return;
    }

    Navigator.push(context, MaterialPageRoute(builder: (context) => page));
  }
}

class _HomeIntelligenceDashboard extends StatelessWidget {
  const _HomeIntelligenceDashboard({
    required this.firestoreService,
    required this.onAddTransaction,
    required this.onCreateBudget,
    required this.onNewGoal,
    required this.onViewTransactions,
  });

  final dynamic firestoreService;
  final VoidCallback onAddTransaction;
  final VoidCallback onCreateBudget;
  final VoidCallback onNewGoal;
  final VoidCallback onViewTransactions;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final monthKey = '${now.year}-${now.month.toString().padLeft(2, '0')}';
    return StreamBuilder<List<FinancialTransaction>>(
      stream: firestoreService.getTransactions(),
      builder: (context, txnSnapshot) {
        final transactions = txnSnapshot.data ?? const <FinancialTransaction>[];
        return StreamBuilder<List<SavingGoal>>(
          stream: firestoreService.getSavingGoals(),
          builder: (context, goalSnapshot) {
            final goals = goalSnapshot.data ?? const <SavingGoal>[];
            return StreamBuilder<List<BudgetPlan>>(
              stream: firestoreService.getBudgetPlans(monthKey: monthKey),
              builder: (context, budgetSnapshot) {
                final budgets = budgetSnapshot.data ?? const <BudgetPlan>[];
                return StreamBuilder<Map<String, dynamic>>(
                  stream: firestoreService.getUserProfile(),
                  builder: (context, profileSnapshot) {
                    final profile = profileSnapshot.data ?? const {};
                    final analytics = _HomeDashboardAnalytics.from(
                      transactions: transactions,
                      goals: goals,
                      budgets: budgets,
                      profile: profile,
                    );
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _DashboardTitle(periodLabel: analytics.periodLabel),
                        const SizedBox(height: 14),
                        _HealthScoreHero(analytics: analytics),
                        const SizedBox(height: 14),
                        _QuickActionDeck(
                          onAddTransaction: onAddTransaction,
                          onCreateBudget: onCreateBudget,
                          onNewGoal: onNewGoal,
                          onViewTransactions: onViewTransactions,
                        ),
                        const SizedBox(height: 14),
                        _BudgetOverviewCard(analytics: analytics),
                        const SizedBox(height: 14),
                        _IncomeExpenseCard(analytics: analytics),
                        const SizedBox(height: 14),
                        _SavingsJourneysCard(analytics: analytics),
                        const SizedBox(height: 14),
                        _ReminderDeadlineCard(analytics: analytics),
                        const SizedBox(height: 14),
                        _WeeklyNarrativeCard(analytics: analytics),
                        const SizedBox(height: 14),
                        _RecentActivityStrip(
                          transactions: analytics.recentTransactions,
                          onViewAll: onViewTransactions,
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
    );
  }
}

class _HomeDashboardAnalytics {
  const _HomeDashboardAnalytics({
    required this.transactions,
    required this.goals,
    required this.budgets,
    required this.monthlyIncome,
    required this.monthlyExpenses,
    required this.totalBudgeted,
    required this.totalSaved,
    required this.totalTarget,
    required this.profileSavings,
  });

  final List<FinancialTransaction> transactions;
  final List<SavingGoal> goals;
  final List<BudgetPlan> budgets;
  final double monthlyIncome;
  final double monthlyExpenses;
  final double totalBudgeted;
  final double totalSaved;
  final double totalTarget;
  final double profileSavings;

  factory _HomeDashboardAnalytics.from({
    required List<FinancialTransaction> transactions,
    required List<SavingGoal> goals,
    required List<BudgetPlan> budgets,
    required Map<String, dynamic> profile,
  }) {
    final now = DateTime.now();
    final monthlyTransactions = transactions
        .where(
          (txn) => txn.date.year == now.year && txn.date.month == now.month,
        )
        .toList();
    final income = monthlyTransactions
        .where((txn) => txn.type == 'income')
        .fold<double>(0, (total, txn) => total + txn.amount);
    final expenses = monthlyTransactions
        .where((txn) => txn.type == 'expense')
        .fold<double>(0, (total, txn) => total + txn.amount);
    final profileIncome = ((profile['monthlyIncome'] ?? 0) as num).toDouble();
    return _HomeDashboardAnalytics(
      transactions: transactions,
      goals: goals,
      budgets: budgets,
      monthlyIncome: income > 0 ? income : profileIncome,
      monthlyExpenses: expenses,
      totalBudgeted: budgets.fold<double>(
        0,
        (total, budget) => total + budget.allocatedAmount,
      ),
      totalSaved: goals.fold<double>(
        0,
        (total, goal) => total + goal.currentAmount,
      ),
      totalTarget: goals.fold<double>(
        0,
        (total, goal) => total + goal.targetAmount,
      ),
      profileSavings:
          ((profile['savingsBalance'] ?? 0) as num).toDouble() +
          ((profile['extraSavingsBalance'] ?? 0) as num).toDouble(),
    );
  }

  String get periodLabel => DateFormat('MMMM yyyy').format(DateTime.now());
  double get budgetProgress =>
      totalBudgeted <= 0 ? 0 : (monthlyExpenses / totalBudgeted).clamp(0, 1);
  double get incomeProgress =>
      monthlyIncome <= 0 ? 0 : (monthlyExpenses / monthlyIncome).clamp(0, 1);
  double get remainingBudget =>
      (totalBudgeted - monthlyExpenses).clamp(0, double.infinity).toDouble();
  double get remainingIncome =>
      (monthlyIncome - monthlyExpenses).clamp(0, double.infinity).toDouble();
  bool get overBudget => monthlyExpenses > totalBudgeted && totalBudgeted > 0;
  bool get overIncome => monthlyExpenses > monthlyIncome && monthlyIncome > 0;
  double get journeyProgress =>
      totalTarget <= 0 ? 0 : (totalSaved / totalTarget).clamp(0, 1);
  int get activeJourneys => goals.where((goal) => goal.remaining > 0).length;
  int get debtItems =>
      goals.where((goal) => goal.isDebtGoal).length +
      budgets.where((budget) => budget.isDebtPayment).length;
  List<FinancialTransaction> get recentTransactions =>
      transactions.take(3).toList();
  List<_ReminderItem> get reminders {
    final now = DateTime.now();
    final items = <_ReminderItem>[
      ...transactions
          .where((txn) => txn.deadline != null)
          .map(
            (txn) => _ReminderItem(
              title: txn.title,
              date: txn.deadline!,
              type: txn.category,
              urgent: txn.deadline!.difference(now).inDays <= 3,
            ),
          ),
      ...goals
          .where((goal) => goal.reminderDate != null)
          .map(
            (goal) => _ReminderItem(
              title: goal.title,
              date: goal.reminderDate!,
              type: goal.isDebtGoal ? 'Debt journey' : 'Journey',
              urgent: goal.reminderDate!.difference(now).inDays <= 5,
            ),
          ),
      ...budgets
          .where((budget) => budget.reminderDate != null)
          .map(
            (budget) => _ReminderItem(
              title: budget.title,
              date: budget.reminderDate!,
              type: budget.isDebtPayment ? 'Debt budget' : 'Budget',
              urgent: budget.reminderDate!.difference(now).inDays <= 5,
            ),
          ),
    ]..sort((a, b) => a.date.compareTo(b.date));
    return items.take(4).toList();
  }

  int get healthScore {
    var score = 100;
    if (overIncome) score -= 28;
    if (overBudget) score -= 22;
    if (monthlyIncome > 0) {
      score -= ((monthlyExpenses / monthlyIncome).clamp(0.0, 1.3) * 24).round();
    }
    if (activeJourneys == 0) score -= 8;
    if (profileSavings <= 0) score -= 8;
    if (journeyProgress > 0.25) score += 5;
    return score.clamp(0, 100);
  }

  Color get healthColor {
    if (healthScore >= 75) return AppTheme.success;
    if (healthScore >= 50) return AppTheme.warning;
    return AppTheme.error;
  }

  String get weeklyNarrative {
    if (overIncome) {
      return 'Expenses are above income this period. Pause optional spending and review Savings before approving more withdrawals.';
    }
    if (overBudget) {
      return 'Budget pressure is building. A quick budget adjustment or smaller next transaction can bring the month back on track.';
    }
    if (activeJourneys > 0 && journeyProgress > 0.2) {
      return 'Good momentum. Your budget, transactions, and journeys are moving together with room still available.';
    }
    return 'This week is steady. Add one transaction or journey update to keep the dashboard fully alive.';
  }
}

class _ReminderItem {
  const _ReminderItem({
    required this.title,
    required this.date,
    required this.type,
    required this.urgent,
  });

  final String title;
  final DateTime date;
  final String type;
  final bool urgent;
}

class _DashboardTitle extends StatelessWidget {
  const _DashboardTitle({required this.periodLabel});

  final String periodLabel;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'Intelligent Dashboard',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: Theme.of(context).colorScheme.onSurface,
            ),
          ),
        ),
        Text(
          periodLabel,
          style: GoogleFonts.inter(
            color:
                (Theme.of(context).textTheme.bodyMedium?.color ??
                AppTheme.textSecondaryFor(context)),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _HealthScoreHero extends StatelessWidget {
  const _HealthScoreHero({required this.analytics});

  final _HomeDashboardAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 92,
                height: 92,
                child: CircularProgressIndicator(
                  value: analytics.healthScore / 100,
                  strokeWidth: 9,
                  backgroundColor: Theme.of(context).dividerColor,
                  color: analytics.healthColor,
                ),
              ),
              Text(
                '${analytics.healthScore}',
                style: GoogleFonts.plusJakartaSans(
                  color: analytics.healthColor,
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Financial Health Score',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 18,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  analytics.weeklyNarrative,
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
}

class _QuickActionDeck extends StatelessWidget {
  const _QuickActionDeck({
    required this.onAddTransaction,
    required this.onCreateBudget,
    required this.onNewGoal,
    required this.onViewTransactions,
  });

  final VoidCallback onAddTransaction;
  final VoidCallback onCreateBudget;
  final VoidCallback onNewGoal;
  final VoidCallback onViewTransactions;

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2.25,
      children: [
        _DashboardAction(
          label: 'Add Transaction',
          icon: Icons.add_card_rounded,
          color: AppTheme.primary,
          onTap: onAddTransaction,
        ),
        _DashboardAction(
          label: 'Create Budget',
          icon: Icons.account_balance_wallet_rounded,
          color: const Color(0xFF0EA5A4),
          onTap: onCreateBudget,
        ),
        _DashboardAction(
          label: 'New Journey',
          icon: Icons.flag_rounded,
          color: AppTheme.success,
          onTap: onNewGoal,
        ),
        _DashboardAction(
          label: 'All Transactions',
          icon: Icons.receipt_long_rounded,
          color: AppTheme.warning,
          onTap: onViewTransactions,
        ),
      ],
    );
  }
}

class _DashboardAction extends StatelessWidget {
  const _DashboardAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Theme.of(context).dividerColor),
          boxShadow: AppTheme.softShadow,
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.10),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetOverviewCard extends StatelessWidget {
  const _BudgetOverviewCard({required this.analytics});

  final _HomeDashboardAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      icon: Icons.account_balance_wallet_rounded,
      title: 'Current Period Budget',
      trailing: CurrencyUtils.format(analytics.remainingBudget),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _DashboardProgress(
            value: analytics.budgetProgress,
            color: analytics.overBudget ? AppTheme.error : AppTheme.primary,
          ),
          const SizedBox(height: 12),
          _MetricRow(
            leftLabel: 'Budgeted',
            leftValue: CurrencyUtils.format(analytics.totalBudgeted),
            rightLabel: analytics.overBudget ? 'Over' : 'Spent',
            rightValue: CurrencyUtils.format(analytics.monthlyExpenses),
          ),
          if (analytics.overBudget) ...[
            const SizedBox(height: 10),
            _WarningText(
              text:
                  'Budget exceeded. Review categories before pulling from Savings.',
            ),
          ],
        ],
      ),
    );
  }
}

class _IncomeExpenseCard extends StatelessWidget {
  const _IncomeExpenseCard({required this.analytics});

  final _HomeDashboardAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      icon: Icons.compare_arrows_rounded,
      title: 'Income vs Expenses',
      trailing: CurrencyUtils.format(analytics.remainingIncome),
      child: Column(
        children: [
          _DashboardProgress(
            value: analytics.incomeProgress,
            color: analytics.overIncome ? AppTheme.error : AppTheme.success,
          ),
          const SizedBox(height: 12),
          _MetricRow(
            leftLabel: 'Income',
            leftValue: CurrencyUtils.format(analytics.monthlyIncome),
            rightLabel: 'Expenses',
            rightValue: CurrencyUtils.format(analytics.monthlyExpenses),
          ),
          if (analytics.overIncome) ...[
            const SizedBox(height: 10),
            _WarningText(
              text:
                  'Expenses are above income. Savings support should require confirmation.',
            ),
          ],
        ],
      ),
    );
  }
}

class _SavingsJourneysCard extends StatelessWidget {
  const _SavingsJourneysCard({required this.analytics});

  final _HomeDashboardAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      icon: Icons.savings_rounded,
      title: 'Savings & Journeys',
      trailing: '${analytics.activeJourneys} active',
      child: Column(
        children: [
          _DashboardProgress(
            value: analytics.journeyProgress,
            color: AppTheme.primary,
          ),
          const SizedBox(height: 12),
          _MetricRow(
            leftLabel: 'Saved',
            leftValue: CurrencyUtils.format(analytics.totalSaved),
            rightLabel: 'Savings pool',
            rightValue: CurrencyUtils.format(analytics.profileSavings),
          ),
          if (analytics.debtItems > 0) ...[
            const SizedBox(height: 10),
            _WarningText(
              text:
                  '${analytics.debtItems} debt reminder item(s) need tracking.',
              color: AppTheme.warning,
            ),
          ],
        ],
      ),
    );
  }
}

class _ReminderDeadlineCard extends StatelessWidget {
  const _ReminderDeadlineCard({required this.analytics});

  final _HomeDashboardAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      icon: Icons.notifications_active_rounded,
      title: 'Upcoming Reminders',
      trailing: '${analytics.reminders.length}',
      child: analytics.reminders.isEmpty
          ? Text(
              'No upcoming deadlines. Debt payments, bills, and journey reminders will appear here.',
              style: GoogleFonts.inter(
                color:
                    (Theme.of(context).textTheme.bodyMedium?.color ??
                    AppTheme.textSecondaryFor(context)),
                height: 1.4,
              ),
            )
          : Column(
              children: analytics.reminders
                  .map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Icon(
                            item.urgent
                                ? Icons.priority_high_rounded
                                : Icons.event_rounded,
                            color: item.urgent
                                ? AppTheme.warning
                                : AppTheme.primary,
                            size: 20,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.title,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: GoogleFonts.inter(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onSurface,
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  '${item.type} • ${DateFormat('MMM dd').format(item.date)}',
                                  style: GoogleFonts.inter(
                                    color:
                                        (Theme.of(
                                          context,
                                        ).textTheme.bodyMedium?.color ??
                                        AppTheme.textSecondaryFor(context)),
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _WeeklyNarrativeCard extends StatelessWidget {
  const _WeeklyNarrativeCard({required this.analytics});

  final _HomeDashboardAnalytics analytics;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      icon: Icons.auto_awesome_rounded,
      title: 'Weekly Narrative',
      trailing: 'Live',
      child: Text(
        analytics.weeklyNarrative,
        style: GoogleFonts.inter(
          color:
              (Theme.of(context).textTheme.bodyMedium?.color ??
              AppTheme.textSecondaryFor(context)),
          height: 1.5,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _RecentActivityStrip extends StatelessWidget {
  const _RecentActivityStrip({
    required this.transactions,
    required this.onViewAll,
  });

  final List<FinancialTransaction> transactions;
  final VoidCallback onViewAll;

  @override
  Widget build(BuildContext context) {
    return _DashboardCard(
      icon: Icons.receipt_long_rounded,
      title: 'Recent Transactions',
      trailing: 'See all',
      onTrailingTap: onViewAll,
      child: transactions.isEmpty
          ? Text(
              'No transactions yet.',
              style: GoogleFonts.inter(
                color:
                    (Theme.of(context).textTheme.bodyMedium?.color ??
                    AppTheme.textSecondaryFor(context)),
              ),
            )
          : Column(
              children: transactions
                  .map(
                    (txn) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              txn.title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: Theme.of(context).colorScheme.onSurface,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          Text(
                            CurrencyUtils.format(txn.amount),
                            style: GoogleFonts.plusJakartaSans(
                              color: txn.type == 'income'
                                  ? AppTheme.success
                                  : txn.type == 'transfer'
                                  ? AppTheme.primary
                                  : AppTheme.error,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _DashboardCard extends StatelessWidget {
  const _DashboardCard({
    required this.icon,
    required this.title,
    required this.trailing,
    required this.child,
    this.onTrailingTap,
  });

  final IconData icon;
  final String title;
  final String trailing;
  final Widget child;
  final VoidCallback? onTrailingTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Theme.of(context).dividerColor),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Theme.of(context).colorScheme.onSurface,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              GestureDetector(
                onTap: onTrailingTap,
                child: Text(
                  trailing,
                  style: GoogleFonts.inter(
                    color: AppTheme.primary,
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _DashboardProgress extends StatelessWidget {
  const _DashboardProgress({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: LinearProgressIndicator(
        value: value,
        minHeight: 9,
        backgroundColor: Theme.of(context).dividerColor,
        color: color,
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.leftLabel,
    required this.leftValue,
    required this.rightLabel,
    required this.rightValue,
  });

  final String leftLabel;
  final String leftValue;
  final String rightLabel;
  final String rightValue;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _SmallMetric(label: leftLabel, value: leftValue),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _SmallMetric(label: rightLabel, value: rightValue),
        ),
      ],
    );
  }
}

class _SmallMetric extends StatelessWidget {
  const _SmallMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
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
          const SizedBox(height: 5),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              color: Theme.of(context).colorScheme.onSurface,
              fontWeight: FontWeight.w800,
              fontSize: 13,
            ),
          ),
        ],
      ),
    );
  }
}

class _WarningText extends StatelessWidget {
  const _WarningText({required this.text, this.color = AppTheme.error});

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(Icons.warning_amber_rounded, color: color, size: 18),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            text,
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w700,
              height: 1.35,
              fontSize: 12,
            ),
          ),
        ),
      ],
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({
    required this.appConfig,
    required this.primaryColor,
    required this.photoUrl,
    required this.isRefreshing,
    required this.onRefresh,
    required this.onProfileTap,
  });

  final AppConfig appConfig;
  final Color primaryColor;
  final String? photoUrl;
  final bool isRefreshing;
  final VoidCallback onRefresh;
  final VoidCallback onProfileTap;

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.watch<AuthService>().firestoreService;
    return StreamBuilder<Map<String, dynamic>>(
      stream: firestoreService?.getUserProfile(),
      builder: (context, snapshot) {
        final profile = snapshot.data ?? const {};
        final name =
            (profile['fullName'] as String?)?.split(' ').first ??
            context.watch<AuthService>().user?.displayName?.split(' ').first ??
            context.watch<AuthService>().user?.email?.split('@').first ??
            'User';
        final role = profile['role'] == 'admin'
            ? 'Administrator'
            : (profile['isDemoAccount'] == true
                  ? 'Demo account'
                  : appConfig.brandTagline);

        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  AppBrandLogo(
                    logoUrl: appConfig.logoUrl,
                    size: 42,
                    backgroundColor: primaryColor.withValues(alpha: 0.08),
                  ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onProfileTap,
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                        boxShadow: AppTheme.softShadow,
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(24),
                        child: photoUrl != null
                            ? Image.network(
                                photoUrl!,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    CircleAvatar(
                                      backgroundColor: primaryColor,
                                      child: Icon(
                                        Icons.person_rounded,
                                        color: Colors.white,
                                      ),
                                    ),
                              )
                            : CircleAvatar(
                                backgroundColor: primaryColor,
                                child: Icon(
                                  Icons.person_rounded,
                                  color: Colors.white,
                                ),
                              ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          appConfig.brandName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFF64748B),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 17,
                            color: Theme.of(context).colorScheme.onSurface,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          role,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFF64748B),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              onTap: onRefresh,
              child: Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Theme.of(context).dividerColor),
                  boxShadow: AppTheme.softShadow,
                ),
                child: isRefreshing
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primary,
                        ),
                      )
                    : Icon(
                        Icons.refresh_rounded,
                        color: Theme.of(context).colorScheme.onSurface,
                        size: 22,
                      ),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({
    required this.title,
    required this.message,
    required this.primaryColor,
    required this.secondaryColor,
    required this.balance,
    required this.income,
    required this.expense,
  });

  final String title;
  final String message;
  final Color primaryColor;
  final Color secondaryColor;
  final double balance;
  final double income;
  final double expense;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(30),
        gradient: LinearGradient(
          colors: [primaryColor, secondaryColor],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.78),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.72),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            CurrencyUtils.format(balance),
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 34,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _BalanceStat(
                  label: 'Income',
                  value: CurrencyUtils.format(income),
                ),
              ),
              Expanded(
                child: _BalanceStat(
                  label: 'Expenses',
                  value: CurrencyUtils.format(expense),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _BalanceStat extends StatelessWidget {
  const _BalanceStat({required this.label, required this.value});

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
            color: Colors.white.withValues(alpha: 0.72),
            fontSize: 12,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: GoogleFonts.plusJakartaSans(
            color: Colors.white,
            fontWeight: FontWeight.w700,
            fontSize: 16,
          ),
        ),
      ],
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
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: Theme.of(context).colorScheme.onSurface,
          ),
        ),
        TextButton(onPressed: onTap, child: Text(actionLabel)),
      ],
    );
  }
}

class _FeatureGrid extends StatelessWidget {
  const _FeatureGrid({required this.items});

  final List<_FeatureItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.2,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        final iconColor = item.enabled ? item.color : const Color(0xFF94A3B8);
        final background = item.enabled
            ? item.background
            : const Color(0xFFF1F5F9);
        return InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: item.onTap,
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Theme.of(context).dividerColor),
              boxShadow: AppTheme.softShadow,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: background,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(item.icon, color: iconColor),
                ),
                const Spacer(),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        item.label,
                        style: GoogleFonts.plusJakartaSans(
                          fontWeight: FontWeight.w700,
                          color: item.enabled
                              ? Theme.of(context).colorScheme.onSurface
                              : AppTheme.textHintFor(context),
                        ),
                      ),
                    ),
                    if (!item.enabled)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF1F5F9),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          'Paused',
                          style: GoogleFonts.inter(
                            color:
                                (Theme.of(
                                  context,
                                ).textTheme.bodyMedium?.color ??
                                AppTheme.textSecondaryFor(context)),
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _FeatureItem {
  const _FeatureItem({
    required this.label,
    required this.icon,
    required this.color,
    required this.background,
    required this.onTap,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final Color color;
  final Color background;
  final VoidCallback onTap;
  final bool enabled;
}

class _ProgressPanel extends StatelessWidget {
  const _ProgressPanel({
    required this.totalSaved,
    required this.goalCount,
    required this.transactionCount,
    required this.completedLessons,
  });

  final double totalSaved;
  final int goalCount;
  final int transactionCount;
  final int completedLessons;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.isDark(context)
            ? AppTheme.surfaceCardFor(context)
            : AppTheme.textPrimaryFor(context),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Your progress is syncing across savings, learning, and activity.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.78),
              height: 1.5,
            ),
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _ProgressMetric(
                  label: 'Saved',
                  value: CurrencyUtils.format(totalSaved),
                ),
              ),
              Expanded(
                child: _ProgressMetric(
                  label: 'Goals',
                  value: '$goalCount active',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _ProgressMetric(
                  label: 'Lessons',
                  value: '$completedLessons done',
                ),
              ),
              Expanded(
                child: _ProgressMetric(
                  label: 'Transactions',
                  value: '$transactionCount logged',
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressMetric extends StatelessWidget {
  const _ProgressMetric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.65),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({required this.txn});

  final FinancialTransaction txn;

  @override
  Widget build(BuildContext context) {
    final isIncome = txn.type == 'income';
    final color = isIncome ? AppTheme.success : const Color(0xFFE11D48);
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              isIncome ? Icons.south_west_rounded : Icons.north_east_rounded,
              color: color,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  txn.title,
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  txn.category,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color:
                        (Theme.of(context).textTheme.bodyMedium?.color ??
                        AppTheme.textSecondaryFor(context)),
                  ),
                ),
              ],
            ),
          ),
          Text(
            CurrencyUtils.format(txn.amount),
            style: GoogleFonts.plusJakartaSans(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 40),
        child: Column(
          children: [
            Icon(
              Icons.receipt_long_rounded,
              size: 64,
              color: Theme.of(context).dividerColor,
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: GoogleFonts.inter(
                color: const Color(0xFF94A3B8),
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DismissibleTransactionTile extends StatelessWidget {
  const _DismissibleTransactionTile({
    required this.txn,
    required this.firestoreService,
  });

  final FinancialTransaction txn;
  final dynamic firestoreService;

  @override
  Widget build(BuildContext context) {
    return Dismissible(
      key: Key(txn.id),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 24),
        decoration: BoxDecoration(
          color: const Color(0xFFE11D48),
          borderRadius: BorderRadius.circular(22),
        ),
        alignment: Alignment.centerRight,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            Text(
              'Delete',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.delete_outline_rounded, color: Colors.white),
          ],
        ),
      ),
      confirmDismiss: (direction) async {
        return true;
      },
      onDismissed: (direction) {
        firestoreService.deleteTransaction(txn.id);
        ScaffoldMessenger.of(context).clearSnackBars();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              '"${txn.title}" deleted',
              style: GoogleFonts.inter(fontWeight: FontWeight.w500),
            ),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            duration: const Duration(seconds: 4),
            action: SnackBarAction(
              label: 'UNDO',
              textColor: AppTheme.secondary,
              onPressed: () {
                firestoreService.addTransaction(txn);
              },
            ),
          ),
        );
      },
      child: _TransactionTile(txn: txn),
    );
  }
}
