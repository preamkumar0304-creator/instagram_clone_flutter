import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/models/story_media_item.dart';
import 'package:instagram_clone_flutter_firebase/providers/user_provider.dart';
import 'package:instagram_clone_flutter_firebase/screens/add_post_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/activity_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/story_compose_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/story_viewer_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/live_broadcast_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/live_viewer_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/global_variables.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:instagram_clone_flutter_firebase/widgets/post_card.dart';
import 'package:provider/provider.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key});

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  Future<List<Map<String, dynamic>>>? _privacyFuture;
  int _privacySignature = 0;

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
          final boostedAtRaw = p["boostedAt"];
          DateTime? boostedAt;
          if (boostedAtRaw is Timestamp) {
            boostedAt = boostedAtRaw.toDate();
          } else if (boostedAtRaw is DateTime) {
            boostedAt = boostedAtRaw;
          }
          if (boostedAt != null && boostedAt.isAfter(now)) {
            return false;
          }
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
    final effectiveInterval =
        intervalOverride > 0 ? intervalOverride : interval;

    final result = <Map<String, dynamic>>[];
    final insertionCounts = <String, int>{};
    var boostIndex = 0;
    for (var i = 0; i < posts.length; i++) {
      result.add(posts[i]);
      final shouldInsert = (i + 1) % effectiveInterval == 0;
      if (shouldInsert) {
        var attempts = 0;
        while (attempts < boosted.length) {
          final candidate = boosted[boostIndex % boosted.length];
          boostIndex++;
          attempts++;
          final postId = (candidate["postId"] ?? "").toString();
          if (postId.isEmpty) continue;
          final maxInsertions = _safeInt(candidate["boostMaxInsertions"]);
          final allowed = maxInsertions > 0 ? maxInsertions : 8;
          final current = insertionCounts[postId] ?? 0;
          if (current >= allowed) continue;
          insertionCounts[postId] = current + 1;
          result.add(candidate);
          break;
        }
      }
    }
    return result;
  }

  Future<List<Map<String, dynamic>>> _filterByPrivacy({
    required List<Map<String, dynamic>> posts,
    required Set<String> allowedUids,
  }) async {
    if (posts.isEmpty) return posts;
    final uidsToCheck = <String>{};
    for (final post in posts) {
      final uid = (post["uid"] ?? "").toString();
      if (uid.isEmpty) continue;
      if (!allowedUids.contains(uid)) {
        uidsToCheck.add(uid);
      }
    }
    if (uidsToCheck.isEmpty) return posts;

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

    return posts.where((post) {
      final uid = (post["uid"] ?? "").toString();
      if (uid.isEmpty) return false;
      return allowedUids.contains(uid) || publicUids.contains(uid);
    }).toList();
  }

  int _hashPosts(List<Map<String, dynamic>> posts) {
    var hash = posts.length;
    for (final post in posts) {
      final id =
          (post["postId"] ?? post["id"] ?? post["uid"] ?? "").toString();
      hash = 0x1fffffff & (hash * 31 + id.hashCode);
    }
    return hash;
  }

  int _hashAllowedUids(Set<String> allowedUids) {
    final ordered = allowedUids.toList()..sort();
    var hash = ordered.length;
    for (final uid in ordered) {
      hash = 0x1fffffff & (hash * 31 + uid.hashCode);
    }
    return hash;
  }

  int _privacyKey(
    List<Map<String, dynamic>> posts,
    Set<String> allowedUids,
  ) {
    return Object.hash(_hashPosts(posts), _hashAllowedUids(allowedUids));
  }

  void _openCreateMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: mobileBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              const Text(
                "Create",
                style: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                leading: const Icon(Icons.video_library, color: primaryColor),
                title: const Text("Reel"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => const AddPostScreen(
                            initialCreateType: "reel",
                          ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit, color: primaryColor),
                title: const Text("Edits"),
                onTap: () {
                  Navigator.pop(context);
                  showSnackBar(
                    context: context,
                    content: "Edits coming soon.",
                    clr: secondaryColor,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.grid_on, color: primaryColor),
                title: const Text("Post"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => const AddPostScreen(
                            initialCreateType: "post",
                          ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: primaryColor),
                title: const Text("Story"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder:
                          (_) => const AddPostScreen(
                            initialCreateType: "story",
                          ),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.star_border, color: primaryColor),
                title: const Text("Highlights"),
                onTap: () {
                  Navigator.pop(context);
                  showSnackBar(
                    context: context,
                    content: "Highlights coming soon.",
                    clr: secondaryColor,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.wifi_tethering, color: primaryColor),
                title: const Text("Live"),
                onTap: () {
                  Navigator.pop(context);
                  final user =
                      Provider.of<UserProvider>(context, listen: false).getUser;
                  if (user == null) return;
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => LiveBroadcastScreen(user: user),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome, color: primaryColor),
                title: const Text("AI"),
                onTap: () {
                  Navigator.pop(context);
                  showSnackBar(
                    context: context,
                    content: "AI tools coming soon.",
                    clr: secondaryColor,
                  );
                },
              ),
              const SizedBox(height: 8),
            ],
          ),
        );
      },
    );
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
                          builder: (_) => const ActivityScreen(),
                        ),
                      );
                    },
                    icon: const Icon(
                      Icons.favorite_border,
                      color: primaryColor,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      _openCreateMenu(context);
                    },
                    icon: const Icon(
                      Icons.add_box_outlined,
                      color: primaryColor,
                    ),
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
          final muted =
              (user.mutedUsers as List).whereType<String>().toSet();
          final blocked =
              (user.blockedUsers as List).whereType<String>().toSet();
          final filteredPosts =
              posts.where((post) {
                final uid = (post["uid"] ?? "").toString();
                if (uid.isEmpty) return false;
                if (muted.contains(uid) || blocked.contains(uid)) {
                  return false;
                }
                return true;
              }).toList();
          final allowedUids = <String>{
            user.uid,
            ...(user.following as List).whereType<String>(),
          };
          final privacyKey = _privacyKey(filteredPosts, allowedUids);
          if (_privacyFuture == null || _privacySignature != privacyKey) {
            _privacySignature = privacyKey;
            _privacyFuture = _filterByPrivacy(
              posts: filteredPosts,
              allowedUids: allowedUids,
            );
          }
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _privacyFuture,
            builder: (context, privacySnap) {
              final visiblePosts = privacySnap.data ?? [];
              if (privacySnap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }
              return ListView.builder(
                itemCount: visiblePosts.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: width > webScreenSize ? width * 0.3 : 0,
                      ),
                      child: _StoriesRow(user: user),
                    );
                  }
                  final post = visiblePosts[index - 1];
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
  late final VoidCallback _storyRefreshListener;

  bool _isUnseenStory(Map<String, dynamic> data, String viewerUid) {
    if (viewerUid.isEmpty) return true;
    final ownerUid = (data["uid"] ?? "").toString();
    if (ownerUid.isNotEmpty && ownerUid == viewerUid) {
      return data["ownerViewed"] != true;
    }
    final viewersRaw = data["viewers"];
    final viewers =
        viewersRaw is List
            ? viewersRaw.whereType<String>().toList()
            : <String>[];
    return !viewers.contains(viewerUid);
  }

  @override
  void initState() {
    super.initState();
    _storiesFuture = _loadStories();
    _storyRefreshListener = () {
      if (!mounted) return;
      setState(() {
        _storiesFuture = _loadStories();
      });
    };
    storyRefreshNotifier.addListener(_storyRefreshListener);
  }

  @override
  void didUpdateWidget(covariant _StoriesRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.following != widget.user.following) {
      _storiesFuture = _loadStories();
    }
  }

  @override
  void dispose() {
    storyRefreshNotifier.removeListener(_storyRefreshListener);
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _loadStories() async {
    await FirestoreMethods().archiveExpiredStories(widget.user.uid);
    final following =
        (widget.user.following as List).whereType<String>().toList();
    final orderedUids = <String>[widget.user.uid, ...following];
    final orderedUniqueUids = <String>[];
    final seenUids = <String>{};
    for (final uid in orderedUids) {
      if (uid.isEmpty) continue;
      if (seenUids.add(uid)) {
        orderedUniqueUids.add(uid);
      }
    }
    if (orderedUniqueUids.isEmpty) return [];

    final liveByUid = <String, Map<String, dynamic>>{};
    for (var i = 0; i < orderedUniqueUids.length; i += 10) {
      final chunk = orderedUniqueUids.sublist(
        i,
        i + 10 > orderedUniqueUids.length
            ? orderedUniqueUids.length
            : i + 10,
      );
      final liveSnap =
          await FirebaseFirestore.instance
              .collection("live_sessions")
              .where("hostUid", whereIn: chunk)
              .where("isLive", isEqualTo: true)
              .get();
      for (final doc in liveSnap.docs) {
        final data = doc.data();
        final uid = (data["hostUid"] ?? "").toString();
        if (uid.isEmpty) continue;
        liveByUid[uid] = {...data, "liveId": doc.id};
      }
    }

    final storyByUid = <String, Map<String, dynamic>>{};
    final storyHasByUid = <String, bool>{};
    final storyUnseenByUid = <String, bool>{};
    final seenStoryIds = <String>{};
    for (var i = 0; i < orderedUniqueUids.length; i += 10) {
      final chunk = orderedUniqueUids.sublist(
        i,
        i + 10 > orderedUniqueUids.length
            ? orderedUniqueUids.length
            : i + 10,
      );
      final snap =
          await FirebaseFirestore.instance
              .collection("stories")
              .where("uid", whereIn: chunk)
              .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        final storyId = (data["storyId"] ?? doc.id).toString();
        if (storyId.isNotEmpty && !seenStoryIds.add(storyId)) {
          continue;
        }
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
        storyHasByUid[uid] = true;
        final unseen = _isUnseenStory(data, widget.user.uid);
        storyUnseenByUid[uid] = (storyUnseenByUid[uid] ?? false) || unseen;
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
    for (final uid in orderedUniqueUids) {
        if (uid == widget.user.uid) {
          final liveData = liveByUid[uid];
          results.add({
            "uid": uid,
            "username": widget.user.username,
            "photoUrl": widget.user.photoUrl,
            "isYou": true,
            "hasStory": storyHasByUid[uid] == true,
            "hasUnseenStory": storyUnseenByUid[uid] == true,
            "isLive": liveData != null,
            "liveId": liveData?["liveId"],
            "channelId": liveData?["channelId"],
          });
          continue;
        }
      final userData = usersByUid[uid] ?? {};
      final liveData = liveByUid[uid];
      if (storyHasByUid[uid] != true && liveData == null) {
        continue;
      }
      results.add({
        "uid": uid,
        "username": (userData["username"] ?? "").toString(),
        "photoUrl": (userData["photoUrl"] ?? "").toString(),
        "isYou": false,
        "hasStory": storyHasByUid[uid] == true,
        "hasUnseenStory": storyUnseenByUid[uid] == true,
        "isLive": liveData != null,
        "liveId": liveData?["liveId"],
        "channelId": liveData?["channelId"],
      });
    }

    final uniqueByUid = <String, Map<String, dynamic>>{};
    for (final item in results) {
      final uid = (item["uid"] ?? "").toString();
      if (uid.isEmpty) continue;
      uniqueByUid.putIfAbsent(uid, () => item);
    }

    return uniqueByUid.values.toList();
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
              final isYou = item["isYou"] == true;
              if (isYou) {
                return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream:
                      FirebaseFirestore.instance
                          .collection("stories")
                          .where("uid", isEqualTo: widget.user.uid)
                          .snapshots(),
                  builder: (context, snapshot) {
                    var hasStory = item["hasStory"] == true;
                    var hasUnseen = item["hasUnseenStory"] == true;
                    if (snapshot.hasData) {
                      hasStory = false;
                      hasUnseen = false;
                      final now = DateTime.now();
                      for (final doc in snapshot.data!.docs) {
                        final data = doc.data();
                        final expiresAt = data["expiresAt"];
                        DateTime? expires;
                        if (expiresAt is Timestamp) {
                          expires = expiresAt.toDate();
                        } else if (expiresAt is DateTime) {
                          expires = expiresAt;
                        }
                        if (expires != null && expires.isBefore(now)) {
                          continue;
                        }
                        hasStory = true;
                        if (data["ownerViewed"] != true) {
                          hasUnseen = true;
                          break;
                        }
                      }
                    }
                    return _StoryAvatar(
                      username: item["username"] ?? "",
                      photoUrl: item["photoUrl"] ?? "",
                      isYou: true,
                      hasStory: hasStory,
                      hasUnseenStory: hasUnseen,
                      isLive: item["isLive"] == true,
                      onTap: () async {
                        if (item["isLive"] == true &&
                            item["liveId"] != null &&
                            item["channelId"] != null) {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => LiveBroadcastScreen(
                                    user: widget.user,
                                    existingLiveId: item["liveId"],
                                    existingChannelId: item["channelId"],
                                    resume: true,
                                  ),
                            ),
                          );
                          if (!mounted) return;
                          setState(() {
                            _storiesFuture = _loadStories();
                          });
                          return;
                        }
                        if (!hasStory) {
                          await Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const AddPostScreen(),
                            ),
                          );
                          if (!mounted) return;
                          setState(() {
                            _storiesFuture = _loadStories();
                          });
                          return;
                        }
                        await Navigator.of(context).push(
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
                        if (!mounted) return;
                        setState(() {
                          _storiesFuture = _loadStories();
                        });
                      },
                      onAddStory: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const AddPostScreen(),
                          ),
                        );
                        if (!mounted) return;
                        setState(() {
                          _storiesFuture = _loadStories();
                        });
                      },
                    );
                  },
                );
              }
              final hasStory = item["hasStory"] == true;
              return _StoryAvatar(
                username: item["username"] ?? "",
                photoUrl: item["photoUrl"] ?? "",
                isYou: false,
                hasStory: hasStory,
                hasUnseenStory: item["hasUnseenStory"] == true,
                isLive: item["isLive"] == true,
                onTap: () async {
                  if (item["isLive"] == true && item["liveId"] != null) {
                    await Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => LiveViewerScreen(
                              liveId: item["liveId"],
                            ),
                      ),
                    );
                    if (!mounted) return;
                    setState(() {
                      _storiesFuture = _loadStories();
                    });
                    return;
                  }
                  if (!hasStory) return;
                  await Navigator.of(context).push(
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
                  if (!mounted) return;
                  setState(() {
                    _storiesFuture = _loadStories();
                  });
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
  final bool hasUnseenStory;
  final bool isLive;
  final VoidCallback? onTap;
  final VoidCallback? onAddStory;

  const _StoryAvatar({
    required this.username,
    required this.photoUrl,
    required this.isYou,
    required this.hasStory,
    required this.hasUnseenStory,
    required this.isLive,
    this.onTap,
    this.onAddStory,
  });

  @override
  Widget build(BuildContext context) {
    final ringGradient = const LinearGradient(
      colors: [
        Color(0xFF2C2C2C),
        Color(0xFF5A5A5A),
        Color(0xFF8A8A8A),
        Color(0xFFBDBDBD),
      ],
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
    );
    final showGradient = hasStory && hasUnseenStory;
    final avatar = Column(
      children: [
        Stack(
          children: [
            Container(
              padding: const EdgeInsets.all(2),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: showGradient ? ringGradient : null,
                border:
                    showGradient
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
            if (isLive)
              Positioned(
                left: 6,
                right: 6,
                bottom: -2,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white, width: 1),
                  ),
                  child: const Text(
                    "LIVE",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
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
        var hasStory = false;
        var hasUnseen = false;
        for (final doc in docs) {
          final data = doc.data();
          final expiresAt = data["expiresAt"];
          DateTime? expires;
          if (expiresAt is Timestamp) {
            expires = expiresAt.toDate();
          } else if (expiresAt is DateTime) {
            expires = expiresAt;
          }
          if (expires != null && expires.isBefore(now)) {
            continue;
          }
          hasStory = true;
          if (data["ownerViewed"] != true) {
            hasUnseen = true;
            break;
          }
        }
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
                  hasStory && hasUnseen
                      ? const LinearGradient(
                        colors: [
                          Color(0xFF2C2C2C),
                          Color(0xFF5A5A5A),
                          Color(0xFF8A8A8A),
                          Color(0xFFBDBDBD),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                      : null,
              border:
                  hasStory && hasUnseen
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
