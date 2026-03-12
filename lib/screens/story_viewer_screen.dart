import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:video_player/video_player.dart';

class StoryViewerScreen extends StatefulWidget {
  final String ownerUid;
  final String viewerUid;

  const StoryViewerScreen({
    super.key,
    required this.ownerUid,
    required this.viewerUid,
  });

  @override
  State<StoryViewerScreen> createState() => _StoryViewerScreenState();
}

class _StoryViewerScreenState extends State<StoryViewerScreen>
    with SingleTickerProviderStateMixin {
  int _currentIndex = 0;
  final Set<String> _viewedStoryIds = {};
  late final PageController _pageController;
  late final AnimationController _progressController;
  int _lastStoryCount = 0;
  static const Duration _imageDuration = Duration(seconds: 5);
  static const Duration _videoDuration = Duration(seconds: 15);
  VideoPlayerController? _videoController;
  String _activeStoryId = "";
  String _activeVideoUrl = "";
  bool _isVideoReady = false;

  int _safeInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return 0;
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> _storyStream() {
    return FirebaseFirestore.instance
        .collection("stories")
        .where("uid", isEqualTo: widget.ownerUid)
        .snapshots();
  }

  String _formatTimeAgo(dynamic createdAt) {
    DateTime? time;
    if (createdAt is Timestamp) {
      time = createdAt.toDate();
    } else if (createdAt is DateTime) {
      time = createdAt;
    }
    if (time == null) return "";
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return "now";
    if (diff.inMinutes < 60) return "${diff.inMinutes}m";
    if (diff.inHours < 24) return "${diff.inHours}h";
    return "${diff.inDays}d";
  }

  Future<void> _recordViewIfNeeded(Map<String, dynamic> story) async {
    final storyId = (story["storyId"] ?? "").toString();
    if (storyId.isEmpty) return;
    if (_viewedStoryIds.contains(storyId)) return;
    _viewedStoryIds.add(storyId);
    await FirestoreMethods().recordStoryView(
      storyId: storyId,
      viewerUid: widget.viewerUid,
    );
  }

  Future<void> _showViewersCount(int count) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: mobileBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.remove_red_eye, color: primaryColor),
                const SizedBox(width: 10),
                Text(
                  "Viewed by $count",
                  style: const TextStyle(color: primaryColor, fontSize: 16),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _promptHighlightTitle(
    Map<String, dynamic> story,
  ) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: mobileBackgroundColor,
          title: const Text(
            "Add to highlight",
            style: TextStyle(color: primaryColor),
          ),
          content: TextField(
            controller: controller,
            style: const TextStyle(color: primaryColor),
            decoration: const InputDecoration(
              hintText: "Highlight name",
              hintStyle: TextStyle(color: secondaryColor),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Cancel", style: TextStyle(color: primaryColor)),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, controller.text.trim()),
              child: const Text("Add", style: TextStyle(color: blueColor)),
            ),
          ],
        );
      },
    );

    if (title == null || title.trim().isEmpty) return;
    await FirestoreMethods().addStoryToHighlight(
      storyData: story,
      title: title.trim(),
    );
    if (!mounted) return;
    showSnackBar(
      context: context,
      content: "Added to highlight.",
      clr: successColor,
    );
  }

  Future<void> _showStoryMenu(Map<String, dynamic> story) async {
    final isOwner = widget.viewerUid == widget.ownerUid;
    await showModalBottomSheet(
      context: context,
      backgroundColor: mobileBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text("Delete story"),
                  onTap: () async {
                    Navigator.pop(context);
                    await FirestoreMethods().deleteStory(
                      (story["storyId"] ?? "").toString(),
                    );
                    _activeStoryId = "";
                    _progressController.reset();
                  },
                ),
              if (isOwner)
                ListTile(
                  leading: const Icon(Icons.auto_awesome, color: primaryColor),
                  title: const Text("Add to highlight"),
                  onTap: () async {
                    Navigator.pop(context);
                    await _promptHighlightTitle(story);
                  },
                ),
              ListTile(
                leading: const Icon(Icons.save_alt, color: primaryColor),
                title: const Text("Save"),
                onTap: () {
                  Navigator.pop(context);
                  showSnackBar(
                    context: context,
                    content: "Save to device coming soon.",
                    clr: secondaryColor,
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.share_outlined, color: primaryColor),
                title: const Text("Share"),
                onTap: () {
                  Navigator.pop(context);
                  showSnackBar(
                    context: context,
                    content: "Share coming soon.",
                    clr: secondaryColor,
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _progressController =
        AnimationController(vsync: this, duration: _imageDuration)
          ..addStatusListener((status) {
            if (status == AnimationStatus.completed) {
              _advanceStory();
            }
          });
    if (widget.viewerUid == widget.ownerUid) {
      FirestoreMethods().archiveExpiredStories(widget.ownerUid);
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _progressController.dispose();
    _videoController?.dispose();
    super.dispose();
  }

  void _startProgress(Duration duration) {
    _progressController.stop();
    _progressController.duration = duration;
    _progressController.reset();
    _progressController.forward();
  }

  void _advanceStory() {
    if (_lastStoryCount == 0) return;
    if (_currentIndex + 1 < _lastStoryCount) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      Navigator.pop(context);
    }
  }

  Future<void> _disposeVideo() async {
    final controller = _videoController;
    if (controller != null) {
      try {
        await controller.pause();
      } catch (_) {}
      await controller.dispose();
    }
    _videoController = null;
    _activeVideoUrl = "";
    _isVideoReady = false;
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _prepareStory(Map<String, dynamic> story) async {
    final storyId = (story["storyId"] ?? "").toString();
    final storyType = (story["storyType"] ?? "image").toString();
    final isVideo = storyType == "video";
    final durationSeconds = _safeInt(story["storyDuration"]);
    final targetDuration =
        durationSeconds > 0
            ? Duration(seconds: durationSeconds)
            : (isVideo ? _videoDuration : _imageDuration);
    if (storyId.isNotEmpty && storyId == _activeStoryId) return;
    _activeStoryId = storyId;

    if (isVideo) {
      final url = (story["storyUrl"] ?? "").toString();
      if (url.isEmpty) {
        await _disposeVideo();
        _startProgress(targetDuration);
        return;
      }
      if (_activeVideoUrl != url) {
        await _disposeVideo();
        _videoController = VideoPlayerController.network(url);
        try {
          await _videoController!.initialize();
          _videoController!.setLooping(false);
          _videoController!.setVolume(1.0);
          _isVideoReady = true;
          if (mounted) {
            setState(() {});
          }
        } catch (_) {
          await _disposeVideo();
        }
      }
      if (_videoController != null) {
        await _videoController!.play();
      }
      _activeVideoUrl = url;
      _startProgress(targetDuration);
      return;
    }

    await _disposeVideo();
    _startProgress(targetDuration);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.ownerUid.isEmpty) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: Text("Story not available", style: TextStyle(color: Colors.white)),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _storyStream(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              _progressController.stop();
              _progressController.reset();
              _videoController?.dispose();
              _videoController = null;
              _activeStoryId = "";
              _activeVideoUrl = "";
              _isVideoReady = false;
              return const Center(
                child: Text(
                  "Unable to load stories",
                  style: TextStyle(color: primaryColor),
                ),
              );
            }
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(
                child: CircularProgressIndicator(color: primaryColor),
              );
            }
            final docs = snapshot.data?.docs ?? [];
            if (docs.isEmpty) {
              _progressController.stop();
              _progressController.reset();
              _videoController?.dispose();
              _videoController = null;
              _activeStoryId = "";
              _activeVideoUrl = "";
              _isVideoReady = false;
              return const Center(
                child: Text(
                  "No stories",
                  style: TextStyle(color: primaryColor),
                ),
              );
            }
            final now = DateTime.now();
            final stories = <Map<String, dynamic>>[];
            final seenIds = <String>{};
            for (final doc in docs) {
              final data = doc.data();
              final id = (data["storyId"] ?? doc.id).toString();
              if (id.isEmpty || seenIds.contains(id)) continue;
              final expiresAt = data["expiresAt"];
              DateTime? expires;
              if (expiresAt is Timestamp) {
                expires = expiresAt.toDate();
              } else if (expiresAt is DateTime) {
                expires = expiresAt;
              }
              if (expires != null && expires.isBefore(now)) {
                continue;
              }
              seenIds.add(id);
              stories.add(data);
            }
            stories.sort((a, b) {
              DateTime? aTime;
              DateTime? bTime;
              final aRaw = a["createdAt"];
              final bRaw = b["createdAt"];
              if (aRaw is Timestamp) {
                aTime = aRaw.toDate();
              } else if (aRaw is DateTime) {
                aTime = aRaw;
              }
              if (bRaw is Timestamp) {
                bTime = bRaw.toDate();
              } else if (bRaw is DateTime) {
                bTime = bRaw;
              }
              if (aTime == null && bTime == null) return 0;
              if (aTime == null) return -1;
              if (bTime == null) return 1;
              return aTime.compareTo(bTime);
            });
            if (stories.isEmpty) {
              _progressController.stop();
              _progressController.reset();
              _videoController?.dispose();
              _videoController = null;
              _activeStoryId = "";
              _activeVideoUrl = "";
              _isVideoReady = false;
              return const Center(
                child: Text(
                  "No stories",
                  style: TextStyle(color: primaryColor),
                ),
              );
            }
            _lastStoryCount = stories.length;
            if (_currentIndex >= stories.length) {
              _currentIndex = stories.length - 1;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (!mounted) return;
                _pageController.jumpToPage(_currentIndex);
              });
            }

            WidgetsBinding.instance.addPostFrameCallback((_) {
              _recordViewIfNeeded(stories[_currentIndex]);
              _prepareStory(stories[_currentIndex]);
            });

            return Stack(
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: stories.length,
                  onPageChanged: (index) {
                    setState(() {
                      _currentIndex = index;
                    });
                    _recordViewIfNeeded(stories[index]);
                    _prepareStory(stories[index]);
                  },
                  itemBuilder: (context, index) {
                    final story = stories[index];
                    final url = (story["storyUrl"] ?? "").toString();
                    final storyType =
                        (story["storyType"] ?? "image").toString();
                    if (storyType == "video") {
                      if (index == _currentIndex &&
                          _videoController != null &&
                          _isVideoReady &&
                          _activeVideoUrl == url) {
                        return FittedBox(
                          fit: BoxFit.cover,
                          clipBehavior: Clip.hardEdge,
                          child: SizedBox(
                            width: _videoController!.value.size.width,
                            height: _videoController!.value.size.height,
                            child: VideoPlayer(_videoController!),
                          ),
                        );
                      }
                      return Container(
                        color: Colors.black,
                        alignment: Alignment.center,
                        child: const Icon(
                          Icons.play_circle_fill,
                          color: Colors.white,
                          size: 72,
                        ),
                      );
                    }
                    return Container(
                      color: Colors.black,
                      alignment: Alignment.center,
                      child: url.isEmpty
                          ? const Text(
                              "Story unavailable",
                              style: TextStyle(color: primaryColor),
                            )
                          : Image.network(
                              url,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                        ),
                    );
                  },
                ),
                Positioned(
                  top: 6,
                  left: 12,
                  right: 12,
                  child: AnimatedBuilder(
                    animation: _progressController,
                    builder: (context, _) {
                      return Row(
                        children: List.generate(stories.length, (index) {
                          final value =
                              index < _currentIndex
                                  ? 1.0
                                  : index == _currentIndex
                                  ? _progressController.value
                                  : 0.0;
                          return Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 2),
                              child: LinearProgressIndicator(
                                value: value,
                                backgroundColor: Colors.white24,
                                color: Colors.white,
                                minHeight: 2,
                              ),
                            ),
                          );
                        }),
                      );
                    },
                  ),
                ),
                Positioned(
                  top: 12,
                  left: 12,
                  right: 12,
                  child: Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.close, color: Colors.white),
                        onPressed: () => Navigator.pop(context),
                      ),
                      const SizedBox(width: 4),
                      CircleAvatar(
                        radius: 16,
                        backgroundImage:
                            (stories[_currentIndex]["photoUrl"] ?? "")
                                    .toString()
                                    .isNotEmpty
                                ? NetworkImage(
                                  (stories[_currentIndex]["photoUrl"] ?? "")
                                      .toString(),
                                )
                                : null,
                        backgroundColor: Colors.grey.shade800,
                        child:
                            (stories[_currentIndex]["photoUrl"] ?? "")
                                    .toString()
                                    .isEmpty
                                ? const Icon(
                                  Icons.person,
                                  color: Colors.white,
                                  size: 16,
                                )
                                : null,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Flexible(
                              child: Text(
                                (stories[_currentIndex]["username"] ?? "")
                                    .toString(),
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              _formatTimeAgo(
                                stories[_currentIndex]["createdAt"],
                              ),
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.more_vert, color: Colors.white),
                        onPressed: () => _showStoryMenu(stories[_currentIndex]),
                      ),
                    ],
                  ),
                ),
                if (widget.viewerUid == widget.ownerUid)
                  Positioned(
                    bottom: 24,
                    left: 16,
                    right: 16,
                    child: GestureDetector(
                      onTap: () {
                        final count = _safeInt(
                          stories[_currentIndex]["viewerCount"],
                        );
                        _showViewersCount(count);
                      },
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(
                            Icons.remove_red_eye,
                            color: Colors.white,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            _safeInt(stories[_currentIndex]["viewerCount"])
                                .toString(),
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            );
          },
        ),
      ),
    );
  }
}
