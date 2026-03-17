import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/widgets/post_card.dart';
import 'package:video_player/video_player.dart';

class SearchMediaViewerScreen extends StatefulWidget {
  final List<Map<String, dynamic>> items;
  final int initialIndex;

  const SearchMediaViewerScreen({
    super.key,
    required this.items,
    required this.initialIndex,
  });

  @override
  State<SearchMediaViewerScreen> createState() =>
      _SearchMediaViewerScreenState();
}

class _SearchMediaViewerScreenState extends State<SearchMediaViewerScreen> {
  late final PageController _pageController;

  @override
  void initState() {
    super.initState();
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
      backgroundColor: mobileBackgroundColor,
      body: SafeArea(
        child: Stack(
          children: [
            PageView.builder(
              controller: _pageController,
              scrollDirection: Axis.vertical,
              itemCount: widget.items.length,
              itemBuilder: (context, index) {
                final item = widget.items[index];
                final type = (item["type"] ?? "").toString();
                final data =
                    item["data"] is Map<String, dynamic>
                        ? item["data"] as Map<String, dynamic>
                        : <String, dynamic>{};

                if (type == "reel") {
                  return _ReelViewerPage(data: data);
                }
                return PostCard(snap: data);
              },
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: primaryColor),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReelViewerPage extends StatefulWidget {
  final Map<String, dynamic> data;

  const _ReelViewerPage({required this.data});

  @override
  State<_ReelViewerPage> createState() => _ReelViewerPageState();
}

class _ReelViewerPageState extends State<_ReelViewerPage> {
  VideoPlayerController? _controller;
  bool _isReady = false;

  String _safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  @override
  void initState() {
    super.initState();
    _initVideo();
  }

  Future<void> _initVideo() async {
    final url = _safeString(widget.data["reelUrl"]);
    if (url.isEmpty) return;
    final controller = VideoPlayerController.network(url);
    _controller = controller;
    try {
      await controller.initialize();
      await controller.setLooping(true);
      await controller.play();
      if (mounted) {
        setState(() {
          _isReady = true;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _isReady = false;
        });
      }
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final username = _safeString(widget.data["username"]);
    final title = _safeString(widget.data["title"]);
    return Container(
      color: Colors.black,
      child: Stack(
        children: [
          Positioned.fill(
            child:
                _controller != null && _isReady
                    ? FittedBox(
                      fit: BoxFit.cover,
                      child: SizedBox(
                        width: _controller!.value.size.width,
                        height: _controller!.value.size.height,
                        child: VideoPlayer(_controller!),
                      ),
                    )
                    : const Center(
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
                    username,
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
      ),
    );
  }
}
