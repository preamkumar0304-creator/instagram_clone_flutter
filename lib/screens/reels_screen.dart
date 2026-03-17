import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class ReelsScreen extends StatelessWidget {
  const ReelsScreen({super.key});

  String _safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: const Text("Reels", style: TextStyle(color: primaryColor)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection("reels").snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }
          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No reels yet.",
                style: TextStyle(color: primaryColor),
              ),
            );
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) =>
                const Divider(color: secondaryColor, height: 1),
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final title = _safeString(data["title"]);
              final username = _safeString(data["username"]);
              final coverUrl =
                  _safeString(data["coverUrl"]).isNotEmpty
                      ? _safeString(data["coverUrl"])
                      : _safeString(data["thumbnailUrl"]);
              return ListTile(
                leading: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.grey.shade800,
                    borderRadius: BorderRadius.circular(8),
                    image:
                        coverUrl.isNotEmpty
                            ? DecorationImage(
                              image: NetworkImage(coverUrl),
                              fit: BoxFit.cover,
                            )
                            : null,
                  ),
                  child:
                      coverUrl.isEmpty
                          ? const Icon(Icons.movie, color: Colors.white)
                          : null,
                ),
                title: Text(
                  title.isNotEmpty ? title : "Reel",
                  style: const TextStyle(color: primaryColor),
                ),
                subtitle:
                    username.isNotEmpty
                        ? Text(
                          username,
                          style: const TextStyle(color: secondaryColor),
                        )
                        : null,
              );
            },
          );
        },
      ),
    );
  }
}
