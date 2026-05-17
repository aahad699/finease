import 'package:cloud_firestore/cloud_firestore.dart';

class FinancialTransaction {
  final String id;
  final String title;
  final double amount;
  final DateTime date;
  final String category;
  final String type; // 'income', 'expense', or 'transfer'
  final String note;
  final DateTime? deadline;
  final String? linkedBudgetCategory;
  final String? transferDirection;
  final String? dayKey;
  final String? weekKey;
  final String? monthKey;
  final String? yearKey;

  FinancialTransaction({
    required this.id,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
    required this.type,
    this.note = '',
    this.deadline,
    this.linkedBudgetCategory,
    this.transferDirection,
    this.dayKey,
    this.weekKey,
    this.monthKey,
    this.yearKey,
  });

  factory FinancialTransaction.fromFirestore(DocumentSnapshot doc) {
    Map data = doc.data() as Map;
    final date = (data['date'] as Timestamp?)?.toDate() ?? DateTime.now();
    return FinancialTransaction(
      id: doc.id,
      title: data['title'] ?? '',
      amount: (data['amount'] ?? 0).toDouble(),
      date: date,
      category: data['category'] ?? '',
      type: data['type'] ?? 'expense',
      note: data['note'] ?? '',
      deadline: (data['deadline'] as Timestamp?)?.toDate(),
      linkedBudgetCategory: data['linkedBudgetCategory'],
      transferDirection: data['transferDirection'],
      dayKey: data['dayKey'] ?? _dayKey(date),
      weekKey: data['weekKey'] ?? _weekKey(date),
      monthKey: data['monthKey'] ?? _monthKey(date),
      yearKey: data['yearKey'] ?? '${date.year}',
    );
  }

  Map<String, dynamic> toMap() {
    final map = {
      'title': title,
      'amount': amount,
      'date': Timestamp.fromDate(date),
      'category': category,
      'type': type,
      'note': note,
      'linkedBudgetCategory': linkedBudgetCategory ?? category,
      'transferDirection': transferDirection,
      'dayKey': dayKey ?? _dayKey(date),
      'weekKey': weekKey ?? _weekKey(date),
      'monthKey': monthKey ?? _monthKey(date),
      'yearKey': yearKey ?? '${date.year}',
    };
    if (deadline != null) {
      map['deadline'] = Timestamp.fromDate(deadline!);
    }
    return map;
  }

  static String _dayKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  static String _monthKey(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}';
  }

  static String _weekKey(DateTime date) {
    final normalized = DateTime(date.year, date.month, date.day);
    final firstDay = DateTime(date.year, 1, 1);
    final offset = firstDay.weekday - DateTime.monday;
    final firstMonday = firstDay.subtract(
      Duration(days: offset < 0 ? 6 : offset),
    );
    final week = (normalized.difference(firstMonday).inDays ~/ 7) + 1;
    return '${date.year}-W${week.toString().padLeft(2, '0')}';
  }
}
