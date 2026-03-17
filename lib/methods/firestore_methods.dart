import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/methods/storage_methods.dart';
import 'package:instagram_clone_flutter_firebase/models/comments.dart';
import 'package:instagram_clone_flutter_firebase/models/posts.dart';
import 'package:instagram_clone_flutter_firebase/models/story_media_item.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:uuid/uuid.dart';

class FirestoreMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String _normalizeGender(String? gender) {
    final value = (gender ?? "").toLowerCase().trim();
    if (value == "male" || value == "m") return "male";
    if (value == "female" || value == "f") return "female";
    return "other";
  }

  Future<String> uploadPost(
    String caption,
    Uint8List file,
    String uid,
    String username,
    String profileUrl,
    String location,
  ) async {
    String message = "";
    try {
      String postUrl = await StorageMethods().uploadImageToStorage(
        "posts",
        file,
        true,
      );
      String postId = Uuid().v1();
      Post post = Post(
        postId: postId,
        postUrl: postUrl,
        postedDate: DateTime.now(),
        caption: caption,
        likes: [],
        uid: uid,
        username: username,
        profileUrl: profileUrl,
        shareCount: 0,
        location: location,
      );
      final postData = post.toMap();
      postData.addAll({
        "impressions": 0,
        "reach": 0,
        "saves": 0,
        "profileVisits": 0,
        "commentCount": 0,
        "reachUsers": [],
        "genderBreakdown": {"male": 0, "female": 0, "other": 0},
      });
      _firestore.collection("posts").doc(postId).set(postData);
      message = "Post Successfully Added!";
    } on FirebaseException catch (err) {
      if (err.code == "canceled") {
        message =
            "Upload was canceled. Please keep the app open and try again.";
      } else if (err.code == "unauthorized") {
        message = "Upload is blocked by Firebase Storage rules.";
      } else if (err.code == "network-request-failed") {
        message = "Network issue while uploading. Please try again.";
      } else {
        message = err.message ?? err.toString();
      }
    } catch (err) {
      message = err.toString();
    }
    return message;
  }

  Future<void> likePost(String postId, String uid, List likes) async {
    try {
      if (likes.contains(uid)) {
        await _firestore.collection("posts").doc(postId).update({
          "likes": FieldValue.arrayRemove([uid]),
        });
      } else {
        await _firestore.collection("posts").doc(postId).update({
          "likes": FieldValue.arrayUnion([uid]),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
    }
  }

  Future<String> addComment(
    String postId,
    String uid,
    String username,
    String profileUrl,
    String commentText,
  ) async {
    String message = "";
    try {
      String commentId = Uuid().v1();
      Comment comment = Comment(
        postId: postId,
        uid: uid,
        username: username,
        profileUrl: profileUrl,
        commentText: commentText,
        commentId: commentId,
        commentDate: DateTime.now(),
      );
      await _firestore
          .collection("posts")
          .doc(postId)
          .collection("comments")
          .doc(commentId)
          .set(comment.toMap());
      await _firestore.collection("posts").doc(postId).update({
        "commentCount": FieldValue.increment(1),
      });
      message = "Comment Successfully Added!";
    } catch (err) {
      message = err.toString();
    }
    return message;
  }

  Future<void> deletePost(BuildContext context, String postId) async {
    try {
      await _firestore.collection("posts").doc(postId).delete();
      if (context.mounted) {
        showSnackBar(
          context: context,
          content: "Post Successfully Deleted!",
          clr: successColor,
        );
      }
    } catch (err) {
      if (context.mounted) {
        showSnackBar(
          context: context,
          content: err.toString(),
          clr: errorColor,
        );
      }
    }
  }

  Future<void> followUser({
    required String uid,
    required String followId,
  }) async {
    try {
      DocumentSnapshot snap =
          await FirebaseFirestore.instance.collection("users").doc(uid).get();
      final data = (snap.data() as Map<String, dynamic>?) ?? {};
      List following = List.from(data["following"] ?? []);
      if (following.contains(followId)) {
        await _firestore.collection("users").doc(followId).update({
          "followers": FieldValue.arrayRemove([uid]),
        });
        await _firestore.collection("users").doc(uid).update({
          "following": FieldValue.arrayRemove([followId]),
        });
      } else {
        await _firestore.collection("users").doc(followId).update({
          "followers": FieldValue.arrayUnion([uid]),
        });
        await _firestore.collection("users").doc(uid).update({
          "following": FieldValue.arrayUnion([followId]),
        });
      }
    } catch (e) {
      e.toString();
    }
  }

  Future<void> toggleSavePost({
    required String uid,
    required String postId,
    required bool isSaved,
  }) async {
    try {
      if (isSaved) {
        await _firestore.collection("users").doc(uid).update({
          "savedPosts": FieldValue.arrayRemove([postId]),
        });
        await _firestore.collection("posts").doc(postId).update({
          "saves": FieldValue.increment(-1),
        });
      } else {
        await _firestore.collection("users").doc(uid).update({
          "savedPosts": FieldValue.arrayUnion([postId]),
        });
        await _firestore.collection("posts").doc(postId).update({
          "saves": FieldValue.increment(1),
        });
      }
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
    }
  }

  Future<String> uploadStory({
    required StoryMediaType type,
    Uint8List? imageBytes,
    Uint8List? videoBytes,
    required String uid,
    required String username,
    required String profileUrl,
  }) async {
    String message = "";
    try {
      String storyUrl = "";
      String storyType = "image";
      int storyDuration = 5;
      final storyId = const Uuid().v1();
      final storyRef = _firestore.collection("stories").doc(storyId);
      if (type == StoryMediaType.video) {
        if (videoBytes == null || videoBytes.isEmpty) {
          return "Video file is empty.";
        }
        storyUrl = await StorageMethods().uploadBytesToStorage(
          "stories",
          videoBytes,
          true,
          contentType: "video/mp4",
          fileName: storyId,
        );
        storyType = "video";
        storyDuration = 15;
      } else {
        if (imageBytes == null || imageBytes.isEmpty) {
          return "Image file is empty.";
        }
        storyUrl = await StorageMethods().uploadImageToStorage(
          "stories",
          imageBytes,
          true,
          fileName: storyId,
        );
      }
      final now = DateTime.now();
      final data = {
        "storyId": storyId,
        "uid": uid,
        "username": username,
        "photoUrl": profileUrl,
        "storyUrl": storyUrl,
        "storyType": storyType,
        "storyDuration": storyDuration,
        "createdAt": now,
        "expiresAt": now.add(const Duration(hours: 24)),
        "viewers": <String>[],
        "viewerCount": 0,
        "ownerViewed": false,
      };
      await storyRef.set(data);
      message = "Story added.";
    } on FirebaseException catch (err) {
      if (err.code == "canceled" || err.code == "cancelled") {
        message = "Upload was canceled. Please keep the app open and try again.";
      } else if (err.code == "unauthorized") {
        message = "Upload is blocked by Firebase Storage rules.";
      } else if (err.code == "network-request-failed") {
        message = "Network issue while uploading. Please try again.";
      } else {
        message = err.message ?? err.toString();
      }
    } catch (e) {
      message = e.toString();
    }
    return message;
  }

  Future<String> uploadReel({
    required Uint8List videoBytes,
    required String uid,
    required String username,
    required String profileUrl,
  }) async {
    String message = "";
    try {
      if (videoBytes.isEmpty) {
        return "Video file is empty.";
      }
      final reelId = const Uuid().v1();
      final reelUrl = await StorageMethods().uploadBytesToStorage(
        "reels",
        videoBytes,
        true,
        contentType: "video/mp4",
        fileName: reelId,
      );
      final now = DateTime.now();
      await _firestore.collection("reels").doc(reelId).set({
        "reelId": reelId,
        "uid": uid,
        "username": username,
        "photoUrl": profileUrl,
        "reelUrl": reelUrl,
        "title": "Reel",
        "createdAt": now,
      });
      message = "Reel added.";
    } on FirebaseException catch (err) {
      if (err.code == "canceled" || err.code == "cancelled") {
        message = "Upload was canceled. Please keep the app open and try again.";
      } else if (err.code == "unauthorized") {
        message = "Upload is blocked by Firebase Storage rules.";
      } else if (err.code == "network-request-failed") {
        message = "Network issue while uploading. Please try again.";
      } else {
        message = err.message ?? err.toString();
      }
    } catch (e) {
      message = e.toString();
    }
    return message;
  }

  Future<void> recordStoryView({
    required String storyId,
    required String viewerUid,
  }) async {
    if (storyId.isEmpty || viewerUid.isEmpty) return;
    final storyRef = _firestore.collection("stories").doc(storyId);
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(storyRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>? ?? {};
        final ownerUid = (data["uid"] ?? "").toString();
        if (ownerUid.isNotEmpty && ownerUid == viewerUid) {
          final ownerViewed = data["ownerViewed"] == true;
          if (ownerViewed) return;
          tx.update(storyRef, {"ownerViewed": true});
          return;
        }
        final viewersRaw = data["viewers"];
        final viewers =
            viewersRaw is List
                ? viewersRaw.whereType<String>().toList()
                : <String>[];
        if (viewers.contains(viewerUid)) return;
        viewers.add(viewerUid);
        final currentCount = _safeInt(data["viewerCount"]);
        tx.update(storyRef, {
          "viewers": viewers,
          "viewerCount": currentCount + 1,
        });
      });
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
    }
  }

  Future<void> markStoriesViewed({
    required String ownerUid,
    required String viewerUid,
  }) async {
    if (ownerUid.isEmpty || viewerUid.isEmpty) return;
    try {
      final snap =
          await _firestore
              .collection("stories")
              .where("uid", isEqualTo: ownerUid)
              .get();
      if (snap.docs.isEmpty) return;
      final now = DateTime.now();
      final batch = _firestore.batch();
      for (final doc in snap.docs) {
        final data = doc.data();
        final expiresAt = data["expiresAt"];
        DateTime? expires;
        if (expiresAt is Timestamp) {
          expires = expiresAt.toDate();
        } else if (expiresAt is DateTime) {
          expires = expiresAt;
        }
        if (expires != null && expires.isBefore(now)) {
          continue;
        }
        if (ownerUid == viewerUid) {
          if (data["ownerViewed"] != true) {
            batch.update(doc.reference, {"ownerViewed": true});
          }
          continue;
        }
        final viewersRaw = data["viewers"];
        final viewers =
            viewersRaw is List
                ? viewersRaw.whereType<String>().toList()
                : <String>[];
        if (viewers.contains(viewerUid)) continue;
        batch.update(doc.reference, {
          "viewers": FieldValue.arrayUnion([viewerUid]),
          "viewerCount": FieldValue.increment(1),
        });
      }
      await batch.commit();
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
    }
  }

  Future<void> deleteStory(String storyId) async {
    if (storyId.isEmpty) return;
    try {
      await _firestore.collection("stories").doc(storyId).delete();
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
    }
  }

  Future<void> archiveExpiredStories(String uid) async {
    if (uid.isEmpty) return;
    try {
      final snap =
          await _firestore
              .collection("stories")
              .where("uid", isEqualTo: uid)
              .get();
      if (snap.docs.isEmpty) return;
      final now = DateTime.now();
      final batch = _firestore.batch();
      var hasExpired = false;
      for (final doc in snap.docs) {
        final data = doc.data();
        final expiresAt = data["expiresAt"];
        DateTime? expires;
        if (expiresAt is Timestamp) {
          expires = expiresAt.toDate();
        } else if (expiresAt is DateTime) {
          expires = expiresAt;
        }
        if (expires != null && expires.isAfter(now)) {
          continue;
        }
        hasExpired = true;
        final archiveRef = _firestore.collection("story_archive").doc();
        batch.set(archiveRef, {
          ...data,
          "archivedAt": DateTime.now(),
          "sourceStoryId": doc.id,
        });
        batch.delete(doc.reference);
      }
      if (hasExpired) {
        await batch.commit();
      }
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
    }
  }

  Future<String> _ensureStoryArchived(Map<String, dynamic> storyData) async {
    final sourceId = (storyData["storyId"] ?? "").toString();
    if (sourceId.isEmpty) return "";
    final existing =
        await _firestore
            .collection("story_archive")
            .where("sourceStoryId", isEqualTo: sourceId)
            .limit(1)
            .get();
    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }
    final archiveRef = _firestore.collection("story_archive").doc();
    await archiveRef.set({
      ...storyData,
      "archivedAt": DateTime.now(),
      "sourceStoryId": sourceId,
    });
    return archiveRef.id;
  }

  Future<void> addStoryToHighlight({
    required Map<String, dynamic> storyData,
    required String title,
  }) async {
    final uid = (storyData["uid"] ?? "").toString();
    if (uid.isEmpty) return;
    final trimmed = title.trim();
    if (trimmed.isEmpty) return;

    final archiveId = await _ensureStoryArchived(storyData);
    if (archiveId.isEmpty) return;

    final highlightSnap =
        await _firestore
            .collection("highlights")
            .where("uid", isEqualTo: uid)
            .where("title", isEqualTo: trimmed)
            .limit(1)
            .get();

    if (highlightSnap.docs.isNotEmpty) {
      await _firestore
          .collection("highlights")
          .doc(highlightSnap.docs.first.id)
          .update({
            "storyIds": FieldValue.arrayUnion([archiveId]),
            "updatedAt": DateTime.now(),
          });
      return;
    }

    final highlightId = const Uuid().v1();
    await _firestore.collection("highlights").doc(highlightId).set({
      "highlightId": highlightId,
      "uid": uid,
      "title": trimmed,
      "coverUrl": (storyData["storyUrl"] ?? "").toString(),
      "storyIds": [archiveId],
      "createdAt": DateTime.now(),
      "updatedAt": DateTime.now(),
    });
  }

  Future<void> recordPostView({
    required String postId,
    required String viewerUid,
    required String viewerGender,
  }) async {
    if (postId.isEmpty || viewerUid.isEmpty) return;
    final postRef = _firestore.collection("posts").doc(postId);
    try {
      await _firestore.runTransaction((tx) async {
        final snap = await tx.get(postRef);
        if (!snap.exists) return;
        final data = snap.data() as Map<String, dynamic>? ?? {};
        final ownerUid = (data["uid"] ?? "").toString();
        if (ownerUid.isNotEmpty && ownerUid == viewerUid) return;

        final impressions = _safeInt(data["impressions"]);
        final reach = _safeInt(data["reach"]);

        final reachUsersRaw = data["reachUsers"];
        final reachUsers =
            reachUsersRaw is List
                ? reachUsersRaw.whereType<String>().toList()
                : <String>[];

        final genderRaw = data["genderBreakdown"];
        final genderMap =
            genderRaw is Map ? Map<String, dynamic>.from(genderRaw) : {};
        int male = _safeInt(genderMap["male"]);
        int female = _safeInt(genderMap["female"]);
        int other = _safeInt(genderMap["other"]);

        final updates = <String, dynamic>{
          "impressions": impressions + 1,
        };

        if (!reachUsers.contains(viewerUid)) {
          reachUsers.add(viewerUid);
          final genderKey = _normalizeGender(viewerGender);
          if (genderKey == "male") {
            male += 1;
          } else if (genderKey == "female") {
            female += 1;
          } else {
            other += 1;
          }

          updates.addAll({
            "reach": reach + 1,
            "reachUsers": reachUsers,
            "genderBreakdown": {
              "male": male,
              "female": female,
              "other": other,
            },
          });
        }

        tx.update(postRef, updates);
      });
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
    }
  }

  Future<void> recordProfileVisit({
    required String postId,
    required String viewerUid,
  }) async {
    if (postId.isEmpty || viewerUid.isEmpty) return;
    try {
      await _firestore.collection("posts").doc(postId).update({
        "profileVisits": FieldValue.increment(1),
      });
    } catch (e) {
      if (kDebugMode) {
        print(e.toString());
      }
    }
  }
}
