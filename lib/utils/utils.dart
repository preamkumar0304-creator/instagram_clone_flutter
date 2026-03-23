import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:permission_handler/permission_handler.dart';

Future<bool> ensureGalleryPermission({bool forVideo = false}) async {
  if (kIsWeb) return true;
  if (defaultTargetPlatform == TargetPlatform.iOS) {
    final status = await Permission.photos.request();
    return status.isGranted || status.isLimited;
  }
  if (defaultTargetPlatform == TargetPlatform.android) {
    final permissions = <Permission>[
      Permission.photos,
      if (forVideo) Permission.videos,
      Permission.storage,
    ];
    final statuses = await permissions.request();
    final photosGranted = statuses[Permission.photos]?.isGranted ?? false;
    final videosGranted = statuses[Permission.videos]?.isGranted ?? false;
    final storageGranted = statuses[Permission.storage]?.isGranted ?? false;
    return forVideo
        ? (videosGranted || photosGranted || storageGranted)
        : (photosGranted || storageGranted);
  }
  return true;
}

pickImage(ImageSource source) async {
  if (source == ImageSource.gallery) {
    final granted = await ensureGalleryPermission();
    if (!granted) return null;
  }
  final ImagePicker imagePicker = ImagePicker();
  XFile? file = await imagePicker.pickImage(source: source);
  if (file != null) {
    return await file.readAsBytes();
  }
}

void showSnackBar({
  required BuildContext context,
  required String content,
  Color clr = Colors.red,
}) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Center(
        child: Text(
          content,
          style: TextStyle(color: primaryColor, fontSize: 14),
        ),
      ),
      backgroundColor: clr,
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
  );
}
