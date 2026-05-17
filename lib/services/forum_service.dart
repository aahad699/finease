import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import '../models/forum_models.dart';

class ForumService {
  ForumService._();

  static final ForumService instance = ForumService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<String> createPost({
    required String authorId,
    required String authorName,
    required String authorAvatar,
    required String title,
    required String content,
    required String category,
    required PostType postType,
    List<String> tags = const [],
    List<String> pollOptions = const [],
    bool isAnonymous = false,
    String languageCode = 'en',
  }) async {
    final normalizedTags = _normalizeTags(tags);
    final normalizedPollOptions = pollOptions
        .map((option) => option.trim())
        .where((option) => option.isNotEmpty)
        .take(6)
        .toList(growable: false);
    final reputation = authorId.isEmpty
        ? const UserReputation(userId: '')
        : await getUserReputation(authorId);

    final docRef = await _db.collection('forum_posts').add({
      'schemaVersion': 2,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'authorReputationPoints': reputation.points,
      'authorBadges': reputation.badges.map((badge) => badge.name).toList(),
      'title': title,
      'content': content,
      'category': category,
      'postType': postType.name,
      'tags': normalizedTags,
      'languageCode': languageCode,
      'isAnonymous': isAnonymous,
      'reactions': <Map<String, dynamic>>[],
      'reactionCounts': _emptyReactionCounts(),
      'likes': 0,
      'likesCount': 0,
      'comments': 0,
      'commentCount': 0,
      'commentsCount': 0,
      'engagementScore': 0.0,
      'hotScore': 0.0,
      'moderationStatus': ModerationStatus.visible.name,
      'pinnedCommentId': null,
      'aiSummary': null,
      'aiInsights': <String>[],
      'aiHooks': <String, dynamic>{},
      'pollOptions': postType == PostType.poll
          ? normalizedPollOptions
          : <String>[],
      'pollVotes': <String, int>{},
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (authorId.isNotEmpty) {
      await updateReputation(
        userId: authorId,
        pointsToAdd: 5,
        incrementPostCount: true,
      );
    }

    debugPrint('[ForumService] Created post: ${docRef.id}');
    return docRef.id;
  }

  Stream<List<ForumPost>> watchPosts({
    String? category,
    PostType? postType,
    List<String>? tags,
    String sortBy = 'createdAt',
    int limit = 80,
  }) {
    Query<Map<String, dynamic>> query = _db.collection('forum_posts');

    if (category != null && category != 'All') {
      query = query.where('category', isEqualTo: category);
    }

    if (postType != null) {
      query = query.where('postType', isEqualTo: postType.name);
    }

    final normalizedTags = _normalizeTags(tags ?? const []);
    if (normalizedTags.isNotEmpty) {
      query = query.where('tags', arrayContains: normalizedTags.first);
    }

    query = query.orderBy('createdAt', descending: true).limit(limit);

    return query.snapshots().map((snapshot) {
      final posts = snapshot.docs
          .map(ForumPost.fromFirestore)
          .where((post) => post.moderationStatus.canRender)
          .where((post) => _matchesAllTags(post, normalizedTags))
          .toList(growable: false);

      return _rankPosts(posts, sortBy);
    });
  }

  Future<ForumPost?> getPost(String postId) async {
    final doc = await _db.collection('forum_posts').doc(postId).get();
    if (!doc.exists) return null;
    return ForumPost.fromFirestore(doc);
  }

  Future<void> togglePostReaction({
    required String postId,
    required String userId,
    required ReactionType reactionType,
  }) async {
    if (userId.isEmpty) return;

    final postRef = _db.collection('forum_posts').doc(postId);
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(postRef);
      if (!snapshot.exists) return;

      final post = ForumPost.fromFirestore(snapshot);
      final reactions = List<Reaction>.from(post.reactions);
      final existingIndex = reactions.indexWhere(
        (reaction) => reaction.userId == userId,
      );

      if (existingIndex >= 0 && reactions[existingIndex].type == reactionType) {
        reactions.removeAt(existingIndex);
      } else if (existingIndex >= 0) {
        reactions[existingIndex] = Reaction(
          userId: userId,
          type: reactionType,
          createdAt: DateTime.now(),
        );
      } else {
        reactions.add(
          Reaction(
            userId: userId,
            type: reactionType,
            createdAt: DateTime.now(),
          ),
        );
      }

      final reactionCounts = _reactionCountsFromList(reactions);
      final engagementScore = _calculateEngagementScore(
        reactions.length,
        post.commentsCount,
      );

      transaction.update(postRef, {
        'reactions': reactions.map((reaction) => reaction.toMap()).toList(),
        'reactionCounts': reactionCounts,
        'likes': reactionCounts[ReactionType.like.name] ?? 0,
        'likesCount': reactionCounts[ReactionType.like.name] ?? 0,
        'engagementScore': engagementScore,
        'hotScore': _calculateHotScore(
          engagementScore: engagementScore,
          createdAt: post.createdAt,
        ),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<ReactionType?> getUserPostReaction({
    required String postId,
    required String userId,
  }) async {
    if (userId.isEmpty) return null;
    final post = await getPost(postId);
    return post?.userReaction(userId);
  }

  Future<String> createComment({
    required String postId,
    required String authorId,
    required String authorName,
    required String authorAvatar,
    required String content,
    bool isAnonymous = false,
    String? parentCommentId,
  }) async {
    final postRef = _db.collection('forum_posts').doc(postId);
    final commentRef = postRef.collection('comments').doc();
    final reputation = authorId.isEmpty
        ? const UserReputation(userId: '')
        : await getUserReputation(authorId);

    final batch = _db.batch();
    batch.set(commentRef, {
      'schemaVersion': 2,
      'postId': postId,
      'authorId': authorId,
      'authorName': authorName,
      'authorAvatar': authorAvatar,
      'authorReputationPoints': reputation.points,
      'authorBadges': reputation.badges.map((badge) => badge.name).toList(),
      'content': content,
      'isAnonymous': isAnonymous,
      'isBestAnswer': false,
      'parentCommentId': parentCommentId,
      'replyCount': 0,
      'reactions': <Map<String, dynamic>>[],
      'reactionCounts': _emptyReactionCounts(),
      'moderationStatus': ModerationStatus.visible.name,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    batch.update(postRef, {
      'comments': FieldValue.increment(1),
      'commentCount': FieldValue.increment(1),
      'commentsCount': FieldValue.increment(1),
      'engagementScore': FieldValue.increment(3),
      'updatedAt': FieldValue.serverTimestamp(),
    });

    if (parentCommentId != null && parentCommentId.isNotEmpty) {
      batch.update(postRef.collection('comments').doc(parentCommentId), {
        'replyCount': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    if (authorId.isNotEmpty) {
      await updateReputation(userId: authorId, pointsToAdd: 2);
    }

    debugPrint('[ForumService] Created comment: ${commentRef.id}');
    return commentRef.id;
  }

  Stream<List<ForumComment>> watchComments(String postId) {
    return _db
        .collection('forum_posts')
        .doc(postId)
        .collection('comments')
        .orderBy('createdAt')
        .snapshots()
        .map((snapshot) {
          final comments = snapshot.docs
              .map(ForumComment.fromFirestore)
              .where((comment) => comment.moderationStatus.canRender)
              .toList();

          comments.sort(_compareComments);
          return comments;
        });
  }

  Future<void> toggleCommentReaction({
    required String postId,
    required String commentId,
    required String userId,
    required ReactionType reactionType,
  }) async {
    if (userId.isEmpty) return;

    final commentRef = _db
        .collection('forum_posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId);

    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(commentRef);
      if (!snapshot.exists) return;

      final comment = ForumComment.fromFirestore(snapshot);
      final reactions = List<Reaction>.from(comment.reactions);
      final existingIndex = reactions.indexWhere(
        (reaction) => reaction.userId == userId,
      );

      if (existingIndex >= 0 && reactions[existingIndex].type == reactionType) {
        reactions.removeAt(existingIndex);
      } else if (existingIndex >= 0) {
        reactions[existingIndex] = Reaction(
          userId: userId,
          type: reactionType,
          createdAt: DateTime.now(),
        );
      } else {
        reactions.add(
          Reaction(
            userId: userId,
            type: reactionType,
            createdAt: DateTime.now(),
          ),
        );
      }

      transaction.update(commentRef, {
        'reactions': reactions.map((reaction) => reaction.toMap()).toList(),
        'reactionCounts': _reactionCountsFromList(reactions),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    });
  }

  Future<void> markBestAnswer({
    required String postId,
    required String commentId,
  }) async {
    final postRef = _db.collection('forum_posts').doc(postId);
    final comments = await postRef.collection('comments').get();
    final batch = _db.batch();

    for (final doc in comments.docs) {
      batch.update(doc.reference, {'isBestAnswer': doc.id == commentId});
    }

    batch.update(postRef, {
      'pinnedCommentId': commentId,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    await batch.commit();
    debugPrint('[ForumService] Marked comment $commentId as best answer');
  }

  Future<UserReputation> getUserReputation(String userId) async {
    if (userId.isEmpty) return const UserReputation(userId: '');
    final doc = await _db.collection('user_reputation').doc(userId).get();
    if (!doc.exists) return UserReputation(userId: userId);
    return UserReputation.fromMap(doc.data() ?? {}, userId: userId);
  }

  Future<void> updateReputation({
    required String userId,
    int pointsToAdd = 0,
    bool markHelpful = false,
    bool incrementPostCount = false,
  }) async {
    if (userId.isEmpty) return;

    final data = <String, dynamic>{
      'points': FieldValue.increment(pointsToAdd),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (markHelpful) {
      data['helpfulCount'] = FieldValue.increment(1);
    }

    if (incrementPostCount) {
      data['postCount'] = FieldValue.increment(1);
    }

    await _db
        .collection('user_reputation')
        .doc(userId)
        .set(data, SetOptions(merge: true));
  }

  Future<String?> generatePostSummary(String postId) async {
    await _queueAiHook(postId, 'summary');
    debugPrint('[ForumService] Queued summary hook for post: $postId');
    return null;
  }

  Future<String?> suggestFinancialAdvice(String postId) async {
    await _queueAiHook(postId, 'financialAdvice');
    debugPrint('[ForumService] Queued financial advice hook for post: $postId');
    return null;
  }

  Future<List<String>?> detectKeyInsights(String postId) async {
    await _queueAiHook(postId, 'keyInsights');
    debugPrint('[ForumService] Queued key insights hook for post: $postId');
    return null;
  }

  Future<void> updatePostModerationStatus({
    required String postId,
    required ModerationStatus status,
  }) async {
    await _db.collection('forum_posts').doc(postId).update({
      'moderationStatus': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    debugPrint(
      '[ForumService] Updated post moderation status to: ${status.name}',
    );
  }

  Future<void> updateCommentModerationStatus({
    required String postId,
    required String commentId,
    required ModerationStatus status,
  }) async {
    await _db
        .collection('forum_posts')
        .doc(postId)
        .collection('comments')
        .doc(commentId)
        .update({
          'moderationStatus': status.name,
          'updatedAt': FieldValue.serverTimestamp(),
        });
    debugPrint(
      '[ForumService] Updated comment moderation status to: ${status.name}',
    );
  }

  Future<void> _queueAiHook(String postId, String action) async {
    await _db.collection('forum_posts').doc(postId).set({
      'aiHooks': {
        action: {
          'status': 'queued',
          'requestedAt': FieldValue.serverTimestamp(),
        },
      },
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  List<ForumPost> _rankPosts(List<ForumPost> posts, String sortBy) {
    final ranked = List<ForumPost>.from(posts);

    if (sortBy == 'hotScore') {
      ranked.sort((a, b) {
        final scoreCompare = _effectiveHotScore(
          b,
        ).compareTo(_effectiveHotScore(a));
        if (scoreCompare != 0) return scoreCompare;
        return _compareDatesDesc(a.createdAt, b.createdAt);
      });
      return ranked;
    }

    if (sortBy == 'engagementScore') {
      ranked.sort((a, b) {
        final scoreCompare = _effectiveEngagementScore(
          b,
        ).compareTo(_effectiveEngagementScore(a));
        if (scoreCompare != 0) return scoreCompare;
        return _compareDatesDesc(a.createdAt, b.createdAt);
      });
      return ranked;
    }

    ranked.sort((a, b) => _compareDatesDesc(a.createdAt, b.createdAt));
    return ranked;
  }

  bool _matchesAllTags(ForumPost post, List<String> tags) {
    if (tags.isEmpty) return true;
    final postTags = post.tags.map((tag) => tag.toLowerCase()).toSet();
    return tags.every(postTags.contains);
  }

  double _effectiveEngagementScore(ForumPost post) {
    if (post.engagementScore > 0) return post.engagementScore;
    return _calculateEngagementScore(post.totalReactions, post.commentsCount);
  }

  double _effectiveHotScore(ForumPost post) {
    if (post.hotScore > 0) return post.hotScore;
    return _calculateHotScore(
      engagementScore: _effectiveEngagementScore(post),
      createdAt: post.createdAt,
    );
  }

  double _calculateEngagementScore(int reactionsCount, int commentsCount) {
    return (reactionsCount * 1.5) + (commentsCount * 3);
  }

  double _calculateHotScore({
    required double engagementScore,
    required DateTime? createdAt,
  }) {
    final ageHours = createdAt == null
        ? 1.0
        : math.max(1.0, DateTime.now().difference(createdAt).inMinutes / 60);
    return engagementScore / math.pow(ageHours + 2, 1.15);
  }
}

int _compareComments(ForumComment a, ForumComment b) {
  if (a.isBestAnswer != b.isBestAnswer) {
    return a.isBestAnswer ? -1 : 1;
  }
  if (a.isReply != b.isReply) {
    return a.isReply ? 1 : -1;
  }
  return (a.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0)).compareTo(
    b.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0),
  );
}

int _compareDatesDesc(DateTime? a, DateTime? b) {
  final left = a ?? DateTime.fromMillisecondsSinceEpoch(0);
  final right = b ?? DateTime.fromMillisecondsSinceEpoch(0);
  return right.compareTo(left);
}

List<String> _normalizeTags(List<String> tags) {
  return tags
      .map((tag) => tag.trim().replaceFirst(RegExp(r'^#+'), '').toLowerCase())
      .where((tag) => tag.isNotEmpty)
      .toSet()
      .take(8)
      .toList(growable: false);
}

Map<String, int> _emptyReactionCounts() {
  return {for (final type in ReactionType.values) type.name: 0};
}

Map<String, int> _reactionCountsFromList(List<Reaction> reactions) {
  final counts = _emptyReactionCounts();
  for (final reaction in reactions) {
    counts.update(reaction.type.name, (value) => value + 1);
  }
  return counts;
}
