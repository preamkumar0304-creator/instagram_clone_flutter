import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/methods/storage_methods.dart';
import 'package:instagram_clone_flutter_firebase/screens/chat_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/message_requests_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';

class MessagesScreen extends StatefulWidget {
  const MessagesScreen({super.key});

  @override
  State<MessagesScreen> createState() => _MessagesScreenState();
}

class _MessagesScreenState extends State<MessagesScreen>
    with AutomaticKeepAliveClientMixin {
  Future<List<Map<String, dynamic>>>? _contactsFuture;
  String _contactsSignature = "";

  List<String> _safeStringList(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toList();
    }
    return [];
  }

  String _safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  Future<List<Map<String, dynamic>>> _loadUsers(
    List<String> ids,
    String currentUid,
  ) async {
    if (ids.isEmpty) return [];
    final usersById = <String, Map<String, dynamic>>{};
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap =
          await FirebaseFirestore.instance
              .collection("users")
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
      for (final doc in snap.docs) {
        usersById[doc.id] = doc.data();
      }
    }

    final results = <Map<String, dynamic>>[];
    for (final id in ids) {
      final data = usersById[id];
      if (data == null) continue;
      final last = await _loadLastMessage(currentUid, id);
      final lastTime = _extractMessageTime(last);
      results.add({
        "uid": id,
        "name": _safeString(data["name"]),
        "username": _safeString(data["username"]),
        "photoUrl": _safeString(data["photoUrl"]),
        "lastMessage": last,
        "lastTime": lastTime,
      });
    }

    results.sort((a, b) {
      final aTime = a["lastTime"] as DateTime? ?? DateTime(1970);
      final bTime = b["lastTime"] as DateTime? ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });
    return results;
  }

  String _formatRelativeTime(DateTime date) {
    final now = DateTime.now();
    final diff = now.difference(date);
    if (diff.inMinutes < 1) return "now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    if (diff.inDays < 7) return "${diff.inDays}d";
    return "${date.day}/${date.month}/${date.year}";
  }

  String _chatId(String a, String b) {
    final ids = [a, b]..sort();
    return ids.join("_");
  }

  Future<Map<String, dynamic>?> _loadLastMessage(
    String currentUid,
    String otherUid,
  ) async {
    final chatId = _chatId(currentUid, otherUid);
    final snap =
        await FirebaseFirestore.instance
            .collection("chats")
            .doc(chatId)
            .collection("messages")
            .orderBy("createdAtLocal", descending: true)
            .limit(1)
            .get();
    if (snap.docs.isEmpty) return null;
    return snap.docs.first.data();
  }

  DateTime _extractMessageTime(Map<String, dynamic>? msg) {
    if (msg == null) return DateTime.fromMillisecondsSinceEpoch(0);
    final localRaw = msg["createdAtLocal"];
    if (localRaw is Timestamp) return localRaw.toDate();
    if (localRaw is DateTime) return localRaw;
    final createdRaw = msg["createdAt"];
    if (createdRaw is Timestamp) return createdRaw.toDate();
    if (createdRaw is DateTime) return createdRaw;
    return DateTime.fromMillisecondsSinceEpoch(0);
  }

  String _messagePreview(Map<String, dynamic>? msg) {
    if (msg == null) return "Tap to chat";
    final type = _safeString(msg["type"]);
    final imageUrl = _safeString(msg["imageUrl"]);
    final videoUrl = _safeString(msg["videoUrl"]);
    final audioUrl = _safeString(msg["audioUrl"]);
    if (type == "share_post") return "Shared a post";
    if (type == "share_reel") return "Shared a reel";
    if (type == "share_profile") return "Shared a profile";
    if (videoUrl.isNotEmpty || type == "video") return "Video";
    if (audioUrl.isNotEmpty || type == "audio") return "Voice message";
    if (imageUrl.isNotEmpty || type == "image") return "Photo";
    final text = _safeString(msg["text"]);
    return text.isEmpty ? "Tap to chat" : text;
  }

  Future<void> _sendCameraMessage({
    required BuildContext context,
    required String currentUid,
    required String otherUid,
  }) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(source: ImageSource.camera);
    if (image == null) return;
    try {
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) return;
      final chatId = _chatId(currentUid, otherUid);
      final fileName = "${chatId}_${DateTime.now().millisecondsSinceEpoch}";
      final imageUrl = await StorageMethods().uploadImageToStorage(
        "chatMedia",
        bytes,
        true,
        fileName: fileName,
      );
      await FirebaseFirestore.instance
          .collection("chats")
          .doc(chatId)
          .collection("messages")
          .add({
            "type": "image",
            "text": "",
            "imageUrl": imageUrl,
            "fromUid": currentUid,
            "toUid": otherUid,
            "createdAt": FieldValue.serverTimestamp(),
            "createdAtLocal": DateTime.now(),
            "reactions": {},
          });
      await FirestoreMethods().addNotification(
        toUid: otherUid,
        fromUid: currentUid,
        type: "message",
        message: "Photo",
      );
      if (mounted) {
        setState(() {
          _contactsFuture = null;
          _contactsSignature = "";
        });
      }
      if (context.mounted) {
        showSnackBar(
          context: context,
          content: "Photo sent.",
          clr: successColor,
        );
      }
    } catch (err) {
      if (context.mounted) {
        showSnackBar(
          context: context,
          content: err.toString(),
          clr: errorColor,
        );
      }
    }
  }

  void _showProfileOptions({
    required BuildContext context,
    required String currentUid,
    required String otherUid,
    required String username,
    required String name,
    required String photoUrl,
    required bool isMuted,
    required bool isBlocked,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: mobileBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundImage:
                          photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                      backgroundColor: Colors.grey.shade300,
                      child:
                          photoUrl.isEmpty
                              ? const Icon(Icons.person, color: Colors.black)
                              : null,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            username.isNotEmpty ? username : "User",
                            style: const TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (name.isNotEmpty)
                            Text(
                              name,
                              style: const TextStyle(color: secondaryColor),
                            ),
                        ],
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ProfileScreen(uid: otherUid),
                          ),
                        );
                      },
                      child: const Text("View profile"),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.block, color: primaryColor),
                title: Text(
                  isBlocked ? "Unblock" : "Block",
                  style: const TextStyle(color: primaryColor),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final ref =
                      FirebaseFirestore.instance
                          .collection("users")
                          .doc(currentUid);
                  await ref.update({
                    "blockedUsers":
                        isBlocked
                            ? FieldValue.arrayRemove([otherUid])
                            : FieldValue.arrayUnion([otherUid]),
                  });
                  if (context.mounted) {
                    showSnackBar(
                      context: context,
                      content: isBlocked ? "User unblocked." : "User blocked.",
                      clr: successColor,
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.notifications_off, color: primaryColor),
                title: Text(
                  isMuted ? "Unmute notifications" : "Mute notifications",
                  style: const TextStyle(color: primaryColor),
                ),
                onTap: () async {
                  Navigator.pop(context);
                  final ref =
                      FirebaseFirestore.instance
                          .collection("users")
                          .doc(currentUid);
                  await ref.update({
                    "mutedUsers":
                        isMuted
                            ? FieldValue.arrayRemove([otherUid])
                            : FieldValue.arrayUnion([otherUid]),
                  });
                  if (context.mounted) {
                    showSnackBar(
                      context: context,
                      content:
                          isMuted
                              ? "Notifications unmuted."
                              : "Notifications muted.",
                      clr: successColor,
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid;
    if (currentUid == null) {
      return const Center(
        child: CircularProgressIndicator(color: primaryColor),
      );
    }

    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        surfaceTintColor: mobileBackgroundColor,
        scrolledUnderElevation: 0,
        elevation: 0,
        titleSpacing: 16,
        title: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream:
              FirebaseFirestore.instance
                  .collection("users")
                  .doc(currentUid)
                  .snapshots(),
          builder: (context, snap) {
            final data = snap.data?.data() ?? {};
            final username = _safeString(data["username"]);
            return Text(
              username.isNotEmpty ? username : "Messages",
              style: const TextStyle(
                color: primaryColor,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_square, color: primaryColor),
            onPressed: () {
              showSnackBar(
                context: context,
                content: "New message coming soon.",
                clr: secondaryColor,
              );
            },
          ),
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection("users")
                .doc(currentUid)
                .snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          final followers = _safeStringList(data["followers"]);
          final following = _safeStringList(data["following"]);
          final blocked = _safeStringList(data["blockedUsers"]);
          final muted = _safeStringList(data["mutedUsers"]);
          final all =
              {...followers, ...following}
                  .where((id) => !blocked.contains(id))
                  .toList()
                ..sort();
          final requestCount =
              followers.where((id) => !following.contains(id)).length;

          final contactSignature = "${currentUid}_${all.join(",")}";
          if (_contactsFuture == null || _contactsSignature != contactSignature) {
            _contactsSignature = contactSignature;
            _contactsFuture = _loadUsers(all, currentUid);
          }

          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _contactsFuture,
            builder: (context, usersSnap) {
              if (usersSnap.connectionState == ConnectionState.waiting &&
                  usersSnap.data == null) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              final users = usersSnap.data ?? [];
              return RefreshIndicator(
                onRefresh: () async {
                  final refreshed = await _loadUsers(all, currentUid);
                  if (!mounted) return;
                  setState(() {
                    _contactsFuture = Future.value(refreshed);
                    _contactsSignature = contactSignature;
                  });
                },
                child: ListView.separated(
                  physics: const AlwaysScrollableScrollPhysics(
                    parent: BouncingScrollPhysics(),
                  ),
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  itemCount: users.isEmpty ? 2 : users.length + 1,
                  separatorBuilder: (_, index) {
                    if (index == 0) return const SizedBox(height: 12);
                    return const SizedBox(height: 8);
                  },
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return Row(
                        children: [
                          const Text(
                            "Messages",
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const Spacer(),
                          InkWell(
                            borderRadius: BorderRadius.circular(999),
                            onTap: () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const MessageRequestsScreen(),
                                ),
                              );
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(999),
                              ),
                              child: Text(
                                requestCount > 0
                                    ? "Requests ($requestCount)"
                                    : "Requests",
                                style: const TextStyle(
                                  color: primaryColor,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    if (users.isEmpty) {
                      return const Padding(
                        padding: EdgeInsets.only(top: 72),
                        child: Center(
                          child: Text(
                            "No contacts yet.",
                            style: TextStyle(
                              color: secondaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      );
                    }

                    final user = users[index - 1];
                    final uid = _safeString(user["uid"]);
                    final name = _safeString(user["name"]);
                    final username = _safeString(user["username"]);
                    final photoUrl = _safeString(user["photoUrl"]);
                    final isMuted = muted.contains(uid);
                    final isBlocked = blocked.contains(uid);
                    final msg = user["lastMessage"] as Map<String, dynamic>?;
                    final fromUid = msg == null ? "" : _safeString(msg["fromUid"]);
                    final showUnreadDot =
                        msg != null && fromUid.isNotEmpty && fromUid != currentUid;
                    final timeLabel =
                        msg == null ? "" : _formatRelativeTime(_extractMessageTime(msg));
                    final preview = _messagePreview(msg);

                    return _MessageThreadTile(
                      username: username.isNotEmpty ? username : "User",
                      lastMessage: preview,
                      timeLabel: timeLabel,
                      photoUrl: photoUrl,
                      showUnreadDot: showUnreadDot,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => ChatScreen(
                                  currentUid: currentUid,
                                  otherUid: uid,
                                  otherUsername: username,
                                  otherPhotoUrl: photoUrl,
                                ),
                          ),
                        );
                      },
                      onLongPress: () {
                        _showProfileOptions(
                          context: context,
                          currentUid: currentUid,
                          otherUid: uid,
                          username: username,
                          name: name,
                          photoUrl: photoUrl,
                          isMuted: isMuted,
                          isBlocked: isBlocked,
                        );
                      },
                      onCameraTap: () {
                        _sendCameraMessage(
                          context: context,
                          currentUid: currentUid,
                          otherUid: uid,
                        );
                      },
                    );
                  },
                ),
              );
            },
          );
        },
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _MessageThreadTile extends StatelessWidget {
  final String username;
  final String lastMessage;
  final String timeLabel;
  final String photoUrl;
  final bool showUnreadDot;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final VoidCallback onCameraTap;

  const _MessageThreadTile({
    required this.username,
    required this.lastMessage,
    required this.timeLabel,
    required this.photoUrl,
    required this.showUnreadDot,
    required this.onTap,
    required this.onLongPress,
    required this.onCameraTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      elevation: 0.6,
      shadowColor: Colors.black.withOpacity(0.08),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        onLongPress: onLongPress,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              CircleAvatar(
                radius: 24,
                backgroundImage: photoUrl.isNotEmpty ? NetworkImage(photoUrl) : null,
                backgroundColor: Colors.grey.shade200,
                child:
                    photoUrl.isEmpty
                        ? const Icon(Icons.person, color: primaryColor)
                        : null,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: primaryColor,
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      lastMessage,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: secondaryColor,
                        fontSize: 13,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (timeLabel.isNotEmpty)
                    Text(
                      timeLabel,
                      style: const TextStyle(
                        color: secondaryColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (showUnreadDot)
                        Container(
                          width: 8,
                          height: 8,
                          margin: const EdgeInsets.only(right: 8),
                          decoration: BoxDecoration(
                            color: Colors.black,
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      InkWell(
                        borderRadius: BorderRadius.circular(999),
                        onTap: onCameraTap,
                        child: const Padding(
                          padding: EdgeInsets.all(2),
                          child: Icon(
                            Icons.camera_alt_outlined,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
