import 'dart:math';
import 'dart:typed_data';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter_firebase/methods/storage_methods.dart';
import 'package:instagram_clone_flutter_firebase/providers/user_provider.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:provider/provider.dart';

class EditProfileScreen extends StatefulWidget {
  final String uid;
  final String initialName;
  final String initialUsername;
  final String initialPronouns;
  final String initialBio;
  final String initialGender;
  final String initialPhotoUrl;

  const EditProfileScreen({
    super.key,
    required this.uid,
    required this.initialName,
    required this.initialUsername,
    required this.initialPronouns,
    required this.initialBio,
    required this.initialGender,
    required this.initialPhotoUrl,
  });

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  late final TextEditingController _nameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _pronounsController;
  late final TextEditingController _bioController;
  late String _photoUrl;
  bool _isSaving = false;
  bool _isUploadingPhoto = false;
  late String _selectedGender;
  String _lastName = "";
  String _lastUsername = "";
  String _lastPronouns = "";
  String _lastBio = "";
  String _lastGender = "";
  String _lastPhotoUrl = "";

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.initialName);
    _usernameController = TextEditingController(text: widget.initialUsername);
    _pronounsController = TextEditingController(text: widget.initialPronouns);
    _bioController = TextEditingController(text: widget.initialBio);
    _photoUrl = widget.initialPhotoUrl;
    _selectedGender = widget.initialGender.isEmpty
        ? "unspecified"
        : widget.initialGender;
    _lastName = widget.initialName;
    _lastUsername = widget.initialUsername;
    _lastPronouns = widget.initialPronouns;
    _lastBio = widget.initialBio;
    _lastGender = _selectedGender;
    _lastPhotoUrl = _photoUrl;
    _loadUserFromFirestore();
  }

  @override
  void dispose() {
    _nameController.dispose();
    _usernameController.dispose();
    _pronounsController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  InputDecoration _inputDecoration(String labelText) {
    final eBorder = OutlineInputBorder(
      borderSide: const BorderSide(color: secondaryColor, width: 1.5),
      borderRadius: BorderRadius.circular(12),
    );
    final fBorder = OutlineInputBorder(
      borderSide: const BorderSide(color: primaryColor, width: 1.5),
      borderRadius: BorderRadius.circular(12),
    );
    return InputDecoration(
      labelText: labelText,
      labelStyle: const TextStyle(color: primaryColor, fontSize: 16),
      enabledBorder: eBorder,
      focusedBorder: fBorder,
      filled: true,
      fillColor: mobileBackgroundColor,
    );
  }

  void _setControllerIfUnchanged({
    required TextEditingController controller,
    required String newValue,
    required String lastValue,
  }) {
    if (controller.text == lastValue) {
      controller.text = newValue;
    }
  }

  Future<void> _loadUserFromFirestore() async {
    try {
      final snap =
          await FirebaseFirestore.instance
              .collection("users")
              .doc(widget.uid)
              .get();
      if (!snap.exists) return;
      final data = snap.data() ?? {};
      final name = (data["name"] ?? "").toString();
      final username = (data["username"] ?? "").toString();
      final pronouns = (data["pronouns"] ?? "").toString();
      final bio = (data["bio"] ?? "").toString();
      final gender = (data["gender"] ?? "").toString();
      final photoUrl = (data["photoUrl"] ?? "").toString();

      if (!mounted) return;
      setState(() {
        _setControllerIfUnchanged(
          controller: _nameController,
          newValue: name,
          lastValue: _lastName,
        );
        _setControllerIfUnchanged(
          controller: _usernameController,
          newValue: username,
          lastValue: _lastUsername,
        );
        _setControllerIfUnchanged(
          controller: _pronounsController,
          newValue: pronouns,
          lastValue: _lastPronouns,
        );
        _setControllerIfUnchanged(
          controller: _bioController,
          newValue: bio,
          lastValue: _lastBio,
        );
        if (_selectedGender == _lastGender) {
          _selectedGender = gender.isEmpty ? "unspecified" : gender;
        }
        if (_photoUrl == _lastPhotoUrl) {
          _photoUrl = photoUrl;
        }
        _lastName = name;
        _lastUsername = username;
        _lastPronouns = pronouns;
        _lastBio = bio;
        _lastGender = _selectedGender;
        _lastPhotoUrl = _photoUrl;
      });
    } catch (_) {
      // Ignore load errors; user can still edit existing values.
    }
  }

  Future<void> _batchUpdateFieldForUid({
    required String collection,
    required String field,
    required String value,
  }) async {
    final snap =
        await FirebaseFirestore.instance
            .collection(collection)
            .where("uid", isEqualTo: widget.uid)
            .get();
    if (snap.docs.isEmpty) return;

    const chunkSize = 400;
    for (var i = 0; i < snap.docs.length; i += chunkSize) {
      final batch = FirebaseFirestore.instance.batch();
      final end = min(i + chunkSize, snap.docs.length);
      for (var j = i; j < end; j++) {
        batch.update(snap.docs[j].reference, {field: value});
      }
      await batch.commit();
    }
  }

  Future<void> _changeProfilePhoto() async {
    if (_isUploadingPhoto) return;
    final file = await pickImage(ImageSource.gallery);
    if (file == null || (file as dynamic).isEmpty) return;

    setState(() {
      _isUploadingPhoto = true;
    });

    try {
      final uid = FirebaseAuth.instance.currentUser!.uid;
      final photoUrl = await StorageMethods().uploadImageToStorage(
        "profilePics",
        file as Uint8List,
        false,
      );
      await FirebaseFirestore.instance.collection("users").doc(uid).update({
        "photoUrl": photoUrl,
      });

      await _batchUpdateFieldForUid(
        collection: "posts",
        field: "photoUrl",
        value: photoUrl,
      );
      await _batchUpdateFieldForUid(
        collection: "stories",
        field: "photoUrl",
        value: photoUrl,
      );
      await _batchUpdateFieldForUid(
        collection: "reels",
        field: "photoUrl",
        value: photoUrl,
      );

      if (!mounted) return;
      setState(() {
        _photoUrl = photoUrl;
      });
      await Provider.of<UserProvider>(context, listen: false).refreshUser();
      if (mounted) {
        showSnackBar(
          context: context,
          content: "Profile photo updated.",
          clr: successColor,
        );
      }
    } on FirebaseException catch (err) {
      if (!mounted) return;
      if (err.code == "unauthorized" || err.code == "unauthenticated") {
        showSnackBar(
          context: context,
          content:
              "Upload blocked by Firebase Storage rules or App Check. "
              "Allow authenticated uploads in Storage rules.",
        );
      } else {
        showSnackBar(context: context, content: err.toString());
      }
    } catch (err) {
      if (mounted) {
        showSnackBar(context: context, content: err.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploadingPhoto = false;
        });
      }
    }
  }

  Future<void> _saveProfile() async {
    if (_isSaving) return;
    final newName = _nameController.text.trim();
    final newUsername = _usernameController.text.trim();
    final newPronouns = _pronounsController.text.trim();
    final newBio = _bioController.text.trim();
    final newGender = _selectedGender.trim().isEmpty
        ? "unspecified"
        : _selectedGender.trim();

    if (newUsername.isEmpty) {
      showSnackBar(
        context: context,
        content: "Username cannot be empty.",
        clr: errorColor,
      );
      return;
    }

    final updates = <String, dynamic>{};
    if (newName != widget.initialName) {
      updates["name"] = newName;
    }
    final usernameChanged = newUsername != widget.initialUsername;
    if (usernameChanged) {
      final existing =
          await FirebaseFirestore.instance
              .collection("users")
              .where("username", isEqualTo: newUsername)
              .limit(1)
              .get();
      if (existing.docs.isNotEmpty && existing.docs.first.id != widget.uid) {
        showSnackBar(
          context: context,
          content: "That username is already taken.",
          clr: errorColor,
        );
        return;
      }
      updates["username"] = newUsername;
    }
    if (newBio != widget.initialBio) {
      updates["bio"] = newBio;
    }
    if (newPronouns != widget.initialPronouns) {
      updates["pronouns"] = newPronouns;
    }
    if (newGender != widget.initialGender) {
      updates["gender"] = newGender;
    }

    if (updates.isEmpty) {
      showSnackBar(
        context: context,
        content: "No changes to save.",
        clr: secondaryColor,
      );
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      await FirebaseFirestore.instance
          .collection("users")
          .doc(widget.uid)
          .update(updates);

      if (usernameChanged) {
        await _batchUpdateFieldForUid(
          collection: "posts",
          field: "username",
          value: newUsername,
        );
        await _batchUpdateFieldForUid(
          collection: "stories",
          field: "username",
          value: newUsername,
        );
        await _batchUpdateFieldForUid(
          collection: "reels",
          field: "username",
          value: newUsername,
        );
      }

      if (!mounted) return;
      await Provider.of<UserProvider>(context, listen: false).refreshUser();
      if (mounted) {
        showSnackBar(
          context: context,
          content: "Profile updated.",
          clr: successColor,
        );
        Navigator.pop(context);
      }
    } catch (err) {
      if (mounted) {
        showSnackBar(context: context, content: err.toString());
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        iconTheme: const IconThemeData(color: primaryColor),
        title: const Text(
          "Edit profile",
          style: TextStyle(color: primaryColor),
        ),
        actions: [
          TextButton(
            onPressed: _isSaving ? null : _saveProfile,
            child: Text(
              _isSaving ? "Saving..." : "Save",
              style: const TextStyle(color: blueColor, fontSize: 16),
            ),
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      CircleAvatar(
                        radius: 36,
                        backgroundImage:
                            _photoUrl.isNotEmpty
                                ? NetworkImage(_photoUrl)
                                : null,
                        backgroundColor: Colors.grey.shade200,
                        child:
                            _photoUrl.isEmpty
                                ? const Icon(
                                  Icons.person,
                                  size: 32,
                                  color: Colors.black,
                                )
                                : null,
                      ),
                      if (_isUploadingPhoto)
                        const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: blueColor,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(width: 18),
                  CircleAvatar(
                    radius: 36,
                    backgroundColor: Colors.grey.shade300,
                    child: const Icon(Icons.face, color: Colors.black54),
                  ),
                ],
              ),
              TextButton(
                onPressed: _isUploadingPhoto ? null : _changeProfilePhoto,
                child: const Text(
                  "Edit picture or avatar",
                  style: TextStyle(color: blueColor, fontSize: 16),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _nameController,
                decoration: _inputDecoration("Name"),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _usernameController,
                decoration: _inputDecoration("Username"),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _pronounsController,
                decoration: _inputDecoration("Pronouns"),
                keyboardType: TextInputType.text,
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _bioController,
                decoration: _inputDecoration("Bio"),
                keyboardType: TextInputType.multiline,
                minLines: 2,
                maxLines: 4,
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    showSnackBar(
                      context: context,
                      content: "Add link coming soon.",
                      clr: secondaryColor,
                    );
                  },
                  child: const Text(
                    "Add link",
                    style: TextStyle(color: primaryColor),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    showSnackBar(
                      context: context,
                      content: "Add banners coming soon.",
                      clr: secondaryColor,
                    );
                  },
                  child: const Text(
                    "Add banners",
                    style: TextStyle(color: primaryColor),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              DropdownButtonFormField<String>(
                value: _selectedGender,
                decoration: _inputDecoration("Gender"),
                dropdownColor: mobileBackgroundColor,
                style: const TextStyle(color: primaryColor),
                iconEnabledColor: primaryColor,
                items: const [
                  DropdownMenuItem(
                    value: "unspecified",
                    child: Text("Prefer not to say"),
                  ),
                  DropdownMenuItem(value: "male", child: Text("Male")),
                  DropdownMenuItem(value: "female", child: Text("Female")),
                  DropdownMenuItem(value: "other", child: Text("Other")),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() {
                    _selectedGender = value;
                  });
                },
              ),
              const SizedBox(height: 10),
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text("Music", style: TextStyle(color: primaryColor)),
                subtitle: const Text(
                  "Add music to your profile",
                  style: TextStyle(color: secondaryColor),
                ),
                trailing: const Icon(Icons.chevron_right, color: secondaryColor),
                onTap: () {
                  showSnackBar(
                    context: context,
                    content: "Music coming soon.",
                    clr: secondaryColor,
                  );
                },
              ),
              const Divider(color: secondaryColor, height: 24),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    showSnackBar(
                      context: context,
                      content: "Professional account tools coming soon.",
                      clr: secondaryColor,
                    );
                  },
                  child: const Text(
                    "Switch to professional account",
                    style: TextStyle(color: blueColor),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    showSnackBar(
                      context: context,
                      content: "Personal information settings coming soon.",
                      clr: secondaryColor,
                    );
                  },
                  child: const Text(
                    "Personal information settings",
                    style: TextStyle(color: blueColor),
                  ),
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () {
                    showSnackBar(
                      context: context,
                      content: "Verification status coming soon.",
                      clr: secondaryColor,
                    );
                  },
                  child: const Text(
                    "Show your profile is verified",
                    style: TextStyle(color: blueColor),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
