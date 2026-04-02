import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:instagram_clone_flutter_firebase/models/users.dart';

class FeedRanker {
  FeedRanker({
    this.halfLife = const Duration(hours: 6),
    this.freshWindow = const Duration(minutes: 5),
    this.cacheTtl = const Duration(minutes: 2),
  });

  final Duration halfLife;
  final Duration freshWindow;
  final Duration cacheTtl;

  final Map<String, _ScoreCacheEntry> _cache = {};

  List<Map<String, dynamic>> rankPosts({
    required List<Map<String, dynamic>> posts,
    required UserModel viewer,
    DateTime? now,
  }) {
    if (posts.isEmpty) return posts;
    final nowTime = now ?? DateTime.now();
    final scored = <_ScoredPost>[];
    final seenPostIds = <String>{};

    for (final post in posts) {
      final postId = _safeString(post["postId"]);
      if (postId.isNotEmpty) {
        seenPostIds.add(postId);
      }
      final postedAt = _extractPostedAt(post);
      final signature = _scoreSignature(post, viewer, postedAt);
      final cached = postId.isEmpty ? null : _cache[postId];
      if (cached != null &&
          cached.signature == signature &&
          nowTime.difference(cached.computedAt) <= cacheTtl) {
        scored.add(
          _ScoredPost(
            post: post,
            score: cached.score,
            postedAt: postedAt,
            isFresh: cached.isFresh,
          ),
        );
        continue;
      }

      final recency = _recencyScore(postedAt, nowTime);
      final engagement = _engagementScore(post);
      final contentPref = _contentPreferenceScore(post, viewer);
      final interaction = _interactionScore(post, viewer, contentPref);
      final relationship = _relationshipScore(post, viewer);
      final score =
          (recency * 0.5) +
          (engagement * 0.2) +
          (interaction * 0.2) +
          (relationship * 0.1);

      final isFresh = nowTime.difference(postedAt) <= freshWindow;
      if (postId.isNotEmpty) {
        _cache[postId] = _ScoreCacheEntry(
          score: score,
          signature: signature,
          computedAt: nowTime,
          isFresh: isFresh,
        );
      }
      scored.add(
        _ScoredPost(
          post: post,
          score: score,
          postedAt: postedAt,
          isFresh: isFresh,
        ),
      );
    }

    _pruneCache(seenPostIds, nowTime);

    scored.sort((a, b) {
      if (a.isFresh != b.isFresh) {
        return a.isFresh ? -1 : 1;
      }
      if (a.isFresh && b.isFresh) {
        return b.postedAt.compareTo(a.postedAt);
      }
      final scoreCompare = b.score.compareTo(a.score);
      if (scoreCompare != 0) return scoreCompare;
      return b.postedAt.compareTo(a.postedAt);
    });

    return scored.map((item) => item.post).toList();
  }

  DateTime _extractPostedAt(Map<String, dynamic> post) {
    final raw = post["postedDate"] ?? post["createdAt"];
    if (raw is Timestamp) return raw.toDate();
    if (raw is DateTime) return raw;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  double _recencyScore(DateTime postedAt, DateTime nowTime) {
    final ageMinutes = nowTime.difference(postedAt).inMinutes;
    if (ageMinutes <= 0) return 1.0;
    final halfLifeMinutes = halfLife.inMinutes <= 0 ? 360 : halfLife.inMinutes;
    final decay = exp(-ageMinutes / halfLifeMinutes);
    return decay.clamp(0.0, 1.0);
  }

  double _engagementScore(Map<String, dynamic> post) {
    final likes = _safeListLength(post["likes"]);
    final comments = _safeInt(post["commentCount"]);
    final shares = _safeInt(post["shareCount"]);
    final saves = _safeInt(post["saves"]);
    final raw =
        (likes * 1.0) + (comments * 1.5) + (shares * 2.0) + (saves * 2.0);
    if (raw <= 0) return 0.0;
    final score = 1 - exp(-raw / 25);
    return score.clamp(0.0, 1.0);
  }

  double _interactionScore(
    Map<String, dynamic> post,
    UserModel viewer,
    double contentPrefScore,
  ) {
    final ownerUid = _safeString(post["uid"]);
    if (ownerUid.isEmpty) return 0.0;
    double base = 0.0;
    if (ownerUid == viewer.uid) {
      base = 1.0;
    } else if (viewer.following.contains(ownerUid)) {
      base = 0.6;
    }
    if (viewer.followers.contains(ownerUid)) {
      base += 0.2;
    }
    final likes = post["likes"];
    if (likes is List && likes.contains(viewer.uid)) {
      base += 0.1;
    }
    final reachUsers = post["reachUsers"];
    if (reachUsers is List && reachUsers.contains(viewer.uid)) {
      base += 0.05;
    }
    base = base.clamp(0.0, 1.0);
    final blended = (base * 0.7) + (contentPrefScore * 0.3);
    return blended.clamp(0.0, 1.0);
  }

  double _relationshipScore(Map<String, dynamic> post, UserModel viewer) {
    final ownerUid = _safeString(post["uid"]);
    if (ownerUid.isEmpty) return 0.0;
    if (ownerUid == viewer.uid) return 1.0;
    final isMutual = viewer.followers.contains(ownerUid);
    if (isMutual) return 1.0;
    if (viewer.following.contains(ownerUid)) return 0.6;
    return 0.0;
  }

  double _contentPreferenceScore(
    Map<String, dynamic> post,
    UserModel viewer,
  ) {
    final caption = _safeString(post["caption"]).toLowerCase();
    final location = _safeString(post["location"]).toLowerCase();
    final audioName = _safeString(post["audioName"]).toLowerCase();
    final category = viewer.professionalCategory.toLowerCase();
    final profType = viewer.professionalType.toLowerCase();
    final keywords = <String>[
      category,
      profType,
    ]..removeWhere((item) => item.trim().isEmpty);
    if (keywords.isEmpty) return 0.0;
    for (final key in keywords) {
      if (caption.contains(key) ||
          location.contains(key) ||
          audioName.contains(key)) {
        return 1.0;
      }
    }
    return 0.0;
  }

  int _scoreSignature(
    Map<String, dynamic> post,
    UserModel viewer,
    DateTime postedAt,
  ) {
    var hash = _safeString(post["postId"]).hashCode;
    hash = 0x1fffffff & (hash * 31 + _safeInt(post["commentCount"]));
    hash = 0x1fffffff & (hash * 31 + _safeListLength(post["likes"]));
    hash = 0x1fffffff & (hash * 31 + _safeInt(post["shareCount"]));
    hash = 0x1fffffff & (hash * 31 + _safeInt(post["saves"]));
    hash = 0x1fffffff & (hash * 31 + postedAt.millisecondsSinceEpoch ~/ 60000);
    final ownerUid = _safeString(post["uid"]);
    final relKey = ownerUid.isEmpty
        ? 0
        : (viewer.followers.contains(ownerUid) ? 2 : 1);
    hash = 0x1fffffff & (hash * 31 + relKey);
    final liked =
        post["likes"] is List &&
        (post["likes"] as List).contains(viewer.uid);
    hash = 0x1fffffff & (hash * 31 + (liked ? 1 : 0));
    return hash;
  }

  void _pruneCache(Set<String> activePostIds, DateTime nowTime) {
    final expired = <String>[];
    _cache.forEach((key, value) {
      if (!activePostIds.contains(key) ||
          nowTime.difference(value.computedAt) > cacheTtl * 3) {
        expired.add(key);
      }
    });
    for (final key in expired) {
      _cache.remove(key);
    }
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  int _safeListLength(dynamic value) {
    if (value is List) return value.length;
    return 0;
  }

  String _safeString(dynamic value) {
    return (value ?? "").toString();
  }
}

class _ScoreCacheEntry {
  final double score;
  final int signature;
  final DateTime computedAt;
  final bool isFresh;

  const _ScoreCacheEntry({
    required this.score,
    required this.signature,
    required this.computedAt,
    required this.isFresh,
  });
}

class _ScoredPost {
  final Map<String, dynamic> post;
  final double score;
  final DateTime postedAt;
  final bool isFresh;

  const _ScoredPost({
    required this.post,
    required this.score,
    required this.postedAt,
    required this.isFresh,
  });
}
