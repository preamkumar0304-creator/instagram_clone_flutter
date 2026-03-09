import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/widgets/elevated_button.dart';
import 'package:instagram_clone_flutter_firebase/widgets/text.dart';
import 'package:instagram_clone_flutter_firebase/widgets/textfield.dart';

class SignupPhoneNo extends StatefulWidget {
  const SignupPhoneNo({super.key});

  @override
  State<SignupPhoneNo> createState() => _SignupPhoneNoState();
}

class _SignupPhoneNoState extends State<SignupPhoneNo> {
  final TextEditingController phoneController = TextEditingController();
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
                text: "What's your mobile number?",
                textClr: primaryColor,
                textSize: 24,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 5),
                child: MyText(
                  text:
                      "Enter the mobile number on which you can be contacted. No one will see this on your profile.",
                  textClr: primaryColor,
                  textSize: 16,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                child: TextFieldInput(
                  labelText: "Mobile number",
                  textEditingController: phoneController,
                  textInputType: TextInputType.phone,
                ),
              ),
              MyText(
                text:
                    "You may receive WhatsApp and SMS notifications from us for security and login purposes.",
                textClr: primaryColor,
                textSize: 16,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                child: MyElevatedButton(onPressed: () {
                  
                },buttonText: "Next"),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: MyElevatedButton(onPressed: () {
                  
                },
                  buttonText: "Sign up with email address",
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
