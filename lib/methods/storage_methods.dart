import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageMethods {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Future<String> uploadBytesToStorage(
    String childName,
    Uint8List file,
    bool isPost, {
    String? contentType,
  }) async {
    if (file.isEmpty) {
      throw FirebaseException(
        plugin: "firebase_storage",
        message: "Selected file is empty.",
      );
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseException(
        plugin: "firebase_auth",
        message: "You need to sign in before uploading.",
      );
    }

    Reference ref = _storage.ref().child(childName).child(user.uid);

    if (isPost) {
      String id = const Uuid().v1();
      ref = ref.child(id);
    }

    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final metadata =
            contentType == null ? null : SettableMetadata(contentType: contentType);
        UploadTask uploadTask = ref.putData(file, metadata);
        TaskSnapshot snap = await uploadTask;
        String downloadURL = await snap.ref.getDownloadURL();
        return downloadURL;
      } on FirebaseException catch (e) {
        final isCanceled = e.code == "canceled" || e.code == "cancelled";
        if (attempt < 2 && isCanceled) {
          await Future.delayed(const Duration(milliseconds: 300));
          continue;
        }
        rethrow;
      }
    }
    throw FirebaseException(
      plugin: "firebase_storage",
      message: "Upload failed after retries.",
    );
  }

  // ADDING IMAGE TO FIREBASE STORAGE
  Future<String> uploadImageToStorage(
    String childName,
    Uint8List file,
    bool isPost,
  ) async {
    return uploadBytesToStorage(
      childName,
      file,
      isPost,
      contentType: "image/jpeg",
    );
  }
}
