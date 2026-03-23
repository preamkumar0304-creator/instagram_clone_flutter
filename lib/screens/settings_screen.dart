import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/screens/activity_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/insights_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/messages_story_replies_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/privacy_settings_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/saved_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/time_management_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class SettingsScreen extends StatefulWidget {
  final bool openInsights;

  const SettingsScreen({super.key, this.openInsights = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _openedInsights = false;

  Widget _statusDot({double size = 10}) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
    );
  }

  Widget _trailingWithDot({required bool showDot}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showDot) _statusDot(),
        if (showDot) const SizedBox(width: 8),
        const Icon(Icons.chevron_right, color: secondaryColor),
      ],
    );
  }

  Widget _sectionLabel(String text) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
      child: Text(
        text,
        style: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _markNotificationsRead(String uid) async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection("users")
              .doc(uid)
              .collection("notifications")
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

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: mobileBackgroundColor,
        body: Center(
          child: CircularProgressIndicator(color: primaryColor),
        ),
      );
    }

    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: const Text("Settings", style: TextStyle(color: primaryColor)),
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          final isProfessional = (data["accountType"] ?? "") == "professional";
          final followRequests =
              (data["followRequests"] as List?)?.whereType<String>().toList() ??
              [];
          final hasFollowRequests = followRequests.isNotEmpty;

          if (widget.openInsights && isProfessional && !_openedInsights) {
            _openedInsights = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InsightsScreen()),
              );
            });
          }

          return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream:
                FirebaseFirestore.instance
                    .collection("users")
                    .doc(uid)
                    .collection("notifications")
                    .where("isRead", isEqualTo: false)
                    .limit(1)
                    .snapshots(),
            builder: (context, notifSnap) {
              final hasUnreadNotifications =
                  (notifSnap.data?.docs ?? []).isNotEmpty;

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _sectionLabel("For professionals"),
                  ListTile(
                    leading: const Icon(Icons.bar_chart, color: primaryColor),
                    title: const Text("Insights"),
                    subtitle: Text(
                      isProfessional
                          ? "View performance insights"
                          : "Available to professional accounts",
                    ),
                    trailing: const Icon(
                      Icons.chevron_right,
                      color: secondaryColor,
                    ),
                    onTap:
                        isProfessional
                            ? () {
                              Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => const InsightsScreen(),
                                ),
                              );
                            }
                            : null,
                  ),
                  const Divider(height: 1),
                  _sectionLabel("How you use Instagram"),
                  ListTile(
                    leading: const Icon(Icons.bookmark_border, color: primaryColor),
                    title: const Text("Saved"),
                    subtitle: const Text("Saved posts and reels"),
                    trailing: const Icon(Icons.chevron_right, color: secondaryColor),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SavedScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.favorite_border, color: primaryColor),
                    title: const Text("Your activity"),
                    subtitle: const Text("See recent interactions"),
                    trailing: const Icon(Icons.chevron_right, color: secondaryColor),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ActivityScreen()),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(
                      Icons.notifications_outlined,
                      color: primaryColor,
                    ),
                    title: const Text("Notifications"),
                    subtitle: const Text("Control your alerts"),
                    trailing: _trailingWithDot(
                      showDot: hasUnreadNotifications,
                    ),
                    onTap: () async {
                      await _markNotificationsRead(uid);
                      if (!mounted) return;
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const ActivityScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  ListTile(
                    leading: const Icon(Icons.timer_outlined, color: primaryColor),
                    title: const Text("Time management"),
                    subtitle: const Text("Track time, set limits, sleep mode"),
                    trailing: const Icon(Icons.chevron_right, color: secondaryColor),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TimeManagementScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _sectionLabel("Who can see your content"),
                  ListTile(
                    leading: const Icon(Icons.lock_outline, color: primaryColor),
                    title: const Text("Privacy"),
                    subtitle: const Text("Manage who can see your content"),
                    trailing: _trailingWithDot(
                      showDot: hasFollowRequests,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PrivacySettingsScreen(),
                        ),
                      );
                    },
                  ),
                  const Divider(height: 1),
                  _sectionLabel("How others can interact with you"),
                  ListTile(
                    leading: const Icon(
                      Icons.message_outlined,
                      color: primaryColor,
                    ),
                    title: const Text("Messages and story replies"),
                    subtitle: const Text("Control who can reach you"),
                    trailing: const Icon(Icons.chevron_right, color: secondaryColor),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const MessagesStoryRepliesScreen(),
                        ),
                      );
                    },
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
