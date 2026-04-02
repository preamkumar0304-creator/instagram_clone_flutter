import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/methods/storage_methods.dart';
import 'package:instagram_clone_flutter_firebase/models/story_media_item.dart';
import 'package:instagram_clone_flutter_firebase/models/users.dart';
import 'package:instagram_clone_flutter_firebase/screens/story_viewer_screen.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/global_variables.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:just_audio/just_audio.dart';

class StoryComposeScreen extends StatefulWidget {
  final List<StoryMediaItem> items;
  final UserModel user;

  const StoryComposeScreen({super.key, required this.items, required this.user});

  @override
  State<StoryComposeScreen> createState() => _StoryComposeScreenState();
}

class _StoryComposeScreenState extends State<StoryComposeScreen> {
  bool _isUploading = false;
  int _currentIndex = 0;
  int _uploadedCount = 0;
  late final PageController _pageController;
  late List<StoryMediaItem> _items;
  final AudioPlayer _audioPlayer = AudioPlayer();
  StreamSubscription<Duration>? _audioPositionSub;
  String? _audioPath;
  String? _audioName;
  double _audioDurationSeconds = 0;
  double _audioStartSeconds = 0;
  double _audioEndSeconds = 0;
  double _audioPositionSeconds = 0;
  bool _isAudioReady = false;
  bool _isAudioPlaying = false;
  static const double _maxAudioClipSeconds = 20;

  Future<bool> _confirmDiscard() async {
    if (_isUploading) return false;
    final hasItems = _items.isNotEmpty;
    if (!hasItems) return true;
    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: mobileBackgroundColor,
          title: const Text(
            "Discard story?",
            style: TextStyle(color: primaryColor),
          ),
          content: const Text(
            "If you go back now, your story will be discarded.",
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
    return result ?? false;
  }

  Future<bool> _pickAudio() async {
    if (_isUploading) return false;
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
    return _loadAudio(path, picked.name);
  }

  Future<bool> _loadAudio(String path, String name) async {
    try {
      final duration = await _audioPlayer.setFilePath(path);
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
      final end = totalSeconds < _maxAudioClipSeconds
          ? totalSeconds
          : _maxAudioClipSeconds;
      setState(() {
        _audioPath = path;
        _audioName = name;
        _audioDurationSeconds = totalSeconds;
        _audioStartSeconds = 0;
        _audioEndSeconds = end;
        _audioPositionSeconds = 0;
        _isAudioReady = true;
        _isAudioPlaying = false;
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

  void _clearAudio() {
    _audioPlayer.stop();
    setState(() {
      _audioPath = null;
      _audioName = null;
      _audioDurationSeconds = 0;
      _audioStartSeconds = 0;
      _audioEndSeconds = 0;
      _audioPositionSeconds = 0;
      _isAudioReady = false;
      _isAudioPlaying = false;
    });
  }

  Future<void> _toggleAudioPlayback() async {
    if (!_isAudioReady || _audioPath == null) return;
    final file = File(_audioPath!);
    if (!file.existsSync()) {
      showSnackBar(
        context: context,
        content: "Audio file not found.",
        clr: errorColor,
      );
      _clearAudio();
      return;
    }
    if (_isAudioPlaying) {
      await _audioPlayer.pause();
      if (!mounted) return;
      setState(() {
        _isAudioPlaying = _audioPlayer.playing;
      });
      return;
    }
    if (_audioPositionSeconds < _audioStartSeconds ||
        _audioPositionSeconds > _audioEndSeconds) {
      await _audioPlayer.seek(
        Duration(milliseconds: (_audioStartSeconds * 1000).round()),
      );
    }
    await _audioPlayer.play();
    if (!mounted) return;
    setState(() {
      _isAudioPlaying = _audioPlayer.playing;
    });
  }

  void _updateTrim(RangeValues values) {
    _applyTrim(values.start, values.end, notify: true);
  }

  void _applyTrim(double start, double end, {required bool notify}) {
    final total = _audioDurationSeconds;
    if (total <= 0) return;
    final window =
        total <= _maxAudioClipSeconds ? total : _maxAudioClipSeconds;
    var nextStart = start;
    var nextEnd = end;
    if (total <= _maxAudioClipSeconds) {
      nextStart = 0;
      nextEnd = total;
    } else {
      final startDelta = (start - _audioStartSeconds).abs();
      final endDelta = (end - _audioEndSeconds).abs();
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
    _audioPlayer.pause();
    _audioPlayer.seek(
      Duration(milliseconds: (nextStart * 1000).round()),
    );
    if (notify) {
      setState(() {
        _audioStartSeconds = nextStart;
        _audioEndSeconds = nextEnd;
        _audioPositionSeconds = nextStart;
        _isAudioPlaying = false;
      });
    } else {
      _audioStartSeconds = nextStart;
      _audioEndSeconds = nextEnd;
      _audioPositionSeconds = nextStart;
      _isAudioPlaying = false;
    }
  }

  Future<void> _openAudioSheet({bool forcePick = false}) async {
    if (_isUploading) return;
    if (forcePick || !_isAudioReady || _audioPath == null) {
      final picked = await _pickAudio();
      if (!picked) return;
    }
    if (!mounted) return;
    await _audioPlayer.pause();
    if (mounted) {
      setState(() {
        _isAudioPlaying = false;
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
              final hasAudio = _audioPath != null && _isAudioReady;
              final total =
                  _audioDurationSeconds > 0 ? _audioDurationSeconds : 1.0;
              final start = _audioStartSeconds.clamp(0, total).toDouble();
              final end = _audioEndSeconds.clamp(0, total).toDouble();

              return Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(height: 6),
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
                          final picked = await _pickAudio();
                          if (!picked) return;
                          sheetSetState(() {});
                        },
                        icon: const Icon(Icons.music_note, size: 18),
                        label: const Text("Add Music"),
                      ),
                    if (hasAudio) ...[
                      const SizedBox(height: 12),
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
                        _audioName ?? "Local audio",
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
                                          _applyTrim(
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
                            stream: _audioPlayer.playerStateStream,
                            builder: (context, snapshot) {
                              final playing =
                                  snapshot.data?.playing ?? _isAudioPlaying;
                              return GestureDetector(
                                onTap: () async {
                                  await _toggleAudioPlayback();
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
                            final picked = await _pickAudio();
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

  Future<String> _uploadAudioIfNeeded() async {
    final path = _audioPath;
    if (path == null || path.isEmpty || !_isAudioReady) return "";
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
          "story_audio_${widget.user.uid}_${DateTime.now().millisecondsSinceEpoch}";
      final url = await StorageMethods().uploadFileToStorage(
        "stories",
        file,
        true,
        fileName: fileName,
        contentType: "audio/mpeg",
      );
      return url;
    } catch (_) {
      return "";
    }
  }

  @override
  void initState() {
    super.initState();
    final filtered = widget.items.where((item) {
      if (item.type == StoryMediaType.image) {
        return item.bytes != null && item.bytes!.isNotEmpty;
      }
      return item.path != null && item.path!.isNotEmpty;
    }).toList();
    final seenKeys = <String>{};
    _items =
        filtered.where((item) {
          if (item.type == StoryMediaType.video) {
            final path = item.path ?? "";
            if (path.isEmpty) return false;
            return seenKeys.add("v:$path");
          }
          final bytes = item.bytes!;
          final len = bytes.length;
          if (len == 0) return false;
          final first = bytes.first;
          final mid = bytes[len ~/ 2];
          final last = bytes.last;
          final key = "i:$len:$first:$mid:$last";
          return seenKeys.add(key);
        }).toList();
    _pageController = PageController();
    _audioPositionSub = _audioPlayer.positionStream.listen((position) {
      if (!_isAudioReady) return;
      final seconds = position.inMilliseconds / 1000.0;
      if (mounted) {
        setState(() {
          _audioPositionSeconds = seconds;
        });
      }
      if (_isAudioPlaying &&
          _audioEndSeconds > 0 &&
          seconds >= _audioEndSeconds - 0.05) {
        _audioPlayer.pause();
        _audioPlayer.seek(
          Duration(milliseconds: (_audioStartSeconds * 1000).round()),
        );
        if (mounted) {
          setState(() {
            _isAudioPlaying = false;
            _audioPositionSeconds = _audioStartSeconds;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    _pageController.dispose();
    _audioPositionSub?.cancel();
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _uploadStory() async {
    if (_isUploading) return;
    if (_items.isEmpty) {
      showSnackBar(
        context: context,
        content: "Please select at least one story.",
        clr: errorColor,
      );
      return;
    }
    await _audioPlayer.pause();
    if (mounted) {
      setState(() {
        _isAudioPlaying = false;
      });
    }
    setState(() {
      _isUploading = true;
      _uploadedCount = 0;
    });
    final audioUrl = await _uploadAudioIfNeeded();
    final hasAudio = audioUrl.isNotEmpty;
    final audioClipSeconds =
        (_audioEndSeconds - _audioStartSeconds).round().clamp(1, 20).toInt();
    final errors = <String>[];
    var successCount = 0;
    for (var i = 0; i < _items.length; i++) {
      final item = _items[i];
      String message = "";
      if (item.type == StoryMediaType.video) {
        final path = item.path ?? "";
        if (path.isEmpty) {
          message = "Video file is missing.";
        } else {
          final bytes = await XFile(path).readAsBytes();
          message = await FirestoreMethods().uploadStory(
            type: StoryMediaType.video,
            videoBytes: bytes,
            uid: widget.user.uid,
            username: widget.user.username,
            profileUrl: widget.user.photoUrl,
            audioUrl: hasAudio ? audioUrl : null,
            audioName: hasAudio ? _audioName : null,
            audioStart: hasAudio ? _audioStartSeconds : null,
            audioEnd: hasAudio ? _audioEndSeconds : null,
          );
        }
      } else {
        message = await FirestoreMethods().uploadStory(
          type: StoryMediaType.image,
          imageBytes: item.bytes,
          uid: widget.user.uid,
          username: widget.user.username,
          profileUrl: widget.user.photoUrl,
          audioUrl: hasAudio ? audioUrl : null,
          audioName: hasAudio ? _audioName : null,
          audioStart: hasAudio ? _audioStartSeconds : null,
          audioEnd: hasAudio ? _audioEndSeconds : null,
          storyDurationSeconds: hasAudio ? audioClipSeconds : null,
        );
      }
      if (!mounted) return;
      if (message.toLowerCase().contains("added")) {
        successCount += 1;
      } else if (message.trim().isNotEmpty) {
        errors.add(message);
      }
      setState(() {
        _uploadedCount = i + 1;
      });
    }
    if (!mounted) return;
    setState(() {
      _isUploading = false;
    });
    final total = _items.length;
    if (successCount == total) {
      showSnackBar(
        context: context,
        content: total == 1 ? "Story added." : "$successCount stories added.",
        clr: successColor,
      );
      storyRefreshNotifier.value++;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder:
              (_) => StoryViewerScreen(
                ownerUid: widget.user.uid,
                viewerUid: widget.user.uid,
                goHomeOnClose: true,
              ),
        ),
      );
      return;
    }
    final failureCount = total - successCount;
    final errorMessage =
        errors.isNotEmpty ? errors.first : "Unable to upload stories.";
    final summary =
        successCount == 0
            ? errorMessage
            : "$successCount of $total stories added. $failureCount failed.";
    showSnackBar(
      context: context,
      content: summary,
      clr: successCount > 0 ? secondaryColor : errorColor,
    );
  }

  String _formatSeconds(double seconds) {
    if (seconds.isNaN || seconds.isInfinite) return "0:00";
    final total = seconds.round();
    final mins = total ~/ 60;
    final secs = total % 60;
    final padded = secs.toString().padLeft(2, "0");
    return "$mins:$padded";
  }

  Widget _buildAudioPanel(int total) {
    final hasAudio = _audioPath != null && _isAudioReady;
    final bottomOffset = total > 1 ? 150.0 : 90.0;
    if (!hasAudio) {
      return Positioned(
        left: 12,
        bottom: bottomOffset,
        child: TextButton.icon(
          style: TextButton.styleFrom(
            backgroundColor: Colors.black.withOpacity(0.6),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
              side: const BorderSide(color: Colors.white24),
            ),
          ),
          onPressed: _isUploading ? null : () => _openAudioSheet(forcePick: true),
          icon: const Icon(Icons.music_note, size: 18),
          label: const Text("Add Music"),
        ),
      );
    }
    return Positioned(
      left: 12,
      right: 12,
      bottom: bottomOffset,
      child: GestureDetector(
        onTap: _isUploading ? null : _openAudioSheet,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.65),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white24),
          ),
          child: Row(
            children: [
              const Icon(Icons.music_note, color: Colors.white, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  _audioName ?? "Selected audio",
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white, fontSize: 12),
                ),
              ),
              TextButton(
                onPressed: _isUploading ? null : _openAudioSheet,
                child: const Text(
                  "Edit",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
              IconButton(
                onPressed: _isUploading ? null : _clearAudio,
                icon: const Icon(Icons.close, color: Colors.white70, size: 18),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final total = _items.length;
    final current = total == 0 ? 0 : _currentIndex + 1;
    return WillPopScope(
      onWillPop: _confirmDiscard,
      child: Scaffold(
        backgroundColor: Colors.black,
        body: SafeArea(
          child: Stack(
            children: [
            Positioned.fill(
              child:
                  total == 0
                      ? const Center(
                        child: Text(
                          "No story selected",
                          style: TextStyle(color: Colors.white),
                        ),
                      )
                      : PageView.builder(
                        controller: _pageController,
                        itemCount: total,
                        onPageChanged: (index) {
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                        itemBuilder: (context, index) {
                          final item = _items[index];
                          if (item.type == StoryMediaType.video) {
                            return Container(
                              color: Colors.black,
                              alignment: Alignment.center,
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: const [
                                  Icon(
                                    Icons.play_circle_fill,
                                    color: Colors.white,
                                    size: 64,
                                  ),
                                  SizedBox(height: 12),
                                  Text(
                                    "Video story",
                                    style: TextStyle(color: Colors.white70),
                                  ),
                                ],
                              ),
                            );
                          }
                          return InteractiveViewer(
                            minScale: 1.0,
                            maxScale: 4.0,
                            child: Image.memory(
                              item.bytes!,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              height: double.infinity,
                            ),
                          );
                        },
                      ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () async {
                  final discard = await _confirmDiscard();
                  if (discard && mounted) {
                    Navigator.pop(context);
                  }
                },
              ),
            ),
            if (total > 1)
              Positioned(
                top: 14,
                right: 72,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    "$current / $total",
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ),
            Positioned(
              top: 8,
              right: 8,
              child: Column(
                children: const [
                  _StoryActionIcon(label: "Aa", icon: Icons.text_fields),
                  SizedBox(height: 10),
                  _StoryActionIcon(label: "", icon: Icons.draw),
                  SizedBox(height: 10),
                  _StoryActionIcon(label: "", icon: Icons.music_note),
                  SizedBox(height: 10),
                  _StoryActionIcon(label: "", icon: Icons.auto_awesome),
                ],
              ),
            ),
            if (_isUploading)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(
                  color: blueColor,
                  value:
                      total == 0
                          ? null
                          : (_uploadedCount / total).clamp(0.0, 1.0),
                ),
              ),
            if (total > 1 && !_isUploading)
              Positioned(
                left: 12,
                right: 12,
                bottom: 78,
                child: SizedBox(
                  height: 54,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: total,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final isActive = index == _currentIndex;
                      final item = _items[index];
                      return GestureDetector(
                        onTap: () {
                          _pageController.jumpToPage(index);
                          setState(() {
                            _currentIndex = index;
                          });
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isActive ? blueColor : Colors.white24,
                              width: isActive ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child:
                                item.type == StoryMediaType.video
                                    ? Container(
                                      width: 46,
                                      height: 46,
                                      color: Colors.black87,
                                      child: const Icon(
                                        Icons.play_arrow,
                                        color: Colors.white,
                                        size: 18,
                                      ),
                                    )
                                    : Image.memory(
                                      item.bytes!,
                                      width: 46,
                                      height: 46,
                                      fit: BoxFit.cover,
                                    ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            _buildAudioPanel(total),
            Positioned(
              left: 12,
              right: 12,
              bottom: 16,
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _uploadStory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.add_circle, size: 18),
                          const SizedBox(width: 8),
                          Text(
                            total > 1 ? "Your story ($total)" : "Your story",
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _isUploading ? null : _uploadStory,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black.withOpacity(0.6),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(24),
                          side: const BorderSide(color: Colors.white24),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.star, size: 18, color: Colors.greenAccent),
                          SizedBox(width: 8),
                          Text(
                            "Close friends",
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: blueColor,
                    child: IconButton(
                      icon: const Icon(
                        Icons.arrow_forward,
                        color: Colors.white,
                      ),
                      onPressed: _isUploading ? null : _uploadStory,
                    ),
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StoryActionIcon extends StatelessWidget {
  final String label;
  final IconData icon;

  const _StoryActionIcon({required this.label, required this.icon});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: Colors.black.withOpacity(0.4),
      child: Icon(icon, color: Colors.white, size: 18),
    );
  }
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
