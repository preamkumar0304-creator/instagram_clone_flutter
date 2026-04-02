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
    if (!showDot) return const SizedBox.shrink();
    return _statusDot();
  }

  Widget _settingsTile({
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? trailing,
    VoidCallback? onTap,
  }) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      leading: Icon(icon, color: Colors.black54, size: 22),
      title: Text(
        title,
        style: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(color: secondaryColor, fontSize: 13),
      ),
      trailing: trailing,
      onTap: onTap,
    );
  }

  Future<void> _markNotificationsRead(String uid) async {
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
        title: const Text(
          "Settings",
          style: TextStyle(
            color: primaryColor,
            fontWeight: FontWeight.w600,
            fontSize: 18,
          ),
        ),
        iconTheme: const IconThemeData(color: primaryColor),
        elevation: 0,
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1, color: Color(0xFFE9E9E9)),
        ),
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
                    .collection("notifications")
                    .where("receiverId", isEqualTo: uid)
                    .where("isRead", isEqualTo: false)
                    .limit(1)
                    .snapshots(),
            builder: (context, notifSnap) {
              final hasUnreadNotifications =
                  (notifSnap.data?.docs ?? []).isNotEmpty;

              return ListView(
                padding: const EdgeInsets.fromLTRB(0, 8, 0, 16),
                children: [
                  _settingsTile(
                    icon: Icons.bar_chart_outlined,
                    title: "Insights",
                    subtitle:
                        isProfessional
                            ? "View performance insights"
                            : "Available to professional accounts",
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
                  const SizedBox(height: 6),
                  _settingsTile(
                    icon: Icons.bookmark_border,
                    title: "Saved",
                    subtitle: "Saved posts and reels",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const SavedScreen()),
                      );
                    },
                  ),
                  _settingsTile(
                    icon: Icons.favorite_border,
                    title: "Your activity",
                    subtitle: "See recent interactions",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (_) => const ActivityScreen()),
                      );
                    },
                  ),
                  _settingsTile(
                    icon: Icons.notifications_none,
                    title: "Notifications",
                    subtitle: "Control your alerts",
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
                  _settingsTile(
                    icon: Icons.timer_outlined,
                    title: "Time management",
                    subtitle: "Track time, set limits, sleep mode",
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const TimeManagementScreen(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 6),
                  _settingsTile(
                    icon: Icons.lock_outline,
                    title: "Privacy",
                    subtitle: "Manage who can see your content",
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
                  _settingsTile(
                    icon: Icons.chat_bubble_outline,
                    title: "Messages and story replies",
                    subtitle: "Control who can reach you",
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
