import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/app_theme.dart';

class NotificationsPage extends StatelessWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final notifications = [
      _NotifData(
        'Budget Alert',
        'You\'ve used 80% of your Food budget this month.',
        Icons.warning_amber_rounded,
        AppTheme.warning,
        '5m ago',
      ),
      _NotifData(
        'AI Insight Ready',
        'Your weekly financial report is ready to view.',
        Icons.auto_awesome_rounded,
        AppTheme.primary,
        '1h ago',
      ),
      _NotifData(
        'Savings Goal',
        'You\'re 75% toward your Emergency Fund goal! 🎉',
        Icons.savings_rounded,
        AppTheme.success,
        '3h ago',
      ),
      _NotifData(
        'Loan Reminder',
        'Your loan EMI of PKR 124,500 is due in 3 days.',
        Icons.account_balance_rounded,
        AppTheme.error,
        '1d ago',
      ),
      _NotifData(
        'New Welfare Program',
        'A new welfare program matching your profile is available.',
        Icons.volunteer_activism_rounded,
        const Color(0xFFFF6B35),
        '2d ago',
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.backgroundFor(context),
      appBar: AppBar(
        title: Text(
          'Notifications',
          style: GoogleFonts.plusJakartaSans(
            fontWeight: FontWeight.w700,
            fontSize: 18,
          ),
        ),
        backgroundColor: AppTheme.backgroundFor(context),
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios_new_rounded, size: 18),
          color: Colors.white,
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          TextButton(
            onPressed: () {},
            child: Text(
              'Mark all read',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: AppTheme.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
      body: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: notifications.length,
        separatorBuilder: (context, index) => const SizedBox(height: 10),
        itemBuilder: (ctx, i) => _NotifCard(data: notifications[i]),
      ),
    );
  }
}

class _NotifData {
  final String title;
  final String message;
  final IconData icon;
  final Color color;
  final String time;
  const _NotifData(this.title, this.message, this.icon, this.color, this.time);
}

class _NotifCard extends StatelessWidget {
  final _NotifData data;
  const _NotifCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderFor(context)),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: data.color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: data.color, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      data.title,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimaryFor(context),
                      ),
                    ),
                    Text(
                      data.time,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textSecondaryFor(context),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  data.message,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    color: AppTheme.textSecondaryFor(context),
                    height: 1.4,
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
