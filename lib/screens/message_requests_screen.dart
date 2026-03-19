import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';

class MessageRequestsScreen extends StatelessWidget {
  const MessageRequestsScreen({super.key});

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

  Future<void> _acceptRequest({
    required String currentUid,
    required String otherUid,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    final currentRef =
        FirebaseFirestore.instance.collection("users").doc(currentUid);
    final otherRef =
        FirebaseFirestore.instance.collection("users").doc(otherUid);
    batch.update(currentRef, {
      "following": FieldValue.arrayUnion([otherUid]),
    });
    batch.update(otherRef, {
      "followers": FieldValue.arrayUnion([currentUid]),
    });
    await batch.commit();
  }

  Future<void> _deleteRequest({
    required String currentUid,
    required String otherUid,
  }) async {
    final batch = FirebaseFirestore.instance.batch();
    final currentRef =
        FirebaseFirestore.instance.collection("users").doc(currentUid);
    final otherRef =
        FirebaseFirestore.instance.collection("users").doc(otherUid);
    batch.update(currentRef, {
      "followers": FieldValue.arrayRemove([otherUid]),
    });
    batch.update(otherRef, {
      "following": FieldValue.arrayRemove([currentUid]),
    });
    await batch.commit();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      return const Scaffold(
        backgroundColor: mobileBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }
    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: const Text(
          "Requests",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
        ),
        iconTheme: const IconThemeData(color: primaryColor),
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
          final blocked = _safeStringList(data["blockedUsers"]);
          final requests =
              followers
                  .where((id) => !following.contains(id))
                  .where((id) => !blocked.contains(id))
                  .toList();

          if (requests.isEmpty) {
            return const Center(
              child: Text(
                "No requests.",
                style: TextStyle(color: primaryColor),
              ),
            );
          }

          return FutureBuilder<Map<String, Map<String, dynamic>>>(
            future: _loadUsers(requests),
            builder: (context, usersSnap) {
              if (usersSnap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }
              final users = usersSnap.data ?? {};
              return ListView.separated(
                itemCount: requests.length,
                separatorBuilder: (_, __) =>
                    const Divider(color: secondaryColor, height: 1),
                itemBuilder: (context, index) {
                  final uid = requests[index];
                  final user = users[uid] ?? {};
                  final username = _safeString(user["username"]);
                  final name = _safeString(user["name"]);
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
                    subtitle: name.isNotEmpty
                        ? Text(name, style: const TextStyle(color: secondaryColor))
                        : null,
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
                          onPressed: () async {
                            await _acceptRequest(
                              currentUid: currentUid,
                              otherUid: uid,
                            );
                            if (context.mounted) {
                              showSnackBar(
                                context: context,
                                content: "Request accepted.",
                                clr: successColor,
                              );
                            }
                          },
                          child: const Text("Accept"),
                        ),
                        const SizedBox(width: 6),
                        OutlinedButton(
                          onPressed: () async {
                            await _deleteRequest(
                              currentUid: currentUid,
                              otherUid: uid,
                            );
                            if (context.mounted) {
                              showSnackBar(
                                context: context,
                                content: "Request removed.",
                                clr: secondaryColor,
                              );
                            }
                          },
                          child: const Text("Delete"),
                        ),
                      ],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ProfileScreen(uid: uid),
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
