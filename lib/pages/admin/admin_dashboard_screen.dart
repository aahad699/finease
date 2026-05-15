import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../app_constants.dart';
import '../../models/app_config.dart';
import '../../services/app_config_service.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/app_config_gate.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  static const List<_AdminTab> _tabs = [
    _AdminTab('Overview', Icons.dashboard_rounded),
    _AdminTab('Users', Icons.manage_accounts_rounded),
    _AdminTab('Forum', Icons.forum_rounded),
    _AdminTab('Partners', Icons.handshake_rounded),
    _AdminTab('Welfare', Icons.volunteer_activism_rounded),
    _AdminTab('App', Icons.tune_rounded),
    _AdminTab('Reports', Icons.analytics_rounded),
  ];

  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final TextEditingController _searchController = TextEditingController();
  final DateFormat _dateFormat = DateFormat('MMM d, yyyy - h:mm a');
  final DateFormat _shortDateFormat = DateFormat('MMM d, h:mm a');

  int _tabIndex = 0;
  bool _busy = false;
  String _search = '';
  String _userFilter = 'All';
  String _forumFilter = 'All';
  String _partnerFilter = 'All';
  String _welfareFilter = 'All';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= 980;
        return Scaffold(
          backgroundColor: AppTheme.background,
          body: SafeArea(
            child: isWide
                ? Row(
                    children: [
                      _AdminSideRail(
                        tabs: _tabs,
                        selectedIndex: _tabIndex,
                        onSelected: _selectTab,
                        onCopyReport: _copyReport,
                        onSeed: _seedAdminSamples,
                        onSignOut: () => context.read<AuthService>().signOut(),
                      ),
                      const VerticalDivider(width: 1, color: AppTheme.border),
                      Expanded(child: _contentArea(isWide: true)),
                    ],
                  )
                : Column(
                    children: [
                      _mobileHeader(),
                      Expanded(child: _contentArea(isWide: false)),
                    ],
                  ),
          ),
          floatingActionButton: _buildFab(),
        );
      },
    );
  }

  Widget _contentArea({required bool isWide}) {
    return Column(
      children: [
        if (isWide) _desktopHeader(),
        if (_busy) const LinearProgressIndicator(minHeight: 2),
        Expanded(child: _buildTab()),
      ],
    );
  }

  Widget _desktopHeader() {
    final tab = _tabs[_tabIndex];
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 16),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: AppTheme.border)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppTheme.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(tab.icon, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${tab.label} Console',
                  style: GoogleFonts.plusJakartaSans(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppTheme.textPrimary,
                  ),
                ),
                Text(
                  'Signed in as ${AppConstants.adminEmail}',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          _ghostButton('Seed', Icons.auto_fix_high_rounded, _seedAdminSamples),
          const SizedBox(width: 8),
          _ghostButton('Report', Icons.file_copy_rounded, _copyReport),
          const SizedBox(width: 8),
          IconButton.filled(
            tooltip: 'Sign out',
            style: IconButton.styleFrom(
              backgroundColor: AppTheme.primary.withValues(alpha: 0.08),
              foregroundColor: AppTheme.primary,
            ),
            onPressed: () => context.read<AuthService>().signOut(),
            icon: const Icon(Icons.logout_rounded),
          ),
        ],
      ),
    );
  }

  Widget _mobileHeader() {
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.cardGradient),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
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
                      'Admin Dashboard',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      AppConstants.adminEmail,
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.76),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Seed review samples',
                onPressed: _seedAdminSamples,
                icon: const Icon(Icons.auto_fix_high_rounded),
                color: Colors.white,
              ),
              IconButton(
                tooltip: 'Copy report',
                onPressed: _copyReport,
                icon: const Icon(Icons.file_copy_rounded),
                color: Colors.white,
              ),
              IconButton(
                tooltip: 'Sign out',
                onPressed: () => context.read<AuthService>().signOut(),
                icon: const Icon(Icons.logout_rounded),
                color: Colors.white,
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: _tabs.length,
              separatorBuilder: (_, index) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final tab = _tabs[index];
                final selected = index == _tabIndex;
                return ChoiceChip(
                  selected: selected,
                  selectedColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.14),
                  side: BorderSide(
                    color: Colors.white.withValues(alpha: selected ? 1 : 0.28),
                  ),
                  avatar: Icon(
                    tab.icon,
                    size: 17,
                    color: selected ? AppTheme.primary : Colors.white,
                  ),
                  label: Text(tab.label),
                  labelStyle: GoogleFonts.inter(
                    color: selected ? AppTheme.primary : Colors.white,
                    fontWeight: FontWeight.w800,
                  ),
                  onSelected: (_) => _selectTab(index),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTab() {
    switch (_tabIndex) {
      case 1:
        return _usersTab();
      case 2:
        return _forumTab();
      case 3:
        return _partnersTab();
      case 4:
        return _welfareTab();
      case 5:
        return _appControlsTab();
      case 6:
        return _reportsTab();
      default:
        return _overviewTab();
    }
  }

  Widget? _buildFab() {
    if (_tabIndex == 3) {
      return FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_business_rounded),
        label: const Text('Partner'),
        onPressed: () => _showPartnerDialog(),
      );
    }
    if (_tabIndex == 4) {
      return FloatingActionButton.extended(
        backgroundColor: AppTheme.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_task_rounded),
        label: const Text('Case'),
        onPressed: () => _showWelfareDialog(),
      );
    }
    return null;
  }

  Widget _overviewTab() {
    return _Stream4(
      users: _db.collection('users').snapshots(),
      posts: _db.collection('forum_posts').snapshots(),
      partners: _db.collection('marketplace_partners').snapshots(),
      welfare: _db.collection('welfare_applications').snapshots(),
      builder: (context, users, posts, partners, welfare) {
        final stats = _AdminStats.from(
          users: users.docs,
          posts: posts.docs,
          partners: partners.docs,
          welfare: welfare.docs,
        );
        final queue = _reviewQueueItems(
          posts: posts.docs,
          partners: partners.docs,
          welfare: welfare.docs,
        );

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
          children: [
            _overviewHero(stats),
            const SizedBox(height: 16),
            _MetricGrid(
              items: [
                _MetricItem(
                  label: 'Users',
                  value: '${stats.users}',
                  detail: '${stats.suspendedUsers} suspended',
                  icon: Icons.people_rounded,
                  color: AppTheme.primary,
                  progress: stats.userHealth,
                ),
                _MetricItem(
                  label: 'Forum',
                  value: '${stats.forumPosts}',
                  detail: '${stats.flaggedPosts} flagged',
                  icon: Icons.forum_rounded,
                  color: AppTheme.warning,
                  progress: stats.forumHealth,
                ),
                _MetricItem(
                  label: 'Partners',
                  value: '${stats.activePartners}',
                  detail: '${stats.partners} total',
                  icon: Icons.handshake_rounded,
                  color: AppTheme.success,
                  progress: stats.partnerHealth,
                ),
                _MetricItem(
                  label: 'Welfare',
                  value: '${stats.pendingCases}',
                  detail: '${stats.welfareCases} cases',
                  icon: Icons.volunteer_activism_rounded,
                  color: AppTheme.error,
                  progress: stats.welfarePressure,
                ),
              ],
            ),
            const SizedBox(height: 16),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final primary = Column(
                  children: [
                    _Panel(
                      title: 'Operations Load',
                      subtitle: 'Live count across admin-owned workflows',
                      icon: Icons.stacked_bar_chart_rounded,
                      action: _StatusPill(
                        text: stats.reviewLoad == 0
                            ? 'Clear'
                            : '${stats.reviewLoad} reviews',
                        color: stats.reviewLoad == 0
                            ? AppTheme.success
                            : AppTheme.warning,
                      ),
                      child: _OperationsBarChart(stats: stats),
                    ),
                    const SizedBox(height: 14),
                    _ReviewQueuePanel(items: queue),
                  ],
                );
                final secondary = Column(
                  children: [
                    _metricsEditor(),
                    const SizedBox(height: 14),
                    _Panel(
                      title: 'Command Center',
                      subtitle: 'Fast paths for the most common admin work',
                      icon: Icons.bolt_rounded,
                      child: _ActionGrid(
                        actions: [
                          _AdminAction(
                            'Review users',
                            Icons.manage_accounts_rounded,
                            () => _selectTab(1),
                          ),
                          _AdminAction(
                            'Moderate forum',
                            Icons.shield_rounded,
                            () => _selectTab(2),
                          ),
                          _AdminAction(
                            'Approve partners',
                            Icons.verified_rounded,
                            () => _selectTab(3),
                          ),
                          _AdminAction(
                            'Welfare queue',
                            Icons.volunteer_activism_rounded,
                            () => _selectTab(4),
                          ),
                          _AdminAction(
                            'Manage app',
                            Icons.tune_rounded,
                            () => _selectTab(5),
                          ),
                          _AdminAction(
                            'Copy report',
                            Icons.file_copy_rounded,
                            _copyReport,
                          ),
                          _AdminAction(
                            'Seed samples',
                            Icons.auto_fix_high_rounded,
                            _seedAdminSamples,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),
                    _recentActivity(posts.docs),
                  ],
                );

                if (!wide) {
                  return Column(
                    children: [primary, const SizedBox(height: 14), secondary],
                  );
                }

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 7, child: primary),
                    const SizedBox(width: 14),
                    Expanded(flex: 5, child: secondary),
                  ],
                );
              },
            ),
          ],
        );
      },
    );
  }

  Widget _overviewHero(_AdminStats stats) {
    final riskColor = stats.reviewLoad > 12
        ? AppTheme.error
        : stats.reviewLoad > 0
        ? AppTheme.warning
        : AppTheme.success;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(8),
        boxShadow: AppTheme.cardShadow,
      ),
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
                    Text(
                      'FinEase Operations',
                      style: GoogleFonts.plusJakartaSans(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'One console for users, moderation, partners, welfare reviews, and reporting.',
                      style: GoogleFonts.inter(
                        color: Colors.white.withValues(alpha: 0.82),
                        height: 1.45,
                      ),
                    ),
                  ],
                ),
              ),
              _StatusPill(
                text: stats.reviewLoad == 0 ? 'Stable' : 'Action needed',
                color: riskColor,
                onDark: true,
              ),
            ],
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _heroSignal(
                'Review load',
                '${stats.reviewLoad}',
                Icons.rate_review_rounded,
              ),
              _heroSignal(
                'Verified users',
                '${stats.verifiedUsers}',
                Icons.verified_user_rounded,
              ),
              _heroSignal(
                'Urgent cases',
                '${stats.urgentCases}',
                Icons.priority_high_rounded,
              ),
              _heroSignal(
                'Last refresh',
                DateFormat('h:mm a').format(DateTime.now()),
                Icons.sync_rounded,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroSignal(String label, String value, IconData icon) {
    return Container(
      width: 162,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      child: Row(
        children: [
          Icon(icon, color: Colors.white, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.plusJakartaSans(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18,
                  ),
                ),
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metricsEditor() {
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: _db.collection('system_metrics').doc('overview').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(message: '${snapshot.error}');
        }
        final data = snapshot.data?.data() ?? {};
        final activeUsers = _intValue(data['activeUsers']);
        final latency = _intValue(data['latencyMs']);
        final pending = _intValue(data['pendingWelfare']);
        final urgent = _intValue(data['urgentReviews']);
        final latencyColor = latency <= 100 ? AppTheme.success : AppTheme.error;
        final urgentColor = urgent <= 5 ? AppTheme.success : AppTheme.warning;

        return _Panel(
          title: 'System Health',
          subtitle: 'Editable operational indicators',
          icon: Icons.monitor_heart_rounded,
          action: TextButton.icon(
            onPressed: () => _showMetricsDialog(data),
            icon: const Icon(Icons.tune_rounded, size: 18),
            label: const Text('Edit'),
          ),
          child: Column(
            children: [
              _HealthRow(
                label: 'Active users',
                value: NumberFormat.compact().format(activeUsers),
                icon: Icons.people_alt_rounded,
                color: AppTheme.primary,
                progress: (activeUsers / 15000).clamp(0, 1).toDouble(),
              ),
              const SizedBox(height: 12),
              _HealthRow(
                label: 'Latency',
                value: '${latency}ms',
                icon: Icons.speed_rounded,
                color: latencyColor,
                progress: (latency / 250).clamp(0, 1).toDouble(),
              ),
              const SizedBox(height: 12),
              _HealthRow(
                label: 'Pending welfare',
                value: '$pending',
                icon: Icons.assignment_late_rounded,
                color: AppTheme.warning,
                progress: (pending / 80).clamp(0, 1).toDouble(),
              ),
              const SizedBox(height: 12),
              _HealthRow(
                label: 'Urgent reviews',
                value: '$urgent',
                icon: Icons.priority_high_rounded,
                color: urgentColor,
                progress: (urgent / 25).clamp(0, 1).toDouble(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _recentActivity(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> posts,
  ) {
    final recent = posts.take(4).toList();
    return _Panel(
      title: 'Recent Activity',
      subtitle: recent.isEmpty
          ? 'No recent forum activity'
          : 'Latest forum posts',
      icon: Icons.history_rounded,
      child: recent.isEmpty
          ? const _EmbeddedEmpty(
              icon: Icons.history_toggle_off_rounded,
              title: 'No activity yet',
              message: 'Forum posts will appear here as they arrive.',
            )
          : Column(
              children: recent.map((doc) {
                final data = doc.data();
                final status = _field(data, 'moderationStatus', 'visible');
                return _MiniActivity(
                  icon: Icons.forum_rounded,
                  title: _field(data, 'title', 'Forum discussion'),
                  subtitle:
                      '${_field(data, 'category', 'General')} by ${_field(data, 'authorName', 'User')}',
                  status: status,
                  color: _statusColor(status),
                );
              }).toList(),
            ),
    );
  }

  Widget _usersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db.collection('users').orderBy('email').snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(message: '${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _LoadingView(label: 'Loading users');
        }

        final docs = snapshot.data?.docs ?? [];
        final stats = _UserTabStats.from(docs);
        final users = docs
            .where(_matchesSearch)
            .where((doc) => _matchesUserFilter(doc.data()))
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
          children: [
            _tabSummary(
              title: 'User Command Center',
              subtitle:
                  'Search Firestore profiles, sync Firebase Auth users, edit roles, and queue sign-in controls.',
              icon: Icons.manage_accounts_rounded,
              items: [
                _SummaryItem('Total', '${stats.total}', AppTheme.primary),
                _SummaryItem('Active', '${stats.active}', AppTheme.success),
                _SummaryItem('Suspended', '${stats.suspended}', AppTheme.error),
                _SummaryItem('Verified', '${stats.verified}', AppTheme.warning),
                _SummaryItem(
                  'Auth synced',
                  '${stats.authSynced}',
                  AppTheme.primary,
                ),
                _SummaryItem(
                  'Auth disabled',
                  '${stats.authDisabled}',
                  AppTheme.error,
                ),
              ],
              action: _ghostButton(
                'Sync Firebase Auth',
                Icons.cloud_sync_rounded,
                _requestFirebaseAuthSync,
              ),
            ),
            const SizedBox(height: 12),
            _filterBar(
              hint: 'Search users by name, email, role, or country',
              selected: _userFilter,
              filters: const [
                'All',
                'Active',
                'Suspended',
                'Disabled',
                'Admin',
                'Demo',
              ],
              onSelected: (value) => setState(() => _userFilter = value),
            ),
            const SizedBox(height: 12),
            if (users.isEmpty)
              const _EmbeddedEmpty(
                icon: Icons.people_outline_rounded,
                title: 'No users found',
                message: 'Try a different search or status filter.',
              )
            else
              ...users.map(_userCard),
          ],
        );
      },
    );
  }

  Widget _userCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final status = _field(data, 'accountStatus', 'active');
    final role = _field(data, 'role', 'user');
    final email = _field(data, 'email', 'No email');
    final fullName = _field(data, 'fullName', email);
    final isAdminEmail = email == AppConstants.adminEmail;
    final authDisabled = data['authDisabled'] == true;

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _InfoCard(
        icon: isAdminEmail
            ? Icons.admin_panel_settings_rounded
            : Icons.person_rounded,
        title: fullName,
        subtitle: email,
        status: isAdminEmail
            ? 'protected'
            : authDisabled
            ? 'auth disabled'
            : status,
        statusColor: isAdminEmail
            ? AppTheme.primary
            : authDisabled
            ? AppTheme.error
            : _statusColor(status),
        metadata: [
          _InfoMeta(Icons.badge_rounded, 'Role: $role'),
          _InfoMeta(Icons.fingerprint_rounded, 'UID: ${doc.id}'),
          _InfoMeta(
            Icons.verified_user_rounded,
            (data['emailVerified'] == true) ? 'Verified' : 'Unverified',
          ),
          _InfoMeta(
            Icons.cloud_done_rounded,
            data['authSyncedAt'] == null
                ? 'Firestore profile'
                : 'Auth synced ${_formatAnyDate(data['authSyncedAt'])}',
          ),
          _InfoMeta(
            Icons.calendar_month_rounded,
            _formatAnyDate(data['createdAt']),
          ),
        ],
        actions: [
          if (!isAdminEmail)
            _smallButton(
              status == 'suspended' ? 'Activate' : 'Suspend',
              status == 'suspended'
                  ? Icons.check_circle_rounded
                  : Icons.block_rounded,
              () => _setUserStatus(
                doc.id,
                status == 'suspended' ? 'active' : 'suspended',
                email: email,
              ),
            ),
          _smallButton('Edit', Icons.edit_rounded, () => _showUserEditor(doc)),
          if (!isAdminEmail)
            _smallButton(
              authDisabled ? 'Enable sign-in' : 'Disable sign-in',
              authDisabled ? Icons.lock_open_rounded : Icons.lock_rounded,
              () => _requestUserAuthDisabled(doc, !authDisabled),
            ),
          _smallButton(
            'Copy email',
            Icons.copy_rounded,
            () => _copyText(email, 'Email copied.'),
          ),
          _smallButton(
            'Details',
            Icons.badge_rounded,
            () => _showDocumentDetails(
              title: fullName,
              subtitle: email,
              path: 'users/${doc.id}',
              icon: Icons.person_rounded,
              data: data,
            ),
          ),
        ],
      ),
    );
  }

  Widget _forumTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('forum_posts')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(message: '${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _LoadingView(label: 'Loading forum posts');
        }

        final docs = snapshot.data?.docs ?? [];
        final flagged = docs
            .where((doc) => doc.data()['moderationStatus'] == 'flagged')
            .length;
        final removed = docs
            .where((doc) => doc.data()['moderationStatus'] == 'removed')
            .length;
        final posts = docs
            .where(_matchesSearch)
            .where(
              (doc) => _matchesStatusFilter(
                _field(doc.data(), 'moderationStatus', 'visible'),
                _forumFilter,
              ),
            )
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
          children: [
            _tabSummary(
              title: 'Forum Moderation',
              subtitle:
                  'Keep public conversations useful, safe, and visible only when they should be.',
              icon: Icons.forum_rounded,
              items: [
                _SummaryItem('Posts', '${docs.length}', AppTheme.primary),
                _SummaryItem('Flagged', '$flagged', AppTheme.warning),
                _SummaryItem('Removed', '$removed', AppTheme.error),
              ],
            ),
            const SizedBox(height: 12),
            _filterBar(
              hint: 'Search title, content, category, or author',
              selected: _forumFilter,
              filters: const ['All', 'Visible', 'Flagged', 'Removed'],
              onSelected: (value) => setState(() => _forumFilter = value),
            ),
            const SizedBox(height: 12),
            if (posts.isEmpty)
              const _EmbeddedEmpty(
                icon: Icons.forum_outlined,
                title: 'No posts found',
                message: 'Moderation results will appear here.',
              )
            else
              ...posts.map(_forumCard),
          ],
        );
      },
    );
  }

  Widget _forumCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final status = _field(data, 'moderationStatus', 'visible');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _InfoCard(
        icon: status == 'removed'
            ? Icons.visibility_off_rounded
            : Icons.forum_rounded,
        title: _field(data, 'title', 'Discussion'),
        subtitle: _field(data, 'content', 'No content'),
        status: status,
        statusColor: _statusColor(status),
        metadata: [
          _InfoMeta(Icons.sell_rounded, _field(data, 'category', 'General')),
          _InfoMeta(Icons.person_rounded, _field(data, 'authorName', 'User')),
          _InfoMeta(
            Icons.favorite_rounded,
            '${_intValue(data['likes'])} likes',
          ),
          _InfoMeta(Icons.schedule_rounded, _formatAnyDate(data['createdAt'])),
        ],
        actions: [
          _smallButton(
            'Flag',
            Icons.flag_rounded,
            () => _setPostStatus(doc.id, 'flagged'),
          ),
          _smallButton(
            'Restore',
            Icons.visibility_rounded,
            () => _setPostStatus(doc.id, 'visible'),
          ),
          _smallButton(
            'Remove',
            Icons.delete_outline_rounded,
            () => _setPostStatus(doc.id, 'removed'),
          ),
          _smallButton(
            'Details',
            Icons.open_in_new_rounded,
            () => _showDocumentDetails(
              title: _field(data, 'title', 'Forum discussion'),
              subtitle: 'forum_posts/${doc.id}',
              path: 'forum_posts/${doc.id}',
              icon: Icons.forum_rounded,
              data: data,
            ),
          ),
        ],
      ),
    );
  }

  Widget _partnersTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('marketplace_partners')
          .orderBy('priority')
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(message: '${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _LoadingView(label: 'Loading partners');
        }

        final docs = snapshot.data?.docs ?? [];
        final active = docs.where((doc) => _isPartnerActive(doc.data())).length;
        final hidden = docs.length - active;
        final unapproved = docs
            .where((doc) => (doc.data()['approved'] ?? true) != true)
            .length;
        final partners = docs
            .where(_matchesSearch)
            .where((doc) => _matchesPartnerFilter(doc.data()))
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
          children: [
            _tabSummary(
              title: 'Partner Marketplace',
              subtitle:
                  'Control which partners are live, approved, and featured for FinEase users.',
              icon: Icons.handshake_rounded,
              items: [
                _SummaryItem('Total', '${docs.length}', AppTheme.primary),
                _SummaryItem('Active', '$active', AppTheme.success),
                _SummaryItem('Hidden', '$hidden', AppTheme.error),
                _SummaryItem('Unapproved', '$unapproved', AppTheme.warning),
              ],
              action: _ghostButton(
                'Add partner',
                Icons.add_business_rounded,
                () => _showPartnerDialog(),
              ),
            ),
            const SizedBox(height: 12),
            _filterBar(
              hint: 'Search partner name, category, badge, or link',
              selected: _partnerFilter,
              filters: const ['All', 'Active', 'Hidden', 'Unapproved'],
              onSelected: (value) => setState(() => _partnerFilter = value),
            ),
            const SizedBox(height: 12),
            if (partners.isEmpty)
              const _EmbeddedEmpty(
                icon: Icons.storefront_outlined,
                title: 'No partners found',
                message: 'Add or adjust a partner to populate this view.',
              )
            else
              ...partners.map(_partnerCard),
          ],
        );
      },
    );
  }

  Widget _partnerCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final active = (data['status'] ?? 'active') == 'active';
    final approved = (data['approved'] ?? true) == true;
    final status = active && approved
        ? 'active'
        : !approved
        ? 'review'
        : 'hidden';
    final priority = _intValue(data['priority'], fallback: 10);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _InfoCard(
        icon: _partnerIcon(data['iconName'] as String?),
        title: _field(data, 'name', 'Partner'),
        subtitle: _field(data, 'description', 'No description configured'),
        status: status,
        statusColor: _statusColor(status),
        metadata: [
          _InfoMeta(
            Icons.category_rounded,
            _field(data, 'category', 'General'),
          ),
          _InfoMeta(Icons.low_priority_rounded, 'Priority $priority'),
          _InfoMeta(
            Icons.verified_rounded,
            approved ? 'Approved' : 'Needs approval',
          ),
          if (_field(data, 'websiteUrl', '').isNotEmpty)
            _InfoMeta(Icons.link_rounded, _field(data, 'websiteUrl', '')),
        ],
        actions: [
          _smallButton(
            'Edit',
            Icons.edit_rounded,
            () => _showPartnerDialog(doc: doc),
          ),
          _smallButton(
            active ? 'Disable' : 'Enable',
            active ? Icons.visibility_off_rounded : Icons.visibility_rounded,
            () => _setPartnerStatus(doc, active ? 'inactive' : 'active'),
          ),
          _smallButton(
            approved ? 'Unapprove' : 'Approve',
            Icons.verified_rounded,
            () => _setPartnerApproval(doc, !approved),
          ),
          _smallButton(
            'Raise',
            Icons.keyboard_arrow_up_rounded,
            () => _adjustPartnerPriority(doc, -1),
          ),
          _smallButton(
            'Lower',
            Icons.keyboard_arrow_down_rounded,
            () => _adjustPartnerPriority(doc, 1),
          ),
        ],
      ),
    );
  }

  Widget _welfareTab() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('welfare_applications')
          .orderBy('createdAt', descending: true)
          .snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(message: '${snapshot.error}');
        }
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return const _LoadingView(label: 'Loading welfare cases');
        }

        final docs = snapshot.data?.docs ?? [];
        final pending = docs
            .where(
              (doc) => _field(doc.data(), 'status', 'pending') == 'pending',
            )
            .length;
        final urgent = docs
            .where(
              (doc) => _field(doc.data(), 'priority', 'normal') == 'urgent',
            )
            .length;
        final resolved = docs
            .where(
              (doc) => _field(doc.data(), 'status', 'pending') == 'resolved',
            )
            .length;
        final cases = docs
            .where(_matchesSearch)
            .where((doc) => _matchesWelfareFilter(doc.data()))
            .toList();

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
          children: [
            _tabSummary(
              title: 'Welfare Review Desk',
              subtitle:
                  'Prioritize support requests, track approvals, and close cases with clear audit history.',
              icon: Icons.volunteer_activism_rounded,
              items: [
                _SummaryItem('Cases', '${docs.length}', AppTheme.primary),
                _SummaryItem('Pending', '$pending', AppTheme.warning),
                _SummaryItem('Urgent', '$urgent', AppTheme.error),
                _SummaryItem('Resolved', '$resolved', AppTheme.success),
              ],
              action: _ghostButton(
                'Add case',
                Icons.add_task_rounded,
                () => _showWelfareDialog(),
              ),
            ),
            const SizedBox(height: 12),
            _filterBar(
              hint: 'Search applicant, program, notes, priority, or status',
              selected: _welfareFilter,
              filters: const [
                'All',
                'Pending',
                'Urgent',
                'Approved',
                'Rejected',
                'Resolved',
              ],
              onSelected: (value) => setState(() => _welfareFilter = value),
            ),
            const SizedBox(height: 12),
            if (cases.isEmpty)
              const _EmbeddedEmpty(
                icon: Icons.assignment_outlined,
                title: 'No welfare cases found',
                message: 'Cases matching your filters will appear here.',
              )
            else
              ...cases.map(_welfareCard),
          ],
        );
      },
    );
  }

  Widget _welfareCard(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final status = _field(data, 'status', 'pending');
    final priority = _field(data, 'priority', 'normal');
    final statusColor = priority == 'urgent' && status == 'pending'
        ? AppTheme.error
        : _statusColor(status);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: _InfoCard(
        icon: Icons.volunteer_activism_rounded,
        title: _field(data, 'applicantName', 'Applicant'),
        subtitle: _field(data, 'notes', 'No notes added'),
        status: priority == 'urgent' && status == 'pending' ? 'urgent' : status,
        statusColor: statusColor,
        metadata: [
          _InfoMeta(
            Icons.assignment_rounded,
            _field(data, 'program', 'Support request'),
          ),
          _InfoMeta(Icons.priority_high_rounded, 'Priority: $priority'),
          _InfoMeta(Icons.schedule_rounded, _formatAnyDate(data['createdAt'])),
          if (data['reviewedAt'] != null)
            _InfoMeta(
              Icons.fact_check_rounded,
              'Reviewed ${_formatAnyDate(data['reviewedAt'])}',
            ),
        ],
        actions: [
          _smallButton(
            'Approve',
            Icons.check_circle_rounded,
            () => _setWelfareStatus(doc.id, 'approved'),
          ),
          _smallButton(
            'Reject',
            Icons.cancel_rounded,
            () => _setWelfareStatus(doc.id, 'rejected'),
          ),
          _smallButton(
            'Resolve',
            Icons.task_alt_rounded,
            () => _setWelfareStatus(doc.id, 'resolved'),
          ),
          _smallButton(
            'Edit',
            Icons.edit_rounded,
            () => _showWelfareDialog(doc: doc),
          ),
          _smallButton(
            'Details',
            Icons.open_in_new_rounded,
            () => _showDocumentDetails(
              title: _field(data, 'applicantName', 'Applicant'),
              subtitle: 'welfare_applications/${doc.id}',
              path: 'welfare_applications/${doc.id}',
              icon: Icons.volunteer_activism_rounded,
              data: data,
            ),
          ),
        ],
      ),
    );
  }

  Widget _appControlsTab() {
    return StreamBuilder<AppConfig>(
      stream: AppConfigService().watchConfig(),
      initialData: AppConfig.defaults(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return _ErrorPanel(message: '${snapshot.error}');
        }

        final config = snapshot.data ?? AppConfig.defaults();
        final communityLive =
            config.forumEnabled &&
            config.forumPostingEnabled &&
            config.forumCommentsEnabled;
        final aiLive = config.chatbotEnabled && config.budgetAiEnabled;
        final marketLive = config.marketplaceEnabled && config.welfareEnabled;

        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
          children: [
            _tabSummary(
              title: 'App Control Room',
              subtitle:
                  'These controls write to Firestore and change what users can access in the live app.',
              icon: Icons.tune_rounded,
              items: [
                _SummaryItem(
                  'App mode',
                  config.maintenanceMode ? 'Maintenance' : 'Live',
                  config.maintenanceMode ? AppTheme.error : AppTheme.success,
                ),
                _SummaryItem(
                  'Announcement',
                  config.announcementEnabled ? 'On' : 'Off',
                  config.announcementEnabled
                      ? AppTheme.warning
                      : AppTheme.textSecondary,
                ),
                _SummaryItem(
                  'Community',
                  communityLive ? 'Open' : 'Limited',
                  communityLive ? AppTheme.success : AppTheme.warning,
                ),
                _SummaryItem(
                  'AI tools',
                  aiLive ? 'Open' : 'Limited',
                  aiLive ? AppTheme.success : AppTheme.warning,
                ),
                _SummaryItem(
                  'Discovery',
                  marketLive ? 'Open' : 'Limited',
                  marketLive ? AppTheme.success : AppTheme.warning,
                ),
              ],
              action: _ghostButton(
                'Reset defaults',
                Icons.restore_rounded,
                () => _saveAppConfig(
                  AppConfig.defaults(),
                  'App controls reset to defaults.',
                ),
              ),
            ),
            const SizedBox(height: 14),
            _AppConfigEditor(
              config: config,
              onSave: (nextConfig) =>
                  _saveAppConfig(nextConfig, 'App controls saved.'),
            ),
          ],
        );
      },
    );
  }

  Widget _reportsTab() {
    return _Stream4(
      users: _db.collection('users').snapshots(),
      posts: _db.collection('forum_posts').snapshots(),
      partners: _db.collection('marketplace_partners').snapshots(),
      welfare: _db.collection('welfare_applications').snapshots(),
      builder: (context, users, posts, partners, welfare) {
        final stats = _AdminStats.from(
          users: users.docs,
          posts: posts.docs,
          partners: partners.docs,
          welfare: welfare.docs,
        );
        return ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 96),
          children: [
            _tabSummary(
              title: 'Reports and Audit',
              subtitle:
                  'Generate operational snapshots and inspect admin-side activity.',
              icon: Icons.analytics_rounded,
              items: [
                _SummaryItem(
                  'Review load',
                  '${stats.reviewLoad}',
                  AppTheme.warning,
                ),
                _SummaryItem('Users', '${stats.users}', AppTheme.primary),
                _SummaryItem('Partners', '${stats.partners}', AppTheme.success),
                _SummaryItem('Cases', '${stats.welfareCases}', AppTheme.error),
              ],
            ),
            const SizedBox(height: 14),
            LayoutBuilder(
              builder: (context, constraints) {
                final wide = constraints.maxWidth >= 900;
                final reportPanel = _Panel(
                  title: 'Export Center',
                  subtitle: 'Copy clean text reports to share or archive',
                  icon: Icons.file_copy_rounded,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _wideButton(
                        'Copy operational report',
                        Icons.summarize_rounded,
                        _copyReport,
                      ),
                      const SizedBox(height: 10),
                      _wideButton(
                        'Copy review queue',
                        Icons.rate_review_rounded,
                        _copyReviewQueue,
                      ),
                      const SizedBox(height: 10),
                      _wideButton(
                        'Seed review samples',
                        Icons.auto_fix_high_rounded,
                        _seedAdminSamples,
                      ),
                    ],
                  ),
                );
                final chartPanel = _Panel(
                  title: 'Operations Mix',
                  subtitle: 'Snapshot of current admin workload',
                  icon: Icons.bar_chart_rounded,
                  child: _OperationsBarChart(stats: stats),
                );

                if (!wide) {
                  return Column(
                    children: [
                      reportPanel,
                      const SizedBox(height: 14),
                      chartPanel,
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(flex: 5, child: reportPanel),
                    const SizedBox(width: 14),
                    Expanded(flex: 7, child: chartPanel),
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            _auditLogPanel(),
          ],
        );
      },
    );
  }

  Widget _tabSummary({
    required String title,
    required String subtitle,
    required IconData icon,
    required List<_SummaryItem> items,
    Widget? action,
  }) {
    return _Panel(
      title: title,
      subtitle: subtitle,
      icon: icon,
      action: action,
      child: Wrap(
        spacing: 10,
        runSpacing: 10,
        children: items
            .map(
              (item) => Container(
                width: 150,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: item.color.withValues(alpha: 0.16)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        color: item.color,
                        fontSize: 22,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      item.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
            .toList(),
      ),
    );
  }

  Widget _filterBar({
    required String hint,
    required String selected,
    required List<String> filters,
    required ValueChanged<String> onSelected,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: _cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _searchController,
            onChanged: (value) => setState(() => _search = value.toLowerCase()),
            decoration: InputDecoration(
              hintText: hint,
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: _search.isEmpty
                  ? null
                  : IconButton(
                      tooltip: 'Clear search',
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () {
                        _searchController.clear();
                        setState(() => _search = '');
                      },
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: filters.map((filter) {
              final isSelected = selected == filter;
              return ChoiceChip(
                selected: isSelected,
                label: Text(filter),
                selectedColor: AppTheme.primary,
                backgroundColor: Colors.white,
                side: BorderSide(
                  color: isSelected ? AppTheme.primary : AppTheme.border,
                ),
                labelStyle: GoogleFonts.inter(
                  color: isSelected ? Colors.white : AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 12,
                ),
                onSelected: (_) => onSelected(filter),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _auditLogPanel() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: _db
          .collection('admin_audit_logs')
          .orderBy('createdAt', descending: true)
          .limit(10)
          .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        return _Panel(
          title: 'Audit Log',
          subtitle: docs.isEmpty
              ? 'No admin actions logged yet'
              : 'Latest admin actions',
          icon: Icons.fact_check_rounded,
          child: docs.isEmpty
              ? const _EmbeddedEmpty(
                  icon: Icons.fact_check_outlined,
                  title: 'No audit events',
                  message: 'Admin actions will be recorded here.',
                )
              : Column(
                  children: docs.map((doc) {
                    final data = doc.data();
                    final action = _field(data, 'action', 'admin_action');
                    final target = _field(data, 'target', 'unknown target');
                    return _MiniActivity(
                      icon: Icons.admin_panel_settings_rounded,
                      title: _labelize(action),
                      subtitle:
                          '$target - ${_formatAnyDate(data['createdAt'])}',
                      status: 'audit',
                      color: AppTheme.primary,
                    );
                  }).toList(),
                ),
        );
      },
    );
  }

  List<_QueueItemData> _reviewQueueItems({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> posts,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> partners,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> welfare,
  }) {
    final queue = <_QueueItemData>[];

    for (final doc
        in posts
            .where((d) => d.data()['moderationStatus'] == 'flagged')
            .take(3)) {
      final data = doc.data();
      queue.add(
        _QueueItemData(
          icon: Icons.flag_rounded,
          color: AppTheme.warning,
          title: _field(data, 'title', 'Flagged forum post'),
          subtitle:
              '${_field(data, 'category', 'General')} by ${_field(data, 'authorName', 'User')}',
          status: 'forum',
          onOpen: () => _selectTab(2),
        ),
      );
    }

    for (final doc
        in welfare
            .where((d) => _field(d.data(), 'status', 'pending') == 'pending')
            .take(3)) {
      final data = doc.data();
      final urgent = _field(data, 'priority', 'normal') == 'urgent';
      queue.add(
        _QueueItemData(
          icon: urgent
              ? Icons.priority_high_rounded
              : Icons.assignment_late_rounded,
          color: urgent ? AppTheme.error : AppTheme.warning,
          title: _field(data, 'applicantName', 'Pending welfare case'),
          subtitle: _field(data, 'program', 'Support request'),
          status: urgent ? 'urgent' : 'pending',
          onOpen: () => _selectTab(4),
        ),
      );
    }

    for (final doc
        in partners
            .where((d) => (d.data()['approved'] ?? true) != true)
            .take(3)) {
      final data = doc.data();
      queue.add(
        _QueueItemData(
          icon: Icons.handshake_rounded,
          color: AppTheme.primary,
          title: _field(data, 'name', 'Partner review'),
          subtitle: _field(data, 'category', 'Marketplace partner'),
          status: 'partner',
          onOpen: () => _selectTab(3),
        ),
      );
    }

    return queue;
  }

  bool _matchesSearch(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    if (_search.isEmpty) {
      return true;
    }
    return doc.data().values.join(' ').toLowerCase().contains(_search);
  }

  bool _matchesUserFilter(Map<String, dynamic> data) {
    final status = _field(data, 'accountStatus', 'active').toLowerCase();
    final role = _field(data, 'role', 'user').toLowerCase();
    final isDemo = data['isDemoAccount'] == true || role == 'demo';
    switch (_userFilter) {
      case 'Active':
        return status != 'suspended' && data['authDisabled'] != true;
      case 'Suspended':
        return status == 'suspended';
      case 'Disabled':
        return data['authDisabled'] == true;
      case 'Admin':
        return role == 'admin' || data['email'] == AppConstants.adminEmail;
      case 'Demo':
        return isDemo;
      default:
        return true;
    }
  }

  bool _matchesStatusFilter(String status, String filter) {
    if (filter == 'All') {
      return true;
    }
    return status.toLowerCase() == filter.toLowerCase();
  }

  bool _matchesPartnerFilter(Map<String, dynamic> data) {
    final active = _isPartnerActive(data);
    final approved = (data['approved'] ?? true) == true;
    switch (_partnerFilter) {
      case 'Active':
        return active;
      case 'Hidden':
        return !active;
      case 'Unapproved':
        return !approved;
      default:
        return true;
    }
  }

  bool _matchesWelfareFilter(Map<String, dynamic> data) {
    final status = _field(data, 'status', 'pending').toLowerCase();
    final priority = _field(data, 'priority', 'normal').toLowerCase();
    switch (_welfareFilter) {
      case 'Pending':
        return status == 'pending';
      case 'Urgent':
        return priority == 'urgent' && status == 'pending';
      case 'Approved':
      case 'Rejected':
      case 'Resolved':
        return status == _welfareFilter.toLowerCase();
      default:
        return true;
    }
  }

  bool _isPartnerActive(Map<String, dynamic> data) {
    return (data['status'] ?? 'active') == 'active' &&
        (data['approved'] ?? true) == true;
  }

  void _selectTab(int index) {
    setState(() {
      _tabIndex = index;
      _search = '';
      _searchController.clear();
    });
  }

  Future<void> _requestFirebaseAuthSync() async {
    await _runAdminAction('Firebase Auth sync queued.', () async {
      final ref = await _db.collection('admin_user_sync_requests').add({
        'requestedByEmail': AppConstants.adminEmail,
        'status': 'queued',
        'createdAt': FieldValue.serverTimestamp(),
      });
      await _logAdminAction('firebase_auth_sync_requested', ref.path, {
        'requestedByEmail': AppConstants.adminEmail,
      });
    });
  }

  Future<void> _requestUserAuthDisabled(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool disabled,
  ) async {
    final data = doc.data();
    final email = _field(data, 'email', 'No email');
    await _runAdminAction(
      disabled ? 'Disable sign-in queued.' : 'Enable sign-in queued.',
      () async {
        await doc.reference.set({
          'authDisabled': disabled,
          'authActionStatus': 'queued',
          'authActionQueuedAt': FieldValue.serverTimestamp(),
          'accountStatus': disabled ? 'suspended' : 'active',
        }, SetOptions(merge: true));
        await _queueUserAuthAction(
          uid: doc.id,
          action: disabled ? 'disableAuth' : 'enableAuth',
          payload: {'email': email},
        );
      },
    );
  }

  Future<void> _queueUserAuthAction({
    required String uid,
    required String action,
    required Map<String, dynamic> payload,
  }) async {
    final ref = await _db.collection('admin_user_actions').add({
      'uid': uid,
      'action': action,
      'payload': payload,
      'requestedByEmail': AppConstants.adminEmail,
      'status': 'queued',
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _logAdminAction(action, ref.path, {'uid': uid, ...payload});
  }

  Future<void> _setUserStatus(
    String uid,
    String status, {
    String? email,
  }) async {
    await _runAdminAction('User marked $status.', () async {
      await _db.collection('users').doc(uid).set({
        'accountStatus': status,
        'statusUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      if (email != AppConstants.adminEmail) {
        await _queueUserAuthAction(
          uid: uid,
          action: status == 'suspended' ? 'disableAuth' : 'enableAuth',
          payload: {'email': email},
        );
      }
      await _logAdminAction('user_status_$status', 'users/$uid', {
        'email': email,
        'status': status,
      });
    });
  }

  Future<void> _setPostStatus(String postId, String status) async {
    await _runAdminAction('Post marked $status.', () async {
      await _db.collection('forum_posts').doc(postId).set({
        'moderationStatus': status,
        'moderatedAt': FieldValue.serverTimestamp(),
        'moderatedBy': AppConstants.adminEmail,
      }, SetOptions(merge: true));
      await _logAdminAction('post_status_$status', 'forum_posts/$postId', {
        'status': status,
      });
    });
  }

  Future<void> _setPartnerStatus(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    String status,
  ) async {
    await _runAdminAction('Partner marked $status.', () async {
      await doc.reference.set({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _logAdminAction('partner_status_$status', doc.reference.path, {
        'status': status,
      });
    });
  }

  Future<void> _setPartnerApproval(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    bool approved,
  ) async {
    await _runAdminAction(
      approved ? 'Partner approved.' : 'Partner approval removed.',
      () async {
        await doc.reference.set({
          'approved': approved,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        await _logAdminAction(
          approved ? 'partner_approved' : 'partner_unapproved',
          doc.reference.path,
          {'approved': approved},
        );
      },
    );
  }

  Future<void> _adjustPartnerPriority(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
    int delta,
  ) async {
    final current = _intValue(doc.data()['priority'], fallback: 10);
    final next = math.max(1, current + delta);
    await _runAdminAction('Partner priority updated.', () async {
      await doc.reference.set({
        'priority': next,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      await _logAdminAction('partner_priority', doc.reference.path, {
        'from': current,
        'to': next,
      });
    });
  }

  Future<void> _setWelfareStatus(String id, String status) async {
    await _runAdminAction('Case marked $status.', () async {
      await _db.collection('welfare_applications').doc(id).set({
        'status': status,
        'reviewedAt': FieldValue.serverTimestamp(),
        'reviewedBy': AppConstants.adminEmail,
      }, SetOptions(merge: true));
      await _logAdminAction(
        'welfare_status_$status',
        'welfare_applications/$id',
        {'status': status},
      );
    });
  }

  Future<void> _saveAppConfig(AppConfig config, String message) async {
    await _runAdminAction(message, () async {
      await AppConfigService().saveConfig(config);
      await _logAdminAction('app_config_updated', 'app_config/global', {
        'maintenanceMode': config.maintenanceMode,
        'announcementEnabled': config.announcementEnabled,
        'marketplaceEnabled': config.marketplaceEnabled,
        'forumEnabled': config.forumEnabled,
        'forumPostingEnabled': config.forumPostingEnabled,
        'forumCommentsEnabled': config.forumCommentsEnabled,
        'welfareEnabled': config.welfareEnabled,
        'chatbotEnabled': config.chatbotEnabled,
        'budgetAiEnabled': config.budgetAiEnabled,
        'brandName': config.brandName,
        'logoUrl': config.logoUrl,
        'primaryColorHex': config.primaryColorHex,
        'secondaryColorHex': config.secondaryColorHex,
      });
    });
  }

  Future<void> _seedAdminSamples() async {
    await _runAdminAction('Admin sample data is ready.', () async {
      final batch = _db.batch();
      final welfare = _db.collection('welfare_applications');
      final partners = _db.collection('marketplace_partners');

      batch.set(welfare.doc('sample-bisp-review'), {
        'applicantName': 'Ayesha Khan',
        'program': 'Benazir Income Support Programme',
        'status': 'pending',
        'priority': 'urgent',
        'notes': 'Household income verification needed before referral.',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(welfare.doc('sample-scholarship-review'), {
        'applicantName': 'Usman Ali',
        'program': 'Education Scholarship Desk',
        'status': 'pending',
        'priority': 'normal',
        'notes': 'Student uploaded fee estimate and CNIC details offline.',
        'createdAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(
        _db.collection('forum_posts').doc('sample-admin-flag'),
        {
          'title': 'Suspicious investment link review',
          'content':
              'A user reported a high-return link that needs moderation before it spreads.',
          'category': 'Investing',
          'authorName': 'FinEase Monitor',
          'authorAvatar': '',
          'authorId': 'system',
          'likes': 0,
          'comments': 0,
          'moderationStatus': 'flagged',
          'createdAt': FieldValue.serverTimestamp(),
        },
        SetOptions(merge: true),
      );
      batch.set(partners.doc('sample-partner-review'), {
        'name': 'Micro Growth Capital Desk',
        'category': 'Business',
        'description':
            'Pending partner review for small business financing referrals.',
        'badge': 'Needs Review',
        'ctaLabel': 'Review Offer',
        'websiteUrl': 'https://finease.app',
        'priority': 30,
        'iconName': 'briefcase',
        'colorHex': AppTheme.primary.toARGB32(),
        'status': 'inactive',
        'approved': false,
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      batch.set(_db.collection('admin_audit_logs').doc(), {
        'action': 'seed_admin_samples',
        'target': 'admin_console',
        'adminEmail': AppConstants.adminEmail,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await batch.commit();
    });
  }

  Future<void> _copyReport() async {
    await _runAdminAction('Report copied to clipboard.', () async {
      final users = await _db.collection('users').get();
      final posts = await _db.collection('forum_posts').get();
      final partners = await _db.collection('marketplace_partners').get();
      final welfare = await _db.collection('welfare_applications').get();
      final metrics = await _db
          .collection('system_metrics')
          .doc('overview')
          .get();
      final stats = _AdminStats.from(
        users: users.docs,
        posts: posts.docs,
        partners: partners.docs,
        welfare: welfare.docs,
      );
      final report = StringBuffer()
        ..writeln('FinEase Admin Report')
        ..writeln('Generated,${_dateFormat.format(DateTime.now())}')
        ..writeln('Users,${stats.users}')
        ..writeln('Active Users,${stats.activeUsers}')
        ..writeln('Verified Users,${stats.verifiedUsers}')
        ..writeln('Suspended Users,${stats.suspendedUsers}')
        ..writeln('Forum Posts,${stats.forumPosts}')
        ..writeln('Flagged Posts,${stats.flaggedPosts}')
        ..writeln('Removed Posts,${stats.removedPosts}')
        ..writeln('Partners,${stats.partners}')
        ..writeln('Active Partners,${stats.activePartners}')
        ..writeln('Hidden Partners,${stats.hiddenPartners}')
        ..writeln('Unapproved Partners,${stats.unapprovedPartners}')
        ..writeln('Welfare Cases,${stats.welfareCases}')
        ..writeln('Pending Welfare,${stats.pendingCases}')
        ..writeln('Urgent Welfare,${stats.urgentCases}')
        ..writeln('Resolved Welfare,${stats.resolvedCases}')
        ..writeln('Review Load,${stats.reviewLoad}')
        ..writeln('System Metrics,"${metrics.data()}"');
      await Clipboard.setData(ClipboardData(text: report.toString()));
      await _logAdminAction('copy_operational_report', 'reports/operations', {
        'reviewLoad': stats.reviewLoad,
      });
    });
  }

  Future<void> _copyReviewQueue() async {
    await _runAdminAction('Review queue copied to clipboard.', () async {
      final posts = await _db.collection('forum_posts').get();
      final partners = await _db.collection('marketplace_partners').get();
      final welfare = await _db.collection('welfare_applications').get();
      final queue = _reviewQueueItems(
        posts: posts.docs,
        partners: partners.docs,
        welfare: welfare.docs,
      );
      final buffer = StringBuffer()
        ..writeln('FinEase Review Queue')
        ..writeln('Generated,${_dateFormat.format(DateTime.now())}');
      if (queue.isEmpty) {
        buffer.writeln('No pending review items.');
      } else {
        for (final item in queue) {
          buffer.writeln('${item.status},${item.title},${item.subtitle}');
        }
      }
      await Clipboard.setData(ClipboardData(text: buffer.toString()));
      await _logAdminAction('copy_review_queue', 'reports/review_queue', {
        'items': queue.length,
      });
    });
  }

  void _showMetricsDialog(Map<String, dynamic> data) {
    final activeUsers = TextEditingController(
      text: '${data['activeUsers'] ?? 12842}',
    );
    final latency = TextEditingController(text: '${data['latencyMs'] ?? 12}');
    final pending = TextEditingController(
      text: '${data['pendingWelfare'] ?? 42}',
    );
    final urgent = TextEditingController(
      text: '${data['urgentReviews'] ?? 12}',
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('System metrics'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _numberField(activeUsers, 'Active users'),
              const SizedBox(height: 10),
              _numberField(latency, 'Latency ms'),
              const SizedBox(height: 10),
              _numberField(pending, 'Pending welfare'),
              const SizedBox(height: 10),
              _numberField(urgent, 'Urgent reviews'),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _runAdminAction('Metrics updated.', () async {
                await _db.collection('system_metrics').doc('overview').set({
                  'activeUsers': int.tryParse(activeUsers.text) ?? 0,
                  'latencyMs': int.tryParse(latency.text) ?? 0,
                  'pendingWelfare': int.tryParse(pending.text) ?? 0,
                  'urgentReviews': int.tryParse(urgent.text) ?? 0,
                  'updatedAt': FieldValue.serverTimestamp(),
                }, SetOptions(merge: true));
                await _logAdminAction(
                  'update_system_metrics',
                  'system_metrics/overview',
                  {
                    'activeUsers': activeUsers.text,
                    'latencyMs': latency.text,
                    'pendingWelfare': pending.text,
                    'urgentReviews': urgent.text,
                  },
                );
              });
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showPartnerDialog({QueryDocumentSnapshot<Map<String, dynamic>>? doc}) {
    final data = doc?.data() ?? {};
    final name = TextEditingController(text: data['name'] ?? '');
    final category = TextEditingController(text: data['category'] ?? 'Finance');
    final description = TextEditingController(text: data['description'] ?? '');
    final badge = TextEditingController(text: data['badge'] ?? 'Verified');
    final cta = TextEditingController(text: data['ctaLabel'] ?? 'Learn More');
    final websiteUrl = TextEditingController(text: data['websiteUrl'] ?? '');
    final priority = TextEditingController(text: '${data['priority'] ?? 10}');
    final iconName = TextEditingController(text: data['iconName'] ?? 'bank');
    final colorHex = TextEditingController(
      text: _formatColorInput(data['colorHex']),
    );

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(doc == null ? 'Add partner' : 'Edit partner'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: category,
                decoration: const InputDecoration(labelText: 'Category'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: description,
                minLines: 2,
                maxLines: 4,
                decoration: const InputDecoration(labelText: 'Description'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: websiteUrl,
                keyboardType: TextInputType.url,
                decoration: const InputDecoration(labelText: 'Website URL'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: badge,
                decoration: const InputDecoration(labelText: 'Badge'),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: cta,
                decoration: const InputDecoration(labelText: 'CTA label'),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: _numberField(priority, 'Priority')),
                  const SizedBox(width: 10),
                  Expanded(
                    child: TextField(
                      controller: iconName,
                      decoration: const InputDecoration(
                        labelText: 'Icon name',
                        hintText: 'bank',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                controller: colorHex,
                decoration: const InputDecoration(
                  labelText: 'Color hex',
                  hintText: '#2E3192',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          ElevatedButton.icon(
            onPressed: () async {
              final title = name.text.trim();
              if (title.isEmpty) {
                _snack('Partner name is required.');
                return;
              }
              Navigator.pop(dialogContext);
              final payload = {
                'name': title,
                'category': category.text.trim().isEmpty
                    ? 'General'
                    : category.text.trim(),
                'description': description.text.trim(),
                'badge': badge.text.trim(),
                'ctaLabel': cta.text.trim().isEmpty
                    ? 'Learn More'
                    : cta.text.trim(),
                'websiteUrl': websiteUrl.text.trim(),
                'priority': int.tryParse(priority.text) ?? 10,
                'iconName': iconName.text.trim().isEmpty
                    ? 'bank'
                    : iconName.text.trim(),
                'colorHex':
                    _parseColorHex(colorHex.text) ??
                    data['colorHex'] ??
                    AppTheme.primary.toARGB32(),
                'status': data['status'] ?? 'active',
                'approved': data['approved'] ?? true,
                'updatedAt': FieldValue.serverTimestamp(),
              };
              await _runAdminAction('Partner saved.', () async {
                if (doc == null) {
                  final ref = await _db
                      .collection('marketplace_partners')
                      .add(payload);
                  await _logAdminAction('partner_created', ref.path, {
                    'name': title,
                  });
                } else {
                  await doc.reference.set(payload, SetOptions(merge: true));
                  await _logAdminAction('partner_updated', doc.reference.path, {
                    'name': title,
                  });
                }
              });
            },
            icon: const Icon(Icons.save_rounded),
            label: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _showWelfareDialog({QueryDocumentSnapshot<Map<String, dynamic>>? doc}) {
    final data = doc?.data() ?? {};
    final applicant = TextEditingController(text: data['applicantName'] ?? '');
    final program = TextEditingController(
      text: data['program'] ?? 'Financial support review',
    );
    final notes = TextEditingController(text: data['notes'] ?? '');
    var priority = _field(data, 'priority', 'normal');
    var status = _field(data, 'status', 'pending');

    showDialog(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: Text(doc == null ? 'Add welfare case' : 'Edit welfare case'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: applicant,
                    decoration: const InputDecoration(
                      labelText: 'Applicant name',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: program,
                    decoration: const InputDecoration(labelText: 'Program'),
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: priority,
                    decoration: const InputDecoration(labelText: 'Priority'),
                    items: const ['normal', 'urgent']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_capitalized(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => priority = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  DropdownButtonFormField<String>(
                    initialValue: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const ['pending', 'approved', 'rejected', 'resolved']
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(_capitalized(value)),
                          ),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) {
                        setDialogState(() => status = value);
                      }
                    },
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: notes,
                    minLines: 2,
                    maxLines: 5,
                    decoration: const InputDecoration(labelText: 'Notes'),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              ElevatedButton.icon(
                onPressed: () async {
                  final name = applicant.text.trim().isEmpty
                      ? 'Applicant'
                      : applicant.text.trim();
                  Navigator.pop(dialogContext);
                  final payload = {
                    'applicantName': name,
                    'program': program.text.trim().isEmpty
                        ? 'Financial support review'
                        : program.text.trim(),
                    'notes': notes.text.trim(),
                    'status': status,
                    'priority': priority,
                    'updatedAt': FieldValue.serverTimestamp(),
                    if (doc == null) 'createdAt': FieldValue.serverTimestamp(),
                  };
                  await _runAdminAction('Welfare case saved.', () async {
                    if (doc == null) {
                      final ref = await _db
                          .collection('welfare_applications')
                          .add(payload);
                      await _logAdminAction('welfare_created', ref.path, {
                        'applicantName': name,
                      });
                    } else {
                      await doc.reference.set(payload, SetOptions(merge: true));
                      await _logAdminAction(
                        'welfare_updated',
                        doc.reference.path,
                        {
                          'applicantName': name,
                          'status': status,
                          'priority': priority,
                        },
                      );
                    }
                  });
                },
                icon: const Icon(Icons.save_rounded),
                label: const Text('Save'),
              ),
            ],
          ),
        );
      },
    );
  }

  void _showUserEditor(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    final fullName = TextEditingController(text: _field(data, 'fullName', ''));
    final country = TextEditingController(
      text: _field(data, 'country', AppConstants.countryName),
    );
    final language = TextEditingController(
      text: _field(data, 'language', 'English (Pakistan)'),
    );
    final monthlyIncome = TextEditingController(
      text: data['monthlyIncome'] == null ? '' : '${data['monthlyIncome']}',
    );
    final adminNotes = TextEditingController(
      text: _field(data, 'adminNotes', ''),
    );
    final originalRole = _field(data, 'role', 'user');
    var role = originalRole;
    var status = _field(data, 'accountStatus', 'active');
    var emailVerified = data['emailVerified'] == true;
    var pushAlerts = data['pushAlerts'] != false;
    var monthlyReports = data['monthlyReports'] != false;

    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Manage Firebase user'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SelectableText(
                  _field(data, 'email', 'No email'),
                  style: GoogleFonts.inter(color: AppTheme.textSecondary),
                ),
                const SizedBox(height: 10),
                SelectableText(
                  'UID: ${doc.id}',
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: fullName,
                  decoration: const InputDecoration(labelText: 'Full name'),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: role,
                        decoration: const InputDecoration(labelText: 'Role'),
                        items: const ['user', 'demo', 'admin']
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(_capitalized(value)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => role = value);
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        initialValue: status,
                        decoration: const InputDecoration(labelText: 'Status'),
                        items: const ['active', 'suspended']
                            .map(
                              (value) => DropdownMenuItem(
                                value: value,
                                child: Text(_capitalized(value)),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value != null) {
                            setDialogState(() => status = value);
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: monthlyIncome,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Monthly income',
                    prefixText: 'PKR ',
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: country,
                  decoration: const InputDecoration(labelText: 'Country'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: language,
                  decoration: const InputDecoration(labelText: 'Language'),
                ),
                const SizedBox(height: 10),
                SwitchListTile(
                  value: emailVerified,
                  onChanged: (value) =>
                      setDialogState(() => emailVerified = value),
                  title: const Text('Mark profile email verified'),
                  subtitle: const Text(
                    'Updates Firestore profile. Firebase Auth email verification still comes from Auth sync.',
                  ),
                ),
                SwitchListTile(
                  value: pushAlerts,
                  onChanged: (value) =>
                      setDialogState(() => pushAlerts = value),
                  title: const Text('Push alerts'),
                ),
                SwitchListTile(
                  value: monthlyReports,
                  onChanged: (value) =>
                      setDialogState(() => monthlyReports = value),
                  title: const Text('Monthly reports'),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: adminNotes,
                  minLines: 2,
                  maxLines: 4,
                  decoration: const InputDecoration(labelText: 'Admin notes'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel'),
            ),
            ElevatedButton.icon(
              onPressed: () async {
                Navigator.pop(dialogContext);
                final income = double.tryParse(monthlyIncome.text.trim());
                await _runAdminAction('User profile updated.', () async {
                  final profilePatch = {
                    'fullName': fullName.text.trim().isEmpty
                        ? _field(data, 'email', 'FinEase user')
                        : fullName.text.trim(),
                    'role': role,
                    'accountStatus': status,
                    'country': country.text.trim().isEmpty
                        ? AppConstants.countryName
                        : country.text.trim(),
                    'language': language.text.trim().isEmpty
                        ? 'English (Pakistan)'
                        : language.text.trim(),
                    'emailVerified': emailVerified,
                    'pushAlerts': pushAlerts,
                    'monthlyReports': monthlyReports,
                    'adminNotes': adminNotes.text.trim(),
                    'adminUpdatedAt': FieldValue.serverTimestamp(),
                    'adminUpdatedBy': AppConstants.adminEmail,
                  };
                  if (income != null) {
                    profilePatch['monthlyIncome'] = income;
                  }
                  await doc.reference.set(
                    profilePatch,
                    SetOptions(merge: true),
                  );
                  if (role != originalRole) {
                    await _queueUserAuthAction(
                      uid: doc.id,
                      action: 'setRole',
                      payload: {'role': role},
                    );
                  }
                  if (_field(data, 'accountStatus', 'active') != status &&
                      _field(data, 'email', '') != AppConstants.adminEmail) {
                    await _queueUserAuthAction(
                      uid: doc.id,
                      action: status == 'suspended'
                          ? 'disableAuth'
                          : 'enableAuth',
                      payload: {'status': status},
                    );
                  }
                  await _logAdminAction(
                    'user_profile_updated',
                    'users/${doc.id}',
                    {'role': role, 'status': status},
                  );
                });
              },
              icon: const Icon(Icons.save_rounded),
              label: const Text('Save user'),
            ),
          ],
        ),
      ),
    );
  }

  void _showDocumentDetails({
    required String title,
    required String subtitle,
    required String path,
    required IconData icon,
    required Map<String, dynamic> data,
  }) {
    final entries = data.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.78,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppTheme.primary.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, color: AppTheme.primary),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.plusJakartaSans(
                              fontSize: 18,
                              fontWeight: FontWeight.w800,
                              color: AppTheme.textPrimary,
                            ),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy path',
                      onPressed: () => _copyText(path, 'Document path copied.'),
                      icon: const Icon(Icons.copy_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: entries.length,
                  separatorBuilder: (_, index) => const Divider(height: 20),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          entry.key,
                          style: GoogleFonts.inter(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        SelectableText(
                          _valueToText(entry.value),
                          style: GoogleFonts.inter(
                            color: AppTheme.textPrimary,
                            height: 1.35,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _numberField(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      decoration: InputDecoration(labelText: label),
    );
  }

  Widget _smallButton(String label, IconData icon, VoidCallback? onPressed) {
    return TextButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 16),
      label: Text(label),
      style: TextButton.styleFrom(
        visualDensity: VisualDensity.compact,
        foregroundColor: AppTheme.primary,
        padding: const EdgeInsets.symmetric(horizontal: 8),
      ),
    );
  }

  Widget _ghostButton(String label, IconData icon, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppTheme.primary,
        side: const BorderSide(color: AppTheme.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      ),
    );
  }

  Widget _wideButton(String label, IconData icon, VoidCallback onPressed) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
      style: OutlinedButton.styleFrom(
        alignment: Alignment.centerLeft,
        foregroundColor: AppTheme.primary,
        side: const BorderSide(color: AppTheme.border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      ),
    );
  }

  Future<void> _runAdminAction(
    String successMessage,
    Future<void> Function() action,
  ) async {
    if (_busy) {
      return;
    }
    setState(() => _busy = true);
    try {
      await action();
      _snack(successMessage);
    } catch (error) {
      _snack('Admin action failed: $error');
    } finally {
      if (mounted) {
        setState(() => _busy = false);
      }
    }
  }

  Future<void> _logAdminAction(
    String action,
    String target,
    Map<String, dynamic> details,
  ) {
    return _db.collection('admin_audit_logs').add({
      'action': action,
      'target': target,
      'details': details,
      'adminEmail': AppConstants.adminEmail,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> _copyText(String text, String message) async {
    await Clipboard.setData(ClipboardData(text: text));
    _snack(message);
  }

  String _field(Map<String, dynamic> data, String key, [String fallback = '']) {
    final value = data[key];
    if (value == null) {
      return fallback;
    }
    final text = '$value'.trim();
    return text.isEmpty ? fallback : text;
  }

  int _intValue(Object? value, {int fallback = 0}) {
    if (value is int) {
      return value;
    }
    if (value is num) {
      return value.round();
    }
    return int.tryParse('$value') ?? fallback;
  }

  String _formatAnyDate(Object? value) {
    if (value is Timestamp) {
      return _shortDateFormat.format(value.toDate());
    }
    if (value is DateTime) {
      return _shortDateFormat.format(value);
    }
    if (value is String && value.trim().isNotEmpty) {
      return value;
    }
    return 'No date';
  }

  String _valueToText(Object? value) {
    if (value is Timestamp) {
      return _dateFormat.format(value.toDate());
    }
    if (value is DateTime) {
      return _dateFormat.format(value);
    }
    return '$value';
  }

  Color _statusColor(String status) {
    switch (status.toLowerCase()) {
      case 'active':
      case 'visible':
      case 'approved':
      case 'resolved':
      case 'verified':
        return AppTheme.success;
      case 'pending':
      case 'flagged':
      case 'review':
      case 'audit':
        return AppTheme.warning;
      case 'urgent':
      case 'suspended':
      case 'removed':
      case 'rejected':
      case 'hidden':
      case 'inactive':
        return AppTheme.error;
      case 'protected':
      case 'admin':
        return AppTheme.primary;
      default:
        return AppTheme.textSecondary;
    }
  }

  IconData _partnerIcon(String? name) {
    switch (name) {
      case 'shield':
        return Icons.shield_rounded;
      case 'briefcase':
        return Icons.work_rounded;
      case 'sun':
        return Icons.solar_power_rounded;
      case 'school':
        return Icons.school_rounded;
      case 'bank':
        return Icons.account_balance_rounded;
      default:
        return Icons.storefront_rounded;
    }
  }

  String _formatColorInput(Object? value) {
    if (value is int) {
      final rgb = (value & 0xFFFFFF).toRadixString(16).padLeft(6, '0');
      return '#${rgb.toUpperCase()}';
    }
    return '#2E3192';
  }

  int? _parseColorHex(String input) {
    var value = input.trim().replaceAll('#', '');
    if (value.startsWith('0x')) {
      value = value.substring(2);
    }
    if (value.length == 6) {
      value = 'FF$value';
    }
    if (value.length != 8) {
      return null;
    }
    return int.tryParse(value, radix: 16);
  }

  String _labelize(String value) {
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((part) => part.isNotEmpty)
        .map(_capitalized)
        .join(' ');
  }

  static String _capitalized(String value) {
    if (value.isEmpty) {
      return value;
    }
    return '${value[0].toUpperCase()}${value.substring(1)}';
  }

  BoxDecoration _cardDecoration() {
    return BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: AppTheme.border),
      boxShadow: AppTheme.softShadow,
    );
  }

  void _snack(String message) {
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _AdminSideRail extends StatelessWidget {
  const _AdminSideRail({
    required this.tabs,
    required this.selectedIndex,
    required this.onSelected,
    required this.onCopyReport,
    required this.onSeed,
    required this.onSignOut,
  });

  final List<_AdminTab> tabs;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final VoidCallback onCopyReport;
  final VoidCallback onSeed;
  final VoidCallback onSignOut;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 262,
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              StreamBuilder<AppConfig>(
                stream: AppConfigService().watchConfig(),
                initialData: AppConfig.defaults(),
                builder: (context, snapshot) {
                  final config = snapshot.data ?? AppConfig.defaults();
                  return AppBrandLogo(logoUrl: config.logoUrl, size: 42);
                },
              ),
              const SizedBox(width: 10),
              Expanded(
                child: StreamBuilder<AppConfig>(
                  stream: AppConfigService().watchConfig(),
                  initialData: AppConfig.defaults(),
                  builder: (context, snapshot) {
                    final config = snapshot.data ?? AppConfig.defaults();
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.brandName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.plusJakartaSans(
                            color: AppTheme.textPrimary,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                        Text(
                          'Admin Panel',
                          style: GoogleFonts.inter(
                            color: AppTheme.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 22),
          Expanded(
            child: ListView.separated(
              itemCount: tabs.length,
              separatorBuilder: (_, index) => const SizedBox(height: 6),
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final selected = selectedIndex == index;
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onSelected(index),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    decoration: BoxDecoration(
                      color: selected
                          ? AppTheme.primary.withValues(alpha: 0.1)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: selected ? AppTheme.primary : Colors.transparent,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          tab.icon,
                          size: 21,
                          color: selected
                              ? AppTheme.primary
                              : AppTheme.textSecondary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            tab.label,
                            style: GoogleFonts.inter(
                              color: selected
                                  ? AppTheme.primary
                                  : AppTheme.textSecondary,
                              fontWeight: selected
                                  ? FontWeight.w800
                                  : FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
          const Divider(height: 24),
          _SideAction(
            label: 'Copy report',
            icon: Icons.file_copy_rounded,
            onPressed: onCopyReport,
          ),
          const SizedBox(height: 6),
          _SideAction(
            label: 'Seed samples',
            icon: Icons.auto_fix_high_rounded,
            onPressed: onSeed,
          ),
          const SizedBox(height: 6),
          _SideAction(
            label: 'Sign out',
            icon: Icons.logout_rounded,
            onPressed: onSignOut,
          ),
        ],
      ),
    );
  }
}

class _AppConfigEditor extends StatefulWidget {
  const _AppConfigEditor({required this.config, required this.onSave});

  final AppConfig config;
  final ValueChanged<AppConfig> onSave;

  @override
  State<_AppConfigEditor> createState() => _AppConfigEditorState();
}

class _AppConfigEditorState extends State<_AppConfigEditor> {
  late bool _maintenanceMode;
  late bool _announcementEnabled;
  late bool _marketplaceEnabled;
  late bool _forumEnabled;
  late bool _forumPostingEnabled;
  late bool _forumCommentsEnabled;
  late bool _welfareEnabled;
  late bool _chatbotEnabled;
  late bool _budgetAiEnabled;

  late final TextEditingController _announcementTitleController;
  late final TextEditingController _announcementMessageController;
  late final TextEditingController _brandNameController;
  late final TextEditingController _brandTaglineController;
  late final TextEditingController _logoUrlController;
  late final TextEditingController _primaryColorController;
  late final TextEditingController _secondaryColorController;
  late final TextEditingController _homeHeroTitleController;
  late final TextEditingController _homeHeroMessageController;
  late final TextEditingController _supportEmailController;
  late final TextEditingController _supportMessageController;

  @override
  void initState() {
    super.initState();
    _announcementTitleController = TextEditingController();
    _announcementMessageController = TextEditingController();
    _brandNameController = TextEditingController();
    _brandTaglineController = TextEditingController();
    _logoUrlController = TextEditingController();
    _primaryColorController = TextEditingController();
    _secondaryColorController = TextEditingController();
    _homeHeroTitleController = TextEditingController();
    _homeHeroMessageController = TextEditingController();
    _supportEmailController = TextEditingController();
    _supportMessageController = TextEditingController();
    _applyConfig(widget.config);
  }

  @override
  void didUpdateWidget(covariant _AppConfigEditor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.config.updatedAt != widget.config.updatedAt) {
      _applyConfig(widget.config);
    }
  }

  @override
  void dispose() {
    _announcementTitleController.dispose();
    _announcementMessageController.dispose();
    _brandNameController.dispose();
    _brandTaglineController.dispose();
    _logoUrlController.dispose();
    _primaryColorController.dispose();
    _secondaryColorController.dispose();
    _homeHeroTitleController.dispose();
    _homeHeroMessageController.dispose();
    _supportEmailController.dispose();
    _supportMessageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final wide = constraints.maxWidth >= 900;
        final switches = _Panel(
          title: 'Live Feature Switches',
          subtitle:
              'Saving these toggles changes access across the user-facing app.',
          icon: Icons.toggle_on_rounded,
          child: Column(
            children: [
              _controlSwitch(
                title: 'Maintenance mode',
                subtitle:
                    'Blocks the user app with the support message. Admin stays in the panel.',
                icon: Icons.construction_rounded,
                value: _maintenanceMode,
                danger: true,
                onChanged: (value) => setState(() => _maintenanceMode = value),
              ),
              _controlSwitch(
                title: 'Marketplace',
                subtitle: 'Controls access to partner marketplace listings.',
                icon: Icons.storefront_rounded,
                value: _marketplaceEnabled,
                onChanged: (value) =>
                    setState(() => _marketplaceEnabled = value),
              ),
              _controlSwitch(
                title: 'Welfare programs',
                subtitle: 'Controls access to the welfare program directory.',
                icon: Icons.volunteer_activism_rounded,
                value: _welfareEnabled,
                onChanged: (value) => setState(() => _welfareEnabled = value),
              ),
              _controlSwitch(
                title: 'Forum access',
                subtitle:
                    'Controls whether users can open the community forum.',
                icon: Icons.forum_rounded,
                value: _forumEnabled,
                onChanged: (value) => setState(() => _forumEnabled = value),
              ),
              _controlSwitch(
                title: 'Forum posting',
                subtitle: 'Controls whether users can publish new discussions.',
                icon: Icons.edit_rounded,
                value: _forumPostingEnabled,
                onChanged: (value) =>
                    setState(() => _forumPostingEnabled = value),
              ),
              _controlSwitch(
                title: 'Forum comments',
                subtitle: 'Controls whether users can add comments to posts.',
                icon: Icons.chat_bubble_rounded,
                value: _forumCommentsEnabled,
                onChanged: (value) =>
                    setState(() => _forumCommentsEnabled = value),
              ),
              _controlSwitch(
                title: 'AI chatbot',
                subtitle: 'Controls access to FinEase AI chat.',
                icon: Icons.smart_toy_rounded,
                value: _chatbotEnabled,
                onChanged: (value) => setState(() => _chatbotEnabled = value),
              ),
              _controlSwitch(
                title: 'Budget AI insights',
                subtitle:
                    'Controls generated AI recommendations on the budget screen.',
                icon: Icons.auto_awesome_rounded,
                value: _budgetAiEnabled,
                onChanged: (value) => setState(() => _budgetAiEnabled = value),
              ),
            ],
          ),
        );

        final content = Column(
          children: [
            _Panel(
              title: 'Brand and Home UI',
              subtitle:
                  'Change the visible app identity, remote logo, brand colors, and home hero copy.',
              icon: Icons.palette_rounded,
              child: Column(
                children: [
                  Row(
                    children: [
                      AppBrandLogo(
                        logoUrl: _logoUrlController.text,
                        size: 58,
                        backgroundColor: AppTheme.primary.withValues(
                          alpha: 0.08,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextField(
                          controller: _logoUrlController,
                          onChanged: (_) => setState(() {}),
                          decoration: const InputDecoration(
                            labelText: 'Logo image URL',
                            hintText: 'https://...',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _brandNameController,
                    decoration: const InputDecoration(labelText: 'App name'),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _brandTaglineController,
                    decoration: const InputDecoration(labelText: 'App tagline'),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _primaryColorController,
                          decoration: const InputDecoration(
                            labelText: 'Primary color',
                            hintText: '#2E3192',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: _secondaryColorController,
                          decoration: const InputDecoration(
                            labelText: 'Secondary color',
                            hintText: '#00F2EA',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _homeHeroTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Home card title',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _homeHeroMessageController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Home card message',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Panel(
              title: 'Announcement Banner',
              subtitle:
                  'This message appears above the main user app immediately after save.',
              icon: Icons.campaign_rounded,
              child: Column(
                children: [
                  _controlSwitch(
                    title: 'Show announcement',
                    subtitle: 'Display the banner to signed-in users.',
                    icon: Icons.notifications_active_rounded,
                    value: _announcementEnabled,
                    onChanged: (value) =>
                        setState(() => _announcementEnabled = value),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _announcementTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Announcement title',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _announcementMessageController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Announcement message',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Panel(
              title: 'Support Copy',
              subtitle:
                  'Used by paused features and maintenance screens across the app.',
              icon: Icons.support_agent_rounded,
              child: Column(
                children: [
                  TextField(
                    controller: _supportEmailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'Support email',
                    ),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _supportMessageController,
                    minLines: 2,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Paused feature / maintenance message',
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            _Panel(
              title: 'Publish Changes',
              subtitle:
                  'App users receive these changes from Firestore streams without a rebuild.',
              icon: Icons.rocket_launch_rounded,
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _save,
                  icon: const Icon(Icons.save_rounded),
                  label: const Text('Save Live App Controls'),
                ),
              ),
            ),
          ],
        );

        if (!wide) {
          return Column(
            children: [switches, const SizedBox(height: 14), content],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(flex: 5, child: switches),
            const SizedBox(width: 14),
            Expanded(flex: 6, child: content),
          ],
        );
      },
    );
  }

  void _applyConfig(AppConfig config) {
    _maintenanceMode = config.maintenanceMode;
    _announcementEnabled = config.announcementEnabled;
    _marketplaceEnabled = config.marketplaceEnabled;
    _forumEnabled = config.forumEnabled;
    _forumPostingEnabled = config.forumPostingEnabled;
    _forumCommentsEnabled = config.forumCommentsEnabled;
    _welfareEnabled = config.welfareEnabled;
    _chatbotEnabled = config.chatbotEnabled;
    _budgetAiEnabled = config.budgetAiEnabled;
    _brandNameController.text = config.brandName;
    _brandTaglineController.text = config.brandTagline;
    _logoUrlController.text = config.logoUrl;
    _primaryColorController.text = config.primaryColorHex;
    _secondaryColorController.text = config.secondaryColorHex;
    _homeHeroTitleController.text = config.homeHeroTitle;
    _homeHeroMessageController.text = config.homeHeroMessage;
    _announcementTitleController.text = config.announcementTitle;
    _announcementMessageController.text = config.announcementMessage;
    _supportEmailController.text = config.supportEmail;
    _supportMessageController.text = config.supportMessage;
  }

  void _save() {
    widget.onSave(
      widget.config.copyWith(
        maintenanceMode: _maintenanceMode,
        announcementEnabled: _announcementEnabled,
        announcementTitle: _announcementTitleController.text.trim(),
        announcementMessage: _announcementMessageController.text.trim(),
        marketplaceEnabled: _marketplaceEnabled,
        forumEnabled: _forumEnabled,
        forumPostingEnabled: _forumPostingEnabled,
        forumCommentsEnabled: _forumCommentsEnabled,
        welfareEnabled: _welfareEnabled,
        chatbotEnabled: _chatbotEnabled,
        budgetAiEnabled: _budgetAiEnabled,
        brandName: _brandNameController.text.trim(),
        brandTagline: _brandTaglineController.text.trim(),
        logoUrl: _logoUrlController.text.trim(),
        primaryColorHex: _primaryColorController.text.trim(),
        secondaryColorHex: _secondaryColorController.text.trim(),
        homeHeroTitle: _homeHeroTitleController.text.trim(),
        homeHeroMessage: _homeHeroMessageController.text.trim(),
        supportEmail: _supportEmailController.text.trim(),
        supportMessage: _supportMessageController.text.trim(),
      ),
    );
  }

  Widget _controlSwitch({
    required String title,
    required String subtitle,
    required IconData icon,
    required bool value,
    required ValueChanged<bool> onChanged,
    bool danger = false,
  }) {
    final color = danger && value ? AppTheme.error : AppTheme.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.14)),
      ),
      child: SwitchListTile(
        value: value,
        onChanged: onChanged,
        activeThumbColor: color,
        secondary: Icon(icon, color: color),
        title: Text(
          title,
          style: GoogleFonts.inter(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w800,
          ),
        ),
        subtitle: Text(
          subtitle,
          style: GoogleFonts.inter(
            color: AppTheme.textSecondary,
            fontSize: 12,
            height: 1.35,
          ),
        ),
      ),
    );
  }
}

class _SideAction extends StatelessWidget {
  const _SideAction({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: TextButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label),
        style: TextButton.styleFrom(
          alignment: Alignment.centerLeft,
          foregroundColor: AppTheme.primary,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
        ),
      ),
    );
  }
}

class _Stream4 extends StatelessWidget {
  const _Stream4({
    required this.users,
    required this.posts,
    required this.partners,
    required this.welfare,
    required this.builder,
  });

  final Stream<QuerySnapshot<Map<String, dynamic>>> users;
  final Stream<QuerySnapshot<Map<String, dynamic>>> posts;
  final Stream<QuerySnapshot<Map<String, dynamic>>> partners;
  final Stream<QuerySnapshot<Map<String, dynamic>>> welfare;
  final Widget Function(
    BuildContext,
    QuerySnapshot<Map<String, dynamic>>,
    QuerySnapshot<Map<String, dynamic>>,
    QuerySnapshot<Map<String, dynamic>>,
    QuerySnapshot<Map<String, dynamic>>,
  )
  builder;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: users,
      builder: (context, usersSnapshot) {
        return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: posts,
          builder: (context, postsSnapshot) {
            return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: partners,
              builder: (context, partnersSnapshot) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: welfare,
                  builder: (context, welfareSnapshot) {
                    final error =
                        usersSnapshot.error ??
                        postsSnapshot.error ??
                        partnersSnapshot.error ??
                        welfareSnapshot.error;
                    if (error != null) {
                      return _ErrorPanel(message: '$error');
                    }
                    if (!usersSnapshot.hasData ||
                        !postsSnapshot.hasData ||
                        !partnersSnapshot.hasData ||
                        !welfareSnapshot.hasData) {
                      return const _LoadingView(label: 'Loading admin data');
                    }
                    return builder(
                      context,
                      usersSnapshot.data!,
                      postsSnapshot.data!,
                      partnersSnapshot.data!,
                      welfareSnapshot.data!,
                    );
                  },
                );
              },
            );
          },
        );
      },
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
    this.action,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: AppTheme.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: AppTheme.primary, size: 20),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              if (action != null) ...[const SizedBox(width: 10), action!],
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  const _MetricGrid({required this.items});

  final List<_MetricItem> items;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: items.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 260,
        mainAxisExtent: 150,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemBuilder: (context, index) => _MetricTile(item: items[index]),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.item});

  final _MetricItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: item.color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(item.icon, color: item.color, size: 20),
              ),
              const Spacer(),
              Text(
                '${((item.progress ?? 0) * 100).round()}%',
                style: GoogleFonts.inter(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w700,
                  fontSize: 11,
                ),
              ),
            ],
          ),
          const Spacer(),
          Text(
            item.value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.plusJakartaSans(
              fontSize: 25,
              fontWeight: FontWeight.w900,
              color: item.color,
            ),
          ),
          Text(
            item.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              color: AppTheme.textPrimary,
            ),
          ),
          Text(
            item.detail,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 12,
              color: AppTheme.textSecondary,
            ),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(99),
            child: LinearProgressIndicator(
              minHeight: 5,
              value: item.progress?.clamp(0, 1),
              color: item.color,
              backgroundColor: item.color.withValues(alpha: 0.12),
            ),
          ),
        ],
      ),
    );
  }
}

class _OperationsBarChart extends StatelessWidget {
  const _OperationsBarChart({required this.stats});

  final _AdminStats stats;

  @override
  Widget build(BuildContext context) {
    final data = [
      _ChartDatum('Users', stats.users.toDouble(), AppTheme.primary),
      _ChartDatum('Forum', stats.forumPosts.toDouble(), AppTheme.warning),
      _ChartDatum('Partners', stats.partners.toDouble(), AppTheme.success),
      _ChartDatum('Cases', stats.welfareCases.toDouble(), AppTheme.error),
    ];
    final maxValue = math.max(
      4.0,
      data.map((datum) => datum.value).reduce(math.max) * 1.25,
    );

    return SizedBox(
      height: 250,
      child: BarChart(
        BarChartData(
          maxY: maxValue,
          alignment: BarChartAlignment.spaceAround,
          barTouchData: BarTouchData(
            touchTooltipData: BarTouchTooltipData(
              getTooltipColor: (_) => AppTheme.textPrimary,
              getTooltipItem: (group, groupIndex, rod, rodIndex) {
                final datum = data[group.x.toInt()];
                return BarTooltipItem(
                  '${datum.label}\n${rod.toY.toStringAsFixed(0)}',
                  GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                );
              },
            ),
          ),
          gridData: FlGridData(
            drawVerticalLine: false,
            getDrawingHorizontalLine: (value) => FlLine(
              color: AppTheme.border,
              strokeWidth: 1,
              dashArray: [4, 4],
            ),
          ),
          borderData: FlBorderData(show: false),
          titlesData: FlTitlesData(
            topTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            rightTitles: const AxisTitles(
              sideTitles: SideTitles(showTitles: false),
            ),
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 38,
                getTitlesWidget: (value, meta) => Text(
                  NumberFormat.compact().format(value),
                  style: GoogleFonts.inter(
                    color: AppTheme.textHint,
                    fontSize: 10,
                  ),
                ),
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 34,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= data.length) {
                    return const SizedBox.shrink();
                  }
                  return Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      data[index].label,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          barGroups: List.generate(data.length, (index) {
            final datum = data[index];
            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: datum.value,
                  width: 24,
                  color: datum.color,
                  borderRadius: const BorderRadius.vertical(
                    top: Radius.circular(6),
                  ),
                ),
              ],
            );
          }),
        ),
        duration: const Duration(milliseconds: 450),
        curve: Curves.easeOutCubic,
      ),
    );
  }
}

class _ReviewQueuePanel extends StatelessWidget {
  const _ReviewQueuePanel({required this.items});

  final List<_QueueItemData> items;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      title: 'Priority Queue',
      subtitle: items.isEmpty
          ? 'No pending items need attention'
          : '${items.length} items surfaced from live data',
      icon: Icons.rate_review_rounded,
      action: _StatusPill(
        text: items.isEmpty ? 'Clear' : 'Review',
        color: items.isEmpty ? AppTheme.success : AppTheme.warning,
      ),
      child: items.isEmpty
          ? const _EmbeddedEmpty(
              icon: Icons.task_alt_rounded,
              title: 'Queue clear',
              message:
                  'Flagged posts, urgent welfare cases, and partner reviews will land here.',
            )
          : Column(
              children: items
                  .map(
                    (item) => _MiniActivity(
                      icon: item.icon,
                      title: item.title,
                      subtitle: item.subtitle,
                      status: item.status,
                      color: item.color,
                      onTap: item.onOpen,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.statusColor,
    this.metadata = const [],
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Color statusColor;
  final List<_InfoMeta> metadata;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
        boxShadow: AppTheme.softShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: statusColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w900,
                        color: AppTheme.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text(
                      subtitle,
                      maxLines: 3,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        color: AppTheme.textSecondary,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              _StatusPill(text: status, color: statusColor),
            ],
          ),
          if (metadata.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: metadata
                  .map(
                    (meta) => Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.surfaceCard,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AppTheme.border),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            meta.icon,
                            size: 14,
                            color: AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 5),
                          ConstrainedBox(
                            constraints: const BoxConstraints(maxWidth: 260),
                            child: Text(
                              meta.label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                color: AppTheme.textSecondary,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                  .toList(),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(spacing: 4, runSpacing: 4, children: actions),
          ],
        ],
      ),
    );
  }
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({required this.actions});

  final List<_AdminAction> actions;

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 220,
        mainAxisExtent: 52,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return OutlinedButton.icon(
          onPressed: action.onPressed,
          icon: Icon(action.icon, size: 18),
          label: Text(
            action.label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          style: OutlinedButton.styleFrom(
            alignment: Alignment.centerLeft,
            foregroundColor: AppTheme.primary,
            side: const BorderSide(color: AppTheme.border),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
            backgroundColor: Colors.white,
          ),
        );
      },
    );
  }
}

class _MiniActivity extends StatelessWidget {
  const _MiniActivity({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.color,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String status;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surfaceCard,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.inter(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          _StatusPill(text: status, color: color),
        ],
      ),
    );

    if (onTap == null) {
      return row;
    }

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: row,
    );
  }
}

class _HealthRow extends StatelessWidget {
  const _HealthRow({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    required this.progress,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;
  final double progress;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: color, size: 20),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: GoogleFonts.plusJakartaSans(
                      color: color,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(99),
                child: LinearProgressIndicator(
                  minHeight: 5,
                  value: progress.clamp(0, 1),
                  color: color,
                  backgroundColor: color.withValues(alpha: 0.12),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    required this.color,
    this.onDark = false,
  });

  final String text;
  final Color color;
  final bool onDark;

  @override
  Widget build(BuildContext context) {
    final foreground = onDark ? Colors.white : color;
    final background = onDark
        ? Colors.white.withValues(alpha: 0.14)
        : color.withValues(alpha: 0.1);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: onDark
              ? Colors.white.withValues(alpha: 0.18)
              : color.withValues(alpha: 0.16),
        ),
      ),
      child: Text(
        text,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: GoogleFonts.inter(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}

class _EmbeddedEmpty extends StatelessWidget {
  const _EmbeddedEmpty({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        children: [
          Icon(icon, size: 46, color: AppTheme.textHint),
          const SizedBox(height: 10),
          Text(
            title,
            textAlign: TextAlign.center,
            style: GoogleFonts.plusJakartaSans(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            message,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              color: AppTheme.textSecondary,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(color: AppTheme.primary),
          const SizedBox(height: 12),
          Text(label, style: GoogleFonts.inter(color: AppTheme.textSecondary)),
        ],
      ),
    );
  }
}

class _ErrorPanel extends StatelessWidget {
  const _ErrorPanel({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: _EmbeddedEmpty(
          icon: Icons.error_outline_rounded,
          title: 'Admin data unavailable',
          message: message,
        ),
      ),
    );
  }
}

class _AdminStats {
  const _AdminStats({
    required this.users,
    required this.activeUsers,
    required this.suspendedUsers,
    required this.verifiedUsers,
    required this.adminUsers,
    required this.forumPosts,
    required this.flaggedPosts,
    required this.removedPosts,
    required this.partners,
    required this.activePartners,
    required this.hiddenPartners,
    required this.unapprovedPartners,
    required this.welfareCases,
    required this.pendingCases,
    required this.urgentCases,
    required this.resolvedCases,
  });

  final int users;
  final int activeUsers;
  final int suspendedUsers;
  final int verifiedUsers;
  final int adminUsers;
  final int forumPosts;
  final int flaggedPosts;
  final int removedPosts;
  final int partners;
  final int activePartners;
  final int hiddenPartners;
  final int unapprovedPartners;
  final int welfareCases;
  final int pendingCases;
  final int urgentCases;
  final int resolvedCases;

  int get reviewLoad => flaggedPosts + pendingCases + unapprovedPartners;

  double get userHealth => users == 0 ? 1 : activeUsers / users;

  double get forumHealth =>
      forumPosts == 0 ? 1 : 1 - (flaggedPosts / forumPosts);

  double get partnerHealth => partners == 0 ? 1 : activePartners / partners;

  double get welfarePressure => welfareCases == 0
      ? 0
      : (pendingCases / welfareCases).clamp(0, 1).toDouble();

  static _AdminStats from({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> posts,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> partners,
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> welfare,
  }) {
    final suspendedUsers = users
        .where((doc) => doc.data()['accountStatus'] == 'suspended')
        .length;
    final activeUsers = users.length - suspendedUsers;
    final verifiedUsers = users
        .where((doc) => doc.data()['emailVerified'] == true)
        .length;
    final adminUsers = users
        .where(
          (doc) =>
              doc.data()['role'] == 'admin' ||
              doc.data()['email'] == AppConstants.adminEmail,
        )
        .length;
    final flaggedPosts = posts
        .where((doc) => doc.data()['moderationStatus'] == 'flagged')
        .length;
    final removedPosts = posts
        .where((doc) => doc.data()['moderationStatus'] == 'removed')
        .length;
    final activePartners = partners
        .where(
          (doc) =>
              (doc.data()['status'] ?? 'active') == 'active' &&
              (doc.data()['approved'] ?? true) == true,
        )
        .length;
    final unapprovedPartners = partners
        .where((doc) => (doc.data()['approved'] ?? true) != true)
        .length;
    final pendingCases = welfare
        .where((doc) => (doc.data()['status'] ?? 'pending') == 'pending')
        .length;
    final urgentCases = welfare
        .where(
          (doc) =>
              (doc.data()['priority'] ?? 'normal') == 'urgent' &&
              (doc.data()['status'] ?? 'pending') == 'pending',
        )
        .length;
    final resolvedCases = welfare
        .where((doc) => (doc.data()['status'] ?? 'pending') == 'resolved')
        .length;

    return _AdminStats(
      users: users.length,
      activeUsers: activeUsers,
      suspendedUsers: suspendedUsers,
      verifiedUsers: verifiedUsers,
      adminUsers: adminUsers,
      forumPosts: posts.length,
      flaggedPosts: flaggedPosts,
      removedPosts: removedPosts,
      partners: partners.length,
      activePartners: activePartners,
      hiddenPartners: partners.length - activePartners,
      unapprovedPartners: unapprovedPartners,
      welfareCases: welfare.length,
      pendingCases: pendingCases,
      urgentCases: urgentCases,
      resolvedCases: resolvedCases,
    );
  }
}

class _UserTabStats {
  const _UserTabStats({
    required this.total,
    required this.active,
    required this.suspended,
    required this.verified,
    required this.authSynced,
    required this.authDisabled,
  });

  final int total;
  final int active;
  final int suspended;
  final int verified;
  final int authSynced;
  final int authDisabled;

  static _UserTabStats from(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> users,
  ) {
    final suspended = users
        .where((doc) => doc.data()['accountStatus'] == 'suspended')
        .length;
    final verified = users
        .where((doc) => doc.data()['emailVerified'] == true)
        .length;
    final authSynced = users
        .where((doc) => doc.data()['authSyncedAt'] != null)
        .length;
    final authDisabled = users
        .where((doc) => doc.data()['authDisabled'] == true)
        .length;
    return _UserTabStats(
      total: users.length,
      active: users.length - suspended,
      suspended: suspended,
      verified: verified,
      authSynced: authSynced,
      authDisabled: authDisabled,
    );
  }
}

class _MetricItem {
  const _MetricItem({
    required this.label,
    required this.value,
    required this.detail,
    required this.icon,
    required this.color,
    this.progress,
  });

  final String label;
  final String value;
  final String detail;
  final IconData icon;
  final Color color;
  final double? progress;
}

class _SummaryItem {
  const _SummaryItem(this.label, this.value, this.color);

  final String label;
  final String value;
  final Color color;
}

class _InfoMeta {
  const _InfoMeta(this.icon, this.label);

  final IconData icon;
  final String label;
}

class _QueueItemData {
  const _QueueItemData({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onOpen,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final String status;
  final VoidCallback onOpen;
}

class _ChartDatum {
  const _ChartDatum(this.label, this.value, this.color);

  final String label;
  final double value;
  final Color color;
}

class _AdminAction {
  const _AdminAction(this.label, this.icon, this.onPressed);

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
}

class _AdminTab {
  const _AdminTab(this.label, this.icon);

  final String label;
  final IconData icon;
}
