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
  final Uint8List? initialFile;
  const AddPostScreen({super.key, this.initialFile});

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController captionController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  Uint8List? _file;
  bool _isLoading = false;
  bool _createMenuShown = false;
  String _createType = "post";

  Future<void> _showCreateMenu() async {
    final type = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: mobileBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.auto_awesome, color: primaryColor),
                  title: const Text("Story"),
                  onTap: () => Navigator.pop(context, "story"),
                ),
                ListTile(
                  leading: const Icon(Icons.grid_on, color: primaryColor),
                  title: const Text("Post"),
                  onTap: () => Navigator.pop(context, "post"),
                ),
                ListTile(
                  leading: const Icon(Icons.video_library, color: primaryColor),
                  title: const Text("Reel"),
                  onTap: () => Navigator.pop(context, "reel"),
                ),
              ],
            ),
          ),
    );
    if (!mounted || type == null) return;
    _createType = type;

    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: mobileBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera, color: primaryColor),
                  title: const Text("Take photo"),
                  onTap: () => Navigator.pop(context, ImageSource.camera),
                ),
                ListTile(
                  leading: const Icon(Icons.photo, color: primaryColor),
                  title: const Text("Choose from gallery"),
                  onTap: () => Navigator.pop(context, ImageSource.gallery),
                ),
              ],
            ),
          ),
    );
    if (!mounted || source == null) return;

    if (_createType == "reel") {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: source);
      if (video == null) return;
      if (!mounted) return;
      showSnackBar(
        context: context,
        content: "Reel video selected (upload coming soon).",
        clr: successColor,
      );
      return;
    }

    final file = await pickImage(source);
    if (file == null) return;

    if (_createType == "post") {
      setState(() {
        _file = file;
      });
      return;
    }

    showSnackBar(
      context: context,
      content: "Story image selected (upload coming soon).",
      clr: successColor,
    );
  }

  _selectImage() {
    if (_isLoading) return;
    return _showCreateMenu();
  }

  postImage(String uid, String username, String profileUrl) async {
    if (_isLoading) return;
    if (_file == null || _file!.isEmpty) {
      showSnackBar(
        context: context,
        content: "Please select an image first.",
        clr: errorColor,
      );
      return;
    }

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
        location: locationController.text.trim(),
      );
      if (!mounted) return;
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
        showSnackBar(context: context, content: message, clr: errorColor);
      }
    } catch (err) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
      });
      showSnackBar(context: context, content: err.toString(), clr: errorColor);
    }
  }

  clearImage() {
    setState(() {
      _file = null;
    });
  }

  @override
  void initState() {
    super.initState();
    if (widget.initialFile != null) {
      _file = widget.initialFile;
      _createMenuShown = true;
    } else {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_createMenuShown) return;
        _createMenuShown = true;
        _showCreateMenu();
      });
    }
  }

  @override
  void dispose() {
    super.dispose();
    captionController.dispose();
    locationController.dispose();
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
          automaticallyImplyLeading: false,
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
                      const SizedBox(height: 8),
                      SizedBox(
                        width: MediaQuery.of(context).size.width * 0.8,
                        child: TextField(
                          controller: locationController,
                          maxLines: 1,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: "Add location",
                            labelStyle: TextStyle(
                              color: primaryColor,
                              fontSize: 16,
                            ),
                            prefixIcon: const Icon(
                              Icons.location_on_outlined,
                              color: secondaryColor,
                            ),
                            suffix: InkWell(
                              child: const Icon(Icons.close, color: primaryColor),
                              onTap: () => locationController.clear(),
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
