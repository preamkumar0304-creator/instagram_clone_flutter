import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/methods/auth_methods.dart';
import 'package:instagram_clone_flutter_firebase/screens/signup2_password.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:instagram_clone_flutter_firebase/widgets/elevated_button.dart';
import 'package:instagram_clone_flutter_firebase/widgets/text.dart';
import 'package:instagram_clone_flutter_firebase/widgets/textfield.dart';

class SignupEmail extends StatefulWidget {
  const SignupEmail({super.key});

  @override
  State<SignupEmail> createState() => _SignupEmailState();
}

class _SignupEmailState extends State<SignupEmail> {
  final TextEditingController emailController = TextEditingController();
  bool _isChecking = false;
  @override
  void dispose() {
    super.dispose();
    emailController.dispose();
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
                text: "What's your email address?",
                textClr: primaryColor,
                textSize: 24,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 5),
                child: MyText(
                  text:
                      "Enter the email address on which you can be contacted. No one will see this on your profile.",
                  textClr: primaryColor,
                  textSize: 16,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                child: TextFieldInput(
                  labelText: "Email address",
                  textEditingController: emailController,
                  textInputType: TextInputType.emailAddress,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                child: MyElevatedButton(
                  buttonText: "Next",
                  isLoading: _isChecking,
                  onPressed: () async {
                    if (_isChecking) return;
                    final email = emailController.text.trim();
                    setState(() {
                      _isChecking = true;
                    });

                    final error =
                        await AuthMethods().checkEmailAvailability(email);

                    if (!mounted) return;
                    setState(() {
                      _isChecking = false;
                    });

                    if (error != null) {
                      showSnackBar(
                        context: context,
                        content: error,
                        clr: errorColor,
                      );
                      return;
                    }

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => SignupPassword(email: email),
                      ),
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: MyElevatedButton(
                  onPressed: () {},
                  buttonText: "Sign up with Mobile Number",
                  bgClr: mobileBackgroundColor,
                  borderClr: secondaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
