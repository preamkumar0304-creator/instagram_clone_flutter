
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/screens/live_viewer_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/post_profile.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/reels_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';

class ActivityScreen extends StatefulWidget {
  const ActivityScreen({super.key});

  @override
  State<ActivityScreen> createState() => _ActivityScreenState();
}

class _ActivityScreenState extends State<ActivityScreen> {
  int _limit = 20;
  bool _markedRead = false;

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  String _bucketFor(DateTime now, DateTime? time) {
    if (time == null) return "Earlier";
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfYesterday = startOfToday.subtract(const Duration(days: 1));
    final startOf7Days = startOfToday.subtract(const Duration(days: 7));
    if (time.isAfter(startOfToday) || time.isAtSameMomentAs(startOfToday)) {
      return "Today";
    }
    if (time.isAfter(startOfYesterday) ||
        time.isAtSameMomentAs(startOfYesterday)) {
      return "Yesterday";
    }
    if (time.isAfter(startOf7Days) || time.isAtSameMomentAs(startOf7Days)) {
      return "This Week";
    }
    return "Earlier";
  }

  String _timeAgo(DateTime? time) {
    if (time == null) return "";
    final now = DateTime.now();
    final diff = now.difference(time);
    if (diff.inMinutes < 1) return "Just now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    if (diff.inDays < 7) return "${diff.inDays}d";
    return "${time.month}/${time.day}/${time.year}";
  }

  Future<void> _markAllRead(String uid) async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection("notifications")
              .where("receiverId", isEqualTo: uid)
              .where("isRead", isEqualTo: false)
              .get();
      if (snap.docs.isEmpty) return;
      final batch = FirebaseFirestore.instance.batch();
      for (final doc in snap.docs) {
        batch.update(doc.reference, {"isRead": true});
      }
      await batch.commit();
    } catch (_) {}
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
      child: Row(
        children: [
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: mobileSearchColor,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: secondaryColor.withOpacity(0.4)),
              ),
              child: Text(
                label,
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  List<_DisplayNotification> _batchItems(List<_NotificationItem> items) {
    final result = <_DisplayNotification>[];
    final used = <String>{};
    for (final item in items) {
      if (used.contains(item.id)) continue;
      if (_isBatchable(item)) {
        final group =
            items
                .where(
                  (other) =>
                      !used.contains(other.id) &&
                      other.type == item.type &&
                      other.postId == item.postId &&
                      item.postId.isNotEmpty,
                )
                .toList();
        if (group.length > 1) {
          used.addAll(group.map((e) => e.id));
          result.add(_DisplayNotification(group));
          continue;
        }
      }
      used.add(item.id);
      result.add(_DisplayNotification([item]));
    }
    return result;
  }

  bool _isBatchable(_NotificationItem item) {
    return (item.type == "like" ||
            item.type == "comment" ||
            item.type == "share_post") &&
        item.postId.isNotEmpty;
  }

  String _titleFor(_DisplayNotification display) {
    final first = display.items.first;
    if (display.count > 1) {
      if (first.type == "like") {
        return "${display.count} people liked your post";
      }
      if (first.type == "comment") {
        return "${display.count} people commented on your post";
      }
      if (first.type == "share_post") {
        return "${display.count} people shared your post";
      }
    }

    final username = first.senderUsername.isNotEmpty
        ? first.senderUsername
        : "Someone";
    switch (first.type) {
      case "like":
        return "$username liked your post";
      case "comment":
        return "$username commented on your post";
      case "message":
        return "$username sent you a message";
      case "follow":
        return "$username started following you";
      case "follow_request":
        return "$username requested to follow you";
      case "follow_accept":
        return "$username accepted your follow request";
      case "share_post":
        return "$username shared your post";
      case "share_reel":
        return "$username shared a reel";
      case "share_profile":
        return "$username shared a profile";
      case "live":
        return "$username is live now";
      default:
        return "$username sent you a notification";
    }
  }

  String _subtitleFor(_DisplayNotification display) {
    final first = display.items.first;
    if (display.count > 1) return _timeAgo(first.timestamp);
    final time = _timeAgo(first.timestamp);
    final detail =
        first.type == "comment" || first.type == "message"
            ? first.message
            : "";
    if (detail.isEmpty) return time;
    if (time.isEmpty) return detail;
    return "$detail ? $time";
  }

  Future<void> _markRead(String notificationId) async {
    if (notificationId.isEmpty) return;
    try {
      await FirebaseFirestore.instance
          .collection("notifications")
          .doc(notificationId)
          .update({"isRead": true});
    } catch (_) {}
  }

  void _openNotification(_NotificationItem item) {
    _markRead(item.id);
    if (item.type == "follow" ||
        item.type == "follow_request" ||
        item.type == "follow_accept") {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfileScreen(uid: item.senderId)),
      );
      return;
    }

    if (item.type == "share_profile" && item.profileUid.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ProfileScreen(uid: item.profileUid)),
      );
      return;
    }

    if (item.type == "live" && item.liveId.isNotEmpty) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LiveViewerScreen(liveId: item.liveId)),
      );
      return;
    }

    if (item.type == "share_reel") {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const ReelsScreen()),
      );
      return;
    }

    if (item.type == "like" ||
        item.type == "comment" ||
        item.type == "share_post") {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PostDetailScreen(uid: item.receiverId),
        ),
      );
      return;
    }
  }

  Widget _leadingAvatar(_NotificationItem item) {
    if (item.senderPhotoUrl.isEmpty) {
      return const CircleAvatar(
        child: Icon(Icons.person, color: Colors.white),
      );
    }
    return CircleAvatar(backgroundImage: NetworkImage(item.senderPhotoUrl));
  }

  Widget? _trailingFor(_DisplayNotification display) {
    final first = display.items.first;
    if (first.type == "follow_request") {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () async {
              await FirestoreMethods().acceptFollowRequest(
                currentUid: first.receiverId,
                requesterUid: first.senderId,
              );
              if (mounted) {
                showSnackBar(
                  context: context,
                  content: "Request accepted.",
                  clr: successColor,
                );
              }
            },
            child: const Text("Accept"),
          ),
          const SizedBox(width: 6),
          OutlinedButton(
            onPressed: () async {
              await FirestoreMethods().declineFollowRequest(
                currentUid: first.receiverId,
                requesterUid: first.senderId,
              );
              if (mounted) {
                showSnackBar(
                  context: context,
                  content: "Request declined.",
                  clr: secondaryColor,
                );
              }
            },
            child: const Text("Decline"),
          ),
        ],
      );
    }

    if (first.mediaUrl.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(6),
        child: Image.network(
          first.mediaUrl,
          width: 44,
          height: 44,
          fit: BoxFit.cover,
        ),
      );
    }

    return null;
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
        title: const Text("Notifications", style: TextStyle(color: primaryColor)),
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection("notifications")
                .where("receiverId", isEqualTo: currentUid)
                .orderBy("timestamp", descending: true)
                .limit(_limit)
                .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: primaryColor),
            );
          }

          final docs = snapshot.data?.docs ?? [];
          if (docs.isEmpty) {
            return const Center(
              child: Text(
                "No notifications yet.",
                style: TextStyle(color: primaryColor),
              ),
            );
          }

          final items =
              docs.map((doc) => _NotificationItem.fromDoc(doc)).toList();
          if (!_markedRead) {
            _markedRead = true;
            _markAllRead(currentUid);
          }

          final now = DateTime.now();
          final sections = <String, List<_NotificationItem>>{};
          for (final item in items) {
            final label = _bucketFor(now, item.timestamp);
            sections.putIfAbsent(label, () => []).add(item);
          }

          final orderedLabels = ["Today", "Yesterday", "This Week", "Earlier"];
          final children = <Widget>[];
          for (final label in orderedLabels) {
            final sectionItems = sections[label] ?? [];
            if (sectionItems.isEmpty) continue;
            children.add(_sectionHeader(label));
            final displayItems = _batchItems(sectionItems);
            for (final display in displayItems) {
              final first = display.items.first;
              final isUnread = display.items.any((e) => !e.isRead);
              children.add(
                Container(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: isUnread
                        ? mobileSearchColor.withOpacity(0.7)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: secondaryColor.withOpacity(0.2),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    onTap: () => _openNotification(first),
                    leading: _leadingAvatar(first),
                    title: Text(
                      _titleFor(display),
                      style: const TextStyle(color: primaryColor),
                    ),
                    subtitle: Text(
                      _subtitleFor(display),
                      style: const TextStyle(color: secondaryColor),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    trailing: _trailingFor(display),
                  ),
                ),
              );
            }
          }

          if (docs.length >= _limit) {
            children.add(
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Center(
                  child: OutlinedButton(
                    onPressed: () {
                      setState(() {
                        _limit += 20;
                      });
                    },
                    child: const Text("Load more"),
                  ),
                ),
              ),
            );
          }

          return ListView(
            padding: const EdgeInsets.only(bottom: 16),
            children: children,
          );
        },
      ),
    );
  }
}

class _NotificationItem {
  final String id;
  final String senderId;
  final String receiverId;
  final String type;
  final String message;
    final String postId;
    final String reelId;
    final String liveId;
    final String profileUid;
    final String mediaUrl;
  final String senderUsername;
  final String senderPhotoUrl;
  final DateTime? timestamp;
  final bool isRead;

  _NotificationItem({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.type,
    required this.message,
    required this.postId,
    required this.reelId,
    required this.liveId,
    required this.profileUid,
    required this.mediaUrl,
    required this.senderUsername,
    required this.senderPhotoUrl,
    required this.timestamp,
    required this.isRead,
  });

  factory _NotificationItem.fromDoc(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? {};
    return _NotificationItem(
      id: doc.id,
      senderId: (data["senderId"] ?? "").toString(),
      receiverId: (data["receiverId"] ?? "").toString(),
      type: (data["type"] ?? "").toString(),
      message: (data["message"] ?? "").toString(),
      postId: (data["postId"] ?? "").toString(),
      reelId: (data["reelId"] ?? "").toString(),
      liveId: (data["liveId"] ?? "").toString(),
      profileUid: (data["profileUid"] ?? "").toString(),
      mediaUrl: (data["mediaUrl"] ?? "").toString(),
      senderUsername: (data["senderUsername"] ?? "").toString(),
      senderPhotoUrl: (data["senderPhotoUrl"] ?? "").toString(),
      timestamp: _parseTimestamp(data["timestamp"]),
      isRead: data["isRead"] == true,
    );
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }
}

class _DisplayNotification {
  final List<_NotificationItem> items;

  _DisplayNotification(this.items);

  int get count => items.length;
}
