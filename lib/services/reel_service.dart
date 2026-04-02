import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:instagram_clone_flutter_firebase/methods/storage_methods.dart';
import 'package:uuid/uuid.dart';
import 'package:video_thumbnail/video_thumbnail.dart';

class ReelService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<String> uploadReel({
    required File videoFile,
    required String uid,
    required String username,
    required String profileUrl,
  }) async {
    String message = "";
    try {
      if (!await videoFile.exists()) {
        return "Video file is missing.";
      }
      final length = await videoFile.length();
      if (length <= 0) {
        return "Video file is empty.";
      }
      final reelId = const Uuid().v1();
      final reelUrl = await StorageMethods().uploadFileToStorage(
        "reels",
        videoFile,
        true,
        contentType: "video/mp4",
        fileName: reelId,
      );

      String thumbnailUrl = "";
      try {
        final thumbBytes = await VideoThumbnail.thumbnailData(
          video: videoFile.path,
          imageFormat: ImageFormat.JPEG,
          maxWidth: 720,
          quality: 75,
          timeMs: 1000,
        );
        if (thumbBytes != null && thumbBytes.isNotEmpty) {
          thumbnailUrl = await StorageMethods().uploadBytesToStorage(
            "reels_thumbs",
            thumbBytes,
            true,
            contentType: "image/jpeg",
            fileName: "${reelId}_thumb",
          );
        }
      } catch (_) {}

      final coverUrl = thumbnailUrl.isNotEmpty ? thumbnailUrl : "";
      final now = DateTime.now();
      await _firestore.collection("reels").doc(reelId).set({
        "reelId": reelId,
        "uid": uid,
        "username": username,
        "photoUrl": profileUrl,
        "reelUrl": reelUrl,
        "videoUrl": reelUrl,
        "userId": uid,
        "title": "Reel",
        "thumbnailUrl": thumbnailUrl,
        "coverUrl": coverUrl,
        "createdAt": now,
        "timestamp": now,
      });
      message = "Reel added.";
    } on FirebaseException catch (err) {
      if (err.code == "canceled" || err.code == "cancelled") {
        message = "Upload was canceled. Please keep the app open and try again.";
      } else if (err.code == "unauthorized") {
        message = "Upload is blocked by Firebase Storage rules.";
      } else if (err.code == "network-request-failed") {
        message = "Network issue while uploading. Please try again.";
      } else {
        message = err.message ?? err.toString();
      }
    } catch (e) {
      message = e.toString();
    }
    return message;
  }
}
