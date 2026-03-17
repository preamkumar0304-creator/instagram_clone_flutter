import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/models/story_media_item.dart';
import 'package:instagram_clone_flutter_firebase/models/users.dart';
import 'package:instagram_clone_flutter_firebase/providers/user_provider.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/responsive/mobile_screen_layout.dart';
import 'package:instagram_clone_flutter_firebase/responsive/responsive_layout_screen.dart';
import 'package:instagram_clone_flutter_firebase/responsive/web_screen_layout.dart';
import 'package:instagram_clone_flutter_firebase/screens/story_compose_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:instagram_clone_flutter_firebase/widgets/text.dart';
import 'package:instagram_clone_flutter_firebase/widgets/text_button.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';

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
  bool _isDiscarding = false;
  bool _hasGalleryPermission = true;
  bool _isLoadingAssets = true;
  List<_AlbumOption> _albumOptions = [];
  _AlbumOption? _currentAlbum;
  List<AssetEntity> _assets = [];
  AssetEntity? _selectedAsset;
  final ScrollController _gridController = ScrollController();
  int _assetPage = 0;
  static const int _pageSize = 200;
  bool _hasMoreAssets = true;
  bool _isLoadingMoreAssets = false;

  void _goHome() {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder:
            (_) => const ResponsiveLayout(
              webScreenLayout: WebScreenLayout(),
              mobileScreenLayout: MobileScreenLayout(),
            ),
      ),
      (route) => false,
    );
  }

  Future<bool> _confirmDiscard() async {
    if (_isLoading || _isDiscarding) return false;
    final hasChanges =
        _file != null ||
        captionController.text.trim().isNotEmpty ||
        locationController.text.trim().isNotEmpty;
    if (!hasChanges) {
      _goHome();
      return false;
    }
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: mobileBackgroundColor,
          title: const Text(
            "Discard post?",
            style: TextStyle(color: primaryColor),
          ),
          content: const Text(
            "If you go back now, your changes will be discarded.",
            style: TextStyle(color: secondaryColor),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text("Continue", style: TextStyle(color: primaryColor)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text("Discard", style: TextStyle(color: errorColor)),
            ),
          ],
        );
      },
    );
    if (result == true) {
      setState(() {
        _isDiscarding = true;
        _file = null;
        _useCurrentLocation = false;
      });
      captionController.clear();
      locationController.clear();
      await Future.delayed(const Duration(milliseconds: 150));
      if (mounted) {
        setState(() {
          _isDiscarding = false;
        });
      }
    }
    return false;
  }

  Future<void> _changePostImage() async {
    if (_isLoading) return;
    _createType = "post";
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

  Future<void> _initGallery() async {
    final permission = await PhotoManager.requestPermissionExtend();
    final isGranted = permission.isAuth || permission.isLimited;
    if (!isGranted) {
      if (mounted) {
        setState(() {
          _hasGalleryPermission = false;
          _isLoadingAssets = false;
        });
      }
      return;
    }
    if (mounted) {
      setState(() {
        _hasGalleryPermission = true;
      });
    }

    final orderOption =
        FilterOptionGroup(orders: [
          const OrderOption(type: OrderOptionType.createDate, asc: false),
        ]);
    final allAlbums =
        await PhotoManager.getAssetPathList(
          type: RequestType.all,
          hasAll: true,
          filterOption: orderOption,
        );
    final imageAlbums =
        await PhotoManager.getAssetPathList(
          type: RequestType.image,
          hasAll: true,
          filterOption: orderOption,
        );
    final videoAlbums =
        await PhotoManager.getAssetPathList(
          type: RequestType.video,
          hasAll: true,
          filterOption: orderOption,
        );

    final options = <_AlbumOption>[];
    if (allAlbums.isNotEmpty) {
      options.add(_AlbumOption(label: "Recents", album: allAlbums.first));
    }
    if (imageAlbums.isNotEmpty) {
      options.add(_AlbumOption(label: "Photos", album: imageAlbums.first));
    }
    if (videoAlbums.isNotEmpty) {
      options.add(_AlbumOption(label: "Videos", album: videoAlbums.first));
    }
    if (allAlbums.length > 1) {
      for (final album in allAlbums.skip(1)) {
        options.add(_AlbumOption(label: album.name, album: album));
      }
    }

    if (!mounted) return;
    setState(() {
      _albumOptions = options;
    });

    if (options.isNotEmpty) {
      _AlbumOption selected = options.first;
      if (_createType == "reel") {
        final videoOption = options.where((o) => o.label == "Videos").toList();
        if (videoOption.isNotEmpty) {
          selected = videoOption.first;
        }
      }
      await _setAlbum(selected);
    } else {
      setState(() {
        _isLoadingAssets = false;
      });
    }
  }

  Future<void> _setAlbum(_AlbumOption option) async {
    setState(() {
      _currentAlbum = option;
      _isLoadingAssets = true;
      _assets = [];
      _selectedAsset = null;
      _assetPage = 0;
      _hasMoreAssets = true;
    });
    await _loadMoreAssets();
  }

  Future<void> _loadMoreAssets() async {
    if (_currentAlbum == null) return;
    if (_isLoadingMoreAssets || !_hasMoreAssets) return;
    setState(() {
      _isLoadingMoreAssets = true;
    });
    final assets =
        await _currentAlbum!.album.getAssetListPaged(
          page: _assetPage,
          size: _pageSize,
        );
    if (!mounted) return;
    setState(() {
      _assets.addAll(assets);
      if (_selectedAsset == null || !_matchesCreateType(_selectedAsset!)) {
        final matches = _assets.where(_matchesCreateType).toList();
        _selectedAsset = matches.isNotEmpty ? matches.first : null;
      }
      _isLoadingAssets = false;
      _isLoadingMoreAssets = false;
      _assetPage += 1;
      if (assets.length < _pageSize) {
        _hasMoreAssets = false;
      }
    });
  }

  bool _matchesCreateType(AssetEntity asset) {
    if (_createType == "reel") {
      return asset.type == AssetType.video;
    }
    if (_createType == "post") {
      return asset.type == AssetType.image;
    }
    return true;
  }

  Future<void> _openAlbumPicker() async {
    if (_albumOptions.isEmpty) return;
    final selected = await showModalBottomSheet<_AlbumOption>(
      context: context,
      backgroundColor: mobileBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder:
          (context) => SafeArea(
            child: ListView.separated(
              shrinkWrap: true,
              itemCount: _albumOptions.length,
              separatorBuilder: (_, __) =>
                  const Divider(color: secondaryColor, height: 1),
              itemBuilder: (context, index) {
                final option = _albumOptions[index];
                return ListTile(
                  title: Text(
                    option.label,
                    style: const TextStyle(color: primaryColor),
                  ),
                  trailing:
                      option.label == _currentAlbum?.label
                          ? const Icon(Icons.check, color: blueColor)
                          : null,
                  onTap: () => Navigator.pop(context, option),
                );
              },
            ),
          ),
    );
    if (selected != null) {
      await _setAlbum(selected);
    }
  }

  Future<void> _openCameraFromPicker() async {
    if (_isLoading) return;
    if (_createType == "reel") {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: ImageSource.camera);
      if (video == null) return;
      final user = Provider.of<UserProvider>(context, listen: false).getUser;
      if (user == null) return;
      setState(() {
        _isLoading = true;
      });
      String message = "";
      try {
        final bytes = await video.readAsBytes();
        message = await FirestoreMethods().uploadReel(
          videoBytes: bytes,
          uid: user.uid,
          username: user.username,
          profileUrl: user.photoUrl,
        );
      } catch (err) {
        message = err.toString();
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      if (!mounted) return;
      if (message.toLowerCase().contains("added")) {
        showSnackBar(
          context: context,
          content: "Reel added.",
          clr: successColor,
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ProfileScreen(uid: user.uid)),
        );
      } else {
        showSnackBar(
          context: context,
          content: message.isEmpty ? "Unable to upload reel." : message,
          clr: errorColor,
        );
      }
      return;
    }

    final bytes = await pickImage(ImageSource.camera);
    if (bytes == null || (bytes as dynamic).isEmpty) return;

    if (_createType == "story") {
      final user = Provider.of<UserProvider>(context, listen: false).getUser;
      if (user == null) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => StoryComposeScreen(
                items: [StoryMediaItem.image(bytes)],
                user: user,
              ),
        ),
      );
      return;
    }

    setState(() {
      _file = bytes;
    });
  }

  Future<void> _openSystemGalleryFallback() async {
    if (_isLoading) return;
    final picker = ImagePicker();
    if (_createType == "reel") {
      final video = await picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;
      final user = Provider.of<UserProvider>(context, listen: false).getUser;
      if (user == null) return;
      setState(() {
        _isLoading = true;
      });
      String message = "";
      try {
        final bytes = await video.readAsBytes();
        message = await FirestoreMethods().uploadReel(
          videoBytes: bytes,
          uid: user.uid,
          username: user.username,
          profileUrl: user.photoUrl,
        );
      } catch (err) {
        message = err.toString();
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      if (!mounted) return;
      if (message.toLowerCase().contains("added")) {
        showSnackBar(
          context: context,
          content: "Reel added.",
          clr: successColor,
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ProfileScreen(uid: user.uid)),
        );
      } else {
        showSnackBar(
          context: context,
          content: message.isEmpty ? "Unable to upload reel." : message,
          clr: errorColor,
        );
      }
      return;
    }

    if (_createType == "story") {
      final mediaType = await _selectStoryMediaType();
      if (mediaType == null) return;
      if (mediaType == StoryMediaType.video) {
        final video = await picker.pickVideo(
          source: ImageSource.gallery,
          maxDuration: const Duration(seconds: 15),
        );
        if (video == null) return;
        final user = Provider.of<UserProvider>(context, listen: false).getUser;
        if (user == null) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => StoryComposeScreen(
                  items: [StoryMediaItem.video(video.path)],
                  user: user,
                ),
          ),
        );
        return;
      }
      final image = await picker.pickImage(source: ImageSource.gallery);
      if (image == null) return;
      final bytes = await image.readAsBytes();
      final user = Provider.of<UserProvider>(context, listen: false).getUser;
      if (user == null || bytes.isEmpty) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => StoryComposeScreen(
                items: [StoryMediaItem.image(bytes)],
                user: user,
              ),
        ),
      );
      return;
    }

    final image = await picker.pickImage(source: ImageSource.gallery);
    if (image == null) return;
    final bytes = await image.readAsBytes();
    if (bytes.isEmpty) return;
    setState(() {
      _file = bytes;
    });
  }

  Future<void> _openSettingsAndReload() async {
    await PhotoManager.openSetting();
    if (!mounted) return;
    await Future.delayed(const Duration(milliseconds: 300));
    await _initGallery();
  }

  Future<void> _handleNextFromPicker() async {
    if (_selectedAsset == null) {
      showSnackBar(
        context: context,
        content: "Please select a file.",
        clr: errorColor,
      );
      return;
    }

    if (_createType == "post") {
      if (_selectedAsset!.type != AssetType.image) {
        showSnackBar(
          context: context,
          content: "Please select a photo for a post.",
          clr: errorColor,
        );
        return;
      }
      final bytes = await _selectedAsset!.originBytes;
      if (bytes == null || bytes.isEmpty) {
        showSnackBar(
          context: context,
          content: "Unable to load image.",
          clr: errorColor,
        );
        return;
      }
      setState(() {
        _file = bytes;
      });
      return;
    }

    if (_createType == "story") {
      final user = Provider.of<UserProvider>(context, listen: false).getUser;
      if (user == null) return;
      if (_selectedAsset!.type == AssetType.video) {
        final file = await _selectedAsset!.file;
        if (file == null) return;
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => StoryComposeScreen(
                  items: [StoryMediaItem.video(file.path)],
                  user: user,
                ),
          ),
        );
        return;
      }
      final bytes = await _selectedAsset!.originBytes;
      if (bytes == null || bytes.isEmpty) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder:
              (_) => StoryComposeScreen(
                items: [StoryMediaItem.image(bytes)],
                user: user,
              ),
        ),
      );
      return;
    }

    if (_createType == "reel") {
      if (_selectedAsset!.type != AssetType.video) {
        showSnackBar(
          context: context,
          content: "Please select a video for a reel.",
          clr: errorColor,
        );
        return;
      }
      final file = await _selectedAsset!.file;
      if (file == null) return;
      final user = Provider.of<UserProvider>(context, listen: false).getUser;
      if (user == null) return;
      setState(() {
        _isLoading = true;
      });
      String message = "";
      try {
        final bytes = await file.readAsBytes();
        message = await FirestoreMethods().uploadReel(
          videoBytes: bytes,
          uid: user.uid,
          username: user.username,
          profileUrl: user.photoUrl,
        );
      } catch (err) {
        message = err.toString();
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      if (!mounted) return;
      if (message.toLowerCase().contains("added")) {
        showSnackBar(
          context: context,
          content: "Reel added.",
          clr: successColor,
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ProfileScreen(uid: user.uid)),
        );
      } else {
        showSnackBar(
          context: context,
          content: message.isEmpty ? "Unable to upload reel." : message,
          clr: errorColor,
        );
      }
    }
  }

  Future<void> _pickFromSource(ImageSource source) async {
    if (_createType == "reel") {
      final picker = ImagePicker();
      final video = await picker.pickVideo(source: source);
      if (video == null) return;
      final user = Provider.of<UserProvider>(context, listen: false).getUser;
      if (user == null) return;
      setState(() {
        _isLoading = true;
      });
      String message = "";
      try {
        final bytes = await video.readAsBytes();
        message = await FirestoreMethods().uploadReel(
          videoBytes: bytes,
          uid: user.uid,
          username: user.username,
          profileUrl: user.photoUrl,
        );
      } catch (err) {
        message = err.toString();
      } finally {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
      if (!mounted) return;
      if (message.toLowerCase().contains("added")) {
        showSnackBar(
          context: context,
          content: "Reel added.",
          clr: successColor,
        );
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => ProfileScreen(uid: user.uid)),
        );
      } else {
        showSnackBar(
          context: context,
          content: message.isEmpty ? "Unable to upload reel." : message,
          clr: errorColor,
        );
      }
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
          final seenPaths = <String>{};
          for (final image in images) {
            final path = image.path;
            if (path.isNotEmpty && !seenPaths.add(path)) {
              continue;
            }
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
        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => ProfileScreen(uid: uid),
          ),
        );
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
    _gridController.addListener(() {
      if (!_gridController.hasClients) return;
      final maxScroll = _gridController.position.maxScrollExtent;
      final current = _gridController.position.pixels;
      if (current >= maxScroll - 400) {
        _loadMoreAssets();
      }
    });
    if (widget.initialFile != null) {
      _file = widget.initialFile;
      _createMenuShown = true;
    } else {
      if (widget.initialCreateType != null) {
        _createType = widget.initialCreateType!;
      }
      if (widget.autoPick && widget.initialCreateType != null) {
        _createMenuShown = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _pickFromSource(widget.initialSource ?? ImageSource.gallery);
        });
      } else {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_createMenuShown) return;
          _createMenuShown = true;
          _initGallery();
        });
      }
    }
  }

  @override
  void dispose() {
    super.dispose();
    captionController.dispose();
    locationController.dispose();
    _locationFocus.dispose();
    _gridController.dispose();
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

  Widget _buildCreateTypeSelector(Color activeColor) {
    Widget buildItem(String label, String type) {
      final isActive = _createType == type;
      return GestureDetector(
        onTap: () {
          setState(() {
            _createType = type;
          });
        },
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Text(
            label,
            style: TextStyle(
              color: isActive ? activeColor : Colors.white54,
              fontSize: 14,
              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
              letterSpacing: 1.2,
            ),
          ),
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.6),
        borderRadius: BorderRadius.circular(30),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          buildItem("POST", "post"),
          buildItem("STORY", "story"),
          buildItem("REEL", "reel"),
        ],
      ),
    );
  }

  Widget _buildPicker() {
    if (!_hasGalleryPermission) {
      return Center(
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _initGallery,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "Allow photos permission to continue.",
                style: TextStyle(color: Colors.white70, fontSize: 14),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: 160,
                height: 44,
                child: ElevatedButton(
                  onPressed: _openSettingsAndReload,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: blueColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: const Text(
                    "Open settings",
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              GestureDetector(
                onTap: _openSystemGalleryFallback,
                child: const Text(
                  "Open gallery",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_isLoadingAssets) {
      return const Center(
        child: CircularProgressIndicator(color: Colors.white),
      );
    }

    final isStory = _createType == "story";
    final isReel = _createType == "reel";

    return Column(
      children: [
        if (isStory)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Row(
              children: const [
                _StoryToolChip(
                  icon: Icons.collections_bookmark,
                  label: "Templates",
                ),
                SizedBox(width: 10),
                _StoryToolChip(icon: Icons.music_note, label: "Music"),
                SizedBox(width: 10),
                _StoryToolChip(icon: Icons.grid_on, label: "Collage"),
                SizedBox(width: 10),
                _StoryToolChip(icon: Icons.auto_awesome, label: "AI Images"),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
          child: Row(
            children: [
              GestureDetector(
                onTap: _openAlbumPicker,
                child: Row(
                  children: [
                    Text(
                      _currentAlbum?.label ?? "Recents",
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 6),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white,
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.white12,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: const [
                    Icon(Icons.check_box_outline_blank, color: Colors.white70, size: 16),
                    SizedBox(width: 6),
                    Text(
                      "Select",
                      style: TextStyle(color: Colors.white70),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Builder(
            builder: (context) {
              final visibleAssets =
                  _assets.where(_matchesCreateType).toList();
              if (_selectedAsset != null &&
                  !_matchesCreateType(_selectedAsset!)) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) return;
                  setState(() {
                    _selectedAsset =
                        visibleAssets.isNotEmpty ? visibleAssets.first : null;
                  });
                });
              }
              return GridView.builder(
                controller: _gridController,
                padding: EdgeInsets.zero,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 1,
                  mainAxisSpacing: 1,
                ),
                itemCount: visibleAssets.length + 1,
                itemBuilder: (context, index) {
                  if (index == 0) {
                    return InkWell(
                      onTap: _openCameraFromPicker,
                      child: Container(
                        color: Colors.white,
                        child: const Center(
                          child: Icon(
                            Icons.photo_camera,
                            color: Colors.black,
                            size: 32,
                          ),
                        ),
                      ),
                    );
                  }
                  final asset = visibleAssets[index - 1];
                  final isSelected = _selectedAsset?.id == asset.id;
                  return GestureDetector(
                    onTap: () {
                      setState(() {
                        _selectedAsset = asset;
                      });
                    },
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: AssetEntityImage(
                            asset,
                            isOriginal: false,
                            fit: BoxFit.cover,
                          ),
                        ),
                        if (asset.type == AssetType.video)
                          Positioned(
                            right: 6,
                            bottom: 6,
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.black54,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(
                                Icons.play_arrow,
                                color: Colors.white,
                                size: 14,
                              ),
                            ),
                          ),
                        if (isSelected)
                          Positioned.fill(
                            child: Container(
                              decoration: BoxDecoration(
                                border: Border.all(color: blueColor, width: 2),
                              ),
                            ),
                          ),
                        if (_isLoadingMoreAssets &&
                            index == visibleAssets.length)
                          const Positioned(
                            right: 6,
                            top: 6,
                            child: SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (!isStory && !isReel)
          Padding(
            padding: const EdgeInsets.only(bottom: 16, top: 10),
            child: _buildCreateTypeSelector(Colors.white),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    UserModel? user = Provider.of<UserProvider>(context, listen: false).getUser;
    final isPickerMode = _file == null;
    return WillPopScope(
      onWillPop: _confirmDiscard,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
        backgroundColor:
            isPickerMode ? Colors.black : mobileBackgroundColor,
        appBar: AppBar(
          backgroundColor:
              isPickerMode ? Colors.black : mobileBackgroundColor,
          automaticallyImplyLeading: false,
          leading: IconButton(
            icon: Icon(
              Icons.close,
              color: isPickerMode ? Colors.white : primaryColor,
            ),
            onPressed: () {
              if (isPickerMode) {
                _goHome();
              } else {
                _confirmDiscard();
              }
            },
          ),
          title: Text(
            _createType == "story"
                ? "Add to story"
                : _createType == "reel"
                    ? "New reel"
                    : "New post",
            style: TextStyle(
              color: isPickerMode ? Colors.white : primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 20,
            ),
          ),
          actions: [
            if (isPickerMode)
              TextButton(
                onPressed:
                    _selectedAsset == null || _isLoading
                        ? null
                        : _handleNextFromPicker,
                child: Text(
                  "Next",
                  style: TextStyle(
                    color:
                        _selectedAsset == null
                            ? Colors.white38
                            : blueColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              MyTextButton(
                buttonText: "Post",
                txtClr: blueColor,
                onPressed: () {
                  postImage(user!.uid, user.username, user.photoUrl);
                },
              ),
          ],
        ),
        body:
            isPickerMode
                ? _buildPicker()
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
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              if (_isLoading)
                                SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.92,
                                  child: LinearProgressIndicator(
                                    borderRadius: BorderRadius.circular(10),
                                    color: blueColor,
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 16,
                                ),
                                child: InkWell(
                                  onTap: _changePostImage,
                                  child: AspectRatio(
                                    aspectRatio: 1,
                                    child: Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border:
                                            Border.all(color: secondaryColor),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: InteractiveViewer(
                                          panEnabled: true,
                                          scaleEnabled: true,
                                          minScale: 1.0,
                                          maxScale: 4.0,
                                          boundaryMargin:
                                              const EdgeInsets.all(80),
                                          child: Image.memory(
                                            _file!,
                                            fit: BoxFit.cover,
                                            width: double.infinity,
                                            height: double.infinity,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
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
                                      MediaQuery.of(context).size.width * 0.92,
                                  child: LinearProgressIndicator(
                                    borderRadius: BorderRadius.circular(10),
                                    color: blueColor,
                                  ),
                                ),
                              ],
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
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
      ),
    );
  }
}

class _AlbumOption {
  final String label;
  final AssetPathEntity album;

  const _AlbumOption({required this.label, required this.album});
}

class _StoryToolChip extends StatelessWidget {
  final IconData icon;
  final String label;

  const _StoryToolChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: Colors.white, size: 22),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white, fontSize: 11),
          ),
        ],
      ),
    );
  }
}
