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
  final int shareCount;
  final String location;
  final String audioUrl;
  final String audioName;
  final double audioStart;
  final double audioEnd;

  Post({
    required this.postId,
    required this.postUrl,
    required this.postedDate,
    required this.caption,
    required this.likes,
    required this.uid,
    required this.username,
    required this.profileUrl,
    required this.shareCount,
    required this.location,
    this.audioUrl = "",
    this.audioName = "",
    this.audioStart = 0,
    this.audioEnd = 0,
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
    "shareCount": shareCount,
    "location": location,
    "audioUrl": audioUrl,
    "audioName": audioName,
    "audioStart": audioStart,
    "audioEnd": audioEnd,
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
      shareCount:
          snapshot["shareCount"] is int
              ? snapshot["shareCount"] as int
              : (snapshot["shareCount"] as num?)?.toInt() ?? 0,
      location: (snapshot["location"] ?? "") as String,
      audioUrl: (snapshot["audioUrl"] ?? "") as String,
      audioName: (snapshot["audioName"] ?? "") as String,
      audioStart:
          snapshot["audioStart"] is num
              ? (snapshot["audioStart"] as num).toDouble()
              : 0,
      audioEnd:
          snapshot["audioEnd"] is num
              ? (snapshot["audioEnd"] as num).toDouble()
              : 0,
    );
  }
}
