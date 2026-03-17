import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/screens/account_type_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/switch_professional_intro_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/settings_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';

class AccountTypeToolsScreen extends StatelessWidget {
  final String uid;

  const AccountTypeToolsScreen({super.key, required this.uid});

  String _accountLabel(String accountType, bool isPublic) {
    final account = accountType == "professional" ? "Professional" : "Personal";
    final privacy = isPublic ? "public" : "private";
    return "$account ($privacy)";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: const Text(
          "Account type and tools",
          style: TextStyle(color: primaryColor),
        ),
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          final accountType = (data["accountType"] ?? "personal").toString();
          final isPublic = data["isPublic"] == true;
          final professionalCategory =
              (data["professionalCategory"] ?? "").toString();
          final isProfessional = accountType == "professional";

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const Text(
                "Your account",
                style: TextStyle(
                  color: secondaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.person_outline, color: primaryColor),
                title: const Text(
                  "Account type",
                  style: TextStyle(color: primaryColor),
                ),
                subtitle:
                    isProfessional && professionalCategory.isNotEmpty
                        ? Text(
                          professionalCategory,
                          style: const TextStyle(color: secondaryColor),
                        )
                        : null,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _accountLabel(accountType, isPublic),
                      style: const TextStyle(color: secondaryColor),
                    ),
                    const SizedBox(width: 6),
                    const Icon(Icons.chevron_right, color: secondaryColor),
                  ],
                ),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AccountTypeScreen(uid: uid),
                    ),
                  );
                },
              ),
              if (!isProfessional) ...[
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.settings, color: primaryColor),
                  title: const Text(
                    "Switch to professional account",
                    style: TextStyle(color: primaryColor),
                  ),
                  trailing: const Icon(
                    Icons.chevron_right,
                    color: secondaryColor,
                  ),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SwitchToProfessionalIntroScreen(uid: uid),
                      ),
                    );
                  },
                ),
              ],
              const SizedBox(height: 12),
              const Text(
                "Your tools",
                style: TextStyle(
                  color: secondaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.wifi_tethering, color: primaryColor),
                title: const Text("Live", style: TextStyle(color: primaryColor)),
                trailing: const Icon(
                  Icons.chevron_right,
                  color: secondaryColor,
                ),
                onTap: () {
                  showSnackBar(
                    context: context,
                    content: "Live tools coming soon.",
                    clr: secondaryColor,
                  );
                },
              ),
              const SizedBox(height: 12),
              const Text(
                "Get access to more tools",
                style: TextStyle(
                  color: secondaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              _DisabledToolTile(
                title: "Insights",
                subtitle: "Available to accounts that are public",
                enabled: isPublic,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SettingsScreen(openInsights: true),
                    ),
                  );
                },
              ),
              _DisabledToolTile(
                title: "Trial reels",
                subtitle: "Available to accounts that are public",
                enabled: isPublic,
              ),
              _DisabledToolTile(
                title: "Channels",
                subtitle: "Available to accounts that are public",
                enabled: isPublic,
              ),
              const SizedBox(height: 12),
              const Text(
                "Get access to professional tools",
                style: TextStyle(
                  color: secondaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                isProfessional
                    ? "Professional tools are enabled for your account."
                    : "Switch to a professional account for access to "
                        "monetization tools and more.",
                style: const TextStyle(color: secondaryColor),
              ),
              const SizedBox(height: 8),
              _DisabledToolTile(
                title: "Add tools",
                subtitle: "Available to professional accounts",
                enabled: isProfessional,
              ),
              _DisabledToolTile(
                title: "Monetization",
                subtitle: "Available to professional accounts",
                enabled: isProfessional,
              ),
              _DisabledToolTile(
                title: "Messaging tools",
                subtitle: "Available to professional accounts",
                enabled: isProfessional,
              ),
            ],
          );
        },
      ),
    );
  }
}

class _DisabledToolTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback? onTap;

  const _DisabledToolTile({
    required this.title,
    required this.subtitle,
    required this.enabled,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final textColor = enabled ? primaryColor : secondaryColor;
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(Icons.insights, color: textColor),
      title: Text(title, style: TextStyle(color: textColor)),
      subtitle: Text(subtitle, style: const TextStyle(color: secondaryColor)),
      trailing: const Icon(Icons.chevron_right, color: secondaryColor),
      onTap:
          enabled
              ? onTap ??
                  () {
                    showSnackBar(
                      context: context,
                      content: "$title is coming soon.",
                      clr: secondaryColor,
                    );
                  }
              : null,
    );
  }
}
