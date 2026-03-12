import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/models/story_media_item.dart';
import 'package:instagram_clone_flutter_firebase/models/users.dart';
import 'package:instagram_clone_flutter_firebase/providers/user_provider.dart';
import 'package:instagram_clone_flutter_firebase/screens/story_compose_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:instagram_clone_flutter_firebase/widgets/text.dart';
import 'package:instagram_clone_flutter_firebase/widgets/text_button.dart';
import 'package:provider/provider.dart';

class AddPostScreen extends StatefulWidget {
  final Uint8List? initialFile;
  final String? initialCreateType;
  final ImageSource? initialSource;
  final bool autoPick;
  final bool popAfterStoryPick;
  const AddPostScreen({
    super.key,
    this.initialFile,
    this.initialCreateType,
    this.initialSource,
    this.autoPick = false,
    this.popAfterStoryPick = false,
  });

  @override
  State<AddPostScreen> createState() => _AddPostScreenState();
}

class _AddPostScreenState extends State<AddPostScreen> {
  final TextEditingController captionController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final FocusNode _locationFocus = FocusNode();
  Uint8List? _file;
  bool _isLoading = false;
  bool _createMenuShown = false;
  String _createType = "post";
  bool _useCurrentLocation = false;
  bool _isFetchingLocation = false;

  Future<StoryMediaType?> _selectStoryMediaType() async {
    return showModalBottomSheet<StoryMediaType>(
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
                  leading: const Icon(Icons.photo, color: primaryColor),
                  title: const Text("Photos"),
                  onTap: () => Navigator.pop(context, StoryMediaType.image),
                ),
                ListTile(
                  leading: const Icon(Icons.videocam, color: primaryColor),
                  title: const Text("Video (15s)"),
                  onTap: () => Navigator.pop(context, StoryMediaType.video),
                ),
              ],
            ),
          ),
    );
  }

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
    await _pickFromSource(source);
  }

  _selectImage() {
    if (_isLoading) return;
    return _showCreateMenu();
  }

  Future<void> _pickFromSource(ImageSource source) async {
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

    if (_createType == "post") {
      final file = await pickImage(source);
      if (file == null) return;
      setState(() {
        _file = file;
      });
      return;
    }

    if (_createType == "story") {
      final user = Provider.of<UserProvider>(context, listen: false).getUser;
      if (user == null) return;
      final mediaType = await _selectStoryMediaType();
      if (mediaType == null) return;
      final picker = ImagePicker();
      final items = <StoryMediaItem>[];
      if (mediaType == StoryMediaType.video) {
        final video = await picker.pickVideo(
          source: source,
          maxDuration: const Duration(seconds: 15),
        );
        if (video == null) return;
        items.add(StoryMediaItem.video(video.path));
      } else {
        if (source == ImageSource.gallery) {
          final images = await picker.pickMultiImage();
          if (images.isEmpty) return;
          for (final image in images) {
            final bytes = await image.readAsBytes();
            if (bytes.isEmpty) continue;
            items.add(StoryMediaItem.image(bytes));
          }
        } else {
          final image = await picker.pickImage(source: source);
          if (image == null) return;
          final bytes = await image.readAsBytes();
          if (bytes.isNotEmpty) {
            items.add(StoryMediaItem.image(bytes));
          }
        }
      }
      if (!mounted || items.isEmpty) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => StoryComposeScreen(items: items, user: user),
        ),
      );
      if (widget.popAfterStoryPick && mounted) {
        Navigator.of(context).pop();
      }
    }
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
        locationController.text.trim(),
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
    } else if (widget.autoPick && widget.initialCreateType != null) {
      _createType = widget.initialCreateType!;
      _createMenuShown = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pickFromSource(widget.initialSource ?? ImageSource.gallery);
      });
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
    _locationFocus.dispose();
  }

  Future<void> _setCurrentLocation() async {
    if (_isFetchingLocation) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _useCurrentLocation = true;
      _isFetchingLocation = true;
    });

    try {
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (!mounted) return;
        await _showLocationDialog(
          title: "Turn on location",
          message: "Please enable location services to use current location.",
          openSettings: () => Geolocator.openLocationSettings(),
        );
        setState(() {
          _useCurrentLocation = false;
          _isFetchingLocation = false;
        });
        return;
      }

      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        if (!mounted) return;
        await _showLocationDialog(
          title: "Allow location access",
          message: permission == LocationPermission.deniedForever
              ? "Location permission is permanently denied. Please enable it in settings."
              : "Please allow location permission to use current location.",
          openSettings: () => Geolocator.openAppSettings(),
        );
        setState(() {
          _useCurrentLocation = false;
          _isFetchingLocation = false;
        });
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );
      final places = await placemarkFromCoordinates(
        position.latitude,
        position.longitude,
      );
      final place = places.isNotEmpty ? places.first : null;
      final parts = <String>[];
      final locality = place?.locality ?? "";
      final admin = place?.administrativeArea ?? "";
      final country = place?.country ?? "";
      if (locality.isNotEmpty) parts.add(locality);
      if (admin.isNotEmpty) parts.add(admin);
      if (country.isNotEmpty) parts.add(country);

      final label = parts.join(", ");
      locationController.text = label.isEmpty ? "Current location" : label;
    } catch (err) {
      if (!mounted) return;
      showSnackBar(
        context: context,
        content: "Unable to fetch current location.",
        clr: errorColor,
      );
      setState(() {
        _useCurrentLocation = false;
      });
    } finally {
      if (mounted) {
        setState(() {
          _isFetchingLocation = false;
        });
      }
    }
  }

  Future<void> _showLocationDialog({
    required String title,
    required String message,
    required Future<bool> Function() openSettings,
  }) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: mobileBackgroundColor,
          title: Text(title, style: const TextStyle(color: primaryColor)),
          content: Text(message, style: const TextStyle(color: primaryColor)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: primaryColor)),
            ),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                await openSettings();
              },
              child: const Text("Open settings", style: TextStyle(color: blueColor)),
            ),
          ],
        );
      },
    );
  }

  void _enableManualLocation() {
    setState(() {
      _useCurrentLocation = false;
    });
    FocusScope.of(context).requestFocus(_locationFocus);
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
                : SafeArea(
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      return SingleChildScrollView(
                        padding: EdgeInsets.only(
                          bottom: MediaQuery.of(context).viewInsets.bottom + 12,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            minHeight: constraints.maxHeight,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (_isLoading)
                                SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.9,
                                  child: LinearProgressIndicator(
                                    borderRadius: BorderRadius.circular(10),
                                    color: blueColor,
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.only(
                                  top: 20,
                                  bottom: 10,
                                ),
                                child: InkWell(
                                  onTap: () => _selectImage(),
                                  child: Container(
                                    height: 250,
                                    width:
                                        MediaQuery.of(context).size.width * 0.9,
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
                                  textAlignVertical: TextAlignVertical.top,
                                  decoration: InputDecoration(
                                    border: InputBorder.none,
                                    hintText: "Add a caption ...",
                                    labelStyle: TextStyle(
                                      color: primaryColor,
                                      fontSize: 16,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: const Icon(
                                        Icons.close,
                                        color: primaryColor,
                                      ),
                                      onPressed: () => captionController.clear(),
                                    ),
                                    filled: true,
                                    fillColor: mobileBackgroundColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.8,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _setCurrentLocation,
                                        icon: const Icon(
                                          Icons.my_location,
                                          color: primaryColor,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          "Use current",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: primaryColor),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: secondaryColor,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed: _enableManualLocation,
                                        icon: const Icon(
                                          Icons.edit_location_alt_outlined,
                                          color: primaryColor,
                                          size: 18,
                                        ),
                                        label: const Text(
                                          "Enter location",
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(color: primaryColor),
                                        ),
                                        style: OutlinedButton.styleFrom(
                                          side: const BorderSide(
                                            color: secondaryColor,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (_isFetchingLocation) ...[
                                const SizedBox(height: 8),
                                SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.8,
                                  child: LinearProgressIndicator(
                                    borderRadius: BorderRadius.circular(10),
                                    color: blueColor,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              SizedBox(
                                width: MediaQuery.of(context).size.width * 0.8,
                                child: TextField(
                                  controller: locationController,
                                  focusNode: _locationFocus,
                                  maxLines: 1,
                                  readOnly: _useCurrentLocation,
                                  textAlignVertical: TextAlignVertical.center,
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
                                    contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 12,
                                    ),
                                    suffixIconConstraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    suffixIcon: IconButton(
                                      padding: EdgeInsets.zero,
                                      icon: const Icon(
                                        Icons.close,
                                        color: primaryColor,
                                      ),
                                      onPressed: () {
                                        locationController.clear();
                                        if (_useCurrentLocation) {
                                          setState(() {
                                            _useCurrentLocation = false;
                                          });
                                        }
                                      },
                                    ),
                                    filled: true,
                                    fillColor: mobileBackgroundColor,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
      ),
    );
  }
}
