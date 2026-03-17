import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/methods/storage_methods.dart';
import 'package:instagram_clone_flutter_firebase/providers/user_provider.dart';
import 'package:instagram_clone_flutter_firebase/screens/activity_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/follow_list_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/post_profile.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_photo_view.dart';
import 'package:instagram_clone_flutter_firebase/screens/saved_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/story_viewer_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/add_post_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:instagram_clone_flutter_firebase/widgets/elevated_button.dart';
import 'package:instagram_clone_flutter_firebase/widgets/share_profile_sheet.dart';
import 'package:instagram_clone_flutter_firebase/widgets/text.dart';
import 'package:provider/provider.dart';

class ProfileScreen extends StatefulWidget {
  final String uid;

  const ProfileScreen({super.key, required this.uid});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  var userData = {};
  int postLength = 0;
  int followers = 0;
  int following = 0;
  bool isFollowing = false;
  bool isLoading = true;
  bool isUploadingPhoto = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _userSub;
  StreamSubscription<QuerySnapshot<Map<String, dynamic>>>? _storySub;
  bool _hasActiveStory = false;
  bool _hasUnseenStory = false;
  bool _markedStoriesViewed = false;

  String _safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  List<String> _safeStringList(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return [];
  }

  @override
  void initState() {
    super.initState();
    _userSub = FirebaseFirestore.instance
        .collection("users")
        .doc(widget.uid)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data == null) {
        setState(() {
          userData = {};
          followers = 0;
          following = 0;
          isFollowing = false;
          isLoading = false;
        });
        return;
      }
      final followersList = _safeStringList(data["followers"]);
      final followingList = _safeStringList(data["following"]);
      setState(() {
        userData = data;
        followers = followersList.length;
        following = followingList.length;
        isFollowing = followersList.contains(
          FirebaseAuth.instance.currentUser!.uid,
        );
        isLoading = false;
      });
    });
    getData();
    _storySub = FirebaseFirestore.instance
        .collection("stories")
        .where("uid", isEqualTo: widget.uid)
        .snapshots()
        .listen((snap) {
      if (!mounted) return;
      final now = DateTime.now();
      final viewerUid = FirebaseAuth.instance.currentUser?.uid ?? "";
      var hasStory = false;
      var hasUnseen = false;
      for (final doc in snap.docs) {
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
        if (viewerUid.isEmpty) {
          hasUnseen = true;
          continue;
        }
        if (viewerUid == widget.uid) {
          final ownerViewed = data["ownerViewed"] == true;
          if (!ownerViewed) {
            hasUnseen = true;
          }
        } else {
          final viewers = _safeStringList(data["viewers"]);
          if (!viewers.contains(viewerUid)) {
            hasUnseen = true;
          }
        }
        if (hasUnseen) {
          break;
        }
      }
      setState(() {
        _hasActiveStory = hasStory;
        _hasUnseenStory = hasUnseen;
      });

      if (!_markedStoriesViewed &&
          hasStory &&
          viewerUid.isNotEmpty &&
          viewerUid != widget.uid) {
        _markedStoriesViewed = true;
        FirestoreMethods().markStoriesViewed(
          ownerUid: widget.uid,
          viewerUid: viewerUid,
        );
      }
    });
  }

  @override
  void dispose() {
    _userSub?.cancel();
    _storySub?.cancel();
    super.dispose();
  }

  Future<void> getData() async {
    try {
      var postSnap = await FirebaseFirestore.instance
          .collection("posts")
          .where("uid", isEqualTo: widget.uid)
          .get();

      setState(() {
        postLength = postSnap.docs.length;
      });
    } catch (err) {
      if (mounted) {
        showSnackBar(context: context, content: err.toString());
      }
    }
  }

  Future<void> _openProfilePhoto() async {
    final photoUrl = _safeString(userData["photoUrl"]);
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ProfilePhotoView(photoUrl: photoUrl),
      ),
    );
  }

  Future<void> _changeProfilePhoto() async {
    if (isUploadingPhoto) return;
    final file = await pickImage(ImageSource.gallery);
    if (file == null || (file as dynamic).isEmpty) return;
    if (!mounted) return;

    setState(() {
      isUploadingPhoto = true;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final photoUrl = await StorageMethods().uploadImageToStorage(
        "profilePics",
        file,
        false,
      );
      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "photoUrl": photoUrl,
      });

      final postsSnap = await FirebaseFirestore.instance
          .collection("posts")
          .where("uid", isEqualTo: uid)
          .get();
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in postsSnap.docs) {
        batch.update(doc.reference, {"photoUrl": photoUrl});
      }
      await batch.commit();

      if (!mounted) return;
      setState(() {
        userData["photoUrl"] = photoUrl;
      });
      await Provider.of<UserProvider>(context, listen: false).refreshUser();
      if (mounted) {
        showSnackBar(
          context: context,
          content: "Profile photo updated.",
          clr: successColor,
        );
      }
    } on FirebaseException catch (err) {
      if (!mounted) return;
      if (err.code == "unauthorized" || err.code == "unauthenticated") {
        showSnackBar(
          context: context,
          content:
              "Upload blocked by Firebase Storage rules or App Check. "
              "Allow authenticated uploads in Storage rules.",
        );
      } else {
        showSnackBar(context: context, content: err.toString());
      }
    } catch (err) {
      if (mounted) {
        showSnackBar(context: context, content: err.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          isUploadingPhoto = false;
        });
      }
    }
  }

  void _showProfilePhotoActions() {
    final isOwner = FirebaseAuth.instance.currentUser?.uid == widget.uid;
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
              ListTile(
                leading: const Icon(Icons.person, color: primaryColor),
                title: const Text("View profile photo"),
                onTap: () async {
                  Navigator.pop(context);
                  await _openProfilePhoto();
                },
              ),
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.photo_camera, color: primaryColor),
                  title: const Text("Change profile photo"),
                  onTap: () async {
                    Navigator.pop(context);
                    await _changeProfilePhoto();
                  },
                ),
            ],
          ),
        );
      },
    );
  }

  void _showProfileMenu() {
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
              ListTile(
                leading: const Icon(Icons.settings, color: primaryColor),
                title: const Text("Settings"),
                onTap: () => Navigator.pop(context),
              ),
              ListTile(
                leading: const Icon(Icons.bookmark_border, color: primaryColor),
                title: const Text("Saved"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SavedScreen()),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.favorite_border, color: primaryColor),
                title: const Text("Activity"),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ActivityScreen()),
                  );
                },
              ),
              const Divider(color: secondaryColor),
              ListTile(
                leading: const Icon(Icons.logout, color: Colors.red),
                title: const Text("Sign Out"),
                onTap: () async {
                  Navigator.pop(context);
                  await FirebaseAuth.instance.signOut();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _shareProfile() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return ShareProfileSheet(
          profileUid: widget.uid,
          profileUsername: _safeString(userData["username"]),
          profilePhotoUrl: _safeString(userData["photoUrl"]),
        );
      },
    );
  }

  void _openStoryViewer() {
    final viewerUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    if (viewerUid.isEmpty) return;
    Navigator.of(context).push(
      PageRouteBuilder(
        transitionDuration: Duration.zero,
        reverseTransitionDuration: Duration.zero,
        opaque: true,
        barrierColor: Colors.black,
        pageBuilder:
            (_, __, ___) => StoryViewerScreen(
              ownerUid: widget.uid,
              viewerUid: viewerUid,
            ),
      ),
    );
  }

  void _openCreateFromProfile() {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => const AddPostScreen()),
    );
  }

  Future<void> _openHighlights() async {
    showModalBottomSheet(
      context: context,
      backgroundColor: mobileBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
          future: _loadHighlights(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: CircularProgressIndicator(color: primaryColor),
                ),
              );
            }
            final data = snapshot.data ?? {"stories": [], "reels": []};
            final stories = data["stories"] ?? [];
            final reels = data["reels"] ?? [];
            if (stories.isEmpty && reels.isEmpty) {
              return const SizedBox(
                height: 200,
                child: Center(
                  child: Text(
                    "No highlights yet.",
                    style: TextStyle(color: primaryColor),
                  ),
                ),
              );
            }
            return SizedBox(
              height: 300,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  if (stories.isNotEmpty) ...[
                    const Text(
                      "Highlights",
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...stories.map(
                      (s) => ListTile(
                        leading: const Icon(
                          Icons.auto_awesome,
                          color: primaryColor,
                        ),
                        title: Text(
                          (s["title"] ?? "Highlight").toString(),
                          style: const TextStyle(color: primaryColor),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  if (reels.isNotEmpty) ...[
                    const Text(
                      "Reels",
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...reels.map(
                      (r) => ListTile(
                        leading: const Icon(
                          Icons.video_library,
                          color: primaryColor,
                        ),
                        title: Text(
                          (r["title"] ?? "Reel").toString(),
                          style: const TextStyle(color: primaryColor),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<Map<String, List<Map<String, dynamic>>>> _loadHighlights() async {
    final storiesSnap =
        await FirebaseFirestore.instance
            .collection("highlights")
            .where("uid", isEqualTo: widget.uid)
            .orderBy("updatedAt", descending: true)
            .get();
    final reelsSnap =
        await FirebaseFirestore.instance
            .collection("reels")
            .where("uid", isEqualTo: widget.uid)
            .get();
    return {
      "stories": storiesSnap.docs.map((d) => d.data()).toList(),
      "reels": reelsSnap.docs.map((d) => d.data()).toList(),
    };
  }

  Widget _buildHighlightsRow(bool isOwner) {
    return FutureBuilder<Map<String, List<Map<String, dynamic>>>>(
      future: _loadHighlights(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SizedBox(
            height: 60,
            child: Center(
              child: CircularProgressIndicator(color: primaryColor),
            ),
          );
        }
        final data = snapshot.data ?? {"stories": [], "reels": []};
        final hasStories = (data["stories"] ?? []).isNotEmpty;
        final hasReels = (data["reels"] ?? []).isNotEmpty;

        if (!hasStories && !hasReels) {
          if (!isOwner) {
            return const Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: Text(
                "No highlights",
                style: TextStyle(color: primaryColor),
              ),
            );
          }
          return SizedBox(
            height: 78,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                _highlightItem(
                  icon: Icons.add,
                  label: "New",
                  onTap: _openHighlights,
                ),
              ],
            ),
          );
        }

        return SizedBox(
          height: 78,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              if (isOwner)
                _highlightItem(
                  icon: Icons.add,
                  label: "New",
                  onTap: _openHighlights,
                ),
              if (hasStories)
                _highlightItem(
                  icon: Icons.auto_awesome,
                  label: "Highlights",
                  onTap: _openHighlights,
                ),
              if (hasReels)
                _highlightItem(
                  icon: Icons.video_library,
                  label: "Reels",
                  onTap: _openHighlights,
                ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final isOwner = FirebaseAuth.instance.currentUser?.uid == widget.uid;

    if (isLoading) {
      return Center(child: CircularProgressIndicator(color: primaryColor));
    }

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: mobileBackgroundColor,
        appBar: AppBar(
          backgroundColor: mobileBackgroundColor,
          title: MyText(
            text: _safeString(userData["username"]),
            textClr: primaryColor,
            textSize: 22,
            textWeight: FontWeight.bold,
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.menu, color: Colors.white),
              onPressed: _showProfileMenu,
            ),
          ],
        ),
        body: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap:
                        _hasActiveStory
                            ? _openStoryViewer
                            : _showProfilePhotoActions,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            gradient:
                                _hasActiveStory && _hasUnseenStory
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
                                _hasActiveStory
                                    ? (_hasUnseenStory
                                        ? null
                                        : Border.all(
                                          color: secondaryColor,
                                          width: 1,
                                        ))
                                    : Border.all(
                                      color: secondaryColor,
                                      width: 1,
                                    ),
                          ),
                          child: CircleAvatar(
                            radius: 40,
                            backgroundImage: (userData["photoUrl"] is String &&
                                    (userData["photoUrl"] as String).isNotEmpty)
                                ? NetworkImage(userData["photoUrl"])
                                : null,
                            child: (userData["photoUrl"] == null ||
                                    (userData["photoUrl"] is String &&
                                        (userData["photoUrl"] as String)
                                            .isEmpty))
                                ? const Icon(
                                    Icons.person,
                                    size: 40,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                        if (isOwner)
                          Positioned(
                            right: 4,
                            bottom: 4,
                            child: GestureDetector(
                              onTap: _openCreateFromProfile,
                              child: Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: blueColor,
                                  shape: BoxShape.circle,
                                  border: Border.all(
                                    color: mobileBackgroundColor,
                                    width: 2,
                                  ),
                                ),
                                child: const Icon(
                                  Icons.add,
                                  size: 14,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        if (isUploadingPhoto)
                          const SizedBox(
                            width: 28,
                            height: 28,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              color: blueColor,
                            ),
                          ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(bottom: 5),
                            child: MyText(
                              text: _safeString(userData["username"]),
                              textClr: primaryColor,
                              textSize: 15,
                              textWeight: FontWeight.bold,
                            ),
                          ),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              statColumn(postLength, "posts"),
                              GestureDetector(
                                onTap: () {
                                  final ids =
                                      _safeStringList(userData["followers"]);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FollowListScreen(
                                        title: "Followers",
                                        userIds: ids,
                                      ),
                                    ),
                                  );
                                },
                                child: statColumn(followers, "followers"),
                              ),
                              GestureDetector(
                                onTap: () {
                                  final ids =
                                      _safeStringList(userData["following"]);
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => FollowListScreen(
                                        title: "Following",
                                        userIds: ids,
                                      ),
                                    ),
                                  );
                                },
                                child: statColumn(following, "following"),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 5),
                child: MyText(
                  text: _safeString(userData["bio"]),
                  textClr: primaryColor,
                  textSize: 14,
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  Expanded(
                    child: isOwner
                        ? MyElevatedButton(
                            buttonText: "Edit profile",
                            onPressed: () {},
                            bgClr: secondaryColor.shade700,
                            radius: 5,
                            height: 35,
                            fontSize: 14,
                          )
                        : isFollowing
                            ? MyElevatedButton(
                                buttonText: "Unfollow",
                                onPressed: () async {
                                  await FirestoreMethods().followUser(
                                    uid: FirebaseAuth
                                        .instance
                                        .currentUser!
                                        .uid,
                                    followId: userData["uid"],
                                  );
                                  setState(() {
                                    isFollowing = false;
                                    followers--;
                                    final list =
                                        _safeStringList(userData["followers"]);
                                    list.remove(FirebaseAuth
                                        .instance
                                        .currentUser!
                                        .uid);
                                    userData["followers"] = list;
                                  });
                                },
                                textClr: Colors.black,
                                bgClr: Colors.grey.shade200,
                                radius: 5,
                                height: 35,
                                fontSize: 14,
                              )
                            : MyElevatedButton(
                                buttonText: "Follow",
                                onPressed: () async {
                                  await FirestoreMethods().followUser(
                                    uid: FirebaseAuth
                                        .instance
                                        .currentUser!
                                        .uid,
                                    followId: userData["uid"],
                                  );
                                  setState(() {
                                    isFollowing = true;
                                    followers++;
                                    final list =
                                        _safeStringList(userData["followers"]);
                                    list.add(FirebaseAuth
                                        .instance
                                        .currentUser!
                                        .uid);
                                    userData["followers"] = list;
                                  });
                                },
                                textClr: Colors.white,
                                bgClr: blueColor,
                                radius: 5,
                                height: 35,
                                fontSize: 14,
                              ),
                  ),
                  const SizedBox(width: 5),
                  Expanded(
                    child: isOwner
                        ? MyElevatedButton(
                            buttonText: "Share profile",
                            onPressed: _shareProfile,
                            bgClr: secondaryColor.shade700,
                            radius: 5,
                            height: 35,
                            fontSize: 14,
                          )
                        : MyElevatedButton(
                            buttonText: "Message",
                            onPressed: () {},
                            bgClr: secondaryColor.shade700,
                            radius: 5,
                            height: 35,
                            fontSize: 14,
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildHighlightsRow(isOwner),
              const SizedBox(height: 10),
              const TabBar(
                indicator: UnderlineTabIndicator(
                  borderSide: BorderSide(color: Colors.transparent, width: 0),
                ),
                indicatorColor: Colors.transparent,
                dividerColor: Colors.transparent,
                tabs: [
                  Tab(icon: Icon(Icons.grid_on, color: primaryColor)),
                  Tab(icon: Icon(Icons.video_library, color: primaryColor)),
                  Tab(icon: Icon(Icons.person_pin, color: primaryColor)),
                ],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    _PostsGrid(uid: widget.uid),
                    const _PlaceholderTab(label: "Reels coming soon"),
                    const _PlaceholderTab(label: "Tagged posts coming soon"),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HighlightItem extends StatelessWidget {
  final IconData? icon;
  final String label;
  final VoidCallback? onTap;

  const _HighlightItem({this.icon, required this.label, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: secondaryColor, width: 1),
              ),
              child: icon == null
                  ? const Icon(Icons.circle, color: secondaryColor, size: 12)
                  : Icon(icon, color: primaryColor),
            ),
            const SizedBox(height: 6),
            SizedBox(
              width: 60,
              child: Text(
                label,
                textAlign: TextAlign.center,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: primaryColor, fontSize: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PostsGrid extends StatelessWidget {
  final String uid;

  const _PostsGrid({required this.uid});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder(
      future: FirebaseFirestore.instance
          .collection("posts")
          .where("uid", isEqualTo: uid)
          .orderBy("postedDate", descending: true)
          .get(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(
            child: CircularProgressIndicator(color: primaryColor),
          );
        }
        return GridView.builder(
          shrinkWrap: true,
          itemCount: (snapshot.data! as dynamic).docs.length,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 3,
            crossAxisSpacing: 5,
            mainAxisSpacing: 1.5,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            DocumentSnapshot snap = (snapshot.data! as dynamic).docs[index];
            final postUrl = snap["postUrl"];
            if (postUrl is! String || postUrl.isEmpty) {
              return const SizedBox.shrink();
            }
            return GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => PostDetailScreen(uid: uid),
                  ),
                );
              },
              child: Image(
                fit: BoxFit.cover,
                image: NetworkImage(postUrl),
              ),
            );
          },
        );
      },
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  final String label;

  const _PlaceholderTab({required this.label});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(label, style: const TextStyle(color: primaryColor)),
    );
  }
}

Widget _highlightItem({IconData? icon, required String label, VoidCallback? onTap}) {
  return _HighlightItem(icon: icon, label: label, onTap: onTap);
}

Column statColumn(int num, String label) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      MyText(
        text: num.toString(),
        textClr: primaryColor,
        textSize: 14,
        textWeight: FontWeight.bold,
      ),
      MyText(
        text: label,
        textClr: primaryColor,
        textSize: 14,
        textWeight: FontWeight.bold,
      ),
    ],
  );
}
