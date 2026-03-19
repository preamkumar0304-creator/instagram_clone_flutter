import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/screens/blocked_users_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';

class PrivacySettingsScreen extends StatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  State<PrivacySettingsScreen> createState() => _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends State<PrivacySettingsScreen> {
  final _auth = FirebaseAuth.instance;

  Future<UserCredential> _reauthenticate(String currentPassword) async {
    final user = _auth.currentUser;
    if (user == null || user.email == null || user.email!.isEmpty) {
      throw Exception("Email not available for this account.");
    }
    final credential = EmailAuthProvider.credential(
      email: user.email!,
      password: currentPassword,
    );
    return user.reauthenticateWithCredential(credential);
  }

  Future<void> _changeEmail() async {
    final currentPasswordController = TextEditingController();
    final newEmailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: mobileBackgroundColor,
          title: const Text("Change email", style: TextStyle(color: primaryColor)),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: newEmailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: "New email"),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Enter a new email.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Current password"),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Enter current password.";
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(context, true);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _reauthenticate(currentPasswordController.text.trim());
      final newEmail = newEmailController.text.trim();
      await user.verifyBeforeUpdateEmail(newEmail);
      await FirebaseFirestore.instance
          .collection("users")
          .doc(user.uid)
          .update({"email": newEmail});
      if (mounted) {
        showSnackBar(
          context: context,
          content: "Verification email sent. Confirm to update email.",
          clr: successColor,
        );
      }
    } on FirebaseAuthException catch (err) {
      if (!mounted) return;
      showSnackBar(
        context: context,
        content: err.message ?? "Unable to update email.",
        clr: errorColor,
      );
    } catch (err) {
      if (!mounted) return;
      showSnackBar(
        context: context,
        content: err.toString(),
        clr: errorColor,
      );
    }
  }

  Future<void> _changePassword() async {
    final currentPasswordController = TextEditingController();
    final newPasswordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: mobileBackgroundColor,
          title: const Text(
            "Change password",
            style: TextStyle(color: primaryColor),
          ),
          content: Form(
            key: formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: currentPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "Current password"),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Enter current password.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: newPasswordController,
                  obscureText: true,
                  decoration: const InputDecoration(labelText: "New password"),
                  validator: (value) {
                    if (value == null || value.trim().length < 6) {
                      return "Password must be 6+ characters.";
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: confirmPasswordController,
                  obscureText: true,
                  decoration:
                      const InputDecoration(labelText: "Confirm password"),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return "Confirm your password.";
                    }
                    if (value.trim() != newPasswordController.text.trim()) {
                      return "Passwords do not match.";
                    }
                    return null;
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Cancel"),
            ),
            TextButton(
              onPressed: () {
                if (formKey.currentState?.validate() != true) return;
                Navigator.pop(context, true);
              },
              child: const Text("Save"),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      final user = _auth.currentUser;
      if (user == null) return;
      await _reauthenticate(currentPasswordController.text.trim());
      await user.updatePassword(newPasswordController.text.trim());
      if (mounted) {
        showSnackBar(
          context: context,
          content: "Password updated.",
          clr: successColor,
        );
      }
    } on FirebaseAuthException catch (err) {
      if (!mounted) return;
      showSnackBar(
        context: context,
        content: err.message ?? "Unable to update password.",
        clr: errorColor,
      );
    } catch (err) {
      if (!mounted) return;
      showSnackBar(
        context: context,
        content: err.toString(),
        clr: errorColor,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _auth.currentUser?.uid;
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
        title: const Text("Privacy", style: TextStyle(color: primaryColor)),
        iconTheme: const IconThemeData(color: primaryColor),
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream:
            FirebaseFirestore.instance.collection("users").doc(uid).snapshots(),
        builder: (context, snapshot) {
          final data = snapshot.data?.data() ?? {};
          final isPublic = data["isPublic"] == true;
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: mobileSearchColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.black12),
                ),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            "Private account",
                            style: TextStyle(
                              color: primaryColor,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 4),
                          Text(
                            "When your account is private, only approved followers can see your posts.",
                            style: TextStyle(color: secondaryColor),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: !isPublic,
                      activeColor: primaryColor,
                      onChanged: (value) async {
                        await FirebaseFirestore.instance
                            .collection("users")
                            .doc(uid)
                            .update({"isPublic": !value});
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              ListTile(
                leading: const Icon(Icons.email_outlined, color: primaryColor),
                title: const Text("Change email"),
                subtitle: Text(
                  (data["email"] ?? "").toString(),
                  style: const TextStyle(color: secondaryColor),
                ),
                trailing: const Icon(Icons.chevron_right, color: secondaryColor),
                onTap: _changeEmail,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.lock_outline, color: primaryColor),
                title: const Text("Change password"),
                trailing: const Icon(Icons.chevron_right, color: secondaryColor),
                onTap: _changePassword,
              ),
              const Divider(height: 1),
              ListTile(
                leading: const Icon(Icons.block, color: primaryColor),
                title: const Text("Blocked users"),
                trailing: const Icon(Icons.chevron_right, color: secondaryColor),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const BlockedUsersScreen()),
                  );
                },
              ),
            ],
          );
        },
      ),
    );
  }
}
