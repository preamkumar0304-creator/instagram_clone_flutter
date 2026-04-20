import 'package:flutter/material.dart';
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
  bool _obscurePassword = true;

  @override
  void dispose() {
    emailController.dispose();
    passwordController.dispose();
    super.dispose();
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
                  : const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              const Spacer(),
              Image.asset(
                "assets/branding/logo.1.png",
                height: 64,
                width: 64,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox(
                    height: 64,
                    width: 64,
                    child: Icon(Icons.public, color: primaryColor, size: 32),
                  );
                },
              ),
              const SizedBox(height: 32),
              TextFieldInput(
                labelText: "Username, email address or mobile number",
                textEditingController: emailController,
                textInputType: TextInputType.emailAddress,
              ),
              const SizedBox(height: 12),
              TextFieldInput(
                labelText: "Password",
                textEditingController: passwordController,
                textInputType: TextInputType.text,
                obscureText: _obscurePassword,
                suffixIcon: IconButton(
                  icon: Icon(
                    _obscurePassword
                        ? Icons.visibility_off_outlined
                        : Icons.visibility_outlined,
                    color: secondaryColor,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscurePassword = !_obscurePassword;
                    });
                  },
                ),
              ),
              const SizedBox(height: 16),
              MyElevatedButton(
                buttonText: "Log in",
                isLoading: _isLoading,
                textClr: Colors.white,
                onPressed: () async {
                  setState(() {
                    _isLoading = true;
                  });
                  String message = await AuthMethods().loginWithEmailAndPassword(
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
              const SizedBox(height: 8),
              MyTextButton(buttonText: "Forgotten password?", onPressed: () {}),
              const Spacer(),
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
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
                  textClr: primaryColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
