import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../../models/app_config.dart';
import '../../services/app_config_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_config_gate.dart';

class CommunityForumPage extends StatefulWidget {
  const CommunityForumPage({super.key});

  @override
  State<CommunityForumPage> createState() => _CommunityForumPageState();
}

class _CommunityForumPageState extends State<CommunityForumPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  String _selectedCategory = 'All';

  final _categories = const [
    'All',
    'Savings',
    'Loans',
    'Budgeting',
    'Investing',
    'Success',
    'General',
  ];

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
          backgroundColor: AppTheme.background,
          body: NestedScrollView(
            headerSliverBuilder: (context, innerBoxIsScrolled) => [
              SliverAppBar(
                pinned: true,
                backgroundColor: AppTheme.background,
                elevation: 0,
                title: Text(
                  'Community Forum',
                  style: GoogleFonts.plusJakartaSans(
                    fontWeight: FontWeight.w800,
                    fontSize: 22,
                    color: AppTheme.textPrimary,
                  ),
                ),
                bottom: TabBar(
                  controller: _tabController,
                  labelColor: AppTheme.primary,
                  unselectedLabelColor: AppTheme.textSecondary,
                  indicatorColor: AppTheme.primary,
                  labelStyle: GoogleFonts.inter(
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                  tabs: const [
                    Tab(text: 'Discussions'),
                    Tab(text: 'Categories'),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: _CategoryFilter(
                  categories: _categories,
                  selected: _selectedCategory,
                  onSelect: (value) =>
                      setState(() => _selectedCategory = value),
                ),
              ),
            ],
            body: TabBarView(
              controller: _tabController,
              children: [
                _PostsList(
                  category: _selectedCategory,
                  commentsEnabled: config.forumCommentsEnabled,
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
          floatingActionButton: FloatingActionButton.extended(
            onPressed: config.forumPostingEnabled
                ? () => _showCreatePostSheet(context)
                : () => _showPausedSnack(config.supportMessage),
            backgroundColor: config.forumPostingEnabled
                ? AppTheme.primary
                : AppTheme.textHint,
            icon: const Icon(Icons.edit_rounded, color: Colors.white),
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
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CreatePostSheet(db: _db),
    );
  }

  void _showPausedSnack(String message) {
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.categories,
    required this.selected,
    required this.onSelect,
  });

  final List<String> categories;
  final String selected;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 52,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (_, index) {
          final category = categories[index];
          final isSelected = selected == category;
          return GestureDetector(
            onTap: () => onSelect(category),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isSelected ? AppTheme.primary : AppTheme.surface,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isSelected ? AppTheme.primary : AppTheme.border,
                ),
              ),
              child: Text(
                category,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PostsList extends StatelessWidget {
  const _PostsList({required this.category, required this.commentsEnabled});

  final String category;
  final bool commentsEnabled;

  @override
  Widget build(BuildContext context) {
    Query<Map<String, dynamic>> query = FirebaseFirestore.instance
        .collection('forum_posts')
        .orderBy('createdAt', descending: true);

    if (category != 'All') {
      query = query.where('category', isEqualTo: category);
    }

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = (snapshot.data?.docs ?? [])
            .where((doc) => doc.data()['moderationStatus'] != 'removed')
            .toList();
        if (docs.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.forum_outlined,
                  size: 56,
                  color: AppTheme.textHint,
                ),
                const SizedBox(height: 12),
                Text(
                  'No posts yet. Start the first conversation.',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.all(20),
          itemCount: docs.length,
          separatorBuilder: (context, index) => const SizedBox(height: 12),
          itemBuilder: (context, index) {
            return _PostCard(
              docId: docs[index].id,
              data: docs[index].data(),
              commentsEnabled: commentsEnabled,
            );
          },
        );
      },
    );
  }
}

class _PostCard extends StatefulWidget {
  const _PostCard({
    required this.docId,
    required this.data,
    required this.commentsEnabled,
  });

  final String docId;
  final Map<String, dynamic> data;
  final bool commentsEnabled;

  @override
  State<_PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<_PostCard> {
  static const Map<String, Color> _tagColors = {
    'Savings': Color(0xFF06C270),
    'Loans': Color(0xFF2E3192),
    'Budgeting': Color(0xFF0EA5A4),
    'Investing': Color(0xFF8B5CF6),
    'Success': Color(0xFFFF6B35),
    'General': Color(0xFF6B7A99),
  };

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final firestoreService = authService.firestoreService;
    final user = authService.user;
    final data = widget.data;
    final category = data['category'] ?? 'General';
    final tagColor = _tagColors[category] ?? AppTheme.primary;
    final likes = data['likes'] ?? 0;
    final comments = data['comments'] ?? 0;
    final avatar = data['authorAvatar'] as String?;
    final savedDoc = user == null
        ? null
        : FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .collection('saved_posts')
              .doc(widget.docId);

    return StreamBuilder<bool>(
      stream: firestoreService?.isForumPostLiked(widget.docId),
      initialData: false,
      builder: (context, likedSnapshot) {
        final isLiked = likedSnapshot.data ?? false;

        return Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: AppTheme.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.border),
            boxShadow: AppTheme.softShadow,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppTheme.primary.withValues(alpha: 0.15),
                    backgroundImage: (avatar != null && avatar.isNotEmpty)
                        ? NetworkImage(avatar)
                        : null,
                    child: (avatar == null || avatar.isEmpty)
                        ? Text(
                            (data['authorName'] ?? 'A')[0].toUpperCase(),
                            style: GoogleFonts.inter(
                              fontWeight: FontWeight.w700,
                              color: AppTheme.primary,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          data['authorName'] ?? 'Anonymous',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: AppTheme.textPrimary,
                          ),
                        ),
                        Text(
                          _timeAgo(data['createdAt']),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: tagColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      category,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: tagColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                data['title'] ?? '',
                style: GoogleFonts.plusJakartaSans(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: AppTheme.textPrimary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                data['content'] ?? '',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: AppTheme.textSecondary,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: AppTheme.border, thickness: 1, height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    onTap: firestoreService == null
                        ? null
                        : () => firestoreService.toggleForumLike(
                            widget.docId,
                            !isLiked,
                          ),
                    child: Row(
                      children: [
                        Icon(
                          isLiked
                              ? Icons.thumb_up_rounded
                              : Icons.thumb_up_outlined,
                          size: 18,
                          color: isLiked
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$likes',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: isLiked
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  GestureDetector(
                    onTap: () => _openComments(context),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.chat_bubble_outline_rounded,
                          size: 18,
                          color: AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$comments',
                          style: GoogleFonts.inter(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppTheme.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Spacer(),
                  if (savedDoc != null) ...[
                    StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                      stream: savedDoc.snapshots(),
                      builder: (context, snapshot) {
                        final isSaved = snapshot.data?.exists ?? false;
                        return IconButton(
                          onPressed: () => _toggleSave(savedDoc, isSaved),
                          icon: Icon(
                            isSaved
                                ? Icons.bookmark_rounded
                                : Icons.bookmark_border_rounded,
                            color: isSaved
                                ? AppTheme.primary
                                : AppTheme.textSecondary,
                          ),
                        );
                      },
                    ),
                  ],
                ],
              ),
            ],
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
      'postId': widget.docId,
      'savedAt': FieldValue.serverTimestamp(),
    });
  }

  void _openComments(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _CommentsSheet(
        postId: widget.docId,
        postTitle: widget.data['title'] ?? 'Discussion',
        commentsEnabled: widget.commentsEnabled,
      ),
    );
  }

  String _timeAgo(dynamic ts) {
    if (ts is! Timestamp) {
      return 'just now';
    }
    final diff = DateTime.now().difference(ts.toDate());
    if (diff.inMinutes < 1) {
      return 'just now';
    }
    if (diff.inMinutes < 60) {
      return '${diff.inMinutes}m ago';
    }
    if (diff.inHours < 24) {
      return '${diff.inHours}h ago';
    }
    return '${diff.inDays}d ago';
  }
}

class _CommentsSheet extends StatefulWidget {
  const _CommentsSheet({
    required this.postId,
    required this.postTitle,
    required this.commentsEnabled,
  });

  final String postId;
  final String postTitle;
  final bool commentsEnabled;

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _commentController = TextEditingController();
  bool _sending = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final authService = context.watch<AuthService>();
    final user = authService.user;
    final commentsQuery = FirebaseFirestore.instance
        .collection('forum_posts')
        .doc(widget.postId)
        .collection('comments')
        .orderBy('createdAt');

    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(20, 20, 20, bottomInset + 20),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.75,
        child: Column(
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
              widget.postTitle,
              style: GoogleFonts.plusJakartaSans(
                fontSize: 20,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: commentsQuery.snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return Center(
                      child: Text(
                        'No comments yet. Add the first one.',
                        style: GoogleFonts.inter(color: AppTheme.textSecondary),
                      ),
                    );
                  }
                  return ListView.separated(
                    itemCount: docs.length,
                    separatorBuilder: (context, index) =>
                        const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final data = docs[index].data();
                      return Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AppTheme.surfaceCard,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              data['authorName'] ?? 'FinEase User',
                              style: GoogleFonts.inter(
                                fontWeight: FontWeight.w700,
                                color: AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              data['content'] ?? '',
                              style: GoogleFonts.inter(
                                color: AppTheme.textSecondary,
                                height: 1.5,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            const SizedBox(height: 12),
            if (!widget.commentsEnabled) ...[
              _ForumPausedBanner(
                message:
                    'Commenting is paused by FinEase admin. Existing comments remain visible.',
              ),
              const SizedBox(height: 12),
            ],
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    enabled: widget.commentsEnabled,
                    maxLines: 3,
                    minLines: 1,
                    decoration: const InputDecoration(
                      hintText: 'Write a comment',
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                ElevatedButton(
                  onPressed: user == null || _sending || !widget.commentsEnabled
                      ? null
                      : _submitComment,
                  child: Text(_sending ? '...' : 'Send'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _submitComment() async {
    if (!widget.commentsEnabled) {
      return;
    }
    final authService = context.read<AuthService>();
    final user = authService.user;
    final content = _commentController.text.trim();
    if (user == null || content.isEmpty) {
      return;
    }

    setState(() => _sending = true);
    final postRef = FirebaseFirestore.instance
        .collection('forum_posts')
        .doc(widget.postId);

    await postRef.collection('comments').add({
      'content': content,
      'authorName': user.displayName ?? user.email ?? 'FinEase User',
      'authorId': user.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await postRef.update({'comments': FieldValue.increment(1)});

    if (mounted) {
      _commentController.clear();
      setState(() => _sending = false);
    }
  }
}

class _ForumPausedBanner extends StatelessWidget {
  const _ForumPausedBanner({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFBEB),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFDE68A)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.pause_circle_outline_rounded,
            color: AppTheme.warning,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: GoogleFonts.inter(
                color: AppTheme.textSecondary,
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

class _CategoriesGrid extends StatelessWidget {
  const _CategoriesGrid({required this.onCategoryTap});

  final ValueChanged<String> onCategoryTap;

  static const _categories = [
    _CatInfo(
      'Savings',
      Icons.savings_rounded,
      Color(0xFF06C270),
      'Build saving habits and emergency funds',
    ),
    _CatInfo(
      'Loans',
      Icons.account_balance_rounded,
      Color(0xFF2E3192),
      'Borrow carefully and manage repayments',
    ),
    _CatInfo(
      'Budgeting',
      Icons.account_balance_wallet_rounded,
      Color(0xFF0EA5A4),
      'Monthly plans, category caps, and spending control',
    ),
    _CatInfo(
      'Investing',
      Icons.trending_up_rounded,
      Color(0xFF8B5CF6),
      'Long-term growth and risk basics',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      padding: const EdgeInsets.all(20),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.1,
      children: _categories
          .map(
            (category) => GestureDetector(
              onTap: () => onCategoryTap(category.name),
              child: Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AppTheme.border),
                  boxShadow: AppTheme.softShadow,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: category.color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(category.icon, color: category.color),
                    ),
                    const Spacer(),
                    Text(
                      category.name,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w700,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      category.subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: AppTheme.textSecondary,
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

class _CatInfo {
  const _CatInfo(this.name, this.icon, this.color, this.subtitle);

  final String name;
  final IconData icon;
  final Color color;
  final String subtitle;
}

class _CreatePostSheet extends StatefulWidget {
  const _CreatePostSheet({required this.db});

  final FirebaseFirestore db;

  @override
  State<_CreatePostSheet> createState() => _CreatePostSheetState();
}

class _CreatePostSheetState extends State<_CreatePostSheet> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _contentController = TextEditingController();
  String _category = 'General';
  bool _posting = false;

  final _categories = const [
    'General',
    'Savings',
    'Loans',
    'Budgeting',
    'Investing',
    'Success',
  ];

  @override
  void dispose() {
    _titleController.dispose();
    _contentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      padding: EdgeInsets.fromLTRB(24, 16, 24, bottomInset + 24),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Start a Discussion',
            style: GoogleFonts.plusJakartaSans(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          const SizedBox(height: 20),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(hintText: 'Post title'),
          ),
          const SizedBox(height: 14),
          TextField(
            controller: _contentController,
            maxLines: 4,
            decoration: const InputDecoration(
              hintText: 'Share your question, tip, or experience...',
            ),
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _categories.map((category) {
              final isSelected = _category == category;
              return GestureDetector(
                onTap: () => setState(() => _category = category),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isSelected ? AppTheme.primary : AppTheme.surface,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isSelected ? AppTheme.primary : AppTheme.border,
                    ),
                  ),
                  child: Text(
                    category,
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSelected ? Colors.white : AppTheme.textSecondary,
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _posting ? null : _post,
              child: Text(_posting ? 'Publishing...' : 'Publish'),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _post() async {
    if (_titleController.text.trim().isEmpty ||
        _contentController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill in all fields')),
      );
      return;
    }

    setState(() => _posting = true);
    final authService = context.read<AuthService>();
    final user = authService.user;

    await widget.db.collection('forum_posts').add({
      'title': _titleController.text.trim(),
      'content': _contentController.text.trim(),
      'category': _category,
      'authorName': user?.displayName ?? user?.email ?? 'FinEase User',
      'authorAvatar': user?.photoURL ?? '',
      'authorId': user?.uid ?? '',
      'likes': 0,
      'comments': 0,
      'createdAt': FieldValue.serverTimestamp(),
    });

    if (mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Discussion posted.')));
    }
  }
}
