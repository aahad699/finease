import 'package:cloud_firestore/cloud_firestore.dart';

class BudgetPlan {
  BudgetPlan({
    required this.id,
    required this.title,
    required this.category,
    required this.allocatedAmount,
    required this.notes,
    required this.monthKey,
    required this.createdAt,
    this.allocationPercent,
    this.allocationMode = 'manual',
    this.periodType = 'monthly',
    this.periodKey,
    this.isDebtPayment = false,
    this.reminderDate,
  });

  final String id;
  final String title;
  final String category;
  final double allocatedAmount;
  final String notes;
  final String monthKey;
  final DateTime? createdAt;
  final double? allocationPercent;
  final String allocationMode;
  final String periodType;
  final String? periodKey;
  final bool isDebtPayment;
  final DateTime? reminderDate;

  factory BudgetPlan.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return BudgetPlan(
      id: doc.id,
      title: data['title'] ?? '',
      category: data['category'] ?? 'General',
      allocatedAmount: (data['allocatedAmount'] ?? 0).toDouble(),
      notes: data['notes'] ?? '',
      monthKey: data['monthKey'] ?? '',
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
      allocationPercent: (data['allocationPercent'] as num?)?.toDouble(),
      allocationMode: data['allocationMode'] ?? 'manual',
      periodType: data['periodType'] ?? 'monthly',
      periodKey: data['periodKey'] ?? data['monthKey'],
      isDebtPayment: data['isDebtPayment'] ?? false,
      reminderDate: (data['reminderDate'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    final resolvedPeriodKey = periodKey ?? monthKey;
    final map = {
      'title': title,
      'category': category,
      'allocatedAmount': allocatedAmount,
      'notes': notes,
      'monthKey': monthKey,
      'periodKey': resolvedPeriodKey,
      'periodType': periodType,
      'allocationPercent': allocationPercent,
      'allocationMode': allocationMode,
      'isDebtPayment': isDebtPayment,
    };
    if (reminderDate != null) {
      map['reminderDate'] = Timestamp.fromDate(reminderDate!);
    }
    return map;
  }
}
