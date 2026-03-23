import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String uid;
  final String email;
  final String photoUrl;
  final String name;
  final String username;
  final String usernameLowercase;
  final String bio;
  final String pronouns;
  final String gender;
  final List followers;
  final List following;
  final List followRequests;
  final Map<String, dynamic> followerTimes;
  final Map<String, dynamic> followRequestTimes;
  final List savedPosts;
  final List blockedUsers;
  final List mutedUsers;
  final String accountType;
  final bool isPublic;
  final String professionalCategory;
  final String professionalType;
  final String phoneNumber;
  final bool allowPhoneShare;

  const UserModel({
    required this.uid,
    required this.email,
    required this.photoUrl,
    required this.name,
    required this.username,
    required this.usernameLowercase,
    required this.bio,
    required this.pronouns,
    required this.gender,
    required this.followers,
    required this.following,
    required this.followRequests,
    required this.followerTimes,
    required this.followRequestTimes,
    required this.savedPosts,
    required this.blockedUsers,
    required this.mutedUsers,
    required this.accountType,
    required this.isPublic,
    required this.professionalCategory,
    required this.professionalType,
    required this.phoneNumber,
    required this.allowPhoneShare,
  });

  // Convert to Map (for saving to Firestore)
  Map<String, dynamic> toMap() => {
        "uid": uid,
        "email": email,
        "photoUrl": photoUrl,
        "name": name,
        "username": username,
        "usernameLowercase": usernameLowercase,
        "bio": bio,
        "pronouns": pronouns,
        "gender": gender,
        "followers": followers,
        "following": following,
        "followRequests": followRequests,
        "followerTimes": followerTimes,
        "followRequestTimes": followRequestTimes,
        "savedPosts": savedPosts,
        "blockedUsers": blockedUsers,
        "mutedUsers": mutedUsers,
        "accountType": accountType,
        "isPublic": isPublic,
        "professionalCategory": professionalCategory,
        "professionalType": professionalType,
        "phoneNumber": phoneNumber,
        "allowPhoneShare": allowPhoneShare,
      };

  // ✅ Safe factory method with null checks
  static UserModel fromSnap(DocumentSnapshot snap) {
    final data = snap.data();

    if (data == null) {
      // If document not found, throw a clear error
      throw Exception("User document not found for id: ${snap.id}");
    }

    final snapshot = data as Map<String, dynamic>;

    return UserModel(
      uid: snapshot["uid"] ?? '',
      email: snapshot["email"] ?? '',
      photoUrl: snapshot["photoUrl"] ?? '',
      name: snapshot["name"] ?? '',
      username: snapshot["username"] ?? '',
      usernameLowercase:
          snapshot["usernameLowercase"] ??
          (snapshot["username"] ?? '').toString().toLowerCase(),
      bio: snapshot["bio"] ?? '',
      pronouns: snapshot["pronouns"] ?? '',
      gender: snapshot["gender"] ?? 'unspecified',
      followers: snapshot["followers"] ?? [],
      following: snapshot["following"] ?? [],
      followRequests: snapshot["followRequests"] ?? [],
      followerTimes:
          snapshot["followerTimes"] is Map
              ? Map<String, dynamic>.from(snapshot["followerTimes"])
              : {},
      followRequestTimes:
          snapshot["followRequestTimes"] is Map
              ? Map<String, dynamic>.from(snapshot["followRequestTimes"])
              : {},
      savedPosts: snapshot["savedPosts"] ?? [],
      blockedUsers: snapshot["blockedUsers"] ?? [],
      mutedUsers: snapshot["mutedUsers"] ?? [],
      accountType: snapshot["accountType"] ?? "personal",
      isPublic: snapshot["isPublic"] == true,
      professionalCategory: snapshot["professionalCategory"] ?? "",
      professionalType: snapshot["professionalType"] ?? "",
      phoneNumber: snapshot["phoneNumber"] ?? "",
      allowPhoneShare: snapshot["allowPhoneShare"] == true,
    );
  }
}
