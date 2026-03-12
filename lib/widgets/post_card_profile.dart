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
      decoration: isHeader
          ? const BoxDecoration(color: Color(0xFF1C1F24))
          : null,
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
        "days": 30,
        "interval": 6,
      },
      {
        "title": "Rs 199 - 3 days",
        "subtitle": "Reach ~1.5k-3k people",
        "days": 3,
        "interval": 4,
      },
      {
        "title": "Rs 399 - 7 days",
        "subtitle": "Reach ~4k-7k people",
        "days": 7,
        "interval": 5,
      },
      {
        "title": "Rs 799 - 14 days",
        "subtitle": "Reach ~10k-18k people",
        "days": 14,
        "interval": 6,
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
                          final postId = _safeString(widget.snap["postId"]);
                          if (postId.isNotEmpty) {
                            FirebaseFirestore.instance
                                .collection("posts")
                                .doc(postId)
                                .update({
                                  "isBoosted": true,
                                  "boostInterval": interval,
                                  "boostedAt": DateTime.now(),
                                  "boostExpiresAt":
                                      DateTime.now().add(Duration(days: days)),
                                });
                          }
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text("Boost enabled."),
                              backgroundColor: secondaryColor,
                              behavior: SnackBarBehavior.floating,
                              duration: Duration(seconds: 2),
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
                        border: Border.all(color: secondaryColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                        border: Border.all(color: secondaryColor),
                        borderRadius: BorderRadius.circular(12),
                      ),
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
                            decoration:
                                const BoxDecoration(color: Color(0xFF1C1F24)),
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
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(left: 12.0),
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
              const SizedBox(width: 4),
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
                    backgroundColor: Colors.transparent,
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

          if (isOwner) ...[
            const Divider(
              color: secondaryColor,
              height: 16,
              thickness: 0.3,
            ),
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
          ],

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



