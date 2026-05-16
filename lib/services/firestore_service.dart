import 'package:cloud_firestore/cloud_firestore.dart';
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
      return budgets.where((budget) => budget.monthKey == monthKey).toList();
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

  Future<void> addSavingGoal(SavingGoal goal) {
    final map = goal.toMap();
    map['createdAt'] = FieldValue.serverTimestamp();
    return _db.collection('users').doc(uid).collection('saving_goals').add(map);
  }

  Future<void> updateSavingGoal(String goalId, Map<String, dynamic> data) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('saving_goals')
        .doc(goalId)
        .update(data);
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
    final goalRef = _db
        .collection('users')
        .doc(uid)
        .collection('saving_goals')
        .doc(goalId);
    final doc = await goalRef.get();
    if (!doc.exists) return;
    final current = (doc.data()?['currentAmount'] ?? 0.0).toDouble();
    final updated = current + amount;

    await goalRef.update({'currentAmount': updated});

    // Log the contribution
    await goalRef.collection('contributions').add({
      'amount': amount,
      'date': FieldValue.serverTimestamp(),
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
    if (!['income', 'expense'].contains(transaction.type)) {
      throw FinanceValidationException(
        'Transaction type must be income or expense.',
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
    } else {
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

    final profilePatch = {
      'monthlyIncome': nextSummary['monthlyIncome'],
      'mainBalance': nextSummary['mainBalance'],
      'savingsBalance': nextSummary['savingsBalance'],
      'extraSavingsBalance': nextSummary['extraSavingsBalance'],
      'totalBalance': nextSummary['totalBalance'],
      'lastFinancialUpdate': FieldValue.serverTimestamp(),
    };

    return _FinanceUpdate(nextSummary, profilePatch);
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
  _FinanceUpdate(this.summary, this.profilePatch);

  final Map<String, dynamic> summary;
  final Map<String, dynamic> profilePatch;
}
