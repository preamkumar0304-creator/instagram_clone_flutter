import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

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
          "text": text,
          "fromUid": widget.currentUid,
          "toUid": widget.otherUid,
          "createdAt": FieldValue.serverTimestamp(),
          "reactions": {},
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
                      .orderBy("createdAt", descending: false)
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
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final data = doc.data();
                    final text = (data["text"] ?? "").toString();
                    final imageUrl = (data["imageUrl"] ?? "").toString();
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
                                  ? blueColor.withOpacity(0.9)
                                  : Colors.grey.shade200,
                          borderRadius: BorderRadius.circular(16),
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
                              if (imageUrl.isNotEmpty)
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(12),
                                  child: Image.network(
                                    imageUrl,
                                    width: 200,
                                    height: 200,
                                    fit: BoxFit.cover,
                                  ),
                                )
                              else
                                Text(
                                  text,
                                  style: TextStyle(
                                    color: isMe ? Colors.white : primaryColor,
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
                                              color:
                                                  isMe
                                                      ? Colors.white12
                                                      : Colors.black12,
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
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
