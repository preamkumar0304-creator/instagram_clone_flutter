import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/screens/post_profile.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class SavedScreen extends StatelessWidget {
  const SavedScreen({super.key});

  Future<List<Map<String, dynamic>>> _loadPosts(List<String> ids) async {
    if (ids.isEmpty) return [];
    final List<Map<String, dynamic>> results = [];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap =
          await FirebaseFirestore.instance
              .collection("posts")
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        results.add({
          "postId": doc.id,
          "postUrl": data["postUrl"] ?? "",
          "uid": data["uid"] ?? "",
        });
      }
    }
    return results;
  }

  Future<List<Map<String, dynamic>>> _loadReels(List<String> ids) async {
    if (ids.isEmpty) return [];
    final List<Map<String, dynamic>> results = [];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap =
          await FirebaseFirestore.instance
              .collection("reels")
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        results.add({
          "reelId": doc.id,
          "reelUrl": data["reelUrl"] ?? "",
          "coverUrl": data["coverUrl"] ?? "",
          "thumbnailUrl": data["thumbnailUrl"] ?? "",
          "uid": data["uid"] ?? "",
        });
      }
    }
    return results;
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: mobileBackgroundColor,
        appBar: AppBar(
          backgroundColor: mobileBackgroundColor,
          title: const Text("Saved", style: TextStyle(color: primaryColor)),
          bottom: const TabBar(
            labelColor: primaryColor,
            tabs: [
              Tab(text: "Posts"),
              Tab(text: "Reels"),
            ],
          ),
        ),
        body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream:
              FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
          builder: (context, snapshot) {
            final data = snapshot.data?.data() ?? {};
            final savedPosts = (data["savedPosts"] as List?) ?? [];
            final savedReels = (data["savedReels"] as List?) ?? [];
            final savedPostIds = savedPosts.whereType<String>().toList();
            final savedReelIds = savedReels.whereType<String>().toList();

            return TabBarView(
              children: [
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadPosts(savedPostIds),
                  builder: (context, postsSnap) {
                    if (postsSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      );
                    }
                    final posts = postsSnap.data ?? [];
                    if (posts.isEmpty) {
                      return const Center(
                        child: Text(
                          "No saved posts yet.",
                          style: TextStyle(color: primaryColor),
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: posts.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                      itemBuilder: (context, index) {
                        final post = posts[index];
                        final postUrl = (post["postUrl"] ?? "") as String;
                        if (postUrl.isEmpty) {
                          return const SizedBox.shrink();
                        }
                        return GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => PostDetailScreen(
                                      uid: post["uid"] ?? uid,
                                    ),
                              ),
                            );
                          },
                          child: Image.network(postUrl, fit: BoxFit.cover),
                        );
                      },
                    );
                  },
                ),
                FutureBuilder<List<Map<String, dynamic>>>(
                  future: _loadReels(savedReelIds),
                  builder: (context, reelsSnap) {
                    if (reelsSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      );
                    }
                    final reels = reelsSnap.data ?? [];
                    if (reels.isEmpty) {
                      return const Center(
                        child: Text(
                          "No saved reels yet.",
                          style: TextStyle(color: primaryColor),
                        ),
                      );
                    }
                    return GridView.builder(
                      padding: const EdgeInsets.all(8),
                      itemCount: reels.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            crossAxisSpacing: 4,
                            mainAxisSpacing: 4,
                          ),
                      itemBuilder: (context, index) {
                        final reel = reels[index];
                        final cover =
                            (reel["coverUrl"] as String?)?.trim() ?? "";
                        final thumb =
                            (reel["thumbnailUrl"] as String?)?.trim() ?? "";
                        final imageUrl = cover.isNotEmpty ? cover : thumb;
                        if (imageUrl.isEmpty) {
                          return Container(
                            color: Colors.black12,
                            child: const Icon(
                              Icons.movie,
                              color: secondaryColor,
                            ),
                          );
                        }
                        return Image.network(imageUrl, fit: BoxFit.cover);
                      },
                    );
                  },
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
