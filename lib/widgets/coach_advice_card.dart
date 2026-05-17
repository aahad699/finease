import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../models/transaction.dart';
import '../../services/financial_coach_service.dart';
import '../pages/coach/coach_chat_screen.dart';

/// Home-screen card that shows the latest coach tip and instant alerts.
/// Tapping "Chat with Coach" opens [CoachChatScreen].
class CoachAdviceCard extends StatefulWidget {
  final List<FinancialTransaction> transactions;
  final Map<String, double> budgets;
  final double monthlyIncome;

  const CoachAdviceCard({
    super.key,
    required this.transactions,
    this.budgets = const {},
    this.monthlyIncome = 0,
  });

  @override
  State<CoachAdviceCard> createState() => _CoachAdviceCardState();
}

class _CoachAdviceCardState extends State<CoachAdviceCard> {
  static const _primary = Color(0xFF2E3192);

  late final FinancialCoachService _svc;
  List<InstantTip> _tips = [];
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _svc = FinancialCoachService();
    _tips = _svc.getInstantTips(
      transactions: widget.transactions,
      budgets: widget.budgets,
      monthlyIncome: widget.monthlyIncome,
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasWarnings = _tips.any((t) => t.isWarning);

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF2E3192), Color(0xFF4B5BD6)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: _primary.withValues(alpha: 0.28),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // ── Header ────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 12),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(Icons.auto_awesome_rounded,
                      color: Colors.white, size: 22),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Financial Coach',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        hasWarnings
                            ? '${_tips.where((t) => t.isWarning).length} alert${_tips.where((t) => t.isWarning).length > 1 ? 's' : ''} detected'
                            : 'Your finances look healthy ✓',
                        style: GoogleFonts.inter(
                          color: Colors.white.withValues(alpha: 0.75),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                if (hasWarnings)
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.20),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                          color:
                              const Color(0xFFDC2626).withValues(alpha: 0.40)),
                    ),
                    child: Text(
                      '⚠️ Alert',
                      style: GoogleFonts.inter(
                        color: const Color(0xFFFFB4B4),
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // ── Tips ──────────────────────────────────────────────────
          if (_tips.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 0, 18, 4),
              child: Column(
                children: [
                  _buildTipRow(_tips.first),
                  if (_expanded && _tips.length > 1)
                    ...(_tips.skip(1).map(_buildTipRow)),
                  if (_tips.length > 1)
                    GestureDetector(
                      onTap: () =>
                          setState(() => _expanded = !_expanded),
                      child: Padding(
                        padding: const EdgeInsets.only(top: 6, bottom: 4),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              _expanded
                                  ? 'Show less'
                                  : 'Show ${_tips.length - 1} more tip${_tips.length > 2 ? 's' : ''}',
                              style: GoogleFonts.inter(
                                color:
                                    Colors.white.withValues(alpha: 0.65),
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(width: 4),
                            Icon(
                              _expanded
                                  ? Icons.keyboard_arrow_up_rounded
                                  : Icons.keyboard_arrow_down_rounded,
                              color: Colors.white.withValues(alpha: 0.65),
                              size: 16,
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // ── CTA ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 6, 18, 18),
            child: GestureDetector(
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => CoachChatScreen(
                    transactions: widget.transactions,
                    budgets: widget.budgets,
                    monthlyIncome: widget.monthlyIncome,
                  ),
                ),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 13),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.10),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.chat_bubble_outline_rounded,
                        color: _primary, size: 18),
                    const SizedBox(width: 8),
                    Text(
                      'Chat with Coach',
                      style: GoogleFonts.plusJakartaSans(
                        color: _primary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTipRow(InstantTip tip) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: tip.isWarning
              ? const Color(0xFFDC2626).withValues(alpha: 0.12)
              : Colors.white.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: tip.isWarning
                ? const Color(0xFFDC2626).withValues(alpha: 0.30)
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(tip.icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                tip.message,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.92),
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
