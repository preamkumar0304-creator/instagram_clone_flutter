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

class _MessagesScreenState extends State<MessagesScreen> {

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

  Future<List<Map<String, dynamic>>> _loadUsersWithLastMessage(
    String currentUid,
    List<Map<String, dynamic>> users,
  ) async {
    final results = <Map<String, dynamic>>[];
    for (final user in users) {
      final uid = _safeString(user["uid"]);
      if (uid.isEmpty) continue;
      final msg = await _loadLastMessage(currentUid, uid);
      final time = _extractMessageTime(msg);
      results.add({
        ...user,
        "lastMessage": msg,
        "lastTime": time,
      });
    }
    results.sort((a, b) {
      final aTime = a["lastTime"] as DateTime? ?? DateTime(1970);
      final bTime = b["lastTime"] as DateTime? ?? DateTime(1970);
      return bTime.compareTo(aTime);
    });
    return results;
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
        setState(() {});
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
                fontWeight: FontWeight.w600,
              ),
            );
          },
        ),
        centerTitle: true,
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
                  .toList();
          final requestCount =
              followers.where((id) => !following.contains(id)).length;
          if (all.isEmpty) {
            return const Center(
              child: Text(
                "No contacts yet.",
                style: TextStyle(color: primaryColor),
              ),
            );
          }
          return FutureBuilder<List<Map<String, dynamic>>>(
            future: _loadUsers(all, currentUid),
            builder: (context, usersSnap) {
              if (usersSnap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }
              final users = usersSnap.data ?? [];
              if (users.isEmpty) {
                return const Center(
                  child: Text(
                    "No contacts yet.",
                    style: TextStyle(color: primaryColor),
                  ),
                );
              }
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                    child: Row(
                      children: [
                        const Text(
                          "Messages",
                          style: TextStyle(
                            color: primaryColor,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
                        InkWell(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MessageRequestsScreen(),
                              ),
                            );
                          },
                          child: Text(
                            requestCount > 0
                                ? "Requests ($requestCount)"
                                : "Requests",
                            style: const TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.separated(
                      itemCount: users.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: secondaryColor, height: 1),
                      itemBuilder: (context, index) {
                        final user = users[index];
                        final uid = _safeString(user["uid"]);
                        final name = _safeString(user["name"]);
                        final username = _safeString(user["username"]);
                        final photoUrl = _safeString(user["photoUrl"]);
                        final isMuted = muted.contains(uid);
                        final isBlocked = blocked.contains(uid);

                        return FutureBuilder<Map<String, dynamic>?>(
                          future: _loadLastMessage(currentUid, uid),
                          builder: (context, msgSnap) {
                            final msg = msgSnap.data;
                            final type =
                                msg == null ? "" : _safeString(msg["type"]);
                            final imageUrl =
                                msg == null ? "" : _safeString(msg["imageUrl"]);
                            final videoUrl =
                                msg == null ? "" : _safeString(msg["videoUrl"]);
                            final audioUrl =
                                msg == null ? "" : _safeString(msg["audioUrl"]);
                            final text = msg == null
                                ? "Tap to chat"
                                : (type == "share_post"
                                    ? "Shared a post"
                                    : type == "share_reel"
                                        ? "Shared a reel"
                                    : type == "share_profile"
                                        ? "Shared a profile"
                                        : videoUrl.isNotEmpty ||
                                                type == "video"
                                            ? "Video"
                                            : audioUrl.isNotEmpty ||
                                                    type == "audio"
                                                ? "Voice message"
                                                : imageUrl.isNotEmpty ||
                                                        type == "image"
                                                    ? "Photo"
                                                    : _safeString(
                                                      msg["text"],
                                                    ));
                            final createdAt = _extractMessageTime(msg);
                            final timeLabel =
                                msg == null ? "" : _formatRelativeTime(createdAt);
                            final fromUid =
                                msg == null ? "" : _safeString(msg["fromUid"]);
                            final showUnreadDot =
                                msg != null && fromUid.isNotEmpty &&
                                fromUid != currentUid;

                            return ListTile(
                              leading: GestureDetector(
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
                                child: CircleAvatar(
                                  backgroundImage:
                                      photoUrl.isNotEmpty
                                          ? NetworkImage(photoUrl)
                                          : null,
                                  backgroundColor: Colors.grey.shade300,
                                  child:
                                      photoUrl.isEmpty
                                          ? const Icon(
                                            Icons.person,
                                            color: Colors.black,
                                          )
                                          : null,
                                ),
                              ),
                              title: Text(
                                username.isNotEmpty ? username : "User",
                                style: const TextStyle(
                                  color: primaryColor,
                                  fontWeight: FontWeight.w400,
                                ),
                              ),
                              subtitle: Text(
                                timeLabel.isEmpty
                                    ? text
                                    : "$text · $timeLabel",
                                style: const TextStyle(
                                  color: secondaryColor,
                                  fontWeight: FontWeight.w400,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (showUnreadDot)
                                    Container(
                                      width: 8,
                                      height: 8,
                                      margin: const EdgeInsets.only(right: 10),
                                      decoration: BoxDecoration(
                                        color: Colors.black,
                                        borderRadius: BorderRadius.circular(999),
                                      ),
                                    ),
                                  IconButton(
                                    icon: const Icon(
                                      Icons.camera_alt_outlined,
                                      color: primaryColor,
                                    ),
                                    onPressed: () {
                                      _sendCameraMessage(
                                        context: context,
                                        currentUid: currentUid,
                                        otherUid: uid,
                                      );
                                    },
                                  ),
                                ],
                              ),
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
    );
  }
}
