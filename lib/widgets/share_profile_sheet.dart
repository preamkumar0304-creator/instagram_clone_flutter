import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:qr_flutter/qr_flutter.dart';

class ShareProfileSheet extends StatelessWidget {
  final String profileUid;
  final String profileUsername;
  final String profilePhotoUrl;

  const ShareProfileSheet({
    super.key,
    required this.profileUid,
    required this.profileUsername,
    required this.profilePhotoUrl,
  });

  String _profileLink() {
    final handle =
        profileUsername.isNotEmpty ? profileUsername : profileUid;
    return "instagram_clone://profile/$handle";
  }

  @override
  Widget build(BuildContext context) {
    final handle =
        profileUsername.isNotEmpty ? "@$profileUsername" : "@user";
    final qrData = _profileLink();

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: const BoxDecoration(
          color: mobileBackgroundColor,
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.close, color: primaryColor),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const Spacer(),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(
                    border: Border.all(color: secondaryColor),
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: const Text(
                    "EMOJI",
                    style: TextStyle(
                      color: primaryColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 40),
              ],
            ),
            const SizedBox(height: 12),
            Stack(
              children: [
                Positioned.fill(
                  child: IgnorePointer(
                    child: Opacity(
                      opacity: 0.12,
                      child: Wrap(
                        alignment: WrapAlignment.center,
                        spacing: 26,
                        runSpacing: 26,
                        children: List.generate(
                          24,
                          (_) => const Icon(
                            Icons.emoji_emotions,
                            color: Colors.amber,
                            size: 42,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 24),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.08),
                          blurRadius: 18,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          alignment: Alignment.center,
                          children: [
                            QrImageView(
                              data: qrData,
                              size: 220,
                              foregroundColor: const Color(0xFFD67E10),
                            ),
                            Container(
                              width: 42,
                              height: 42,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(0xFFD67E10),
                                  width: 2,
                                ),
                              ),
                              child: const Icon(
                                Icons.camera_alt,
                                color: Color(0xFFD67E10),
                                size: 20,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          handle,
                          style: const TextStyle(
                            color: Color(0xFFD67E10),
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _ShareAction(
                  label: "Share profile",
                  icon: Icons.share,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Share coming soon."),
                        backgroundColor: secondaryColor,
                      ),
                    );
                  },
                ),
                _ShareAction(
                  label: "Copy link",
                  icon: Icons.link,
                  onTap: () async {
                    await Clipboard.setData(ClipboardData(text: qrData));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text("Profile link copied."),
                          backgroundColor: successColor,
                        ),
                      );
                    }
                  },
                ),
                _ShareAction(
                  label: "Download",
                  icon: Icons.download,
                  onTap: () {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Download coming soon."),
                        backgroundColor: secondaryColor,
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

class _ShareAction extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _ShareAction({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(24),
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: Colors.black12),
              color: Colors.white,
            ),
            child: Icon(icon, color: primaryColor),
          ),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: primaryColor, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
