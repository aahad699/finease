import 'package:cloud_firestore/cloud_firestore.dart';

class SavingGoal {
  final String id;
  final String title;
  final double targetAmount;
  final double currentAmount;
  final DateTime targetDate;
  final String category;
  final String emoji;
  final DateTime? createdAt;
  final String goalType;
  final bool isDebtGoal;
  final String payoffStrategy;
  final DateTime? reminderDate;
  final List<JourneyMilestone> milestones;

  SavingGoal({
    required this.id,
    required this.title,
    required this.targetAmount,
    required this.currentAmount,
    required this.targetDate,
    required this.category,
    this.emoji = 'Goal',
    this.createdAt,
    this.goalType = 'General',
    this.isDebtGoal = false,
    this.payoffStrategy = 'steady',
    this.reminderDate,
    this.milestones = const [],
  });

  factory SavingGoal.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final targetAmount = (data['targetAmount'] ?? 0).toDouble();
    final currentAmount = (data['currentAmount'] ?? 0).toDouble();
    final targetDate =
        (data['targetDate'] as Timestamp?)?.toDate() ??
        DateTime.now().add(const Duration(days: 365));
    final milestones = (data['milestones'] as List<dynamic>?)
        ?.whereType<Map>()
        .map(
          (item) => JourneyMilestone.fromMap(Map<String, dynamic>.from(item)),
        )
        .toList();

    return SavingGoal(
      id: doc.id,
      title: data['title'] ?? '',
      targetAmount: targetAmount,
      currentAmount: currentAmount,
      targetDate: targetDate,
      category: data['category'] ?? 'General',
      emoji: data['emoji'] ?? 'Goal',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      goalType: data['goalType'] ?? data['category'] ?? 'General',
      isDebtGoal: data['isDebtGoal'] ?? false,
      payoffStrategy: data['payoffStrategy'] ?? 'steady',
      reminderDate: (data['reminderDate'] as Timestamp?)?.toDate(),
      milestones:
          milestones ??
          JourneyMilestone.generate(
            targetAmount: targetAmount,
            currentAmount: currentAmount,
            targetDate: targetDate,
          ),
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'title': title,
      'targetAmount': targetAmount,
      'currentAmount': currentAmount,
      'targetDate': Timestamp.fromDate(targetDate),
      'category': category,
      'emoji': emoji,
      'goalType': goalType,
      'isDebtGoal': isDebtGoal,
      'payoffStrategy': payoffStrategy,
      'milestones':
          (milestones.isEmpty
                  ? JourneyMilestone.generate(
                      targetAmount: targetAmount,
                      currentAmount: currentAmount,
                      targetDate: targetDate,
                    )
                  : milestones)
              .map((item) => item.toMap())
              .toList(),
    };
    if (reminderDate != null) {
      map['reminderDate'] = Timestamp.fromDate(reminderDate!);
    }
    return map;
  }

  SavingGoal copyWith({
    String? id,
    String? title,
    double? targetAmount,
    double? currentAmount,
    DateTime? targetDate,
    String? category,
    String? emoji,
    String? goalType,
    bool? isDebtGoal,
    String? payoffStrategy,
    DateTime? reminderDate,
    List<JourneyMilestone>? milestones,
  }) {
    return SavingGoal(
      id: id ?? this.id,
      title: title ?? this.title,
      targetAmount: targetAmount ?? this.targetAmount,
      currentAmount: currentAmount ?? this.currentAmount,
      targetDate: targetDate ?? this.targetDate,
      category: category ?? this.category,
      emoji: emoji ?? this.emoji,
      createdAt: createdAt,
      goalType: goalType ?? this.goalType,
      isDebtGoal: isDebtGoal ?? this.isDebtGoal,
      payoffStrategy: payoffStrategy ?? this.payoffStrategy,
      reminderDate: reminderDate ?? this.reminderDate,
      milestones: milestones ?? this.milestones,
    );
  }

  double get progress =>
      targetAmount > 0 ? (currentAmount / targetAmount).clamp(0.0, 1.0) : 0;
  double get remaining =>
      (targetAmount - currentAmount).clamp(0, double.infinity).toDouble();
  int get daysLeft => targetDate.difference(DateTime.now()).inDays;
  double get monthlyTarget {
    final months = ((daysLeft <= 0 ? 1 : daysLeft) / 30).clamp(
      1,
      double.infinity,
    );
    return remaining / months;
  }

  int get completedMilestones =>
      milestones.where((item) => currentAmount >= item.amount).length;
}

class JourneyMilestone {
  const JourneyMilestone({
    required this.title,
    required this.amount,
    required this.targetDate,
  });

  final String title;
  final double amount;
  final DateTime targetDate;

  factory JourneyMilestone.fromMap(Map<String, dynamic> map) {
    return JourneyMilestone(
      title: map['title'] ?? '',
      amount: (map['amount'] ?? 0).toDouble(),
      targetDate:
          (map['targetDate'] as Timestamp?)?.toDate() ??
          DateTime.now().add(const Duration(days: 30)),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'amount': amount,
      'targetDate': Timestamp.fromDate(targetDate),
    };
  }

  static List<JourneyMilestone> generate({
    required double targetAmount,
    required double currentAmount,
    required DateTime targetDate,
  }) {
    if (targetAmount <= 0) return const [];
    final now = DateTime.now();
    final months = (targetDate.difference(now).inDays / 30).ceil().clamp(1, 24);
    final step =
        (targetAmount - currentAmount).clamp(0, double.infinity).toDouble() /
        months;
    return List.generate(months, (index) {
      final number = index + 1;
      return JourneyMilestone(
        title: 'Month $number target',
        amount: (currentAmount + (step * number)).clamp(0, targetAmount),
        targetDate: DateTime(now.year, now.month + number, now.day),
      );
    });
  }
}
