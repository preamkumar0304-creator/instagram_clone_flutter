import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/models/users.dart';
import 'package:instagram_clone_flutter_firebase/providers/user_provider.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/widgets/text.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

class CommentsBottomSheet extends StatefulWidget {
  final snap;
  final AsyncSnapshot<QuerySnapshot<Map<String, dynamic>>> snapshot;
  const CommentsBottomSheet({
    super.key,
    required this.snap,
    required this.snapshot,
  });

  @override
  State<CommentsBottomSheet> createState() => _CommentsBottomSheetState();
}

class _CommentsBottomSheetState extends State<CommentsBottomSheet> {
  final TextEditingController commentController = TextEditingController();
  bool isTyping = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    commentController.addListener(() {
      setState(() {
        isTyping = commentController.text.isNotEmpty;
      });
    });
  }

  @override
  void dispose() {
    commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    UserModel? user = Provider.of<UserProvider>(context).getUser;
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.vertical(top: Radius.circular(40)),
            color: secondaryColor.shade900,
          ),
          child: Column(
            children: [
              const Divider(
                thickness: 2,
                indent: 180,
                endIndent: 180,
                color: secondaryColor,
              ),
              MyText(
                text: "Comments",
                textClr: primaryColor,
                textSize: 16,
                textWeight: FontWeight.bold,
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: widget.snapshot.data!.docs.length,
                  itemBuilder:
                      (context, index) => Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.only(
                              left: 12,
                              top: 6,
                              bottom: 6,
                              right: 12,
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 16,
                                  backgroundImage: NetworkImage(
                                    "${widget.snapshot.data!.docs[index]["profileUrl"]}",
                                  ),
                                ),
                                Padding(
                                  padding: const EdgeInsets.only(left: 12),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      RichText(
                                        text: TextSpan(
                                          children: [
                                            TextSpan(
                                              text:
                                                  "${widget.snapshot.data!.docs[index]["username"]}   ",
                                              style: TextStyle(
                                                color: primaryColor,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 14,
                                              ),
                                            ),
                                            TextSpan(
                                              text: DateFormat.yMMMd().format(
                                                widget
                                                    .snapshot
                                                    .data!
                                                    .docs[index]["commentDate"]
                                                    .toDate(),
                                              ),
                                              style: TextStyle(
                                                color: secondaryColor,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                      MyText(
                                        text:
                                            "${widget.snapshot.data!.docs[index]["commentText"]}",
                                        textClr: primaryColor,
                                        textSize: 14,
                                      ),
                                    ],
                                  ),
                                ),
                                Spacer(),
                                IconButton(
                                  onPressed: () {},
                                  icon: Icon(
                                    Icons.favorite_border,
                                    color: primaryColor,
                                    size: 18,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 12),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundImage: NetworkImage(user!.photoUrl),
                      ),
                    ),
                    Expanded(
                      child: TextField(
                        style: TextStyle(color: primaryColor, fontSize: 14),
                        decoration: InputDecoration(
                          hintText: "Comment as ${user.username} ...",
                          hintStyle: TextStyle(
                            color: secondaryColor,
                            fontSize: 14,
                          ),
                          border: InputBorder.none,
                        ),
                        controller: commentController,
                        keyboardType: TextInputType.text,
                        textCapitalization: TextCapitalization.sentences,
                      ),
                    ),
                    isTyping
                        ? IconButton(
                          style: IconButton.styleFrom(
                            backgroundColor: blueColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                              side: BorderSide(color: blueColor),
                            ),
                          ),
                          color: primaryColor,
                          iconSize: 28,
                          tooltip: "Add comment",
                          onPressed: () async {
                            setState(() {
                              _isLoading = true;
                            });
                            String message = await FirestoreMethods()
                                .addComment(
                                  widget.snap["postId"],
                                  user.uid,
                                  user.username,
                                  user.photoUrl,
                                  commentController.text.trim(),
                                );
                            setState(() {
                              _isLoading = false;
                            });
                            if (message == "Comment Successfully Added!") {
                              commentController.clear();
                            }
                          },
                          icon:
                              _isLoading
                                  ? SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      color: primaryColor,
                                    ),
                                  )
                                  : Icon(Icons.upload, color: primaryColor),
                        )
                        : SizedBox.shrink(),
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
