import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/widgets/share_reel_sheet.dart';

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
        title: const Text(
          "Reels",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection("reels")
                .orderBy("createdAt", descending: true)
                .snapshots(),
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
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data();
              final title = _safeString(data["title"]);
              final username = _safeString(data["username"]);
              final reelId = _safeString(data["reelId"]);
              final reelUrl = _safeString(data["reelUrl"]);
              final ownerUid = _safeString(data["uid"]);
              final ownerPhotoUrl = _safeString(data["photoUrl"]);
              final coverUrl =
                  _safeString(data["coverUrl"]).isNotEmpty
                      ? _safeString(data["coverUrl"])
                      : _safeString(data["thumbnailUrl"]);
              final thumbnailUrl = _safeString(data["thumbnailUrl"]);
              return Container(
                margin: const EdgeInsets.only(bottom: 14),
                height: 220,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: Colors.grey.shade300),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      if (coverUrl.isNotEmpty)
                        Positioned.fill(
                          child: Image.network(
                            coverUrl,
                            fit: BoxFit.cover,
                          ),
                        )
                      else
                        Positioned.fill(
                          child: Container(
                            color: Colors.grey.shade200,
                            child: const Icon(
                              Icons.movie,
                              color: secondaryColor,
                              size: 40,
                            ),
                          ),
                        ),
                      Positioned.fill(
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [
                                Colors.transparent,
                                Colors.white.withOpacity(0.9),
                              ],
                            ),
                          ),
                        ),
                      ),
                      if (index < 3)
                        Positioned(
                          top: 12,
                          left: 12,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.black,
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: const Text(
                              "TRENDING",
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 11,
                              ),
                            ),
                          ),
                        ),
                      Positioned(
                        right: 12,
                        top: 12,
                        child: Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: Colors.white70,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(
                            Icons.play_arrow,
                            color: Colors.black,
                            size: 20,
                          ),
                        ),
                      ),
                      Positioned(
                        left: 12,
                        right: 12,
                        bottom: 12,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title.isNotEmpty ? title : "Reel",
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              username.isNotEmpty ? "@$username" : "Creator",
                              style: const TextStyle(color: secondaryColor),
                            ),
                          ],
                        ),
                      ),
                      Positioned(
                        right: 12,
                        bottom: 12,
                        child: IconButton(
                          icon: const Icon(
                            Icons.send_outlined,
                            color: Colors.black,
                          ),
                          onPressed: () {
                            showModalBottomSheet(
                              context: context,
                              isScrollControlled: true,
                              useSafeArea: true,
                              backgroundColor: Colors.transparent,
                              builder:
                                  (context) => ShareReelSheet(
                                    reelId: reelId,
                                    reelUrl: reelUrl,
                                    reelOwnerUid: ownerUid,
                                    reelOwnerUsername: username,
                                    reelOwnerPhotoUrl: ownerPhotoUrl,
                                    reelCoverUrl: coverUrl,
                                    reelThumbnailUrl: thumbnailUrl,
                                  ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}
