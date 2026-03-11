import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class FollowListScreen extends StatefulWidget {
  final String title;
  final List<String> userIds;

  const FollowListScreen({
    super.key,
    required this.title,
    required this.userIds,
  });

  @override
  State<FollowListScreen> createState() => _FollowListScreenState();
}

class _FollowListScreenState extends State<FollowListScreen> {
  Future<List<Map<String, dynamic>>> _loadUsers(List<String> ids) async {
    if (ids.isEmpty) return [];
    final List<Map<String, dynamic>> results = [];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap =
          await FirebaseFirestore.instance
              .collection("users")
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        results.add({
          "uid": doc.id,
          "username": data["username"] ?? "",
          "photoUrl": data["photoUrl"] ?? "",
          "bio": data["bio"] ?? "",
        });
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser!.uid;

    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: Text(widget.title, style: const TextStyle(color: primaryColor)),
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection("users")
                .doc(currentUid)
                .snapshots(),
        builder: (context, userSnap) {
          final following =
              (userSnap.data?.data()?["following"] as List?) ?? [];
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadUsers(widget.userIds),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }
              final users = snapshot.data ?? [];
              if (users.isEmpty) {
                return const Center(
                  child: Text(
                    "No users yet.",
                    style: TextStyle(color: primaryColor),
                  ),
                );
              }
              return ListView.builder(
                itemCount: users.length,
                itemBuilder: (context, index) {
                  final user = users[index];
                  final uid = (user["uid"] ?? "") as String;
                  final username = (user["username"] ?? "") as String;
                  final photoUrl = (user["photoUrl"] ?? "") as String;
                  final isMe = uid == currentUid;
                  final isFollowing = following.contains(uid);

                  return ListTile(
                    onTap:
                        () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(uid: uid),
                          ),
                        ),
                    leading: CircleAvatar(
                      backgroundImage:
                          photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      child:
                          photoUrl.isEmpty
                              ? const Icon(
                                Icons.person,
                                color: Colors.white,
                              )
                              : null,
                    ),
                    title: Text(username, style: const TextStyle(color: primaryColor)),
                    trailing:
                        isMe
                            ? const SizedBox.shrink()
                            : TextButton(
                              onPressed: () async {
                                await FirestoreMethods().followUser(
                                  uid: currentUid,
                                  followId: uid,
                                );
                              },
                              style: TextButton.styleFrom(
                                backgroundColor:
                                    isFollowing ? secondaryColor : blueColor,
                              ),
                              child: Text(
                                isFollowing ? "Following" : "Follow",
                                style: const TextStyle(color: primaryColor),
                              ),
                            ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}
