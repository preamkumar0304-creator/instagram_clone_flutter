import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';

class ProfileReelsViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> reels;
  final int initialIndex;

  const ProfileReelsViewerScreen({
    super.key,
    required this.reels,
    required this.initialIndex,
  });

  @override
  State<ProfileReelsViewerScreen> createState() =>
      _ProfileReelsViewerScreenState();
}

class _ProfileReelsViewerScreenState extends State<ProfileReelsViewerScreen> {
  late final PageController _pageController;
  int _currentIndex = 0;
  final ValueNotifier<bool> _isScrollSettled = ValueNotifier<bool>(true);

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _isScrollSettled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            NotificationListener<ScrollNotification>(
              onNotification: (notification) {
                // Keep playback locked to one settled page to avoid audio overlap.
                if (notification is ScrollStartNotification) {
                  _isScrollSettled.value = false;
                } else if (notification is ScrollEndNotification) {
                  _isScrollSettled.value = true;
                  final page = _pageController.page;
                  if (page != null) {
                    final nextIndex = page.round();
                    if (nextIndex != _currentIndex &&
                        nextIndex >= 0 &&
                        nextIndex < widget.reels.length) {
                      setState(() {
                        _currentIndex = nextIndex;
                      });
                    }
                  }
                }
                return false;
              },
              child: PageView.builder(
                controller: _pageController,
                scrollDirection: Axis.vertical,
                itemCount: widget.reels.length,
                onPageChanged: (index) {
                  setState(() {
                    _currentIndex = index;
                  });
                },
                itemBuilder: (context, index) {
                  return _ProfileReelPage(
                    data: widget.reels[index],
                    isActive: index == _currentIndex,
                    shouldPrepare: (index - _currentIndex).abs() <= 1,
                    scrollSettledListenable: _isScrollSettled,
                  );
                },
              ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfileReelPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isActive;
  final bool shouldPrepare;
  final ValueNotifier<bool> scrollSettledListenable;

  const _ProfileReelPage({
    required this.data,
    required this.isActive,
    required this.shouldPrepare,
    required this.scrollSettledListenable,
  });

  @override
  State<_ProfileReelPage> createState() => _ProfileReelPageState();
}

class _ProfileReelPageState extends State<_ProfileReelPage> {
  VideoPlayerController? _controller;
  bool _isReady = false;
  bool _hasError = false;
  bool _isLoading = false;
  String _activeUrl = "";
  int _loadVersion = 0;

  String _safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  @override
  void initState() {
    super.initState();
    widget.scrollSettledListenable.addListener(_syncPlaybackState);
    _syncPreparedState();
  }

  @override
  void didUpdateWidget(covariant _ProfileReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data ||
        oldWidget.shouldPrepare != widget.shouldPrepare) {
      _syncPreparedState(force: true);
      return;
    }
    if (oldWidget.isActive != widget.isActive) {
      _syncPlaybackState();
    }
  }

  void _syncPreparedState({bool force = false}) {
    final url = _safeString(widget.data["reelUrl"]);
    if (!widget.shouldPrepare || url.isEmpty) {
      _loadVersion++;
      _disposeController();
      if (_isReady || _hasError) {
        setState(() {
          _isReady = false;
          _hasError = false;
          _isLoading = false;
          _activeUrl = url;
        });
      } else {
        _activeUrl = url;
      }
      return;
    }
    if (!force && _controller != null && _activeUrl == url) {
      _syncPlaybackState();
      return;
    }
    _initController(url);
  }

  Future<void> _initController(String url) async {
    final currentVersion = ++_loadVersion;
    _disposeController();
    if (mounted) {
      setState(() {
        _isReady = false;
        _hasError = false;
        _isLoading = true;
      });
    } else {
      _isReady = false;
      _hasError = false;
      _isLoading = true;
    }
    _activeUrl = url;
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      await controller.initialize();
      if (!mounted || currentVersion != _loadVersion) {
        await controller.dispose();
        return;
      }
      _controller = controller;
      await controller.setLooping(true);
      setState(() {
        _isReady = true;
        _isLoading = false;
      });
      _syncPlaybackState();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
        _isLoading = false;
      });
    }
  }

  void _syncPlaybackState() {
    final controller = _controller;
    if (controller == null) return;
    if (widget.scrollSettledListenable.value && widget.isActive && _isReady) {
      if (!controller.value.isPlaying) {
        controller.play();
      }
      return;
    }
    if (controller.value.isPlaying) {
      controller.pause();
    }
  }

  void _disposeController() {
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    widget.scrollSettledListenable.removeListener(_syncPlaybackState);
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _safeString(widget.data["title"]);
    final username = _safeString(widget.data["username"]);
    final ownerPhotoUrl = _safeString(widget.data["photoUrl"]);
    final rawCoverUrl = _safeString(widget.data["coverUrl"]);
    final thumbnailUrl = _safeString(widget.data["thumbnailUrl"]);
    final coverUrl =
        rawCoverUrl.isNotEmpty && rawCoverUrl != ownerPhotoUrl
            ? rawCoverUrl
            : "";
    final fallbackImage =
        thumbnailUrl.isNotEmpty
            ? thumbnailUrl
            : (coverUrl.isNotEmpty ? coverUrl : "");

    return Stack(
      children: [
        Positioned.fill(
          child:
              _isReady && _controller != null
                  ? FittedBox(
                    fit: BoxFit.cover,
                    clipBehavior: Clip.hardEdge,
                    child: SizedBox(
                      width: _controller!.value.size.width,
                      height: _controller!.value.size.height,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                  : Container(
                    color: Colors.black,
                    alignment: Alignment.center,
                    child:
                        _hasError
                            ? const Icon(
                              Icons.broken_image_outlined,
                              color: Colors.white,
                              size: 48,
                            )
                            : fallbackImage.isNotEmpty
                            ? CachedNetworkImage(
                              imageUrl: fallbackImage,
                              fit: BoxFit.cover,
                              placeholder:
                                  (_, __) => const CircularProgressIndicator(
                                    color: Colors.white,
                                  ),
                              errorWidget:
                                  (_, __, ___) => const Icon(
                                    Icons.broken_image_outlined,
                                    color: Colors.white,
                                    size: 48,
                                  ),
                            )
                            : const CircularProgressIndicator(
                              color: Colors.white,
                            ),
                  ),
        ),
        if (_isLoading)
          const Positioned.fill(
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          ),
        Positioned(
          left: 16,
          right: 16,
          bottom: 24,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (username.isNotEmpty)
                Text(
                  "@$username",
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
              if (title.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    title,
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
