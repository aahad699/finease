import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/app_config.dart';
import '../../models/forum_models.dart';
import '../../services/app_config_service.dart';
import '../../services/auth_service.dart';
import '../../services/forum_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_config_gate.dart';

const _forumCategories = [
  'All',
  'Savings',
  'Loans',
  'Budgeting',
  'Investing',
  'Success',
  'General',
];

const _suggestedTags = [
  'emergency-fund',
  'debt-payoff',
  'student',
  'family-budget',
  'side-income',
  'beginner',
  'goal-tracking',
  'zakat',
];

enum _ForumAiAction { summarize, suggestAdvice, detectInsights }

enum _ForumLanguage {
  english('English', 'EN'),
  urdu('اردو', 'UR'),
  romanUrdu('Roman Urdu', 'RU');

  const _ForumLanguage(this.label, this.shortLabel);

  final String label;
  final String shortLabel;
}

enum _FeedFocus {
  community('Community', Icons.public_rounded),
  aiForYou('AI For You', Icons.auto_awesome_rounded),
  beginnerPath('Beginner Path', Icons.route_rounded);

  const _FeedFocus(this.label, this.icon);

  final String label;
  final IconData icon;
}

class CommunityForumPage extends StatefulWidget {
  const CommunityForumPage({super.key});

  @override
  State<CommunityForumPage> createState() => _CommunityForumPageState();
}

class _CommunityForumPageState extends State<CommunityForumPage>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _selectedCategory = 'All';
  PostType? _selectedPostType;
  String? _selectedTag;
  String _sortBy = 'createdAt';
  _FeedFocus _feedFocus = _FeedFocus.community;
  _ForumLanguage _language = _ForumLanguage.english;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AppConfig>(
      stream: AppConfigService().watchConfig(),
      initialData: AppConfig.defaults(),
      builder: (context, snapshot) {
        final config = snapshot.data ?? AppConfig.defaults();
        if (config.maintenanceMode || !config.forumEnabled) {
          return AppBlockedScreen(
            title: config.maintenanceMode
                ? 'FinEase is under maintenance'
                : 'Community forum is paused',
            message: config.supportMessage,
            icon: config.maintenanceMode
                ? Icons.construction_rounded
                : Icons.forum_outlined,
          );
        }

        return Scaffold(
          backgroundColor: AppTheme.backgroundFor(context),
          body: Stack(
            children: [
              const _ForumAmbientBackground(),
              NestedScrollView(
                headerSliverBuilder: (context, innerBoxIsScrolled) => [
                  SliverAppBar(
                    pinned: true,
                    backgroundColor: AppTheme.backgroundFor(context).withValues(
                      alpha: 0.88,
                    ),
                    elevation: innerBoxIsScrolled ? 1 : 0,
                    title: Text(
                      _forumCopy(_language, 'title'),
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textPrimaryFor(context),
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    actions: [
                      _LanguageMenu(
                        language: _language,
                        onSelected: (language) {
                          setState(() => _language = language);
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    bottom: TabBar(
                      controller: _tabController,
                      labelColor: AppTheme.primary,
                      unselectedLabelColor: AppTheme.textSecondaryFor(context),
                      indicatorColor: AppTheme.primary,
                      labelStyle: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      ),
                      tabs: [
                        Tab(text: _forumCopy(_language, 'feed')),
                        Tab(text: _forumCopy(_language, 'topics')),
                      ],
                    ),
                  ),
                ],
                body: TabBarView(
                  controller: _tabController,
                  children: [
                    _ForumFeedTab(
                      selectedCategory: _selectedCategory,
                      selectedPostType: _selectedPostType,
                      selectedTag: _selectedTag,
                      sortBy: _sortBy,
                      feedFocus: _feedFocus,
                      language: _language,
                      commentsEnabled: config.forumCommentsEnabled,
                      onCategoryChanged: (category) {
                        setState(() => _selectedCategory = category);
                      },
                      onPostTypeChanged: (type) {
                        setState(() => _selectedPostType = type);
                      },
                      onTagChanged: (tag) {
                        setState(() => _selectedTag = tag);
                      },
                      onSortChanged: (sortBy) {
                        setState(() => _sortBy = sortBy);
                      },
                      onFeedFocusChanged: (focus) {
                        setState(() {
                          _feedFocus = focus;
                          if (focus == _FeedFocus.aiForYou &&
                              _selectedTag == null) {
                            _selectedTag = 'beginner';
                            _sortBy = 'hotScore';
                          }
                          if (focus == _FeedFocus.beginnerPath) {
                            _selectedTag = 'beginner';
                            _selectedPostType ??= PostType.tip;
                          }
                        });
                      },
                    ),
                    _CategoriesGrid(
                      onCategoryTap: (category) {
                        setState(() => _selectedCategory = category);
                        _tabController.animateTo(0);
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: config.forumPostingEnabled
                ? () => _showCreatePostSheet(context)
                : () => _showPausedSnack(config.supportMessage),
            backgroundColor: config.forumPostingEnabled
                ? AppTheme.primary
                : AppTheme.textHintFor(context),
            icon: Icon(Icons.edit_rounded, color: Colors.white),
            label: Text(
              config.forumPostingEnabled ? 'Post' : 'Posting paused',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCreatePostSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreatePostSheet(language: _language),
    );
  }

  void _showPausedSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _ForumFeedTab extends StatelessWidget {
  const _ForumFeedTab({
    required this.selectedCategory,
    required this.selectedPostType,
    required this.selectedTag,
    required this.sortBy,
    required this.feedFocus,
    required this.language,
    required this.commentsEnabled,
    required this.onCategoryChanged,
    required this.onPostTypeChanged,
    required this.onTagChanged,
    required this.onSortChanged,
    required this.onFeedFocusChanged,
  });

  final String selectedCategory;
  final PostType? selectedPostType;
  final String? selectedTag;
  final String sortBy;
  final _FeedFocus feedFocus;
  final _ForumLanguage language;
  final bool commentsEnabled;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<PostType?> onPostTypeChanged;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<_FeedFocus> onFeedFocusChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ForumFilterBar(
          selectedCategory: selectedCategory,
          selectedPostType: selectedPostType,
          selectedTag: selectedTag,
          sortBy: sortBy,
          feedFocus: feedFocus,
          language: language,
          onCategoryChanged: onCategoryChanged,
          onPostTypeChanged: onPostTypeChanged,
          onTagChanged: onTagChanged,
          onSortChanged: onSortChanged,
          onFeedFocusChanged: onFeedFocusChanged,
        ),
        Expanded(
          child: _ForumPostsList(
            category: selectedCategory,
            postType: selectedPostType,
            tag: selectedTag,
            sortBy: sortBy,
            feedFocus: feedFocus,
            language: language,
            commentsEnabled: commentsEnabled,
          ),
        ),
      ],
    );
  }
}

class _ForumFilterBar extends StatelessWidget {
  const _ForumFilterBar({
    required this.selectedCategory,
    required this.selectedPostType,
    required this.selectedTag,
    required this.sortBy,
    required this.feedFocus,
    required this.language,
    required this.onCategoryChanged,
    required this.onPostTypeChanged,
    required this.onTagChanged,
    required this.onSortChanged,
    required this.onFeedFocusChanged,
  });

  final String selectedCategory;
  final PostType? selectedPostType;
  final String? selectedTag;
  final String sortBy;
  final _FeedFocus feedFocus;
  final _ForumLanguage language;
  final ValueChanged<String> onCategoryChanged;
  final ValueChanged<PostType?> onPostTypeChanged;
  final ValueChanged<String?> onTagChanged;
  final ValueChanged<String> onSortChanged;
  final ValueChanged<_FeedFocus> onFeedFocusChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.backgroundFor(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: _FeedFocusSelector(
              selected: feedFocus,
              language: language,
              onSelected: onFeedFocusChanged,
            ),
          ),
          SizedBox(
            height: 52,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              itemCount: _forumCategories.length,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final category = _forumCategories[index];
                return _FilterChipButton(
                  label: category,
                  selected: selectedCategory == category,
                  onTap: () => onCategoryChanged(category),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        for (final type in PostType.values)
                          Padding(
                            padding: const EdgeInsets.only(right: 8),
                            child: _TypeFilterChip(
                              type: type,
                              selected: selectedPostType == type,
                              onTap: () {
                                onPostTypeChanged(
                                  selectedPostType == type ? null : type,
                                );
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                _SortMenu(sortBy: sortBy, onSelected: onSortChanged),
              ],
            ),
          ),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
              itemCount: _suggestedTags.length + 1,
              separatorBuilder: (context, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                if (index == 0) {
                  return _FilterChipButton(
                    label: 'All tags',
                    selected: selectedTag == null,
                    onTap: () => onTagChanged(null),
                    compact: true,
                  );
                }
                final tag = _suggestedTags[index - 1];
                return _FilterChipButton(
                  label: '#$tag',
                  selected: selectedTag == tag,
                  onTap: () => onTagChanged(selectedTag == tag ? null : tag),
                  compact: true,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _SortMenu extends StatelessWidget {
  const _SortMenu({required this.sortBy, required this.onSelected});

  final String sortBy;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<String>(
      tooltip: 'Sort feed',
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(value: 'createdAt', child: Text('Newest')),
        PopupMenuItem(value: 'hotScore', child: Text('Hot')),
        PopupMenuItem(value: 'engagementScore', child: Text('Most engaged')),
      ],
      child: Container(
        height: 36,
        width: 36,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surfaceFor(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderFor(context)),
        ),
        child: Icon(
          sortBy == 'createdAt' ? Icons.sort_rounded : Icons.whatshot_rounded,
          color: AppTheme.textSecondaryFor(context),
          size: 20,
        ),
      ),
    );
  }
}

class _LanguageMenu extends StatelessWidget {
  const _LanguageMenu({required this.language, required this.onSelected});

  final _ForumLanguage language;
  final ValueChanged<_ForumLanguage> onSelected;

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_ForumLanguage>(
      tooltip: 'Language',
      onSelected: onSelected,
      itemBuilder: (context) => [
        for (final option in _ForumLanguage.values)
          PopupMenuItem(value: option, child: Text(option.label)),
      ],
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: AppTheme.surfaceFor(context).withValues(alpha: 0.72),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.borderFor(context)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.translate_rounded,
              size: 16,
              color: AppTheme.primary,
            ),
            const SizedBox(width: 5),
            Text(
              language.shortLabel,
              style: GoogleFonts.inter(
                color: AppTheme.textPrimaryFor(context),
                fontSize: 12,
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedFocusSelector extends StatelessWidget {
  const _FeedFocusSelector({
    required this.selected,
    required this.language,
    required this.onSelected,
  });

  final _FeedFocus selected;
  final _ForumLanguage language;
  final ValueChanged<_FeedFocus> onSelected;

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      padding: const EdgeInsets.all(6),
      glowColor: AppTheme.primary,
      child: Row(
        children: [
          for (final focus in _FeedFocus.values)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: _FocusButton(
                  focus: focus,
                  label: _feedFocusCopy(focus, language),
                  selected: selected == focus,
                  onTap: () => onSelected(focus),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _FocusButton extends StatelessWidget {
  const _FocusButton({
    required this.focus,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final _FeedFocus focus;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primary : Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 9),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                focus.icon,
                color: selected ? Colors.white : AppTheme.textSecondaryFor(context),
                size: 16,
              ),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: selected ? Colors.white : AppTheme.textSecondaryFor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ForumPostsList extends StatelessWidget {
  const _ForumPostsList({
    required this.category,
    required this.postType,
    required this.tag,
    required this.sortBy,
    required this.feedFocus,
    required this.language,
    required this.commentsEnabled,
  });

  final String category;
  final PostType? postType;
  final String? tag;
  final String sortBy;
  final _FeedFocus feedFocus;
  final _ForumLanguage language;
  final bool commentsEnabled;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<ForumPost>>(
      stream: ForumService.instance.watchPosts(
        category: category,
        postType: postType,
        tags: tag == null ? const [] : [tag!],
        sortBy: sortBy,
      ),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorState(
            title: 'Could not load forum posts',
            message: '${snapshot.error}',
          );
        }

        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _PostSkeletonList();
        }

        final posts = _personalizePosts(
          snapshot.data ?? const <ForumPost>[],
          feedFocus,
          tag,
        );
        if (posts.isEmpty) {
          return _EmptyState(
            icon: Icons.forum_outlined,
            title: 'No conversations yet',
            message: tag == null
                ? 'Start a focused finance discussion for this topic.'
                : 'No posts currently use #$tag.',
          );
        }

        return RefreshIndicator(
          color: AppTheme.primary,
          onRefresh: () async {
            await Future<void>.delayed(const Duration(milliseconds: 350));
          },
          child: ListView.separated(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 96),
            itemCount: posts.length + 1,
            separatorBuilder: (context, index) => const SizedBox(height: 12),
            itemBuilder: (context, index) {
              if (index == 0) {
                return Column(
                  children: [
                    _ForumDashboardHeader(
                      posts: posts,
                      feedFocus: feedFocus,
                      language: language,
                    ),
                    const SizedBox(height: 12),
                    _LearningPathsStrip(language: language),
                  ],
                );
              }
              return _ForumPostCard(
                post: posts[index - 1],
                commentsEnabled: commentsEnabled,
              );
            },
          ),
        );
      },
    );
  }
}

class _ForumDashboardHeader extends StatelessWidget {
  const _ForumDashboardHeader({
    required this.posts,
    required this.feedFocus,
    required this.language,
  });

  final List<ForumPost> posts;
  final _FeedFocus feedFocus;
  final _ForumLanguage language;

  @override
  Widget build(BuildContext context) {
    final comments = posts.fold<int>(
      0,
      (total, post) => total + post.commentsCount,
    );
    final helpful = posts.fold<int>(
      0,
      (total, post) => total + post.reactionCount(ReactionType.helpful),
    );
    final trending = _topTrendingPost(posts);
    final topTag = _topTag(posts);
    final progress = (helpful + comments + posts.length).clamp(0, 100) / 100;

    return _GlassPanel(
      glowColor: AppTheme.secondary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _InfoBadge(
                      label: _feedFocusCopy(feedFocus, language),
                      icon: feedFocus.icon,
                      color: AppTheme.secondary,
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _forumCopy(language, 'heroTitle'),
                      style: GoogleFonts.plusJakartaSans(
                        color: AppTheme.textPrimaryFor(context),
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _forumCopy(language, 'heroSubtitle'),
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondaryFor(context),
                        fontSize: 13,
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _AiPulseOrb(progress: progress),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              Expanded(
                child: _DashboardMetric(
                  label: _forumCopy(language, 'activeThreads'),
                  value: '${posts.length}',
                  icon: Icons.forum_outlined,
                  color: AppTheme.primary,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DashboardMetric(
                  label: _forumCopy(language, 'replies'),
                  value: '$comments',
                  icon: Icons.question_answer_outlined,
                  color: AppTheme.success,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _DashboardMetric(
                  label: _forumCopy(language, 'helpful'),
                  value: '$helpful',
                  icon: Icons.volunteer_activism_outlined,
                  color: const Color(0xFF7C3AED),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _TrendingDiscussionStrip(
            post: trending,
            topTag: topTag,
            language: language,
          ),
          const SizedBox(height: 14),
          _AiCoachBanner(language: language, feedFocus: feedFocus),
        ],
      ),
    );
  }
}

class _DashboardMetric extends StatelessWidget {
  const _DashboardMetric({
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
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 520),
      tween: Tween(begin: 0, end: 1),
      curve: Curves.easeOutCubic,
      builder: (context, opacity, child) {
        return Opacity(
          opacity: opacity,
          child: Transform.translate(
            offset: Offset(0, (1 - opacity) * 8),
            child: child,
          ),
        );
      },
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: AppTheme.surfaceFor(context).withValues(alpha: 0.62),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.white.withValues(alpha: 0.52)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textPrimaryFor(context),
                fontSize: 19,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 10,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TrendingDiscussionStrip extends StatelessWidget {
  const _TrendingDiscussionStrip({
    required this.post,
    required this.topTag,
    required this.language,
  });

  final ForumPost? post;
  final String topTag;
  final _ForumLanguage language;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.primary.withValues(alpha: 0.10),
            AppTheme.secondary.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.48)),
      ),
      child: Row(
        children: [
          Container(
            height: 36,
            width: 36,
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              Icons.trending_up_rounded,
              color: AppTheme.primary,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _forumCopy(language, 'trending'),
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondaryFor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  post?.title ??
                      'Budget wins, savings streaks, and loan clarity',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimaryFor(context),
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _TagPill(label: topTag.isEmpty ? '#beginner' : '#$topTag'),
        ],
      ),
    );
  }
}

class _AiCoachBanner extends StatelessWidget {
  const _AiCoachBanner({required this.language, required this.feedFocus});

  final _ForumLanguage language;
  final _FeedFocus feedFocus;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(
          Icons.psychology_alt_outlined,
          color: AppTheme.primary,
          size: 18,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            _coachCopy(language, feedFocus),
            style: GoogleFonts.inter(
              color: AppTheme.textSecondaryFor(context),
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

class _LearningPathsStrip extends StatelessWidget {
  const _LearningPathsStrip({required this.language});

  final _ForumLanguage language;

  @override
  Widget build(BuildContext context) {
    final paths = [
      _LearningPath(
        _forumCopy(language, 'pathBudget'),
        Icons.account_balance_wallet_outlined,
        AppTheme.primary,
        0.72,
      ),
      _LearningPath(
        _forumCopy(language, 'pathSavings'),
        Icons.savings_outlined,
        AppTheme.success,
        0.58,
      ),
      _LearningPath(
        _forumCopy(language, 'pathInvest'),
        Icons.show_chart_rounded,
        const Color(0xFF7C3AED),
        0.36,
      ),
    ];

    return SizedBox(
      height: 112,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: paths.length,
        separatorBuilder: (context, index) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final path = paths[index];
          return _LearningPathCard(path: path);
        },
      ),
    );
  }
}

class _LearningPathCard extends StatelessWidget {
  const _LearningPathCard({required this.path});

  final _LearningPath path;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 196,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context).withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderFor(context)),
        boxShadow: [
          BoxShadow(
            color: path.color.withValues(alpha: 0.10),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(path.icon, color: path.color, size: 20),
          const Spacer(),
          Text(
            path.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              color: AppTheme.textPrimaryFor(context),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: path.progress,
              minHeight: 6,
              backgroundColor: AppTheme.borderFor(context),
              valueColor: AlwaysStoppedAnimation<Color>(path.color),
            ),
          ),
        ],
      ),
    );
  }
}

class _LearningPath {
  const _LearningPath(this.title, this.icon, this.color, this.progress);

  final String title;
  final IconData icon;
  final Color color;
  final double progress;
}

class _AiPulseOrb extends StatelessWidget {
  const _AiPulseOrb({required this.progress});

  final double progress;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      duration: const Duration(milliseconds: 700),
      tween: Tween(begin: 0, end: progress.clamp(0, 1)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        return SizedBox(
          height: 76,
          width: 76,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.primaryGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.secondary.withValues(alpha: 0.28),
                      blurRadius: 24,
                    ),
                  ],
                ),
              ),
              CircularProgressIndicator(
                value: value,
                strokeWidth: 5,
                backgroundColor: Colors.white.withValues(alpha: 0.26),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
              Icon(Icons.auto_awesome_rounded, color: Colors.white),
            ],
          ),
        );
      },
    );
  }
}

class _ForumPostCard extends StatefulWidget {
  const _ForumPostCard({required this.post, required this.commentsEnabled});

  final ForumPost post;
  final bool commentsEnabled;

  @override
  State<_ForumPostCard> createState() => _ForumPostCardState();
}

class _ForumPostCardState extends State<_ForumPostCard> {
  bool _expanded = false;
  bool _aiBusy = false;

  @override
  Widget build(BuildContext context) {
    final userId =
        context.select<AuthService, String?>((service) => service.user?.uid) ??
        '';
    final post = widget.post;
    final isLong = post.content.trim().length > 220;

    return Semantics(
      label: '${post.postType.label} post: ${post.title}',
      child: _GlassPanel(
        padding: EdgeInsets.zero,
        glowColor: post.postType.color,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _InfoBadge(
                        label: post.postType.label,
                        icon: post.postType.icon,
                        color: post.postType.color,
                      ),
                      _InfoBadge(
                        label: post.category,
                        icon: Icons.folder_outlined,
                        color: AppTheme.primary,
                      ),
                      if (post.hasPinnedAnswer)
                        const _InfoBadge(
                          label: 'Best answer',
                          icon: Icons.push_pin_outlined,
                          color: AppTheme.success,
                        ),
                      if (post.moderationStatus == ModerationStatus.flagged)
                        const _InfoBadge(
                          label: 'Flagged',
                          icon: Icons.flag_outlined,
                          color: AppTheme.warning,
                        ),
                    ],
                  ),
                  if (post.moderationStatus == ModerationStatus.flagged) ...[
                    const SizedBox(height: 12),
                    const _ModerationNotice(),
                  ],
                  const SizedBox(height: 14),
                  _PostAuthorRow(post: post),
                  const SizedBox(height: 14),
                  Text(
                    post.title,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimaryFor(context),
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      height: 1.25,
                    ),
                  ),
                  const SizedBox(height: 8),
                  AnimatedSize(
                    duration: const Duration(milliseconds: 180),
                    curve: Curves.easeOut,
                    child: Text(
                      post.content,
                      maxLines: _expanded ? null : 4,
                      overflow: _expanded
                          ? TextOverflow.visible
                          : TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondaryFor(context),
                        fontSize: 13,
                        height: 1.55,
                      ),
                    ),
                  ),
                  if (isLong)
                    Align(
                      alignment: Alignment.centerLeft,
                      child: TextButton.icon(
                        onPressed: () {
                          setState(() => _expanded = !_expanded);
                        },
                        icon: Icon(
                          _expanded
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          size: 18,
                        ),
                        label: Text(_expanded ? 'Show less' : 'Read more'),
                      ),
                    ),
                  if (post.postType == PostType.poll &&
                      post.pollOptions.isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _PollPreview(post: post),
                  ],
                  if (post.postType != PostType.poll) ...[
                    const SizedBox(height: 10),
                    _VisualFinanceStory(post: post),
                  ],
                  if (post.aiSummary != null &&
                      post.aiSummary!.trim().isNotEmpty) ...[
                    const SizedBox(height: 10),
                    _AiSummaryPreview(summary: post.aiSummary!.trim()),
                  ],
                  if (post.tags.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final tag in post.tags.take(8))
                          _TagPill(label: '#$tag'),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(height: 14),
            Divider(color: AppTheme.borderFor(context), height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
              child: Row(
                children: [
                  _ReactionButton(
                    post: post,
                    reactionType: ReactionType.helpful,
                    userId: userId,
                  ),
                  const SizedBox(width: 6),
                  _ReactionButton(
                    post: post,
                    reactionType: ReactionType.inspiring,
                    userId: userId,
                  ),
                  const SizedBox(width: 6),
                  _ReactionButton(
                    post: post,
                    reactionType: ReactionType.insightful,
                    userId: userId,
                  ),
                  const Spacer(),
                  _CommentsButton(
                    post: post,
                    commentsEnabled: widget.commentsEnabled,
                  ),
                  _SaveButton(post: post, userId: userId),
                  _AiActionMenu(busy: _aiBusy, onSelected: _runAiHook),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _runAiHook(_ForumAiAction action) async {
    if (_aiBusy) return;
    setState(() => _aiBusy = true);

    try {
      switch (action) {
        case _ForumAiAction.summarize:
          await ForumService.instance.generatePostSummary(widget.post.id);
        case _ForumAiAction.suggestAdvice:
          await ForumService.instance.suggestFinancialAdvice(widget.post.id);
        case _ForumAiAction.detectInsights:
          await ForumService.instance.detectKeyInsights(widget.post.id);
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'AI hook queued. Connect an AI service to complete it.',
            ),
          ),
        );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('AI hook failed: $error')));
    } finally {
      if (mounted) setState(() => _aiBusy = false);
    }
  }
}

class _PostAuthorRow extends StatelessWidget {
  const _PostAuthorRow({required this.post});

  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        CircleAvatar(
          radius: 18,
          backgroundColor: post.postType.color.withValues(alpha: 0.12),
          backgroundImage: post.displayAuthorAvatar.isEmpty
              ? null
              : NetworkImage(post.displayAuthorAvatar),
          child: post.displayAuthorAvatar.isEmpty
              ? Icon(
                  post.isAnonymous
                      ? Icons.visibility_off_outlined
                      : Icons.person_outline_rounded,
                  size: 18,
                  color: post.postType.color,
                )
              : null,
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Flexible(
                    child: Text(
                      post.displayAuthorName,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimaryFor(context),
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  if (post.isAnonymous) ...[
                    const SizedBox(width: 6),
                    Icon(
                      Icons.lock_outline_rounded,
                      color: AppTheme.textHintFor(context),
                      size: 14,
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  Flexible(
                    child: Text(
                      _formatTime(post.createdAt),
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondaryFor(context),
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  if (!post.isAnonymous) ...[
                    const SizedBox(width: 8),
                    _ReputationPill(
                      points: post.authorReputationPoints,
                      badges: post.authorBadges,
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ReactionButton extends StatelessWidget {
  const _ReactionButton({
    required this.post,
    required this.reactionType,
    required this.userId,
  });

  final ForumPost post;
  final ReactionType reactionType;
  final String userId;

  @override
  Widget build(BuildContext context) {
    final selected = post.userReaction(userId) == reactionType;
    final count = post.reactionCount(reactionType);
    final color = _reactionColor(reactionType);

    return Tooltip(
      message: reactionType.label,
      child: Material(
        color: selected ? color.withValues(alpha: 0.10) : AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: userId.isEmpty
              ? null
              : () async {
                  try {
                    await ForumService.instance.togglePostReaction(
                      postId: post.id,
                      userId: userId,
                      reactionType: reactionType,
                    );
                  } catch (error) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context)
                      ..clearSnackBars()
                      ..showSnackBar(
                        SnackBar(content: Text('Reaction failed: $error')),
                      );
                  }
                },
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.35)
                    : AppTheme.borderFor(context),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  selected ? reactionType.filledIcon : reactionType.outlineIcon,
                  size: 17,
                  color: selected ? color : AppTheme.textSecondaryFor(context),
                ),
                if (count > 0) ...[
                  const SizedBox(width: 4),
                  Text(
                    '$count',
                    style: GoogleFonts.inter(
                      color: selected ? color : AppTheme.textSecondaryFor(context),
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CommentsButton extends StatelessWidget {
  const _CommentsButton({required this.post, required this.commentsEnabled});

  final ForumPost post;
  final bool commentsEnabled;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: commentsEnabled ? 'Open comments' : 'Commenting paused',
      child: Material(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: commentsEnabled
              ? () {
                  showModalBottomSheet<void>(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (context) => _CommentsSheet(
                      post: post,
                      commentsEnabled: commentsEnabled,
                    ),
                  );
                }
              : null,
          child: Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.borderFor(context)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.chat_bubble_outline_rounded,
                  size: 17,
                  color: AppTheme.textSecondaryFor(context),
                ),
                const SizedBox(width: 4),
                Text(
                  '${post.commentsCount}',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondaryFor(context),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.post, required this.userId});

  final ForumPost post;
  final String userId;

  @override
  Widget build(BuildContext context) {
    if (userId.isEmpty) return const SizedBox.shrink();

    final savedDoc = FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('saved_posts')
        .doc(post.id);

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: savedDoc.snapshots(),
      builder: (context, snapshot) {
        final isSaved = snapshot.data?.exists ?? false;
        return IconButton(
          tooltip: isSaved ? 'Remove saved post' : 'Save post',
          visualDensity: VisualDensity.compact,
          onPressed: () => _toggleSave(savedDoc, isSaved),
          icon: Icon(
            isSaved ? Icons.bookmark_rounded : Icons.bookmark_outline_rounded,
            color: isSaved ? AppTheme.primary : AppTheme.textSecondaryFor(context),
          ),
        );
      },
    );
  }

  Future<void> _toggleSave(
    DocumentReference<Map<String, dynamic>> savedDoc,
    bool isSaved,
  ) async {
    if (isSaved) {
      await savedDoc.delete();
      return;
    }

    await savedDoc.set({
      'postId': post.id,
      'postType': post.postType.name,
      'category': post.category,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }
}

class _AiActionMenu extends StatelessWidget {
  const _AiActionMenu({required this.busy, required this.onSelected});

  final bool busy;
  final ValueChanged<_ForumAiAction> onSelected;

  @override
  Widget build(BuildContext context) {
    if (busy) {
      return const Padding(
        padding: EdgeInsets.all(10),
        child: SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }

    return PopupMenuButton<_ForumAiAction>(
      tooltip: 'AI learning tools',
      onSelected: onSelected,
      itemBuilder: (context) => const [
        PopupMenuItem(
          value: _ForumAiAction.summarize,
          child: Text('Summarize post'),
        ),
        PopupMenuItem(
          value: _ForumAiAction.suggestAdvice,
          child: Text('Suggest finance next steps'),
        ),
        PopupMenuItem(
          value: _ForumAiAction.detectInsights,
          child: Text('Detect key insights'),
        ),
      ],
      icon: Icon(
        Icons.auto_awesome_outlined,
        color: AppTheme.textSecondaryFor(context),
      ),
    );
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({required this.post, required this.commentsEnabled});

  final ForumPost post;
  final bool commentsEnabled;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _sending = false;
  bool _anonymous = false;
  ForumComment? _replyingTo;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthService>().user;
    final userId = user?.uid ?? '';

    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.48,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceFor(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 10),
              Container(
                width: 42,
                height: 4,
                decoration: BoxDecoration(
                  color: AppTheme.borderFor(context),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 10),
                child: _CommentsHeader(post: widget.post),
              ),
              Expanded(
                child: StreamBuilder<List<ForumComment>>(
                  stream: ForumService.instance.watchComments(widget.post.id),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return _ErrorState(
                        title: 'Could not load comments',
                        message: '${snapshot.error}',
                      );
                    }

                    if (snapshot.connectionState == ConnectionState.waiting &&
                        !snapshot.hasData) {
                      return const _CommentSkeletonList();
                    }

                    final comments = snapshot.data ?? const <ForumComment>[];
                    if (comments.isEmpty) {
                      return const _EmptyState(
                        icon: Icons.question_answer_outlined,
                        title: 'No answers yet',
                        message: 'Add the first reply or answer.',
                      );
                    }

                    return _ThreadedCommentsList(
                      controller: scrollController,
                      comments: comments,
                      post: widget.post,
                      userId: userId,
                      onReply: (comment) {
                        setState(() => _replyingTo = comment);
                      },
                    );
                  },
                ),
              ),
              _CommentComposer(
                controller: _commentController,
                enabled: widget.commentsEnabled && user != null,
                sending: _sending,
                anonymous: _anonymous,
                replyingTo: _replyingTo,
                onAnonymousChanged: (value) {
                  setState(() => _anonymous = value);
                },
                onCancelReply: () {
                  setState(() => _replyingTo = null);
                },
                onSubmit: _submitComment,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _submitComment() async {
    if (!widget.commentsEnabled || _sending) return;

    final user = context.read<AuthService>().user;
    final content = _commentController.text.trim();
    if (user == null || content.isEmpty) return;

    setState(() => _sending = true);

    try {
      await ForumService.instance.createComment(
        postId: widget.post.id,
        authorId: user.uid,
        authorName: user.displayName ?? user.email ?? 'FinEase User',
        authorAvatar: user.photoURL ?? '',
        content: content,
        isAnonymous: _anonymous,
        parentCommentId: _replyingTo?.id,
      );

      if (!mounted) return;
      _commentController.clear();
      setState(() => _replyingTo = null);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(SnackBar(content: Text('Comment failed: $error')));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }
}

class _CommentsHeader extends StatelessWidget {
  const _CommentsHeader({required this.post});

  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          height: 34,
          width: 34,
          decoration: BoxDecoration(
            color: post.postType.color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(post.postType.icon, size: 18, color: post.postType.color),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                post.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.plusJakartaSans(
                  color: AppTheme.textPrimaryFor(context),
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '${post.commentsCount} comments and replies',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondaryFor(context),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _ThreadedCommentsList extends StatelessWidget {
  const _ThreadedCommentsList({
    required this.controller,
    required this.comments,
    required this.post,
    required this.userId,
    required this.onReply,
  });

  final ScrollController controller;
  final List<ForumComment> comments;
  final ForumPost post;
  final String userId;
  final ValueChanged<ForumComment> onReply;

  @override
  Widget build(BuildContext context) {
    final repliesByParent = <String, List<ForumComment>>{};
    final roots = <ForumComment>[];

    for (final comment in comments) {
      if (comment.isReply) {
        repliesByParent
            .putIfAbsent(comment.parentCommentId!, () => [])
            .add(comment);
      } else {
        roots.add(comment);
      }
    }

    return ListView.separated(
      controller: controller,
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
      itemCount: roots.length,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final root = roots[index];
        final replies = repliesByParent[root.id] ?? const <ForumComment>[];
        return Column(
          children: [
            _CommentTile(
              post: post,
              comment: root,
              userId: userId,
              depth: 0,
              onReply: onReply,
            ),
            for (final reply in replies)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: _CommentTile(
                  post: post,
                  comment: reply,
                  userId: userId,
                  depth: 1,
                  onReply: onReply,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _CommentTile extends StatelessWidget {
  const _CommentTile({
    required this.post,
    required this.comment,
    required this.userId,
    required this.depth,
    required this.onReply,
  });

  final ForumPost post;
  final ForumComment comment;
  final String userId;
  final int depth;
  final ValueChanged<ForumComment> onReply;

  @override
  Widget build(BuildContext context) {
    final canMarkBestAnswer =
        userId.isNotEmpty && userId == post.authorId && !comment.isBestAnswer;

    return Padding(
      padding: EdgeInsets.only(left: depth == 0 ? 0 : 22),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (depth > 0)
            Container(
              width: 2,
              height: 82,
              margin: const EdgeInsets.only(right: 10, top: 4),
              color: AppTheme.borderFor(context),
            ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: comment.isBestAnswer
                    ? AppTheme.success.withValues(alpha: 0.08)
                    : AppTheme.surfaceCardFor(context),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: comment.isBestAnswer
                      ? AppTheme.success.withValues(alpha: 0.24)
                      : AppTheme.borderFor(context),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Wrap(
                          spacing: 6,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Text(
                              comment.displayName,
                              style: GoogleFonts.inter(
                                color: AppTheme.textPrimaryFor(context),
                                fontSize: 12,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                            if (comment.isAnonymous)
                              Icon(
                                Icons.lock_outline_rounded,
                                size: 12,
                                color: AppTheme.textHintFor(context),
                              ),
                            if (!comment.isAnonymous)
                              _ReputationPill(
                                points: comment.authorReputationPoints,
                                badges: comment.authorBadges,
                              ),
                            if (comment.isBestAnswer)
                              const _InfoBadge(
                                label: 'Best answer',
                                icon: Icons.check_circle_rounded,
                                color: AppTheme.success,
                              ),
                            if (comment.moderationStatus ==
                                ModerationStatus.flagged)
                              const _InfoBadge(
                                label: 'Flagged',
                                icon: Icons.flag_outlined,
                                color: AppTheme.warning,
                              ),
                          ],
                        ),
                      ),
                      Text(
                        _formatTime(comment.createdAt),
                        style: GoogleFonts.inter(
                          color: AppTheme.textSecondaryFor(context),
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    comment.content,
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondaryFor(context),
                      fontSize: 13,
                      height: 1.45,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _CommentReactionButton(
                        postId: post.id,
                        comment: comment,
                        userId: userId,
                        reactionType: ReactionType.helpful,
                      ),
                      const SizedBox(width: 8),
                      TextButton.icon(
                        onPressed: userId.isEmpty
                            ? null
                            : () => onReply(comment),
                        icon: Icon(Icons.reply_rounded, size: 16),
                        label: const Text('Reply'),
                        style: TextButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(54, 30),
                        ),
                      ),
                      if (canMarkBestAnswer) ...[
                        const SizedBox(width: 6),
                        TextButton.icon(
                          onPressed: () async {
                            await ForumService.instance.markBestAnswer(
                              postId: post.id,
                              commentId: comment.id,
                            );
                          },
                          icon: Icon(Icons.push_pin_outlined, size: 16),
                          label: const Text('Best'),
                          style: TextButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            padding: EdgeInsets.zero,
                            minimumSize: const Size(54, 30),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentReactionButton extends StatelessWidget {
  const _CommentReactionButton({
    required this.postId,
    required this.comment,
    required this.userId,
    required this.reactionType,
  });

  final String postId;
  final ForumComment comment;
  final String userId;
  final ReactionType reactionType;

  @override
  Widget build(BuildContext context) {
    final selected = comment.userReaction(userId) == reactionType;
    final count = comment.reactionCount(reactionType);

    return TextButton.icon(
      onPressed: userId.isEmpty
          ? null
          : () => ForumService.instance.toggleCommentReaction(
              postId: postId,
              commentId: comment.id,
              userId: userId,
              reactionType: reactionType,
            ),
      icon: Icon(
        selected ? reactionType.filledIcon : reactionType.outlineIcon,
        size: 15,
      ),
      label: Text(count > 0 ? '$count helpful' : 'Helpful'),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        minimumSize: const Size(72, 30),
        foregroundColor: selected ? AppTheme.success : AppTheme.textSecondaryFor(context),
      ),
    );
  }
}

class _CommentComposer extends StatelessWidget {
  const _CommentComposer({
    required this.controller,
    required this.enabled,
    required this.sending,
    required this.anonymous,
    required this.replyingTo,
    required this.onAnonymousChanged,
    required this.onCancelReply,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool sending;
  final bool anonymous;
  final ForumComment? replyingTo;
  final ValueChanged<bool> onAnonymousChanged;
  final VoidCallback onCancelReply;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    return AnimatedPadding(
      duration: const Duration(milliseconds: 160),
      padding: EdgeInsets.fromLTRB(20, 10, 20, bottomInset + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!enabled)
            const _ForumPausedBanner(
              message: 'Commenting is paused or requires a signed-in account.',
            ),
          if (replyingTo != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: AppTheme.primary.withValues(alpha: 0.16),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Replying to ${replyingTo!.displayName}',
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondaryFor(context),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cancel reply',
                    visualDensity: VisualDensity.compact,
                    onPressed: onCancelReply,
                    icon: Icon(Icons.close_rounded, size: 18),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),
          ],
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: controller,
                  enabled: enabled && !sending,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: InputDecoration(
                    hintText: replyingTo == null
                        ? 'Add an answer or comment'
                        : 'Write a reply',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filled(
                tooltip: 'Send comment',
                onPressed: enabled && !sending ? onSubmit : null,
                style: IconButton.styleFrom(backgroundColor: AppTheme.primary),
                icon: sending
                    ? const SizedBox(
                        height: 16,
                        width: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Icon(Icons.send_rounded, color: Colors.white),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: SwitchListTile.adaptive(
              value: anonymous,
              onChanged: enabled && !sending ? onAnonymousChanged : null,
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Comment anonymously',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondaryFor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet({required this.language});

  final _ForumLanguage language;

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  final TextEditingController _tagsController = TextEditingController();
  final TextEditingController _pollOptionsController = TextEditingController();

  PostType _postType = PostType.question;
  String _category = 'General';
  bool _isAnonymous = false;
  bool _posting = false;
  int _step = 0;

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    _tagsController.dispose();
    _pollOptionsController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.82,
      minChildSize: 0.52,
      maxChildSize: 0.94,
      builder: (context, scrollController) {
        return Container(
          decoration: BoxDecoration(
            color: AppTheme.surfaceFor(context),
            borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          ),
          child: SingleChildScrollView(
            controller: scrollController,
            padding: EdgeInsets.fromLTRB(
              24,
              14,
              24,
              MediaQuery.of(context).viewInsets.bottom + 24,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 42,
                    height: 4,
                    decoration: BoxDecoration(
                      color: AppTheme.borderFor(context),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Text(
                  'Create a finance discussion',
                  style: GoogleFonts.plusJakartaSans(
                    color: AppTheme.textPrimaryFor(context),
                    fontSize: 19,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Structure the post so people can learn from it quickly.',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondaryFor(context),
                    fontSize: 13,
                  ),
                ),
                const SizedBox(height: 18),
                _StepIndicator(step: _step),
                const SizedBox(height: 20),
                AnimatedSwitcher(
                  duration: const Duration(milliseconds: 180),
                  child: _buildStep(),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    if (_step > 0)
                      Expanded(
                        child: OutlinedButton(
                          onPressed: _posting
                              ? null
                              : () => setState(() => _step--),
                          child: const Text('Back'),
                        ),
                      ),
                    if (_step > 0) const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: _posting ? null : _handlePrimaryAction,
                        child: Text(
                          _step == 2
                              ? (_posting ? 'Publishing...' : 'Publish')
                              : 'Next',
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildStep() {
    if (_step == 0) {
      return _ComposerStep(
        key: const ValueKey('type'),
        title: 'Choose the learning format',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final type in PostType.values)
                  _PostTypeOption(
                    type: type,
                    selected: _postType == type,
                    onTap: () => setState(() => _postType = type),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SwitchListTile.adaptive(
              value: _isAnonymous,
              onChanged: (value) => setState(() => _isAnonymous = value),
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                'Safe-mode anonymous posting',
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimaryFor(context),
                  fontWeight: FontWeight.w700,
                ),
              ),
              subtitle: Text(
                'Your identity is hidden in the forum while authorId stays securely stored for moderation.',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondaryFor(context),
                  fontSize: 12,
                ),
              ),
            ),
            if (_isAnonymous) const _SafeModeNotice(),
          ],
        ),
      );
    }

    if (_step == 1) {
      return _ComposerStep(
        key: const ValueKey('write'),
        title: 'Write the post',
        child: Column(
          children: [
            TextField(
              controller: _titleController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Title',
                hintText: 'Example: How should I rebuild my emergency fund?',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _contentController,
              minLines: 5,
              maxLines: 8,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Details',
                hintText: 'Share the context, numbers, tradeoffs, and goal.',
              ),
            ),
            if (_postType == PostType.poll) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _pollOptionsController,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(
                  labelText: 'Poll options',
                  hintText: 'One option per line, or separate with commas',
                ),
              ),
            ],
          ],
        ),
      );
    }

    return _ComposerStep(
      key: const ValueKey('classify'),
      title: 'Classify for discovery',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Category',
            style: GoogleFonts.inter(
              color: AppTheme.textPrimaryFor(context),
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final category in _forumCategories.where(
                (item) => item != 'All',
              ))
                _FilterChipButton(
                  label: category,
                  selected: _category == category,
                  onTap: () => setState(() => _category = category),
                ),
            ],
          ),
          const SizedBox(height: 18),
          TextField(
            controller: _tagsController,
            decoration: const InputDecoration(
              labelText: 'Tags',
              hintText: 'Separate with commas: emergency-fund, beginner',
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final tag in _suggestedTags.take(6))
                ActionChip(
                  label: Text('#$tag'),
                  onPressed: () => _appendTag(tag),
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _handlePrimaryAction() {
    if (_step < 2) {
      if (!_canContinue()) return;
      setState(() => _step++);
      return;
    }
    _post();
  }

  bool _canContinue() {
    if (_step != 1) return true;

    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      _showSnack('Add a title and details before continuing.');
      return false;
    }

    if (_postType == PostType.poll && _parsePollOptions().length < 2) {
      _showSnack('Add at least two poll options.');
      return false;
    }

    return true;
  }

  Future<void> _post() async {
    if (!_canContinue()) return;

    final user = context.read<AuthService>().user;
    if (user == null) {
      _showSnack('Please sign in before posting.');
      return;
    }

    setState(() => _posting = true);

    try {
      await ForumService.instance.createPost(
        authorId: user.uid,
        authorName: user.displayName ?? user.email ?? 'FinEase User',
        authorAvatar: user.photoURL ?? '',
        title: _titleController.text.trim(),
        content: _contentController.text.trim(),
        category: _category,
        postType: _postType,
        tags: _parseTags(),
        pollOptions: _parsePollOptions(),
        isAnonymous: _isAnonymous,
        languageCode: _languageCode(widget.language),
      );

      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context)
        ..clearSnackBars()
        ..showSnackBar(const SnackBar(content: Text('Post published.')));
    } catch (error) {
      if (!mounted) return;
      _showSnack('Post failed: $error');
    } finally {
      if (mounted) setState(() => _posting = false);
    }
  }

  void _appendTag(String tag) {
    final existing = _parseTags().toSet();
    existing.add(tag);
    _tagsController.text = existing.take(8).join(', ');
  }

  List<String> _parseTags() {
    return _tagsController.text
        .split(',')
        .map((tag) => tag.trim().replaceFirst(RegExp(r'^#+'), '').toLowerCase())
        .where((tag) => tag.isNotEmpty)
        .toSet()
        .take(8)
        .toList(growable: false);
  }

  List<String> _parsePollOptions() {
    return _pollOptionsController.text
        .split(RegExp(r'[\n,]'))
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .toSet()
        .take(6)
        .toList(growable: false);
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CategoriesGrid extends StatelessWidget {
  const _CategoriesGrid({required this.onCategoryTap});

  final ValueChanged<String> onCategoryTap;

  static const _categories = [
    _CatInfo(
      'Savings',
      Icons.savings_rounded,
      Color(0xFF059669),
      'Emergency funds, savings goals, and habit building',
    ),
    _CatInfo(
      'Loans',
      Icons.account_balance_rounded,
      Color(0xFF2E3192),
      'Borrowing decisions, repayments, and debt payoff',
    ),
    _CatInfo(
      'Budgeting',
      Icons.account_balance_wallet_rounded,
      Color(0xFF0F766E),
      'Monthly plans, spending control, and family budgets',
    ),
    _CatInfo(
      'Investing',
      Icons.trending_up_rounded,
      Color(0xFF7C3AED),
      'Risk basics, compounding, and long-term thinking',
    ),
    _CatInfo(
      'Success',
      Icons.emoji_events_rounded,
      Color(0xFFD97706),
      'Wins, lessons learned, and progress milestones',
    ),
    _CatInfo(
      'General',
      Icons.forum_outlined,
      Color(0xFF475569),
      'Everyday money questions and community support',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 96),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        childAspectRatio: 0.96,
      ),
      itemCount: _categories.length,
      itemBuilder: (context, index) {
        final category = _categories[index];
        return Material(
          color: AppTheme.surfaceFor(context),
          borderRadius: BorderRadius.circular(8),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onCategoryTap(category.name),
            child: Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: AppTheme.borderFor(context)),
                boxShadow: AppTheme.softShadow,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 38,
                    width: 38,
                    decoration: BoxDecoration(
                      color: category.color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(category.icon, color: category.color, size: 21),
                  ),
                  const Spacer(),
                  Text(
                    category.name,
                    style: GoogleFonts.plusJakartaSans(
                      color: AppTheme.textPrimaryFor(context),
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    category.subtitle,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.inter(
                      color: AppTheme.textSecondaryFor(context),
                      fontSize: 11,
                      height: 1.35,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _ComposerStep extends StatelessWidget {
  const _ComposerStep({super.key, required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      key: key,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: GoogleFonts.plusJakartaSans(
            color: AppTheme.textPrimaryFor(context),
            fontSize: 16,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 14),
        child,
      ],
    );
  }
}

class _StepIndicator extends StatelessWidget {
  const _StepIndicator({required this.step});

  final int step;

  static const _labels = ['Type', 'Write', 'Classify'];

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var index = 0; index < _labels.length; index++) ...[
          _StepDot(label: _labels[index], selected: step >= index),
          if (index < _labels.length - 1)
            Expanded(
              child: Container(
                height: 1,
                margin: const EdgeInsets.symmetric(horizontal: 8),
                color: step > index ? AppTheme.primary : AppTheme.borderFor(context),
              ),
            ),
        ],
      ],
    );
  }
}

class _StepDot extends StatelessWidget {
  const _StepDot({required this.label, required this.selected});

  final String label;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          width: 30,
          height: 30,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: selected ? AppTheme.primary : AppTheme.surfaceFor(context),
            shape: BoxShape.circle,
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.borderFor(context),
            ),
          ),
          child: Icon(
            selected ? Icons.check_rounded : Icons.circle_outlined,
            size: 16,
            color: selected ? Colors.white : AppTheme.textHintFor(context),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            color: selected ? AppTheme.primary : AppTheme.textSecondaryFor(context),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _PostTypeOption extends StatelessWidget {
  const _PostTypeOption({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final PostType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? type.color : AppTheme.surfaceFor(context),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: onTap,
        child: Container(
          width: 146,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: selected ? type.color : AppTheme.borderFor(context)),
          ),
          child: Row(
            children: [
              Icon(type.icon, color: selected ? Colors.white : type.color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  type.label,
                  style: GoogleFonts.inter(
                    color: selected ? Colors.white : AppTheme.textPrimaryFor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterChipButton extends StatelessWidget {
  const _FilterChipButton({
    required this.label,
    required this.selected,
    required this.onTap,
    this.compact = false,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppTheme.primary : AppTheme.surfaceFor(context),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 12 : 15,
            vertical: compact ? 6 : 8,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: selected ? AppTheme.primary : AppTheme.borderFor(context),
            ),
          ),
          child: Text(
            label,
            style: GoogleFonts.inter(
              color: selected ? Colors.white : AppTheme.textSecondaryFor(context),
              fontSize: compact ? 12 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _TypeFilterChip extends StatelessWidget {
  const _TypeFilterChip({
    required this.type,
    required this.selected,
    required this.onTap,
  });

  final PostType type;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? type.color : AppTheme.surfaceFor(context),
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        borderRadius: BorderRadius.circular(999),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: selected ? type.color : AppTheme.borderFor(context)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                type.icon,
                size: 15,
                color: selected ? Colors.white : type.color,
              ),
              const SizedBox(width: 5),
              Text(
                type.label,
                style: GoogleFonts.inter(
                  color: selected ? Colors.white : type.color,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBadge extends StatelessWidget {
  const _InfoBadge({
    required this.label,
    required this.icon,
    required this.color,
  });

  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(7),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReputationPill extends StatelessWidget {
  const _ReputationPill({required this.points, required this.badges});

  final int points;
  final List<ReputationBadge> badges;

  @override
  Widget build(BuildContext context) {
    final badge = badges.isEmpty ? null : badges.first;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: AppTheme.success.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            badge?.icon ?? Icons.workspace_premium_outlined,
            color: AppTheme.success,
            size: 11,
          ),
          const SizedBox(width: 3),
          Text(
            points > 0 ? '$points pts' : 'new learner',
            style: GoogleFonts.inter(
              color: AppTheme.success,
              fontSize: 10,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _TagPill extends StatelessWidget {
  const _TagPill({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.07),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          color: AppTheme.primary,
          fontSize: 10,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _PollPreview extends StatelessWidget {
  const _PollPreview({required this.post});

  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    final totalVotes = post.pollVotes.values.fold<int>(
      0,
      (total, value) => total + value,
    );
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCardFor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderFor(context)),
      ),
      child: Column(
        children: [
          for (final option in post.pollOptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _PollOptionRow(
                label: option,
                votes: post.pollVotes[option] ?? 0,
                totalVotes: totalVotes,
              ),
            ),
        ],
      ),
    );
  }
}

class _VisualFinanceStory extends StatelessWidget {
  const _VisualFinanceStory({required this.post});

  final ForumPost post;

  @override
  Widget build(BuildContext context) {
    final progress = _financeProgress(post);
    final breakdown = _financeBreakdown(post);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            post.postType.color.withValues(alpha: 0.10),
            AppTheme.surfaceCardFor(context).withValues(alpha: 0.74),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: post.postType.color.withValues(alpha: 0.16)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  _storyTitle(post.postType),
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimaryFor(context),
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                '${(progress * 100).round()}%',
                style: GoogleFonts.plusJakartaSans(
                  color: post.postType.color,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 7,
              backgroundColor: AppTheme.borderFor(context),
              valueColor: AlwaysStoppedAnimation<Color>(post.postType.color),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 82,
            child: Row(
              children: [
                Expanded(
                  child: BarChart(
                    BarChartData(
                      alignment: BarChartAlignment.spaceAround,
                      borderData: FlBorderData(show: false),
                      gridData: const FlGridData(show: false),
                      titlesData: const FlTitlesData(show: false),
                      barTouchData: BarTouchData(enabled: false),
                      maxY: 100,
                      barGroups: [
                        for (var index = 0; index < breakdown.length; index++)
                          BarChartGroupData(
                            x: index,
                            barRods: [
                              BarChartRodData(
                                toY: breakdown[index].value,
                                width: 12,
                                borderRadius: BorderRadius.circular(4),
                                color: breakdown[index].color,
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final item in breakdown)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: _BreakdownLegend(item: item),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BreakdownLegend extends StatelessWidget {
  const _BreakdownLegend({required this.item});

  final _BreakdownItem item;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          height: 8,
          width: 8,
          decoration: BoxDecoration(color: item.color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 5),
        Text(
          item.label,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondaryFor(context),
            fontSize: 10,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}

class _BreakdownItem {
  const _BreakdownItem(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}

class _PollOptionRow extends StatelessWidget {
  const _PollOptionRow({
    required this.label,
    required this.votes,
    required this.totalVotes,
  });

  final String label;
  final int votes;
  final int totalVotes;

  @override
  Widget build(BuildContext context) {
    final percent = totalVotes == 0 ? 0.0 : votes / totalVotes;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: AppTheme.textPrimaryFor(context),
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${(percent * 100).round()}%',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: percent,
            minHeight: 6,
            backgroundColor: AppTheme.borderFor(context),
            valueColor: const AlwaysStoppedAnimation<Color>(AppTheme.primary),
          ),
        ),
      ],
    );
  }
}

class _AiSummaryPreview extends StatelessWidget {
  const _AiSummaryPreview({required this.summary});

  final String summary;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.auto_awesome_outlined,
            size: 16,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              summary,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 12,
                height: 1.45,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ModerationNotice extends StatelessWidget {
  const _ModerationNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warning.withValues(alpha: 0.22)),
      ),
      child: Text(
        'This post is flagged for review. Treat the financial claims carefully.',
        style: GoogleFonts.inter(
          color: AppTheme.textSecondaryFor(context),
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _ForumPausedBanner extends StatelessWidget {
  const _ForumPausedBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.pause_circle_outline_rounded,
            color: AppTheme.warning,
            size: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                height: 1.35,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _SafeModeNotice extends StatelessWidget {
  const _SafeModeNotice();

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primary.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.primary.withValues(alpha: 0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: AppTheme.primary, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Safe mode is designed for sensitive money questions. Keep personal account numbers and passwords out of the post.',
              style: GoogleFonts.inter(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  const _GlassPanel({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.glowColor = AppTheme.primary,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color glowColor;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: AppTheme.surfaceFor(context).withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.54)),
            boxShadow: [
              BoxShadow(
                color: glowColor.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.035),
                blurRadius: 14,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _ForumAmbientBackground extends StatelessWidget {
  const _ForumAmbientBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppTheme.backgroundFor(context),
            const Color(0xFFEFF7FF),
            const Color(0xFFF7F4FF),
            AppTheme.backgroundFor(context),
          ],
          stops: const [0, 0.34, 0.68, 1],
        ),
      ),
      child: const SizedBox.expand(),
    );
  }
}

class _PostSkeletonList extends StatelessWidget {
  const _PostSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      separatorBuilder: (context, index) => const SizedBox(height: 12),
      itemBuilder: (context, index) => const _PostCardSkeleton(),
    );
  }
}

class _PostCardSkeleton extends StatelessWidget {
  const _PostCardSkeleton();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surfaceFor(context),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.borderFor(context)),
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _SkeletonBox(width: 90, height: 24),
              SizedBox(width: 8),
              _SkeletonBox(width: 70, height: 24),
            ],
          ),
          SizedBox(height: 16),
          Row(
            children: [
              _SkeletonBox(width: 36, height: 36, radius: 18),
              SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SkeletonBox(width: 130, height: 12),
                  SizedBox(height: 6),
                  _SkeletonBox(width: 82, height: 10),
                ],
              ),
            ],
          ),
          SizedBox(height: 14),
          _SkeletonBox(width: double.infinity, height: 16),
          SizedBox(height: 8),
          _SkeletonBox(width: double.infinity, height: 12),
          SizedBox(height: 6),
          _SkeletonBox(width: 220, height: 12),
        ],
      ),
    );
  }
}

class _CommentSkeletonList extends StatelessWidget {
  const _CommentSkeletonList();

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      separatorBuilder: (context, index) => const SizedBox(height: 10),
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppTheme.surfaceCardFor(context),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppTheme.borderFor(context)),
        ),
        child: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _SkeletonBox(width: 130, height: 12),
            SizedBox(height: 10),
            _SkeletonBox(width: double.infinity, height: 12),
            SizedBox(height: 6),
            _SkeletonBox(width: 180, height: 12),
          ],
        ),
      ),
    );
  }
}

class _SkeletonBox extends StatelessWidget {
  const _SkeletonBox({
    required this.width,
    required this.height,
    this.radius = 6,
  });

  final double width;
  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: AppTheme.borderFor(context),
        borderRadius: BorderRadius.circular(radius),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: AppTheme.primary.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppTheme.primary, size: 38),
            ),
            const SizedBox(height: 14),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textPrimaryFor(context),
                fontSize: 18,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 13,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline_rounded,
              color: AppTheme.error,
              size: 38,
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: GoogleFonts.plusJakartaSans(
                color: AppTheme.textPrimaryFor(context),
                fontSize: 17,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondaryFor(context),
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CatInfo {
  const _CatInfo(this.name, this.icon, this.color, this.subtitle);

  final String name;
  final IconData icon;
  final Color color;
  final String subtitle;
}

Color _reactionColor(ReactionType type) {
  switch (type) {
    case ReactionType.like:
      return AppTheme.primary;
    case ReactionType.helpful:
      return AppTheme.success;
    case ReactionType.inspiring:
      return const Color(0xFFD97706);
    case ReactionType.insightful:
      return const Color(0xFF7C3AED);
  }
}

List<ForumPost> _personalizePosts(
  List<ForumPost> posts,
  _FeedFocus focus,
  String? selectedTag,
) {
  if (focus == _FeedFocus.community) return posts;

  final ranked = List<ForumPost>.from(posts);
  int score(ForumPost post) {
    var value = post.totalReactions + (post.commentsCount * 2);
    if (selectedTag != null && post.tags.contains(selectedTag)) value += 12;
    if (post.tags.any(_starterTag)) value += 8;
    if (post.category == 'Budgeting' || post.category == 'Savings') value += 6;
    if (post.postType == PostType.tip || post.postType == PostType.question) {
      value += 5;
    }
    if (post.hasPinnedAnswer) value += 4;
    return value;
  }

  if (focus == _FeedFocus.beginnerPath) {
    final beginnerPosts = ranked
        .where(
          (post) =>
              post.tags.any(_starterTag) ||
              post.postType == PostType.tip ||
              post.category == 'Budgeting' ||
              post.category == 'Savings',
        )
        .toList();
    if (beginnerPosts.isNotEmpty) {
      beginnerPosts.sort((a, b) => score(b).compareTo(score(a)));
      return beginnerPosts;
    }
  }

  ranked.sort((a, b) => score(b).compareTo(score(a)));
  return ranked;
}

bool _starterTag(String tag) {
  return tag == 'beginner' ||
      tag == 'student' ||
      tag == 'family-budget' ||
      tag == 'emergency-fund' ||
      tag == 'goal-tracking';
}

ForumPost? _topTrendingPost(List<ForumPost> posts) {
  if (posts.isEmpty) return null;
  final ranked = List<ForumPost>.from(posts)
    ..sort(
      (a, b) => (b.totalReactions + b.commentsCount).compareTo(
        a.totalReactions + a.commentsCount,
      ),
    );
  return ranked.first;
}

String _topTag(List<ForumPost> posts) {
  final counts = <String, int>{};
  for (final post in posts) {
    for (final tag in post.tags) {
      counts.update(tag, (value) => value + 1, ifAbsent: () => 1);
    }
  }
  if (counts.isEmpty) return '';
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return entries.first.key;
}

String _forumCopy(_ForumLanguage language, String key) {
  final english = {
    'title': 'Community Forum',
    'feed': 'Feed',
    'topics': 'Topics',
    'heroTitle': 'Learn money together, one decision at a time.',
    'heroSubtitle':
        'AI-ready recommendations, safe community stories, and practical finance paths for students, families, and young professionals.',
    'activeThreads': 'Threads',
    'replies': 'Replies',
    'helpful': 'Helpful',
    'trending': 'Trending discussion',
    'pathBudget': 'Budget Starter Path',
    'pathSavings': 'Savings Momentum',
    'pathInvest': 'Investing Basics',
  };
  final urdu = {
    'title': 'کمیونٹی فورم',
    'feed': 'فیڈ',
    'topics': 'موضوعات',
    'heroTitle': 'مل کر مالی فیصلے بہتر بنائیں۔',
    'heroSubtitle':
        'طلبہ، خاندانوں اور نوجوان پروفیشنلز کے لیے محفوظ گفتگو، AI رہنمائی، اور آسان مالی سیکھنے کے راستے۔',
    'activeThreads': 'گفتگو',
    'replies': 'جوابات',
    'helpful': 'مددگار',
    'trending': 'مقبول گفتگو',
    'pathBudget': 'بجٹ کی شروعات',
    'pathSavings': 'بچت کی رفتار',
    'pathInvest': 'سرمایہ کاری بنیادیات',
  };
  final romanUrdu = {
    'title': 'Community Forum',
    'feed': 'Feed',
    'topics': 'Topics',
    'heroTitle': 'Mil kar paisay ke faislay behtar banayein.',
    'heroSubtitle':
        'Students, families aur young professionals ke liye safe discussions, AI guidance aur simple finance learning paths.',
    'activeThreads': 'Threads',
    'replies': 'Replies',
    'helpful': 'Helpful',
    'trending': 'Trending discussion',
    'pathBudget': 'Budget Starter Path',
    'pathSavings': 'Savings Momentum',
    'pathInvest': 'Investing Basics',
  };

  return switch (language) {
    _ForumLanguage.english => english[key] ?? english['title']!,
    _ForumLanguage.urdu => urdu[key] ?? english[key] ?? english['title']!,
    _ForumLanguage.romanUrdu =>
      romanUrdu[key] ?? english[key] ?? english['title']!,
  };
}

String _feedFocusCopy(_FeedFocus focus, _ForumLanguage language) {
  return switch (language) {
    _ForumLanguage.urdu => switch (focus) {
      _FeedFocus.community => 'کمیونٹی',
      _FeedFocus.aiForYou => 'AI آپ کے لیے',
      _FeedFocus.beginnerPath => 'ابتدائی راستہ',
    },
    _ForumLanguage.romanUrdu => switch (focus) {
      _FeedFocus.community => 'Community',
      _FeedFocus.aiForYou => 'AI Aap ke liye',
      _FeedFocus.beginnerPath => 'Beginner Path',
    },
    _ForumLanguage.english => focus.label,
  };
}

String _coachCopy(_ForumLanguage language, _FeedFocus focus) {
  if (language == _ForumLanguage.urdu) {
    return focus == _FeedFocus.aiForYou
        ? 'AI کوچ آپ کے منتخب موضوعات، بجٹ عادات، اور محفوظ سیکھنے کے اہداف کے مطابق گفتگو ترجیح دے گا۔'
        : 'چھوٹے اقدامات، واضح سوالات، اور مددگار جوابات سے مالی اعتماد بڑھائیں۔';
  }
  if (language == _ForumLanguage.romanUrdu) {
    return focus == _FeedFocus.aiForYou
        ? 'AI coach aap ke topics, budget habits aur goals ke mutabiq discussions ko prioritize karega.'
        : 'Chhote steps, clear sawal aur helpful answers se financial confidence build karein.';
  }
  return focus == _FeedFocus.aiForYou
      ? 'AI coach mode prioritizes posts using your selected interests, budgeting context, goals, and interaction signals.'
      : 'Tiny steps, clear questions, and helpful answers build durable financial confidence.';
}

String _languageCode(_ForumLanguage language) {
  return switch (language) {
    _ForumLanguage.english => 'en',
    _ForumLanguage.urdu => 'ur',
    _ForumLanguage.romanUrdu => 'roman-ur',
  };
}

double _financeProgress(ForumPost post) {
  final raw =
      (post.commentsCount * 11) + (post.totalReactions * 7) + post.title.length;
  return (0.28 + ((raw % 58) / 100)).clamp(0.18, 0.92).toDouble();
}

List<_BreakdownItem> _financeBreakdown(ForumPost post) {
  final seed = post.id.hashCode.abs() + post.title.length;
  final first = 34 + (seed % 28);
  final second = 22 + ((seed ~/ 3) % 24);
  final third = (100 - first - second).clamp(18, 42);

  return [
    _BreakdownItem('Spend', first.toDouble(), AppTheme.primary),
    _BreakdownItem('Save', second.toDouble(), AppTheme.success),
    _BreakdownItem('Grow', third.toDouble(), const Color(0xFF7C3AED)),
  ];
}

String _storyTitle(PostType type) {
  return switch (type) {
    PostType.question => 'Decision map',
    PostType.story => 'Milestone story',
    PostType.tip => 'Learning insight',
    PostType.update => 'Progress signal',
    PostType.poll => 'Community poll',
  };
}

String _formatTime(DateTime? dateTime) {
  if (dateTime == null) return 'just now';
  final diff = DateTime.now().difference(dateTime);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
}
