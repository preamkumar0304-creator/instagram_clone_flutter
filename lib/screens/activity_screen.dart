import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  Future<Map<String, Map<String, dynamic>>> _loadUsers(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    final Map<String, Map<String, dynamic>> results = {};
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap =
          await FirebaseFirestore.instance
              .collection("users")
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
      for (final doc in snap.docs) {
        results[doc.id] = doc.data();
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: const Text("Activity", style: TextStyle(color: primaryColor)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection("users")
                .doc(currentUid)
                .snapshots(),
        builder: (context, userSnap) {
          final userData = userSnap.data?.data() ?? {};
          final followers =
              (userData["followers"] as List?)?.whereType<String>().toList() ??
              [];

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance
                    .collection("posts")
                    .where("uid", isEqualTo: currentUid)
                    .orderBy("postedDate", descending: true)
                    .snapshots(),
            builder: (context, postSnap) {
              if (postSnap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              final posts = postSnap.data?.docs ?? [];
              final List<_ActivityItem> items = [];
              final Set<String> userIds = {};

              // Followers
              for (final uid in followers) {
                if (uid == currentUid) continue;
                items.add(
                  _ActivityItem.follow(uid: uid),
                );
                userIds.add(uid);
              }

              // Likes on your posts
              for (final doc in posts) {
                final data = doc.data();
                final postUrl = (data["postUrl"] ?? "") as String;
                final likes =
                    (data["likes"] as List?)?.whereType<String>().toList() ?? [];
                for (final liker in likes) {
                  if (liker == currentUid) continue;
                  items.add(
                    _ActivityItem.like(uid: liker, postUrl: postUrl),
                  );
                  userIds.add(liker);
                }
              }

              if (items.isEmpty) {
                return const Center(
                  child: Text(
                    "No activity yet.",
                    style: TextStyle(color: primaryColor),
                  ),
                );
              }

              return FutureBuilder<Map<String, Map<String, dynamic>>>(
                future: _loadUsers(userIds.toList()),
                builder: (context, usersSnap) {
                  if (usersSnap.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    );
                  }
                  final users = usersSnap.data ?? {};
                  return ListView.builder(
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final user = users[item.uid] ?? {};
                      final username = (user["username"] ?? "user") as String;
                      final photoUrl = (user["photoUrl"] ?? "") as String;

                      return ListTile(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => ProfileScreen(uid: item.uid),
                            ),
                          );
                        },
                        leading: CircleAvatar(
                          backgroundImage:
                              photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                          child:
                              photoUrl.isEmpty
                                  ? const Icon(Icons.person, color: Colors.white)
                                  : null,
                        ),
                        title: Text(
                          item.type == _ActivityType.follow
                              ? "$username started following you"
                              : "$username liked your post",
                          style: const TextStyle(color: primaryColor),
                        ),
                        trailing:
                            item.type == _ActivityType.like &&
                                    item.postUrl.isNotEmpty
                                ? Image.network(
                                  item.postUrl,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.cover,
                                )
                                : null,
                      );
                    },
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

enum _ActivityType { follow, like }

class _ActivityItem {
  final _ActivityType type;
  final String uid;
  final String postUrl;

  _ActivityItem.follow({required this.uid})
      : type = _ActivityType.follow,
        postUrl = "";

  _ActivityItem.like({required this.uid, required this.postUrl})
      : type = _ActivityType.like;
}
