import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/providers/user_provider.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/widgets/comments_bottom_sheet.dart';
import 'package:instagram_clone_flutter_firebase/widgets/like_animation.dart';
import 'package:instagram_clone_flutter_firebase/widgets/share_post_sheet.dart';
import 'package:instagram_clone_flutter_firebase/widgets/text.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class PostCardProfile extends StatefulWidget {
  final snap;
  const PostCardProfile({super.key, required this.snap});

  @override
  State<PostCardProfile> createState() => _PostCardState();
}

class _PostCardState extends State<PostCardProfile> {
  bool isLikeAnimating = false;
  int commentL = 0;

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  String _safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  @override
  void initState() {
    super.initState();
    getComments();
  }

  getComments() async {
    QuerySnapshot snap = await FirebaseFirestore.instance
        .collection("posts")
        .doc(widget.snap["postId"])
        .collection("comments")
        .get();
    commentL = snap.docs.length;
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserProvider>(context).getUser;
    final bool isOwner = user != null && user.uid == widget.snap["uid"];
    final shareCount = _safeInt(widget.snap["shareCount"]);
    final location = _safeString(widget.snap["location"]);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 10),
                child: Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: secondaryColor, width: 1),
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(widget.snap["photoUrl"]),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(left: 12.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    MyText(
                      text: widget.snap["username"],
                      textClr: primaryColor,
                      textSize: 16,
                      textWeight: FontWeight.bold,
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
              const Spacer(),
              IconButton(
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (context) {
                      return SimpleDialog(
                        children: [
                          SimpleDialogOption(
                            child: const Text("Delete post"),
                            onPressed: () async {
                              await FirestoreMethods().deletePost(
                                context,
                                widget.snap["postId"],
                              );
                              if (context.mounted) {
                                Navigator.of(context).pop();
                              }
                            },
                          ),
                        ],
                      );
                    },
                  );
                },
                icon: const Icon(Icons.more_vert),
              ),
            ],
          ),

          // --- POST IMAGE ---
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

                    // --- ACTION ROW ---
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
                    child: widget.snap["likes"].contains(user.uid)
                        ? const Icon(Icons.favorite, color: errorColor, size: 28)
                        : const Icon(Icons.favorite_border, color: primaryColor),
                  ),
                ),
              ),
              MyText(
                text: "${widget.snap["likes"].length}",
                textClr: primaryColor,
                textSize: 12,
              ),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (context) => StreamBuilder(
                      stream: FirebaseFirestore.instance
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
                },
                child: const Padding(
                  padding: EdgeInsets.only(left: 15, right: 3),
                  child: Icon(Icons.messenger_outline, color: primaryColor, size: 28),
                ),
              ),
              MyText(
                text: commentL.toString(),
                textClr: primaryColor,
                textSize: 12,
              ),
              GestureDetector(
                onTap: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    useSafeArea: true,
                    builder: (context) => SharePostSheet(
                      postId: _safeString(widget.snap["postId"]),
                      postUrl: _safeString(widget.snap["postUrl"]),
                      postOwnerUid: _safeString(widget.snap["uid"]),
                      postOwnerUsername: _safeString(widget.snap["username"]),
                      postOwnerPhotoUrl: _safeString(widget.snap["photoUrl"]),
                    ),
                  );
                },
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
            ],
          ),

          if (isOwner)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6),
              child: Row(
                children: [
                  TextButton(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Insights will be available in a future update.",
                          ),
                          backgroundColor: secondaryColor,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    child: const Text(
                      "View insights",
                      style: TextStyle(
                        color: primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  TextButton.icon(
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(
                            "Boost feature will be available in a future update!",
                          ),
                          backgroundColor: secondaryColor,
                          behavior: SnackBarBehavior.floating,
                          duration: Duration(seconds: 2),
                        ),
                      );
                    },
                    icon: const Icon(Icons.bolt, color: Colors.amber, size: 20),
                    label: const Text(
                      "Boost",
                      style: TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ),

          // --- CAPTION ---
          Padding(
            padding: const EdgeInsets.only(left: 10.0, bottom: 5),
            child: Row(
              children: [
                RichText(
                  text: TextSpan(
                    children: [
                      TextSpan(
                        text: widget.snap["username"],
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      TextSpan(
                        text: "  ${widget.snap["caption"]}",
                        style: const TextStyle(fontSize: 16),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // --- DATE ---
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



