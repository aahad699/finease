import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../models/budget_plan.dart';
import '../../models/saving_goal.dart';
import '../../models/transaction.dart';
import '../../services/ai_service.dart';
import '../../services/financial_coach_service.dart';
import '../../theme/app_theme.dart';

class CoachChatScreen extends StatefulWidget {
  const CoachChatScreen({
    super.key,
    required this.transactions,
    required this.budgets,
    required this.monthlyIncome,
  });

  final List<FinancialTransaction> transactions;
  final Map<String, double> budgets;
  final double monthlyIncome;

  @override
  State<CoachChatScreen> createState() => _CoachChatScreenState();
}

class _CoachChatScreenState extends State<CoachChatScreen> {
  static const _primary = Color(0xFF2E3192);
  final _coachService = FinancialCoachService();
  final _aiService = AIService();
  final _scrollController = ScrollController();
  final _inputController = TextEditingController();
  final List<_ChatMessage> _messages = [
    _ChatMessage(
      text:
          'Hello! I am your AI Finance Coach. I use your real budgets, transactions, and savings context for personalized guidance.',
      isBot: true,
    ),
  ];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final tips = _coachService.getInstantTips(
      transactions: widget.transactions,
      budgets: widget.budgets,
      monthlyIncome: widget.monthlyIncome,
    );
    if (tips.isNotEmpty) {
      _messages.add(
        _ChatMessage(
          text: tips
              .take(2)
              .map((tip) => '${tip.icon} ${tip.message}')
              .join('\n\n'),
          isBot: true,
        ),
      );
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _inputController.dispose();
    super.dispose();
  }

  Future<void> _sendMessage() async {
    final userMessage = _inputController.text.trim();
    if (userMessage.isEmpty || _isLoading) return;

    _inputController.clear();
    setState(() {
      _isLoading = true;
      _messages.add(_ChatMessage(text: userMessage, isBot: false));
    });
    _scrollToBottom();

    try {
      final budgets = widget.budgets.entries
          .map(
            (entry) => BudgetPlan(
              id: '',
              title: entry.key,
              category: entry.key,
              allocatedAmount: entry.value,
              notes: '',
              monthKey: '',
              createdAt: DateTime.now(),
            ),
          )
          .toList();
      final response = await _aiService.personalizedCoachAnswer(
        question: userMessage,
        transactions: widget.transactions,
        budgets: budgets,
        goals: const <SavingGoal>[],
      );
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messages.add(_ChatMessage(text: response, isBot: true));
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _messages.add(
          _ChatMessage(
            text: 'AI Finance Coach is not running yet: $error',
            isBot: true,
          ),
        );
      });
    }
    _scrollToBottom();
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.backgroundFor(context),
      appBar: AppBar(
        title: Text(
          'AI Finance Coach',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
        backgroundColor: _primary,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              controller: _scrollController,
              padding: const EdgeInsets.all(16),
              itemCount: _messages.length + (_isLoading ? 1 : 0),
              itemBuilder: (context, index) {
                if (index == _messages.length) {
                  return const _TypingBubble();
                }
                return _ChatBubble(message: _messages[index]);
              },
            ),
          ),
          _InputArea(controller: _inputController, onSend: _sendMessage),
        ],
      ),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  const _ChatBubble({required this.message});

  final _ChatMessage message;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: message.isBot ? Alignment.centerLeft : Alignment.centerRight,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: message.isBot
              ? AppTheme.surfaceFor(context)
              : _CoachChatScreenState._primary,
          border: message.isBot
              ? Border.all(color: AppTheme.borderFor(context))
              : null,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Text(
          message.text,
          style: GoogleFonts.inter(
            color: message.isBot
                ? AppTheme.textPrimaryFor(context)
                : Colors.white,
            fontSize: 14,
            height: 1.4,
          ),
        ),
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return const Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: EdgeInsets.only(bottom: 12),
        child: CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}

class _InputArea extends StatelessWidget {
  const _InputArea({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        border: Border(top: BorderSide(color: AppTheme.borderFor(context))),
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: controller,
              decoration: InputDecoration(
                hintText: 'Ask about your budget, savings, or spending...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(24),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              onSubmitted: (_) => onSend(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton.filled(
            onPressed: onSend,
            icon: Icon(Icons.send_rounded),
            style: IconButton.styleFrom(
              backgroundColor: _CoachChatScreenState._primary,
            ),
          ),
        ],
      ),
    );
  }
}

class _ChatMessage {
  const _ChatMessage({required this.text, required this.isBot});

  final String text;
  final bool isBot;
}
