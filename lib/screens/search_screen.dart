import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/search_media_viewer_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen>
    with AutomaticKeepAliveClientMixin {
  final TextEditingController searchController = TextEditingController();
  bool isShowUsers = false;
  Future<List<Map<String, dynamic>>>? _mediaFuture;

  String _safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  DateTime _extractTime(dynamic value) {
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  Future<List<Map<String, dynamic>>> _loadMedia() async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    final allowedUids = <String>{};
    final blockedUids = <String>{};
    if (currentUid.isNotEmpty) {
      allowedUids.add(currentUid);
      final userSnap =
          await FirebaseFirestore.instance
              .collection("users")
              .doc(currentUid)
              .get();
      final userData = userSnap.data() ?? {};
      final following =
          (userData["following"] as List?)?.whereType<String>().toList() ?? [];
      allowedUids.addAll(following);
      final blocked =
          (userData["blockedUsers"] as List?)?.whereType<String>().toList() ?? [];
      blockedUids.addAll(blocked);
    }

    final postsSnap =
        await FirebaseFirestore.instance
            .collection("posts")
            .orderBy("postedDate", descending: true)
            .limit(100)
            .get();
    final reelsSnap =
        await FirebaseFirestore.instance
            .collection("reels")
            .orderBy("createdAt", descending: true)
            .limit(100)
            .get();

    final items = <Map<String, dynamic>>[];
    for (final doc in postsSnap.docs) {
      final data = doc.data();
      items.add({
        "type": "post",
        "data": data,
        "sortTime": _extractTime(data["postedDate"]),
      });
    }
    for (final doc in reelsSnap.docs) {
      final data = doc.data();
      items.add({
        "type": "reel",
        "data": data,
        "sortTime": _extractTime(data["createdAt"]),
      });
    }

    items.sort((a, b) {
      final aTime = a["sortTime"] as DateTime? ?? DateTime(1970);
      final bTime = b["sortTime"] as DateTime? ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });

    final uidsToCheck = <String>{};
    for (final item in items) {
      final data =
          item["data"] is Map<String, dynamic>
              ? item["data"] as Map<String, dynamic>
              : <String, dynamic>{};
      final uid = _safeString(data["uid"]);
      if (uid.isEmpty) continue;
      if (blockedUids.contains(uid)) continue;
      if (!allowedUids.contains(uid)) {
        uidsToCheck.add(uid);
      }
    }

    final publicUids = <String>{};
    final uidList = uidsToCheck.toList();
    for (var i = 0; i < uidList.length; i += 10) {
      final chunk = uidList.sublist(
        i,
        i + 10 > uidList.length ? uidList.length : i + 10,
      );
      final snap =
          await FirebaseFirestore.instance
              .collection("users")
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        if (data["isPublic"] == true) {
          publicUids.add(doc.id);
        }
      }
    }

    return items.where((item) {
      final data =
          item["data"] is Map<String, dynamic>
              ? item["data"] as Map<String, dynamic>
              : <String, dynamic>{};
      final uid = _safeString(data["uid"]);
      if (uid.isEmpty) return false;
      if (blockedUids.contains(uid)) return false;
      return allowedUids.contains(uid) || publicUids.contains(uid);
    }).toList();
  }

  Future<List<QueryDocumentSnapshot<Map<String, dynamic>>>> _searchUsers(
    String rawQuery,
  ) async {
    final query = rawQuery.trim().toLowerCase();
    if (query.isEmpty) return [];

    final primarySnap =
        await FirebaseFirestore.instance
            .collection("users")
            .orderBy("usernameLowercase")
            .startAt([query])
            .endAt(["$query\uf8ff"])
            .limit(50)
            .get();

    final results = <String, QueryDocumentSnapshot<Map<String, dynamic>>>{};
    for (final doc in primarySnap.docs) {
      results[doc.id] = doc;
    }

    if (results.length < 50) {
      final fallbackSnap =
          await FirebaseFirestore.instance.collection("users").limit(200).get();
      for (final doc in fallbackSnap.docs) {
        final data = doc.data();
        final username = _safeString(data["username"]).toLowerCase();
        if (!username.contains(query)) continue;
        results.putIfAbsent(doc.id, () => doc);
      }
    }

    return results.values.toList();
  }

  Widget _mediaFallback({required bool isReel}) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade200, Colors.grey.shade300],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Icon(
          isReel ? Icons.play_circle_outline : Icons.image_outlined,
          color: secondaryColor,
          size: 32,
        ),
      ),
    );
  }
  @override
  void initState() {
    super.initState();
    _mediaFuture = _loadMedia();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final trendTags = const [
      "Trending",
      "Travel",
      "Music",
      "Food",
      "Fitness",
      "Art",
      "Sports",
      "Tech",
    ];
    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: const Text(
          "Search",
          style: TextStyle(color: primaryColor, fontWeight: FontWeight.w600),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextFormField(
              style: const TextStyle(color: primaryColor),
              controller: searchController,
              decoration: InputDecoration(
                suffixIcon: GestureDetector(
                  onTap: () {
                    searchController.clear();
                    setState(() {
                      isShowUsers = false;
                    });
                  },
                  child: const Icon(Icons.close, color: secondaryColor),
                ),
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                filled: true,
                fillColor: mobileSearchColor,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(color: Colors.grey.shade300),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(color: primaryColor, width: 1.5),
                ),
                hintText: "Search people, reels, posts",
                hintStyle: const TextStyle(color: secondaryColor),
                prefixIcon: const Icon(Icons.search, color: secondaryColor),
              ),
              onFieldSubmitted: (value) {
                setState(() {
                  isShowUsers = true;
                });
              },
            ),
          ),
        ),
      ),
      body:
          isShowUsers
              ? FutureBuilder(
                future: _searchUsers(searchController.text),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    );
                  } else {
                    final docs = snapshot.data ?? [];
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text(
                          "No users found.",
                          style: TextStyle(color: primaryColor),
                        ),
                      );
                    }
                    return ListView.builder(
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final doc = docs[index];
                        final data =
                            (doc.data() as Map<String, dynamic>?) ?? {};
                        final username = _safeString(data["username"]);
                        final photoUrl = _safeString(data["photoUrl"]);

                        return InkWell(
                          onTap:
                              () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder:
                                      (context) => ProfileScreen(
                                        uid:
                                            _safeString(data["uid"]),
                                      ),
                                ),
                              ),
                          child: ListTile(
                            leading: Container(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: secondaryColor,
                                  width: 1,
                                ),
                              ),
                              child: CircleAvatar(
                                backgroundImage:
                                    photoUrl.isNotEmpty
                                        ? NetworkImage(photoUrl)
                                        : null,
                                child:
                                    photoUrl.isEmpty
                                        ? const Icon(
                                          Icons.person,
                                          color: Colors.white,
                                        )
                                        : null,
                              ),
                            ),
                            title: Text(
                              username,
                              style: const TextStyle(color: primaryColor),
                            ),
                            subtitle: Text(
                              "@$username",
                              style: const TextStyle(color: secondaryColor),
                            ),
                          ),
                        );
                      },
                    );
                  }
                },
              )
              : FutureBuilder(
                future: _mediaFuture,
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  final media = snapshot.data ?? [];
                  if (media.isEmpty) {
                    return const Center(
                      child: Text(
                        "No posts or reels yet.",
                        style: TextStyle(color: primaryColor),
                      ),
                    );
                  }
                  return Column(
                    children: [
                      SizedBox(
                        height: 44,
                        child: ListView.separated(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          scrollDirection: Axis.horizontal,
                          itemBuilder: (context, index) {
                            final tag = trendTags[index];
                            return Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 10,
                              ),
                              decoration: BoxDecoration(
                                color: mobileSearchColor,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: Colors.grey.shade300,
                                ),
                              ),
                              child: Text(
                                tag,
                                style: const TextStyle(color: primaryColor),
                              ),
                            );
                          },
                          separatorBuilder: (_, __) => const SizedBox(width: 8),
                          itemCount: trendTags.length,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Expanded(
                        child: MasonryGridView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          mainAxisSpacing: 10,
                          crossAxisSpacing: 10,
                          gridDelegate:
                              SliverSimpleGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                              ),
                          itemCount: media.length,
                          itemBuilder: (context, index) {
                            final item = media[index];
                            final type = _safeString(item["type"]);
                            final isReel = type == "reel";
                            final data =
                                item["data"] is Map<String, dynamic>
                                    ? item["data"] as Map<String, dynamic>
                                    : <String, dynamic>{};
                            final postUrl = _safeString(data["postUrl"]);
                            final thumbnailUrl = _safeString(data["thumbnailUrl"]);
                            final reelUrl = _safeString(data["reelUrl"]);
                            final profilePhoto = _safeString(data["photoUrl"]);
                            final rawCoverUrl = _safeString(data["coverUrl"]);
                            final coverUrl =
                                rawCoverUrl.isNotEmpty &&
                                        rawCoverUrl != profilePhoto
                                    ? rawCoverUrl
                                    : "";
                            final fallbackUrl =
                                postUrl.isNotEmpty ? postUrl : profilePhoto;
                            final previewUrl =
                                isReel
                                    ? (thumbnailUrl.isNotEmpty
                                        ? thumbnailUrl
                                        : (coverUrl.isNotEmpty ? coverUrl : ""))
                                    : (postUrl.isNotEmpty
                                        ? postUrl
                                        : fallbackUrl);

                            return GestureDetector(
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder:
                                        (_) => SearchMediaViewerScreen(
                                          items: media,
                                          initialIndex: index,
                                        ),
                                  ),
                                );
                              },
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(16),
                                child: Stack(
                                  children: [
                                    AspectRatio(
                                      aspectRatio: 1,
                                      child:
                                          isReel
                                              ? _ReelSearchThumb(
                                                thumbnailUrl: previewUrl,
                                                reelUrl: reelUrl,
                                                fallback: _mediaFallback(
                                                  isReel: isReel,
                                                ),
                                              )
                                              : (previewUrl.isNotEmpty
                                                  ? CachedNetworkImage(
                                                    imageUrl: previewUrl,
                                                    fit: BoxFit.cover,
                                                    placeholder:
                                                        (_, __) => _mediaFallback(
                                                          isReel: isReel,
                                                        ),
                                                    errorWidget:
                                                        (_, __, ___) => _mediaFallback(
                                                          isReel: isReel,
                                                        ),
                                                  )
                                                  : _mediaFallback(isReel: isReel)),
                                    ),
                                    if (isReel)
                                      Positioned(
                                        top: 8,
                                        right: 8,
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.white70,
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                          child: const Icon(
                                            Icons.play_arrow,
                                            color: Colors.black,
                                            size: 18,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  );
                },
              ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _ReelSearchThumb extends StatefulWidget {
  final String thumbnailUrl;
  final String reelUrl;
  final Widget fallback;

  const _ReelSearchThumb({
    required this.thumbnailUrl,
    required this.reelUrl,
    required this.fallback,
  });

  @override
  State<_ReelSearchThumb> createState() => _ReelSearchThumbState();
}

class _ReelSearchThumbState extends State<_ReelSearchThumb> {
  Future<Uint8List?>? _thumbFuture;

  @override
  void initState() {
    super.initState();
    if (widget.thumbnailUrl.isEmpty) {
      _thumbFuture = _generateThumbnail();
    }
  }

  @override
  void didUpdateWidget(covariant _ReelSearchThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.thumbnailUrl.isNotEmpty) {
      _thumbFuture = null;
      return;
    }
    if (oldWidget.thumbnailUrl.isNotEmpty && widget.thumbnailUrl.isEmpty) {
      _thumbFuture = _generateThumbnail();
    }
  }

  Future<Uint8List?> _generateThumbnail() async {
    if (widget.reelUrl.isEmpty) return null;
    try {
      final bytes = await VideoThumbnail.thumbnailData(
        video: widget.reelUrl,
        imageFormat: ImageFormat.JPEG,
        maxWidth: 720,
        quality: 75,
        timeMs: 1000,
      );
      return bytes;
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.thumbnailUrl.isNotEmpty) {
      return CachedNetworkImage(
        imageUrl: widget.thumbnailUrl,
        fit: BoxFit.cover,
        placeholder: (_, __) => widget.fallback,
        errorWidget: (_, __, ___) => widget.fallback,
      );
    }

    return FutureBuilder<Uint8List?>(
      future: _thumbFuture,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null || bytes.isEmpty) {
          return widget.fallback;
        }
        return Image.memory(
          bytes,
          fit: BoxFit.cover,
          gaplessPlayback: true,
        );
      },
    );
  }
}
