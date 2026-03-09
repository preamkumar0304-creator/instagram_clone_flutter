import 'package:cloud_firestore/cloud_firestore.dart';

class Comment {
  final String postId;
  final String uid;
  final String username;
  final String profileUrl;
  final String commentText;
  final String commentId;
  final DateTime commentDate;

  Comment({
    required this.postId,
    required this.uid,
    required this.username,
    required this.profileUrl,
    required this.commentText,
    required this.commentId,
    required this.commentDate,
  });

  Map<String, dynamic> toMap() => {
    "postId": postId,
    "uid": uid,
    "username": username,
    "profileUrl": profileUrl,
    "commentText": commentText,
    "commentId": commentId,
    "commentDate": commentDate,
  };

  static Comment fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;
    return Comment(
      postId: snapshot["postId"],
      uid: snapshot["uid"],
      username: snapshot["username"],
      profileUrl: snapshot["profileUrl"],
      commentText: snapshot["commentText"],
      commentId: snapshot["commentId"],
      commentDate: snapshot["commentDate"],
    );
  }
}
