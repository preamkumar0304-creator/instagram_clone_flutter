import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:instagram_clone_flutter_firebase/methods/auth_methods.dart';
import 'package:instagram_clone_flutter_firebase/responsive/responsive_layout_screen.dart';
import 'package:instagram_clone_flutter_firebase/responsive/mobile_screen_layout.dart';
import 'package:instagram_clone_flutter_firebase/responsive/web_screen_layout.dart';
import 'package:instagram_clone_flutter_firebase/screens/signup1_email.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/global_variables.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:instagram_clone_flutter_firebase/widgets/elevated_button.dart';
import 'package:instagram_clone_flutter_firebase/widgets/text_button.dart';
import 'package:instagram_clone_flutter_firebase/widgets/textfield.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController emailController = TextEditingController();
  final TextEditingController passwordController = TextEditingController();
  bool _isLoading = false;
  @override
  void dispose() {
    super.dispose();
    emailController.dispose();
    passwordController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding:
              MediaQuery.of(context).size.width > webScreenSize
                  ? EdgeInsets.symmetric(
                    horizontal: MediaQuery.of(context).size.width / 3,
                  )
                  : const EdgeInsets.only(left: 20, right: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Flexible(flex: 1, child: Container()),
              SvgPicture.asset("assets/instagramIcon.svg", height: 64),
              const SizedBox(height: 120),
              Padding(
                padding: const EdgeInsets.only(bottom: 5),
                child: TextFieldInput(
                  labelText: "Username, email address or mobile number",
                  textEditingController: emailController,
                  textInputType: TextInputType.emailAddress,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 5),
                child: TextFieldInput(
                  labelText: "Password",
                  textEditingController: passwordController,
                  textInputType: TextInputType.text,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 5),
                child: MyElevatedButton(
                  buttonText: "Log in",
                  isLoading: _isLoading,
                  onPressed: () async {
                    setState(() {
                      _isLoading = true;
                    });
                    String message = await AuthMethods()
                        .loginWithEmailAndPassword(
                          email: emailController.text.trim(),
                          password: passwordController.text.trim(),
                        );
                    setState(() {
                      _isLoading = false;
                    });
                    if (message == "User Logged In Successfully!") {
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
                      if (context.mounted) {
                        showSnackBar(
                          context: context,
                          content: message,
                          clr: errorColor,
                        );
                      }
                    }
                  },
                ),
              ),
              MyTextButton(buttonText: "Forgotten password?", onPressed: () {}),
              Flexible(flex: 1, child: Container()),
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: MyElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignupEmail(),
                      ),
                    );
                  },
                  buttonText: "Create new account",
                  bgClr: mobileBackgroundColor,
                  borderClr: blueColor,
                  textClr: blueColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
