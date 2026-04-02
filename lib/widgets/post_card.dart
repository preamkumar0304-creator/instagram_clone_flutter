import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_feather_icons/flutter_feather_icons.dart';
import 'package:google_fonts/google_fonts.dart';
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
import 'package:instagram_clone_flutter_firebase/utils/audio_manager.dart';
import 'package:provider/provider.dart';
import 'package:visibility_detector/visibility_detector.dart';

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
  Timer? _labelTimer;
  bool _showAudioLabel = true;
  bool _isVisible = false;
  late final VoidCallback _audioListener;

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
    _startLabelTicker();
    _audioListener = () {
      if (mounted) {
        setState(() {});
      }
    };
    AudioManager.instance.addListener(_audioListener);
  }

  @override
  void didUpdateWidget(covariant PostCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snap != widget.snap) {
      _startLabelTicker();
    }
  }

  @override
  void dispose() {
    _labelTimer?.cancel();
    AudioManager.instance.removeListener(_audioListener);
    super.dispose();
  }

  void _startLabelTicker() {
    _labelTimer?.cancel();
    final audioName = _safeString(widget.snap["audioName"]);
    final location = _safeString(widget.snap["location"]);
    if (audioName.isEmpty) {
      _showAudioLabel = false;
      if (mounted) {
        setState(() {});
      }
      return;
    }
    if (location.isEmpty) {
      _showAudioLabel = true;
      if (mounted) {
        setState(() {});
      }
      return;
    }
    _showAudioLabel = true;
    if (mounted) {
      setState(() {});
    }
    _labelTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      if (!mounted) return;
      setState(() {
        _showAudioLabel = !_showAudioLabel;
      });
    });
  }

  void _handleVisibility(VisibilityInfo info) {
    final fraction = info.visibleFraction;
    final shouldBeVisible = fraction >= 0.7;
    if (_isVisible == shouldBeVisible) return;
    _isVisible = shouldBeVisible;
    final postId = _safeString(widget.snap["postId"]);
    final audioUrl = _safeString(widget.snap["audioUrl"]);
    if (!_isVisible) {
      if (AudioManager.instance.currentPostId == postId) {
        AudioManager.instance.stopAudio();
      }
      return;
    }
    if (audioUrl.isEmpty || AudioManager.instance.isMuted) return;
    final start =
        (widget.snap["audioStart"] is num)
            ? (widget.snap["audioStart"] as num).toDouble()
            : 0.0;
    final end =
        (widget.snap["audioEnd"] is num)
            ? (widget.snap["audioEnd"] as num).toDouble()
            : 0.0;
    AudioManager.instance.playAudio(postId, audioUrl, start, end);
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
    AudioManager.instance.stopAudio();
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
    AudioManager.instance.stopAudio();
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
    AudioManager.instance.stopAudio();
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
    AudioManager.instance.stopAudio();
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
                return Padding(
                  padding: EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: Text(
                    "Why are you reporting this ad?",
                    style: GoogleFonts.inter(
                      color: Colors.black,
                      fontWeight: FontWeight.w600,
                      fontSize: 18,
                    ),
                  ),
                );
              }
              final reason = reasons[index - 1];
              return ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                title: Text(
                  reason,
                  style: GoogleFonts.inter(
                    color: Colors.black,
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                  ),
                ),
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
    final audioName = _safeString(widget.snap["audioName"]);
    final audioUrl = _safeString(widget.snap["audioUrl"]);
    final isSaved = user?.savedPosts.contains(postId) ?? false;
    final isOwner = user != null && user.uid == ownerUid;
    final isFollowing = user?.following.contains(ownerUid) ?? false;
    final shareCount = _safeInt(widget.snap["shareCount"]);
    final hasAudioName = audioName.isNotEmpty;
    final showAudio = hasAudioName && (location.isEmpty || _showAudioLabel);
    final labelText = showAudio ? audioName : location;
    final isMuted = AudioManager.instance.isMuted;
    final isPlaying = AudioManager.instance.isPlaying &&
        AudioManager.instance.currentPostId == postId;
    return VisibilityDetector(
      key: ValueKey("post-$postId"),
      onVisibilityChanged: _handleVisibility,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
                              ? const Icon(
                                FeatherIcons.user,
                                color: Colors.black,
                                size: 20,
                              )
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
                          style: GoogleFonts.inter(
                            color: Colors.black,
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (labelText.isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            labelText,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: GoogleFonts.inter(
                              color: Colors.grey,
                              fontSize: 12,
                              fontWeight: FontWeight.w400,
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
                        style: GoogleFonts.inter(
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
                              child: Row(
                                children: [
                                  Icon(
                                    FeatherIcons.trash2,
                                    color: Colors.redAccent,
                                    size: 22,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "Delete Post",
                                    style: GoogleFonts.inter(
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
                              child: Row(
                                children: [
                                  Icon(
                                    FeatherIcons.eyeOff,
                                    color: Colors.black,
                                    size: 22,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "Not Interested",
                                    style: GoogleFonts.inter(
                                      color: Colors.black,
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
                              child: Row(
                                children: [
                                  Icon(
                                    FeatherIcons.alertTriangle,
                                    color: Colors.redAccent,
                                    size: 22,
                                  ),
                                  SizedBox(width: 10),
                                  Text(
                                    "Report Ad",
                                    style: GoogleFonts.inter(
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
                  icon: const Icon(
                    FeatherIcons.moreVertical,
                    color: Colors.black,
                    size: 22,
                  ),
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
                if (audioUrl.isNotEmpty)
                  Positioned(
                    top: 8,
                    right: 8,
                    child: GestureDetector(
                      onTap: () async {
                        await AudioManager.instance.toggleMute();
                        if (!AudioManager.instance.isMuted && _isVisible) {
                          final start =
                              widget.snap["audioStart"] is num
                                  ? (widget.snap["audioStart"] as num)
                                      .toDouble()
                                  : 0.0;
                          final end =
                              widget.snap["audioEnd"] is num
                                  ? (widget.snap["audioEnd"] as num).toDouble()
                                  : 0.0;
                          await AudioManager.instance.playAudio(
                            postId,
                            audioUrl,
                            start,
                            end,
                          );
                        }
                      },
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: Colors.black54,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          isMuted
                              ? FeatherIcons.volumeX
                              : (isPlaying
                                  ? FeatherIcons.volume2
                                  : FeatherIcons.volume1),
                          color: Colors.white,
                          size: 20,
                        ),
                      ),
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
                      FeatherIcons.heart,
                      color: Colors.black,
                      size: 24,
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
                _ActionCount(
                  count: widget.snap["likes"].length.toString(),
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
                            ? const Icon(
                              FeatherIcons.heart,
                              color: Colors.black,
                              size: 22,
                            )
                            : const Icon(
                              FeatherIcons.heart,
                              color: Colors.black,
                              size: 22,
                            ),
                  ),
                ),
                const SizedBox(width: 18),
                _ActionCount(
                  count: commentL.toString(),
                  onTap: _openComments,
                  child: const Icon(
                    FeatherIcons.messageCircle,
                    color: Colors.black,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 18),
                _ActionCount(
                  count: shareCount.toString(),
                  onTap: _openShareSheet,
                  child: const Icon(
                    FeatherIcons.send,
                    color: Colors.black,
                    size: 22,
                  ),
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
                    isSaved ? FeatherIcons.bookmark : FeatherIcons.bookmark,
                    color: isSaved ? Colors.black : Colors.black54,
                    size: 22,
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
                        style: GoogleFonts.inter(
                          color: Colors.black,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      TextSpan(
                        text: "  ${widget.snap["caption"]}",
                        style: GoogleFonts.inter(
                          color: Colors.black,
                          fontSize: 14,
                          fontWeight: FontWeight.w400,
                        ),
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
    ),
  );
  }
}

class _ActionCount extends StatelessWidget {
  final Widget child;
  final String count;
  final VoidCallback onTap;

  const _ActionCount({
    required this.child,
    required this.count,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          child,
          const SizedBox(height: 4),
          Text(
            count,
            style: GoogleFonts.inter(
              color: Colors.grey,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}
