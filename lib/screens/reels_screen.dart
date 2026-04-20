import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/widgets/share_reel_sheet.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:video_player/video_player.dart';
import 'package:visibility_detector/visibility_detector.dart';
import 'package:instagram_clone_flutter_firebase/screens/add_post_screen.dart';
import 'package:instagram_clone_flutter_firebase/screens/profile_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/global_variables.dart';

class ReelsScreen extends StatefulWidget {
  const ReelsScreen({super.key});

  @override
  State<ReelsScreen> createState() => _ReelsScreenState();
}

class _ReelsScreenState extends State<ReelsScreen>
    with AutomaticKeepAliveClientMixin, WidgetsBindingObserver {
  final PageController _pageController = PageController();
  int _currentIndex = 0;
  int _reelsCount = 0;
  static const double _fastSwipeVelocity = 1800;
  final ValueNotifier<bool> _isMuted = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isScreenVisible = ValueNotifier<bool>(true);
  late final VoidCallback _homeTabListener;

  String _safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  bool _handleFastSwipe(ScrollEndNotification notification, int maxIndex) {
    final details = notification.dragDetails;
    if (details == null) return false;
    final velocity = details.primaryVelocity ?? 0;
    if (velocity.abs() < _fastSwipeVelocity) return false;
    final target = velocity < 0 ? _currentIndex + 1 : _currentIndex - 1;
    if (target < 0 || target > maxIndex) return false;
    _pageController.animateToPage(
      target,
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
    );
    return false;
  }

  void _syncActiveIndexDuringScroll() {
    if (!_pageController.hasClients || _reelsCount <= 0) return;
    final rawPage = _pageController.page;
    if (rawPage == null) return;
    final nextIndex = rawPage.round().clamp(0, _reelsCount - 1).toInt();
    if (nextIndex == _currentIndex) return;
    if (!mounted) return;
    setState(() {
      _currentIndex = nextIndex;
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController.addListener(_syncActiveIndexDuringScroll);
    _homeTabListener = () {
      _isScreenVisible.value = homeTabIndexNotifier.value == 2;
    };
    homeTabIndexNotifier.addListener(_homeTabListener);
    _isScreenVisible.value = homeTabIndexNotifier.value == 2;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _isScreenVisible.value = false;
      return;
    }
    if (state == AppLifecycleState.resumed) {
      _isScreenVisible.value = homeTabIndexNotifier.value == 2;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.removeListener(_syncActiveIndexDuringScroll);
    homeTabIndexNotifier.removeListener(_homeTabListener);
    _pageController.dispose();
    _isMuted.dispose();
    _isScreenVisible.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    return Scaffold(
      backgroundColor: Colors.black,
      body: VisibilityDetector(
        key: const Key("reels_visibility"),
        onVisibilityChanged: (info) {
          _isScreenVisible.value = info.visibleFraction > 0.6;
        },
        child: Stack(
          children: [
            NotificationListener<OverscrollIndicatorNotification>(
              onNotification: (overscroll) {
                overscroll.disallowIndicator();
                return false;
              },
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream:
                    FirebaseFirestore.instance
                        .collection("reels")
                        .orderBy("createdAt", descending: true)
                        .snapshots(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(color: primaryColor),
                    );
                  }
                  final docs = snapshot.data?.docs ?? [];
                  _reelsCount = docs.length;
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "No reels yet.",
                        style: TextStyle(color: Colors.white),
                      ),
                    );
                  }
                  final maxIndex = docs.length - 1;
                  return NotificationListener<ScrollEndNotification>(
                    onNotification: (notification) {
                      return _handleFastSwipe(notification, maxIndex);
                    },
                    child: PageView.builder(
                      controller: _pageController,
                      scrollDirection: Axis.vertical,
                      physics: const PageScrollPhysics(),
                      allowImplicitScrolling: false,
                      onPageChanged: (index) {
                        setState(() {
                          _currentIndex = index;
                        });
                      },
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        return _ReelPage(
                          key: ValueKey(docs[index].id),
                          data: docs[index].data(),
                          isActive: index == _currentIndex,
                          mutedListenable: _isMuted,
                          screenVisibleListenable: _isScreenVisible,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const AddPostScreen()),
                        );
                      },
                      icon: const Icon(Icons.add, color: Colors.white, size: 28),
                    ),
                    const Spacer(),
                    Row(
                      children: const [
                        Text(
                          "Reels",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 4),
                        Icon(
                          Icons.keyboard_arrow_down,
                          color: Colors.white,
                        ),
                      ],
                    ),
                    const Spacer(),
                    const SizedBox(width: 40),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  bool get wantKeepAlive => true;
}

class _ReelPage extends StatefulWidget {
  final Map<String, dynamic> data;
  final bool isActive;
  final ValueNotifier<bool> mutedListenable;
  final ValueNotifier<bool> screenVisibleListenable;

  const _ReelPage({
    super.key,
    required this.data,
    required this.isActive,
    required this.mutedListenable,
    required this.screenVisibleListenable,
  });

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  VideoPlayerController? _controller;
  bool _isReady = false;
  bool _hasError = false;
  bool _isPageVisible = false;
  String _activeUrl = "";
  bool _isMuted = false;
  late final VoidCallback _muteListener;
  late final VoidCallback _visibilityListener;

  String _safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  @override
  void initState() {
    super.initState();
    _isPageVisible = widget.isActive;
    _isMuted = widget.mutedListenable.value;
    _muteListener = () {
      if (!mounted) return;
      setState(() {
        _isMuted = widget.mutedListenable.value;
      });
      _applyVolume();
    };
    _visibilityListener = () {
      _syncPlaybackState();
    };
    widget.mutedListenable.addListener(_muteListener);
    widget.screenVisibleListenable.addListener(_visibilityListener);
    _initController();
  }

  @override
  void didUpdateWidget(covariant _ReelPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    final url = _safeString(widget.data["reelUrl"]);
    if (url != _activeUrl) {
      _disposeController();
      _isReady = false;
      _hasError = false;
      _initController();
      return;
    }
    _syncPlaybackState();
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
      await controller.setVolume(_isMuted ? 0.0 : 1.0);
      if (!mounted) return;
      setState(() {
        _isReady = true;
      });
      _syncPlaybackState();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _hasError = true;
      });
    }
  }

  void _applyVolume() {
    final controller = _controller;
    if (controller == null) return;
    controller.setVolume(_isMuted ? 0.0 : 1.0);
  }

  void _syncPlaybackState() {
    final controller = _controller;
    if (controller == null) return;
    final shouldPlay =
        widget.screenVisibleListenable.value &&
        widget.isActive &&
        _isPageVisible &&
        _isReady;
    if (shouldPlay) {
      controller.play();
      return;
    }
    controller.pause();
  }

  void _disposeController() {
    _controller?.pause();
    _controller?.dispose();
    _controller = null;
  }

  @override
  void dispose() {
    widget.mutedListenable.removeListener(_muteListener);
    widget.screenVisibleListenable.removeListener(_visibilityListener);
    _disposeController();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = _safeString(widget.data["title"]);
    final username = _safeString(widget.data["username"]);
    final reelId = _safeString(widget.data["reelId"]);
    final reelUrl = _safeString(widget.data["reelUrl"]);
    final ownerUid = _safeString(widget.data["uid"]);
    final ownerPhotoUrl = _safeString(widget.data["photoUrl"]);
    final thumbnailUrl = _safeString(widget.data["thumbnailUrl"]);
    final rawCoverUrl = _safeString(widget.data["coverUrl"]);
    final coverUrl =
        rawCoverUrl.isNotEmpty && rawCoverUrl != ownerPhotoUrl
            ? rawCoverUrl
            : "";
    final fallbackImage =
        thumbnailUrl.isNotEmpty
            ? thumbnailUrl
            : (coverUrl.isNotEmpty ? coverUrl : "");

    final visibilityKey =
        reelId.isNotEmpty ? "reel-$reelId" : "reel-${reelUrl.hashCode}";
    return VisibilityDetector(
      key: ValueKey(visibilityKey),
      onVisibilityChanged: (info) {
        final nowVisible = info.visibleFraction > 0.8;
        if (_isPageVisible == nowVisible) return;
        _isPageVisible = nowVisible;
        _syncPlaybackState();
      },
      child: Stack(
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
            right: 90,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (ownerUid.isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ProfileScreen(uid: ownerUid)),
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundImage:
                            ownerPhotoUrl.isNotEmpty
                                ? NetworkImage(ownerPhotoUrl)
                                : null,
                        backgroundColor: Colors.white24,
                        child:
                            ownerPhotoUrl.isEmpty
                                ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 18,
                                )
                                : null,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        username.isNotEmpty ? "@$username" : "Creator",
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  title.isNotEmpty ? title : "Reel",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 8,
            bottom: 24,
            child: Column(
              children: [
                IconButton(
                  icon: Icon(
                    _isMuted ? Icons.volume_off : Icons.volume_up,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    widget.mutedListenable.value = !_isMuted;
                  },
                ),
                const SizedBox(height: 8),
                IconButton(
                  icon: const Icon(Icons.send_outlined, color: Colors.white),
                  onPressed: () {
                    showModalBottomSheet(
                      context: context,
                      isScrollControlled: true,
                      useSafeArea: true,
                      backgroundColor: Colors.transparent,
                      builder:
                          (context) => ShareReelSheet(
                            reelId: reelId,
                            reelUrl: reelUrl,
                            reelOwnerUid: ownerUid,
                            reelOwnerUsername: username,
                            reelOwnerPhotoUrl: ownerPhotoUrl,
                            reelCoverUrl: coverUrl,
                            reelThumbnailUrl: thumbnailUrl,
                          ),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
