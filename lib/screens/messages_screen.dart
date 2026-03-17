import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/screens/chat_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class MessagesScreen extends StatelessWidget {
  const MessagesScreen({super.key});

  List<String> _safeStringList(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return [];
  }

  String _safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  Future<List<Map<String, dynamic>>> _loadUsers(List<String> ids) async {
    if (ids.isEmpty) return [];
    final usersById = <String, Map<String, dynamic>>{};
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap =
          await FirebaseFirestore.instance
              .collection("users")
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
      for (final doc in snap.docs) {
        usersById[doc.id] = doc.data();
      }
    }
    final results = <Map<String, dynamic>>[];
    for (final id in ids) {
      final data = usersById[id];
      if (data == null) continue;
      results.add({
        "uid": id,
        "username": _safeString(data["username"]),
        "photoUrl": _safeString(data["photoUrl"]),
      });
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
        title: const Text(
          "Messages",
          style: TextStyle(color: primaryColor),
        ),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection("users")
                .doc(currentUid)
                .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          final followers = _safeStringList(data["followers"]);
          final following = _safeStringList(data["following"]);
          final all = {...followers, ...following}.toList();
          if (all.isEmpty) {
            return const Center(
              child: Text(
                "No contacts yet.",
                style: TextStyle(color: primaryColor),
              ),
            );
          }
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadUsers(all),
            builder: (context, usersSnap) {
              if (usersSnap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }
              final users = usersSnap.data ?? [];
              if (users.isEmpty) {
                return const Center(
                  child: Text(
                    "No contacts yet.",
                    style: TextStyle(color: primaryColor),
                  ),
                );
              }
              return ListView.separated(
                itemCount: users.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: secondaryColor, height: 1),
                itemBuilder: (context, index) {
                  final user = users[index];
                  final uid = _safeString(user["uid"]);
                  final username = _safeString(user["username"]);
                  final photoUrl = _safeString(user["photoUrl"]);
                  return ListTile(
                    leading: CircleAvatar(
                      backgroundImage:
                          photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      backgroundColor: Colors.grey.shade300,
                      child:
                          photoUrl.isEmpty
                              ? const Icon(Icons.person, color: Colors.black)
                              : null,
                    ),
                    title: Text(
                      username.isNotEmpty ? username : "User",
                      style: const TextStyle(color: primaryColor),
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => ChatScreen(
                                currentUid: currentUid,
                                otherUid: uid,
                                otherUsername: username,
                                otherPhotoUrl: photoUrl,
                              ),
                        ),
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
