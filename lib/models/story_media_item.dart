import 'dart:typed_data';

enum StoryMediaType { image, video }

class StoryMediaItem {
  final StoryMediaType type;
  final Uint8List? bytes;
  final String? path;

  const StoryMediaItem._({
    required this.type,
    this.bytes,
    this.path,
  });

  const StoryMediaItem.image(Uint8List bytes)
      : this._(type: StoryMediaType.image, bytes: bytes);

  const StoryMediaItem.video(String path)
      : this._(type: StoryMediaType.video, path: path);
}
