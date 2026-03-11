import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:uuid/uuid.dart';

class StorageMethods {
  final FirebaseStorage _storage = FirebaseStorage.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // ADDING IMAGE TO FIREBASE STORAGE
  Future<String> uploadImageToStorage(
    String childName,
    Uint8List file,
    bool isPost,
  ) async {
    if (file.isEmpty) {
      throw FirebaseException(
        plugin: "firebase_storage",
        message: "Selected image is empty.",
      );
    }

    final user = _auth.currentUser;
    if (user == null) {
      throw FirebaseException(
        plugin: "firebase_auth",
        message: "You need to sign in before uploading.",
      );
    }

    Reference ref = _storage
        .ref()
        .child(childName)
        .child(user.uid);

    if (isPost) {
      String id = const Uuid().v1();
      ref = ref.child(id);
    }

    try {
      UploadTask uploadTask = ref.putData(file);
      TaskSnapshot snap = await uploadTask;
      String downloadURL = await snap.ref.getDownloadURL();
      return downloadURL;
    } on FirebaseException catch (e) {
      // Retry once for intermittent task cancellations from platform/network.
      if (e.code == "canceled") {
        UploadTask retryTask = ref.putData(file);
        TaskSnapshot retrySnap = await retryTask;
        String downloadURL = await retrySnap.ref.getDownloadURL();
        return downloadURL;
      }
      rethrow;
    }
  }
}
