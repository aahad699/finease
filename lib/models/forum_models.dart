import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

enum PostType {
  question('Question', Icons.help_outline_rounded, Color(0xFF2E3192)),
  poll('Poll', Icons.poll_rounded, Color(0xFF7C3AED)),
  story('Success Story', Icons.emoji_events_rounded, Color(0xFFD97706)),
  tip('Financial Tip', Icons.lightbulb_outline_rounded, Color(0xFF0F766E)),
  update('Progress Update', Icons.trending_up_rounded, Color(0xFF059669));

  const PostType(this.label, this.icon, this.color);

  final String label;
  final IconData icon;
  final Color color;

  static PostType fromName(Object? value) {
    return PostType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => PostType.question,
    );
  }
}

enum ReactionType {
  like('Like', Icons.thumb_up_outlined, Icons.thumb_up_rounded),
  helpful(
    'Helpful',
    Icons.check_circle_outline_rounded,
    Icons.check_circle_rounded,
  ),
  inspiring(
    'Inspiring',
    Icons.favorite_outline_rounded,
    Icons.favorite_rounded,
  ),
  insightful(
    'Insightful',
    Icons.lightbulb_outline_rounded,
    Icons.lightbulb_rounded,
  );

  const ReactionType(this.label, this.outlineIcon, this.filledIcon);

  final String label;
  final IconData outlineIcon;
  final IconData filledIcon;

  static ReactionType fromName(Object? value) {
    return ReactionType.values.firstWhere(
      (type) => type.name == value,
      orElse: () => ReactionType.like,
    );
  }
}

enum ModerationStatus {
  visible,
  hidden,
  flagged,
  removed;

  static ModerationStatus fromName(Object? value) {
    return ModerationStatus.values.firstWhere(
      (status) => status.name == value,
      orElse: () => ModerationStatus.visible,
    );
  }

  bool get canRender =>
      this == ModerationStatus.visible || this == ModerationStatus.flagged;
}

enum ReputationBadge {
  helpfulContributor('Helpful Contributor', Icons.verified_outlined),
  knowledgeSharer('Knowledge Sharer', Icons.school_rounded),
  communityLeader('Community Leader', Icons.star_rounded),
  mentor('Mentor', Icons.groups_rounded);

  const ReputationBadge(this.label, this.icon);

  final String label;
  final IconData icon;

  static ReputationBadge fromName(Object? value) {
    return ReputationBadge.values.firstWhere(
      (badge) => badge.name == value,
      orElse: () => ReputationBadge.helpfulContributor,
    );
  }
}

class UserReputation {
  const UserReputation({
    required this.userId,
    this.points = 0,
    this.badges = const [],
    this.postCount = 0,
    this.helpfulCount = 0,
    this.reputationScore = 0,
  });

  final String userId;
  final int points;
  final List<ReputationBadge> badges;
  final int postCount;
  final int helpfulCount;
  final double reputationScore;

  factory UserReputation.fromMap(
    Map<String, dynamic> map, {
    required String userId,
  }) {
    return UserReputation(
      userId: userId,
      points: _readInt(map['points']),
      badges: _readStringList(
        map['badges'],
      ).map(ReputationBadge.fromName).toList(growable: false),
      postCount: _readInt(map['postCount']),
      helpfulCount: _readInt(map['helpfulCount']),
      reputationScore: _readDouble(map['reputationScore']),
    );
  }

  Map<String, dynamic> toMap() => {
    'points': points,
    'badges': badges.map((badge) => badge.name).toList(),
    'postCount': postCount,
    'helpfulCount': helpfulCount,
    'reputationScore': reputationScore,
  };
}

class Reaction {
  const Reaction({
    required this.userId,
    required this.type,
    required this.createdAt,
  });

  final String userId;
  final ReactionType type;
  final DateTime createdAt;

  factory Reaction.fromMap(Map<String, dynamic> map) {
    return Reaction(
      userId: map['userId'] as String? ?? '',
      type: ReactionType.fromName(map['type']),
      createdAt: _readDate(map['createdAt']) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() => {
    'userId': userId,
    'type': type.name,
    'createdAt': Timestamp.fromDate(createdAt),
  };
}

class ForumComment {
  const ForumComment({
    required this.id,
    required this.postId,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.content,
    this.isAnonymous = false,
    this.isBestAnswer = false,
    this.parentCommentId,
    this.replyCount = 0,
    this.reactions = const [],
    this.reactionCounts = const {},
    this.moderationStatus = ModerationStatus.visible,
    this.authorReputationPoints = 0,
    this.authorBadges = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String postId;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String content;
  final bool isAnonymous;
  final bool isBestAnswer;
  final String? parentCommentId;
  final int replyCount;
  final List<Reaction> reactions;
  final Map<ReactionType, int> reactionCounts;
  final ModerationStatus moderationStatus;
  final int authorReputationPoints;
  final List<ReputationBadge> authorBadges;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isReply => parentCommentId != null && parentCommentId!.isNotEmpty;

  String get displayName {
    if (isAnonymous) return 'Anonymous learner';
    return authorName.trim().isEmpty ? 'FinEase User' : authorName.trim();
  }

  String get displayAvatar => isAnonymous ? '' : authorAvatar;

  int get totalReactions {
    if (reactionCounts.isNotEmpty) {
      return reactionCounts.values.fold<int>(
        0,
        (total, value) => total + value,
      );
    }
    return reactions.length;
  }

  int reactionCount(ReactionType type) {
    return reactionCounts[type] ??
        reactions.where((r) => r.type == type).length;
  }

  ReactionType? userReaction(String userId) {
    if (userId.isEmpty) return null;
    for (final reaction in reactions) {
      if (reaction.userId == userId) return reaction.type;
    }
    return null;
  }

  factory ForumComment.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return ForumComment.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory ForumComment.fromMap(Map<String, dynamic> map, {required String id}) {
    final reactions = _readReactions(map['reactions']);
    return ForumComment(
      id: id,
      postId: map['postId'] as String? ?? '',
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? 'FinEase User',
      authorAvatar: map['authorAvatar'] as String? ?? '',
      content: map['content'] as String? ?? '',
      isAnonymous: map['isAnonymous'] as bool? ?? false,
      isBestAnswer: map['isBestAnswer'] as bool? ?? false,
      parentCommentId: map['parentCommentId'] as String?,
      replyCount: _readInt(map['replyCount']),
      reactions: reactions,
      reactionCounts: _readReactionCounts(
        map['reactionCounts'],
        fallbackReactions: reactions,
      ),
      moderationStatus: ModerationStatus.fromName(map['moderationStatus']),
      authorReputationPoints: _readInt(map['authorReputationPoints']),
      authorBadges: _readStringList(
        map['authorBadges'],
      ).map(ReputationBadge.fromName).toList(growable: false),
      createdAt: _readDate(map['createdAt']),
      updatedAt: _readDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'postId': postId,
    'authorId': authorId,
    'authorName': authorName,
    'authorAvatar': authorAvatar,
    'content': content,
    'isAnonymous': isAnonymous,
    'isBestAnswer': isBestAnswer,
    'parentCommentId': parentCommentId,
    'replyCount': replyCount,
    'reactions': reactions.map((reaction) => reaction.toMap()).toList(),
    'reactionCounts': _reactionCountsToMap(reactionCounts),
    'moderationStatus': moderationStatus.name,
    'authorReputationPoints': authorReputationPoints,
    'authorBadges': authorBadges.map((badge) => badge.name).toList(),
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

class ForumPost {
  const ForumPost({
    required this.id,
    required this.title,
    required this.content,
    required this.authorId,
    required this.authorName,
    required this.authorAvatar,
    required this.category,
    required this.postType,
    this.tags = const [],
    this.languageCode = 'en',
    this.isAnonymous = false,
    this.reactions = const [],
    this.reactionCounts = const {},
    this.likesCount = 0,
    this.commentsCount = 0,
    this.engagementScore = 0,
    this.hotScore = 0,
    this.moderationStatus = ModerationStatus.visible,
    this.pinnedCommentId,
    this.aiSummary,
    this.aiInsights = const [],
    this.pollOptions = const [],
    this.pollVotes = const {},
    this.authorReputationPoints = 0,
    this.authorBadges = const [],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final String content;
  final String authorId;
  final String authorName;
  final String authorAvatar;
  final String category;
  final PostType postType;
  final List<String> tags;
  final String languageCode;
  final bool isAnonymous;
  final List<Reaction> reactions;
  final Map<ReactionType, int> reactionCounts;
  final int likesCount;
  final int commentsCount;
  final double engagementScore;
  final double hotScore;
  final ModerationStatus moderationStatus;
  final String? pinnedCommentId;
  final String? aiSummary;
  final List<String> aiInsights;
  final List<String> pollOptions;
  final Map<String, int> pollVotes;
  final int authorReputationPoints;
  final List<ReputationBadge> authorBadges;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  int get commentCount => commentsCount;

  String get displayAuthorName {
    if (isAnonymous) return 'Anonymous learner';
    return authorName.trim().isEmpty ? 'FinEase User' : authorName.trim();
  }

  String get displayAuthorAvatar => isAnonymous ? '' : authorAvatar;

  bool get hasPinnedAnswer =>
      pinnedCommentId != null && pinnedCommentId!.isNotEmpty;

  int get totalReactions {
    if (reactionCounts.isNotEmpty) {
      return reactionCounts.values.fold<int>(
        0,
        (total, value) => total + value,
      );
    }
    return reactions.length;
  }

  int reactionCount(ReactionType type) {
    return reactionCounts[type] ??
        reactions.where((r) => r.type == type).length;
  }

  ReactionType? userReaction(String userId) {
    if (userId.isEmpty) return null;
    for (final reaction in reactions) {
      if (reaction.userId == userId) return reaction.type;
    }
    return null;
  }

  factory ForumPost.fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return ForumPost.fromMap(doc.data() ?? {}, id: doc.id);
  }

  factory ForumPost.fromMap(Map<String, dynamic> map, {required String id}) {
    final reactions = _readReactions(map['reactions']);
    final reactionCounts = _readReactionCounts(
      map['reactionCounts'],
      fallbackReactions: reactions,
    );
    final legacyLikes = _readInt(map['likes']);
    final likesCount = _readInt(
      map['likesCount'],
      fallback: reactionCounts[ReactionType.like] ?? legacyLikes,
    );

    return ForumPost(
      id: id,
      title: map['title'] as String? ?? '',
      content: map['content'] as String? ?? '',
      authorId: map['authorId'] as String? ?? '',
      authorName: map['authorName'] as String? ?? 'FinEase User',
      authorAvatar: map['authorAvatar'] as String? ?? '',
      category: map['category'] as String? ?? 'General',
      postType: PostType.fromName(map['postType']),
      tags: _readStringList(map['tags']),
      languageCode: map['languageCode'] as String? ?? 'en',
      isAnonymous: map['isAnonymous'] as bool? ?? false,
      reactions: reactions,
      reactionCounts: reactionCounts,
      likesCount: likesCount,
      commentsCount: _readInt(
        map['commentsCount'],
        fallback: _readInt(
          map['commentCount'],
          fallback: _readInt(map['comments']),
        ),
      ),
      engagementScore: _readDouble(map['engagementScore']),
      hotScore: _readDouble(map['hotScore']),
      moderationStatus: ModerationStatus.fromName(map['moderationStatus']),
      pinnedCommentId: map['pinnedCommentId'] as String?,
      aiSummary: map['aiSummary'] as String?,
      aiInsights: _readStringList(map['aiInsights']),
      pollOptions: _readStringList(map['pollOptions']),
      pollVotes: _readStringIntMap(map['pollVotes']),
      authorReputationPoints: _readInt(map['authorReputationPoints']),
      authorBadges: _readStringList(
        map['authorBadges'],
      ).map(ReputationBadge.fromName).toList(growable: false),
      createdAt: _readDate(map['createdAt']),
      updatedAt: _readDate(map['updatedAt']),
    );
  }

  Map<String, dynamic> toMap() => {
    'title': title,
    'content': content,
    'authorId': authorId,
    'authorName': authorName,
    'authorAvatar': authorAvatar,
    'category': category,
    'postType': postType.name,
    'tags': tags,
    'languageCode': languageCode,
    'isAnonymous': isAnonymous,
    'reactions': reactions.map((reaction) => reaction.toMap()).toList(),
    'reactionCounts': _reactionCountsToMap(reactionCounts),
    'likes': likesCount,
    'likesCount': likesCount,
    'comments': commentsCount,
    'commentCount': commentsCount,
    'commentsCount': commentsCount,
    'engagementScore': engagementScore,
    'hotScore': hotScore,
    'moderationStatus': moderationStatus.name,
    'pinnedCommentId': pinnedCommentId,
    'aiSummary': aiSummary,
    'aiInsights': aiInsights,
    'pollOptions': pollOptions,
    'pollVotes': pollVotes,
    'authorReputationPoints': authorReputationPoints,
    'authorBadges': authorBadges.map((badge) => badge.name).toList(),
    'createdAt': FieldValue.serverTimestamp(),
    'updatedAt': FieldValue.serverTimestamp(),
  };
}

DateTime? _readDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is DateTime) return value;
  return null;
}

int _readInt(Object? value, {int fallback = 0}) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return fallback;
}

double _readDouble(Object? value, {double fallback = 0}) {
  if (value is double) return value;
  if (value is num) return value.toDouble();
  return fallback;
}

List<String> _readStringList(Object? value) {
  if (value is Iterable) {
    return value
        .whereType<Object>()
        .map((item) => item.toString().trim())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

Map<String, int> _readStringIntMap(Object? value) {
  if (value is! Map) return const {};
  return value.map((key, val) => MapEntry(key.toString(), _readInt(val)));
}

List<Reaction> _readReactions(Object? value) {
  if (value is! Iterable) return const [];
  return value
      .whereType<Map>()
      .map((reaction) => Reaction.fromMap(Map<String, dynamic>.from(reaction)))
      .where((reaction) => reaction.userId.isNotEmpty)
      .toList(growable: false);
}

Map<ReactionType, int> _readReactionCounts(
  Object? value, {
  List<Reaction> fallbackReactions = const [],
}) {
  final counts = <ReactionType, int>{};

  if (value is Map) {
    final raw = Map<String, dynamic>.from(value);
    for (final type in ReactionType.values) {
      final count = _readInt(raw[type.name]);
      if (count > 0) counts[type] = count;
    }
  }

  if (counts.isEmpty && fallbackReactions.isNotEmpty) {
    for (final reaction in fallbackReactions) {
      counts.update(reaction.type, (value) => value + 1, ifAbsent: () => 1);
    }
  }

  return counts;
}

Map<String, int> _reactionCountsToMap(Map<ReactionType, int> counts) {
  return {for (final type in ReactionType.values) type.name: counts[type] ?? 0};
}
