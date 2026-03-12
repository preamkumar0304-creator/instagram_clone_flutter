import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/methods/auth_methods.dart';
import 'package:instagram_clone_flutter_firebase/responsive/responsive_layout_screen.dart';
import 'package:instagram_clone_flutter_firebase/responsive/mobile_screen_layout.dart';
import 'package:instagram_clone_flutter_firebase/responsive/web_screen_layout.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:instagram_clone_flutter_firebase/widgets/elevated_button.dart';
import 'package:instagram_clone_flutter_firebase/widgets/text.dart';
import 'package:instagram_clone_flutter_firebase/widgets/textfield.dart';

class SignupUsername extends StatefulWidget {
  final String email;
  final String password;
  final Uint8List? file;
  const SignupUsername({
    super.key,
    required this.email,
    required this.password,
    required this.file,
  });

  @override
  State<SignupUsername> createState() => _SignupUsernameState();
}

class _SignupUsernameState extends State<SignupUsername> {
  final TextEditingController usernameContoller = TextEditingController();
  final TextEditingController bioController = TextEditingController();
  bool _isLoading = false;
  String _selectedGender = "unspecified";

  @override
  void dispose() {
    super.dispose();
    usernameContoller.dispose();
    bioController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        iconTheme: IconThemeData(color: primaryColor),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.only(left: 20, right: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              MyText(
                text: "Review your username and bio",
                textClr: primaryColor,
                textSize: 24,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 5),
                child: MyText(
                  text:
                      "Add a username and bio. Your bio is visible to everyone on and off Instagram. You can change these at any time.",
                  textClr: primaryColor,
                  textSize: 16,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 5),
                child: TextFieldInput(
                  labelText: "Username",
                  textEditingController: usernameContoller,
                  textInputType: TextInputType.text,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 10),
                child: TextFieldInput(
                  labelText: "Bio",
                  textEditingController: bioController,
                  textInputType: TextInputType.text,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 10),
                child: DropdownButtonFormField<String>(
                  value: _selectedGender,
                  decoration: const InputDecoration(
                    labelText: "Gender",
                    labelStyle: TextStyle(color: primaryColor),
                    enabledBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: secondaryColor),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderSide: BorderSide(color: primaryColor),
                    ),
                  ),
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
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: MyElevatedButton(
                  onPressed: () async {
                    if (usernameContoller.text.trim().isEmpty) {
                      showSnackBar(
                        context: context,
                        content: "Please enter a username.",
                        clr: errorColor,
                      );
                      return;
                    }

                    setState(() {
                      _isLoading = true;
                    });

                    String message = await AuthMethods()
                        .signupWithEmailAndPassword(
                          email: widget.email,
                          password: widget.password,
                          file: widget.file,
                          username: usernameContoller.text.trim(),
                          bio: bioController.text.trim(),
                          gender: _selectedGender,
                        );

                    setState(() {
                      _isLoading = false;
                    });

                    if (message.toLowerCase().contains("success")) {
                      // ✅ success
                      showSnackBar(
                        context: context,
                        content: message,
                        clr: Colors.green,
                      );

                      if (context.mounted) {
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder:
                                (context) => const ResponsiveLayout(
                                  webScreenLayout: WebScreenLayout(),
                                  mobileScreenLayout: MobileScreenLayout(),
                                ),
                          ),
                        );
                      }
                    } else {
                      // ❌ error
                      showSnackBar(
                        context: context,
                        content: message,
                        clr: errorColor,
                      );
                    }
                  },
                  buttonText: "Sign Up",
                  isLoading: _isLoading,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
