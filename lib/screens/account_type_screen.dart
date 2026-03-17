import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/screens/switch_professional_intro_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';

enum AccountTypeChoice { personalPublic, professionalPublic }

class AccountTypeScreen extends StatelessWidget {
  final String uid;

  const AccountTypeScreen({super.key, required this.uid});

  String _accountTitle(String accountType) {
    return accountType == "professional" ? "Professional" : "Personal";
  }

  String _privacyLabel(bool isPublic) {
    return isPublic ? "Public" : "Private";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: const Text(
          "Account type",
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
          final username = (data["username"] ?? "").toString();

          AccountTypeChoice? groupValue;
          if (accountType == "personal" && isPublic) {
            groupValue = AccountTypeChoice.personalPublic;
          } else if (accountType == "professional" && isPublic) {
            groupValue = AccountTypeChoice.professionalPublic;
          }

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
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: secondaryColor.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _accountTitle(accountType),
                            style: const TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _privacyLabel(isPublic),
                            style: const TextStyle(color: secondaryColor),
                          ),
                        ],
                      ),
                    ),
                    if (username.isNotEmpty)
                      Text(
                        username,
                        style: const TextStyle(color: secondaryColor),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              const Text(
                "You can get access to more tools when you make your account "
                "public or switch to a professional account.",
                style: TextStyle(color: secondaryColor),
              ),
              const SizedBox(height: 16),
              const Text(
                "Other account types",
                style: TextStyle(
                  color: secondaryColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              RadioListTile<AccountTypeChoice>(
                value: AccountTypeChoice.personalPublic,
                groupValue: groupValue,
                activeColor: blueColor,
                title: const Text(
                  "Personal",
                  style: TextStyle(color: primaryColor),
                ),
                subtitle: const Text(
                  "Public",
                  style: TextStyle(color: secondaryColor),
                ),
                onChanged: (value) async {
                  await FirebaseFirestore.instance
                      .collection("users")
                      .doc(uid)
                      .update({
                        "accountType": "personal",
                        "isPublic": true,
                        "professionalCategory": "",
                        "professionalType": "",
                      });
                  if (context.mounted) {
                    showSnackBar(
                      context: context,
                      content: "Account updated to personal (public).",
                      clr: successColor,
                    );
                  }
                },
              ),
              const SizedBox(height: 6),
              RadioListTile<AccountTypeChoice>(
                value: AccountTypeChoice.professionalPublic,
                groupValue: groupValue,
                activeColor: blueColor,
                title: const Text(
                  "Professional",
                  style: TextStyle(color: primaryColor),
                ),
                subtitle: const Text(
                  "Public",
                  style: TextStyle(color: secondaryColor),
                ),
                onChanged: (value) {
                  if (accountType != "professional") {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => SwitchToProfessionalIntroScreen(uid: uid),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 6),
              const Text(
                "Personal accounts set to public with less than 1,000 "
                "followers can get access to tools like insights and "
                "scheduled content.",
                style: TextStyle(color: secondaryColor),
              ),
              const SizedBox(height: 12),
              const Text(
                "Professional accounts get access to additional tools for ads, "
                "monetization and messaging.",
                style: TextStyle(color: secondaryColor),
              ),
            ],
          );
        },
      ),
    );
  }
}
