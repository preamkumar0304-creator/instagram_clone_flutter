import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:instagram_clone_flutter_firebase/utils/agora_config.dart';
import 'package:instagram_clone_flutter_firebase/utils/colors.dart';
import 'package:instagram_clone_flutter_firebase/utils/utils.dart';

class LiveViewerScreen extends StatefulWidget {
  final String liveId;

  const LiveViewerScreen({super.key, required this.liveId});

  @override
  State<LiveViewerScreen> createState() => _LiveViewerScreenState();
}

class _LiveViewerScreenState extends State<LiveViewerScreen> {
  RtcEngine? _engine;
  String _channelId = "";
  int? _remoteUid;
  int _viewerCount = 0;
  int _likeCount = 0;
  String _hostUsername = "";
  String _hostPhotoUrl = "";
  bool _isLive = true;
  bool _initializing = true;
  int _localUid = 0;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _liveSub;
  Timer? _joinTimeout;
  bool _usedToken = false;
  bool _retriedWithoutToken = false;

  @override
  void initState() {
    super.initState();
    _listenLiveDoc();
  }

  @override
  void dispose() {
    _joinTimeout?.cancel();
    _liveSub?.cancel();
    _leaveViewerPresence();
    _releaseEngine();
    super.dispose();
  }

  Future<void> _releaseEngine() async {
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.leaveChannel();
      await engine.release();
    } catch (_) {}
    _engine = null;
  }

  void _listenLiveDoc() {
    _liveSub = FirebaseFirestore.instance
        .collection("live_sessions")
        .doc(widget.liveId)
        .snapshots()
        .listen((snap) async {
      final data = snap.data();
      if (data == null) {
        _endWithMessage("Live ended.");
        return;
      }
      final isLive = data["isLive"] == true;
      if (!isLive) {
        _endWithMessage("Live ended.");
        return;
      }

      final viewersRaw = data["viewerCount"];
      final likesRaw = data["likeCount"];
      setState(() {
        _isLive = true;
        _viewerCount = viewersRaw is num ? viewersRaw.toInt() : 0;
        _likeCount = likesRaw is num ? likesRaw.toInt() : 0;
        _hostUsername = (data["hostUsername"] ?? "").toString();
        _hostPhotoUrl = (data["hostPhotoUrl"] ?? "").toString();
      });

      final channelIdRaw = (data["channelId"] ?? "").toString();
      final channelId = channelIdRaw.isNotEmpty ? channelIdRaw : widget.liveId;
      if (channelId.isEmpty) return;
      if (_channelId.isEmpty) {
        _channelId = channelId;
        await _joinAgora();
        await _joinViewerPresence();
      }
    });
  }

  Future<void> _joinAgora() async {
    final appId = AgoraConfig.appId.trim();
    if (appId.isEmpty) {
      if (mounted) {
        showSnackBar(
          context: context,
          content:
              "Set AGORA_APP_ID in assets/.env or build with --dart-define=AGORA_APP_ID=YOUR_ID to watch live.",
          clr: errorColor,
        );
        Navigator.pop(context);
      }
      return;
    }

    final engine = createAgoraRtcEngine();
    await engine.initialize(
      RtcEngineContext(
        appId: appId,
        channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
      ),
    );
    await engine.setClientRole(role: ClientRoleType.clientRoleAudience);
    engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (_, __) {
          if (!mounted) return;
          setState(() {
            _initializing = false;
          });
        },
        onError: (err, msg) {
          if (!mounted) return;
          setState(() {
            _initializing = false;
          });
          showSnackBar(
            context: context,
            content: "Agora error: $err ${msg ?? ""}".trim(),
            clr: errorColor,
          );
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
                _initializing = false;
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
              _initializing = false;
            });
            showSnackBar(
              context: context,
              content:
                  "Live failed: $reason. Check AGORA_APP_ID / AGORA_TEMP_TOKEN.",
              clr: errorColor,
            );
          }
        },
        onUserJoined: (_, remoteUid, __) {
          if (!mounted) return;
          setState(() {
            _remoteUid = remoteUid;
          });
        },
        onUserOffline: (_, remoteUid, __) {
          if (!mounted) return;
          if (_remoteUid == remoteUid) {
            setState(() {
              _remoteUid = null;
            });
          }
        },
        onRemoteVideoStateChanged: (_, remoteUid, state, __, ___) {
          if (!mounted) return;
          if (_remoteUid == null &&
              (state == RemoteVideoState.remoteVideoStateStarting ||
                  state == RemoteVideoState.remoteVideoStateDecoding)) {
            setState(() {
              _remoteUid = remoteUid;
            });
          }
        },
      ),
    );
    await engine.enableAudio();
    await engine.enableVideo();
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
        channelId: _channelId,
        uid: _localUid,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleAudience,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
    } catch (err) {
      if (mounted) {
        setState(() {
          _initializing = false;
        });
      }
      showSnackBar(
        context: context,
        content: "Live join failed. Check AGORA_APP_ID / AGORA_TEMP_TOKEN.",
        clr: errorColor,
      );
      return;
    }
    _engine = engine;

    _joinTimeout?.cancel();
    _joinTimeout = Timer(const Duration(seconds: 8), () {
      if (!mounted) return;
      if (_initializing) {
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
          _initializing = false;
        });
      }
    });
  }

  Future<void> _retryJoinWithoutToken() async {
    if (_engine == null || _channelId.isEmpty || _retriedWithoutToken) return;
    _retriedWithoutToken = true;
    try {
      await _engine!.leaveChannel();
      await _engine!.joinChannel(
        token: "",
        channelId: _channelId,
        uid: _localUid,
        options: ChannelMediaOptions(
          channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
          clientRoleType: ClientRoleType.clientRoleAudience,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
        ),
      );
    } catch (_) {}
  }

  Future<void> _joinViewerPresence() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final liveRef =
        FirebaseFirestore.instance.collection("live_sessions").doc(widget.liveId);
    final viewerRef = liveRef.collection("viewers").doc(uid);
    await FirebaseFirestore.instance.runTransaction((tx) async {
      final viewerSnap = await tx.get(viewerRef);
      if (!viewerSnap.exists) {
        tx.set(viewerRef, {"uid": uid, "joinedAt": FieldValue.serverTimestamp()});
        tx.update(liveRef, {"viewerCount": FieldValue.increment(1)});
      }
    });
  }

  Future<void> _leaveViewerPresence() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    final liveRef =
        FirebaseFirestore.instance.collection("live_sessions").doc(widget.liveId);
    final viewerRef = liveRef.collection("viewers").doc(uid);
    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        final viewerSnap = await tx.get(viewerRef);
        if (viewerSnap.exists) {
          tx.delete(viewerRef);
          tx.update(liveRef, {"viewerCount": FieldValue.increment(-1)});
        }
      });
    } catch (_) {}
  }

  Future<void> _sendLike() async {
    await FirebaseFirestore.instance
        .collection("live_sessions")
        .doc(widget.liveId)
        .update({"likeCount": FieldValue.increment(1)});
  }

  void _endWithMessage(String message) {
    if (!_isLive) return;
    _isLive = false;
    if (mounted) {
      showSnackBar(context: context, content: message, clr: secondaryColor);
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
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child:
                engine == null || _remoteUid == null
                    ? const Center(
                      child: Text(
                        "Waiting for host...",
                        style: TextStyle(color: Colors.white70),
                      ),
                    )
                    : AgoraVideoView(
                      controller: VideoViewController.remote(
                        rtcEngine: engine,
                        canvas: VideoCanvas(
                          uid: _remoteUid,
                          renderMode: RenderModeType.renderModeHidden,
                          mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
                        ),
                        connection: RtcConnection(channelId: _channelId),
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
                      _hostPhotoUrl.isNotEmpty
                          ? NetworkImage(_hostPhotoUrl)
                          : null,
                  backgroundColor: Colors.grey.shade800,
                  child:
                      _hostPhotoUrl.isEmpty
                          ? const Icon(Icons.person, color: Colors.white)
                          : null,
                ),
                const SizedBox(width: 8),
                Text(
                  _hostUsername.isEmpty ? "Host" : _hostUsername,
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
            bottom: 24,
            right: 16,
            child: Column(
              children: [
                FloatingActionButton(
                  backgroundColor: Colors.black,
                  onPressed: _sendLike,
                  child: const Icon(Icons.favorite, color: Colors.pinkAccent),
                ),
                const SizedBox(height: 8),
                Text(
                  _likeCount.toString(),
                  style: const TextStyle(color: Colors.white),
                ),
              ],
            ),
          ),
          if (_initializing)
            const Positioned(
              bottom: 80,
              left: 0,
              right: 0,
              child: Center(
                child: Text(
                  "Joining live...",
                  style: TextStyle(color: Colors.white70),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
