import 'dart:typed_data';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:instagram_clone_flutter_firebase/methods/storage_methods.dart';
import 'package:instagram_clone_flutter_firebase/models/users.dart';

class AuthMethods {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> _ensureUserDoc(User user) async {
    final userDoc = await _firestore.collection("users").doc(user.uid).get();
    if (userDoc.exists) return;

    final baseUsername = (user.email ?? "user").split("@").first;
    String uniqueUsername =
        baseUsername.trim().isEmpty ? "user" : baseUsername.trim();
    int counter = 1;
    while (true) {
      final usernameCheck =
          await _firestore
              .collection("users")
              .where("username", isEqualTo: uniqueUsername)
              .get();
      if (usernameCheck.docs.isEmpty) {
        break;
      }
      uniqueUsername = "$baseUsername$counter";
      counter++;
    }

    await _firestore.collection("users").doc(user.uid).set({
      "uid": user.uid,
      "email": user.email ?? "",
      "username": uniqueUsername,
      "bio": "",
      "photoUrl": "https://via.placeholder.com/150",
      "gender": "unspecified",
      "followers": [],
      "following": [],
      "savedPosts": [],
    });
  }

  Future<UserModel> getUserDetails() async {
    User currentUser = _auth.currentUser!;
    await _ensureUserDoc(currentUser);
    DocumentSnapshot snap =
        await _firestore.collection("users").doc(currentUser.uid).get();
    return UserModel.fromSnap(snap);
  }

  //LOG IN USING EMAIL AND PASSWORD
  Future<String> loginWithEmailAndPassword({
    required String email,
    required String password,
  }) async {
    String message = "";
    try {
      if (email.isNotEmpty && password.isNotEmpty) {
        await _auth.signInWithEmailAndPassword(
          email: email,
          password: password,
        );
        // Ensure a user document exists for this account
        final currentUser = _auth.currentUser;
        if (currentUser != null) {
          await _ensureUserDoc(currentUser);
        }
        message = "User Logged In Successfully!";
      } else {
        message = "Please enter all the fields.";
      }
    } on FirebaseAuthException catch (err) {
      switch (err.code) {
        case "invalid-email":
          message = "The email format is invalid.";
          break;
        case 'user-not-found':
          message = 'No user found for this email.';
          break;
        case 'invalid-credential':
          message = 'Incorrect password.';
          break;
        default:
          message = "An error occured. Please try again.";
      }
    }
    return message;
  }

  Future<String> signupWithEmailAndPassword({
    required String email,
    required String password,
    required String username,
    required String bio,
    required Uint8List? file,
    required String gender,
  }) async {
    String message = "";

    try {
      if (email.isEmpty || password.isEmpty || username.isEmpty) {
        return "Please fill out all the fields.";
      }

      // 🔹 Create Firebase user
      UserCredential userCred = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // 🔹 Check for existing username (after auth so rules allow read)
      String uniqueUsername = username.trim();
      int counter = 1;
      while (true) {
        final QuerySnapshot usernameCheck = await _firestore
            .collection("users")
            .where("username", isEqualTo: uniqueUsername)
            .get();

        if (usernameCheck.docs.isEmpty) {
          break;
        }
        uniqueUsername = "$username$counter";
        counter++;
      }

      // 🔹 Upload profile image
      String photoUrl = "";
      try {
        if (file != null && file.isNotEmpty) {
          photoUrl = await StorageMethods().uploadImageToStorage(
            "profilePics",
            file,
            false,
          );
        }
      } on FirebaseException catch (e) {
        // If Storage rules/App Check block upload, continue with placeholder
        if (e.code == "unauthorized" || e.code == "unauthenticated") {
          photoUrl = "";
        } else {
          rethrow;
        }
      }

      if (photoUrl.isEmpty) {
        photoUrl = "https://via.placeholder.com/150";
      }

      // 🔹 Create user model
      UserModel user = UserModel(
        uid: userCred.user!.uid,
        username: uniqueUsername,
        email: email,
        bio: bio,
        photoUrl: photoUrl,
        gender: gender.isEmpty ? "unspecified" : gender,
        followers: [],
        following: [],
        savedPosts: [],
      );

      // 🔹 Store in Firestore
      await _firestore
          .collection("users")
          .doc(userCred.user!.uid)
          .set(user.toMap());

      message =
          "Account created successfully! Your username is @$uniqueUsername";
    } on FirebaseAuthException catch (err) {
      switch (err.code) {
        case "invalid-email":
          message = "The email address is badly formatted.";
          break;
        case "weak-password":
          message =
              "Your password is too weak. Please use at least 6 characters.";
          break;
        case "email-already-in-use":
          message = "This email is already registered. Try logging in instead.";
          break;
        case "network-request-failed":
          message =
              "No internet connection. Please check your network and try again.";
          break;
        case "operation-not-allowed":
          message = "Email/password accounts are not enabled in Firebase.";
          break;
        default:
          message =
              "Something went wrong: ${err.message ?? "Please try again."}";
      }
    } catch (e) {
      message = "Unexpected error: ${e.toString()}";
    }

    return message;
  }

  // SIGN OUT USER
  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<String?> checkEmailAvailability(String email) async {
    final trimmedEmail = email.trim();
    if (trimmedEmail.isEmpty) {
      return "Please enter your email address.";
    }

    try {
      final existingUsers =
          await _firestore
              .collection("users")
              .where("email", isEqualTo: trimmedEmail)
              .limit(1)
              .get();
      if (existingUsers.docs.isNotEmpty) {
        return "This email already exists. Try logging in instead.";
      }
      return null;
    } on FirebaseException catch (err) {
      if (err.code == "permission-denied") {
        return "Unable to verify this email right now. Please try again.";
      }
      if (err.code == "unavailable") {
        return "No internet connection. Please check your network and try again.";
      }
      return "Unable to verify this email right now. Please try again.";
    } catch (err) {
      return "Unexpected error while checking email. Please try again.";
    }
  }
}
