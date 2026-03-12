import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/models/story_media_item.dart';
import 'package:instagram_clone_flutter_firebase/providers/user_provider.dart';
import 'package:instagram_clone_flutter_firebase/screens/add_post_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/story_compose_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/story_viewer_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/global_variables.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:instagram_clone_flutter_firebase/screens/saved_screen.dart';
import 'package:instagram_clone_flutter_firebase/widgets/post_card.dart';
import 'package:provider/provider.dart';

class FeedScreen extends StatelessWidget {
  const FeedScreen({super.key});

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  List<Map<String, dynamic>> _applyBoostPattern(
    List<Map<String, dynamic>> posts, {
    int interval = 5,
  }) {
    if (posts.isEmpty || interval <= 0) return posts;
    final now = DateTime.now();
    final boosted =
        posts.where((p) {
          if (p["isBoosted"] != true) return false;
          final expiresAt = p["boostExpiresAt"];
          DateTime? expires;
          if (expiresAt is Timestamp) {
            expires = expiresAt.toDate();
          } else if (expiresAt is DateTime) {
            expires = expiresAt;
          }
          if (expires == null) return true;
          return expires.isAfter(now);
        }).toList(growable: false);
    if (boosted.isEmpty) return posts;

    final intervalOverride = _safeInt(boosted.first["boostInterval"]);
    final effectiveInterval = intervalOverride > 0 ? intervalOverride : interval;

    final result = <Map<String, dynamic>>[];
    var boostIndex = 0;
    for (var i = 0; i < posts.length; i++) {
      result.add(posts[i]);
      final shouldInsert = (i + 1) % effectiveInterval == 0;
      if (shouldInsert) {
        result.add(boosted[boostIndex % boosted.length]);
        boostIndex++;
      }
    }
    return result;
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).getUser;
    if (user == null) {
      return Center(
        child: SizedBox(
          width: 30,
          height: 30,
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }
    final width = MediaQuery.of(context).size.width;
    return Scaffold(
      backgroundColor:
          width > webScreenSize ? webBackgroundColor : mobileBackgroundColor,
      appBar:
          width > webScreenSize
              ? null
              : AppBar(
                backgroundColor: mobileBackgroundColor,
                title: SvgPicture.asset(
                  "assets/instagramLogo.svg",
                  color: primaryColor,
                  height: 32,
                  width: 32,
                ),
                actions: [
                  IconButton(
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const SavedScreen(),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bookmark_border, color: primaryColor),
                  ),
                ],
              ),
      body: StreamBuilder(
        stream:
            FirebaseFirestore.instance
                .collection("posts")
                .orderBy("postedDate", descending: true)
                .snapshots(),
        builder: (
          context,
          AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshots,
        ) {
          if (snapshots.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }
          final postData =
              snapshots.data!.docs.map((d) => d.data()).toList();
          final posts = _applyBoostPattern(postData);
          return ListView.builder(
            itemCount: posts.length + 1,
            itemBuilder: (context, index) {
              if (index == 0) {
                return Container(
                  margin: EdgeInsets.symmetric(
                    horizontal: width > webScreenSize ? width * 0.3 : 0,
                  ),
                  child: _StoriesRow(user: user),
                );
              }
              final post = posts[index - 1];
              return Container(
                margin: EdgeInsets.symmetric(
                  horizontal: width > webScreenSize ? width * 0.3 : 0,
                  vertical: width > webScreenSize ? 15 : 0,
                ),
                child: PostCard(snap: post),
              );
            },
          );
        },
      ),
    );
  }
}

class _StoriesRow extends StatefulWidget {
  final user;
  const _StoriesRow({required this.user});

  @override
  State<_StoriesRow> createState() => _StoriesRowState();
}

class _StoriesRowState extends State<_StoriesRow> {
  Future<List<Map<String, dynamic>>>? _storiesFuture;

  @override
  void initState() {
    super.initState();
    _storiesFuture = _loadStories();
  }

  @override
  void didUpdateWidget(covariant _StoriesRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.following != widget.user.following) {
      _storiesFuture = _loadStories();
    }
  }

  Future<List<Map<String, dynamic>>> _loadStories() async {
    await FirestoreMethods().archiveExpiredStories(widget.user.uid);
    final following =
        (widget.user.following as List).whereType<String>().toList();
    final orderedUids = <String>[widget.user.uid, ...following];
    final uniqueUids = orderedUids.toSet().toList();
    if (uniqueUids.isEmpty) return [];

    final storyByUid = <String, Map<String, dynamic>>{};
    for (var i = 0; i < uniqueUids.length; i += 10) {
      final chunk = uniqueUids.sublist(
        i,
        i + 10 > uniqueUids.length ? uniqueUids.length : i + 10,
      );
      final snap =
          await FirebaseFirestore.instance
              .collection("stories")
              .where("uid", whereIn: chunk)
              .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final expiresAt = data["expiresAt"];
        DateTime? expires;
        if (expiresAt is Timestamp) {
          expires = expiresAt.toDate();
        } else if (expiresAt is DateTime) {
          expires = expiresAt;
        }
        if (expires != null && expires.isBefore(DateTime.now())) {
          continue;
        }
        final uid = (data["uid"] ?? "").toString();
        if (uid.isEmpty) continue;
        if (!storyByUid.containsKey(uid)) {
          storyByUid[uid] = data;
          continue;
        }
        final existing = storyByUid[uid]!;
        DateTime? existingCreated;
        final existingCreatedRaw = existing["createdAt"];
        if (existingCreatedRaw is Timestamp) {
          existingCreated = existingCreatedRaw.toDate();
        } else if (existingCreatedRaw is DateTime) {
          existingCreated = existingCreatedRaw;
        }
        DateTime? candidateCreated;
        final createdRaw = data["createdAt"];
        if (createdRaw is Timestamp) {
          candidateCreated = createdRaw.toDate();
        } else if (createdRaw is DateTime) {
          candidateCreated = createdRaw;
        }
        if (existingCreated == null) {
          storyByUid[uid] = data;
          continue;
        }
        if (candidateCreated != null &&
            candidateCreated.isAfter(existingCreated)) {
          storyByUid[uid] = data;
        }
      }
    }

    final storyUids = storyByUid.keys.toList();
    final usersByUid = <String, Map<String, dynamic>>{};
    for (var i = 0; i < storyUids.length; i += 10) {
      final chunk = storyUids.sublist(
        i,
        i + 10 > storyUids.length ? storyUids.length : i + 10,
      );
      final snap =
          await FirebaseFirestore.instance
              .collection("users")
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
      for (final doc in snap.docs) {
        usersByUid[doc.id] = doc.data();
      }
    }

    final results = <Map<String, dynamic>>[];
    for (final uid in orderedUids) {
      if (uid == widget.user.uid) {
        results.add({
          "uid": uid,
          "username": widget.user.username,
          "photoUrl": widget.user.photoUrl,
          "isYou": true,
          "hasStory": storyByUid.containsKey(uid),
        });
        continue;
      }
      if (!storyByUid.containsKey(uid)) continue;
      final userData = usersByUid[uid] ?? {};
      results.add({
        "uid": uid,
        "username": (userData["username"] ?? "").toString(),
        "photoUrl": (userData["photoUrl"] ?? "").toString(),
        "isYou": false,
        "hasStory": true,
      });
    }

    return results;
  }

  Future<void> _pickStoryFromGallery() async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    if (!mounted) return;
    final bytes = await image.readAsBytes();
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => StoryComposeScreen(
              items: [StoryMediaItem.image(bytes)],
              user: widget.user,
            ),
      ),
    );
    if (!mounted) return;
    setState(() {
      _storiesFuture = _loadStories();
    });
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, dynamic>>>(
      future: _storiesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 110,
            child: Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
          );
        }
        final stories = snapshot.data ?? [];
        if (stories.isEmpty) {
          return const SizedBox(height: 12);
        }
        return SizedBox(
          height: 110,
          child: ListView.separated(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            itemBuilder: (context, index) {
              final item = stories[index];
              return _StoryAvatar(
                username: item["username"] ?? "",
                photoUrl: item["photoUrl"] ?? "",
                isYou: item["isYou"] == true,
                hasStory: item["hasStory"] == true,
                onTap: () {
                  final isYou = item["isYou"] == true;
                  final hasStory = item["hasStory"] == true;
                  if (isYou && !hasStory) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const AddPostScreen()),
                    );
                    return;
                  }
                  if (!hasStory) return;
                  Navigator.of(context).push(
                    PageRouteBuilder(
                      transitionDuration: Duration.zero,
                      reverseTransitionDuration: Duration.zero,
                      opaque: true,
                      barrierColor: Colors.black,
                      pageBuilder:
                          (_, __, ___) => StoryViewerScreen(
                            ownerUid: item["uid"] ?? "",
                            viewerUid: widget.user.uid,
                          ),
                    ),
                  );
                },
                onAddStory: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const AddPostScreen(),
                    ),
                  );
                },
              );
            },
            separatorBuilder: (_, __) => const SizedBox(width: 12),
            itemCount: stories.length,
          ),
        );
      },
    );
  }
}

class _StoryAvatar extends StatelessWidget {
  final String username;
  final String photoUrl;
  final bool isYou;
  final bool hasStory;
  final VoidCallback? onTap;
  final VoidCallback? onAddStory;

  const _StoryAvatar({
    required this.username,
    required this.photoUrl,
    required this.isYou,
    required this.hasStory,
    this.onTap,
    this.onAddStory,
  });

  @override
  Widget build(BuildContext context) {
    final ringGradient = const LinearGradient(
      colors: [
        Color(0xFFF58529),
        Color(0xFFDD2A7B),
        Color(0xFF8134AF),
        Color(0xFF515BD4),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final avatar = Column(
      children: [
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: hasStory ? ringGradient : null,
                border:
                    hasStory
                        ? null
                        : Border.all(color: secondaryColor, width: 1),
              ),
              child: CircleAvatar(
                radius: 28,
                backgroundImage:
                    photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                backgroundColor: Colors.grey.shade800,
                child:
                    photoUrl.isEmpty
                        ? const Icon(Icons.person, color: Colors.white)
                        : null,
              ),
            ),
            if (isYou)
              Positioned(
                right: -2,
                bottom: -2,
                child: GestureDetector(
                  onTap: onAddStory,
                  child: Container(
                    width: 18,
                    height: 18,
                    decoration: BoxDecoration(
                      color: blueColor,
                      shape: BoxShape.circle,
                      border: Border.all(color: mobileBackgroundColor, width: 2),
                    ),
                    child: const Icon(Icons.add, size: 12, color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 6),
        SizedBox(
          width: 70,
          child: Text(
            isYou ? "Your story" : username,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: const TextStyle(color: primaryColor, fontSize: 12),
          ),
        ),
      ],
    );

    if (onTap == null) return avatar;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: avatar,
    );
  }
}

class _AppBarStoryAvatar extends StatelessWidget {
  final user;

  const _AppBarStoryAvatar({required this.user});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream:
          FirebaseFirestore.instance
              .collection("stories")
              .where("uid", isEqualTo: user.uid)
              .snapshots(),
      builder: (context, snapshot) {
        final docs = snapshot.data?.docs ?? [];
        final now = DateTime.now();
        final hasStory = docs.any((doc) {
          final data = doc.data();
          final expiresAt = data["expiresAt"];
          DateTime? expires;
          if (expiresAt is Timestamp) {
            expires = expiresAt.toDate();
          } else if (expiresAt is DateTime) {
            expires = expiresAt;
          }
          if (expires == null) return true;
          return expires.isAfter(now);
        });
        return GestureDetector(
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => ProfileScreen(uid: user.uid)),
            );
          },
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient:
                  hasStory
                      ? const LinearGradient(
                        colors: [
                          Color(0xFFF58529),
                          Color(0xFFDD2A7B),
                          Color(0xFF8134AF),
                          Color(0xFF515BD4),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                      : null,
              border:
                  hasStory
                      ? null
                      : Border.all(color: secondaryColor, width: 1),
            ),
            child: CircleAvatar(
              radius: 14,
              backgroundImage:
                  user.photoUrl.isNotEmpty ? NetworkImage(user.photoUrl) : null,
              backgroundColor: Colors.grey.shade800,
              child:
                  user.photoUrl.isEmpty
                      ? const Icon(
                        Icons.person,
                        color: Colors.white,
                        size: 16,
                      )
                      : null,
            ),
          ),
        );
      },
    );
  }
}
