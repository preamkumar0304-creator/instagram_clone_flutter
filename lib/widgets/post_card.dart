import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/providers/user_provider.dart';
import 'package:instagram_clone_flutter_firebase/screens/image_viewer_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:instagram_clone_flutter_firebase/widgets/comments_bottom_sheet.dart';
import 'package:instagram_clone_flutter_firebase/widgets/like_animation.dart';
import 'package:instagram_clone_flutter_firebase/widgets/share_post_sheet.dart';
import 'package:instagram_clone_flutter_firebase/widgets/text.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PostCard extends StatefulWidget {
  final snap;
  const PostCard({super.key, required this.snap});

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  bool isLikeAnimating = false;
  int commentL = 0;
  bool _hasRecordedView = false;

  String _safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  @override
  void initState() {
    super.initState();
    getComments();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _recordViewIfNeeded();
  }

  getComments() async {
    QuerySnapshot snap =
        await FirebaseFirestore.instance
            .collection("posts")
            .doc(widget.snap["postId"])
            .collection("comments")
            .get();
    commentL = snap.docs.length;
    setState(() {});
  }

  void _openProfile() {
    final uid = _safeString(widget.snap["uid"]);
    if (uid.isEmpty) return;
    final viewer = Provider.of<UserProvider>(context, listen: false).getUser;
    final postId = _safeString(widget.snap["postId"]);
    if (viewer != null && viewer.uid != uid && postId.isNotEmpty) {
      FirestoreMethods().recordProfileVisit(
        postId: postId,
        viewerUid: viewer.uid,
      );
    }
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ProfileScreen(uid: uid)),
    );
  }

  Future<void> _recordViewIfNeeded() async {
    if (_hasRecordedView) return;
    final user = Provider.of<UserProvider>(context).getUser;
    if (user == null) return;
    final postId = _safeString(widget.snap["postId"]);
    final ownerUid = _safeString(widget.snap["uid"]);
    if (postId.isEmpty || ownerUid.isEmpty) return;
    if (user.uid == ownerUid) return;
    _hasRecordedView = true;
    await FirestoreMethods().recordPostView(
      postId: postId,
      viewerUid: user.uid,
      viewerGender: user.gender,
    );
  }

  void _openComments() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder:
          (context) => StreamBuilder(
            stream:
                FirebaseFirestore.instance
                    .collection("posts")
                    .doc(widget.snap["postId"])
                    .collection("comments")
                    .orderBy("commentDate", descending: true)
                    .snapshots(),
            builder: (
              context,
              AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot,
            ) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }
              return CommentsBottomSheet(
                snap: widget.snap,
                snapshot: snapshot,
              );
            },
          ),
    );
  }

  void _openShareSheet() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return SharePostSheet(
          postId: _safeString(widget.snap["postId"]),
          postUrl: _safeString(widget.snap["postUrl"]),
          postOwnerUid: _safeString(widget.snap["uid"]),
          postOwnerUsername: _safeString(widget.snap["username"]),
          postOwnerPhotoUrl: _safeString(widget.snap["photoUrl"]),
        );
      },
    );
  }

  Future<void> _toggleFollow(String ownerUid) async {
    final user = Provider.of<UserProvider>(context, listen: false).getUser;
    if (user == null || ownerUid.isEmpty || user.uid == ownerUid) return;
    await FirestoreMethods().followUser(uid: user.uid, followId: ownerUid);
    await Provider.of<UserProvider>(context, listen: false).refreshUser();
    if (mounted) {
      setState(() {});
    }
  }

  void _openImageViewer(String url) {
    if (url.isEmpty) return;
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ImageViewerScreen(imageUrl: url)),
    );
  }

  Future<void> _hideUserPosts(String ownerUid) async {
    final user = Provider.of<UserProvider>(context, listen: false).getUser;
    if (user == null || ownerUid.isEmpty || user.uid == ownerUid) return;
    await FirestoreMethods().muteUser(uid: user.uid, targetUid: ownerUid);
    if (context.mounted) {
      await Provider.of<UserProvider>(context, listen: false).refreshUser();
      showSnackBar(
        context: context,
        content: "We'll show fewer posts like this.",
        clr: secondaryColor,
      );
    }
  }

  void _showReportSheet() {
    final reasons = [
      "It's spam",
      "Nudity or sexual activity",
      "Hate speech or symbols",
      "Violence or dangerous organizations",
      "Bullying or harassment",
      "Scam or fraud",
      "False information",
      "Something else",
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: mobileBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: reasons.length + 1,
            separatorBuilder: (_, __) =>
                const Divider(color: secondaryColor, height: 1),
            itemBuilder: (context, index) {
              if (index == 0) {
                return const Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    "Why are you reporting this ad?",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                );
              }
              final reason = reasons[index - 1];
              return ListTile(
                title: Text(reason, style: const TextStyle(color: primaryColor)),
                onTap: () {
                  Navigator.pop(context);
                  showSnackBar(
                    context: context,
                    content: "Thanks for letting us know. We'll review it.",
                    clr: secondaryColor,
                  );
                },
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).getUser;
    final photoUrl = _safeString(widget.snap["photoUrl"]);
    final username = _safeString(widget.snap["username"]);
    final postId = _safeString(widget.snap["postId"]);
    final ownerUid = _safeString(widget.snap["uid"]);
    final location = _safeString(widget.snap["location"]);
    final isSaved = user?.savedPosts.contains(postId) ?? false;
    final isOwner = user != null && user.uid == ownerUid;
    final isFollowing = user?.following.contains(ownerUid) ?? false;
    final shareCount = _safeInt(widget.snap["shareCount"]);
    final actionDividerColor = secondaryColor.withOpacity(0.3);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: _openProfile,
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: secondaryColor, width: 1),
                    ),
                    child: CircleAvatar(
                      radius: 16,
                      backgroundImage:
                          photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      backgroundColor: Colors.grey.shade300,
                      child:
                          photoUrl.isEmpty
                              ? const Icon(Icons.person, color: Colors.black)
                              : null,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: GestureDetector(
                    onTap: _openProfile,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          username,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        if (location.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            location,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: secondaryColor,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                if (!isOwner)
                  Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: TextButton(
                      onPressed: () => _toggleFollow(ownerUid),
                      style: TextButton.styleFrom(
                        backgroundColor:
                            isFollowing
                                ? Colors.grey.shade200
                                : Colors.black,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        minimumSize: const Size(0, 28),
                        shape: const StadiumBorder(),
                      ),
                      child: Text(
                        isFollowing ? "Following" : "Follow",
                        style: TextStyle(
                          color: isFollowing ? Colors.black : Colors.white,
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                IconButton(
                  onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      final isPostOwner = widget.snap["uid"] == user!.uid;

                      return SimpleDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        children: [
                          if (isPostOwner)
                            SimpleDialogOption(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.delete_outline,
                                    color: Colors.redAccent,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "Delete Post",
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              onPressed: () async {
                                await FirestoreMethods().deletePost(
                                  context,
                                  widget.snap["postId"],
                                );
                                if (context.mounted)
                                  Navigator.of(context).pop();
                              },
                            )
                          else ...[
                            SimpleDialogOption(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.visibility_off_outlined,
                                    color: primaryColor,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "Not Interested",
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                _hideUserPosts(ownerUid);
                              },
                            ),
                            SimpleDialogOption(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 14,
                              ),
                              child: const Row(
                                children: [
                                  Icon(
                                    Icons.report_gmailerrorred_outlined,
                                    color: Colors.redAccent,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "Report Ad",
                                    style: TextStyle(
                                      color: Colors.redAccent,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                _showReportSheet();
                              },
                            ),
                          ],
                        ],
                      );
                    },
                  );
                },
                  icon: const Icon(Icons.more_vert),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          GestureDetector(
            onDoubleTap: () async {
              await FirestoreMethods().likePost(
                widget.snap["postId"],
                user!.uid,
                widget.snap["likes"],
              );
              setState(() {
                isLikeAnimating = true;
              });
            },
            onTap: () => _openImageViewer(_safeString(widget.snap["postUrl"])),
            child: Stack(
              alignment: Alignment.center,
              children: [
                SizedBox(
                  width: double.infinity,
                  height: MediaQuery.of(context).size.height * 0.45,
                  child: Image.network(
                    fit: BoxFit.cover,
                    widget.snap["postUrl"],
                  ),
                ),
                AnimatedOpacity(
                  duration: const Duration(milliseconds: 200),
                  opacity: isLikeAnimating ? 1 : 0,
                  child: LikeAnimation(
                    isAnimating: isLikeAnimating,
                    duration: const Duration(milliseconds: 400),
                    onEnd: () {
                      setState(() {
                        isLikeAnimating = false;
                      });
                    },
                    child: const Icon(
                      Icons.favorite,
                      color: primaryColor,
                      size: 150,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                GestureDetector(
                  onTap: () async {
                    await FirestoreMethods().likePost(
                      widget.snap["postId"],
                      user.uid,
                      widget.snap["likes"],
                    );
                  },
                  child: LikeAnimation(
                    isAnimating: widget.snap["likes"].contains(user!.uid),
                    smallLike: true,
                    child:
                        widget.snap["likes"].contains(user.uid)
                            ? Icon(Icons.favorite, color: errorColor, size: 28)
                            : Icon(Icons.favorite_border, color: primaryColor),
                  ),
                ),
                const SizedBox(width: 6),
                MyText(
                  text: "${widget.snap["likes"].length}",
                  textClr: primaryColor,
                  textSize: 12,
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 18, color: actionDividerColor),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _openComments,
                  child: const Icon(
                    Icons.messenger_outline,
                    color: primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 6),
                GestureDetector(
                  onTap: _openComments,
                  child: MyText(
                    text: commentL.toString(),
                    textClr: primaryColor,
                    textSize: 12,
                  ),
                ),
                const SizedBox(width: 10),
                Container(width: 1, height: 18, color: actionDividerColor),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: _openShareSheet,
                  child: const Icon(
                    Icons.send_outlined,
                    color: primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 6),
                MyText(
                  text: shareCount.toString(),
                  textClr: primaryColor,
                  textSize: 12,
                ),
                const Spacer(),
                IconButton(
                  onPressed: () async {
                    if (user == null || postId.isEmpty) return;
                    await FirestoreMethods().toggleSavePost(
                      uid: user.uid,
                      postId: postId,
                      isSaved: isSaved,
                    );
                    if (context.mounted) {
                      await Provider.of<UserProvider>(
                        context,
                        listen: false,
                      ).refreshUser();
                    }
                  },
                  icon: Icon(
                    isSaved
                        ? Icons.bookmark_rounded
                        : Icons.bookmark_border_rounded,
                    color: primaryColor,
                    size: 28,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: widget.snap["username"],
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      TextSpan(
                        text: "  ${widget.snap["caption"]}",
                        style: TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: MyText(
                text: DateFormat.yMMMd().format(
                  widget.snap["postedDate"].toDate(),
                ),
                textClr: secondaryColor,
                textSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}
