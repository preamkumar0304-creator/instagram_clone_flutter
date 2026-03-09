import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/methods/storage_methods.dart';
import 'package:instagram_clone_flutter_firebase/models/comments.dart';
import 'package:instagram_clone_flutter_firebase/models/posts.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:uuid/uuid.dart';

class FirestoreMethods {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> uploadPost(
    String caption,
    Uint8List file,
    String uid,
    String username,
    String profileUrl,
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
      );
      _firestore.collection("posts").doc(postId).set(post.toMap());
      message = "Post Successfully Added!";
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
      List following = (snap.data()! as dynamic)["following"];
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
}
