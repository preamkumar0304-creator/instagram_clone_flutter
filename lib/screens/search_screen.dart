import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_staggered_grid_view/flutter_staggered_grid_view.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/search_media_viewer_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
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
    return items;
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
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: SizedBox(height: 40,
          child: TextFormField(
            style: TextStyle(color: primaryColor),
            controller: searchController,
            decoration: InputDecoration(
              suffixIcon: GestureDetector(
                onTap: () => searchController.clear(),
                child: Icon(Icons.close, color: secondaryColor),
              ),
              contentPadding: EdgeInsets.symmetric(),
              filled: true,
              fillColor: mobileBackgroundColor,
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: secondaryColor, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10),
                borderSide: BorderSide(color: blueColor, width: 2),
              ),
              hintText: "Search for a user",
              hintStyle: TextStyle(color: secondaryColor),
              prefixIcon: Icon(Icons.search, color: secondaryColor),
            ),
            onFieldSubmitted: (value) {
              setState(() {
                isShowUsers = true;
              });
            },
          ),
        ),
      ),
      body:
          isShowUsers
              ? FutureBuilder(
                future:
                    FirebaseFirestore.instance
                        .collection("users")
                        .where(
                          "username",
                          isGreaterThanOrEqualTo: searchController.text.trim(),
                        )
                        .get(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    );
                  } else {
                    return ListView.builder(
                      itemCount: (snapshot.data! as dynamic).docs.length,
                      itemBuilder: (context, index) {
                        final doc = (snapshot.data! as dynamic).docs[index];
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
                  return MasonryGridView.builder(
                    mainAxisSpacing: 8,
                    crossAxisSpacing: 8,
                    gridDelegate:
                        SliverSimpleGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                        ),
                    itemCount: media.length,
                    itemBuilder: (context, index) {
                      final item = media[index];
                      final type = _safeString(item["type"]);
                      final data =
                          item["data"] is Map<String, dynamic>
                              ? item["data"] as Map<String, dynamic>
                              : <String, dynamic>{};
                      final postUrl = _safeString(data["postUrl"]);
                      final coverUrl = _safeString(data["coverUrl"]);
                      final thumbnailUrl = _safeString(data["thumbnailUrl"]);
                      final previewUrl =
                          coverUrl.isNotEmpty
                              ? coverUrl
                              : (thumbnailUrl.isNotEmpty
                                  ? thumbnailUrl
                                  : postUrl);

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
                        child: Stack(
                          children: [
                            if (previewUrl.isNotEmpty)
                              Image.network(previewUrl, fit: BoxFit.cover)
                            else
                              Container(
                                height: 160,
                                color: Colors.black12,
                                child: const Center(
                                  child: Icon(
                                    Icons.image_not_supported_outlined,
                                    color: secondaryColor,
                                  ),
                                ),
                              ),
                            if (type == "reel")
                              const Positioned(
                                top: 8,
                                right: 8,
                                child: Icon(
                                  Icons.play_circle_fill,
                                  color: Colors.white,
                                ),
                              ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
    );
  }
}
