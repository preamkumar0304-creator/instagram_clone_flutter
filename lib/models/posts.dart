import 'package:cloud_firestore/cloud_firestore.dart';

class Post {
  final String postId;
  final String postUrl;
  final DateTime postedDate;
  final String caption;
  final List likes;
  final String uid;
  final String username;
  final String profileUrl;

  Post({
    required this.postId,
    required this.postUrl,
    required this.postedDate,
    required this.caption,
    required this.likes,
    required this.uid,
    required this.username,
    required this.profileUrl,
  });

  Map<String, dynamic> toMap() => {
    "postId": postId,
    "postUrl": postUrl,
    "postedDate": postedDate,
    "caption": caption,
    "likes": likes,
    "uid": uid,
    "username": username,
    "photoUrl": profileUrl,
  };

  static Post fromSnap(DocumentSnapshot snap) {
    var snapshot = snap.data() as Map<String, dynamic>;
    return Post(
      postId: snapshot["postId"],
      postUrl: snapshot["postUrl"],
      postedDate: snapshot["postedDate"],
      caption: snapshot["caption"],
      likes: snapshot["likes"],
      uid: snapshot["uid"],
      username: snapshot["username"],
      profileUrl: snapshot["profileUrl"],
    );
  }
}
