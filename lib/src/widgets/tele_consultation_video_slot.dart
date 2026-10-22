import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

/// Owns exactly one [VideoViewController] for its whole lifetime.
/// Give it a ValueKey that changes when the engine / remote uid / renderMode changes.
class TeleVideoSlot extends StatefulWidget {
  final RtcEngine engine;
  final int? remoteUid; // null => local camera
  final String channelId;
  final int localUid;
  final RenderModeType renderMode;

  const TeleVideoSlot.local({
    super.key,
    required this.engine,
    this.renderMode = RenderModeType.renderModeHidden,
  })  : remoteUid = null,
        channelId = '',
        localUid = 0;

  const TeleVideoSlot.remote({
    super.key,
    required this.engine,
    required int this.remoteUid,
    required this.channelId,
    required this.localUid,
    this.renderMode = RenderModeType.renderModeFit,
  });

  @override
  State<TeleVideoSlot> createState() => _TeleVideoSlotState();
}

class _TeleVideoSlotState extends State<TeleVideoSlot> {
  late VideoViewController _vc;

  @override
  void initState() {
    super.initState();
    _initController();
  }

  void _initController() {
    if (widget.remoteUid == null) {
      _vc = VideoViewController(
        rtcEngine: widget.engine,
        canvas: VideoCanvas(
          uid: 0,
          renderMode: widget.renderMode,
          sourceType: VideoSourceType.videoSourceCamera,
          setupMode: VideoViewSetupMode.videoViewSetupAdd,
        ),
        useFlutterTexture: false,
        useAndroidSurfaceView: false,
      );
    } else {
      _vc = VideoViewController.remote(
        rtcEngine: widget.engine,
        canvas: VideoCanvas(
          uid: widget.remoteUid!,
          renderMode: widget.renderMode,
          sourceType: VideoSourceType.videoSourceRemote,
          setupMode: VideoViewSetupMode.videoViewSetupAdd,
        ),
        connection: RtcConnection(
          channelId: widget.channelId,
          localUid: widget.localUid,
        ),
        useFlutterTexture: false,
        useAndroidSurfaceView: false,
      );
    }
  }

  @override
  void didUpdateWidget(TeleVideoSlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.renderMode != widget.renderMode ||
        oldWidget.remoteUid != widget.remoteUid ||
        oldWidget.localUid != widget.localUid) {
      _vc.dispose();
      _initController();
      setState(() {});
    }
  }

  @override
  void dispose() {
    _vc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
        child: AgoraVideoView(controller: _vc),
      );
}