import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:instagram_clone_flutter_firebase/models/users.dart';
import 'package:instagram_clone_flutter_firebase/utils/agora_config.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';
import 'package:uuid/uuid.dart';

class LiveBroadcastScreen extends StatefulWidget {
  final UserModel user;
  final String? existingLiveId;
  final String? existingChannelId;
  final bool resume;

  const LiveBroadcastScreen({
    super.key,
    required this.user,
    this.existingLiveId,
    this.existingChannelId,
    this.resume = false,
  });

  @override
  State<LiveBroadcastScreen> createState() => _LiveBroadcastScreenState();
}

class _LiveBroadcastScreenState extends State<LiveBroadcastScreen> {
  RtcEngine? _engine;
  String? _liveId;
  String? _channelId;
  bool _joining = true;
  bool _ended = false;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _liveSub;
  int _viewerCount = 0;
  int _likeCount = 0;
  int _localUid = 0;
  Timer? _joinTimeout;
  String _lastAgoraError = "";
  String _localVideoStatus = "";
  bool _usedToken = false;
  bool _retriedWithoutToken = false;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startLive();
    });
  }

  @override
  void dispose() {
    _joinTimeout?.cancel();
    _liveSub?.cancel();
    _commentController.dispose();
    _releaseEngine();
    super.dispose();
  }

  Future<void> _releaseEngine() async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.leaveChannel();
      await engine.stopPreview();
      await engine.release();
    } catch (_) {}
    _engine = null;
  }

  Future<void> _startLive() async {
    final appId = AgoraConfig.appId.trim();
    if (appId.isEmpty) {
      if (mounted) {
        showSnackBar(
          context: context,
          content:
              "Set AGORA_APP_ID in assets/.env or build with --dart-define=AGORA_APP_ID=YOUR_ID to start live.",
          clr: errorColor,
        );
        Navigator.pop(context);
      }
      return;
    }

    final permissions = await [
      Permission.camera,
      Permission.microphone,
    ].request();

    if (permissions[Permission.camera] != PermissionStatus.granted ||
        permissions[Permission.microphone] != PermissionStatus.granted) {
      if (mounted) {
        showSnackBar(
          context: context,
          content: "Camera and microphone permissions are required.",
          clr: errorColor,
        );
        Navigator.pop(context);
      }
      return;
    }

    if (widget.resume &&
        widget.existingLiveId != null &&
        widget.existingChannelId != null) {
      _liveId = widget.existingLiveId;
      _channelId = widget.existingChannelId;
    } else {
      _liveId = const Uuid().v4();
      _channelId = _liveId;
      await _createLiveSession();
    }

    if (!mounted || _liveId == null || _channelId == null) return;

    await _initAgora(appId);
    _listenLiveDoc();
  }

  Future<void> _createLiveSession() async {
    final liveId = _liveId!;
    final now = FieldValue.serverTimestamp();
    await FirebaseFirestore.instance.collection("live_sessions").doc(liveId).set({
      "liveId": liveId,
      "channelId": _channelId,
      "hostUid": widget.user.uid,
      "hostUsername": widget.user.username,
      "hostPhotoUrl": widget.user.photoUrl,
      "startedAt": now,
      "endedAt": null,
      "isLive": true,
      "viewerCount": 0,
      "likeCount": 0,
    });
    await _notifyFollowers(liveId);
  }

  Future<void> _notifyFollowers(String liveId) async {
    final userSnap =
        await FirebaseFirestore.instance
            .collection("users")
            .doc(widget.user.uid)
            .get();
    final userData = userSnap.data() ?? {};
    final followers =
        (userData["followers"] as List?)?.whereType<String>().toList() ?? [];
    final blocked =
        (userData["blockedUsers"] as List?)?.whereType<String>().toList() ?? [];
    if (followers.isEmpty) return;
    const chunkSize = 400;
    for (var i = 0; i < followers.length; i += chunkSize) {
      final batch = FirebaseFirestore.instance.batch();
      final end = (i + chunkSize > followers.length)
          ? followers.length
          : i + chunkSize;
      for (var j = i; j < end; j++) {
        final followerUid = followers[j];
        if (followerUid == widget.user.uid) continue;
        if (blocked.contains(followerUid)) continue;
        final ref = FirebaseFirestore.instance
            .collection("users")
            .doc(followerUid)
            .collection("notifications")
            .doc(liveId);
        batch.set(ref, {
          "type": "live",
          "fromUid": widget.user.uid,
          "liveId": liveId,
          "createdAt": FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    }
  }

  Future<void> _initAgora(String appId) async {
    final engine = createAgoraRtcEngine();
    await engine.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );
    _engine = engine;
    if (mounted) {
      setState(() {});
    }
    await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (_, __) {
          if (!mounted) return;
          setState(() {
            _joining = false;
          });
        },
        onConnectionStateChanged: (connection, state, reason) {
          if (!mounted) return;
          if (reason ==
                  ConnectionChangedReasonType.connectionChangedInvalidAppId ||
              reason ==
                  ConnectionChangedReasonType.connectionChangedInvalidToken ||
              reason ==
                  ConnectionChangedReasonType.connectionChangedTokenExpired ||
              reason ==
                  ConnectionChangedReasonType.connectionChangedJoinFailed ||
              state == ConnectionStateType.connectionStateFailed) {
            if (_usedToken &&
                (reason ==
                        ConnectionChangedReasonType
                            .connectionChangedInvalidToken ||
                    reason ==
                        ConnectionChangedReasonType
                            .connectionChangedTokenExpired)) {
              if (!_retriedWithoutToken) {
                _retryJoinWithoutToken();
                showSnackBar(
                  context: context,
                  content:
                      "Invalid/expired token. Retrying without token. If App Certificate is enabled, set AGORA_TEMP_TOKEN.",
                  clr: secondaryColor,
                );
                return;
              }
              setState(() {
                _joining = false;
                _lastAgoraError = "Invalid/expired token.";
              });
              showSnackBar(
                context: context,
                content:
                    "Invalid/expired token. Set AGORA_TEMP_TOKEN and AGORA_UID.",
                clr: errorColor,
              );
              return;
            }
            setState(() {
              _joining = false;
              _lastAgoraError = "Connection failed: $reason";
            });
            showSnackBar(
              context: context,
              content:
                  "Live failed: $reason. Check AGORA_APP_ID / AGORA_TEMP_TOKEN.",
              clr: errorColor,
            );
          }
        },
        onError: (err, msg) {
          if (!mounted) return;
          setState(() {
            _lastAgoraError = "$err ${msg ?? ""}".trim();
            _joining = false;
          });
          showSnackBar(
            context: context,
            content: "Agora error: $err $msg",
            clr: errorColor,
          );
        },
        onLocalVideoStateChanged: (source, state, reason) {
          if (!mounted) return;
          setState(() {
            _localVideoStatus = "localVideo=$state reason=$reason";
          });
        },
      ),
    );

    await engine.setVideoEncoderConfiguration(
      const VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: 720, height: 1280),
        frameRate: 30,
        orientationMode: OrientationMode.orientationModeFixedPortrait,
      ),
    );
    await engine.setCameraCapturerConfiguration(
      const CameraCapturerConfiguration(
        cameraDirection: CameraDirection.cameraFront,
      ),
    );
    await engine.enableAudio();
    await engine.enableVideo();
    await engine.enableLocalVideo(true);
    await engine.enableLocalAudio(true);
    await engine.muteLocalAudioStream(false);
    await engine.muteLocalVideoStream(false);
    final token = AgoraConfig.tokenOrNull();
    final explicitUid = AgoraConfig.uidOrNull();
    _usedToken = token != null;
    _localUid = explicitUid ?? 0;
    if (token != null && explicitUid == null && mounted) {
      showSnackBar(
        context: context,
        content:
            "AGORA_TEMP_TOKEN set but AGORA_UID missing. If join fails, set AGORA_UID to match your token.",
        clr: secondaryColor,
      );
    }
    try {
      await engine.joinChannel(
        token: token ?? "",
        channelId: _channelId!,
        uid: _localUid,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
        ),
      );
    } catch (err) {
      if (mounted) {
        setState(() {
          _joining = false;
          _lastAgoraError = "Join failed: $err";
        });
      }
      showSnackBar(
        context: context,
        content: "Live join failed. Check AGORA_APP_ID / AGORA_TEMP_TOKEN.",
        clr: errorColor,
      );
      return;
    }
    await engine.enableLocalVideo(true);
    await engine.enableLocalAudio(true);
    await engine.startPreview();

    _joinTimeout?.cancel();
    _joinTimeout = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      if (_joining) {
        if (_usedToken && !_retriedWithoutToken) {
          _retryJoinWithoutToken();
          showSnackBar(
            context: context,
            content:
                "Retrying live without token. If App Certificate is enabled, set AGORA_TEMP_TOKEN.",
            clr: secondaryColor,
          );
          return;
        }
        showSnackBar(
          context: context,
          content:
              "Still connecting... Check AGORA_APP_ID / AGORA_TEMP_TOKEN and network.",
          clr: secondaryColor,
        );
        setState(() {
          _joining = false;
          _lastAgoraError = "Join timed out. Check Agora credentials/network.";
        });
      }
    });
  }

  Future<void> _retryJoinWithoutToken() async {
    if (_engine == null || _channelId == null || _retriedWithoutToken) return;
    _retriedWithoutToken = true;
    try {
      await _engine!.leaveChannel();
      await _engine!.joinChannel(
        token: "",
        channelId: _channelId!,
        uid: _localUid,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          publishCameraTrack: true,
          publishMicrophoneTrack: true,
        ),
      );
    } catch (_) {}
  }

  void _listenLiveDoc() {
    final liveId = _liveId;
    if (liveId == null) return;
    _liveSub = FirebaseFirestore.instance
        .collection("live_sessions")
        .doc(liveId)
        .snapshots()
        .listen((snap) {
      final data = snap.data();
      if (data == null) return;
      if (!mounted) return;
      final viewersRaw = data["viewerCount"];
      final likesRaw = data["likeCount"];
      setState(() {
        _viewerCount =
            viewersRaw is num ? viewersRaw.toInt() : 0;
        _likeCount =
            likesRaw is num ? likesRaw.toInt() : 0;
      });
    });
  }

  Future<void> _sendComment(String text) async {
    final liveId = _liveId;
    final trimmed = text.trim();
    if (liveId == null || trimmed.isEmpty) return;
    await FirebaseFirestore.instance
        .collection("live_sessions")
        .doc(liveId)
        .collection("comments")
        .add({
      "text": trimmed,
      "username": widget.user.username,
      "photoUrl": widget.user.photoUrl,
      "createdAt": FieldValue.serverTimestamp(),
    });
  }

  Future<void> _endLive() async {
    if (_ended) return;
    _ended = true;
    final liveId = _liveId;
    if (liveId != null) {
      await FirebaseFirestore.instance.collection("live_sessions").doc(liveId).update({
        "isLive": false,
        "endedAt": FieldValue.serverTimestamp(),
      });
    }
    await _releaseEngine();
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    final engine = _engine;
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: const Text(
          "Live",
          style: TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: _endLive,
            child: const Text(
              "End",
              style: TextStyle(color: Colors.redAccent, fontSize: 16),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child:
                engine == null
                    ? const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    )
                    : AgoraVideoView(
                      controller: VideoViewController(
                        rtcEngine: engine,
                        canvas: VideoCanvas(
                          uid: _localUid,
                          renderMode: RenderModeType.renderModeHidden,
                          mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
                        ),
                        useAndroidSurfaceView: false,
                      ),
                    ),
          ),
          Positioned(
            top: 16,
            left: 16,
            child: Row(
              children: [
                CircleAvatar(
                  radius: 18,
                  backgroundImage:
                      widget.user.photoUrl.isNotEmpty
                          ? NetworkImage(widget.user.photoUrl)
                          : null,
                  backgroundColor: Colors.grey.shade800,
                  child:
                      widget.user.photoUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                ),
                const SizedBox(width: 8),
                Text(
                  widget.user.username,
                  style: const TextStyle(color: Colors.white),
                ),
                const SizedBox(width: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text(
                    "LIVE",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Positioned(
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.visibility_outlined,
                      color: Colors.white, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _viewerCount.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 330,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(20),
              ),
              child: Row(
                children: [
                  const Icon(Icons.favorite,
                      color: Colors.pinkAccent, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    _likeCount.toString(),
                    style: const TextStyle(color: Colors.white),
                  ),
                ],
              ),
            ),
          ),
          if (_joining)
            const Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "Starting live...",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
          if (_lastAgoraError.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 120,
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _lastAgoraError,
                  style: const TextStyle(color: Colors.white70, fontSize: 12),
                ),
              ),
            ),
          if (_localVideoStatus.isNotEmpty)
            Positioned(
              left: 16,
              right: 16,
              bottom: 90,
              child: Text(
                _localVideoStatus,
                style: const TextStyle(color: Colors.white38, fontSize: 11),
              ),
            ),
          if (_liveId != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 110,
              child: SizedBox(
                height: 200,
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream:
                      FirebaseFirestore.instance
                          .collection("live_sessions")
                          .doc(_liveId)
                          .collection("comments")
                          .orderBy("createdAt", descending: true)
                          .snapshots(),
                  builder: (context, snapshot) {
                    final docs = snapshot.data?.docs ?? [];
                    if (docs.isEmpty) {
                      return const SizedBox.shrink();
                    }
                    return ListView.builder(
                      reverse: true,
                      itemCount: docs.length,
                      itemBuilder: (context, index) {
                        final data = docs[index].data();
                        final username = (data["username"] ?? "").toString();
                        final text = (data["text"] ?? "").toString();
                        final photoUrl = (data["photoUrl"] ?? "").toString();
                        if (text.isEmpty) return const SizedBox.shrink();
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              CircleAvatar(
                                radius: 12,
                                backgroundImage:
                                    photoUrl.isNotEmpty
                                        ? NetworkImage(photoUrl)
                                        : null,
                                backgroundColor: Colors.grey.shade800,
                                child:
                                    photoUrl.isEmpty
                                        ? const Icon(
                                          Icons.person,
                                          size: 12,
                                          color: Colors.white,
                                        )
                                        : null,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  username.isEmpty
                                      ? text
                                      : "$username: $text",
                                  style: const TextStyle(color: Colors.white),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          Positioned(
            left: 12,
            right: 12,
            bottom: 24,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _commentController,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      hintText: "Add a comment...",
                      hintStyle: const TextStyle(color: Colors.white54),
                      filled: true,
                      fillColor: Colors.black54,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(30),
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
                CircleAvatar(
                  radius: 20,
                  backgroundColor: Colors.white,
                  child: IconButton(
                    icon: const Icon(Icons.send, color: Colors.black),
                    onPressed: () async {
                      final text = _commentController.text;
                      _commentController.clear();
                      await _sendComment(text);
                    },
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
