import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';

class ProfilePhotoView extends StatelessWidget {
  final String photoUrl;

  const ProfilePhotoView({super.key, required this.photoUrl});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: mobileBackgroundColor,
      appBar: AppBar(
        backgroundColor: mobileBackgroundColor,
        iconTheme: const IconThemeData(color: primaryColor),
        title: const Text(
          "Profile photo",
          style: TextStyle(color: primaryColor),
        ),
      ),
      body: Center(
        child: photoUrl.isEmpty
            ? const Icon(Icons.person, color: primaryColor, size: 120)
            : InteractiveViewer(
              minScale: 0.8,
              maxScale: 3.0,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(
                  photoUrl,
                  fit: BoxFit.contain,
                  errorBuilder: (context, error, stackTrace) {
                    return const Icon(
                      Icons.person,
                      color: primaryColor,
                      size: 120,
                    );
                  },
                ),
              ),
            ),
      ),
    );
  }
}
