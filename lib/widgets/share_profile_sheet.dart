import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ShareProfileSheet extends StatefulWidget {
  final String profileUid;
  final String profileUsername;
  final String profilePhotoUrl;

  const ShareProfileSheet({
    super.key,
    required this.profileUid,
    required this.profileUsername,
    required this.profilePhotoUrl,
  });

  @override
  State<ShareProfileSheet> createState() => _ShareProfileSheetState();
}

class _ShareProfileSheetState extends State<ShareProfileSheet> {
  final TextEditingController _searchController = TextEditingController();
  final FocusNode _searchFocus = FocusNode();
  bool _isSending = false;
  final Set<String> _selected = {};
  String _followersKey = "";
  Future<List<Map<String, dynamic>>>? _followersFuture;

  String _profileLink() {
    final handle =
        widget.profileUsername.isNotEmpty
            ? widget.profileUsername
            : widget.profileUid;
    return "instagram_clone://profile/$handle";
  }

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

  Future<void> _sendProfileTo(String targetUid) async {
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) return;
    final chatId = _chatId(currentUid, targetUid);
    await FirebaseFirestore.instance
        .collection("chats")
        .doc(chatId)
        .collection("messages")
        .add({
          "type": "share_profile",
          "text": "",
          "fromUid": currentUid,
          "toUid": targetUid,
          "profileUid": widget.profileUid,
          "profileUsername": widget.profileUsername,
          "profilePhotoUrl": widget.profilePhotoUrl,
          "createdAt": FieldValue.serverTimestamp(),
          "createdAtLocal": DateTime.now(),
          "reactions": {},
        });
    await FirestoreMethods().addNotification(
      toUid: targetUid,
      fromUid: currentUid,
      type: "share_profile",
      profileUid: widget.profileUid,
      profilePhotoUrl: widget.profilePhotoUrl,
      message: "Shared a profile",
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
    final handle =
        widget.profileUsername.isNotEmpty
            ? "@${widget.profileUsername}"
            : "@user";
    final qrData = _profileLink();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: mobileBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: primaryColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: secondaryColor),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    "EMOJI",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 12),
            Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.12,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 26,
                        runSpacing: 26,
                        children: List.generate(
                          24,
                          (_) => const Icon(
                            Icons.emoji_emotions,
                            color: Colors.amber,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 12),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            QrImageView(
                              data: qrData,
                              size: 200,
                              foregroundColor: const Color(0xFFD67E10),
                            ),
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD67E10),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Color(0xFFD67E10),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          handle,
                          style: const TextStyle(
                            color: Color(0xFFD67E10),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShareAction(
                  label: "Copy link",
                  icon: Icons.link,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: qrData));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Profile link copied."),
                          backgroundColor: successColor,
                        ),
                      );
                    }
                  },
                ),
                _ShareAction(
                  label: "Download",
                  icon: Icons.download,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Download coming soon."),
                        backgroundColor: secondaryColor,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
            if (currentUid == null)
              const SizedBox.shrink()
            else
              StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
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
                    return const Text(
                      "No followers to share with.",
                      style: TextStyle(color: primaryColor),
                    );
                  }
                  return FutureBuilder<List<Map<String, dynamic>>>(
                    future: _followersFutureFor(followers),
                    builder: (context, usersSnap) {
                      if (usersSnap.connectionState ==
                          ConnectionState.waiting) {
                        return const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: CircularProgressIndicator(
                            color: primaryColor,
                          ),
                        );
                      }
                      final users = usersSnap.data ?? [];
                      return Column(
                        children: [
                          TextField(
                            focusNode: _searchFocus,
                            controller: _searchController,
                            textInputAction: TextInputAction.search,
                            keyboardType: TextInputType.text,
                            style: const TextStyle(color: primaryColor),
                            decoration: InputDecoration(
                              hintText: "Search",
                              hintStyle: const TextStyle(color: secondaryColor),
                              prefixIcon: const Icon(
                                Icons.search,
                                color: secondaryColor,
                              ),
                              filled: true,
                              fillColor: Colors.white,
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: secondaryColor,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(color: blueColor),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            height: 180,
                            child: ValueListenableBuilder<TextEditingValue>(
                              valueListenable: _searchController,
                              builder: (context, value, _) {
                                final query =
                                    value.text.trim().toLowerCase();
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
                                  itemCount: filtered.length,
                                  gridDelegate:
                                      const SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: 4,
                                        crossAxisSpacing: 10,
                                        mainAxisSpacing: 10,
                                        childAspectRatio: 0.8,
                                      ),
                                  itemBuilder: (context, index) {
                                    final user = filtered[index];
                                    final uid = (user["uid"] ?? "") as String;
                                    final username =
                                        (user["username"] ?? "") as String;
                                    final photoUrl =
                                        (user["photoUrl"] ?? "") as String;
                                    final isSelected =
                                        _selected.contains(uid);
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
                                                radius: 24,
                                                backgroundImage:
                                                    photoUrl.isNotEmpty
                                                        ? NetworkImage(
                                                          photoUrl,
                                                        )
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
                                              color: primaryColor,
                                              fontSize: 11,
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
                                              await _sendProfileTo(uid);
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
                                  disabledBackgroundColor: Colors.black12,
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
          ],
        ),
      ),
    );
  }
}

class _ShareAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ShareAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12),
              color: Colors.white,
            ),
            child: Icon(icon, color: primaryColor),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: primaryColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
