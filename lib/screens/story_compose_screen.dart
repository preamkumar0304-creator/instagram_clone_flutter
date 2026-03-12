import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/models/story_media_item.dart';
import 'package:instagram_clone_flutter_firebase/models/users.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';

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

  @override
  void initState() {
    super.initState();
    _items = widget.items.where((item) {
      if (item.type == StoryMediaType.image) {
        return item.bytes != null && item.bytes!.isNotEmpty;
      }
      return item.path != null && item.path!.isNotEmpty;
    }).toList();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
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
    setState(() {
      _isUploading = true;
      _uploadedCount = 0;
    });
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
          );
        }
      } else {
        message = await FirestoreMethods().uploadStory(
          type: StoryMediaType.image,
          imageBytes: item.bytes,
          uid: widget.user.uid,
          username: widget.user.username,
          profileUrl: widget.user.photoUrl,
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
      Navigator.pop(context);
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

  @override
  Widget build(BuildContext context) {
    final total = _items.length;
    final current = total == 0 ? 0 : _currentIndex + 1;
    return Scaffold(
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
                          return Image.memory(
                            item.bytes!,
                            fit: BoxFit.cover,
                          );
                        },
                      ),
            ),
            Positioned(
              top: 8,
              left: 8,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white),
                onPressed: () => Navigator.pop(context),
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
