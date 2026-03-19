import 'package:flutter_dotenv/flutter_dotenv.dart';

class AgoraConfig {
  static const String _dartAppId =
      String.fromEnvironment("AGORA_APP_ID", defaultValue: "");
  static const String _dartToken =
      String.fromEnvironment("AGORA_TEMP_TOKEN", defaultValue: "");
  static const String _dartUid =
      String.fromEnvironment("AGORA_UID", defaultValue: "");

  static String get appId {
    if (_dartAppId.trim().isNotEmpty) {
      return _dartAppId;
    }
    return dotenv.env["AGORA_APP_ID"] ?? "";
  }

  static String get tempToken {
    if (_dartToken.trim().isNotEmpty) {
      return _dartToken;
    }
    return dotenv.env["AGORA_TEMP_TOKEN"] ?? "";
  }

  static String? tokenOrNull() {
    final token = tempToken.trim();
    return token.isEmpty ? null : token;
  }

  static int? uidOrNull() {
    final raw = _dartUid.trim().isNotEmpty ? _dartUid : (dotenv.env["AGORA_UID"] ?? "");
    if (raw.trim().isEmpty) return null;
    final parsed = int.tryParse(raw.trim());
    return parsed;
  }
}
