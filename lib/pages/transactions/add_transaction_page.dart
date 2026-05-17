import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/transaction.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';

class AddTransactionPage extends StatefulWidget {
  const AddTransactionPage({super.key});

  @override
  State<AddTransactionPage> createState() => _AddTransactionPageState();
}

class _AddTransactionPageState extends State<AddTransactionPage>
    with SingleTickerProviderStateMixin {
  final _titleCtrl = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _noteCtrl = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  String _type = 'expense';
  String _category = 'Groceries';
  DateTime _date = DateTime.now();
  DateTime? _deadline;
  bool _saving = false;
  Timer? _impactDebounce;
  TransactionImpactPreview? _impact;
  String? _impactError;

  late final AnimationController _anim;
  late final Animation<double> _fadeAnim;

  final List<_Cat> _categories = const [
    _Cat('Education', Icons.school_rounded, Color(0xFF0099CC)),
    _Cat('Groceries', Icons.local_grocery_store_rounded, Color(0xFFFF6B35)),
    _Cat('Electricity', Icons.bolt_rounded, Color(0xFFFF4B5C)),
    _Cat('Transport', Icons.directions_car_rounded, AppTheme.primary),
    _Cat('Entertainment', Icons.movie_rounded, Color(0xFF8B5CF6)),
    _Cat('Healthcare', Icons.health_and_safety_rounded, Color(0xFF06C270)),
    _Cat('Savings', Icons.savings_rounded, Color(0xFF059669)),
    _Cat('Salary', Icons.work_rounded, Color(0xFF06C270)),
    _Cat('Others', Icons.category_rounded, Color(0xFF6B7A99)),
  ];

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnim = CurvedAnimation(parent: _anim, curve: Curves.easeOutCubic);
    _amountCtrl.addListener(_scheduleImpactPreview);
    _titleCtrl.addListener(_scheduleImpactPreview);
    _anim.forward();
    _scheduleImpactPreview();
  }

  @override
  void dispose() {
    _impactDebounce?.cancel();
    _anim.dispose();
    _titleCtrl.dispose();
    _amountCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'New Transaction',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surface,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Theme.of(context).dividerColor),
            ),
            child: Icon(Icons.arrow_back_ios_new_rounded, size: 16),
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: FadeTransition(
        opacity: _fadeAnim,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _TypeToggle(
                  value: _type,
                  onChanged: (v) {
                    setState(() {
                      _type = v;
                      if (_type == 'income' && _category == 'Groceries') {
                        _category = 'Salary';
                      }
                    });
                    _scheduleImpactPreview();
                  },
                ),
                const SizedBox(height: 24),
                _AmountCard(type: _type, controller: _amountCtrl),
                const SizedBox(height: 20),
                _FieldLabel('Date and deadline'),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: _PickerTile(
                        icon: Icons.calendar_month_rounded,
                        label: DateFormat('MMM dd, yyyy').format(_date),
                        onTap: () => _pickDate(isDeadline: false),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _PickerTile(
                        icon: Icons.notifications_active_rounded,
                        label: _deadline == null
                            ? 'No deadline'
                            : DateFormat('MMM dd').format(_deadline!),
                        onTap: () => _pickDate(isDeadline: true),
                        onClear: _deadline == null
                            ? null
                            : () {
                                setState(() => _deadline = null);
                                _scheduleImpactPreview();
                              },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),
                _FieldLabel('Description'),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _titleCtrl,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'e.g. Grocery shopping',
                    prefixIcon: Icon(
                      Icons.edit_note_rounded,
                      color:
                          (Theme.of(context).textTheme.bodyMedium?.color ??
                          AppTheme.textSecondaryFor(context)),
                    ),
                  ),
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? 'Enter a description'
                      : null,
                ),
                const SizedBox(height: 20),
                _FieldLabel('Category'),
                const SizedBox(height: 10),
                _CategoryGrid(
                  categories: _categories,
                  selected: _category,
                  onSelect: (c) {
                    setState(() => _category = c);
                    _scheduleImpactPreview();
                  },
                ),
                const SizedBox(height: 18),
                _ImpactPanel(
                  impact: _impact,
                  error: _impactError,
                  type: _type,
                  deadline: _deadline,
                ),
                const SizedBox(height: 20),
                _FieldLabel('Note (optional)'),
                const SizedBox(height: 8),
                TextField(
                  controller: _noteCtrl,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'Add a note...',
                    prefixIcon: Padding(
                      padding: const EdgeInsets.only(bottom: 40),
                      child: Icon(
                        Icons.notes_rounded,
                        color:
                            (Theme.of(context).textTheme.bodyMedium?.color ??
                            AppTheme.textSecondaryFor(context)),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _saving ? null : _submit,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _type == 'income'
                          ? AppTheme.success
                          : AppTheme.primary,
                    ),
                    child: _saving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                _type == 'income'
                                    ? Icons.arrow_downward_rounded
                                    : Icons.arrow_upward_rounded,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Save ${_type == 'income' ? 'Income' : 'Expense'}',
                                style: GoogleFonts.inter(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ],
                          ),
                  ),
                ),
                const SizedBox(height: 40),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate({required bool isDeadline}) async {
    final initial = isDeadline ? (_deadline ?? _date) : _date;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (picked == null) return;
    setState(() {
      if (isDeadline) {
        _deadline = picked;
      } else {
        _date = picked;
      }
    });
    _scheduleImpactPreview();
  }

  void _scheduleImpactPreview() {
    _impactDebounce?.cancel();
    _impactDebounce = Timer(const Duration(milliseconds: 350), _loadImpact);
  }

  Future<void> _loadImpact() async {
    final fs = Provider.of<AuthService>(
      context,
      listen: false,
    ).firestoreService;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (fs == null ||
        amount == null ||
        amount <= 0 ||
        _titleCtrl.text.trim().isEmpty) {
      if (mounted) {
        setState(() {
          _impact = null;
          _impactError = null;
        });
      }
      return;
    }
    try {
      final impact = await fs.previewTransactionImpact(_draft(amount));
      if (mounted) {
        setState(() {
          _impact = impact;
          _impactError = null;
        });
      }
    } on FinanceValidationException catch (error) {
      if (mounted) {
        setState(() => _impactError = error.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _impactError = 'Live finance check is unavailable.');
      }
    }
  }

  FinancialTransaction _draft(double amount) {
    return FinancialTransaction(
      id: '',
      title: _titleCtrl.text.trim(),
      amount: amount,
      date: _date,
      category: _category,
      type: _type,
      note: _noteCtrl.text.trim(),
      deadline: _deadline,
      linkedBudgetCategory: _category,
    );
  }

  Future<void> _submit() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final amount = double.tryParse(_amountCtrl.text.trim());
    if (amount == null || amount <= 0 || !amount.isFinite) {
      _showError('Amount must be greater than zero.');
      return;
    }
    setState(() => _saving = true);

    final fs = Provider.of<AuthService>(
      context,
      listen: false,
    ).firestoreService;
    if (fs != null) {
      final transaction = _draft(amount);
      try {
        await fs.addTransaction(transaction);
      } on SavingsUsageRequiredException catch (error) {
        if (!mounted) return;
        final approved = await _confirmSavingsUse(error.requiredAmount);
        if (approved != true) {
          setState(() => _saving = false);
          return;
        }
        try {
          await fs.addTransaction(transaction, allowSavingsWithdrawal: true);
        } on FinanceValidationException catch (secondError) {
          if (mounted) {
            _showError(secondError.message);
          }
          setState(() => _saving = false);
          return;
        }
      } on FinanceValidationException catch (error) {
        if (mounted) {
          _showError(error.message);
        }
        setState(() => _saving = false);
        return;
      }
    }

    if (mounted) {
      setState(() => _saving = false);
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _deadline == null
                ? 'Transaction saved'
                : 'Transaction saved with reminder',
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      );
    }
  }

  Future<bool?> _confirmSavingsUse(double amount) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Use money from Savings?'),
        content: Text(
          'Total expenses exceed income for this period. Do you want to take ${CurrencyUtils.format(amount)} from Savings?',
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
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppTheme.error),
    );
  }
}

class _Cat {
  final String name;
  final IconData icon;
  final Color color;
  const _Cat(this.name, this.icon, this.color);
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);
  @override
  Widget build(BuildContext context) => Text(
    text,
    style: GoogleFonts.inter(
      fontSize: 13,
      fontWeight: FontWeight.w600,
      color: Theme.of(context).colorScheme.onSurface,
    ),
  );
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.type, required this.controller});

  final String type;
  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: type == 'income'
            ? AppTheme.successGradient
            : AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Amount',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                'PKR',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white.withValues(alpha: 0.7),
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 42,
                    fontWeight: FontWeight.w800,
                  ),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    fillColor: Colors.transparent,
                    filled: false,
                    hintText: '0.00',
                    hintStyle: GoogleFonts.plusJakartaSans(
                      color: Colors.white.withValues(alpha: 0.3),
                      fontSize: 42,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Enter amount';
                    final amount = double.tryParse(v);
                    if (amount == null || !amount.isFinite || amount <= 0) {
                      return 'Amount must be greater than zero';
                    }
                    return null;
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  const _PickerTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.onClear,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.primary, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Theme.of(context).colorScheme.onSurface,
                  fontWeight: FontWeight.w600,
                  fontSize: 13,
                ),
              ),
            ),
            if (onClear != null)
              GestureDetector(
                onTap: onClear,
                child: Icon(
                  Icons.close_rounded,
                  size: 16,
                  color:
                      (Theme.of(context).textTheme.bodyMedium?.color ??
                      AppTheme.textSecondaryFor(context)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ImpactPanel extends StatelessWidget {
  const _ImpactPanel({
    required this.impact,
    required this.error,
    required this.type,
    required this.deadline,
  });

  final TransactionImpactPreview? impact;
  final String? error;
  final String type;
  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    final panelColor = type == 'income'
        ? AppTheme.success.withValues(alpha: 0.08)
        : AppTheme.primary.withValues(alpha: 0.06);
    if (error != null) {
      return _Banner(
        color: AppTheme.error,
        icon: Icons.error_outline_rounded,
        title: 'Live check',
        body: error!,
      );
    }
    if (impact == null) {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: panelColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Text(
          'Add amount and description to see budget, income, savings, and health impact instantly.',
          style: GoogleFonts.inter(
            color:
                (Theme.of(context).textTheme.bodyMedium?.color ??
                AppTheme.textSecondaryFor(context)),
            height: 1.4,
          ),
        ),
      );
    }

    final warnings = impact!.warnings;
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Theme.of(context).dividerColor),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Expanded(
                    child: _MiniMetric(
                      label: 'Income',
                      value: CurrencyUtils.format(impact!.periodIncome),
                      color: AppTheme.success,
                    ),
                  ),
                  Expanded(
                    child: _MiniMetric(
                      label: 'Expenses',
                      value: CurrencyUtils.format(impact!.projectedExpenses),
                      color: AppTheme.error,
                    ),
                  ),
                  Expanded(
                    child: _MiniMetric(
                      label: 'Health',
                      value: '${impact!.healthScore}/100',
                      color: AppTheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _ProgressRow(
                label: 'Budget use',
                value: impact!.budgetUsage.clamp(0.0, 1.0),
                trailing: impact!.periodBudget <= 0
                    ? 'No budget'
                    : '${(impact!.budgetUsage * 100).round()}%',
              ),
              const SizedBox(height: 10),
              _ProgressRow(
                label: 'Income use',
                value: impact!.incomeUsage.clamp(0.0, 1.0),
                trailing: '${(impact!.incomeUsage * 100).round()}%',
              ),
            ],
          ),
        ),
        if (warnings.isNotEmpty) ...[
          const SizedBox(height: 10),
          _Banner(
            color: impact!.needsSavings ? AppTheme.error : AppTheme.warning,
            icon: impact!.needsSavings
                ? Icons.savings_outlined
                : Icons.warning_amber_rounded,
            title: impact!.needsSavings
                ? 'Savings confirmation needed'
                : 'Budget warning',
            body: impact!.needsSavings
                ? 'This may need ${CurrencyUtils.format(impact!.requiredSavings)} from Savings.'
                : warnings.first,
          ),
        ],
        if (deadline != null) ...[
          const SizedBox(height: 10),
          _Banner(
            color: AppTheme.primary,
            icon: Icons.notifications_active_rounded,
            title: 'Reminder linked',
            body:
                'This deadline will appear with the transaction and stay tied to its budget category.',
          ),
        ],
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

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
    );
  }
}

class _ProgressRow extends StatelessWidget {
  const _ProgressRow({
    required this.label,
    required this.value,
    required this.trailing,
  });

  final String label;
  final double value;
  final String trailing;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        SizedBox(
          width: 84,
          child: Text(
            label,
            style: GoogleFonts.inter(
              color:
                  (Theme.of(context).textTheme.bodyMedium?.color ??
                  AppTheme.textSecondaryFor(context)),
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: value,
              minHeight: 8,
              backgroundColor: Theme.of(context).dividerColor,
              color: value >= 0.95
                  ? AppTheme.error
                  : value >= 0.85
                  ? AppTheme.warning
                  : AppTheme.primary,
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          trailing,
          style: GoogleFonts.inter(
            color: Theme.of(context).colorScheme.onSurface,
            fontWeight: FontWeight.w700,
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  const _Banner({
    required this.color,
    required this.icon,
    required this.title,
    required this.body,
  });

  final Color color;
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.plusJakartaSans(
                    color: color,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  body,
                  style: GoogleFonts.inter(
                    color:
                        (Theme.of(context).textTheme.bodyMedium?.color ??
                        AppTheme.textSecondaryFor(context)),
                    height: 1.35,
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

class _TypeToggle extends StatelessWidget {
  final String value;
  final ValueChanged<String> onChanged;
  const _TypeToggle({required this.value, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Theme.of(context).dividerColor),
      ),
      child: Row(
        children: [
          _ToggleBtn(
            label: 'Expense',
            icon: Icons.arrow_upward_rounded,
            selected: value == 'expense',
            color: AppTheme.error,
            onTap: () => onChanged('expense'),
          ),
          _ToggleBtn(
            label: 'Income',
            icon: Icons.arrow_downward_rounded,
            selected: value == 'income',
            color: AppTheme.success,
            onTap: () => onChanged('income'),
          ),
        ],
      ),
    );
  }
}

class _ToggleBtn extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  const _ToggleBtn({
    required this.label,
    required this.icon,
    required this.selected,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: selected ? color : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                color: selected
                    ? Colors.white
                    : (Theme.of(context).textTheme.bodyMedium?.color ??
                          AppTheme.textSecondaryFor(context)),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: selected
                      ? Colors.white
                      : (Theme.of(context).textTheme.bodyMedium?.color ??
                            AppTheme.textSecondaryFor(context)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  final List<_Cat> categories;
  final String selected;
  final ValueChanged<String> onSelect;
  const _CategoryGrid({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: categories
          .map(
            (cat) => GestureDetector(
              onTap: () => onSelect(cat.name),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: selected == cat.name
                      ? cat.color.withValues(alpha: 0.15)
                      : Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: selected == cat.name
                        ? cat.color
                        : Theme.of(context).dividerColor,
                    width: selected == cat.name ? 2 : 1,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      cat.icon,
                      color: selected == cat.name
                          ? cat.color
                          : (Theme.of(context).textTheme.bodyMedium?.color ??
                                AppTheme.textSecondaryFor(context)),
                      size: 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      cat.name,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: selected == cat.name
                            ? cat.color
                            : (Theme.of(context).textTheme.bodyMedium?.color ??
                                  AppTheme.textSecondaryFor(context)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          )
          .toList(),
    );
  }
}
