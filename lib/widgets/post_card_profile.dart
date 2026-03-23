import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/providers/user_provider.dart';
import 'package:instagram_clone_flutter_firebase/screens/image_viewer_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/boost_review_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
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
  bool _hasRecordedView = false;

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  int _safeListLength(dynamic value) {
    if (value is List) return value.length;
    return 0;
  }

  String _safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  String _formatCount(int value) {
    if (value < 1000) return value.toString();
    if (value < 1000000) {
      final rounded = (value / 100).round() / 10;
      return "${rounded.toStringAsFixed(rounded % 1 == 0 ? 0 : 1)}k";
    }
    final rounded = (value / 100000).round() / 10;
    return "${rounded.toStringAsFixed(rounded % 1 == 0 ? 0 : 1)}m";
  }

  TableRow _insightsRow({
    required String label,
    required String value,
    bool isHeader = false,
  }) {
    final textStyle = TextStyle(
      color: isHeader ? primaryColor : secondaryColor,
      fontSize: isHeader ? 13 : 12,
      fontWeight: isHeader ? FontWeight.w700 : FontWeight.w500,
    );
    return TableRow(
      decoration:
          isHeader ? const BoxDecoration(color: Color(0xFFF2F2F2)) : null,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(label, style: textStyle),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Text(
            value,
            style: textStyle.copyWith(
              color: isHeader ? primaryColor : primaryColor,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  void _showBoostSheet() {
      final options = [
        {
          "title": "Free for 30 days",
          "subtitle": "Trial boost for new posts",
          "amount": 0,
          "days": 30,
          "interval": 4,
          "maxInsertions": 8,
        },
        {
          "title": "Rs 199 - 3 days",
          "subtitle": "Reach ~1.5k-3k people",
          "amount": 199,
          "days": 3,
          "interval": 4,
          "maxInsertions": 12,
        },
        {
          "title": "Rs 399 - 7 days",
          "subtitle": "Reach ~4k-7k people",
          "amount": 399,
          "days": 7,
          "interval": 5,
          "maxInsertions": 16,
        },
        {
          "title": "Rs 799 - 14 days",
          "subtitle": "Reach ~10k-18k people",
          "amount": 799,
          "days": 14,
          "interval": 6,
          "maxInsertions": 20,
        },
    ];
    showModalBottomSheet(
      context: context,
      backgroundColor: mobileBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        int selectedIndex = 0;
        return StatefulBuilder(
          builder: (context, setSheetState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: secondaryColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Boost post",
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    ...List.generate(options.length, (index) {
                      final option = options[index];
                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        decoration: BoxDecoration(
                          border: Border.all(
                            color:
                                selectedIndex == index
                                    ? blueColor
                                    : secondaryColor,
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: RadioListTile<int>(
                          value: index,
                          groupValue: selectedIndex,
                          onChanged: (value) {
                            if (value == null) return;
                            setSheetState(() => selectedIndex = value);
                          },
                          activeColor: blueColor,
                          title: Text(
                            option["title"] as String,
                            style: const TextStyle(color: primaryColor),
                          ),
                          subtitle: Text(
                            option["subtitle"] as String,
                            style: const TextStyle(color: secondaryColor),
                          ),
                        ),
                      );
                    }),
                    const SizedBox(height: 6),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context);
                          final selected = options[selectedIndex];
                            final days = selected["days"] as int? ?? 7;
                            final interval = selected["interval"] as int? ?? 5;
                            final maxInsertions =
                                selected["maxInsertions"] as int? ?? 8;
                            final amount = selected["amount"] as int?;
                            final title = selected["title"] as String?;
                            final subtitle = selected["subtitle"] as String?;
                            final postId = _safeString(widget.snap["postId"]);
                            if (postId.isEmpty) return;
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => BoostReviewScreen(
                                      postId: postId,
                                      postUrl: _safeString(
                                        widget.snap["postUrl"],
                                      ),
                                      days: days,
                                      interval: interval,
                                      maxInsertions: maxInsertions,
                                      packageAmount: amount,
                                      packageTitle: title,
                                      packageSubtitle: subtitle,
                                    ),
                              ),
                            );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: blueColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: const Text(
                          "Continue",
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _showInsightsSheet() {
    final postId = _safeString(widget.snap["postId"]);
    showModalBottomSheet(
      context: context,
      backgroundColor: mobileBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        final stream =
            postId.isNotEmpty
                ? FirebaseFirestore.instance
                    .collection("posts")
                    .doc(postId)
                    .snapshots()
                : null;
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: stream,
          builder: (context, snapshot) {
            final data =
                snapshot.data?.data() ??
                (widget.snap is Map<String, dynamic>
                    ? widget.snap as Map<String, dynamic>
                    : <String, dynamic>{});

            final metrics = [
              {
                "label": "Reach",
                "value": _safeInt(data["reach"]),
              },
              {
                "label": "Impressions",
                "value": _safeInt(data["impressions"]),
              },
              {
                "label": "Likes",
                "value": _safeListLength(data["likes"]),
              },
              {
                "label": "Comments",
                "value":
                    data.containsKey("commentCount")
                        ? _safeInt(data["commentCount"])
                        : commentL,
              },
              {
                "label": "Saves",
                "value": _safeInt(data["saves"]),
              },
              {
                "label": "Profile visits",
                "value": _safeInt(data["profileVisits"]),
              },
            ];

            final genderBreakdown = data["genderBreakdown"];
            final male =
                genderBreakdown is Map
                    ? _safeInt(genderBreakdown["male"])
                    : 0;
            final female =
                genderBreakdown is Map
                    ? _safeInt(genderBreakdown["female"])
                    : 0;
            final other =
                genderBreakdown is Map
                    ? _safeInt(genderBreakdown["other"])
                    : 0;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 36,
                      height: 4,
                      decoration: BoxDecoration(
                        color: secondaryColor,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      "Post insights",
                      style: TextStyle(
                        color: primaryColor,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: secondaryColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(2),
                            1: FlexColumnWidth(1),
                          },
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            _insightsRow(
                              label: "Metric",
                              value: "Value",
                              isHeader: true,
                            ),
                            ...metrics.map(
                              (metric) => _insightsRow(
                                label: metric["label"] as String,
                                value: _formatCount(metric["value"] as int),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        "Audience by gender",
                        style: const TextStyle(
                          color: primaryColor,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: secondaryColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Table(
                          columnWidths: const {
                            0: FlexColumnWidth(1),
                            1: FlexColumnWidth(1),
                            2: FlexColumnWidth(1),
                          },
                          defaultVerticalAlignment:
                              TableCellVerticalAlignment.middle,
                          children: [
                            TableRow(
                              decoration: const BoxDecoration(
                                color: Color(0xFFF2F2F2),
                              ),
                              children: const [
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    "Male",
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    "Female",
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    "Other",
                                    style: TextStyle(
                                      color: primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            TableRow(
                              children: [
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    _formatCount(male),
                                    style: const TextStyle(
                                      color: primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    _formatCount(female),
                                    style: const TextStyle(
                                      color: primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 8,
                                  ),
                                  child: Text(
                                    _formatCount(other),
                                    style: const TextStyle(
                                      color: primaryColor,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
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
    QuerySnapshot snap = await FirebaseFirestore.instance
        .collection("posts")
        .doc(widget.snap["postId"])
        .collection("comments")
        .get();
    commentL = snap.docs.length;
    setState(() {});
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
    final bool isOwner = user != null && user.uid == widget.snap["uid"];
    final ownerUid = _safeString(widget.snap["uid"]);
    final isFollowing = user?.following.contains(ownerUid) ?? false;
    final shareCount = _safeInt(widget.snap["shareCount"]);
    final location = _safeString(widget.snap["location"]);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: secondaryColor, width: 1),
                  ),
                  child: CircleAvatar(
                    radius: 16,
                    backgroundImage: NetworkImage(widget.snap["photoUrl"]),
                    backgroundColor: Colors.grey.shade300,
                    child: (widget.snap["photoUrl"] ?? "").toString().isEmpty
                        ? const Icon(Icons.person, color: Colors.black)
                        : null,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 6.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.snap["username"],
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
                      return SimpleDialog(
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        children: [
                          if (isOwner)
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
                                if (context.mounted) {
                                  Navigator.of(context).pop();
                                }
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

          const SizedBox(height: 6),

          if (isOwner) ...[
            const SizedBox(height: 10),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: SizedBox(
                height: 36,
                child: Row(
                  children: [
                    TextButton(
                      onPressed: () {
                        _showInsightsSheet();
                      },
                      style: TextButton.styleFrom(
                        padding: EdgeInsets.zero,
                        minimumSize: const Size(0, 36),
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        "View insights",
                        style: TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      onPressed: _showBoostSheet,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: blueColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 6,
                        ),
                        minimumSize: const Size(0, 32),
                        shape: const StadiumBorder(),
                      ),
                      child: const Text(
                        "Boost post",
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],

          // --- ACTION ROW ---
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
                            ? const Icon(
                              Icons.favorite,
                              color: errorColor,
                              size: 28,
                            )
                            : const Icon(
                              Icons.favorite_border,
                              color: primaryColor,
                            ),
                  ),
                ),
                const SizedBox(width: 6),
                MyText(
                  text: "${widget.snap["likes"].length}",
                  textClr: primaryColor,
                  textSize: 12,
                ),
                const SizedBox(width: 10),
                Container(
                  width: 1,
                  height: 18,
                  color: secondaryColor.withOpacity(0.3),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
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
                              AsyncSnapshot<
                                QuerySnapshot<Map<String, dynamic>>
                              >
                              snapshot,
                            ) {
                              if (snapshot.connectionState ==
                                  ConnectionState.waiting) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: primaryColor,
                                  ),
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
                  child: const Icon(
                    Icons.messenger_outline,
                    color: primaryColor,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 6),
                MyText(
                  text: commentL.toString(),
                  textClr: primaryColor,
                  textSize: 12,
                ),
                const SizedBox(width: 10),
                Container(
                  width: 1,
                  height: 18,
                  color: secondaryColor.withOpacity(0.3),
                ),
                const SizedBox(width: 10),
                GestureDetector(
                  onTap: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: Colors.transparent,
                      builder:
                          (context) => SharePostSheet(
                            postId: _safeString(widget.snap["postId"]),
                            postUrl: _safeString(widget.snap["postUrl"]),
                            postOwnerUid: _safeString(widget.snap["uid"]),
                            postOwnerUsername: _safeString(
                              widget.snap["username"],
                            ),
                            postOwnerPhotoUrl: _safeString(
                              widget.snap["photoUrl"],
                            ),
                          ),
                    );
                  },
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
              ],
            ),
          ),

          // --- CAPTION ---
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



