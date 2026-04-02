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

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
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
                );
              },
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

  const _ProfileReelPage({required this.data, required this.isActive});

  @override
  State<_ProfileReelPage> createState() => _ProfileReelPageState();
}

class _ProfileReelPageState extends State<_ProfileReelPage> {
  VideoPlayerController? _controller;
  bool _isReady = false;
  bool _hasError = false;
  String _activeUrl = "";

  String _safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  @override
  void initState() {
    super.initState();
    _initController();
  }

  @override
  void didUpdateWidget(covariant _ProfileReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final url = _safeString(widget.data["reelUrl"]);
    if (url != _activeUrl) {
      _disposeController();
      _isReady = false;
      _hasError = false;
      _initController();
      return;
    }
    if (widget.isActive) {
      _controller?.play();
    } else {
      _controller?.pause();
    }
  }

  Future<void> _initController() async {
    final url = _safeString(widget.data["reelUrl"]);
    if (url.isEmpty) return;
    _activeUrl = url;
    try {
      final controller = VideoPlayerController.networkUrl(Uri.parse(url));
      _controller = controller;
      await controller.initialize();
      await controller.setLooping(true);
      if (!mounted) return;
      setState(() {
        _isReady = true;
      });
      if (widget.isActive) {
        await controller.play();
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
      });
    }
  }

  void _disposeController() {
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
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
                                  errorWidget: (_, __, ___) => const Icon(
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
