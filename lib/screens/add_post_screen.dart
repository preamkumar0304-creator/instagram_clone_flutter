import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/methods/storage_methods.dart';
import 'package:instagram_clone_flutter_firebase/models/story_media_item.dart';
import 'package:instagram_clone_flutter_firebase/models/users.dart';
import 'package:instagram_clone_flutter_firebase/providers/user_provider.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/responsive/mobile_screen_layout.dart';
import 'package:instagram_clone_flutter_firebase/responsive/responsive_layout_screen.dart';
import 'package:instagram_clone_flutter_firebase/responsive/web_screen_layout.dart';
import 'package:instagram_clone_flutter_firebase/screens/story_compose_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/live_broadcast_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:instagram_clone_flutter_firebase/widgets/text.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:photo_manager/photo_manager.dart';
import 'package:photo_manager_image_provider/photo_manager_image_provider.dart';
import 'package:video_player/video_player.dart';
import 'package:instagram_clone_flutter_firebase/services/reel_service.dart';

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
  static const Color _brandGreen = Color(0xFF009333);
  static const Color _surfaceFill = Color(0xFFF6F7F8);
  static const Color _borderLight = Color(0xFFE2E4E8);

  final TextEditingController captionController = TextEditingController();
  final TextEditingController locationController = TextEditingController();
  final FocusNode _locationFocus = FocusNode();
  Uint8List? _file;
  File? _reelFile;
  VideoPlayerController? _reelController;
  bool _isReelReady = false;
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
  final AudioPlayer _postAudioPlayer = AudioPlayer();
  StreamSubscription<Duration>? _postAudioPositionSub;
  String? _postAudioPath;
  String? _postAudioName;
  double _postAudioDuration = 0;
  double _postAudioStart = 0;
  double _postAudioEnd = 0;
  bool _isPostAudioReady = false;
  bool _isPostAudioPlaying = false;
  static const double _maxPostAudioClipSeconds = 20;

  Widget _buildCardButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return Material(
      color: Colors.white,
      elevation: 1.2,
      shadowColor: Colors.black.withOpacity(0.08),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: _brandGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: const TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSoftActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onPressed,
  }) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: primaryColor, size: 18),
      label: Text(
        label,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: const TextStyle(
          color: primaryColor,
          fontWeight: FontWeight.w500,
        ),
      ),
      style: ElevatedButton.styleFrom(
        elevation: 0,
        backgroundColor: _surfaceFill,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: _borderLight),
        ),
      ),
    );
  }

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
        _reelFile != null ||
        captionController.text.trim().isNotEmpty ||
        locationController.text.trim().isNotEmpty ||
        _postAudioPath != null;
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
      _clearPostAudio();
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

  Future<bool> _pickPostAudio() async {
    if (_isLoading) return false;
    final result = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (result == null || result.files.isEmpty) return false;
    final picked = result.files.first;
    final path = picked.path ?? "";
    if (path.isEmpty) {
      showSnackBar(
        context: context,
        content: "Selected audio is missing.",
        clr: errorColor,
      );
      return false;
    }
    final file = File(path);
    if (!file.existsSync()) {
      showSnackBar(
        context: context,
        content: "Audio file not found.",
        clr: errorColor,
      );
      return false;
    }
    return _loadPostAudio(path, picked.name);
  }

  Future<bool> _loadPostAudio(String path, String name) async {
    try {
      final duration = await _postAudioPlayer.setFilePath(path);
      if (!mounted) return false;
      final totalSeconds =
          (duration?.inMilliseconds ?? 0) / 1000.0;
      if (totalSeconds <= 0) {
        showSnackBar(
          context: context,
          content: "Unable to read audio duration.",
          clr: errorColor,
        );
        return false;
      }
      final end = totalSeconds < _maxPostAudioClipSeconds
          ? totalSeconds
          : _maxPostAudioClipSeconds;
      setState(() {
        _postAudioPath = path;
        _postAudioName = name;
        _postAudioDuration = totalSeconds;
        _postAudioStart = 0;
        _postAudioEnd = end;
        _isPostAudioReady = true;
        _isPostAudioPlaying = false;
      });
      return true;
    } catch (_) {
      if (!mounted) return false;
      showSnackBar(
        context: context,
        content: "Unable to load audio.",
        clr: errorColor,
      );
      return false;
    }
  }

  void _clearPostAudio() {
    _postAudioPlayer.stop();
    _postAudioPath = null;
    _postAudioName = null;
    _postAudioDuration = 0;
    _postAudioStart = 0;
    _postAudioEnd = 0;
    _isPostAudioReady = false;
    _isPostAudioPlaying = false;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _setReelFile(File file) async {
    if (!await file.exists()) {
      showSnackBar(
        context: context,
        content: "Video file not found.",
        clr: errorColor,
      );
      return;
    }
    _reelController?.pause();
    _reelController?.dispose();
    _reelController = VideoPlayerController.file(file);
    _reelFile = file;
    _isReelReady = false;
    try {
      await _reelController!.initialize();
      await _reelController!.setLooping(true);
      await _reelController!.play();
      if (!mounted) return;
      setState(() {
        _isReelReady = true;
      });
    } catch (_) {
      if (!mounted) return;
      showSnackBar(
        context: context,
        content: "Unable to load video preview.",
        clr: errorColor,
      );
      setState(() {
        _isReelReady = false;
      });
    }
  }

  Future<void> _pickReelFromGallery() async {
    final granted = await ensureGalleryPermission(forVideo: true);
    if (!granted) {
      showSnackBar(
        context: context,
        content: "Gallery permission is required to pick videos.",
        clr: errorColor,
      );
      return;
    }
    final picker = ImagePicker();
    final video = await picker.pickVideo(source: ImageSource.gallery);
    if (video == null) return;
    await _setReelFile(File(video.path));
  }

  Future<void> _postReel(UserModel user) async {
    if (_reelFile == null) {
      showSnackBar(
        context: context,
        content: "Please select a video first.",
        clr: errorColor,
      );
      return;
    }
    setState(() {
      _isLoading = true;
    });
    String message = "";
    try {
      message = await ReelService().uploadReel(
        videoFile: _reelFile!,
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
      _reelController?.pause();
      _reelController?.dispose();
      _reelController = null;
      _reelFile = null;
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

  void _applyPostTrim(double start, double end, {required bool notify}) {
    final total = _postAudioDuration;
    if (total <= 0) return;
    final window =
        total <= _maxPostAudioClipSeconds ? total : _maxPostAudioClipSeconds;
    var nextStart = start;
    var nextEnd = end;
    if (total <= _maxPostAudioClipSeconds) {
      nextStart = 0;
      nextEnd = total;
    } else {
      final startDelta = (start - _postAudioStart).abs();
      final endDelta = (end - _postAudioEnd).abs();
      if (startDelta >= endDelta) {
        nextStart = start;
        nextEnd = nextStart + window;
      } else {
        nextEnd = end;
        nextStart = nextEnd - window;
      }
      if (nextStart < 0) {
        nextStart = 0;
        nextEnd = window;
      } else if (nextEnd > total) {
        nextEnd = total;
        nextStart = total - window;
      }
    }
    nextStart = nextStart.clamp(0, total);
    nextEnd = nextEnd.clamp(0, total);
    _postAudioPlayer.pause();
    _postAudioPlayer.seek(
      Duration(milliseconds: (nextStart * 1000).round()),
    );
    if (notify) {
      setState(() {
        _postAudioStart = nextStart;
        _postAudioEnd = nextEnd;
        _isPostAudioPlaying = false;
      });
    } else {
      _postAudioStart = nextStart;
      _postAudioEnd = nextEnd;
      _isPostAudioPlaying = false;
    }
  }

  Future<void> _togglePostAudioPlayback() async {
    if (!_isPostAudioReady || _postAudioPath == null) return;
    final file = File(_postAudioPath!);
    if (!file.existsSync()) {
      showSnackBar(
        context: context,
        content: "Audio file not found.",
        clr: errorColor,
      );
      _clearPostAudio();
      return;
    }
    if (_isPostAudioPlaying) {
      await _postAudioPlayer.pause();
      if (!mounted) return;
      setState(() {
        _isPostAudioPlaying = _postAudioPlayer.playing;
      });
      return;
    }
    await _postAudioPlayer.seek(
      Duration(milliseconds: (_postAudioStart * 1000).round()),
    );
    await _postAudioPlayer.play();
    if (!mounted) return;
    setState(() {
      _isPostAudioPlaying = _postAudioPlayer.playing;
    });
  }

  Future<void> _openPostAudioSheet({bool forcePick = false}) async {
    if (_isLoading) return;
    if (forcePick || !_isPostAudioReady || _postAudioPath == null) {
      final picked = await _pickPostAudio();
      if (!picked) return;
    }
    if (!mounted) return;
    await _postAudioPlayer.pause();
    if (mounted) {
      setState(() {
        _isPostAudioPlaying = false;
      });
    }
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: mobileBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: StatefulBuilder(
            builder: (context, sheetSetState) {
              final hasAudio = _postAudioPath != null && _isPostAudioReady;
              final total =
                  _postAudioDuration > 0 ? _postAudioDuration : 1.0;
              final start = _postAudioStart.clamp(0, total).toDouble();
              final end = _postAudioEnd.clamp(0, total).toDouble();

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!hasAudio)
                      TextButton.icon(
                        style: TextButton.styleFrom(
                          backgroundColor: Colors.black.withOpacity(0.6),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 10,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: const BorderSide(color: Colors.white24),
                          ),
                        ),
                        onPressed: () async {
                          final picked = await _pickPostAudio();
                          if (!picked) return;
                          sheetSetState(() {});
                        },
                        icon: const Icon(Icons.music_note, size: 18),
                        label: const Text("Add Music"),
                      ),
                    if (hasAudio) ...[
                      const SizedBox(height: 8),
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: const Icon(Icons.audiotrack, color: Colors.black54),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _postAudioName ?? "Local audio",
                        style: const TextStyle(
                          color: primaryColor,
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              shape: BoxShape.circle,
                            ),
                            child: const Text(
                              "20",
                              style: TextStyle(
                                color: Colors.black87,
                                fontSize: 11,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      _formatSeconds(start),
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 11,
                                      ),
                                    ),
                                    Text(
                                      _formatSeconds(end),
                                      style: const TextStyle(
                                        color: Colors.black54,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Stack(
                                  alignment: Alignment.center,
                                  children: [
                                    _WaveformTrimView(
                                      durationSeconds: total,
                                      startSeconds: start,
                                      endSeconds: end,
                                    ),
                                    Positioned.fill(
                                      child: RangeSlider(
                                        values: RangeValues(start, end),
                                        max: total,
                                        min: 0,
                                        divisions:
                                            total >= 1 ? total.round() : null,
                                        labels: RangeLabels(
                                          _formatSeconds(start),
                                          _formatSeconds(end),
                                        ),
                                        onChanged: (values) {
                                          _applyPostTrim(
                                            values.start,
                                            values.end,
                                            notify: false,
                                          );
                                          sheetSetState(() {});
                                        },
                                        activeColor: Colors.transparent,
                                        inactiveColor: Colors.transparent,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          StreamBuilder<PlayerState>(
                            stream: _postAudioPlayer.playerStateStream,
                            builder: (context, snapshot) {
                              final playing =
                                  snapshot.data?.playing ?? _isPostAudioPlaying;
                              return GestureDetector(
                                onTap: () async {
                                  await _togglePostAudioPlayback();
                                  sheetSetState(() {});
                                },
                                child: CircleAvatar(
                                  radius: 18,
                                  backgroundColor: Colors.black87,
                                  child: Icon(
                                    playing ? Icons.pause : Icons.play_arrow,
                                    color: Colors.white,
                                  ),
                                ),
                              );
                            },
                          ),
                        ],
                      ),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          onPressed: () async {
                            final picked = await _pickPostAudio();
                            if (!picked) return;
                            sheetSetState(() {});
                          },
                          child: const Text(
                            "Change Music",
                            style: TextStyle(color: blueColor),
                          ),
                        ),
                      ),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text(
                            "Add",
                            style: TextStyle(color: blueColor),
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<String> _uploadPostAudioIfNeeded(String uid) async {
    final path = _postAudioPath;
    if (path == null || path.isEmpty || !_isPostAudioReady) return "";
    final file = File(path);
    if (!file.existsSync()) {
      showSnackBar(
        context: context,
        content: "Audio file not found.",
        clr: errorColor,
      );
      return "";
    }
    try {
      final fileName =
          "post_audio_${uid}_${DateTime.now().millisecondsSinceEpoch}";
      return await StorageMethods().uploadFileToStorage(
        "posts",
        file,
        true,
        fileName: fileName,
        contentType: "audio/mpeg",
      );
    } catch (_) {
      return "";
    }
  }

  String _formatSeconds(double seconds) {
    if (seconds.isNaN || seconds.isInfinite) return "0:00";
    final total = seconds.round();
    final mins = total ~/ 60;
    final secs = total % 60;
    final padded = secs.toString().padLeft(2, "0");
    return "$mins:$padded";
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
                ListTile(
                  leading: const Icon(Icons.wifi_tethering, color: primaryColor),
                  title: const Text("Live"),
                  onTap: () => Navigator.pop(context, "live"),
                ),
              ],
            ),
          ),
    );
    if (!mounted || type == null) return;
    if (type == "live") {
      final user = Provider.of<UserProvider>(context, listen: false).getUser;
      if (user == null) return;
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => LiveBroadcastScreen(user: user)),
      );
      return;
    }
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
      await _setReelFile(File(video.path));
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
    final granted = await ensureGalleryPermission(
      forVideo: _createType == "reel" || _createType == "story",
    );
    if (!granted) {
      if (mounted) {
        showSnackBar(
          context: context,
          content: "Gallery permission is required to pick media.",
          clr: errorColor,
        );
      }
      return;
    }
    final picker = ImagePicker();
    if (_createType == "reel") {
      final video = await picker.pickVideo(source: ImageSource.gallery);
      if (video == null) return;
      await _setReelFile(File(video.path));
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
      if (file == null) {
        showSnackBar(
          context: context,
          content: "Unable to load video. Try picking from gallery.",
          clr: errorColor,
        );
        await _openSystemGalleryFallback();
        return;
      }
      await _setReelFile(file);
    }
  }

  Future<void> _pickFromSource(ImageSource source) async {
    if (source == ImageSource.gallery) {
      final granted = await ensureGalleryPermission(
        forVideo: _createType == "reel" || _createType == "story",
      );
      if (!granted) {
        if (mounted) {
          showSnackBar(
            context: context,
            content: "Gallery permission is required to pick media.",
            clr: errorColor,
          );
        }
        return;
      }
    }
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
        final file = File(video.path);
        message = await FirestoreMethods().uploadReel(
          videoFile: file,
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
      final audioUrl = await _uploadPostAudioIfNeeded(uid);
      String message = await FirestoreMethods().uploadPost(
        captionController.text.trim(),
        _file!,
        uid,
        username,
        profileUrl,
        locationController.text.trim(),
        audioUrl: audioUrl.isNotEmpty ? audioUrl : null,
        audioName: audioUrl.isNotEmpty ? _postAudioName : null,
        audioStart: audioUrl.isNotEmpty ? _postAudioStart : null,
        audioEnd: audioUrl.isNotEmpty ? _postAudioEnd : null,
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
        _clearPostAudio();
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
    _postAudioPositionSub = _postAudioPlayer.positionStream.listen((position) {
      if (!_isPostAudioReady) return;
      final seconds = position.inMilliseconds / 1000.0;
      if (_postAudioEnd > 0 && seconds >= _postAudioEnd - 0.05) {
        _postAudioPlayer.pause();
        _postAudioPlayer.seek(
          Duration(milliseconds: (_postAudioStart * 1000).round()),
        );
        if (mounted) {
          setState(() {
            _isPostAudioPlaying = false;
          });
        }
      }
    });
  }
  }

  @override
  void dispose() {
    super.dispose();
    captionController.dispose();
    locationController.dispose();
    _locationFocus.dispose();
    _gridController.dispose();
    _postAudioPositionSub?.cancel();
    _postAudioPlayer.dispose();
    _reelController?.dispose();
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

  Future<void> _switchCreateType(String type) async {
    if (_createType == type) return;
    setState(() {
      _createType = type;
    });
    if (_albumOptions.isEmpty) return;
    if (type == "reel") {
      final videoOption =
          _albumOptions.firstWhere(
            (o) => o.label == "Videos",
            orElse: () => _albumOptions.first,
          );
      if (videoOption != _currentAlbum) {
        await _setAlbum(videoOption);
      }
      return;
    }
    if (type == "post") {
      final photoOption = _albumOptions.firstWhere(
        (o) => o.label == "Photos",
        orElse: () => _albumOptions.first,
      );
      if (photoOption != _currentAlbum) {
        await _setAlbum(photoOption);
      }
    }
  }

  Widget _buildCreateTypeSelector(Color activeColor) {
    Widget buildItem(String label, String type) {
      final isActive = _createType == type;
      return GestureDetector(
        onTap: () {
          _switchCreateType(type);
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
    final selectionColor = (isStory || isReel) ? Colors.white : blueColor;

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
                      onTap:
                          isReel
                              ? _openSystemGalleryFallback
                              : _openCameraFromPicker,
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
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      setState(() {
                        _selectedAsset = asset;
                      });
                      if (_isLoading) return;
                      if (_createType == "post" ||
                          _createType == "story" ||
                          _createType == "reel") {
                        _handleNextFromPicker();
                      }
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
                                border: Border.all(
                                  color: selectionColor,
                                  width: 2,
                                ),
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
    final isPickerMode = _file == null && _reelFile == null;
    final isReel = _createType == "reel";
    final hasMedia = isReel ? _reelFile != null : _file != null;
    final canPost = hasMedia && !_isLoading;
    return WillPopScope(
      onWillPop: _confirmDiscard,
      child: GestureDetector(
        onTap: () {
          FocusScope.of(context).unfocus();
        },
        child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: isPickerMode ? Colors.black : mobileBackgroundColor,
        appBar: AppBar(
          backgroundColor: isPickerMode ? Colors.black : mobileBackgroundColor,
          automaticallyImplyLeading: false,
          elevation: 0,
          centerTitle: true,
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
                ? "Add to Story"
                : _createType == "reel"
                    ? "New Reel"
                    : "New Post",
            style: TextStyle(
              color: isPickerMode ? Colors.white : primaryColor,
              fontWeight: FontWeight.w700,
              fontSize: 18,
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
                            ? (isPickerMode ? Colors.white38 : Colors.black38)
                            : (isPickerMode ? Colors.white : _brandGreen),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.only(right: 12),
                child: ElevatedButton(
                  onPressed:
                      canPost
                          ? () {
                            if (user == null) return;
                            if (_createType == "reel") {
                              _postReel(user);
                            } else {
                              postImage(user.uid, user.username, user.photoUrl);
                            }
                          }
                          : null,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _brandGreen,
                    disabledBackgroundColor: _brandGreen.withOpacity(0.45),
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 10,
                    ),
                    shape: const StadiumBorder(),
                  ),
                  child:
                      _isLoading
                          ? Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              SizedBox(
                                width: 14,
                                height: 14,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              ),
                              SizedBox(width: 8),
                              Text(
                                "Posting",
                                style: TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          )
                          : const Text(
                            "Post",
                            style: TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ),
          ],
        ),
        body:
            isPickerMode
                ? SafeArea(
                  child: _buildPicker(),
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
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              if (_isLoading)
                                SizedBox(
                                  width:
                                      MediaQuery.of(context).size.width * 0.92,
                                  child: LinearProgressIndicator(
                                    borderRadius: BorderRadius.circular(10),
                                    color: _brandGreen,
                                  ),
                                ),
                              Padding(
                                padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
                                child: AnimatedScale(
                                  duration: const Duration(milliseconds: 200),
                                  curve: Curves.easeOut,
                                  scale: hasMedia ? 1.0 : 0.98,
                                  child: AnimatedOpacity(
                                    duration: const Duration(milliseconds: 200),
                                    opacity: hasMedia ? 1.0 : 0.9,
                                    child: InkWell(
                                      onTap:
                                          _createType == "reel"
                                              ? _pickReelFromGallery
                                              : _changePostImage,
                                      child: AspectRatio(
                                        aspectRatio:
                                            (_createType == "reel" ||
                                                    _createType == "story")
                                                ? 9 / 16
                                                : 1,
                                        child: Container(
                                          decoration: BoxDecoration(
                                            color:
                                                (_createType == "reel" ||
                                                        _createType == "story")
                                                    ? Colors.black
                                                    : Colors.white,
                                            borderRadius: BorderRadius.circular(20),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(0.08),
                                                blurRadius: 16,
                                                offset: const Offset(0, 8),
                                              ),
                                            ],
                                          ),
                                          child: ClipRRect(
                                            borderRadius: BorderRadius.circular(20),
                                            child: Stack(
                                              children: [
                                                Positioned.fill(
                                                  child:
                                                      _createType == "reel"
                                                          ? (_reelFile == null
                                                              ? Container(
                                                                color: Colors.black12,
                                                                child: const Center(
                                                                  child: Icon(
                                                                    Icons.play_circle_fill,
                                                                    color: Colors.white54,
                                                                    size: 56,
                                                                  ),
                                                                ),
                                                              )
                                                              : (_isReelReady &&
                                                                      _reelController !=
                                                                          null)
                                                                  ? FittedBox(
                                                                    fit: BoxFit.cover,
                                                                    child: SizedBox(
                                                                      width:
                                                                          _reelController!
                                                                              .value
                                                                              .size
                                                                              .width,
                                                                      height:
                                                                          _reelController!
                                                                              .value
                                                                              .size
                                                                              .height,
                                                                      child: VideoPlayer(
                                                                        _reelController!,
                                                                      ),
                                                                    ),
                                                                  )
                                                                  : const Center(
                                                                    child:
                                                                        CircularProgressIndicator(
                                                                      color: Colors.white,
                                                                    ),
                                                                  ))
                                                          : (_file == null
                                                              ? Container(
                                                                color: _surfaceFill,
                                                                child: const Center(
                                                                  child: Icon(
                                                                    Icons.image_outlined,
                                                                    color: secondaryColor,
                                                                    size: 48,
                                                                  ),
                                                                ),
                                                              )
                                                              : InteractiveViewer(
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
                                                              )),
                                                ),
                                                Positioned(
                                                  top: 12,
                                                  right: 12,
                                                  child: Material(
                                                    color: Colors.white.withOpacity(0.9),
                                                    shape: const CircleBorder(),
                                                    child: InkWell(
                                                      customBorder:
                                                          const CircleBorder(),
                                                      onTap:
                                                          _createType == "reel"
                                                              ? _pickReelFromGallery
                                                              : _changePostImage,
                                                      child: const Padding(
                                                        padding: EdgeInsets.all(8),
                                                        child: Icon(
                                                          Icons.edit_outlined,
                                                          color: primaryColor,
                                                          size: 18,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                if (_createType == "reel" &&
                                                    _reelFile != null)
                                                  Center(
                                                    child: GestureDetector(
                                                      onTap: () {
                                                        final controller =
                                                            _reelController;
                                                        if (controller == null) return;
                                                        if (controller.value.isPlaying) {
                                                          controller.pause();
                                                        } else {
                                                          controller.play();
                                                        }
                                                        setState(() {});
                                                      },
                                                      child: Container(
                                                        width: 56,
                                                        height: 56,
                                                        decoration: BoxDecoration(
                                                          color: Colors.black.withOpacity(0.35),
                                                          shape: BoxShape.circle,
                                                        ),
                                                        child: Icon(
                                                          _reelController?.value
                                                                      .isPlaying ==
                                                                  true
                                                              ? Icons.pause
                                                              : Icons.play_arrow,
                                                          color: Colors.white,
                                                          size: 32,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                              ],
                                            ),
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
                                  minLines: 2,
                                  maxLines: 6,
                                  keyboardType: TextInputType.multiline,
                                  textAlign: TextAlign.start,
                                  textAlignVertical: TextAlignVertical.top,
                                  style: const TextStyle(color: primaryColor),
                                  decoration: InputDecoration(
                                    hintText: "Write a caption...",
                                    hintStyle: const TextStyle(
                                      color: secondaryColor,
                                      fontSize: 14,
                                    ),
                                    prefixIcon: const Icon(
                                      Icons.emoji_emotions_outlined,
                                      color: secondaryColor,
                                    ),
                                    contentPadding: const EdgeInsets.fromLTRB(
                                      12,
                                      14,
                                      40,
                                      14,
                                    ),
                                    suffixIconConstraints: const BoxConstraints(
                                      minWidth: 40,
                                      minHeight: 40,
                                    ),
                                    suffixIcon: Align(
                                      alignment: Alignment.topRight,
                                      child: IconButton(
                                        padding: EdgeInsets.zero,
                                        icon: const Icon(
                                          Icons.close,
                                          color: primaryColor,
                                        ),
                                        onPressed:
                                            () => captionController.clear(),
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: _surfaceFill,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: _borderLight,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: _borderLight,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: _brandGreen,
                                        width: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child:
                                    _postAudioPath == null
                                        ? _buildCardButton(
                                          icon: Icons.music_note,
                                          label: "Add Music",
                                          onTap: _openPostAudioSheet,
                                        )
                                        : Material(
                                          color: Colors.white,
                                          elevation: 1.2,
                                          shadowColor: Colors.black.withOpacity(0.08),
                                          borderRadius: BorderRadius.circular(16),
                                          child: Padding(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 12,
                                              vertical: 10,
                                            ),
                                            child: Row(
                                              children: [
                                                Container(
                                                  width: 32,
                                                  height: 32,
                                                  decoration: BoxDecoration(
                                                    color: _surfaceFill,
                                                    borderRadius:
                                                        BorderRadius.circular(10),
                                                  ),
                                                  child: const Icon(
                                                    Icons.music_note,
                                                    color: primaryColor,
                                                    size: 18,
                                                  ),
                                                ),
                                                const SizedBox(width: 10),
                                                Expanded(
                                                  child: Text(
                                                    _postAudioName ?? "Selected audio",
                                                    maxLines: 1,
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                    style: const TextStyle(
                                                      color: primaryColor,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                TextButton(
                                                  onPressed: _openPostAudioSheet,
                                                  child: const Text(
                                                    "Edit",
                                                    style: TextStyle(
                                                      color: _brandGreen,
                                                      fontWeight: FontWeight.w600,
                                                    ),
                                                  ),
                                                ),
                                                IconButton(
                                                  onPressed: _clearPostAudio,
                                                  icon: const Icon(
                                                    Icons.close,
                                                    color: primaryColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                              ),
                              const SizedBox(height: 12),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16),
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: _buildSoftActionButton(
                                        icon: Icons.my_location,
                                        label: "Use current",
                                        onPressed: _setCurrentLocation,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: _buildSoftActionButton(
                                        icon: Icons.edit_location_alt_outlined,
                                        label: "Location",
                                        onPressed: _enableManualLocation,
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
                                    color: _brandGreen,
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
                                  style: const TextStyle(color: primaryColor),
                                  decoration: InputDecoration(
                                    hintText: "Add location",
                                    hintStyle: const TextStyle(
                                      color: secondaryColor,
                                      fontSize: 14,
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
                                    fillColor: _surfaceFill,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: _borderLight,
                                      ),
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: BorderSide(
                                        color: _borderLight,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(16),
                                      borderSide: const BorderSide(
                                        color: _brandGreen,
                                        width: 1.5,
                                      ),
                                    ),
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

class _WaveformTrimView extends StatelessWidget {
  final double durationSeconds;
  final double startSeconds;
  final double endSeconds;

  const _WaveformTrimView({
    required this.durationSeconds,
    required this.startSeconds,
    required this.endSeconds,
  });

  List<double> _barHeights(int count) {
    final pattern = <double>[6, 10, 8, 14, 9, 12, 7, 13, 9, 11];
    return List<double>.generate(
      count,
      (index) => pattern[index % pattern.length],
    );
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final safeDuration = durationSeconds <= 0 ? 1.0 : durationSeconds;
        final startX = (startSeconds / safeDuration) * width;
        final endX = (endSeconds / safeDuration) * width;
        final highlightWidth = (endX - startX).clamp(0.0, width);
        final bars = _barHeights(32);

        return SizedBox(
          height: 36,
          child: Stack(
            alignment: Alignment.centerLeft,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: bars
                    .map(
                      (height) => Container(
                        width: 3,
                        height: height,
                        decoration: BoxDecoration(
                          color: Colors.black12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    )
                    .toList(),
              ),
              Positioned(
                left: startX,
                child: Container(
                  width: highlightWidth,
                  height: 30,
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.pinkAccent, width: 2),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
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
