import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/widgets/post_card_profile.dart';

class PostDetailScreen extends StatelessWidget {
  final String? uid; // UID of the user whose posts to show

  const PostDetailScreen({super.key, this.uid});

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;

    // Use given UID, or fallback to current logged-in user's UID
    final String currentUid = uid ?? FirebaseAuth.instance.currentUser!.uid;

    print("🔥 Showing posts for UID: $currentUid");

    return Scaffold(
      backgroundColor:
          width > 600 ? webBackgroundColor : mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor:
            width > 600 ? webBackgroundColor : mobileBackgroundColor,
        title: const Text(
          "Posts",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection("posts")
            .where("uid", isEqualTo: currentUid)
            .orderBy("postedDate", descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return const Center(
              child: Text(
                "No posts yet.",
                style: TextStyle(color: Colors.white70, fontSize: 16),
              ),
            );
          }

          return ListView.builder(
            itemCount: snapshot.data!.docs.length,
            itemBuilder: (context, index) {
              final postData = snapshot.data!.docs[index].data();

              return Container(
                margin: EdgeInsets.symmetric(
                  horizontal: width > 600 ? width * 0.3 : 0,
                  vertical: width > 600 ? 15 : 0,
                ),
                child: PostCardProfile(snap: postData),
              );
            },
          );
        },
      ),
    );
  }
}
