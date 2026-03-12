import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/providers/user_provider.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
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

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).getUser;
    final photoUrl = _safeString(widget.snap["photoUrl"]);
    final username = _safeString(widget.snap["username"]);
    final postId = _safeString(widget.snap["postId"]);
    final location = _safeString(widget.snap["location"]);
    final isSaved = user?.savedPosts.contains(postId) ?? false;
    final shareCount = _safeInt(widget.snap["shareCount"]);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: GestureDetector(
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
                      child:
                          photoUrl.isEmpty
                              ? const Icon(Icons.person, color: Colors.white)
                              : null,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
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
                          const SizedBox(height: 2),
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
              ),
              const SizedBox(width: 4),
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
                                    color: Colors.white,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "Not Interested",
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w500,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                              onPressed: () {
                                Navigator.of(context).pop();
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "We’ll show you fewer posts like this.",
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
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
                                    "Report Post",
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
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      "Thank you. Our team will review this post.",
                                    ),
                                    behavior: SnackBarBehavior.floating,
                                  ),
                                );
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
          Row(
            children: [
              GestureDetector(
                onTap: () async {
                  await FirestoreMethods().likePost(
                    widget.snap["postId"],
                    user.uid,
                    widget.snap["likes"],
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.only(left: 10, right: 3),
                  child: LikeAnimation(
                    isAnimating: widget.snap["likes"].contains(user!.uid),
                    smallLike: true,
                    child:
                        widget.snap["likes"].contains(user.uid)
                            ? Icon(Icons.favorite, color: errorColor, size: 28)
                            : Icon(Icons.favorite_border, color: primaryColor),
                  ),
                ),
              ),
              MyText(
                text: "${widget.snap["likes"].length}",
                textClr: primaryColor,
                textSize: 12,
              ),
              GestureDetector(
                onTap: _openComments,
                child: const Padding(
                  padding: EdgeInsets.only(left: 15, right: 3),
                  child: Icon(
                    Icons.messenger_outline,
                    color: primaryColor,
                    size: 28,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _openComments,
                child: Padding(
                  padding: const EdgeInsets.only(left: 4, right: 3),
                  child: MyText(
                    text: commentL.toString(),
                    textClr: primaryColor,
                    textSize: 12,
                  ),
                ),
              ),
              GestureDetector(
                onTap: _openShareSheet,
                child: const Padding(
                  padding: EdgeInsets.only(left: 15, right: 4),
                  child: Icon(Icons.send, color: primaryColor, size: 28),
                ),
              ),
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
                  isSaved ? Icons.bookmark : Icons.bookmark_border,
                  color: primaryColor,
                  size: 28,
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 10.0, bottom: 5),
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
            padding: const EdgeInsets.only(left: 10.0),
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
        ],
      ),
    );
  }
}
