import 'dart:async';
import 'dart:math' as math;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:youtube_player_iframe/youtube_player_iframe.dart';

import '../../data/demo_finance_data.dart';
import '../../models/lesson.dart';
import '../../services/auth_service.dart';
import '../../services/firestore_service.dart';
import '../../theme/app_theme.dart';

class LiteracyHubPage extends StatelessWidget {
  const LiteracyHubPage({super.key});

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.select<AuthService, FirestoreService?>(
      (auth) => auth.firestoreService,
    );

    if (firestoreService == null) {
      return _LiteracyExperience(
        progressByCourse: const {},
        quizScores: const {},
        userProfile: const {},
        firestoreService: null,
      );
    }

    return StreamBuilder<Map<String, Map<String, dynamic>>>(
      stream: firestoreService.getAllCourseProgress(),
      initialData: const {},
      builder: (context, progressSnapshot) {
        return StreamBuilder<Map<String, Map<String, dynamic>>>(
          stream: firestoreService.getAllQuizScores(),
          initialData: const {},
          builder: (context, quizSnapshot) {
            return StreamBuilder<Map<String, dynamic>>(
              stream: firestoreService.getUserProfile(),
              initialData: const {},
              builder: (context, profileSnapshot) {
                return _LiteracyExperience(
                  progressByCourse: progressSnapshot.data ?? const {},
                  quizScores: quizSnapshot.data ?? const {},
                  userProfile: profileSnapshot.data ?? const {},
                  firestoreService: firestoreService,
                );
              },
            );
          },
        );
      },
    );
  }
}

class _LiteracyExperience extends StatefulWidget {
  const _LiteracyExperience({
    required this.progressByCourse,
    required this.quizScores,
    required this.userProfile,
    required this.firestoreService,
  });

  final Map<String, Map<String, dynamic>> progressByCourse;
  final Map<String, Map<String, dynamic>> quizScores;
  final Map<String, dynamic> userProfile;
  final FirestoreService? firestoreService;

  @override
  State<_LiteracyExperience> createState() => _LiteracyExperienceState();
}

class _LiteracyExperienceState extends State<_LiteracyExperience> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _selectedTrackId = 'all';
  String _selectedDifficulty = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final plan = _LearningPlan(
      courses: DemoFinanceData.courses,
      progressByCourse: widget.progressByCourse,
      quizScores: widget.quizScores,
      userProfile: widget.userProfile,
    );
    final nextAction = plan.nextAction;
    final filteredCourses = plan.filteredCourses(
      query: _query,
      trackId: _selectedTrackId,
      difficulty: _selectedDifficulty,
    );

    return Scaffold(
      backgroundColor: AppTheme.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          SliverAppBar(
            expandedHeight: 240,
            pinned: true,
            backgroundColor: AppTheme.primary,
            title: Text(
              'Literacy Hub',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontWeight: FontWeight.w800,
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(background: _HubHero(plan: plan)),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(18, 22, 18, 120),
            sliver: SliverToBoxAdapter(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 840;
                  final overview = _ProgressOverviewCard(plan: plan);
                  final continueCard = _ContinueLearningCard(
                    action: nextAction,
                    plan: plan,
                    firestoreService: widget.firestoreService,
                  );

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (isWide)
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(flex: 6, child: overview),
                            const SizedBox(width: 16),
                            Expanded(flex: 5, child: continueCard),
                          ],
                        )
                      else ...[
                        overview,
                        const SizedBox(height: 16),
                        continueCard,
                      ],
                      const SizedBox(height: 22),
                      _ForYouRoadmapSection(plan: plan),
                      const SizedBox(height: 22),
                      _LearningPathGrid(
                        plan: plan,
                        selectedTrackId: _selectedTrackId,
                        onTrackSelected: (trackId) {
                          setState(() => _selectedTrackId = trackId);
                        },
                      ),
                      const SizedBox(height: 22),
                      _SkillTreeSection(plan: plan),
                      const SizedBox(height: 22),
                      _AchievementGallery(plan: plan),
                      const SizedBox(height: 22),
                      _CategoryRail(plan: plan),
                      const SizedBox(height: 26),
                      _SectionHeader(
                        title: 'Library',
                        subtitle:
                            'Search the full FinEase curriculum by track, topic, skill, or real-life money situation.',
                      ),
                      const SizedBox(height: 16),
                      _LearningLibraryControls(
                        controller: _searchController,
                        query: _query,
                        selectedTrackId: _selectedTrackId,
                        selectedDifficulty: _selectedDifficulty,
                        onQueryChanged: (value) {
                          setState(() => _query = value);
                        },
                        onTrackChanged: (value) {
                          setState(() => _selectedTrackId = value);
                        },
                        onDifficultyChanged: (value) {
                          setState(() => _selectedDifficulty = value);
                        },
                      ),
                      const SizedBox(height: 16),
                      if (filteredCourses.isEmpty)
                        const _EmptyLibraryState()
                      else
                        ...filteredCourses.asMap().entries.map(
                          (entry) => Padding(
                            padding: const EdgeInsets.only(bottom: 18),
                            child: _CourseJourneyCard(
                              index: entry.key,
                              course: entry.value,
                              plan: plan,
                              isRecommended:
                                  nextAction?.course.id == entry.value.id,
                              firestoreService: widget.firestoreService,
                            ),
                          ),
                        ),
                      const SizedBox(height: 6),
                      const _CommunityLearningCard(),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _HubHero extends StatelessWidget {
  const _HubHero({required this.plan});

  final _LearningPlan plan;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF15157D), Color(0xFF2E3192), Color(0xFF0EA5A4)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 28, 22, 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.16),
                  ),
                ),
                child: Text(
                  'Adaptive fintech learning',
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.86),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Financial Literacy Hub',
                style: GoogleFonts.plusJakartaSans(
                  color: Colors.white,
                  fontSize: 30,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Continue the smartest next lesson, track real progress, and turn money basics into daily momentum.',
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.78),
                  fontSize: 14,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HeroMetric(
                    icon: Icons.bolt_rounded,
                    label: '${plan.earnedXp} XP',
                    value: 'Level ${plan.level}',
                  ),
                  _HeroMetric(
                    icon: Icons.local_fire_department_rounded,
                    label: plan.streakLabel,
                    value: 'Streak',
                  ),
                  _HeroMetric(
                    icon: Icons.route_rounded,
                    label: '${plan.completedLessons}/${plan.totalLessons}',
                    value: 'Lessons',
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroMetric extends StatelessWidget {
  const _HeroMetric({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: const Color(0xFF1BFFFF)),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: GoogleFonts.inter(
                  color: Colors.white.withValues(alpha: 0.62),
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ProgressOverviewCard extends StatelessWidget {
  const _ProgressOverviewCard({required this.plan});

  final _LearningPlan plan;

  @override
  Widget build(BuildContext context) {
    final progressPercent = (plan.overallProgress * 100).round();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBadge(icon: Icons.insights_rounded, color: AppTheme.primary),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Your learning portfolio',
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 18,
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Progress, XP, streak awareness, and quiz momentum.',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              _LevelBadge(level: plan.level, label: plan.levelLabel),
            ],
          ),
          const SizedBox(height: 18),
          _LevelProgressBar(plan: plan),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _OverviewStat(
                  label: 'Complete',
                  value: '$progressPercent%',
                  icon: Icons.pie_chart_rounded,
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewStat(
                  label: 'Earned XP',
                  value: '${plan.earnedXp}',
                  icon: Icons.bolt_rounded,
                  color: const Color(0xFFD97706),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _OverviewStat(
                  label: 'Lessons',
                  value: '${plan.completedLessons}/${plan.totalLessons}',
                  icon: Icons.menu_book_rounded,
                  color: const Color(0xFF0EA5A4),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _OverviewStat(
                  label: 'Quiz wins',
                  value: '${plan.completedQuizzes}/${plan.totalQuizzes}',
                  icon: Icons.emoji_events_rounded,
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _AchievementPrompt(plan: plan),
        ],
      ),
    );
  }
}

class _LevelProgressBar extends StatelessWidget {
  const _LevelProgressBar({required this.plan});

  final _LearningPlan plan;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Level ${plan.level} progression',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w800,
                color: AppTheme.textPrimary,
              ),
            ),
            const Spacer(),
            Text(
              '${plan.levelXp} / ${plan.xpPerLevel} XP',
              style: GoogleFonts.inter(
                fontWeight: FontWeight.w700,
                color: AppTheme.textSecondary,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: plan.levelProgress,
            minHeight: 10,
            backgroundColor: const Color(0xFFE8EDF7),
            color: AppTheme.primary,
          ),
        ),
      ],
    );
  }
}

class _OverviewStat extends StatelessWidget {
  const _OverviewStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 19),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _AchievementPrompt extends StatelessWidget {
  const _AchievementPrompt({required this.plan});

  final _LearningPlan plan;

  @override
  Widget build(BuildContext context) {
    final prompt = plan.achievementPrompt;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF131525),
            const Color(0xFF2E3192).withValues(alpha: 0.94),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.auto_awesome_rounded,
              color: Color(0xFF1BFFFF),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  prompt.title,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  prompt.subtitle,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.72),
                    height: 1.35,
                    fontSize: 12,
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

class _ContinueLearningCard extends StatelessWidget {
  const _ContinueLearningCard({
    required this.action,
    required this.plan,
    required this.firestoreService,
  });

  final _NextLearningAction? action;
  final _LearningPlan plan;
  final FirestoreService? firestoreService;

  @override
  Widget build(BuildContext context) {
    final currentAction = action;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primary.withValues(alpha: 0.16),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: const Color(0xFF1BFFFF).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(
                  currentAction?.isQuiz == true
                      ? Icons.quiz_rounded
                      : Icons.play_arrow_rounded,
                  color: const Color(0xFF1BFFFF),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Continue learning',
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              _StreakPill(label: plan.streakLabel),
            ],
          ),
          const SizedBox(height: 18),
          if (currentAction == null) ...[
            Text(
              'All learning paths are complete.',
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Retake a quiz or join the community to keep the habit alive.',
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.72),
                height: 1.45,
              ),
            ),
          ] else ...[
            Text(
              currentAction.eyebrow,
              style: GoogleFonts.inter(
                color: const Color(0xFF1BFFFF),
                fontSize: 12,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currentAction.title,
              style: GoogleFonts.plusJakartaSans(
                color: Colors.white,
                fontSize: 22,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              currentAction.reason,
              style: GoogleFonts.inter(
                color: Colors.white.withValues(alpha: 0.72),
                height: 1.45,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _DarkMetaPill(
                  icon: Icons.route_rounded,
                  label: currentAction.course.pathLabel,
                ),
                _DarkMetaPill(
                  icon: Icons.signal_cellular_alt_rounded,
                  label: currentAction.course.difficulty,
                ),
                _DarkMetaPill(
                  icon: Icons.schedule_rounded,
                  label: '${currentAction.course.durationMinutes} min',
                ),
              ],
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: firestoreService == null
                    ? null
                    : () {
                        if (currentAction.isQuiz) {
                          showDialog(
                            context: context,
                            builder: (_) =>
                                _QuizDialog(course: currentAction.course),
                          );
                          return;
                        }
                        final lesson = currentAction.lesson;
                        if (lesson == null) return;
                        _showLessonDetailSheet(
                          context,
                          course: currentAction.course,
                          lesson: lesson,
                          completed: plan.isLessonCompleted(
                            currentAction.course,
                            lesson,
                          ),
                        );
                      },
                icon: Icon(
                  currentAction.isQuiz
                      ? Icons.sports_score_rounded
                      : Icons.play_circle_fill_rounded,
                ),
                label: Text(currentAction.ctaLabel),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1BFFFF),
                  foregroundColor: const Color(0xFF0F172A),
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                  textStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ForYouRoadmapSection extends StatelessWidget {
  const _ForYouRoadmapSection({required this.plan});

  final _LearningPlan plan;

  @override
  Widget build(BuildContext context) {
    final roadmap = plan.personalizedRoadmap;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBadge(
                icon: Icons.auto_graph_rounded,
                color: const Color(0xFF0EA5A4),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'For You',
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textPrimary,
                        fontSize: 21,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      plan.personalizedBrief,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        height: 1.45,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetaPill(
                icon: Icons.flag_rounded,
                label: plan.primaryGoalLabel,
                color: AppTheme.primary,
              ),
              _MetaPill(
                icon: Icons.signal_cellular_alt_rounded,
                label: plan.currentLevelLabel,
                color: const Color(0xFF7C3AED),
              ),
              _MetaPill(
                icon: Icons.route_rounded,
                label: '${plan.remainingLessons} lessons left',
                color: const Color(0xFFD97706),
              ),
            ],
          ),
          const SizedBox(height: 18),
          ...roadmap.asMap().entries.map(
            (entry) => _RoadmapStepTile(
              step: entry.value,
              index: entry.key,
              isLast: entry.key == roadmap.length - 1,
            ),
          ),
        ],
      ),
    );
  }
}

class _RoadmapStepTile extends StatelessWidget {
  const _RoadmapStepTile({
    required this.step,
    required this.index,
    required this.isLast,
  });

  final _RoadmapStep step;
  final int index;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final color = step.completed
        ? AppTheme.success
        : step.active
        ? AppTheme.primary
        : AppTheme.textHint;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Column(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: step.completed ? color : color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: color.withValues(alpha: 0.35)),
              ),
              child: Icon(
                step.completed ? Icons.check_rounded : step.icon,
                color: step.completed ? Colors.white : color,
                size: 18,
              ),
            ),
            if (!isLast)
              Container(
                width: 2,
                height: 38,
                margin: const EdgeInsets.symmetric(vertical: 4),
                color: color.withValues(alpha: 0.18),
              ),
          ],
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 1, bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        step.title,
                        style: GoogleFonts.plusJakartaSans(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    _TinyStatusPill(
                      label: step.completed
                          ? 'Done'
                          : step.active
                          ? 'Now'
                          : 'Next',
                      color: color,
                    ),
                  ],
                ),
                const SizedBox(height: 5),
                Text(
                  step.subtitle,
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    height: 1.35,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _LearningPathGrid extends StatelessWidget {
  const _LearningPathGrid({
    required this.plan,
    required this.selectedTrackId,
    required this.onTrackSelected,
  });

  final _LearningPlan plan;
  final String selectedTrackId;
  final ValueChanged<String> onTrackSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionHeader(
          title: 'All Learning Paths',
          subtitle:
              'Choose a track by confidence level or jump into the specialist areas that match your goals.',
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final isWide = constraints.maxWidth >= 760;
            return GridView.count(
              crossAxisCount: isWide ? 4 : 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              childAspectRatio: isWide ? 1.05 : 0.92,
              children: DemoFinanceData.learningTracks.map((track) {
                return _TrackCard(
                  track: track,
                  progress: plan.trackProgress(track.id),
                  courseCount: plan.coursesForTrack(track.id).length,
                  selected: selectedTrackId == track.id,
                  onTap: () => onTrackSelected(
                    selectedTrackId == track.id ? 'all' : track.id,
                  ),
                );
              }).toList(),
            );
          },
        ),
      ],
    );
  }
}

class _TrackCard extends StatelessWidget {
  const _TrackCard({
    required this.track,
    required this.progress,
    required this.courseCount,
    required this.selected,
    required this.onTap,
  });

  final LearningTrack track;
  final double progress;
  final int courseCount;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(22),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: selected ? track.color.withValues(alpha: 0.1) : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(
            color: selected ? track.color : AppTheme.border,
            width: selected ? 1.5 : 1,
          ),
          boxShadow: AppTheme.softShadow,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _IconBadge(
                  icon: DemoFinanceData.courseIcon(track.iconName),
                  color: track.color,
                ),
                const Spacer(),
                _ProgressDot(value: progress),
              ],
            ),
            const Spacer(),
            Text(
              track.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              '$courseCount courses - ${(progress * 100).round()}% complete',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              track.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontSize: 12,
                height: 1.3,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SkillTreeSection extends StatelessWidget {
  const _SkillTreeSection({required this.plan});

  final _LearningPlan plan;

  @override
  Widget build(BuildContext context) {
    final tracks = DemoFinanceData.learningTracks;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 22,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Skill Tree',
            style: GoogleFonts.plusJakartaSans(
              color: Colors.white,
              fontSize: 21,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'A knowledge map from money basics to specialist PKR and Shariah-aware decisions.',
            style: GoogleFonts.inter(
              color: Colors.white.withValues(alpha: 0.68),
              height: 1.45,
            ),
          ),
          const SizedBox(height: 18),
          ...tracks.map((track) {
            final courses = plan.coursesForTrack(track.id);
            return Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        DemoFinanceData.courseIcon(track.iconName),
                        color: track.color,
                        size: 18,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        track.title,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    physics: const BouncingScrollPhysics(),
                    child: Row(
                      children: courses.map((course) {
                        final progress = plan.courseProgress(course);
                        return Container(
                          width: 190,
                          margin: const EdgeInsets.only(right: 10),
                          padding: const EdgeInsets.all(13),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.07),
                            borderRadius: BorderRadius.circular(18),
                            border: Border.all(
                              color: progress >= 1
                                  ? AppTheme.success.withValues(alpha: 0.45)
                                  : Colors.white.withValues(alpha: 0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      course.title,
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                      style: GoogleFonts.inter(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w900,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  Icon(
                                    progress >= 1
                                        ? Icons.check_circle_rounded
                                        : Icons.lock_open_rounded,
                                    color: progress >= 1
                                        ? AppTheme.success
                                        : track.color,
                                    size: 18,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 10),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(999),
                                child: LinearProgressIndicator(
                                  value: progress.clamp(0.0, 1.0),
                                  minHeight: 7,
                                  backgroundColor: Colors.white.withValues(
                                    alpha: 0.1,
                                  ),
                                  color: progress >= 1
                                      ? AppTheme.success
                                      : track.color,
                                ),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _AchievementGallery extends StatelessWidget {
  const _AchievementGallery({required this.plan});

  final _LearningPlan plan;

  @override
  Widget build(BuildContext context) {
    final achievements = plan.achievementCards;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionHeader(
            title: 'Achievements',
            subtitle:
                'Milestones encourage consistency without changing your backend reward model.',
          ),
          const SizedBox(height: 14),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            physics: const BouncingScrollPhysics(),
            child: Row(
              children: achievements.map((achievement) {
                return Container(
                  width: 210,
                  margin: const EdgeInsets.only(right: 12),
                  padding: const EdgeInsets.all(15),
                  decoration: BoxDecoration(
                    gradient: achievement.unlocked
                        ? LinearGradient(
                            colors: [
                              achievement.color,
                              achievement.color.withValues(alpha: 0.72),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                    color: achievement.unlocked
                        ? null
                        : const Color(0xFFF8FAFC),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: achievement.unlocked
                          ? achievement.color.withValues(alpha: 0.2)
                          : AppTheme.border,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        achievement.icon,
                        color: achievement.unlocked
                            ? Colors.white
                            : achievement.color,
                        size: 28,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        achievement.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.plusJakartaSans(
                          color: achievement.unlocked
                              ? Colors.white
                              : AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        achievement.subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          color: achievement.unlocked
                              ? Colors.white.withValues(alpha: 0.75)
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningLibraryControls extends StatelessWidget {
  const _LearningLibraryControls({
    required this.controller,
    required this.query,
    required this.selectedTrackId,
    required this.selectedDifficulty,
    required this.onQueryChanged,
    required this.onTrackChanged,
    required this.onDifficultyChanged,
  });

  final TextEditingController controller;
  final String query;
  final String selectedTrackId;
  final String selectedDifficulty;
  final ValueChanged<String> onQueryChanged;
  final ValueChanged<String> onTrackChanged;
  final ValueChanged<String> onDifficultyChanged;

  @override
  Widget build(BuildContext context) {
    const difficulties = [
      'All',
      'Starter',
      'Intermediate',
      'Advanced',
      'Specialist',
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: query.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      onPressed: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                      icon: const Icon(Icons.close_rounded),
                    ),
              hintText: 'Search budgeting, zakat, taxes, investing, PKR...',
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: AppTheme.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(
                  color: AppTheme.primary,
                  width: 1.5,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedTrackId,
                  decoration: InputDecoration(
                    labelText: 'Path',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: 'all',
                      child: Text('All paths'),
                    ),
                    ...DemoFinanceData.learningTracks.map(
                      (track) => DropdownMenuItem(
                        value: track.id,
                        child: Text(track.title),
                      ),
                    ),
                  ],
                  onChanged: (value) {
                    if (value != null) onTrackChanged(value);
                  },
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: selectedDifficulty,
                  decoration: InputDecoration(
                    labelText: 'Level',
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  items: difficulties
                      .map(
                        (difficulty) => DropdownMenuItem(
                          value: difficulty,
                          child: Text(difficulty),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value != null) onDifficultyChanged(value);
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

class _EmptyLibraryState extends StatelessWidget {
  const _EmptyLibraryState();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.search_off_rounded,
            color: AppTheme.textHint,
            size: 34,
          ),
          const SizedBox(height: 10),
          Text(
            'No matching courses',
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a broader topic like saving, tax, zakat, investing, or business.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(color: AppTheme.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _CategoryRail extends StatelessWidget {
  const _CategoryRail({required this.plan});

  final _LearningPlan plan;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      child: Row(
        children: DemoFinanceData.courses.map((course) {
          final progress = plan.courseProgress(course);
          return Container(
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppTheme.border),
              boxShadow: AppTheme.softShadow,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                _ProgressDot(value: progress),
                const SizedBox(width: 10),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      course.category,
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w800,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${(progress * 100).round()}% path progress',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: AppTheme.textPrimary,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            height: 1.45,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }
}

class _CourseJourneyCard extends StatelessWidget {
  const _CourseJourneyCard({
    required this.index,
    required this.course,
    required this.plan,
    required this.isRecommended,
    required this.firestoreService,
  });

  final int index;
  final LessonCourse course;
  final _LearningPlan plan;
  final bool isRecommended;
  final FirestoreService? firestoreService;

  @override
  Widget build(BuildContext context) {
    final completedIds = plan.completedLessonIds(course);
    final progress = plan.courseProgress(course);
    final quizScore = plan.quizScore(course);
    final quizPercentage = plan.quizPercentage(course);
    final nextLesson = plan.nextLessonFor(course);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isRecommended
              ? const Color(0xFF0EA5A4).withValues(alpha: 0.42)
              : AppTheme.border,
        ),
        boxShadow: [
          BoxShadow(
            color: isRecommended
                ? const Color(0xFF0EA5A4).withValues(alpha: 0.12)
                : Colors.black.withValues(alpha: 0.04),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              CachedNetworkImage(
                imageUrl: course.coverImageUrl,
                height: 178,
                width: double.infinity,
                fit: BoxFit.cover,
                placeholder: (context, url) => Container(
                  height: 178,
                  color: const Color(0xFFE8EDF7),
                  alignment: Alignment.center,
                  child: const CircularProgressIndicator(strokeWidth: 2),
                ),
                errorWidget: (context, url, error) => Container(
                  height: 178,
                  color: const Color(0xFFE8EDF7),
                  alignment: Alignment.center,
                  child: const Icon(Icons.image_not_supported_rounded),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.05),
                        Colors.black.withValues(alpha: 0.72),
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                left: 16,
                right: 16,
                bottom: 16,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ImageChip(label: 'Step ${index + 1}'),
                        _ImageChip(label: course.pathLabel),
                        if (isRecommended)
                          const _ImageChip(
                            label: 'Recommended next',
                            color: Color(0xFF1BFFFF),
                            textColor: Color(0xFF0F172A),
                          ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      course.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _MetaPill(
                      icon: Icons.signal_cellular_alt_rounded,
                      label: course.difficulty,
                      color: _difficultyColor(course.difficulty),
                    ),
                    _MetaPill(
                      icon: Icons.schedule_rounded,
                      label: '${course.durationMinutes} min',
                      color: AppTheme.primary,
                    ),
                    _MetaPill(
                      icon: Icons.bolt_rounded,
                      label: '${course.xpReward} quiz XP',
                      color: const Color(0xFFD97706),
                    ),
                    _MetaPill(
                      icon: Icons.star_rounded,
                      label: course.rating.toStringAsFixed(1),
                      color: const Color(0xFFF59E0B),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  course.subtitle,
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  course.description,
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    height: 1.5,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 14),
                _OutcomeBand(course: course),
                const SizedBox(height: 16),
                _CourseDepthPanel(course: course),
                const SizedBox(height: 16),
                _CourseProgressLine(
                  progress: progress,
                  completed: completedIds.length,
                  total: course.lessons.length,
                  quizPercentage: quizPercentage,
                ),
                const SizedBox(height: 16),
                if (course.skillTags.isNotEmpty)
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: course.skillTags
                        .map((tag) => _SkillTag(label: tag))
                        .toList(),
                  ),
                const SizedBox(height: 18),
                Text(
                  'Course lessons',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                ...course.lessons.asMap().entries.map(
                  (entry) => _LessonStepRow(
                    course: course,
                    lesson: entry.value,
                    index: entry.key,
                    completed: completedIds.contains(entry.value.id),
                    isNext: nextLesson?.id == entry.value.id,
                    enabled: firestoreService != null,
                  ),
                ),
                const SizedBox(height: 16),
                if (quizScore.isNotEmpty)
                  _QuizScoreBanner(
                    score: quizScore['score'] as int? ?? 0,
                    total:
                        quizScore['total'] as int? ??
                        course.quiz.questions.length,
                    percentage: quizPercentage,
                  ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _openExternal(course.externalUrl),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('Course Link'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.primary,
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _showCourseVideo(context, course),
                        icon: const Icon(
                          Icons.play_circle_outline_rounded,
                          size: 18,
                        ),
                        label: const Text('Watch'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          side: const BorderSide(color: AppTheme.border),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    onPressed: firestoreService == null
                        ? null
                        : () => showDialog(
                            context: context,
                            builder: (_) => _QuizDialog(course: course),
                          ),
                    icon: const Icon(Icons.quiz_rounded),
                    label: Text(
                      quizScore.isEmpty ? 'Take Quiz' : 'Retake Quiz',
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      textStyle: GoogleFonts.inter(
                        fontWeight: FontWeight.w900,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openExternal(String url) async {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  }
}

class _OutcomeBand extends StatelessWidget {
  const _OutcomeBand({required this.course});

  final LessonCourse course;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFEEF8F7),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFF0EA5A4).withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.flag_rounded, color: Color(0xFF0EA5A4), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              course.outcome,
              style: GoogleFonts.inter(
                color: const Color(0xFF115E59),
                fontWeight: FontWeight.w700,
                height: 1.4,
                fontSize: 13,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CourseDepthPanel extends StatelessWidget {
  const _CourseDepthPanel({required this.course});

  final LessonCourse course;

  @override
  Widget build(BuildContext context) {
    final rows = <_CourseDepthRow>[
      if (course.localRelevance.isNotEmpty)
        _CourseDepthRow(
          icon: Icons.location_on_rounded,
          label: 'Pakistan context',
          value: course.localRelevance,
        ),
      if (course.capstone.isNotEmpty)
        _CourseDepthRow(
          icon: Icons.task_alt_rounded,
          label: 'Capstone',
          value: course.capstone,
        ),
      if (course.prerequisites.isNotEmpty)
        _CourseDepthRow(
          icon: Icons.account_tree_rounded,
          label: 'Prerequisites',
          value: course.prerequisites.join(', '),
        ),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: rows.map((row) {
          final isLast = rows.last == row;
          return Padding(
            padding: EdgeInsets.only(bottom: isLast ? 0 : 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(row.icon, color: AppTheme.primary, size: 18),
                const SizedBox(width: 9),
                Expanded(
                  child: RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        height: 1.35,
                        fontSize: 13,
                      ),
                      children: [
                        TextSpan(
                          text: '${row.label}: ',
                          style: const TextStyle(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        TextSpan(text: row.value),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _CourseProgressLine extends StatelessWidget {
  const _CourseProgressLine({
    required this.progress,
    required this.completed,
    required this.total,
    required this.quizPercentage,
  });

  final double progress;
  final int completed;
  final int total;
  final int quizPercentage;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Path progress',
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
                fontSize: 13,
              ),
            ),
            const Spacer(),
            Text(
              '$completed/$total lessons',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 9),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: progress.clamp(0.0, 1.0),
            minHeight: 9,
            backgroundColor: const Color(0xFFE8EDF7),
            color: progress >= 1 ? AppTheme.success : AppTheme.primary,
          ),
        ),
        if (quizPercentage > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Latest quiz mastery: $quizPercentage%',
            style: GoogleFonts.inter(
              color: quizPercentage >= 80 ? AppTheme.success : AppTheme.warning,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }
}

class _LessonStepRow extends StatelessWidget {
  const _LessonStepRow({
    required this.course,
    required this.lesson,
    required this.index,
    required this.completed,
    required this.isNext,
    required this.enabled,
  });

  final LessonCourse course;
  final Lesson lesson;
  final int index;
  final bool completed;
  final bool isNext;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<AuthService>().firestoreService;
    final stepColor = completed
        ? AppTheme.success
        : isNext
        ? AppTheme.primary
        : AppTheme.textHint;
    final preview = lesson.content.length > 170
        ? '${lesson.content.substring(0, 170)}...'
        : lesson.content;
    final contentSignals = <String>[
      if (lesson.keyTakeaways.isNotEmpty)
        '${lesson.keyTakeaways.length} takeaways',
      if (lesson.practiceTasks.isNotEmpty)
        '${lesson.practiceTasks.length} practice tasks',
      if (lesson.caseStudies.isNotEmpty) 'case study',
      if (lesson.mythBusters.isNotEmpty) 'myth buster',
      if (lesson.localExample.isNotEmpty) 'PKR example',
    ];

    return InkWell(
      onTap: () => _showLessonDetailSheet(
        context,
        course: course,
        lesson: lesson,
        completed: completed,
      ),
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: completed
              ? AppTheme.success.withValues(alpha: 0.06)
              : isNext
              ? AppTheme.primary.withValues(alpha: 0.06)
              : const Color(0xFFF8FAFC),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: completed
                ? AppTheme.success.withValues(alpha: 0.18)
                : isNext
                ? AppTheme.primary.withValues(alpha: 0.18)
                : AppTheme.border,
          ),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: stepColor.withValues(alpha: completed ? 1 : 0.1),
                shape: BoxShape.circle,
                border: Border.all(
                  color: stepColor.withValues(alpha: completed ? 1 : 0.4),
                ),
              ),
              child: Icon(
                completed
                    ? Icons.check_rounded
                    : DemoFinanceData.courseIcon(lesson.icon),
                color: completed ? Colors.white : stepColor,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          lesson.title,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 15,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _TinyStatusPill(
                        label: completed
                            ? 'Done'
                            : isNext
                            ? 'Next'
                            : '${lesson.points} XP',
                        color: completed
                            ? AppTheme.success
                            : isNext
                            ? AppTheme.primary
                            : AppTheme.textHint,
                      ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  Text(
                    lesson.description,
                    style: GoogleFonts.inter(
                      color: AppTheme.textPrimary,
                      height: 1.35,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    preview,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondary,
                      height: 1.45,
                      fontSize: 13,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      ...contentSignals
                          .take(3)
                          .map(
                            (signal) => _TinyStatusPill(
                              label: signal,
                              color: AppTheme.primary,
                            ),
                          ),
                      TextButton.icon(
                        onPressed: () => _showLessonDetailSheet(
                          context,
                          course: course,
                          lesson: lesson,
                          completed: completed,
                        ),
                        icon: const Icon(Icons.menu_book_rounded, size: 16),
                        label: const Text('Read lesson'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Tooltip(
              message: completed ? 'Mark incomplete' : 'Mark complete',
              child: IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: !enabled || firestoreService == null
                    ? null
                    : () async {
                        await firestoreService.setLessonCompleted(
                          course.id,
                          lesson.id,
                          !completed,
                        );
                        if (!context.mounted) return;
                        _showLessonFeedback(
                          context,
                          lesson: lesson,
                          completed: !completed,
                        );
                      },
                icon: Icon(
                  completed
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: completed ? AppTheme.success : AppTheme.textHint,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonDetailSheet extends StatelessWidget {
  const _LessonDetailSheet({
    required this.course,
    required this.lesson,
    required this.completed,
  });

  final LessonCourse course;
  final Lesson lesson;
  final bool completed;

  @override
  Widget build(BuildContext context) {
    final firestoreService = context.read<AuthService>().firestoreService;
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.72,
      maxChildSize: 0.92,
      minChildSize: 0.45,
      builder: (context, controller) {
        return Container(
          decoration: const BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
          ),
          child: SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 12),
                Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                Expanded(
                  child: ListView(
                    controller: controller,
                    padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
                    children: [
                      Row(
                        children: [
                          _IconBadge(
                            icon: DemoFinanceData.courseIcon(lesson.icon),
                            color: completed
                                ? AppTheme.success
                                : AppTheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  course.pathLabel,
                                  style: GoogleFonts.inter(
                                    color: AppTheme.primary,
                                    fontWeight: FontWeight.w900,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Text(
                                  lesson.title,
                                  style: GoogleFonts.plusJakartaSans(
                                    fontSize: 24,
                                    fontWeight: FontWeight.w900,
                                    color: AppTheme.textPrimary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          _MetaPill(
                            icon: Icons.bolt_rounded,
                            label: '${lesson.points} XP',
                            color: const Color(0xFFD97706),
                          ),
                          _MetaPill(
                            icon: Icons.signal_cellular_alt_rounded,
                            label: course.difficulty,
                            color: _difficultyColor(course.difficulty),
                          ),
                          _MetaPill(
                            icon: completed
                                ? Icons.verified_rounded
                                : Icons.radio_button_unchecked_rounded,
                            label: completed ? 'Completed' : 'Ready',
                            color: completed
                                ? AppTheme.success
                                : AppTheme.primary,
                          ),
                        ],
                      ),
                      const SizedBox(height: 18),
                      Text(
                        lesson.description,
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondary,
                          fontSize: 15,
                          height: 1.45,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(18),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF8FAFC),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: AppTheme.border),
                        ),
                        child: Text(
                          lesson.content,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            height: 1.65,
                            color: const Color(0xFF334155),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      _LessonApplicationPanel(lesson: lesson),
                      const SizedBox(height: 18),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEEF2FF),
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.lightbulb_rounded,
                              color: AppTheme.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                course.outcome,
                                style: GoogleFonts.inter(
                                  color: AppTheme.textPrimary,
                                  height: 1.4,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(22, 8, 22, 18),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: firestoreService == null
                          ? null
                          : () async {
                              final nextCompleted = !completed;
                              await firestoreService.setLessonCompleted(
                                course.id,
                                lesson.id,
                                nextCompleted,
                              );
                              if (!context.mounted) return;
                              Navigator.pop(context);
                              _showLessonFeedback(
                                context,
                                lesson: lesson,
                                completed: nextCompleted,
                              );
                            },
                      icon: Icon(
                        completed
                            ? Icons.remove_done_rounded
                            : Icons.check_circle_rounded,
                      ),
                      label: Text(
                        completed ? 'Mark Incomplete' : 'Complete Lesson',
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: completed
                            ? const Color(0xFF475569)
                            : AppTheme.primary,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        textStyle: GoogleFonts.inter(
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _LessonApplicationPanel extends StatelessWidget {
  const _LessonApplicationPanel({required this.lesson});

  final Lesson lesson;

  @override
  Widget build(BuildContext context) {
    final sections = <_LessonResource>[
      if (lesson.keyTakeaways.isNotEmpty)
        _LessonResource(
          title: 'Key Takeaways',
          icon: Icons.checklist_rounded,
          items: lesson.keyTakeaways,
          color: AppTheme.success,
        ),
      if (lesson.practiceTasks.isNotEmpty)
        _LessonResource(
          title: 'Practice',
          icon: Icons.edit_note_rounded,
          items: lesson.practiceTasks,
          color: AppTheme.primary,
        ),
      if (lesson.caseStudies.isNotEmpty)
        _LessonResource(
          title: 'Case Study',
          icon: Icons.person_search_rounded,
          items: lesson.caseStudies,
          color: const Color(0xFF7C3AED),
        ),
      if (lesson.mythBusters.isNotEmpty)
        _LessonResource(
          title: 'Myth Buster',
          icon: Icons.psychology_alt_rounded,
          items: lesson.mythBusters,
          color: AppTheme.warning,
        ),
      if (lesson.calculators.isNotEmpty)
        _LessonResource(
          title: 'Calculator',
          icon: Icons.calculate_rounded,
          items: lesson.calculators,
          color: const Color(0xFF0EA5A4),
        ),
      if (lesson.templates.isNotEmpty)
        _LessonResource(
          title: 'Template',
          icon: Icons.description_rounded,
          items: lesson.templates,
          color: const Color(0xFF475569),
        ),
      if (lesson.applicationTools.isNotEmpty)
        _LessonResource(
          title: 'Application Tool',
          icon: Icons.construction_rounded,
          items: lesson.applicationTools,
          color: const Color(0xFFD97706),
        ),
      if (lesson.localExample.isNotEmpty)
        _LessonResource(
          title: 'PKR Example',
          icon: Icons.payments_rounded,
          items: [lesson.localExample],
          color: AppTheme.primary,
        ),
    ];

    final visibleSections = sections.isEmpty
        ? [
            const _LessonResource(
              title: 'Apply This',
              icon: Icons.task_alt_rounded,
              items: [
                'Write one decision you can make this week using this lesson.',
                'Translate the idea into a PKR amount, date, or habit rule.',
              ],
              color: AppTheme.primary,
            ),
          ]
        : sections;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Practice Lab',
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w900,
            fontSize: 17,
          ),
        ),
        const SizedBox(height: 10),
        ...visibleSections.map(
          (section) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _LessonResourceCard(section: section),
          ),
        ),
      ],
    );
  }
}

class _LessonResourceCard extends StatelessWidget {
  const _LessonResourceCard({required this.section});

  final _LessonResource section;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: section.color.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: section.color.withValues(alpha: 0.16)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(section.icon, color: section.color, size: 21),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  section.title,
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 6),
                ...section.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      item,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        height: 1.38,
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
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

class _QuizDialog extends StatefulWidget {
  const _QuizDialog({required this.course});

  final LessonCourse course;

  @override
  State<_QuizDialog> createState() => _QuizDialogState();
}

class _QuizDialogState extends State<_QuizDialog> {
  static const int _quizDurationSeconds = 120;

  final Map<String, int> _answers = {};
  bool _isSaving = false;
  Timer? _timer;
  int _remainingSeconds = _quizDurationSeconds;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_remainingSeconds <= 1) {
        timer.cancel();
        _submitQuiz(autoSubmitted: true);
        return;
      }
      setState(() => _remainingSeconds--);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final totalQuestions = widget.course.quiz.questions.length;
    final answeredCount = _answers.length;
    final answerProgress = totalQuestions == 0
        ? 0.0
        : answeredCount / totalQuestions;
    final timerProgress = _remainingSeconds / _quizDurationSeconds;
    final urgency = _timerUrgency(_remainingSeconds);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 640,
          maxHeight: MediaQuery.sizeOf(context).height * 0.9,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF15157D), Color(0xFF2E3192)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.course.pathLabel,
                              style: GoogleFonts.inter(
                                color: const Color(0xFF1BFFFF),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              widget.course.quiz.title,
                              style: GoogleFonts.plusJakartaSans(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 220),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          color: urgency.color.withValues(alpha: 0.18),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: urgency.color.withValues(alpha: 0.32),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.timer_rounded,
                              color: urgency.color,
                              size: 17,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _formatTime(_remainingSeconds),
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: _QuizProgressBar(
                          value: answerProgress,
                          color: const Color(0xFF1BFFFF),
                          label: 'Answered $answeredCount/$totalQuestions',
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: _QuizProgressBar(
                          value: timerProgress.clamp(0.0, 1.0),
                          color: urgency.color,
                          label: urgency.label,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                child: Column(
                  children: widget.course.quiz.questions.asMap().entries.map((
                    entry,
                  ) {
                    final question = entry.value;
                    final selected = _answers[question.id];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 18),
                      child: _QuizQuestionCard(
                        index: entry.key,
                        question: question,
                        selectedIndex: selected,
                        onSelected: (value) {
                          setState(() => _answers[question.id] = value);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(
                  bottom: Radius.circular(26),
                ),
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _isSaving ? null : () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  ElevatedButton.icon(
                    onPressed: _isSaving ? null : _submitQuiz,
                    icon: Icon(
                      _isSaving
                          ? Icons.sync_rounded
                          : Icons.sports_score_rounded,
                    ),
                    label: Text(_isSaving ? 'Saving...' : 'Submit Quiz'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.primary,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitQuiz({bool autoSubmitted = false}) async {
    final firestoreService = context.read<AuthService>().firestoreService;
    if (firestoreService == null || _isSaving) {
      return;
    }

    _timer?.cancel();
    if (mounted) {
      setState(() => _isSaving = true);
    }

    var score = 0;
    for (final question in widget.course.quiz.questions) {
      if (_answers[question.id] == question.correctIndex) {
        score++;
      }
    }

    await firestoreService.saveQuizSubmission(
      widget.course.id,
      widget.course.quiz.id,
      score,
      widget.course.quiz.questions.length,
      _answers,
    );

    if (score == widget.course.quiz.questions.length) {
      final title = switch (widget.course.id) {
        'budget-foundations' => 'Budget Master',
        'smart-investing' => 'Investment Beginner',
        'credit-and-debt' => 'Amateur Finance Expert',
        _ => 'Smart Saver',
      };
      await firestoreService.awardAchievement(widget.course.id, title);
    }

    if (!mounted) return;
    Navigator.pop(context);
    showDialog(
      context: context,
      builder: (_) => _QuizResultDialog(
        course: widget.course,
        answers: Map<String, int>.from(_answers),
        score: score,
        autoSubmitted: autoSubmitted,
      ),
    );
  }
}

class _QuizQuestionCard extends StatelessWidget {
  const _QuizQuestionCard({
    required this.index,
    required this.question,
    required this.selectedIndex,
    required this.onSelected,
  });

  final int index;
  final QuizQuestion question;
  final int? selectedIndex;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Text(
                '${index + 1}',
                style: GoogleFonts.inter(
                  color: AppTheme.primary,
                  fontWeight: FontWeight.w900,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                question.prompt,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w900,
                  fontSize: 16,
                  height: 1.35,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        ...List.generate(question.options.length, (optionIndex) {
          final isSelected = selectedIndex == optionIndex;
          return Padding(
            padding: const EdgeInsets.only(bottom: 9),
            child: InkWell(
              onTap: () => onSelected(optionIndex),
              borderRadius: BorderRadius.circular(16),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 180),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primary.withValues(alpha: 0.08)
                      : const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: isSelected ? AppTheme.primary : AppTheme.border,
                    width: isSelected ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      isSelected
                          ? Icons.check_circle_rounded
                          : Icons.circle_outlined,
                      color: isSelected ? AppTheme.primary : AppTheme.textHint,
                      size: 21,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        question.options[optionIndex],
                        style: GoogleFonts.inter(
                          color: AppTheme.textPrimary,
                          fontWeight: isSelected
                              ? FontWeight.w800
                              : FontWeight.w600,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }),
        if (selectedIndex != null)
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: Text(
              'Answer locked. You can change it before submitting.',
              style: GoogleFonts.inter(
                color: AppTheme.success,
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
      ],
    );
  }
}

class _QuizProgressBar extends StatelessWidget {
  const _QuizProgressBar({
    required this.value,
    required this.color,
    required this.label,
  });

  final double value;
  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(
            color: Colors.white.withValues(alpha: 0.78),
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 7),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: value.clamp(0.0, 1.0),
            minHeight: 9,
            backgroundColor: Colors.white.withValues(alpha: 0.12),
            color: color,
          ),
        ),
      ],
    );
  }
}

class _QuizResultDialog extends StatelessWidget {
  const _QuizResultDialog({
    required this.course,
    required this.answers,
    required this.score,
    required this.autoSubmitted,
  });

  final LessonCourse course;
  final Map<String, int> answers;
  final int score;
  final bool autoSubmitted;

  @override
  Widget build(BuildContext context) {
    final total = course.quiz.questions.length;
    final percentage = total == 0 ? 0 : ((score / total) * 100).round();
    final perfect = score == total && total > 0;
    final earnedQuizXp = total == 0
        ? 0
        : ((score / total) * course.xpReward).round();

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(26)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 620,
          maxHeight: MediaQuery.sizeOf(context).height * 0.88,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(22),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: perfect
                      ? const [Color(0xFF047857), Color(0xFF0EA5A4)]
                      : const [Color(0xFF15157D), Color(0xFF2E3192)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(26),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    perfect
                        ? Icons.emoji_events_rounded
                        : autoSubmitted
                        ? Icons.timer_off_rounded
                        : Icons.sports_score_rounded,
                    color: const Color(0xFF1BFFFF),
                    size: 34,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    autoSubmitted
                        ? 'Time is up'
                        : perfect
                        ? 'Achievement unlocked'
                        : 'Quiz saved',
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 24,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Score $score/$total - $percentage% mastery - $earnedQuizXp XP credited to your learning view.',
                    style: GoogleFonts.inter(
                      color: Colors.white.withValues(alpha: 0.78),
                      height: 1.45,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
            Flexible(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 18, 20, 8),
                shrinkWrap: true,
                children: course.quiz.questions.map((question) {
                  final answer = answers[question.id];
                  final correct = answer == question.correctIndex;
                  final selectedLabel = answer == null
                      ? 'No answer selected'
                      : question.options[answer];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: correct
                            ? AppTheme.success.withValues(alpha: 0.08)
                            : AppTheme.error.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: correct
                              ? AppTheme.success.withValues(alpha: 0.22)
                              : AppTheme.error.withValues(alpha: 0.18),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                correct
                                    ? Icons.check_circle_rounded
                                    : Icons.cancel_rounded,
                                color: correct
                                    ? AppTheme.success
                                    : AppTheme.error,
                                size: 20,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  question.prompt,
                                  style: GoogleFonts.inter(
                                    color: AppTheme.textPrimary,
                                    fontWeight: FontWeight.w900,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Text(
                            'Your answer: $selectedLabel',
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary,
                              fontWeight: FontWeight.w700,
                              height: 1.35,
                            ),
                          ),
                          if (!correct) ...[
                            const SizedBox(height: 6),
                            Text(
                              'Correct answer: ${question.options[question.correctIndex]}',
                              style: GoogleFonts.inter(
                                color: AppTheme.textPrimary,
                                fontWeight: FontWeight.w900,
                                height: 1.35,
                              ),
                            ),
                          ],
                          const SizedBox(height: 8),
                          Text(
                            question.explanation,
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary,
                              height: 1.45,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primary,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: const Text('Close'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuizScoreBanner extends StatelessWidget {
  const _QuizScoreBanner({
    required this.score,
    required this.total,
    required this.percentage,
  });

  final int score;
  final int total;
  final int percentage;

  @override
  Widget build(BuildContext context) {
    final color = percentage >= 80 ? AppTheme.success : AppTheme.warning;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          Icon(Icons.workspace_premium_rounded, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Latest quiz: $score/$total with $percentage% mastery',
              style: GoogleFonts.inter(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmbeddedVideoSheet extends StatefulWidget {
  const _EmbeddedVideoSheet({required this.course, required this.videoId});

  final LessonCourse course;
  final String videoId;

  @override
  State<_EmbeddedVideoSheet> createState() => _EmbeddedVideoSheetState();
}

class _EmbeddedVideoSheetState extends State<_EmbeddedVideoSheet> {
  late final YoutubePlayerController _controller;

  @override
  void initState() {
    super.initState();
    _controller = YoutubePlayerController.fromVideoId(
      videoId: widget.videoId,
      autoPlay: false,
      params: const YoutubePlayerParams(
        showControls: true,
        showFullscreenButton: true,
      ),
    );
  }

  @override
  void dispose() {
    _controller.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.border,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              Text(
                widget.course.title,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimary,
                  fontSize: 21,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Embedded lesson video',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 14),
              ClipRRect(
                borderRadius: BorderRadius.circular(18),
                child: YoutubePlayer(
                  controller: _controller,
                  aspectRatio: 16 / 9,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.course.outcome,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        height: 1.4,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  OutlinedButton.icon(
                    onPressed: () => launchUrl(
                      Uri.parse(widget.course.videoUrl),
                      mode: LaunchMode.externalApplication,
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 17),
                    label: const Text('Open'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CommunityLearningCard extends StatelessWidget {
  const _CommunityLearningCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _IconBadge(icon: Icons.forum_rounded, color: const Color(0xFF7C3AED)),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Community Learning',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 19,
                    fontWeight: FontWeight.w900,
                    color: AppTheme.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Discuss lessons, budgeting habits, and savings questions with other FinEase learners.',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    height: 1.45,
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

class _LearningPlan {
  _LearningPlan({
    required this.courses,
    required this.progressByCourse,
    required this.quizScores,
    required this.userProfile,
  });

  final List<LessonCourse> courses;
  final Map<String, Map<String, dynamic>> progressByCourse;
  final Map<String, Map<String, dynamic>> quizScores;
  final Map<String, dynamic> userProfile;

  int get totalLessons => courses.fold<int>(
    0,
    (runningTotal, course) => runningTotal + course.lessons.length,
  );

  int get completedLessons => courses.fold<int>(
    0,
    (runningTotal, course) => runningTotal + completedLessonIds(course).length,
  );

  int get totalQuizzes => courses.length;

  int get remainingLessons => math.max(0, totalLessons - completedLessons);

  int get completedQuizzes => courses.where((course) {
    final score = quizScore(course);
    final total = score['total'] as int? ?? course.quiz.questions.length;
    final earned = score['score'] as int? ?? 0;
    return score.isNotEmpty && total > 0 && earned / total >= 0.8;
  }).length;

  int get totalXp => courses.fold<int>(0, (runningTotal, course) {
    final lessonXp = course.lessons.fold<int>(
      0,
      (lessonSum, lesson) => lessonSum + lesson.points,
    );
    return runningTotal + lessonXp + course.xpReward;
  });

  int get earnedXp => courses.fold<int>(0, (runningTotal, course) {
    final completedIds = completedLessonIds(course);
    final lessonXp = course.lessons
        .where((lesson) => completedIds.contains(lesson.id))
        .fold<int>(0, (lessonSum, lesson) => lessonSum + lesson.points);
    final score = quizScore(course);
    final total = score['total'] as int? ?? course.quiz.questions.length;
    final earned = score['score'] as int? ?? 0;
    final quizXp = score.isEmpty || total == 0
        ? 0
        : ((earned / total) * course.xpReward).round();
    return runningTotal + lessonXp + quizXp;
  });

  int get xpPerLevel => 500;

  int get level => math.max(1, (earnedXp ~/ xpPerLevel) + 1);

  int get levelXp => earnedXp % xpPerLevel;

  double get levelProgress => levelXp / xpPerLevel;

  String get levelLabel {
    const labels = ['Starter', 'Builder', 'Planner', 'Strategist', 'Mentor'];
    return labels[math.min(level - 1, labels.length - 1)];
  }

  double get overallProgress {
    if (totalLessons == 0) return 0;
    return completedLessons / totalLessons;
  }

  String get currentLevelLabel {
    if (overallProgress >= 0.72 || completedQuizzes >= 6) {
      return 'Advanced learner';
    }
    if (overallProgress >= 0.34 || completedQuizzes >= 3) {
      return 'Intermediate learner';
    }
    if (completedLessons > 0) return 'Building basics';
    return 'New learner';
  }

  String get primaryGoalLabel {
    final explicitGoal =
        (userProfile['learningGoal'] ?? userProfile['financialGoal'])
            ?.toString()
            .trim();
    if (explicitGoal != null && explicitGoal.isNotEmpty) {
      return explicitGoal;
    }

    final savingsRate = _numValue(userProfile['targetSavingsRate']);
    final income = _numValue(userProfile['monthlyIncome']);
    if (income <= 0) return 'Set financial foundation';
    if (savingsRate >= 0.2) return 'Invest and build wealth';
    if (completedLessons < 4) return 'Stabilize cash flow';
    return 'Grow savings rate';
  }

  String get recommendedTrackId {
    if (completedLessons < 4) return 'beginner';
    final savingsRate = _numValue(userProfile['targetSavingsRate']);
    if (savingsRate >= 0.2 && overallProgress >= 0.35) return 'advanced';
    if (completedQuizzes >= 4) return 'specialist';
    if (overallProgress >= 0.22) return 'intermediate';
    return 'beginner';
  }

  LearningTrack get recommendedTrack {
    return DemoFinanceData.learningTracks.firstWhere(
      (track) => track.id == recommendedTrackId,
      orElse: () => DemoFinanceData.learningTracks.first,
    );
  }

  String get personalizedBrief {
    final track = recommendedTrack;
    final income = _numValue(userProfile['monthlyIncome']);
    final incomeContext = income > 0
        ? ' Your profile has PKR ${income.toStringAsFixed(0)} monthly income, so recommendations emphasize usable cash flow and next-step planning.'
        : '';
    return 'FinEase recommends the ${track.title} path because your current level is $currentLevelLabel and your goal signal is "$primaryGoalLabel".$incomeContext';
  }

  List<_RoadmapStep> get personalizedRoadmap {
    final action = nextAction;
    final recommended = recommendedTrack;
    final foundationDone = trackProgress('beginner') >= 0.55;
    final intermediateDone = trackProgress('intermediate') >= 0.5;
    final advancedDone = trackProgress('advanced') >= 0.45;

    return [
      _RoadmapStep(
        title: 'Stabilize the foundation',
        subtitle:
            'Budget, emergency cash, spending behavior, and debt basics before complex products.',
        icon: Icons.account_balance_wallet_rounded,
        completed: foundationDone,
        active: recommended.id == 'beginner',
      ),
      _RoadmapStep(
        title: action == null ? 'Review mastery' : 'Do next: ${action.title}',
        subtitle:
            action?.reason ??
            'All current content is complete. Retake quizzes or explore specialist topics.',
        icon: Icons.play_circle_fill_rounded,
        completed: action == null,
        active: action != null,
      ),
      _RoadmapStep(
        title: 'Upgrade planning depth',
        subtitle:
            'Layer in protection, salary tax awareness, and investing rules when the base is steady.',
        icon: Icons.auto_graph_rounded,
        completed: intermediateDone,
        active: recommended.id == 'intermediate',
      ),
      _RoadmapStep(
        title: 'Specialize for your life',
        subtitle:
            'Choose advanced wealth, business finance, Islamic finance, zakat, or Pakistan-specific planning.',
        icon: Icons.workspace_premium_rounded,
        completed: advancedDone,
        active: recommended.id == 'advanced' || recommended.id == 'specialist',
      ),
    ];
  }

  String get streakLabel {
    final dates = courses
        .map(lastUpdatedFor)
        .whereType<DateTime>()
        .map((date) => DateUtils.dateOnly(date.toLocal()))
        .toSet();
    if (dates.isEmpty) return 'Start today';
    final today = DateUtils.dateOnly(DateTime.now());
    if (dates.contains(today)) return 'Active today';
    return 'Ready today';
  }

  _AchievementCopy get achievementPrompt {
    if (earnedXp == 0) {
      return const _AchievementCopy(
        title: 'First lesson bonus is waiting',
        subtitle: 'Complete any lesson to start building your FinEase XP.',
      );
    }
    if (levelProgress >= 0.8) {
      return _AchievementCopy(
        title: 'Level ${level + 1} is close',
        subtitle:
            '${xpPerLevel - levelXp} XP left. Finish a lesson or quiz to push over the line.',
      );
    }
    if (completedQuizzes == 0 && completedLessons >= 2) {
      return const _AchievementCopy(
        title: 'Quiz streak opportunity',
        subtitle: 'You have enough lesson work to turn knowledge into quiz XP.',
      );
    }
    return _AchievementCopy(
      title: '$levelLabel momentum',
      subtitle:
          'You have earned $earnedXp of $totalXp possible XP across all learning paths.',
    );
  }

  _NextLearningAction? get nextAction {
    final inProgress =
        courses.where((course) {
          final completed = completedLessonIds(course).length;
          return completed > 0 && completed < course.lessons.length;
        }).toList()..sort((a, b) {
          final aDate =
              lastUpdatedFor(a) ?? DateTime.fromMillisecondsSinceEpoch(0);
          final bDate =
              lastUpdatedFor(b) ?? DateTime.fromMillisecondsSinceEpoch(0);
          return bDate.compareTo(aDate);
        });

    for (final course in inProgress) {
      final lesson = nextLessonFor(course);
      if (lesson != null) {
        return _NextLearningAction.lesson(
          course: course,
          lesson: lesson,
          reason:
              'You already started this path. Finish the next lesson to keep the journey moving.',
        );
      }
    }

    for (final course in courses) {
      if (completedLessonIds(course).length == course.lessons.length &&
          quizScore(course).isEmpty) {
        return _NextLearningAction.quiz(
          course: course,
          reason:
              'All lessons are complete. Take the quiz to lock in mastery and earn course XP.',
        );
      }
    }

    final recommendedCourses = [
      ...coursesForTrack(recommendedTrackId),
      ...courses.where((course) => course.trackId != recommendedTrackId),
    ];

    for (final course in recommendedCourses) {
      final lesson = nextLessonFor(course);
      if (lesson != null) {
        return _NextLearningAction.lesson(
          course: course,
          lesson: lesson,
          reason:
              'This is the best starting point for the next visible outcome in your learning plan.',
        );
      }
    }

    for (final course in courses) {
      final score = quizScore(course);
      final total = score['total'] as int? ?? course.quiz.questions.length;
      final earned = score['score'] as int? ?? 0;
      if (score.isNotEmpty && total > 0 && earned < total) {
        return _NextLearningAction.quiz(
          course: course,
          reason:
              'You have completed the content. Retake the quiz to chase full mastery and unlock the achievement prompt.',
        );
      }
    }

    return null;
  }

  Set<String> completedLessonIds(LessonCourse course) {
    final progress = progressByCourse[course.id] ?? const {};
    return List<String>.from(
      progress['completedLessonIds'] ?? const [],
    ).toSet();
  }

  bool isLessonCompleted(LessonCourse course, Lesson lesson) {
    return completedLessonIds(course).contains(lesson.id);
  }

  double courseProgress(LessonCourse course) {
    if (course.lessons.isEmpty) return 0;
    return completedLessonIds(course).length / course.lessons.length;
  }

  List<LessonCourse> coursesForTrack(String trackId) {
    return courses.where((course) => course.trackId == trackId).toList();
  }

  double trackProgress(String trackId) {
    final trackCourses = coursesForTrack(trackId);
    final trackLessons = trackCourses.fold<int>(
      0,
      (runningTotal, course) => runningTotal + course.lessons.length,
    );
    if (trackLessons == 0) return 0;
    final trackCompleted = trackCourses.fold<int>(
      0,
      (runningTotal, course) =>
          runningTotal + completedLessonIds(course).length,
    );
    return trackCompleted / trackLessons;
  }

  List<LessonCourse> filteredCourses({
    required String query,
    required String trackId,
    required String difficulty,
  }) {
    final normalizedQuery = query.trim().toLowerCase();
    return courses.where((course) {
      final trackMatches = trackId == 'all' || course.trackId == trackId;
      final difficultyMatches =
          difficulty == 'All' || course.difficulty == difficulty;
      if (!trackMatches || !difficultyMatches) return false;
      if (normalizedQuery.isEmpty) return true;
      return _courseSearchText(course).contains(normalizedQuery);
    }).toList();
  }

  List<_AchievementCard> get achievementCards {
    return [
      _AchievementCard(
        title: 'First Lesson',
        subtitle: 'Complete any lesson',
        icon: Icons.flag_rounded,
        color: AppTheme.primary,
        unlocked: completedLessons >= 1,
      ),
      _AchievementCard(
        title: 'Quiz Winner',
        subtitle: 'Score 80% or better',
        icon: Icons.quiz_rounded,
        color: const Color(0xFF0EA5A4),
        unlocked: completedQuizzes >= 1,
      ),
      _AchievementCard(
        title: 'Foundation Builder',
        subtitle: 'Reach 50% in Beginner',
        icon: Icons.account_balance_wallet_rounded,
        color: AppTheme.success,
        unlocked: trackProgress('beginner') >= 0.5,
      ),
      _AchievementCard(
        title: 'Pakistan Specialist',
        subtitle: 'Start a local or Islamic finance path',
        icon: Icons.workspace_premium_rounded,
        color: const Color(0xFFD97706),
        unlocked: coursesForTrack(
          'specialist',
        ).any((course) => courseProgress(course) > 0),
      ),
      _AchievementCard(
        title: 'Wealth Strategist',
        subtitle: 'Cross Level 3',
        icon: Icons.auto_graph_rounded,
        color: const Color(0xFF7C3AED),
        unlocked: level >= 3,
      ),
    ];
  }

  Lesson? nextLessonFor(LessonCourse course) {
    final completed = completedLessonIds(course);
    for (final lesson in course.lessons) {
      if (!completed.contains(lesson.id)) return lesson;
    }
    return null;
  }

  Map<String, dynamic> quizScore(LessonCourse course) {
    return quizScores['${course.id}_${course.quiz.id}'] ?? const {};
  }

  int quizPercentage(LessonCourse course) {
    final score = quizScore(course);
    if (score.isEmpty) return 0;
    final percentage = score['percentage'];
    if (percentage is int) return percentage;
    if (percentage is num) return percentage.round();
    final total = score['total'] as int? ?? course.quiz.questions.length;
    final earned = score['score'] as int? ?? 0;
    return total == 0 ? 0 : ((earned / total) * 100).round();
  }

  DateTime? lastUpdatedFor(LessonCourse course) {
    final value = progressByCourse[course.id]?['lastUpdated'];
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _courseSearchText(LessonCourse course) {
    final values = <String>[
      course.title,
      course.subtitle,
      course.description,
      course.category,
      course.difficulty,
      course.outcome,
      course.pathLabel,
      course.localRelevance,
      course.capstone,
      ...course.skillTags,
      ...course.prerequisites,
      for (final lesson in course.lessons) ...[
        lesson.title,
        lesson.description,
        lesson.content,
        lesson.localExample,
        ...lesson.keyTakeaways,
        ...lesson.practiceTasks,
        ...lesson.caseStudies,
        ...lesson.mythBusters,
        ...lesson.templates,
        ...lesson.calculators,
        ...lesson.applicationTools,
      ],
    ];
    return values.join(' ').toLowerCase();
  }

  double _numValue(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }
}

class _NextLearningAction {
  const _NextLearningAction._({
    required this.course,
    required this.lesson,
    required this.isQuiz,
    required this.reason,
  });

  factory _NextLearningAction.lesson({
    required LessonCourse course,
    required Lesson lesson,
    required String reason,
  }) {
    return _NextLearningAction._(
      course: course,
      lesson: lesson,
      isQuiz: false,
      reason: reason,
    );
  }

  factory _NextLearningAction.quiz({
    required LessonCourse course,
    required String reason,
  }) {
    return _NextLearningAction._(
      course: course,
      lesson: null,
      isQuiz: true,
      reason: reason,
    );
  }

  final LessonCourse course;
  final Lesson? lesson;
  final bool isQuiz;
  final String reason;

  String get eyebrow => isQuiz ? 'Recommended quiz' : course.pathLabel;

  String get title =>
      isQuiz ? course.quiz.title : lesson?.title ?? course.title;

  String get ctaLabel => isQuiz ? 'Start Quiz' : 'Open Lesson';
}

class _AchievementCopy {
  const _AchievementCopy({required this.title, required this.subtitle});

  final String title;
  final String subtitle;
}

class _RoadmapStep {
  const _RoadmapStep({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.completed,
    required this.active,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool completed;
  final bool active;
}

class _AchievementCard {
  const _AchievementCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.unlocked,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final bool unlocked;
}

class _CourseDepthRow {
  const _CourseDepthRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;
}

class _LessonResource {
  const _LessonResource({
    required this.title,
    required this.icon,
    required this.items,
    required this.color,
  });

  final String title;
  final IconData icon;
  final List<String> items;
  final Color color;
}

class _TimerUrgency {
  const _TimerUrgency({required this.color, required this.label});

  final Color color;
  final String label;
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.label});

  final int level;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.14)),
      ),
      child: Text(
        'L$level $label',
        style: GoogleFonts.inter(
          color: AppTheme.primary,
          fontWeight: FontWeight.w900,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _IconBadge extends StatelessWidget {
  const _IconBadge({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Icon(icon, color: color),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({
    required this.icon,
    required this.label,
    required this.color,
  });

  final IconData icon;
  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontWeight: FontWeight.w900,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkMetaPill extends StatelessWidget {
  const _DarkMetaPill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: const Color(0xFF1BFFFF), size: 15),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontWeight: FontWeight.w800,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}

class _ImageChip extends StatelessWidget {
  const _ImageChip({required this.label, this.color, this.textColor});

  final String label;
  final Color? color;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color ?? Colors.white.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: textColor ?? Colors.white,
          fontWeight: FontWeight.w900,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _SkillTag extends StatelessWidget {
  const _SkillTag({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppTheme.border),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w800,
          fontSize: 12,
        ),
      ),
    );
  }
}

class _TinyStatusPill extends StatelessWidget {
  const _TinyStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _StreakPill extends StatelessWidget {
  const _StreakPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFFD97706).withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.local_fire_department_rounded,
            color: Color(0xFFF59E0B),
            size: 16,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: GoogleFonts.inter(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProgressDot extends StatelessWidget {
  const _ProgressDot({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final complete = value >= 1;
    return SizedBox(
      width: 34,
      height: 34,
      child: Stack(
        alignment: Alignment.center,
        children: [
          CircularProgressIndicator(
            value: value.clamp(0.0, 1.0),
            strokeWidth: 4,
            backgroundColor: const Color(0xFFE8EDF7),
            color: complete ? AppTheme.success : AppTheme.primary,
          ),
          Icon(
            complete ? Icons.check_rounded : Icons.route_rounded,
            size: 16,
            color: complete ? AppTheme.success : AppTheme.primary,
          ),
        ],
      ),
    );
  }
}

Color _difficultyColor(String difficulty) {
  switch (difficulty.toLowerCase()) {
    case 'intermediate':
      return const Color(0xFF7C3AED);
    case 'advanced':
      return AppTheme.error;
    default:
      return AppTheme.success;
  }
}

_TimerUrgency _timerUrgency(int remainingSeconds) {
  if (remainingSeconds <= 15) {
    return const _TimerUrgency(
      color: Color(0xFFEF4444),
      label: 'Final seconds',
    );
  }
  if (remainingSeconds <= 30) {
    return const _TimerUrgency(
      color: Color(0xFFF59E0B),
      label: 'Time pressure',
    );
  }
  return const _TimerUrgency(color: Color(0xFF1BFFFF), label: 'Timer steady');
}

String _formatTime(int seconds) {
  final minutes = seconds ~/ 60;
  final remainder = seconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${remainder.toString().padLeft(2, '0')}';
}

void _showCourseVideo(BuildContext context, LessonCourse course) {
  final videoId = course.videoId ?? _extractYoutubeVideoId(course.videoUrl);
  if (videoId == null) {
    launchUrl(Uri.parse(course.videoUrl), mode: LaunchMode.externalApplication);
    return;
  }

  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _EmbeddedVideoSheet(course: course, videoId: videoId),
  );
}

String? _extractYoutubeVideoId(String url) {
  final uri = Uri.tryParse(url);
  if (uri == null) return null;
  if (uri.host.contains('youtu.be') && uri.pathSegments.isNotEmpty) {
    return uri.pathSegments.first;
  }
  if (uri.queryParameters['v'] case final id?) {
    return id;
  }
  if (uri.pathSegments.contains('embed')) {
    final index = uri.pathSegments.indexOf('embed');
    if (uri.pathSegments.length > index + 1) {
      return uri.pathSegments[index + 1];
    }
  }
  return null;
}

void _showLessonDetailSheet(
  BuildContext context, {
  required LessonCourse course,
  required Lesson lesson,
  required bool completed,
}) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _LessonDetailSheet(
      course: course,
      lesson: lesson,
      completed: completed,
    ),
  );
}

void _showLessonFeedback(
  BuildContext context, {
  required Lesson lesson,
  required bool completed,
}) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: completed
          ? const Color(0xFF0F766E)
          : const Color(0xFF475569),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      content: Row(
        children: [
          Icon(
            completed ? Icons.bolt_rounded : Icons.undo_rounded,
            color: Colors.white,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              completed
                  ? 'Lesson complete. +${lesson.points} XP added to your learning progress.'
                  : 'Lesson marked incomplete. Your progress was updated.',
              style: GoogleFonts.inter(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    ),
  );
}
