import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/live_viewer_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';

class ActivityScreen extends StatelessWidget {
  const ActivityScreen({super.key});

  DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) return value.toDate();
    if (value is DateTime) return value;
    return null;
  }

  Map<String, DateTime> _parseTimestampMap(dynamic value) {
    if (value is! Map) return {};
    final result = <String, DateTime>{};
    value.forEach((key, raw) {
      if (key is! String) return;
      final parsed = _parseDateTime(raw);
      if (parsed != null) {
        result[key] = parsed;
      }
    });
    return result;
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

  Future<Map<String, Map<String, dynamic>>> _loadUsers(
    List<String> ids,
  ) async {
    if (ids.isEmpty) return {};
    final Map<String, Map<String, dynamic>> results = {};
    for (var i = 0; i < ids.length; i += 10) {
      final chunk = ids.sublist(i, i + 10 > ids.length ? ids.length : i + 10);
      final snap =
          await FirebaseFirestore.instance
              .collection("users")
              .where(FieldPath.documentId, whereIn: chunk)
              .get();
      for (final doc in snap.docs) {
        results[doc.id] = doc.data();
      }
    }
    return results;
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
        title: const Text("Activity", style: TextStyle(color: primaryColor)),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance
                .collection("users")
                .doc(currentUid)
                .snapshots(),
        builder: (context, userSnap) {
          final userData = userSnap.data?.data() ?? {};
          final followers =
              (userData["followers"] as List?)?.whereType<String>().toList() ??
              [];
          final followRequests =
              (userData["followRequests"] as List?)?.whereType<String>().toList() ??
              [];
          final blocked =
              (userData["blockedUsers"] as List?)?.whereType<String>().toList() ??
              [];
          final followRequestTimes =
              _parseTimestampMap(userData["followRequestTimes"]);
          final followerTimes = _parseTimestampMap(userData["followerTimes"]);

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance
                    .collection("posts")
                    .where("uid", isEqualTo: currentUid)
                    .orderBy("postedDate", descending: true)
                    .snapshots(),
            builder: (context, postSnap) {
              if (postSnap.connectionState == ConnectionState.waiting) {
                return const Center(
                  child: CircularProgressIndicator(color: primaryColor),
                );
              }

              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    FirebaseFirestore.instance
                        .collection("users")
                        .doc(currentUid)
                        .collection("notifications")
                        .orderBy("createdAt", descending: true)
                        .limit(20)
                        .snapshots(),
                builder: (context, notifSnap) {
                  final posts = postSnap.data?.docs ?? [];
                  final List<_ActivityItem> items = [];
                  final Set<String> userIds = {};

                  final notifications = notifSnap.data?.docs ?? [];
                  for (final doc in notifications) {
                    final data = doc.data();
                    if ((data["type"] ?? "") != "live") continue;
                    final fromUid = (data["fromUid"] ?? "").toString();
                    final liveId = (data["liveId"] ?? doc.id).toString();
                    final createdAt = _parseDateTime(data["createdAt"]);
                    if (fromUid.isEmpty || liveId.isEmpty) continue;
                    items.add(
                      _ActivityItem.live(
                        uid: fromUid,
                        liveId: liveId,
                        activityAt: createdAt,
                      ),
                    );
                    userIds.add(fromUid);
                  }

                  // Follow requests (private accounts)
                  for (final uid in followRequests) {
                    if (uid == currentUid) continue;
                    if (blocked.contains(uid)) continue;
                    if (followers.contains(uid)) continue;
                    items.add(
                      _ActivityItem.followRequest(
                        uid: uid,
                        activityAt: followRequestTimes[uid],
                      ),
                    );
                    userIds.add(uid);
                  }

                  // Followers
                  for (final uid in followers) {
                    if (uid == currentUid) continue;
                    items.add(
                      _ActivityItem.follow(
                        uid: uid,
                        activityAt: followerTimes[uid],
                      ),
                    );
                    userIds.add(uid);
                  }

                  // Likes on your posts
                  for (final doc in posts) {
                    final data = doc.data();
                    final postUrl = (data["postUrl"] ?? "") as String;
                    final postedAt = _parseDateTime(data["postedDate"]);
                    final likes =
                        (data["likes"] as List?)?.whereType<String>().toList() ??
                        [];
                    for (final liker in likes) {
                      if (liker == currentUid) continue;
                      items.add(
                        _ActivityItem.like(
                          uid: liker,
                          postUrl: postUrl,
                          activityAt: postedAt,
                        ),
                      );
                      userIds.add(liker);
                    }
                  }

                  if (items.isEmpty) {
                    return const Center(
                      child: Text(
                        "No activity yet.",
                        style: TextStyle(color: primaryColor),
                      ),
                    );
                  }

                  return FutureBuilder<Map<String, Map<String, dynamic>>>(
                    future: _loadUsers(userIds.toList()),
                    builder: (context, usersSnap) {
                      if (usersSnap.connectionState == ConnectionState.waiting) {
                        return const Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        );
                      }
                      final users = usersSnap.data ?? {};
                      items.sort((a, b) {
                        final aTime = a.activityAt;
                        final bTime = b.activityAt;
                        if (aTime == null && bTime == null) return 0;
                        if (aTime == null) return 1;
                        if (bTime == null) return -1;
                        return bTime.compareTo(aTime);
                      });

                      final now = DateTime.now();
                      final sections = <String, List<_ActivityItem>>{};
                      for (final item in items) {
                        final label = _bucketFor(now, item.activityAt);
                        sections.putIfAbsent(label, () => []).add(item);
                      }

                      final orderedLabels = [
                        "Today",
                        "Yesterday",
                        "This Week",
                        "Earlier",
                      ];
                      final children = <Widget>[];
                      for (final label in orderedLabels) {
                        final sectionItems = sections[label] ?? [];
                        if (sectionItems.isEmpty) continue;
                        children.add(_sectionHeader(label));
                        for (final item in sectionItems) {
                          final user = users[item.uid] ?? {};
                          final username =
                              (user["username"] ?? "user") as String;
                          final photoUrl = (user["photoUrl"] ?? "") as String;
                          children.add(
                            Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
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
                                onTap: () {
                                  if (item.type == _ActivityType.live &&
                                      item.liveId.isNotEmpty) {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder:
                                            (_) => LiveViewerScreen(
                                              liveId: item.liveId,
                                            ),
                                      ),
                                    );
                                    return;
                                  }
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder:
                                          (_) => ProfileScreen(uid: item.uid),
                                    ),
                                  );
                                },
                                leading: CircleAvatar(
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
                                title: Text(
                                  item.type == _ActivityType.followRequest
                                      ? "$username requested to follow you"
                                      : item.type == _ActivityType.follow
                                          ? "$username started following you"
                                          : item.type == _ActivityType.like
                                              ? "$username liked your post"
                                              : "$username is live now",
                                  style:
                                      const TextStyle(color: primaryColor),
                                ),
                                trailing:
                                    item.type == _ActivityType.followRequest
                                        ? Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            TextButton(
                                              onPressed: () async {
                                                await FirestoreMethods()
                                                    .acceptFollowRequest(
                                                      currentUid: currentUid,
                                                      requesterUid: item.uid,
                                                    );
                                                if (context.mounted) {
                                                  showSnackBar(
                                                    context: context,
                                                    content:
                                                        "Request accepted.",
                                                    clr: successColor,
                                                  );
                                                }
                                              },
                                              child: const Text("Accept"),
                                            ),
                                            const SizedBox(width: 6),
                                            OutlinedButton(
                                              onPressed: () async {
                                                await FirestoreMethods()
                                                    .declineFollowRequest(
                                                      currentUid: currentUid,
                                                      requesterUid: item.uid,
                                                    );
                                                if (context.mounted) {
                                                  showSnackBar(
                                                    context: context,
                                                    content:
                                                        "Request declined.",
                                                    clr: secondaryColor,
                                                  );
                                                }
                                              },
                                              child: const Text("Decline"),
                                            ),
                                          ],
                                        )
                                        : item.type == _ActivityType.like &&
                                                item.postUrl.isNotEmpty
                                            ? ClipRRect(
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: Image.network(
                                                item.postUrl,
                                                width: 44,
                                                height: 44,
                                                fit: BoxFit.cover,
                                              ),
                                            )
                                            : item.type == _ActivityType.live
                                                ? Container(
                                                  padding:
                                                      const EdgeInsets.symmetric(
                                                        horizontal: 8,
                                                        vertical: 4,
                                                      ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.red,
                                                    borderRadius:
                                                        BorderRadius.circular(6),
                                                  ),
                                                  child: const Text(
                                                    "LIVE",
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold,
                                                      fontSize: 12,
                                                    ),
                                                  ),
                                                )
                                                : null,
                              ),
                            ),
                          );
                        }
                      }

                      return ListView(
                        padding: const EdgeInsets.only(bottom: 16),
                        children: children,
                      );
                    },
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

enum _ActivityType { follow, like, live, followRequest }

class _ActivityItem {
  final _ActivityType type;
  final String uid;
  final String postUrl;
  final String liveId;
  final DateTime? activityAt;

  _ActivityItem.follow({required this.uid, required this.activityAt})
      : type = _ActivityType.follow,
        postUrl = "",
        liveId = "";

  _ActivityItem.followRequest({required this.uid, required this.activityAt})
      : type = _ActivityType.followRequest,
        postUrl = "",
        liveId = "";

  _ActivityItem.like({
    required this.uid,
    required this.postUrl,
    required this.activityAt,
  })
      : type = _ActivityType.like,
        liveId = "";

  _ActivityItem.live({
    required this.uid,
    required this.liveId,
    required this.activityAt,
  })
      : type = _ActivityType.live,
        postUrl = "";
}
