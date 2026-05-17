import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../theme/app_theme.dart';

class RewardsScreen extends StatelessWidget {
  const RewardsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final userId = FirebaseAuth.instance.currentUser?.uid ?? '';
    return Scaffold(
      backgroundColor: AppTheme.backgroundFor(context),
      body: StreamBuilder<DocumentSnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots(),
        builder: (context, snapshot) {
          final userData = snapshot.data?.data() as Map<String, dynamic>? ?? {};
          final points = userData['points'] ?? 0;
          final level = userData['level'] ?? 1;
          final nextLevelPoints = 2000;
          final progress = (points / nextLevelPoints).clamp(0.0, 1.0);

          return CustomScrollView(
            slivers: [
              SliverAppBar(
                expandedHeight: 220,
                floating: false,
                pinned: true,
                backgroundColor: AppTheme.primary,
                automaticallyImplyLeading: true,
                flexibleSpace: FlexibleSpaceBar(
                  background: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.primary, AppTheme.secondary],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'FinEdge',
                              style: TextStyle(
                                color: Colors.white70,
                                fontSize: 14,
                                fontFamily: 'Inter',
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Rewards & Gamification',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                fontFamily: 'Plus Jakarta Sans',
                              ),
                            ),
                            const SizedBox(height: 20),
                            // Current Balance Card
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withValues(alpha: 0.2),
                                ),
                              ),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Current Balance',
                                        style: TextStyle(
                                          color: Colors.white70,
                                          fontSize: 12,
                                          fontFamily: 'Inter',
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$points pts',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          fontFamily: 'Plus Jakarta Sans',
                                        ),
                                      ),
                                    ],
                                  ),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF00F2EA,
                                      ).withValues(alpha: 0.25),
                                      borderRadius: BorderRadius.circular(20),
                                    ),
                                    child: Text(
                                      'Level $level',
                                      style: TextStyle(
                                        color: Color(0xFF00F2EA),
                                        fontWeight: FontWeight.bold,
                                        fontFamily: 'Inter',
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 20, 16, 100),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Active Challenges
                      Text(
                        'Active Challenges',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryFor(context),
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                      ),
                      const SizedBox(height: 12),
                      _challengeCard(
                        context,
                        'Complete a lesson',
                        "Read 'The Art of Compound Interest'",
                        Icons.menu_book_rounded,
                        150,
                        0.3,
                      ),
                      _challengeCard(
                        context,
                        'Weekly Saver',
                        'Deposit at least 3000 PKR to your vault',
                        Icons.savings_rounded,
                        200,
                        0.6,
                      ),
                      _challengeCard(
                        context,
                        'Daily Login',
                        'Come back tomorrow for your streak',
                        Icons.local_fire_department_rounded,
                        50,
                        1.0,
                      ),
                      const SizedBox(height: 28),
                      // Milestones
                      Text(
                        'Milestones',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryFor(context),
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                      ),
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceFor(context),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppTheme.borderFor(context)),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Gold Tier Progress',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: AppTheme.textPrimaryFor(context),
                                    fontFamily: 'Plus Jakarta Sans',
                                  ),
                                ),
                                Text(
                                  '$points / $nextLevelPoints',
                                  style: TextStyle(
                                    color: Color(0xFF777683),
                                    fontSize: 13,
                                    fontFamily: 'Inter',
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: LinearProgressIndicator(
                                value: progress,
                                backgroundColor: const Color(0xFFE5EEFF),
                                color: const Color(0xFF00F2EA),
                                minHeight: 10,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              '"Consistency is the key to financial freedom."',
                              style: TextStyle(
                                color: Color(0xFF777683),
                                fontSize: 13,
                                fontStyle: FontStyle.italic,
                                fontFamily: 'Inter',
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 28),
                      // Digital milestones
                      Text(
                        'Digital Milestones',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: AppTheme.textPrimaryFor(context),
                          fontFamily: 'Plus Jakarta Sans',
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Points stay inside FinEase for engagement, learning, and streaks. They are not redeemable for gift cards, cash, or external perks.',
                        style: TextStyle(
                          color: Color(0xFF777683),
                          fontSize: 13,
                          fontFamily: 'Inter',
                        ),
                      ),
                      const SizedBox(height: 16),
                      _perkCard(
                        context,
                        userId,
                        'Budget Builder',
                        'Create your first complete monthly budget',
                        500,
                        Icons.account_balance_wallet_rounded,
                        const Color(0xFF2E3192),
                      ),
                      _perkCard(
                        context,
                        userId,
                        'Savings Streak',
                        'Contribute to your savings goals consistently',
                        800,
                        Icons.savings_rounded,
                        const Color(0xFF006A66),
                      ),
                      _perkCard(
                        context,
                        userId,
                        'Forum Helper',
                        'Support other users with helpful replies',
                        300,
                        Icons.forum_rounded,
                        const Color(0xFFBA1A1A),
                      ),
                      _perkCard(
                        context,
                        userId,
                        'Learning Champion',
                        'Finish literacy courses and quizzes',
                        1200,
                        Icons.workspace_premium_rounded,
                        const Color(0xFF4F54B4),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _challengeCard(
    BuildContext context,
    String title,
    String subtitle,
    IconData icon,
    int reward,
    double progress,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderFor(context)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFE5EEFF),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: const Color(0xFF2E3192), size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: AppTheme.textPrimaryFor(context),
                        fontFamily: 'Plus Jakarta Sans',
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: TextStyle(
                        color: Color(0xFF777683),
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 5,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xFFF0FDF4),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '+$reward pts',
                  style: TextStyle(
                    color: Color(0xFF006A66),
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: progress,
              backgroundColor: const Color(0xFFE5EEFF),
              color: progress == 1.0
                  ? const Color(0xFF00F2EA)
                  : const Color(0xFF4F54B4),
              minHeight: 6,
            ),
          ),
        ],
      ),
    );
  }

  Widget _perkCard(
    BuildContext context,
    String userId,
    String title,
    String desc,
    int cost,
    IconData icon,
    Color color,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.borderFor(context)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppTheme.textPrimaryFor(context),
                    fontFamily: 'Plus Jakarta Sans',
                  ),
                ),
                Text(
                  desc,
                  style: TextStyle(
                    color: Color(0xFF777683),
                    fontSize: 12,
                    fontFamily: 'Inter',
                  ),
                ),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF2E3192),
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            ),
            onPressed: () async {
              try {
                await FirebaseFirestore.instance.runTransaction((tx) async {
                  final ref = FirebaseFirestore.instance
                      .collection('users')
                      .doc(userId);
                  final snap = await tx.get(ref);
                  final pts = snap['points'] ?? 0;
                  if (pts >= cost) {
                    tx.update(ref, {'points': pts - cost});
                  } else {
                    throw Exception('Not enough points');
                  }
                });
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    backgroundColor: Color(0xFF006A66),
                    content: Text('Milestone acknowledged in-app.'),
                  ),
                );
              } catch (e) {
                // ignore: use_build_context_synchronously
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    backgroundColor: const Color(0xFFBA1A1A),
                    content: Text(e.toString()),
                  ),
                );
              }
            },
            child: Text(
              '$cost pts',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 12,
                fontFamily: 'Inter',
              ),
            ),
          ),
        ],
      ),
    );
  }
}
