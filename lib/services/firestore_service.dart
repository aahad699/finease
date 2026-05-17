import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../app_constants.dart';
import '../models/budget_plan.dart';
import '../models/saving_goal.dart';
import '../models/transaction.dart';

class FinanceValidationException implements Exception {
  FinanceValidationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class SavingsUsageRequiredException extends FinanceValidationException {
  SavingsUsageRequiredException(this.requiredAmount)
    : super(
        'This action needs savings support of ${requiredAmount.toStringAsFixed(0)}. Please confirm before FinEase uses savings.',
      );

  final double requiredAmount;
}

class TransactionImpactPreview {
  const TransactionImpactPreview({
    required this.periodIncome,
    required this.periodExpenses,
    required this.projectedExpenses,
    required this.periodBudget,
    required this.categoryBudget,
    required this.categorySpent,
    required this.savingsBalance,
    required this.budgetUsage,
    required this.incomeUsage,
    required this.healthScore,
    required this.warnings,
    required this.needsSavings,
    required this.requiredSavings,
  });

  final double periodIncome;
  final double periodExpenses;
  final double projectedExpenses;
  final double periodBudget;
  final double categoryBudget;
  final double categorySpent;
  final double savingsBalance;
  final double budgetUsage;
  final double incomeUsage;
  final int healthScore;
  final List<String> warnings;
  final bool needsSavings;
  final double requiredSavings;
}

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final String uid;

  FirestoreService({required this.uid});

  // --------------- Transactions ---------------

  Stream<List<FinancialTransaction>> getTransactions() {
    return _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .orderBy('date', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => FinancialTransaction.fromFirestore(doc))
              .toList(),
        );
  }

  Future<DocumentReference<Map<String, dynamic>>> addTransaction(
    FinancialTransaction transaction, {
    bool allowSavingsWithdrawal = false,
  }) async {
    _validateTransaction(transaction);

    final budgets = await getBudgetPlans(
      monthKey: _monthKey(transaction.date),
    ).first;
    final summaryRef = _monthlySummaryRef(_monthKey(transaction.date));
    final userRef = _db.collection('users').doc(uid);
    final txRef = userRef.collection('transactions').doc();
    final transferRef = userRef.collection('transactions').doc();
    final transferLogRef = userRef.collection('savings_transfers').doc();

    await _db.runTransaction((dbTransaction) async {
      final userSnap = await dbTransaction.get(userRef);
      final summarySnap = await dbTransaction.get(summaryRef);
      final profile = userSnap.data() ?? {};
      final summary = summarySnap.data() ?? _emptyMonthlySummary();
      final updated = _applyTransactionToSummary(
        summary: summary,
        transaction: transaction,
        budgets: budgets,
        profile: profile,
        isReversal: false,
        allowSavingsWithdrawal: allowSavingsWithdrawal,
      );

      dbTransaction.set(txRef, transaction.toMap());
      if (updated.savingsWithdrawal > 0) {
        final transferMap = FinancialTransaction(
          id: '',
          title: 'Savings transfer for ${transaction.title}',
          amount: updated.savingsWithdrawal,
          date: transaction.date,
          category: 'Savings',
          type: 'transfer',
          note: 'Automatically moved from Savings to cover this expense.',
          linkedBudgetCategory: categoryFromTransaction(transaction),
          transferDirection: 'savings_to_spending',
        ).toMap();
        transferMap['linkedTransactionId'] = txRef.id;
        dbTransaction.set(transferRef, transferMap);
        dbTransaction.set(transferLogRef, {
          'amount': updated.savingsWithdrawal,
          'date': Timestamp.fromDate(transaction.date),
          'direction': 'savings_to_spending',
          'category': categoryFromTransaction(transaction),
          'reason': transaction.title,
          'linkedTransactionId': txRef.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      dbTransaction.set(summaryRef, updated.summary, SetOptions(merge: true));
      dbTransaction.set(userRef, updated.profilePatch, SetOptions(merge: true));
    });

    return txRef;
  }

  Future<void> deleteTransaction(String id) async {
    final txRef = _db
        .collection('users')
        .doc(uid)
        .collection('transactions')
        .doc(id);
    final txSnap = await txRef.get();
    if (!txSnap.exists) return;
    final transaction = FinancialTransaction.fromFirestore(txSnap);
    final budgets = await getBudgetPlans(
      monthKey: _monthKey(transaction.date),
    ).first;
    final summaryRef = _monthlySummaryRef(_monthKey(transaction.date));
    final userRef = _db.collection('users').doc(uid);

    await _db.runTransaction((dbTransaction) async {
      final userSnap = await dbTransaction.get(userRef);
      final summarySnap = await dbTransaction.get(summaryRef);
      final profile = userSnap.data() ?? {};
      final summary = summarySnap.data() ?? _emptyMonthlySummary();
      final updated = _applyTransactionToSummary(
        summary: summary,
        transaction: transaction,
        budgets: budgets,
        profile: profile,
        isReversal: true,
        allowSavingsWithdrawal: true,
      );
      dbTransaction.delete(txRef);
      dbTransaction.set(summaryRef, updated.summary, SetOptions(merge: true));
      dbTransaction.set(userRef, updated.profilePatch, SetOptions(merge: true));
    });
  }

  Stream<Map<String, dynamic>> getMonthlySummary({String? monthKey}) {
    final key = monthKey ?? _monthKey(DateTime.now());
    return _monthlySummaryRef(key).snapshots().map((doc) {
      final data = doc.data() ?? _emptyMonthlySummary();
      return data;
    });
  }

  Future<TransactionImpactPreview> previewTransactionImpact(
    FinancialTransaction transaction,
  ) async {
    _validateTransaction(transaction);
    final periodKey = _monthKey(transaction.date);
    final transactions = await getTransactions().first;
    final budgets = await getBudgetPlans(monthKey: periodKey).first;
    final profile = await getUserProfile().first;
    final monthly = transactions
        .where((item) => _monthKey(item.date) == periodKey)
        .toList();
    final periodIncome = monthly
        .where((item) => item.type == 'income')
        .fold<double>(0, (total, item) => total + item.amount);
    final periodExpenses = monthly
        .where((item) => item.type == 'expense')
        .fold<double>(0, (total, item) => total + item.amount);
    final periodBudget = budgets.fold<double>(
      0,
      (total, budget) => total + budget.allocatedAmount,
    );
    final category = _normalizeCategory(transaction.category);
    final categoryBudget = budgets
        .where((budget) => budget.category == category)
        .fold<double>(0, (total, budget) => total + budget.allocatedAmount);
    final categorySpent = monthly
        .where((item) => item.type == 'expense' && item.category == category)
        .fold<double>(0, (total, item) => total + item.amount);
    final projectedExpenses = transaction.type == 'expense'
        ? periodExpenses + transaction.amount
        : periodExpenses;
    final projectedIncome = transaction.type == 'income'
        ? periodIncome + transaction.amount
        : periodIncome;
    final budgetUsage = periodBudget <= 0
        ? 0.0
        : (projectedExpenses / periodBudget).clamp(0.0, 2.0);
    final incomeUsage = projectedIncome <= 0
        ? 0.0
        : (projectedExpenses / projectedIncome).clamp(0.0, 2.0);
    final availableSavings =
        ((profile['savingsBalance'] ?? 0) as num).toDouble() +
        ((profile['extraSavingsBalance'] ?? 0) as num).toDouble();
    final requiredSavings = transaction.type == 'expense'
        ? (projectedExpenses - projectedIncome)
              .clamp(0, double.infinity)
              .toDouble()
        : 0.0;
    final warnings = <String>[];
    if (transaction.type == 'expense' &&
        budgetUsage >= 0.85 &&
        budgetUsage < 1) {
      warnings.add(
        'This expense puts the selected period close to budget limit.',
      );
    }
    if (transaction.type == 'expense' && budgetUsage >= 1) {
      warnings.add('This expense will exceed the selected period budget.');
    }
    if (transaction.type == 'expense' && projectedExpenses > projectedIncome) {
      warnings.add('Total expenses will exceed income for this period.');
    }
    if (transaction.type == 'expense' &&
        categoryBudget > 0 &&
        categorySpent + transaction.amount > categoryBudget) {
      warnings.add('$category is repeatedly moving past its budget.');
    }
    final healthScore = _healthScore(
      income: projectedIncome,
      expenses: projectedExpenses,
      budget: periodBudget,
      savings: availableSavings,
    );
    return TransactionImpactPreview(
      periodIncome: projectedIncome,
      periodExpenses: periodExpenses,
      projectedExpenses: projectedExpenses,
      periodBudget: periodBudget,
      categoryBudget: categoryBudget,
      categorySpent: categorySpent,
      savingsBalance: availableSavings,
      budgetUsage: budgetUsage,
      incomeUsage: incomeUsage,
      healthScore: healthScore,
      warnings: warnings,
      needsSavings: requiredSavings > 0,
      requiredSavings: requiredSavings,
    );
  }

  Future<void> reconcileCurrentMonth() async {
    final key = _monthKey(DateTime.now());
    final transactions = await getTransactions().first;
    final budgets = await getBudgetPlans(monthKey: key).first;
    final profile = await getUserProfile().first;
    var summary = _emptyMonthlySummary();
    var profilePatch = <String, dynamic>{};
    for (final transaction in transactions.where(
      (t) => _monthKey(t.date) == key,
    )) {
      final updated = _applyTransactionToSummary(
        summary: summary,
        transaction: transaction,
        budgets: budgets,
        profile: {...profile, ...profilePatch},
        isReversal: false,
        allowSavingsWithdrawal: true,
      );
      summary = updated.summary;
      profilePatch = updated.profilePatch;
    }
    await _monthlySummaryRef(key).set(summary, SetOptions(merge: true));
    await _db
        .collection('users')
        .doc(uid)
        .set(profilePatch, SetOptions(merge: true));
  }

  // --------------- Budget Plans ---------------

  Stream<List<BudgetPlan>> getBudgetPlans({String? monthKey}) {
    final query = _db
        .collection('users')
        .doc(uid)
        .collection('budget_plans')
        .orderBy('createdAt', descending: true);

    return query.snapshots().map((snapshot) {
      final budgets = snapshot.docs
          .map((doc) => BudgetPlan.fromFirestore(doc))
          .toList();
      if (monthKey == null || monthKey.isEmpty) {
        return budgets;
      }
      return budgets
          .where(
            (budget) =>
                budget.monthKey == monthKey || budget.periodKey == monthKey,
          )
          .toList();
    });
  }

  Future<void> carryForwardBudgetLeftover({
    required String periodType,
    required String periodKey,
    required DateTime periodEnd,
  }) async {
    if (DateTime.now().isBefore(periodEnd)) return;
    final userRef = _db.collection('users').doc(uid);
    final closureRef = userRef
        .collection('budget_period_closures')
        .doc(periodKey);
    final budgets = await getBudgetPlans(monthKey: periodKey).first;
    if (budgets.isEmpty) return;
    final transactions = await getTransactions().first;
    final periodExpenses = transactions
        .where(
          (transaction) =>
              transaction.type == 'expense' &&
              _periodKeyFor(transaction.date, periodType) == periodKey,
        )
        .fold<double>(0, (total, transaction) => total + transaction.amount);
    final totalBudgeted = budgets.fold<double>(
      0,
      (total, budget) => total + budget.allocatedAmount,
    );
    final leftover = (totalBudgeted - periodExpenses)
        .clamp(0, double.infinity)
        .toDouble();
    if (leftover <= 0) return;

    final transferRef = userRef.collection('transactions').doc();
    await _db.runTransaction((dbTransaction) async {
      final closureSnap = await dbTransaction.get(closureRef);
      if (closureSnap.exists) return;
      final userSnap = await dbTransaction.get(userRef);
      final profile = userSnap.data() ?? {};
      final savingsBalance = ((profile['savingsBalance'] ?? 0) as num)
          .toDouble();
      final extraSavingsBalance = ((profile['extraSavingsBalance'] ?? 0) as num)
          .toDouble();
      final mainBalance = ((profile['mainBalance'] ?? 0) as num).toDouble();
      final nextSavings = savingsBalance + leftover;
      dbTransaction.set(closureRef, {
        'periodType': periodType,
        'periodKey': periodKey,
        'leftover': leftover,
        'closedAt': FieldValue.serverTimestamp(),
      });
      dbTransaction.set(transferRef, {
        ...FinancialTransaction(
          id: '',
          title: 'Budget leftover moved to Savings',
          amount: leftover,
          date: periodEnd,
          category: 'Savings',
          type: 'transfer',
          note: 'Automatic carry-forward from $periodType budget.',
          linkedBudgetCategory: 'Savings',
          transferDirection: 'budget_leftover_to_savings',
        ).toMap(),
        'periodType': periodType,
        'periodKey': periodKey,
      });
      dbTransaction.set(userRef, {
        'savingsBalance': nextSavings,
        'extraSavingsBalance': extraSavingsBalance,
        'totalBalance': mainBalance + nextSavings + extraSavingsBalance,
        'lastFinancialUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<double> previewBudgetLeftover({
    required String periodType,
    required String periodKey,
  }) async {
    final userRef = _db.collection('users').doc(uid);
    final closureSnap = await userRef
        .collection('budget_period_closures')
        .doc(periodKey)
        .get();
    if (closureSnap.exists) return 0;
    final budgets = await getBudgetPlans(monthKey: periodKey).first;
    if (budgets.isEmpty) return 0;
    final transactions = await getTransactions().first;
    final periodExpenses = transactions
        .where(
          (transaction) =>
              transaction.type == 'expense' &&
              _periodKeyFor(transaction.date, periodType) == periodKey,
        )
        .fold<double>(0, (total, transaction) => total + transaction.amount);
    final totalBudgeted = budgets.fold<double>(
      0,
      (total, budget) => total + budget.allocatedAmount,
    );
    return (totalBudgeted - periodExpenses)
        .clamp(0, double.infinity)
        .toDouble();
  }

  Future<void> pullSavingsForBudgetOverage({
    required double amount,
    required String periodType,
    required String periodKey,
    required String reason,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw FinanceValidationException(
        'Savings transfer must be greater than zero.',
      );
    }
    final userRef = _db.collection('users').doc(uid);
    final transferRef = userRef.collection('transactions').doc();
    final logRef = userRef.collection('savings_transfers').doc();
    await _db.runTransaction((dbTransaction) async {
      final userSnap = await dbTransaction.get(userRef);
      final profile = userSnap.data() ?? {};
      var savingsBalance = ((profile['savingsBalance'] ?? 0) as num).toDouble();
      var extraSavingsBalance = ((profile['extraSavingsBalance'] ?? 0) as num)
          .toDouble();
      final availableSavings = savingsBalance + extraSavingsBalance;
      if (amount > availableSavings) {
        throw FinanceValidationException(
          'Insufficient savings for this budget support transfer.',
        );
      }
      final savingsDebit = amount.clamp(0, savingsBalance).toDouble();
      savingsBalance -= savingsDebit;
      extraSavingsBalance -= amount - savingsDebit;
      final mainBalance =
          ((profile['mainBalance'] ?? 0) as num).toDouble() + amount;
      dbTransaction.set(transferRef, {
        ...FinancialTransaction(
          id: '',
          title: 'Savings support for budget',
          amount: amount,
          date: DateTime.now(),
          category: 'Savings',
          type: 'transfer',
          note: reason,
          linkedBudgetCategory: 'Savings',
          transferDirection: 'savings_to_budget',
        ).toMap(),
        'periodType': periodType,
        'periodKey': periodKey,
      });
      dbTransaction.set(logRef, {
        'amount': amount,
        'date': FieldValue.serverTimestamp(),
        'direction': 'savings_to_budget',
        'periodType': periodType,
        'periodKey': periodKey,
        'reason': reason,
        'linkedTransactionId': transferRef.id,
      });
      dbTransaction.set(userRef, {
        'mainBalance': mainBalance,
        'savingsBalance': savingsBalance,
        'extraSavingsBalance': extraSavingsBalance,
        'totalBalance': mainBalance + savingsBalance + extraSavingsBalance,
        'lastFinancialUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> addBudgetPlan(
    BudgetPlan budgetPlan, {
    bool allowSavingsAdjustment = false,
  }) async {
    _validateBudgetPlan(budgetPlan.allocatedAmount, budgetPlan.category);
    final map = budgetPlan.toMap();
    map['createdAt'] = FieldValue.serverTimestamp();
    final userRef = _db.collection('users').doc(uid);
    final summaryRef = _monthlySummaryRef(budgetPlan.monthKey);
    final budgetRef = userRef.collection('budget_plans').doc();
    await _db.runTransaction((dbTransaction) async {
      final userSnap = await dbTransaction.get(userRef);
      final summarySnap = await dbTransaction.get(summaryRef);
      final updated = _applyBudgetDeltaToSummary(
        summary: summarySnap.data() ?? _emptyMonthlySummary(),
        profile: userSnap.data() ?? {},
        delta: budgetPlan.allocatedAmount,
        allowSavingsAdjustment: allowSavingsAdjustment,
      );
      dbTransaction.set(budgetRef, map);
      dbTransaction.set(summaryRef, updated.summary, SetOptions(merge: true));
      dbTransaction.set(userRef, updated.profilePatch, SetOptions(merge: true));
    });
  }

  Future<void> updateBudgetPlan(
    String budgetId,
    Map<String, dynamic> data, {
    bool allowSavingsAdjustment = false,
  }) async {
    final category = data['category'] as String? ?? 'Others';
    final amount = (data['allocatedAmount'] as num? ?? 0).toDouble();
    final monthKey = data['monthKey'] as String? ?? _monthKey(DateTime.now());
    _validateBudgetPlan(amount, category);

    final userRef = _db.collection('users').doc(uid);
    final budgetRef = userRef.collection('budget_plans').doc(budgetId);
    final summaryRef = _monthlySummaryRef(monthKey);

    await _db.runTransaction((dbTransaction) async {
      final userSnap = await dbTransaction.get(userRef);
      final budgetSnap = await dbTransaction.get(budgetRef);
      final summarySnap = await dbTransaction.get(summaryRef);
      final oldAmount = (budgetSnap.data()?['allocatedAmount'] ?? 0).toDouble();
      final updated = _applyBudgetDeltaToSummary(
        summary: summarySnap.data() ?? _emptyMonthlySummary(),
        profile: userSnap.data() ?? {},
        delta: amount - oldAmount,
        allowSavingsAdjustment: allowSavingsAdjustment,
      );
      dbTransaction.update(budgetRef, data);
      dbTransaction.set(summaryRef, updated.summary, SetOptions(merge: true));
      dbTransaction.set(userRef, updated.profilePatch, SetOptions(merge: true));
    });
  }

  Future<double> monthlyIncomeForCurrentMonth() async {
    final key = _monthKey(DateTime.now());
    final summary = await getMonthlySummary(monthKey: key).first;
    final profile = await getUserProfile().first;
    final summaryIncome = (summary['monthlyIncome'] ?? 0).toDouble();
    if (summaryIncome > 0) return summaryIncome;
    return (profile['monthlyIncome'] ?? 0).toDouble();
  }

  Future<void> ensureMonthlySavingsRollover() async {
    final now = DateTime.now();
    final previous = DateTime(now.year, now.month - 1);
    final previousKey = _monthKey(previous);
    final userRef = _db.collection('users').doc(uid);
    final summaryRef = _monthlySummaryRef(previousKey);

    await _db.runTransaction((dbTransaction) async {
      final userSnap = await dbTransaction.get(userRef);
      final profile = userSnap.data() ?? {};
      if (profile['lastClosedMonthKey'] == previousKey) return;

      final summarySnap = await dbTransaction.get(summaryRef);
      final summary = summarySnap.data();
      if (summary == null) {
        dbTransaction.set(userRef, {
          'lastClosedMonthKey': previousKey,
        }, SetOptions(merge: true));
        return;
      }

      final leftover = (summary['mainBalance'] ?? 0).toDouble();
      if (leftover <= 0) {
        dbTransaction.set(userRef, {
          'lastClosedMonthKey': previousKey,
        }, SetOptions(merge: true));
        return;
      }

      final savingsBalance =
          (profile['savingsBalance'] ?? summary['savingsBalance'] ?? 0)
              .toDouble();
      final extraSavingsBalance =
          (profile['extraSavingsBalance'] ??
                  summary['extraSavingsBalance'] ??
                  0)
              .toDouble();
      final newSavings = savingsBalance + leftover;
      final totalBalance = newSavings + extraSavingsBalance;

      dbTransaction.set(summaryRef, {
        'mainBalance': 0.0,
        'savingsBalance': newSavings,
        'totalBalance': totalBalance,
        'closedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      dbTransaction.set(userRef, {
        'mainBalance': 0.0,
        'savingsBalance': newSavings,
        'extraSavingsBalance': extraSavingsBalance,
        'totalBalance': totalBalance,
        'lastClosedMonthKey': previousKey,
        'lastFinancialUpdate': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    });
  }

  Future<void> deleteBudgetPlan(String budgetId) async {
    final userRef = _db.collection('users').doc(uid);
    final budgetRef = userRef.collection('budget_plans').doc(budgetId);

    await _db.runTransaction((dbTransaction) async {
      final userSnap = await dbTransaction.get(userRef);
      final budgetSnap = await dbTransaction.get(budgetRef);
      if (!budgetSnap.exists) return;
      final data = budgetSnap.data() ?? {};
      final monthKey = data['monthKey'] as String? ?? _monthKey(DateTime.now());
      final summaryRef = _monthlySummaryRef(monthKey);
      final summarySnap = await dbTransaction.get(summaryRef);
      final oldAmount = (data['allocatedAmount'] ?? 0).toDouble();
      final updated = _applyBudgetDeltaToSummary(
        summary: summarySnap.data() ?? _emptyMonthlySummary(),
        profile: userSnap.data() ?? {},
        delta: -oldAmount,
        allowSavingsAdjustment: true,
      );
      dbTransaction.delete(budgetRef);
      dbTransaction.set(summaryRef, updated.summary, SetOptions(merge: true));
      dbTransaction.set(userRef, updated.profilePatch, SetOptions(merge: true));
    });
  }

  // --------------- Saving Goals ---------------

  Stream<List<SavingGoal>> getSavingGoals() {
    return _db
        .collection('users')
        .doc(uid)
        .collection('saving_goals')
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => SavingGoal.fromFirestore(doc))
              .toList(),
        );
  }

  Future<void> addSavingGoal(SavingGoal goal) async {
    await _validateSavingGoalFeasibility(goal);
    final map = goal.toMap();
    map['createdAt'] = FieldValue.serverTimestamp();
    await _db.collection('users').doc(uid).collection('saving_goals').add(map);
  }

  Future<void> updateSavingGoal(
    String goalId,
    Map<String, dynamic> data,
  ) async {
    final normalized = Map<String, dynamic>.from(data);
    if (normalized['targetDate'] is DateTime) {
      normalized['targetDate'] = Timestamp.fromDate(
        normalized['targetDate'] as DateTime,
      );
    }
    if (normalized['reminderDate'] is DateTime) {
      normalized['reminderDate'] = Timestamp.fromDate(
        normalized['reminderDate'] as DateTime,
      );
    }
    return _db
        .collection('users')
        .doc(uid)
        .collection('saving_goals')
        .doc(goalId)
        .update(normalized);
  }

  Future<void> deleteSavingGoal(String goalId) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('saving_goals')
        .doc(goalId)
        .delete();
  }

  Future<void> addContribution(String goalId, double amount) async {
    if (!amount.isFinite || amount <= 0) {
      throw FinanceValidationException(
        'Contribution must be greater than zero.',
      );
    }
    await _validateSavingsAllocation(additionalAllocation: amount);
    final goalRef = _db
        .collection('users')
        .doc(uid)
        .collection('saving_goals')
        .doc(goalId);
    final doc = await goalRef.get();
    if (!doc.exists) return;
    final current = (doc.data()?['currentAmount'] ?? 0.0).toDouble();
    final updated = current + amount;
    final userRef = _db.collection('users').doc(uid);
    final txRef = userRef.collection('transactions').doc();

    await _db.runTransaction((dbTransaction) async {
      dbTransaction.update(goalRef, {
        'currentAmount': updated,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      dbTransaction.set(goalRef.collection('contributions').doc(), {
        'amount': amount,
        'date': FieldValue.serverTimestamp(),
      });
      dbTransaction.set(txRef, {
        ...FinancialTransaction(
          id: '',
          title: 'Savings contribution',
          amount: amount,
          date: DateTime.now(),
          category: 'Savings',
          type: 'transfer',
          note: 'Contribution allocated to ${doc.data()?['title'] ?? 'goal'}.',
          linkedBudgetCategory: 'Savings',
          transferDirection: 'savings_to_goal',
        ).toMap(),
        'linkedGoalId': goalId,
      });
    });
  }

  Future<void> updateContribution(
    String goalId,
    String contributionId,
    double amount,
  ) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('saving_goals')
        .doc(goalId)
        .collection('contributions')
        .doc(contributionId)
        .update({'amount': amount});
  }

  Stream<List<Map<String, dynamic>>> getContributions(String goalId) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('saving_goals')
        .doc(goalId)
        .collection('contributions')
        .orderBy('date', descending: true)
        .limit(20)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs.map((doc) {
            final data = doc.data();
            return {
              'id': doc.id,
              'amount': (data['amount'] ?? 0).toDouble(),
              'date': (data['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
            };
          }).toList(),
        );
  }

  Future<void> _validateSavingGoalFeasibility(SavingGoal goal) async {
    if (goal.title.trim().isEmpty) {
      throw FinanceValidationException('Journey title is required.');
    }
    if (!goal.targetAmount.isFinite || goal.targetAmount <= 0) {
      throw FinanceValidationException(
        'Target amount must be greater than zero.',
      );
    }
    if (goal.currentAmount < 0 || goal.currentAmount > goal.targetAmount) {
      throw FinanceValidationException(
        'Current savings must stay between zero and the target amount.',
      );
    }
    await _validateSavingsAllocation(additionalAllocation: goal.currentAmount);

    final key = _monthKey(DateTime.now());
    final summary = await getMonthlySummary(monthKey: key).first;
    final profile = await getUserProfile().first;
    final income =
        ((summary['monthlyIncome'] ?? profile['monthlyIncome'] ?? 0) as num)
            .toDouble();
    final totalBudgeted = ((summary['totalBudgeted'] ?? 0) as num).toDouble();
    final totalExpenses = ((summary['totalExpenses'] ?? 0) as num).toDouble();
    final remainingBudget = (income - totalBudgeted - totalExpenses).clamp(
      0,
      double.infinity,
    );
    if (goal.monthlyTarget > remainingBudget && remainingBudget > 0) {
      throw FinanceValidationException(
        'This journey needs ${goal.monthlyTarget.toStringAsFixed(0)} per month, which is above the remaining budget. Adjust budget or choose a later date.',
      );
    }
  }

  Future<void> _validateSavingsAllocation({
    required double additionalAllocation,
  }) async {
    final goals = await getSavingGoals().first;
    final profile = await getUserProfile().first;
    final availableSavings =
        ((profile['savingsBalance'] ?? 0) as num).toDouble() +
        ((profile['extraSavingsBalance'] ?? 0) as num).toDouble();
    if (availableSavings <= 0) return;
    final allocated = goals.fold<double>(
      0,
      (total, goal) => total + goal.currentAmount,
    );
    if (allocated + additionalAllocation > availableSavings) {
      throw FinanceValidationException(
        'Savings cannot be over-allocated. Add savings first or reduce goal allocation.',
      );
    }
  }

  // --------------- Course Progress ---------------

  Future<void> saveCourseProgress(
    String courseId,
    int completedLessons,
    int totalLessons,
  ) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('course_progress')
        .doc(courseId)
        .set({
          'completedLessons': completedLessons,
          'totalLessons': totalLessons,
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>> getCourseProgress(String courseId) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('course_progress')
        .doc(courseId)
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  Stream<Map<String, Map<String, dynamic>>> getAllCourseProgress() {
    return _db
        .collection('users')
        .doc(uid)
        .collection('course_progress')
        .snapshots()
        .map(
          (snapshot) => {for (final doc in snapshot.docs) doc.id: doc.data()},
        );
  }

  Future<void> setLessonCompleted(
    String courseId,
    String lessonId,
    bool completed,
  ) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('course_progress')
        .doc(courseId)
        .set({
          'completedLessonIds': completed
              ? FieldValue.arrayUnion([lessonId])
              : FieldValue.arrayRemove([lessonId]),
          'lastUpdated': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Future<void> saveQuizSubmission(
    String courseId,
    String quizId,
    int score,
    int total,
    Map<String, int> answers,
  ) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('quiz_scores')
        .doc('${courseId}_$quizId')
        .set({
          'quizId': quizId,
          'courseId': courseId,
          'score': score,
          'total': total,
          'percentage': total == 0 ? 0 : ((score / total) * 100).round(),
          'answers': answers,
          'date': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>> getQuizScore(String courseId, String quizId) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('quiz_scores')
        .doc('${courseId}_$quizId')
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  Stream<Map<String, Map<String, dynamic>>> getAllQuizScores() {
    return _db
        .collection('users')
        .doc(uid)
        .collection('quiz_scores')
        .snapshots()
        .map(
          (snapshot) => {for (final doc in snapshot.docs) doc.id: doc.data()},
        );
  }

  Future<void> saveQuizScore(
    String courseId,
    String quizId,
    int score,
    int total,
  ) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('quiz_scores')
        .doc('${courseId}_$quizId')
        .set({
          'score': score,
          'total': total,
          'percentage': ((score / total) * 100).round(),
          'date': FieldValue.serverTimestamp(),
        });
  }

  // --------------- User Profile ---------------

  Future<void> saveUserProfile(Map<String, dynamic> data) async {
    await _db.collection('users').doc(uid).set(data, SetOptions(merge: true));
  }

  Stream<Map<String, dynamic>> getUserProfile() {
    return _db
        .collection('users')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.data() ?? {});
  }

  Stream<List<Map<String, dynamic>>> getMarketplacePartners() {
    return _db
        .collection('marketplace_partners')
        .orderBy('priority')
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .where(
                (partner) =>
                    (partner['status'] ?? 'active') == 'active' &&
                    (partner['approved'] ?? true) == true,
              )
              .toList(),
        );
  }

  Stream<Map<String, dynamic>> getMarketplaceUserState() {
    return _db
        .collection('users')
        .doc(uid)
        .collection('marketplace_state')
        .doc('default')
        .snapshots()
        .map((doc) => doc.data() ?? const <String, dynamic>{});
  }

  Future<void> saveMarketplaceOnboarding({
    required String intent,
    required String riskProfile,
    required String timeHorizon,
    required String preferredOutcome,
  }) {
    return _db.collection('users').doc(uid).set({
      'marketplaceIntent': intent,
      'marketplaceRiskProfile': riskProfile,
      'marketplaceTimeHorizon': timeHorizon,
      'marketplacePreferredOutcome': preferredOutcome,
      'marketplaceOnboardedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> setMarketplacePartnerSavedState({
    required String partnerId,
    required String field,
    required bool saved,
  }) {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('marketplace_state')
        .doc('default');
    return ref.set({
      field: saved
          ? FieldValue.arrayUnion([partnerId])
          : FieldValue.arrayRemove([partnerId]),
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> markMarketplacePartnerViewed(String partnerId) {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('marketplace_state')
        .doc('default');
    return ref
        .set({
          'recentlyViewedIds': FieldValue.arrayRemove([partnerId]),
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true))
        .then(
          (_) => ref.set({
            'recentlyViewedIds': FieldValue.arrayUnion([partnerId]),
            'updatedAt': FieldValue.serverTimestamp(),
          }, SetOptions(merge: true)),
        );
  }

  Future<void> saveMarketplaceComparisonHistory(List<String> partnerIds) async {
    final ref = _db
        .collection('users')
        .doc(uid)
        .collection('marketplace_state')
        .doc('default');
    await ref.collection('comparison_history').add({
      'partnerIds': partnerIds,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await ref.set({
      'lastComparedPartnerIds': partnerIds,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> logMarketplaceEvent(
    String eventName, {
    Map<String, dynamic>? payload,
  }) async {
    try {
      await _db
          .collection('users')
          .doc(uid)
          .collection('marketplace_events')
          .add({
            'eventName': eventName,
            'payload': payload ?? const <String, dynamic>{},
            'createdAt': FieldValue.serverTimestamp(),
          });
    } catch (error, stackTrace) {
      debugPrint(
        '[FirestoreService] marketplace analytics failed: $eventName - $error',
      );
      debugPrint('$stackTrace');
    }
  }

  Future<DocumentReference<Map<String, dynamic>>> createMarketplaceLead({
    required String partnerId,
    required String partnerName,
    required String category,
    required String applicantName,
    required String contact,
    Map<String, dynamic>? context,
  }) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('marketplace_leads')
        .add({
          'partnerId': partnerId,
          'partnerName': partnerName,
          'category': category,
          'applicantName': applicantName,
          'contact': contact,
          'status': 'started',
          'source': 'marketplace_detail',
          'context': context ?? const <String, dynamic>{},
          'createdAt': FieldValue.serverTimestamp(),
          'updatedAt': FieldValue.serverTimestamp(),
        });
  }

  Future<void> toggleForumLike(String postId, bool liked) async {
    final postRef = _db.collection('forum_posts').doc(postId);
    final likeRef = postRef.collection('likes').doc(uid);

    if (liked) {
      await likeRef.set({
        'userId': uid,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await postRef.set({
        'likes': FieldValue.increment(1),
      }, SetOptions(merge: true));
      return;
    }

    await likeRef.delete();
    await postRef.set({
      'likes': FieldValue.increment(-1),
    }, SetOptions(merge: true));
  }

  Stream<bool> isForumPostLiked(String postId) {
    return _db
        .collection('forum_posts')
        .doc(postId)
        .collection('likes')
        .doc(uid)
        .snapshots()
        .map((doc) => doc.exists);
  }

  Future<void> awardAchievement(String id, String title) async {
    await _db
        .collection('users')
        .doc(uid)
        .collection('achievements')
        .doc(id)
        .set({
          'id': id,
          'title': title,
          'earnedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
  }

  void _validateTransaction(FinancialTransaction transaction) {
    if (transaction.title.trim().isEmpty) {
      throw FinanceValidationException('Transaction description is required.');
    }
    if (transaction.amount <= 0 || transaction.amount.isNaN) {
      throw FinanceValidationException(
        'Transaction amount must be greater than zero.',
      );
    }
    if (!['income', 'expense', 'transfer'].contains(transaction.type)) {
      throw FinanceValidationException(
        'Transaction type must be income, expense, or transfer.',
      );
    }
  }

  void _validateBudgetPlan(double amount, String category) {
    if (!amount.isFinite || amount < 0) {
      throw FinanceValidationException(
        'Budget allocation must be a valid positive amount.',
      );
    }
    if (!AppConstants.budgetCategories.contains(_normalizeCategory(category))) {
      throw FinanceValidationException('Choose a valid budget category.');
    }
  }

  DocumentReference<Map<String, dynamic>> _monthlySummaryRef(String monthKey) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('monthly_summaries')
        .doc(monthKey);
  }

  String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  String _periodKeyFor(DateTime date, String periodType) {
    switch (periodType) {
      case 'daily':
        return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
      case 'weekly':
        final normalized = DateTime(date.year, date.month, date.day);
        final firstDay = DateTime(date.year, 1, 1);
        final offset = firstDay.weekday - DateTime.monday;
        final firstMonday = firstDay.subtract(
          Duration(days: offset < 0 ? 6 : offset),
        );
        final week = (normalized.difference(firstMonday).inDays ~/ 7) + 1;
        return '${date.year}-W${week.toString().padLeft(2, '0')}';
      case 'yearly':
        return '${date.year}';
      case 'monthly':
      default:
        return _monthKey(date);
    }
  }

  Map<String, dynamic> _emptyMonthlySummary() {
    return {
      'monthlyIncome': 0.0,
      'totalExpenses': 0.0,
      'mainBalance': 0.0,
      'savingsBalance': 0.0,
      'extraSavingsBalance': 0.0,
      'totalBudgeted': 0.0,
      'availableToAllocate': 0.0,
      'categorySpent': <String, dynamic>{},
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  _FinanceUpdate _applyBudgetDeltaToSummary({
    required Map<String, dynamic> summary,
    required Map<String, dynamic> profile,
    required double delta,
    required bool allowSavingsAdjustment,
  }) {
    final summaryIncome = (summary['monthlyIncome'] ?? 0).toDouble();
    final monthlyIncome = summaryIncome > 0
        ? summaryIncome
        : (profile['monthlyIncome'] ?? 0).toDouble();
    final totalExpenses = (summary['totalExpenses'] ?? 0).toDouble();
    var totalBudgeted = (summary['totalBudgeted'] ?? 0).toDouble();
    var mainBalance = (summary['mainBalance'] ?? profile['mainBalance'] ?? 0)
        .toDouble();
    var savingsBalance =
        (summary['savingsBalance'] ?? profile['savingsBalance'] ?? 0)
            .toDouble();
    var extraSavingsBalance =
        (summary['extraSavingsBalance'] ?? profile['extraSavingsBalance'] ?? 0)
            .toDouble();

    if (mainBalance <= 0 &&
        monthlyIncome > 0 &&
        totalBudgeted <= 0 &&
        totalExpenses <= 0) {
      mainBalance = monthlyIncome;
    }

    if (delta > 0) {
      final fromMain = delta.clamp(0, mainBalance).toDouble();
      final fromSavings = delta - fromMain;
      if (fromSavings > 0) {
        final availableSavings = savingsBalance + extraSavingsBalance;
        if (!allowSavingsAdjustment) {
          throw SavingsUsageRequiredException(fromSavings);
        }
        if (fromSavings > availableSavings) {
          throw FinanceValidationException(
            'Insufficient funds for this budget increase. Reduce allocations or add income.',
          );
        }
        final savingsDebit = fromSavings.clamp(0, savingsBalance).toDouble();
        savingsBalance -= savingsDebit;
        extraSavingsBalance -= (fromSavings - savingsDebit);
      }
      mainBalance -= fromMain;
    } else if (delta < 0) {
      mainBalance += delta.abs();
    }

    totalBudgeted = (totalBudgeted + delta).clamp(0, double.infinity);
    final nextSummary = {
      ...summary,
      'monthlyIncome': monthlyIncome,
      'totalExpenses': totalExpenses,
      'mainBalance': mainBalance,
      'savingsBalance': savingsBalance,
      'extraSavingsBalance': extraSavingsBalance,
      'totalBudgeted': totalBudgeted,
      'availableToAllocate': (monthlyIncome - totalBudgeted - totalExpenses)
          .clamp(0, double.infinity),
      'totalBalance': mainBalance + savingsBalance + extraSavingsBalance,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final profilePatch = {
      'mainBalance': nextSummary['mainBalance'],
      'savingsBalance': nextSummary['savingsBalance'],
      'extraSavingsBalance': nextSummary['extraSavingsBalance'],
      'totalBalance': nextSummary['totalBalance'],
      'lastFinancialUpdate': FieldValue.serverTimestamp(),
    };

    return _FinanceUpdate(nextSummary, profilePatch);
  }

  _FinanceUpdate _applyTransactionToSummary({
    required Map<String, dynamic> summary,
    required FinancialTransaction transaction,
    required List<BudgetPlan> budgets,
    required Map<String, dynamic> profile,
    required bool isReversal,
    required bool allowSavingsWithdrawal,
  }) {
    final sign = isReversal ? -1.0 : 1.0;
    final category = _normalizeCategory(transaction.category);
    final categorySpent = Map<String, dynamic>.from(
      summary['categorySpent'] ?? {},
    );
    final summaryIncome = (summary['monthlyIncome'] ?? 0).toDouble();
    final monthlyIncome = summaryIncome > 0
        ? summaryIncome
        : (profile['monthlyIncome'] ?? 0).toDouble();
    final totalExpenses = (summary['totalExpenses'] ?? 0).toDouble();
    var mainBalance = (summary['mainBalance'] ?? profile['mainBalance'] ?? 0)
        .toDouble();
    var savingsBalance =
        (summary['savingsBalance'] ?? profile['savingsBalance'] ?? 0)
            .toDouble();
    var extraSavingsBalance =
        (summary['extraSavingsBalance'] ?? profile['extraSavingsBalance'] ?? 0)
            .toDouble();
    var nextMonthlyIncome = monthlyIncome;
    var nextTotalExpenses = totalExpenses;

    if (transaction.type == 'income') {
      final delta = transaction.amount * sign;
      nextMonthlyIncome += delta;
      mainBalance += delta;
    } else if (transaction.type == 'expense') {
      final delta = transaction.amount * sign;
      final spentSoFar = (categorySpent[category] ?? 0).toDouble();
      final categoryBudget = budgets
          .where((budget) => budget.category == category)
          .fold<double>(0, (total, budget) => total + budget.allocatedAmount);
      final remainingCategoryBudget = categoryBudget - spentSoFar;

      if (!isReversal) {
        var fromMain = transaction.amount;
        var fromSavings = 0.0;
        if (categoryBudget > 0) {
          fromMain = 0;
          if (transaction.amount > remainingCategoryBudget) {
            fromSavings =
                transaction.amount -
                remainingCategoryBudget.clamp(0, transaction.amount).toDouble();
          }
        }
        if (fromMain > mainBalance) {
          fromSavings += fromMain - mainBalance;
          fromMain = mainBalance;
        }
        final availableSavings = savingsBalance + extraSavingsBalance;
        if (fromSavings > 0 && !allowSavingsWithdrawal) {
          throw SavingsUsageRequiredException(fromSavings);
        }
        if (fromMain > mainBalance || fromSavings > availableSavings) {
          throw FinanceValidationException(
            'Insufficient balance. Add income, reduce the expense, or increase savings before proceeding.',
          );
        }
        mainBalance -= fromMain;
        if (fromSavings > 0) {
          final savingsDebit = fromSavings.clamp(0, savingsBalance).toDouble();
          savingsBalance -= savingsDebit;
          extraSavingsBalance -= (fromSavings - savingsDebit);
        }
        summary['_savingsWithdrawal'] = fromSavings;
      } else {
        mainBalance += transaction.amount;
      }

      categorySpent[category] = (spentSoFar + delta).clamp(0, double.infinity);
      nextTotalExpenses = (totalExpenses + delta).clamp(0, double.infinity);
    }

    final nextSummary = {
      'monthlyIncome': nextMonthlyIncome.clamp(0, double.infinity),
      'totalExpenses': nextTotalExpenses,
      'mainBalance': mainBalance,
      'savingsBalance': savingsBalance,
      'extraSavingsBalance': extraSavingsBalance,
      'totalBudgeted': summary['totalBudgeted'] ?? 0.0,
      'availableToAllocate':
          ((nextMonthlyIncome.clamp(0, double.infinity) as num).toDouble() -
                  ((summary['totalBudgeted'] ?? 0) as num).toDouble() -
                  nextTotalExpenses)
              .clamp(0, double.infinity),
      'totalBalance': mainBalance + savingsBalance + extraSavingsBalance,
      'categorySpent': categorySpent,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    final savingsWithdrawal = (summary.remove('_savingsWithdrawal') ?? 0.0)
        .toDouble();

    final profilePatch = {
      'monthlyIncome': nextSummary['monthlyIncome'],
      'mainBalance': nextSummary['mainBalance'],
      'savingsBalance': nextSummary['savingsBalance'],
      'extraSavingsBalance': nextSummary['extraSavingsBalance'],
      'totalBalance': nextSummary['totalBalance'],
      'lastFinancialUpdate': FieldValue.serverTimestamp(),
    };

    return _FinanceUpdate(
      nextSummary,
      profilePatch,
      savingsWithdrawal: savingsWithdrawal,
    );
  }

  String categoryFromTransaction(FinancialTransaction transaction) {
    return _normalizeCategory(transaction.category);
  }

  int _healthScore({
    required double income,
    required double expenses,
    required double budget,
    required double savings,
  }) {
    var score = 100;
    if (income > 0) {
      score -= ((expenses / income).clamp(0.0, 1.4) * 35).round();
    } else if (expenses > 0) {
      score -= 35;
    }
    if (budget > 0) {
      score -= ((expenses / budget).clamp(0.0, 1.4) * 25).round();
    }
    if (savings <= 0) {
      score -= 15;
    } else if (income > 0 && savings < income * 0.1) {
      score -= 8;
    }
    return score.clamp(0, 100);
  }

  String _normalizeCategory(String category) {
    switch (category) {
      case 'Grocery':
      case 'Food':
        return 'Groceries';
      case 'Health':
        return 'Healthcare';
      default:
        return AppConstants.budgetCategories.contains(category)
            ? category
            : 'Others';
    }
  }
}

class _FinanceUpdate {
  _FinanceUpdate(this.summary, this.profilePatch, {this.savingsWithdrawal = 0});

  final Map<String, dynamic> summary;
  final Map<String, dynamic> profilePatch;
  final double savingsWithdrawal;
}
