import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

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
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: mobileBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: const Text("Blocked users", style: TextStyle(color: primaryColor)),
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          final blocked =
              (data["blockedUsers"] as List?)?.whereType<String>().toList() ??
              [];
          if (blocked.isEmpty) {
            return const Center(
              child: Text(
                "No blocked users.",
                style: TextStyle(color: primaryColor),
              ),
            );
          }
          return FutureBuilder<Map<String, Map<String, dynamic>>>(
            future: _loadUsers(blocked),
            builder: (context, usersSnap) {
              if (usersSnap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }
              final users = usersSnap.data ?? {};
              return ListView.builder(
                itemCount: blocked.length,
                itemBuilder: (context, index) {
                  final userId = blocked[index];
                  final user = users[userId] ?? {};
                  final username = (user["username"] ?? "User").toString();
                  final photoUrl = (user["photoUrl"] ?? "").toString();
                  return ListTile(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(uid: userId),
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
                      username,
                      style: const TextStyle(color: primaryColor),
                    ),
                    trailing: TextButton(
                      onPressed: () async {
                        await FirebaseFirestore.instance
                            .collection("users")
                            .doc(uid)
                            .update({
                              "blockedUsers": FieldValue.arrayRemove([userId]),
                            });
                        if (context.mounted) {
                          showSnackBar(
                            context: context,
                            content: "User unblocked.",
                            clr: successColor,
                          );
                        }
                      },
                      child: const Text("Unblock"),
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
