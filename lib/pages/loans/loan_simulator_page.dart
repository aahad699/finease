import 'dart:math';

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../services/ai_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/currency_utils.dart';

class LoanSimulatorPage extends StatefulWidget {
  const LoanSimulatorPage({super.key, this.embedded = false});

  final bool embedded;

  @override
  State<LoanSimulatorPage> createState() => _LoanSimulatorPageState();
}

class _LoanSimulatorPageState extends State<LoanSimulatorPage> {
  double _amount = 1500000;
  double _rate = 16.5;
  double _tenure = 36;
  String? _aiInsight;
  bool _aiLoading = false;
  final AIService _aiService = AIService();

  double get _emi {
    if (_tenure <= 0) return 0;
    final r = (_rate / 12) / 100;
    if (r == 0) {
      return _amount / _tenure;
    }
    return (_amount * r * pow(1 + r, _tenure)) / (pow(1 + r, _tenure) - 1);
  }

  double get _totalInterest =>
      _tenure <= 0 ? 0 : ((_emi * _tenure) - _amount).clamp(0, double.infinity);
  double get _totalPayment => _tenure <= 0 ? _amount : _emi * _tenure;
  double get _recommendedIncome => _emi <= 0 ? 0 : _emi / 0.3;
  double get _loanToCostRatio => _amount <= 0 ? 0 : _totalPayment / _amount;

  Future<void> _getAIInsight() async {
    setState(() {
      _aiLoading = true;
      _aiInsight = null;
    });
    try {
      final prompt ='''Analyze this loan for a user in Pakistan: Amount ${CurrencyUtils.exact(_amount)}, markup ${_rate.toStringAsFixed(1)}% annually, tenure ${_tenure.toInt()} months. EMI: ${CurrencyUtils.exact(_emi)}/month, Total interest: ${CurrencyUtils.exact(_totalInterest)}. Give 3 concise bullet points in PKR.''';
      final response = await _aiService.generalFinancialAnswer(prompt);
      setState(() {
        _aiInsight = response;
        _aiLoading = false;
      });
    } catch (error) {
      setState(() {
        _aiInsight = 'AI is not running yet: $error';
        _aiLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundFor(context),
      appBar: AppBar(
        backgroundColor: AppTheme.backgroundFor(context),
        automaticallyImplyLeading: !widget.embedded,
        leading: widget.embedded
            ? null
            : IconButton(
                icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
                color: Colors.white,
                onPressed: () => Navigator.pop(context),
              ),
        title: Text(
          'Loan Simulator',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                gradient: AppTheme.cyanGradient,
                borderRadius: BorderRadius.circular(24),
                boxShadow: AppTheme.cardShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Monthly EMI',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.75),
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    CurrencyUtils.exact(_emi),
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 36,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  Text(
                    '/month',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.6),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _statPill('Principal', CurrencyUtils.exact(_amount)),
                      const SizedBox(width: 12),
                      _statPill(
                        'Interest',
                        CurrencyUtils.exact(_totalInterest),
                      ),
                      const SizedBox(width: 12),
                      _statPill('Total', CurrencyUtils.exact(_totalPayment)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            _SimCard(
              child: Row(
                children: [
                  Expanded(
                    child: _miniMetric(
                      'Suggested income',
                      CurrencyUtils.exact(_recommendedIncome),
                      AppTheme.success,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _miniMetric(
                      'Total cost ratio',
                      '${_loanToCostRatio.toStringAsFixed(2)}x',
                      AppTheme.warning,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SimCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Adjust Parameters',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryFor(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  _Slider(
                    label: 'Loan Amount',
                    value: _amount,
                    min: 0,
                    max: 5000000,
                    display: CurrencyUtils.exact(_amount),
                    onChanged: (value) => setState(() => _amount = value),
                  ),
                  const SizedBox(height: 16),
                  _Slider(
                    label: 'Markup Rate',
                    value: _rate,
                    min: 0,
                    max: 30,
                    display: '${_rate.toStringAsFixed(1)}%',
                    onChanged: (value) => setState(() => _rate = value),
                  ),
                  const SizedBox(height: 16),
                  _Slider(
                    label: 'Tenure',
                    value: _tenure,
                    min: 0,
                    max: 120,
                    display: '${_tenure.toInt()} mo',
                    onChanged: (value) => setState(() => _tenure = value),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _SimCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Amortization Breakdown',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryFor(context),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Principal vs interest through the repayment timeline',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      color: AppTheme.textSecondaryFor(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 160,
                    child: BarChart(
                      BarChartData(
                        alignment: BarChartAlignment.spaceAround,
                        maxY: _totalPayment <= 0 ? 1 : _totalPayment,
                        barTouchData: BarTouchData(enabled: false),
                        titlesData: FlTitlesData(
                          show: true,
                          bottomTitles: AxisTitles(
                            sideTitles: SideTitles(
                              showTitles: true,
                              reservedSize: 24,
                              getTitlesWidget: (value, meta) {
                                final labels = ['Start', 'Q1', 'Mid', 'End'];
                                if (value.toInt() < labels.length) {
                                  return SideTitleWidget(
                                    meta: meta,
                                    child: Text(
                                      labels[value.toInt()],
                                      style: GoogleFonts.inter(
                                        fontSize: 10,
                                        color: AppTheme.textSecondaryFor(context),
                                      ),
                                    ),
                                  );
                                }
                                return const SizedBox();
                              },
                            ),
                          ),
                          leftTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          topTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                          rightTitles: AxisTitles(
                            sideTitles: SideTitles(showTitles: false),
                          ),
                        ),
                        gridData: FlGridData(show: false),
                        borderData: FlBorderData(show: false),
                        barGroups: [
                          _bar(0, _amount * 0.95, _totalInterest * 0.05),
                          _bar(1, _amount * 0.65, _totalInterest * 0.35),
                          _bar(2, _amount * 0.35, _totalInterest * 0.65),
                          _bar(3, _amount * 0.05, _totalInterest * 0.95),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      _legend(AppTheme.primary, 'Principal'),
                      const SizedBox(width: 16),
                      _legend(AppTheme.secondary, 'Interest'),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _aiLoading ? null : _getAIInsight,
                icon: _aiLoading
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          color: Colors.white,
                          strokeWidth: 2,
                        ),
                      )
                    : Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(
                  _aiLoading ? 'Analyzing...' : 'Get AI Analysis',
                  style: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
            ),
            if (_aiInsight != null) ...[
              const SizedBox(height: 16),
              _SimCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.auto_awesome_rounded,
                          color: AppTheme.primary,
                          size: 18,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'AI Analysis',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.primary,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _aiInsight!,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        color: AppTheme.textPrimaryFor(context),
                        height: 1.7,
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _SimCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Repayment Overview',
                    style: GoogleFonts.plusJakartaSans(
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      color: AppTheme.textPrimaryFor(context),
                    ),
                  ),
                  const SizedBox(height: 16),
                  _row(
                    context,
                    'Loan Amount',
                    CurrencyUtils.exact(_amount),
                    first: true,
                  ),
                  _row(context, 'Monthly EMI', CurrencyUtils.exact(_emi)),
                  _row(
                    context,
                    'Total Interest',
                    CurrencyUtils.exact(_totalInterest),
                  ),
                  _row(
                    context,
                    'Total Payment',
                    CurrencyUtils.exact(_totalPayment),
                    highlight: true,
                  ),
                  _row(
                    context,
                    'Suggested Monthly Income',
                    CurrencyUtils.exact(_recommendedIncome),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _statPill(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 10,
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  BarChartGroupData _bar(int x, double principal, double interest) {
    return BarChartGroupData(
      x: x,
      barRods: [
        BarChartRodData(
          toY: principal + interest,
          width: 22,
          borderRadius: BorderRadius.circular(6),
          rodStackItems: [
            BarChartRodStackItem(0, principal, AppTheme.primary),
            BarChartRodStackItem(
              principal,
              principal + interest,
              AppTheme.secondary,
            ),
          ],
        ),
      ],
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: GoogleFonts.inter(fontSize: 12, color: AppTheme.textSecondaryFor(context)),
        ),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    String label,
    String value, {
    bool first = false,
    bool highlight = false,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
      decoration: BoxDecoration(
        border: first ? null : Border(top: BorderSide(color: AppTheme.borderFor(context))),
        color: highlight ? AppTheme.primary.withValues(alpha: 0.06) : null,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              fontSize: 13,
              color: AppTheme.textSecondaryFor(context),
              fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
          Text(
            value,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 14,
              fontWeight: FontWeight.w700,
              color: highlight ? AppTheme.primary : AppTheme.textPrimaryFor(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniMetric(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondaryFor(context),
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
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

class _SimCard extends StatelessWidget {
  const _SimCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.borderFor(context)),
        boxShadow: AppTheme.softShadow,
      ),
      child: child,
    );
  }
}

class _Slider extends StatelessWidget {
  const _Slider({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.display,
    required this.onChanged,
  });

  final String label;
  final double value;
  final double min;
  final double max;
  final String display;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: AppTheme.textSecondaryFor(context),
              ),
            ),
            Text(
              display,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppTheme.primary,
              ),
            ),
          ],
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(
            activeTrackColor: AppTheme.primary,
            inactiveTrackColor: AppTheme.borderFor(context),
            thumbColor: Colors.white,
            thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 10),
            overlayColor: AppTheme.primary.withValues(alpha: 0.1),
            trackHeight: 5,
          ),
          child: Slider(value: value, min: min, max: max, onChanged: onChanged),
        ),
      ],
    );
  }
}
