import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class ShareReelSheet extends StatefulWidget {
  final String reelId;
  final String reelUrl;
  final String reelOwnerUid;
  final String reelOwnerUsername;
  final String reelOwnerPhotoUrl;
  final String reelCoverUrl;
  final String reelThumbnailUrl;

  const ShareReelSheet({
    super.key,
    required this.reelId,
    required this.reelUrl,
    required this.reelOwnerUid,
    required this.reelOwnerUsername,
    required this.reelOwnerPhotoUrl,
    required this.reelCoverUrl,
    required this.reelThumbnailUrl,
  });

  @override
  State<ShareReelSheet> createState() => _ShareReelSheetState();
}

class _ShareReelSheetState extends State<ShareReelSheet> {
  bool _isSending = false;
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  String _followersKey = "";
  Future<List<Map<String, dynamic>>>? _followersFuture;
  final Set<String> _selected = {};

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

  Future<List<Map<String, dynamic>>> _followersFutureFor(List<String> ids) {
    final key = ids.join(",");
    if (_followersFuture == null || _followersKey != key) {
      _followersKey = key;
      _followersFuture = _loadUsers(ids);
    }
    return _followersFuture!;
  }

  String _chatId(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join("_");
  }

  Future<void> _sendTo(String targetUid) async {
    final fromUid = FirebaseAuth.instance.currentUser!.uid;
    final chatId = _chatId(fromUid, targetUid);
    await FirebaseFirestore.instance
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .add({
          "type": "share_reel",
          "text": "",
          "fromUid": fromUid,
          "toUid": targetUid,
          "reelId": widget.reelId,
          "reelUrl": widget.reelUrl,
          "reelOwnerUid": widget.reelOwnerUid,
          "reelOwnerUsername": widget.reelOwnerUsername,
          "reelOwnerPhotoUrl": widget.reelOwnerPhotoUrl,
          "reelCoverUrl": widget.reelCoverUrl,
          "reelThumbnailUrl": widget.reelThumbnailUrl,
          "createdAt": FieldValue.serverTimestamp(),
          "createdAtLocal": DateTime.now(),
          "reactions": {},
        });
    await FirestoreMethods().addNotification(
      toUid: targetUid,
      fromUid: fromUid,
      type: "share_reel",
      reelId: widget.reelId,
      reelCoverUrl:
          widget.reelCoverUrl.isNotEmpty
              ? widget.reelCoverUrl
              : widget.reelThumbnailUrl,
      message: "Shared a reel",
    );
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
      initialChildSize: 0.7,
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
                          autofocus: false,
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
                                      crossAxisCount: 4,
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
                                  final isSelected = _selected.contains(uid);
                                  return GestureDetector(
                                    onTap: () {
                                      setState(() {
                                        if (isSelected) {
                                          _selected.remove(uid);
                                        } else {
                                          _selected.add(uid);
                                        }
                                      });
                                    },
                                    child: Column(
                                      children: [
                                        Stack(
                                          children: [
                                            CircleAvatar(
                                              radius: 26,
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
                                            if (isSelected)
                                              Positioned(
                                                right: 0,
                                                bottom: 0,
                                                child: Container(
                                                  width: 18,
                                                  height: 18,
                                                  decoration: BoxDecoration(
                                                    color: blueColor,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          999,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.white,
                                                      width: 2,
                                                    ),
                                                  ),
                                                  child: const Icon(
                                                    Icons.check,
                                                    size: 12,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                          ],
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
                        const SizedBox(height: 10),
                        Center(
                          child: SizedBox(
                            height: 48,
                            child: ElevatedButton(
                              onPressed:
                                  _selected.isEmpty || _isSending
                                      ? null
                                      : () async {
                                        setState(() {
                                          _isSending = true;
                                        });
                                        try {
                                          final targets = _selected.toList();
                                          for (final uid in targets) {
                                            await _sendTo(uid);
                                          }
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                                  const SnackBar(
                                                    content: Text("Shared"),
                                                    backgroundColor:
                                                        successColor,
                                                  ),
                                                );
                                            Navigator.of(context).pop();
                                          }
                                        } catch (e) {
                                          if (mounted) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
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
                                      },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: blueColor,
                                disabledBackgroundColor: sheetBorder,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(24),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 36,
                                ),
                              ),
                              child: const Text("Send"),
                            ),
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
