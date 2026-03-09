import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/models/users.dart';
import 'package:instagram_clone_flutter_firebase/providers/user_provider.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:instagram_clone_flutter_firebase/widgets/text.dart';
import 'package:instagram_clone_flutter_firebase/widgets/text_button.dart';
import 'package:provider/provider.dart';

class AddPostScreen extends StatefulWidget {
  const AddPostScreen({super.key});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController captionController = TextEditingController();
  Uint8List? _file;
  bool _isLoading = false;
  _selectImage() {
    return showDialog(
      context: context,
      builder: (context) {
        return SimpleDialog(
          title: const Text("Create a post"),
          children: [
            SimpleDialogOption(
              padding: EdgeInsets.all(15),
              onPressed: () async {
                Navigator.of(context).pop();
                Uint8List file = await pickImage(ImageSource.camera);
                setState(() {
                  _file = file;
                });
              },
              child: Text("Take a photo"),
            ),
            SimpleDialogOption(
              padding: EdgeInsets.all(15),
              onPressed: () async {
                Navigator.of(context).pop();
                Uint8List file = await pickImage(ImageSource.gallery);
                setState(() {
                  _file = file;
                });
              },
              child: Text("Upload from gallery"),
            ),
          ],
        );
      },
    );
  }

  postImage(String uid, String username, String profileUrl) async {
    setState(() {
      _isLoading = true;
    });
    try {
      String message = await FirestoreMethods().uploadPost(
        captionController.text.trim(),
        _file!,
        uid,
        username,
        profileUrl,
      );
      if (message == "Post Successfully Added!") {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          showSnackBar(
            context: context,
            content: "Post Successfully Added!",
            clr: successColor,
          );
        }
        clearImage();
      } else {
        setState(() {
          _isLoading = false;
        });
        if (mounted) {
          showSnackBar(context: context, content: message, clr: errorColor);
        }
      }
    } catch (err) {
      setState(() {
        _isLoading = false;
      });
      if (mounted) {
        showSnackBar(
          context: context,
          content: err.toString(),
          clr: errorColor,
        );
      }
    }
  }

  clearImage() {
    setState(() {
      _file = null;
    });
  }

  @override
  void dispose() {
    super.dispose();
    captionController.dispose();
  }

  @override
  Widget build(BuildContext context) {
    UserModel? user = Provider.of<UserProvider>(context, listen: false).getUser;
    return GestureDetector(
      onTap: () {
        FocusScope.of(context).unfocus();
      },
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: mobileBackgroundColor,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: primaryColor),
            onPressed: () => clearImage(),
          ),
          title: MyText(text: "New post", textClr: primaryColor, textSize: 22),
          actions: [
            _file == null
                ? SizedBox.shrink()
                : MyTextButton(
                  buttonText: "Post",
                  txtClr: blueColor,
                  onPressed: () {
                    postImage(user!.uid, user.username, user.photoUrl);
                  },
                ),
          ],
        ),
        body:
            _file == null
                ? Center(
                  child: IconButton(
                    style: IconButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: blueColor),
                      ),
                    ),
                    color: primaryColor,
                    iconSize: 28,
                    tooltip: "Upload an image",
                    onPressed: () => _selectImage(),
                    icon: Icon(Icons.upload, color: primaryColor),
                  ),
                )
                : Center(
                  child: Column(
                    children: [
                      _isLoading
                          ? SizedBox(
                            width: MediaQuery.of(context).size.width * 0.9,
                            child: LinearProgressIndicator(
                              borderRadius: BorderRadius.circular(10),
                              color: blueColor,
                            ),
                          )
                          : SizedBox.shrink(),
                      Padding(
                        padding: const EdgeInsets.only(top: 20, bottom: 10),
                        child: InkWell(
                          onTap: () => _selectImage(),
                          child: Container(
                            height: 250,
                            width: MediaQuery.of(context).size.width * 0.9,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: secondaryColor),
                              image: DecorationImage(
                                image: MemoryImage(_file!),
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.center,
                              ),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.8,
                        child: TextField(
                          controller: captionController,
                          maxLines: 4,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Add a caption ...",
                            labelStyle: TextStyle(
                              color: primaryColor,
                              fontSize: 16,
                            ),
                            suffix: InkWell(
                              child: Icon(Icons.close, color: primaryColor),
                              onTap: () => captionController.clear(),
                            ),
                            filled: true,
                            fillColor: mobileBackgroundColor,
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
