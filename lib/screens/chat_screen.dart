import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter_firebase/methods/storage_methods.dart';
import 'package:instagram_clone_flutter_firebase/methods/firestore_methods.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:video_player/video_player.dart';

class ChatScreen extends StatefulWidget {
  final String currentUid;
  final String otherUid;
  final String otherUsername;
  final String otherPhotoUrl;

  const ChatScreen({
    super.key,
    required this.currentUid,
    required this.otherUid,
    required this.otherUsername,
    required this.otherPhotoUrl,
  });

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ImagePicker _picker = ImagePicker();
  final AudioRecorder _recorder = AudioRecorder();
  final AudioPlayer _audioPlayer = AudioPlayer();
  bool _isRecording = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  String _playingUrl = "";
  static const int _maxUploadBytes = 100 * 1024 * 1024;

  String get _chatId {
    final ids = [widget.currentUid, widget.otherUid]..sort();
    return ids.join("_");
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty) return;
    _messageController.clear();
    await FirebaseFirestore.instance
        .collection("chats")
        .doc(_chatId)
        .collection("messages")
        .add({
          "type": "text",
          "text": text,
          "fromUid": widget.currentUid,
          "toUid": widget.otherUid,
          "createdAt": FieldValue.serverTimestamp(),
          "createdAtLocal": DateTime.now(),
          "reactions": {},
        });
    await FirestoreMethods().addNotification(
      toUid: widget.otherUid,
      fromUid: widget.currentUid,
      type: "message",
      message: text,
    );
  }

  Future<void> _sendImage(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final granted = await ensureGalleryPermission();
        if (!granted) return;
      }
      final image = await _picker.pickImage(source: source);
      if (image == null) return;
      final size = await image.length();
      if (size > _maxUploadBytes) {
        if (mounted) {
          showSnackBar(
            context: context,
            content: "Image too large. Max 100MB allowed.",
            clr: errorColor,
          );
        }
        return;
      }
      final bytes = await image.readAsBytes();
      if (bytes.isEmpty) return;
      final fileName = "${_chatId}_${DateTime.now().millisecondsSinceEpoch}";
      final url = await StorageMethods().uploadImageToStorage(
        "chatMedia",
        bytes,
        true,
        fileName: fileName,
      );
      await FirebaseFirestore.instance
          .collection("chats")
          .doc(_chatId)
          .collection("messages")
          .add({
            "type": "image",
            "text": "",
            "imageUrl": url,
            "fromUid": widget.currentUid,
            "toUid": widget.otherUid,
            "createdAt": FieldValue.serverTimestamp(),
            "createdAtLocal": DateTime.now(),
            "reactions": {},
          });
      await FirestoreMethods().addNotification(
        toUid: widget.otherUid,
        fromUid: widget.currentUid,
        type: "message",
        message: "Photo",
      );
    } catch (err) {
      if (mounted) {
        showSnackBar(
          context: context,
          content: err.toString(),
          clr: errorColor,
        );
      }
    }
  }

  Future<void> _sendVideo(ImageSource source) async {
    try {
      if (source == ImageSource.gallery) {
        final granted = await ensureGalleryPermission(forVideo: true);
        if (!granted) return;
      }
      final video = await _picker.pickVideo(source: source);
      if (video == null) return;
      final size = await video.length();
      if (size > _maxUploadBytes) {
        if (mounted) {
          showSnackBar(
            context: context,
            content: "Video too large. Max 100MB allowed.",
            clr: errorColor,
          );
        }
        return;
      }
      final bytes = await video.readAsBytes();
      if (bytes.isEmpty) return;
      final fileName = "${_chatId}_${DateTime.now().millisecondsSinceEpoch}";
      final url = await StorageMethods().uploadBytesToStorage(
        "chatMedia",
        bytes,
        true,
        fileName: fileName,
        contentType: "video/mp4",
      );
      await FirebaseFirestore.instance
          .collection("chats")
          .doc(_chatId)
          .collection("messages")
          .add({
            "type": "video",
            "text": "",
            "videoUrl": url,
            "fromUid": widget.currentUid,
            "toUid": widget.otherUid,
            "createdAt": FieldValue.serverTimestamp(),
            "createdAtLocal": DateTime.now(),
            "reactions": {},
          });
      await FirestoreMethods().addNotification(
        toUid: widget.otherUid,
        fromUid: widget.currentUid,
        type: "message",
        message: "Video",
      );
    } catch (err) {
      if (mounted) {
        showSnackBar(
          context: context,
          content: err.toString(),
          clr: errorColor,
        );
      }
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    final micStatus = await Permission.microphone.request();
    if (!micStatus.isGranted) {
      if (mounted) {
        showSnackBar(
          context: context,
          content: "Microphone permission is required.",
          clr: errorColor,
        );
      }
      return;
    }
    final hasPermission = await _recorder.hasPermission();
    if (!hasPermission) return;
    final dir = await getTemporaryDirectory();
    final path =
        "${dir.path}/voice_${DateTime.now().millisecondsSinceEpoch}.m4a";
    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
    if (!mounted) return;
    setState(() {
      _isRecording = true;
      _recordDuration = Duration.zero;
    });
    _recordTimer?.cancel();
    _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() {
        _recordDuration += const Duration(seconds: 1);
      });
    });
  }

  Future<void> _stopRecording() async {
    if (!_isRecording) return;
    final path = await _recorder.stop();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
    });
    _recordTimer?.cancel();
    final durationSec = _recordDuration.inSeconds;
    if (path == null || path.isEmpty) return;
    try {
      final bytes = await File(path).readAsBytes();
      if (bytes.isEmpty) return;
      if (bytes.length > _maxUploadBytes) {
        if (mounted) {
          showSnackBar(
            context: context,
            content: "Audio too large. Max 100MB allowed.",
            clr: errorColor,
          );
        }
        return;
      }
      final fileName = "${_chatId}_${DateTime.now().millisecondsSinceEpoch}";
      final url = await StorageMethods().uploadBytesToStorage(
        "chatMedia",
        bytes,
        true,
        fileName: fileName,
        contentType: "audio/m4a",
      );
      await FirebaseFirestore.instance
          .collection("chats")
          .doc(_chatId)
          .collection("messages")
          .add({
            "type": "audio",
            "text": "",
            "audioUrl": url,
            "audioDurationSec": durationSec,
            "fromUid": widget.currentUid,
            "toUid": widget.otherUid,
            "createdAt": FieldValue.serverTimestamp(),
            "createdAtLocal": DateTime.now(),
            "reactions": {},
          });
      await FirestoreMethods().addNotification(
        toUid: widget.otherUid,
        fromUid: widget.currentUid,
        type: "message",
        message: "Voice message",
      );
    } catch (err) {
      if (mounted) {
        showSnackBar(
          context: context,
          content: err.toString(),
          clr: errorColor,
        );
      }
    }
  }

  Future<void> _cancelRecording() async {
    if (!_isRecording) return;
    await _recorder.cancel();
    _recordTimer?.cancel();
    if (!mounted) return;
    setState(() {
      _isRecording = false;
      _recordDuration = Duration.zero;
    });
  }

  Future<void> _toggleAudio(String url) async {
    if (url.isEmpty) return;
    if (_playingUrl == url) {
      await _audioPlayer.stop();
      if (!mounted) return;
      setState(() {
        _playingUrl = "";
      });
      return;
    }
    await _audioPlayer.stop();
    await _audioPlayer.play(UrlSource(url));
    if (!mounted) return;
    setState(() {
      _playingUrl = url;
    });
  }

  String _currentUserReaction(Map<String, dynamic> reactions) {
    for (final entry in reactions.entries) {
      final list =
          entry.value is List
              ? (entry.value as List).whereType<String>().toList()
              : <String>[];
      if (list.contains(widget.currentUid)) {
        return entry.key;
      }
    }
    return "";
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, "0");
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, "0");
    return "$minutes:$seconds";
  }

  String _formatAudioSeconds(int seconds) {
    if (seconds <= 0) return "00:00";
    return _formatDuration(Duration(seconds: seconds));
  }

  Future<void> _toggleReaction({
    required String messageId,
    required String emoji,
  }) async {
    final ref =
        FirebaseFirestore.instance
            .collection("chats")
            .doc(_chatId)
            .collection("messages")
            .doc(messageId);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) return;
      final data = snap.data() as Map<String, dynamic>? ?? {};
      final reactionsRaw = data["reactions"];
      final reactions =
          reactionsRaw is Map
              ? Map<String, dynamic>.from(reactionsRaw)
              : <String, dynamic>{};
      final currentEmoji = _currentUserReaction(reactions);
      for (final key in reactions.keys.toList()) {
        final listRaw = reactions[key];
        final list =
            listRaw is List ? listRaw.whereType<String>().toList() : <String>[];
        list.remove(widget.currentUid);
        if (list.isEmpty) {
          reactions.remove(key);
        } else {
          reactions[key] = list;
        }
      }
      if (currentEmoji != emoji) {
        final list =
            reactions[emoji] is List
                ? (reactions[emoji] as List).whereType<String>().toList()
                : <String>[];
        list.add(widget.currentUid);
        reactions[emoji] = list;
      }
      tx.update(ref, {"reactions": reactions});
    });
  }

  void _openReactionPicker({
    required String messageId,
    required String currentReaction,
  }) {
    const options = ["❤️", "😂", "😮", "😢", "😡", "👍"];
    showModalBottomSheet(
      context: context,
      backgroundColor: mobileBackgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: options.map((emoji) {
                final isSelected = currentReaction == emoji;
                return GestureDetector(
                  onTap: () {
                    Navigator.pop(context);
                    _toggleReaction(messageId: messageId, emoji: emoji);
                  },
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.black12 : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      emoji,
                      style: const TextStyle(fontSize: 22),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _messageController.dispose();
    _audioPlayer.dispose();
    _recorder.dispose();
    _recordTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        title: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundImage:
                  widget.otherPhotoUrl.isNotEmpty
                      ? NetworkImage(widget.otherPhotoUrl)
                      : null,
              backgroundColor: Colors.grey.shade300,
              child:
                  widget.otherPhotoUrl.isEmpty
                      ? const Icon(Icons.person, color: Colors.black)
                      : null,
            ),
            const SizedBox(width: 8),
            Text(
              widget.otherUsername.isNotEmpty
                  ? widget.otherUsername
                  : "User",
              style: const TextStyle(color: primaryColor),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream:
                  FirebaseFirestore.instance
                      .collection("chats")
                      .doc(_chatId)
                      .collection("messages")
                      .orderBy("createdAtLocal", descending: true)
                      .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  );
                }
                final docs = snapshot.data?.docs ?? [];
                if (docs.isEmpty) {
                  return const Center(
                    child: Text(
                      "Say hello!",
                      style: TextStyle(color: secondaryColor),
                    ),
                  );
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  reverse: true,
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final text = (data["text"] ?? "").toString();
                    final imageUrl = (data["imageUrl"] ?? "").toString();
                    final videoUrl = (data["videoUrl"] ?? "").toString();
                    final audioUrl = (data["audioUrl"] ?? "").toString();
                    final audioDurationRaw = data["audioDurationSec"];
                    final audioDurationSec =
                        audioDurationRaw is num
                            ? audioDurationRaw.toInt()
                            : 0;
                    final shareType = (data["type"] ?? "").toString();
                    final fromUid = (data["fromUid"] ?? "").toString();
                    final isMe = fromUid == widget.currentUid;
                    final reactionsRaw = data["reactions"];
                    final reactions =
                        reactionsRaw is Map
                            ? Map<String, dynamic>.from(reactionsRaw)
                            : <String, dynamic>{};
                    final currentReaction = _currentUserReaction(reactions);
                    final reactionEntries = reactions.entries
                        .map((e) {
                          final list =
                              e.value is List
                                  ? (e.value as List)
                                      .whereType<String>()
                                      .toList()
                                  : <String>[];
                          return MapEntry(e.key, list.length);
                        })
                        .where((e) => e.value > 0)
                        .toList();
                    return Align(
                      alignment:
                          isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color:
                              isMe
                                  ? const Color(0xFFE0E0E0)
                                  : const Color(0xFFF3F3F3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.black12),
                        ),
                        child: GestureDetector(
                          onLongPress: () {
                            _openReactionPicker(
                              messageId: doc.id,
                              currentReaction: currentReaction,
                            );
                          },
                          child: Column(
                            crossAxisAlignment:
                                isMe
                                    ? CrossAxisAlignment.end
                                    : CrossAxisAlignment.start,
                            children: [
                              if (shareType == "share_post")
                                _ShareCard(
                                  title: "Shared a post",
                                  subtitle: data["postOwnerUsername"] ?? "",
                                  imageUrl: data["postUrl"] ?? "",
                                  isMe: isMe,
                                )
                              else if (shareType == "share_reel")
                                _ShareCard(
                                  title: "Shared a reel",
                                  subtitle: data["reelOwnerUsername"] ?? "",
                                  imageUrl:
                                      data["reelCoverUrl"] ??
                                      data["reelThumbnailUrl"] ??
                                      "",
                                  isMe: isMe,
                                )
                              else if (shareType == "share_profile")
                                _ShareCard(
                                  title: "Shared a profile",
                                  subtitle: data["profileUsername"] ?? "",
                                  imageUrl: data["profilePhotoUrl"] ?? "",
                                  isMe: isMe,
                                )
                              else if (imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    imageUrl,
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else if (videoUrl.isNotEmpty)
                                _VideoPreview(
                                  url: videoUrl,
                                  isMe: isMe,
                                )
                              else if (audioUrl.isNotEmpty ||
                                  shareType == "audio")
                                _AudioMessageBubble(
                                  isMe: isMe,
                                  isPlaying:
                                      audioUrl.isNotEmpty &&
                                      _playingUrl == audioUrl,
                                  durationLabel:
                                      _formatAudioSeconds(audioDurationSec),
                                  onTap:
                                      audioUrl.isNotEmpty
                                          ? () => _toggleAudio(audioUrl)
                                          : null,
                                )
                              else
                                Text(
                                  text,
                                  style: TextStyle(
                                    color: primaryColor,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                              if (reactionEntries.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6),
                                  child: Wrap(
                                    spacing: 6,
                                    children:
                                        reactionEntries.map((entry) {
                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 6,
                                              vertical: 2,
                                            ),
                                            decoration: BoxDecoration(
                                              color: Colors.black12,
                                              borderRadius:
                                                  BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              "${entry.key} ${entry.value}",
                                              style: TextStyle(
                                                color:
                                                    isMe
                                                        ? Colors.white
                                                        : primaryColor,
                                                fontSize: 12,
                                              ),
                                            ),
                                          );
                                        }).toList(),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  if (_isRecording) ...[
                    IconButton(
                      icon: const Icon(Icons.delete, color: errorColor),
                      onPressed: _cancelRecording,
                    ),
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(24),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.mic, color: errorColor, size: 18),
                            const SizedBox(width: 8),
                            Text(
                              _formatDuration(_recordDuration),
                              style: const TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: 12),
                            const Expanded(
                              child: Text(
                                "Recording...",
                                style: TextStyle(color: secondaryColor),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: successColor),
                      onPressed: _stopRecording,
                    ),
                  ] else ...[
                    IconButton(
                      icon: const Icon(Icons.add, color: secondaryColor),
                      onPressed: () async {
                        await showModalBottomSheet(
                          context: context,
                          backgroundColor: mobileBackgroundColor,
                          shape: const RoundedRectangleBorder(
                            borderRadius: BorderRadius.vertical(
                              top: Radius.circular(16),
                            ),
                          ),
                          builder: (context) {
                            return SafeArea(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  ListTile(
                                    leading: const Icon(
                                      Icons.photo,
                                      color: primaryColor,
                                    ),
                                    title: const Text(
                                      "Photo from gallery",
                                      style: TextStyle(color: primaryColor),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _sendImage(ImageSource.gallery);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(
                                      Icons.videocam,
                                      color: primaryColor,
                                    ),
                                    title: const Text(
                                      "Video from gallery",
                                      style: TextStyle(color: primaryColor),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _sendVideo(ImageSource.gallery);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(
                                      Icons.photo_camera,
                                      color: primaryColor,
                                    ),
                                    title: const Text(
                                      "Take photo",
                                      style: TextStyle(color: primaryColor),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _sendImage(ImageSource.camera);
                                    },
                                  ),
                                  ListTile(
                                    leading: const Icon(
                                      Icons.videocam_outlined,
                                      color: primaryColor,
                                    ),
                                    title: const Text(
                                      "Record video",
                                      style: TextStyle(color: primaryColor),
                                    ),
                                    onTap: () {
                                      Navigator.pop(context);
                                      _sendVideo(ImageSource.camera);
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        );
                      },
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: InputDecoration(
                          hintText: "Message...",
                          filled: true,
                          fillColor: Colors.grey.shade200,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(24),
                            borderSide: BorderSide.none,
                          ),
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      icon: const Icon(Icons.send, color: blueColor),
                      onPressed: _sendMessage,
                    ),
                    IconButton(
                      icon: const Icon(Icons.mic, color: secondaryColor),
                      onPressed: _startRecording,
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MediaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isMe;

  const _MediaPill({
    required this.icon,
    required this.label,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white24 : Colors.black12,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: primaryColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioMessageBubble extends StatelessWidget {
  final bool isMe;
  final bool isPlaying;
  final String durationLabel;
  final VoidCallback? onTap;

  const _AudioMessageBubble({
    required this.isMe,
    required this.isPlaying,
    required this.durationLabel,
    this.onTap,
  });

  List<double> _barHeights() {
    return const [
      6,
      12,
      8,
      14,
      10,
      6,
      16,
      9,
      13,
      7,
      12,
      8,
      15,
      10,
      6,
      14,
      9,
      11,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final bars = _barHeights();
    final playColor = isMe ? Colors.black87 : Colors.black54;
    final barColor = isMe ? Colors.black54 : Colors.black45;
    return InkWell(
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: playColor,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isPlaying ? Icons.stop : Icons.play_arrow,
              color: Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 8),
          SizedBox(
            height: 18,
            child: Row(
              children: [
                for (final height in bars)
                  Container(
                    width: 3,
                    height: height,
                    margin: const EdgeInsets.symmetric(horizontal: 1),
                    decoration: BoxDecoration(
                      color: barColor,
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            durationLabel,
            style: const TextStyle(
              color: primaryColor,
              fontSize: 12,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _ShareCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String imageUrl;
  final bool isMe;

  const _ShareCard({
    required this.title,
    required this.subtitle,
    required this.imageUrl,
    required this.isMe,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: isMe ? Colors.white24 : Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (imageUrl.isNotEmpty)
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(
                imageUrl,
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              height: 120,
              decoration: BoxDecoration(
                color: Colors.black12,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Center(
                child: Icon(Icons.play_arrow, color: primaryColor, size: 32),
              ),
            ),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(
              color: primaryColor,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          if (subtitle.toString().isNotEmpty)
            Text(
              subtitle.toString().startsWith("@")
                  ? subtitle.toString()
                  : "@${subtitle.toString()}",
              style: TextStyle(
                color: secondaryColor,
                fontSize: 12,
              ),
            ),
        ],
      ),
    );
  }
}

class _VideoPreview extends StatefulWidget {
  final String url;
  final bool isMe;

  const _VideoPreview({
    required this.url,
    required this.isMe,
  });

  @override
  State<_VideoPreview> createState() => _VideoPreviewState();
}

class _VideoPreviewState extends State<_VideoPreview> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    _controller =
        VideoPlayerController.networkUrl(Uri.parse(widget.url))
          ..initialize().then((_) {
            if (mounted) {
              setState(() {});
            }
          });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final isReady = controller != null && controller.value.isInitialized;
    return GestureDetector(
      onTap: () {
        if (!isReady) return;
        if (controller.value.isPlaying) {
          controller.pause();
        } else {
          controller.play();
        }
        setState(() {});
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Container(
          width: 220,
          height: 200,
          color: Colors.black12,
          child:
              isReady
                  ? Stack(
                    alignment: Alignment.center,
                    children: [
                      AspectRatio(
                        aspectRatio: controller.value.aspectRatio,
                        child: VideoPlayer(controller),
                      ),
                      Icon(
                        controller.value.isPlaying
                            ? Icons.pause_circle_filled
                            : Icons.play_circle_filled,
                        color: Colors.white,
                        size: 42,
                      ),
                    ],
                  )
                  : const Center(
                    child: CircularProgressIndicator(color: primaryColor),
                  ),
        ),
      ),
    );
  }
}
