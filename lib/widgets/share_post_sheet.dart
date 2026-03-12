import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class SharePostSheet extends StatefulWidget {
  final String postId;
  final String postUrl;
  final String postOwnerUid;
  final String postOwnerUsername;
  final String postOwnerPhotoUrl;

  const SharePostSheet({
    super.key,
    required this.postId,
    required this.postUrl,
    required this.postOwnerUid,
    required this.postOwnerUsername,
    required this.postOwnerPhotoUrl,
  });

  @override
  State<SharePostSheet> createState() => _SharePostSheetState();
}

class _SharePostSheetState extends State<SharePostSheet> {
  bool _isSending = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _followersKey = "";
  Future<List<Map<String, dynamic>>>? _followersFuture;

  Future<List<Map<String, dynamic>>> _loadUsers(List<String> ids) async {
    if (ids.isEmpty) return [];
    final List<Map<String, dynamic>> results = [];
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap =
          await FirebaseFirestore.instance
              .collection("users")
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
      for (final doc in snap.docs) {
        final data = doc.data();
        results.add({
          "uid": doc.id,
          "username": data["username"] ?? "",
          "photoUrl": data["photoUrl"] ?? "",
        });
      }
    }
    return results;
  }

  Future<void> _incrementShareCount() async {
    await FirebaseFirestore.instance.collection("posts").doc(widget.postId).update(
      {"shareCount": FieldValue.increment(1)},
    );
  }

  Future<void> _sendTo(String targetUid) async {
    if (_isSending) return;
    setState(() {
      _isSending = true;
    });
    try {
      final fromUid = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance
          .collection("users")
          .doc(targetUid)
          .collection("shares")
          .add({
            "type": "post",
            "fromUid": fromUid,
            "postId": widget.postId,
            "postUrl": widget.postUrl,
            "postOwnerUid": widget.postOwnerUid,
            "postOwnerUsername": widget.postOwnerUsername,
            "postOwnerPhotoUrl": widget.postOwnerPhotoUrl,
            "createdAt": FieldValue.serverTimestamp(),
          });
      await _incrementShareCount();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Shared"),
            backgroundColor: successColor,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.toString()),
            backgroundColor: errorColor,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
      }
    }
  }

  Future<List<Map<String, dynamic>>> _followersFutureFor(List<String> ids) {
    final key = ids.join(",");
    if (_followersFuture == null || _followersKey != key) {
      _followersKey = key;
      _followersFuture = _loadUsers(ids);
    }
    return _followersFuture!;
  }

  @override
  void dispose() {
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      return const SizedBox.shrink();
    }
    const sheetBg = Colors.white;
    const sheetText = Colors.black87;
    const sheetHint = Colors.black45;
    const sheetBorder = Colors.black12;
    const searchFill = Color(0xFFF2F2F2);

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      minChildSize: 0.4,
      maxChildSize: 0.9,
      builder: (context, scrollController) {
        return AnimatedPadding(
          duration: const Duration(milliseconds: 150),
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            decoration: const BoxDecoration(
              color: sheetBg,
              borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance
                      .collection("users")
                      .doc(currentUid)
                      .snapshots(),
              builder: (context, snapshot) {
                final data = snapshot.data?.data() ?? {};
                final followers =
                    (data["followers"] as List?)
                        ?.whereType<String>()
                        .toList() ??
                    [];
                if (followers.isEmpty) {
                  return const Center(
                    child: Text(
                      "No followers to share with.",
                      style: TextStyle(color: sheetText),
                    ),
                  );
                }

                return FutureBuilder<List<Map<String, dynamic>>>(
                  future: _followersFutureFor(followers),
                  builder: (context, usersSnap) {
                    if (usersSnap.connectionState == ConnectionState.waiting) {
                      return const Center(
                        child: CircularProgressIndicator(color: primaryColor),
                      );
                    }
                    final users = usersSnap.data ?? [];

                    return Column(
                      children: [
                        Center(
                          child: Container(
                            width: 36,
                            height: 4,
                            decoration: BoxDecoration(
                              color: sheetBorder,
                              borderRadius: BorderRadius.circular(999),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          focusNode: _searchFocus,
                          controller: _searchController,
                          autofocus: true,
                          textInputAction: TextInputAction.search,
                          keyboardType: TextInputType.text,
                          style: const TextStyle(color: sheetText),
                          decoration: InputDecoration(
                            hintText: "Search",
                            hintStyle: const TextStyle(color: sheetHint),
                            prefixIcon: const Icon(
                              Icons.search,
                              color: sheetHint,
                            ),
                            filled: true,
                            fillColor: searchFill,
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: sheetBorder),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                              borderSide: const BorderSide(color: blueColor),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: ValueListenableBuilder<TextEditingValue>(
                            valueListenable: _searchController,
                            builder: (context, value, _) {
                              final query = value.text.trim().toLowerCase();
                              final filtered =
                                  query.isEmpty
                                      ? users
                                      : users
                                          .where(
                                            (u) => (u["username"] ?? "")
                                                .toString()
                                                .toLowerCase()
                                                .contains(query),
                                          )
                                          .toList();

                              return GridView.builder(
                                controller: scrollController,
                                gridDelegate:
                                    const SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: 3,
                                      crossAxisSpacing: 10,
                                      mainAxisSpacing: 10,
                                      childAspectRatio: 0.8,
                                    ),
                                itemCount: filtered.length,
                                itemBuilder: (context, index) {
                                  final user = filtered[index];
                                  final uid = (user["uid"] ?? "") as String;
                                  final username =
                                      (user["username"] ?? "") as String;
                                  final photoUrl =
                                      (user["photoUrl"] ?? "") as String;
                                  return GestureDetector(
                                    onTap:
                                        _isSending ? null : () => _sendTo(uid),
                                    child: Column(
                                      children: [
                                        CircleAvatar(
                                          radius: 28,
                                          backgroundImage:
                                              photoUrl.isNotEmpty
                                                  ? NetworkImage(photoUrl)
                                                  : null,
                                          child:
                                              photoUrl.isEmpty
                                                  ? const Icon(
                                                    Icons.person,
                                                    color: Colors.white,
                                                  )
                                                  : null,
                                        ),
                                        const SizedBox(height: 6),
                                        Text(
                                          username,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: const TextStyle(
                                            color: sheetText,
                                            fontSize: 12,
                                          ),
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
