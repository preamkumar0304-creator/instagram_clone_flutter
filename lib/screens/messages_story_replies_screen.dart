import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class MessagesStoryRepliesScreen extends StatelessWidget {
  const MessagesStoryRepliesScreen({super.key});

  Future<void> _updateBool(String uid, String field, bool value) async {
    await FirebaseFirestore.instance.collection("users").doc(uid).update({
      field: value,
    });
  }

  Future<void> _pickOnOff({
    required BuildContext context,
    required String uid,
    required String field,
    required String title,
    required bool currentValue,
  }) async {
    final selected = await showDialog<bool>(
      context: context,
      builder: (context) {
        return SimpleDialog(
          backgroundColor: mobileBackgroundColor,
          title: Text(title, style: const TextStyle(color: primaryColor)),
          children: [
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, true),
              child: Row(
                children: [
                  Icon(
                    currentValue ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 8),
                  const Text("On", style: TextStyle(color: primaryColor)),
                ],
              ),
            ),
            SimpleDialogOption(
              onPressed: () => Navigator.pop(context, false),
              child: Row(
                children: [
                  Icon(
                    !currentValue ? Icons.radio_button_checked : Icons.radio_button_off,
                    color: primaryColor,
                  ),
                  const SizedBox(width: 8),
                  const Text("Off", style: TextStyle(color: primaryColor)),
                ],
              ),
            ),
          ],
        );
      },
    );

    if (selected == null || selected == currentValue) return;
    await _updateBool(uid, field, selected);
  }

  Widget _sectionHeader(String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 22, 16, 8),
      child: Text(
        label,
        style: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.bold,
          fontSize: 15,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(
        backgroundColor: mobileBackgroundColor,
        body: Center(child: CircularProgressIndicator(color: primaryColor)),
      );
    }

    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: const Text(
          "Messages and story replies",
          style: TextStyle(color: primaryColor),
        ),
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          final messageRequests = data["messageRequests"] != false;
          final storyReplies = data["storyReplies"] != false;
          final showActivityStatus = data["showActivityStatus"] != false;
          final showReadReceipts = data["showReadReceipts"] != false;
          final nudityProtection = data["nudityProtection"] == true;
          final securityAlerts = data["securityAlerts"] != false;

          return ListView(
            children: [
              _sectionHeader("How people can reach you"),
              ListTile(
                title: const Text("Message requests"),
                subtitle: Text(
                  messageRequests ? "On" : "Off",
                  style: const TextStyle(color: secondaryColor),
                ),
                trailing: const Icon(Icons.chevron_right, color: secondaryColor),
                onTap: () => _pickOnOff(
                  context: context,
                  uid: uid,
                  field: "messageRequests",
                  title: "Message requests",
                  currentValue: messageRequests,
                ),
              ),
              const Divider(height: 1),
              ListTile(
                title: const Text("Story replies"),
                subtitle: Text(
                  storyReplies ? "On" : "Off",
                  style: const TextStyle(color: secondaryColor),
                ),
                trailing: const Icon(Icons.chevron_right, color: secondaryColor),
                onTap: () => _pickOnOff(
                  context: context,
                  uid: uid,
                  field: "storyReplies",
                  title: "Story replies",
                  currentValue: storyReplies,
                ),
              ),
              _sectionHeader("Who can see you're online"),
              SwitchListTile(
                title: const Text("Show activity status"),
                value: showActivityStatus,
                activeColor: primaryColor,
                onChanged: (value) => _updateBool(uid, "showActivityStatus", value),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text("Show read receipts"),
                value: showReadReceipts,
                activeColor: primaryColor,
                onChanged: (value) => _updateBool(uid, "showReadReceipts", value),
              ),
              _sectionHeader("What you see in messages"),
              SwitchListTile(
                title: const Text("Nudity protection"),
                value: nudityProtection,
                activeColor: primaryColor,
                onChanged: (value) => _updateBool(uid, "nudityProtection", value),
              ),
              _sectionHeader("End-to-end encryption"),
              SwitchListTile(
                title: const Text("Security alerts"),
                value: securityAlerts,
                activeColor: primaryColor,
                onChanged: (value) => _updateBool(uid, "securityAlerts", value),
              ),
              const SizedBox(height: 12),
            ],
          );
        },
      ),
    );
  }
}
