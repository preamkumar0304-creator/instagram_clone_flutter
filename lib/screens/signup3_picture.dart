import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter_firebase/screens/signup4_username.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:instagram_clone_flutter_firebase/widgets/elevated_button.dart';
import 'package:instagram_clone_flutter_firebase/widgets/text.dart';

class SignupPicture extends StatefulWidget {
  final String email;
  final String password;
  const SignupPicture({super.key, required this.email, required this.password});

  @override
  State<SignupPicture> createState() => _SignupPictureState();
}

class _SignupPictureState extends State<SignupPicture> {
  Uint8List? image;
  void selectImage() async {
    Uint8List im = await pickImage(ImageSource.gallery);
    setState(() {
      image = im;
    });
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
                text: "Add a profile picture",
                textClr: primaryColor,
                textSize: 24,
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5, bottom: 5),
                child: MyText(
                  text:
                      "Add a profile picture so that your friends know it's you. Everyone will be able to see your picture.",
                  textClr: primaryColor,
                  textSize: 16,
                ),
              ),
              const SizedBox(height: 70),
              Center(
                child: CircleAvatar(
                  radius: 64,
                  backgroundImage:
                      image != null
                          ? MemoryImage(image!)
                          : NetworkImage(
                            "https://i.pinimg.com/236x/74/67/ac/7467acd73768ec753f20c4ac6cf39441.jpg",
                          ),
                ),
              ),
              Flexible(flex: 1, child: Container()),
              Padding(
                padding: const EdgeInsets.only(top: 10, bottom: 10),
                child: MyElevatedButton(
                  onPressed: () {
                    selectImage();
                  },
                  buttonText: "Add picture",
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(top: 5),
                child: MyElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (context) => SignupUsername(
                              email: widget.email,
                              password: widget.password,
                              file: image!,
                            ),
                      ),
                    );
                  },
                  buttonText: "Next",
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
