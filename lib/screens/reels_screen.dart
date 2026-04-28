import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
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
  final ValueNotifier<bool> _isMuted = ValueNotifier<bool>(false);
  final ValueNotifier<bool> _isScreenVisible = ValueNotifier<bool>(true);
  final ValueNotifier<bool> _isScrollSettled = ValueNotifier<bool>(true);
  late final VoidCallback _homeTabListener;

  String _safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  Set<String> _safeStringSet(dynamic value) {
    if (value is List) {
      return value.whereType<String>().toSet();
    }
    return <String>{};
  }

  String _normalizeReelUrl(String url) {
    final raw = url.trim();
    if (raw.isEmpty) return "";
    final parsed = Uri.tryParse(raw);
    if (parsed == null) return raw;
    // Ignore token/query differences so the same media URL is not repeated.
    final host = parsed.host.toLowerCase();
    final path = parsed.path.toLowerCase();
    return "$host$path";
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _dedupeReels(
    List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
  ) {
    final seenKeys = <String>{};
    final seenUrls = <String>{};
    final unique = <QueryDocumentSnapshot<Map<String, dynamic>>>[];
    for (final doc in docs) {
      final data = doc.data();
      final reelId =
          _safeString(data["reelId"]).isNotEmpty
              ? _safeString(data["reelId"])
              : doc.id;
      final reelUrl = _safeString(data["reelUrl"]);
      if (reelUrl.isEmpty) continue;
      final normalizedUrl = _normalizeReelUrl(reelUrl);
      if (normalizedUrl.isNotEmpty && !seenUrls.add(normalizedUrl)) {
        continue;
      }
      final key = "$reelId|$normalizedUrl";
      if (!seenKeys.add(key)) continue;
      unique.add(doc);
    }
    return unique;
  }

  List<QueryDocumentSnapshot<Map<String, dynamic>>> _buildReelsFeed({
    required List<QueryDocumentSnapshot<Map<String, dynamic>>> docs,
    required String currentUid,
    required Set<String> followingUids,
    required Set<String> blockedUids,
  }) {
    final visible = docs
        .where((doc) {
          final ownerUid = _safeString(doc.data()["uid"]);
          if (ownerUid.isEmpty) return false;
          return !blockedUids.contains(ownerUid);
        })
        .toList(growable: false);

    final allowed = <String>{...followingUids, currentUid};
    final followingOnly = visible
        .where((doc) => allowed.contains(_safeString(doc.data()["uid"])))
        .toList(growable: false);

    // Keep fallback feed ready when following users have no reels.
    return followingOnly.isNotEmpty ? followingOnly : visible;
  }

  void _clampCurrentIndex(int length) {
    if (length <= 0 || _currentIndex < length) return;
    final nextIndex = length - 1;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _currentIndex = nextIndex;
      });
    });
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
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
    homeTabIndexNotifier.removeListener(_homeTabListener);
    _pageController.dispose();
    _isMuted.dispose();
    _isScreenVisible.dispose();
    _isScrollSettled.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final currentUid = FirebaseAuth.instance.currentUser?.uid ?? "";
    return Scaffold(
      backgroundColor: Colors.black,
      body: VisibilityDetector(
        key: const Key("reels_visibility"),
        onVisibilityChanged: (info) {
          _isScreenVisible.value = info.visibleFraction > 0.6;
        },
        child: Stack(
          children: [
            StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream:
                  currentUid.isEmpty
                      ? null
                      : FirebaseFirestore.instance
                          .collection("users")
                          .doc(currentUid)
                          .snapshots(),
              builder: (context, userSnap) {
                final userData =
                    userSnap.data?.data() ?? const <String, dynamic>{};
                final followingUids = _safeStringSet(userData["following"]);
                final blockedUids = _safeStringSet(userData["blockedUsers"]);
                return NotificationListener<OverscrollIndicatorNotification>(
                  onNotification: (overscroll) {
                    overscroll.disallowIndicator();
                    return false;
                  },
                  child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                    stream:
                        FirebaseFirestore.instance
                            .collection("reels")
                            .orderBy("createdAt", descending: true)
                            .limit(200)
                            .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting &&
                          snapshot.data == null) {
                        return const Center(
                          child: CircularProgressIndicator(color: primaryColor),
                        );
                      }
                      final rawDocs = snapshot.data?.docs ?? [];
                      final dedupedDocs = _dedupeReels(rawDocs);
                      final feedDocs = _buildReelsFeed(
                        docs: dedupedDocs,
                        currentUid: currentUid,
                        followingUids: followingUids,
                        blockedUids: blockedUids,
                      );
                      _clampCurrentIndex(feedDocs.length);
                      if (feedDocs.isEmpty) {
                        return const Center(
                          child: Text(
                            "No reels yet.",
                            style: TextStyle(color: Colors.white),
                          ),
                        );
                      }
                      return NotificationListener<ScrollNotification>(
                        onNotification: (notification) {
                          // Pause all reels while the page is in transition;
                          // resume only when scroll settles on one full-screen item.
                          if (notification is ScrollStartNotification) {
                            _isScrollSettled.value = false;
                          } else if (notification is ScrollEndNotification) {
                            _isScrollSettled.value = true;
                            final page = _pageController.page;
                            if (page != null) {
                              final nextIndex = page.round();
                              if (nextIndex != _currentIndex &&
                                  nextIndex >= 0 &&
                                  nextIndex < feedDocs.length) {
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
                          pageSnapping: true,
                          physics: const PageScrollPhysics(
                            parent: BouncingScrollPhysics(),
                          ),
                          allowImplicitScrolling: true,
                          onPageChanged: (index) {
                            if (_currentIndex == index) return;
                            setState(() {
                              _currentIndex = index;
                            });
                          },
                          itemCount: feedDocs.length,
                          itemBuilder: (context, index) {
                            return _ReelPage(
                              key: ValueKey(feedDocs[index].id),
                              data: feedDocs[index].data(),
                              isActive: index == _currentIndex,
                              shouldPrepare: (index - _currentIndex).abs() <= 1,
                              mutedListenable: _isMuted,
                              screenVisibleListenable: _isScreenVisible,
                              scrollSettledListenable: _isScrollSettled,
                            );
                          },
                        ),
                      );
                    },
                  ),
                );
              },
            ),
            // Soft overlays keep text/icons readable while preserving full-screen video.
            Positioned.fill(
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withOpacity(0.35),
                        Colors.transparent,
                        Colors.transparent,
                        Colors.black.withOpacity(0.6),
                      ],
                      stops: const [0, 0.18, 0.55, 1],
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: IconButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder:
                                  (_) => const AddPostScreen(
                                    initialCreateType: "reel",
                                  ),
                            ),
                          );
                        },
                        icon: const Icon(
                          Icons.add_circle_outline_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.45),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white24),
                      ),
                      child: const Row(
                        children: [
                          Text(
                            "Reels",
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.2,
                            ),
                          ),
                          SizedBox(width: 4),
                          Icon(
                            Icons.keyboard_arrow_down_rounded,
                            color: Colors.white,
                            size: 20,
                          ),
                        ],
                      ),
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
  final bool shouldPrepare;
  final ValueNotifier<bool> mutedListenable;
  final ValueNotifier<bool> screenVisibleListenable;
  final ValueNotifier<bool> scrollSettledListenable;

  const _ReelPage({
    super.key,
    required this.data,
    required this.isActive,
    required this.shouldPrepare,
    required this.mutedListenable,
    required this.screenVisibleListenable,
    required this.scrollSettledListenable,
  });

  @override
  State<_ReelPage> createState() => _ReelPageState();
}

class _ReelPageState extends State<_ReelPage> {
  VideoPlayerController? _controller;
  bool _isReady = false;
  bool _hasError = false;
  bool _isLoading = false;
  String _activeUrl = "";
  bool _isMuted = false;
  int _loadVersion = 0;
  late final VoidCallback _muteListener;
  late final VoidCallback _visibilityListener;

  String _safeString(dynamic value) {
    if (value == null) return "";
    return value.toString();
  }

  @override
  void initState() {
    super.initState();
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
    widget.scrollSettledListenable.addListener(_visibilityListener);
    _syncPreparedState();
  }

  @override
  void didUpdateWidget(covariant _ReelPage oldWidget) {
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
      await controller.setVolume(_isMuted ? 0.0 : 1.0);
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
        widget.scrollSettledListenable.value &&
        widget.isActive &&
        _isReady;
    if (shouldPlay) {
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
    widget.mutedListenable.removeListener(_muteListener);
    widget.screenVisibleListenable.removeListener(_visibilityListener);
    widget.scrollSettledListenable.removeListener(_visibilityListener);
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
    return RepaintBoundary(
      key: ValueKey(visibilityKey),
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
            right: 96,
            bottom: 24,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                GestureDetector(
                  onTap: () {
                    if (ownerUid.isEmpty) return;
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => ProfileScreen(uid: ownerUid),
                      ),
                    );
                  },
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 17,
                        backgroundImage:
                            ownerPhotoUrl.isNotEmpty
                                ? NetworkImage(ownerPhotoUrl)
                                : null,
                        backgroundColor: Colors.white24,
                        child:
                            ownerPhotoUrl.isEmpty
                                ? const Icon(
                                  Icons.person_outline_rounded,
                                  color: Colors.white,
                                  size: 18,
                                )
                                : null,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          username.isNotEmpty ? "@$username" : "Creator",
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            letterSpacing: 0.2,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  title.isNotEmpty ? title : "Reel",
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            right: 10,
            bottom: 24,
            child: Column(
              children: [
                _ReelActionButton(
                  icon:
                      _isMuted
                          ? Icons.volume_off_rounded
                          : Icons.volume_up_rounded,
                  onTap: () {
                    widget.mutedListenable.value = !_isMuted;
                  },
                ),
                const SizedBox(height: 10),
                _ReelActionButton(
                  icon: Icons.send_rounded,
                  onTap: () {
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

class _ReelActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _ReelActionButton({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withOpacity(0.45),
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: Icon(icon, color: Colors.white, size: 23),
        ),
      ),
    );
  }
}
