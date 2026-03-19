import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/screens/insights_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/privacy_settings_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class SettingsScreen extends StatefulWidget {
  final bool openInsights;

  const SettingsScreen({super.key, this.openInsights = false});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  bool _openedInsights = false;

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

          if (widget.openInsights && isProfessional && !_openedInsights) {
            _openedInsights = true;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const InsightsScreen()),
              );
            });
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
              ListTile(
                leading: const Icon(Icons.lock_outline, color: primaryColor),
                title: const Text("Privacy"),
                subtitle: const Text("Manage who can see your content"),
                trailing: const Icon(Icons.chevron_right, color: secondaryColor),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const PrivacySettingsScreen(),
                    ),
                  );
                },
              ),
              const Divider(height: 1),
              const ListTile(
                leading: Icon(Icons.notifications_outlined, color: primaryColor),
                title: Text("Notifications"),
                subtitle: Text("Control your alerts"),
              ),
            ],
          );
        },
      ),
    );
  }
}
