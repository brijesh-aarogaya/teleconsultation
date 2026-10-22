import 'dart:async';
import 'dart:math' as math;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../controllers/tele_consultation_controller.dart';
import '../utils/web_fullscreen.dart';
import '../widgets/participant_avatar.dart';
import '../widgets/tele_consultation_clinical_panel.dart';
import '../widgets/tele_consultation_settings_sheet.dart';
import '../widgets/tele_consultation_stats_overlay.dart';
import '../widgets/tele_consultation_video_slot.dart';

enum _PipCorner { topLeft, topRight, bottomLeft, bottomRight }

/// Enhanced HMIS Teleconsultation Call View.
///
/// Features:
///  • Responsive desktop/web and mobile layout
///  • Desktop "Patient focus" layout preserving remote aspect ratio (no cropping)
///  • Desktop "Side-by-side" layout
///  • User Fit/Fill toggle (renderModeFit vs renderModeHidden)
///  • In-call Clinical Side Panel (desktop) & Bottom Sheet (mobile)
///  • Web Fullscreen API toggle via conditional import
///  • Single-center-state waiting & ringing UI (eliminating overlapping ghost avatars)
///  • Reusable ParticipantAvatar with non-Latin grapheme & long-name support
///  • Camera/mic unavailable warning banner with "Check devices" action
class TeleConsultationCallView extends StatefulWidget {
  const TeleConsultationCallView({super.key});

  @override
  State<TeleConsultationCallView> createState() =>
      _TeleConsultationCallViewState();
}

class _TeleConsultationCallViewState extends State<TeleConsultationCallView>
    with SingleTickerProviderStateMixin {
  final TeleConsultationController c = TeleConsultationController.instance;

  static const _bg = Color(0xFF0B141A);
  static const _panel = Color(0xFF1F2C34);

  bool _controlsVisible = true;
  Timer? _hideTimer;
  CallStatus _lastStatus = CallStatus.idle;

  bool _isSwapped = false;
  _PipCorner _pipCorner = _PipCorner.topRight;
  Offset? _dragPos;

  late final AnimationController _pulse;
  late final Animation<double> _pulseAnim;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
    _pulseAnim = Tween<double>(begin: 0.95, end: 1.08).animate(
      CurvedAnimation(parent: _pulse, curve: Curves.easeInOut),
    );
    c.addListener(_onController);
  }

  @override
  void dispose() {
    c.removeListener(_onController);
    _hideTimer?.cancel();
    _pulse.dispose();
    super.dispose();
  }

  void _onController() {
    if (!mounted) return;
    if (c.status != _lastStatus) {
      _lastStatus = c.status;
      if (c.status == CallStatus.connected) _restartHideTimer();
    }
  }

  // ------------------------------------------------------------- controls
  void _restartHideTimer() {
    _hideTimer?.cancel();
    if (!c.features.autoHideControls || c.status != CallStatus.connected) return;
    if (c.showSidePanel) return;
    _hideTimer = Timer(
      Duration(seconds: c.videoConfig.autoHideDelaySeconds),
      () {
        if (mounted) setState(() => _controlsVisible = false);
      },
    );
  }

  void _onUserHover() {
    if (!_controlsVisible) {
      setState(() => _controlsVisible = true);
    }
    _restartHideTimer();
  }

  void _toggleControls() {
    setState(() => _controlsVisible = !_controlsVisible);
    if (_controlsVisible) {
      _restartHideTimer();
    } else {
      _hideTimer?.cancel();
    }
  }

  void _onBack() {
    if (c.status == CallStatus.failed || c.engine == null) {
      c.endCall(context: context);
    } else if (c.features.floatingPip) {
      c.minimizeCall(context);
    } else {
      _confirmEndCall();
    }
  }

  String _patientName() {
    final raw = c.config?.patientName;
    if (raw == null || raw.trim().isEmpty) return 'Patient';
    return raw.trim();
  }

  double _adaptiveNameSize(String name) {
    if (name.length > 24) return 18;
    if (name.length > 16) return 20;
    return 24;
  }

  String _statusText() {
    switch (c.status) {
      case CallStatus.connecting:
        return 'Connecting…';
      case CallStatus.ringing:
        return 'Ringing… waiting for patient to join';
      case CallStatus.reconnecting:
        return 'Reconnecting…';
      case CallStatus.remoteLeft:
        return 'Patient left. Waiting to rejoin…';
      default:
        return '';
    }
  }

  // ----------------------------------------------------------------- build
  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: _bg,
        body: ListenableBuilder(
          listenable: c,
          builder: (context, _) {
            if (c.status == CallStatus.ended) return _buildEndedView();
            if (c.status == CallStatus.failed) return _buildErrorView();
            if (c.engine == null) return _buildConnectingView();
            return LayoutBuilder(builder: (context, box) => _buildCall(box));
          },
        ),
      ),
    );
  }

  Widget _buildCall(BoxConstraints box) {
    final size = box.biggest;
    final pad = MediaQuery.paddingOf(context);
    final isWide = size.width >= 768;
    final engine = c.engine!;
    final hasRemote = c.remoteUid != null;
    final localCamOn = c.hasCamera && c.isVideoEnabled;

    // =========================================================================
    // STATE MACHINE (EXTRA FIX):
    // 1. If no remote user has joined:
    //    a) If local camera is ON -> local camera preview full screen + small top chip.
    //       NO center avatar!
    //    b) If local camera is OFF/unavailable -> ONE opaque waiting screen with
    //       single ParticipantAvatar. Local camera-off placeholder is NOT rendered!
    // 2. If remote user joined -> connected call layout (patient focus / side-by-side).
    // =========================================================================

    if (!hasRemote) {
      return MouseRegion(
        onHover: (_) => _onUserHover(),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _toggleControls,
          child: Stack(
            fit: StackFit.expand,
            children: [
              if (localCamOn)
                Positioned.fill(
                  child: IgnorePointer(
                    child: TeleVideoSlot.local(
                      key: ValueKey('local_preview_${identityHashCode(engine)}'),
                      engine: engine,
                      renderMode: RenderModeType.renderModeHidden,
                    ),
                  ),
                )
              else
                Positioned.fill(child: _buildOpaqueWaitingView()),

              // Small status chip when camera is ON (avoids center avatar clash)
              if (localCamOn)
                Positioned(
                  top: pad.top + 76,
                  left: 16,
                  right: 16,
                  child: Center(
                    child: _chip(
                      Icons.ring_volume,
                      '${_patientName()} • ${_statusText()}',
                    ),
                  ),
                ),

              if (c.deviceWarningBanner != null)
                Positioned(
                  top: pad.top + 60,
                  left: 16,
                  right: 16,
                  child: _buildDeviceWarningBanner(),
                ),

              if (c.showStats && c.features.callStats)
                Positioned(
                  top: pad.top + 110,
                  left: 16,
                  child: const TeleConsultationStatsOverlay(),
                ),

              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: _buildHeader(isWide),
              ),

              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: _buildDock(isWide),
              ),
            ],
          ),
        ),
      );
    }

    // =========================================================================
    // CONNECTED STATE (both in channel)
    // =========================================================================

    Widget mainVideoArea;
    if (isWide && c.desktopLayout == TeleconsultationDesktopLayout.sideBySide) {
      mainVideoArea = _buildSideBySideLayout(engine);
    } else if (isWide) {
      mainVideoArea = _buildPatientFocusLayout(engine, size, pad);
    } else {
      mainVideoArea = _buildMobileLayout(engine, size, pad);
    }

    final showControls = _controlsVisible || c.status != CallStatus.connected;

    final videoArea = MouseRegion(
      onHover: (_) => _onUserHover(),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: Container(
          color: Colors.black,
          child: mainVideoArea,
        ),
      ),
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        Row(
          children: [
            Expanded(child: videoArea),
            if (isWide && c.showSidePanel &&
                (c.features.patientInfoPanel || c.features.consultationNotes))
              TeleConsultationClinicalPanel(
                onClose: () => c.toggleSidePanel(),
              ),
          ],
        ),

        // Remote muted indicator
        if (c.remoteAudioMuted)
          Positioned(
            top: pad.top + 74,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: Center(
                child: _chip(Icons.mic_off, '${_patientName()} is muted'),
              ),
            ),
          ),

        // Device warning banner
        if (c.deviceWarningBanner != null)
          Positioned(
            top: pad.top + 60,
            left: 16,
            right: 16,
            child: _buildDeviceWarningBanner(),
          ),

        // Diagnostics Overlay
        if (c.showStats && c.features.callStats)
          Positioned(
            top: pad.top + 84,
            left: 16,
            child: const TeleConsultationStatsOverlay(),
          ),

        // Header
        Positioned(
          top: 0,
          left: 0,
          right: (isWide && c.showSidePanel &&
                  (c.features.patientInfoPanel || c.features.consultationNotes))
              ? 360
              : 0,
          child: IgnorePointer(
            ignoring: !showControls,
            child: AnimatedOpacity(
              opacity: showControls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: _buildHeader(isWide),
            ),
          ),
        ),

        // Dock
        Positioned(
          bottom: 0,
          left: 0,
          right: (isWide && c.showSidePanel &&
                  (c.features.patientInfoPanel || c.features.consultationNotes))
              ? 360
              : 0,
          child: IgnorePointer(
            ignoring: !showControls,
            child: AnimatedOpacity(
              opacity: showControls ? 1 : 0,
              duration: const Duration(milliseconds: 200),
              child: _buildDock(isWide),
            ),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------- layouts
  Widget _buildPatientFocusLayout(RtcEngine engine, Size size, EdgeInsets pad) {
    final eh = identityHashCode(engine);
    final remoteUid = c.remoteUid!;
    final aspect = c.remoteAspectRatio;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: Container(
        color: Colors.black,
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Center letterbox area sized to patient aspect ratio
            Center(
              child: AspectRatio(
                aspectRatio: aspect,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _toggleControls,
                  child: Container(
                    color: Colors.black,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (c.remoteVideoEnabled)
                          IgnorePointer(
                            child: TeleVideoSlot.remote(
                              key: ValueKey('remote_${remoteUid}_${c.remoteRenderMode}_$eh'),
                              engine: engine,
                              remoteUid: remoteUid,
                              channelId: c.config?.channelId ?? '',
                              localUid: c.localUid,
                              renderMode: c.remoteRenderMode,
                            ),
                          )
                        else
                          _cameraOffPlaceholder(
                            name: _patientName(),
                            isLocal: false,
                            compact: false,
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Small self-view in top right
            Positioned(
              top: pad.top + 76,
              right: 20,
              width: 200,
              height: 120,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                child: _selfViewBox(engine, eh),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSideBySideLayout(RtcEngine engine) {
    final eh = identityHashCode(engine);
    final remoteUid = c.remoteUid!;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _toggleControls,
      child: Container(
        color: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 76),
        child: Row(
          children: [
            // Doctor View
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFF111B21),
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (c.hasCamera && c.isVideoEnabled)
                          IgnorePointer(
                            child: TeleVideoSlot.local(
                              key: ValueKey('sbs_local_$eh'),
                              engine: engine,
                              renderMode: RenderModeType.renderModeHidden,
                            ),
                          )
                        else
                          _cameraOffPlaceholder(
                            name: 'You',
                            isLocal: true,
                            compact: false,
                          ),
                        Positioned(
                          bottom: 8,
                          left: 12,
                          child: _chip(Icons.person, 'You (Doctor)'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 16),
            // Patient View
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: _toggleControls,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(16),
                    color: const Color(0xFF111B21),
                    border: Border.all(color: Colors.white24, width: 1.5),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(16),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        if (c.remoteVideoEnabled)
                          IgnorePointer(
                            child: TeleVideoSlot.remote(
                              key: ValueKey('sbs_remote_${remoteUid}_${c.remoteRenderMode}_$eh'),
                              engine: engine,
                              remoteUid: remoteUid,
                              channelId: c.config?.channelId ?? '',
                              localUid: c.localUid,
                              renderMode: c.remoteRenderMode,
                            ),
                          )
                        else
                          _cameraOffPlaceholder(
                            name: _patientName(),
                            isLocal: false,
                            compact: false,
                          ),
                        Positioned(
                          bottom: 8,
                          left: 12,
                          child: _chip(Icons.person, _patientName()),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileLayout(RtcEngine engine, Size size, EdgeInsets pad) {
    final swapped = _isSwapped;
    const pipSize = Size(112, 160);
    final full = Rect.fromLTWH(0, 0, size.width, size.height);
    final pipRect = _pipRect(size, pipSize, pad);

    final localLayer = _videoLayer(
      key: const ValueKey('local_layer'),
      engine: engine,
      isLocal: true,
      isBig: swapped,
      rect: swapped ? full : pipRect,
    );

    final remoteLayer = _videoLayer(
      key: const ValueKey('remote_layer'),
      engine: engine,
      isLocal: false,
      isBig: !swapped,
      rect: swapped ? pipRect : full,
    );

    return Stack(
      fit: StackFit.expand,
      children: [
        swapped ? localLayer : remoteLayer,
        swapped ? remoteLayer : localLayer,
      ],
    );
  }

  Widget _selfViewBox(RtcEngine engine, int eh) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white30, width: 1.5),
        boxShadow: const [
          BoxShadow(color: Colors.black54, blurRadius: 10, offset: Offset(0, 4)),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Stack(
          fit: StackFit.expand,
          children: [
            if (c.hasCamera && c.isVideoEnabled)
              IgnorePointer(
                child: TeleVideoSlot.local(
                  key: ValueKey('self_dock_$eh'),
                  engine: engine,
                  renderMode: RenderModeType.renderModeHidden,
                ),
              )
            else
              _cameraOffPlaceholder(
                name: 'You',
                isLocal: true,
                compact: true,
              ),
            if (c.isMuted)
              const Positioned(
                bottom: 6,
                left: 6,
                child: Icon(Icons.mic_off, color: Colors.redAccent, size: 16),
              ),
            Positioned(
              top: 6,
              right: 6,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: Colors.black54,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: const Text(
                  'You',
                  style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------ video layer
  Widget _videoLayer({
    required Key key,
    required RtcEngine engine,
    required bool isLocal,
    required bool isBig,
    required Rect rect,
  }) {
    final eh = identityHashCode(engine);
    final name = isLocal ? 'You' : _patientName();
    final videoOn = isLocal
        ? (c.hasCamera && c.isVideoEnabled)
        : c.remoteVideoEnabled;

    final Widget video = isLocal
        ? (c.hasCamera
            ? TeleVideoSlot.local(
                key: ValueKey('local_$eh'),
                engine: engine,
                renderMode: RenderModeType.renderModeHidden,
              )
            : const SizedBox.shrink())
        : TeleVideoSlot.remote(
            key: ValueKey('remote_${c.remoteUid}_${c.remoteRenderMode}_$eh'),
            engine: engine,
            remoteUid: c.remoteUid!,
            channelId: c.config?.channelId ?? '',
            localUid: c.localUid,
            renderMode: c.remoteRenderMode,
          );

    final content = Stack(
      fit: StackFit.expand,
      children: [
        IgnorePointer(child: video),
        if (!videoOn)
          _cameraOffPlaceholder(name: name, isLocal: isLocal, compact: !isBig),
        if (isLocal && c.isMuted && !isBig)
          const Positioned(
            bottom: 6,
            left: 6,
            child: Icon(Icons.mic_off, color: Colors.redAccent, size: 16),
          ),
      ],
    );

    final dragging = _dragPos != null;

    Widget child;
    if (isBig) {
      child = GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: _toggleControls,
        child: content,
      );
    } else {
      child = GestureDetector(
        onTap: () => setState(() => _isSwapped = !_isSwapped),
        onPanStart: (_) => setState(() => _dragPos = rect.topLeft),
        onPanUpdate: (d) {
          final size = MediaQuery.sizeOf(context);
          final p = (_dragPos ?? rect.topLeft) + d.delta;
          setState(() {
            _dragPos = Offset(
              p.dx.clamp(0.0, math.max(0.0, size.width - rect.width)),
              p.dy.clamp(0.0, math.max(0.0, size.height - rect.height)),
            );
          });
        },
        onPanEnd: (_) => _snapPip(rect),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            boxShadow: const [
              BoxShadow(color: Colors.black54, blurRadius: 12, offset: Offset(0, 4)),
            ],
          ),
          foregroundDecoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white24, width: 1.5),
          ),
          child: ClipRRect(borderRadius: BorderRadius.circular(16), child: content),
        ),
      );
    }

    return AnimatedPositioned(
      key: key,
      duration: (dragging && !isBig)
          ? Duration.zero
          : const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: child,
    );
  }

  // -------------------------------------------------------------- PiP math
  Offset _cornerOffset(_PipCorner corner, Size size, Size pip, EdgeInsets pad) {
    const m = 12.0;
    const left = m;
    final right = math.max(m, size.width - pip.width - m);
    final top = pad.top + 76;
    final bottom = math.max(top, size.height - pip.height - pad.bottom - 130);
    switch (corner) {
      case _PipCorner.topLeft:
        return Offset(left, top);
      case _PipCorner.topRight:
        return Offset(right, top);
      case _PipCorner.bottomLeft:
        return Offset(left, bottom);
      case _PipCorner.bottomRight:
        return Offset(right, bottom);
    }
  }

  Rect _pipRect(Size size, Size pip, EdgeInsets pad) {
    final o = _dragPos ?? _cornerOffset(_pipCorner, size, pip, pad);
    return Rect.fromLTWH(o.dx, o.dy, pip.width, pip.height);
  }

  void _snapPip(Rect current) {
    final size = MediaQuery.sizeOf(context);
    final pad = MediaQuery.paddingOf(context);
    final pip = current.size;
    final center = current.center;
    var best = _pipCorner;
    var bestDist = double.infinity;
    for (final corner in _PipCorner.values) {
      final o = _cornerOffset(corner, size, pip, pad);
      final d = (Rect.fromLTWH(o.dx, o.dy, pip.width, pip.height).center - center)
          .distanceSquared;
      if (d < bestDist) {
        bestDist = d;
        best = corner;
      }
    }
    setState(() {
      _pipCorner = best;
      _dragPos = null;
    });
  }

  // -------------------------------------------------------------- overlays & placeholders
  Widget _chip(IconData icon, String text) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
    decoration: BoxDecoration(
      color: Colors.black.withValues(alpha: 0.65),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white24, width: 0.8),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: Colors.white, size: 14),
        const SizedBox(width: 6),
        Text(text, style: const TextStyle(color: Colors.white, fontSize: 12)),
      ],
    ),
  );

  /// Single opaque waiting view when local camera is off / unavailable.
  /// Guarantees that only ONE center avatar is visible and never stacked over local placeholder!
  Widget _buildOpaqueWaitingView() {
    final patientName = _patientName();
    return Container(
      color: _bg,
      child: SafeArea(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ScaleTransition(
                scale: _pulseAnim,
                child: ParticipantAvatar(
                  name: patientName,
                  size: 110,
                  fontSize: 44,
                  borderWidth: 2,
                  borderColor: Colors.white38,
                ),
              ),
              const SizedBox(height: 22),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width * 0.8,
                ),
                child: Text(
                  patientName,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: _adaptiveNameSize(patientName),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _statusText(),
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _cameraOffPlaceholder({
    required String name,
    required bool isLocal,
    required bool compact,
  }) {
    return Container(
      color: const Color(0xFF111B21),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ParticipantAvatar(
              name: name,
              size: compact ? 44 : 96,
              fontSize: compact ? 18 : 40,
            ),
            if (!compact) ...[
              const SizedBox(height: 14),
              Text(
                isLocal
                    ? (c.hasCamera ? 'Your camera is off' : 'No camera available')
                    : '$name turned off camera',
                style: const TextStyle(color: Colors.white70, fontSize: 14),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceWarningBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF2C2214),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.amberAccent.withValues(alpha: 0.6)),
        boxShadow: const [
          BoxShadow(color: Colors.black45, blurRadius: 8, offset: Offset(0, 3)),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: Colors.amberAccent, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              c.deviceWarningBanner!,
              style: const TextStyle(color: Colors.white, fontSize: 12),
            ),
          ),
          const SizedBox(width: 8),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: const Color(0xFF00A884),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            ),
            onPressed: c.checkDevicesAndRejoin,
            child: const Text('Check devices',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
          ),
          IconButton(
            icon: const Icon(Icons.close, color: Colors.white60, size: 16),
            onPressed: c.dismissDeviceWarning,
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- header
  Widget _roundIcon(IconData icon, String tooltip, VoidCallback onTap,
      {bool active = false}) {
    return IconButton(
      tooltip: tooltip,
      onPressed: () {
        _restartHideTimer();
        onTap();
      },
      icon: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: active
              ? Colors.white.withValues(alpha: 0.9)
              : Colors.black.withValues(alpha: 0.35),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: active ? Colors.black : Colors.white, size: 20),
      ),
    );
  }

  Color _qualityColor(QualityType q) {
    switch (q) {
      case QualityType.qualityExcellent:
      case QualityType.qualityGood:
        return Colors.greenAccent;
      case QualityType.qualityPoor:
        return Colors.amberAccent;
      case QualityType.qualityBad:
      case QualityType.qualityVbad:
      case QualityType.qualityDown:
        return Colors.redAccent;
      default:
        return Colors.white54;
    }
  }

  Widget _buildHeader(bool isWide) {
    final patientName = _patientName();
    final f = c.features;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.paddingOf(context).top + 6,
        left: 8,
        right: 8,
        bottom: 14,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
        ),
      ),
      child: Row(
        children: [
          if (f.floatingPip)
            _roundIcon(Icons.keyboard_arrow_down, 'Minimize', () => c.minimizeCall(context)),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Tooltip(
                  message: patientName,
                  child: Text(
                    patientName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                ValueListenableBuilder<int>(
                  valueListenable: c.callDuration,
                  builder: (_, secs, _) {
                    final connected = c.status == CallStatus.connected;
                    final txt = connected
                        ? c.formatDuration(secs)
                        : (c.status == CallStatus.reconnecting
                              ? 'Reconnecting…'
                              : (c.status == CallStatus.remoteLeft
                                    ? 'Patient left'
                                    : (c.status == CallStatus.ringing
                                          ? 'Ringing…'
                                          : 'Connecting…')));
                    return Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (c.hasActiveCall)
                          Padding(
                            padding: const EdgeInsets.only(right: 5),
                            child: Icon(
                              Icons.signal_cellular_alt,
                              size: 13,
                              color: _qualityColor(c.localNetworkQuality),
                            ),
                          ),
                        Text(
                          txt,
                          style: TextStyle(
                            color: c.status == CallStatus.reconnecting
                                ? Colors.amberAccent
                                : Colors.white70,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),

          // Fit / Fill Toggle
          if (f.fitFillToggle && c.status == CallStatus.connected)
            _roundIcon(
              c.isFitMode ? Icons.fit_screen : Icons.fullscreen,
              c.isFitMode ? 'Fit mode (No crop)' : 'Fill mode (Cropped)',
              c.toggleFitFill,
              active: c.isFitMode,
            ),

          // Desktop Layout Toggle
          if (f.layoutToggle && isWide && c.status == CallStatus.connected)
            _roundIcon(
              c.desktopLayout == TeleconsultationDesktopLayout.patientFocus
                  ? Icons.view_sidebar_outlined
                  : Icons.view_column_outlined,
              c.desktopLayout == TeleconsultationDesktopLayout.patientFocus
                  ? 'Switch to Side-by-side'
                  : 'Switch to Patient focus',
              c.toggleDesktopLayout,
              active: c.desktopLayout == TeleconsultationDesktopLayout.sideBySide,
            ),

          // Clinical Panel Toggle on Desktop
          if (isWide && (f.patientInfoPanel || f.consultationNotes))
            _roundIcon(
              Icons.medical_information_outlined,
              c.showSidePanel ? 'Hide clinical panel' : 'Show clinical panel',
              c.toggleSidePanel,
              active: c.showSidePanel,
            ),

          // Web Fullscreen Toggle
          if (f.fullscreen && kIsWeb)
            _roundIcon(
              Icons.fullscreen,
              'Toggle browser fullscreen',
              WebFullscreen.toggleFullscreen,
            ),

          // Pop out to new tab (Web only)
          if (f.popOutNewTab && kIsWeb)
            _roundIcon(
              Icons.open_in_new,
              'Open in new tab',
              () => c.popOutToNewTab(context: context),
            ),

          // Call settings
          _roundIcon(
            Icons.tune,
            'Call settings',
            () => TeleConsultationSettingsSheet.show(context),
          ),
        ],
      ),
    );
  }

  // ------------------------------------------------------------------ dock
  Widget _dockButton({
    required IconData icon,
    required String tooltip,
    required VoidCallback? onTap,
    bool highlighted = false,
  }) {
    final enabled = onTap != null;
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: enabled
            ? () {
                _restartHideTimer();
                onTap();
              }
            : null,
        radius: 30,
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: highlighted
                  ? Colors.white
                  : Colors.white.withValues(alpha: 0.16),
            ),
            child: Icon(
              icon,
              size: 24,
              color: highlighted ? Colors.black87 : Colors.white,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDock(bool isWide) {
    final f = c.features;
    final canFlip = f.cameraFlip && c.hasCamera && (!kIsWeb || c.videoDevices.length > 1);

    return Container(
      padding: EdgeInsets.only(
        left: 16,
        right: 16,
        top: 24,
        bottom: MediaQuery.paddingOf(context).bottom + 14,
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [Colors.black.withValues(alpha: 0.75), Colors.transparent],
        ),
      ),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: isWide ? 520 : 420),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: _panel.withValues(alpha: 0.92),
            borderRadius: BorderRadius.circular(36),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              if (canFlip)
                _dockButton(
                  icon: Icons.cameraswitch_outlined,
                  tooltip: 'Flip camera',
                  onTap: c.switchCamera,
                ),
              _dockButton(
                icon: c.isVideoEnabled && c.hasCamera
                    ? Icons.videocam
                    : Icons.videocam_off,
                tooltip: c.isVideoEnabled ? 'Turn camera off' : 'Turn camera on',
                highlighted: !c.isVideoEnabled || !c.hasCamera,
                onTap: c.hasCamera ? c.toggleVideo : null,
              ),
              _dockButton(
                icon: c.isMuted ? Icons.mic_off : Icons.mic,
                tooltip: c.isMuted ? 'Unmute' : 'Mute',
                highlighted: c.isMuted,
                onTap: c.hasMicrophone ? c.toggleMute : null,
              ),
              if (!kIsWeb && f.speakerToggle)
                _dockButton(
                  icon: c.isSpeakerEnabled ? Icons.volume_up : Icons.hearing,
                  tooltip: c.isSpeakerEnabled ? 'Speaker on' : 'Earpiece',
                  highlighted: c.isSpeakerEnabled,
                  onTap: c.toggleSpeaker,
                )
              else if (f.screenShare && c.canScreenShare)
                _dockButton(
                  icon: c.isScreenSharing
                      ? Icons.stop_screen_share
                      : Icons.screen_share,
                  tooltip: c.isScreenSharing ? 'Stop sharing' : 'Share screen',
                  highlighted: c.isScreenSharing,
                  onTap: c.toggleScreenShare,
                ),
              if (!isWide && (f.patientInfoPanel || f.consultationNotes))
                _dockButton(
                  icon: Icons.medical_information_outlined,
                  tooltip: 'Clinical info',
                  onTap: () => TeleConsultationClinicalPanel.showBottomSheet(context),
                ),
              InkResponse(
                onTap: _confirmEndCall,
                radius: 34,
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(
                    color: Color(0xFFF15C6D),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.call_end, color: Colors.white, size: 28),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ------------------------------------------------------ connecting / error / ended
  Widget _buildConnectingView() {
    final patientName = _patientName();
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF111B21), Color(0xFF0B141A)],
        ),
      ),
      child: SafeArea(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnim,
              child: ParticipantAvatar(
                name: patientName,
                size: 100,
                fontSize: 40,
                borderWidth: 2,
              ),
            ),
            const SizedBox(height: 20),
            ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: MediaQuery.sizeOf(context).width * 0.8,
              ),
              child: Text(
                patientName,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: _adaptiveNameSize(patientName),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Starting secure consultation…',
              style: TextStyle(color: Colors.white60, fontSize: 14),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white54),
            ),
            const SizedBox(height: 36),
            TextButton(
              onPressed: () => c.endCall(context: context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorView() {
    return Container(
      width: double.infinity,
      color: _bg,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.redAccent.withValues(alpha: 0.15),
                    border: Border.all(color: Colors.redAccent, width: 2),
                  ),
                  child: const Icon(Icons.videocam_off_rounded,
                      color: Colors.redAccent, size: 44),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Unable to start call',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  c.errorMessage,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.white60, fontSize: 14, height: 1.5),
                ),
                const SizedBox(height: 28),
                Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.white70,
                        side: const BorderSide(color: Colors.white24),
                      ),
                      onPressed: () => c.endCall(context: context),
                      icon: const Icon(Icons.close, size: 18),
                      label: const Text('Close'),
                    ),
                    if (c.needsAppSettings)
                      ElevatedButton.icon(
                        onPressed: openAppSettings,
                        icon: const Icon(Icons.settings, size: 18),
                        label: const Text('Open settings'),
                      ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A884),
                        foregroundColor: Colors.white,
                      ),
                      onPressed: c.retry,
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: const Text('Retry'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEndedView() {
    return Container(
      width: double.infinity,
      color: _bg,
      child: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white.withValues(alpha: 0.1),
                    border: Border.all(color: Colors.white24, width: 2),
                  ),
                  child: const Icon(Icons.call_end,
                      color: Colors.white70, size: 44),
                ),
                const SizedBox(height: 22),
                const Text(
                  'Consultation ended',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ValueListenableBuilder<int>(
                  valueListenable: c.callDuration,
                  builder: (_, secs, _) => Text(
                    secs > 0
                        ? 'Call duration: ${c.formatDuration(secs)}'
                        : 'The consultation has concluded.',
                    style: const TextStyle(color: Colors.white60, fontSize: 14),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (c.features.prescriptionShortcut &&
                        c.clinicalDataProvider != null) ...[
                      ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blueAccent.shade700,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 12),
                        ),
                        onPressed: () {
                          c.clinicalDataProvider?.onPrescriptionRequested();
                          final nav = Navigator.maybeOf(context);
                          if (nav != null && nav.canPop()) nav.pop();
                        },
                        icon: const Icon(Icons.receipt_long, size: 18),
                        label: const Text('Add Prescription'),
                      ),
                      const SizedBox(width: 12),
                    ],
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A884),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 24, vertical: 12),
                      ),
                      onPressed: () {
                        final nav = Navigator.maybeOf(context);
                        if (nav != null && nav.canPop()) nav.pop();
                      },
                      icon: const Icon(Icons.check, size: 18),
                      label: const Text('Close'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _confirmEndCall() {
    if (!c.features.endCallConfirm) {
      c.endCall(context: context);
      return;
    }

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: _panel,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: const Text('End consultation?',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        content: const Text(
          'This will end the video consultation for both doctor and patient.',
          style: TextStyle(color: Colors.white70, fontSize: 13),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel', style: TextStyle(color: Colors.white60)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF15C6D),
              foregroundColor: Colors.white,
            ),
            onPressed: () {
              Navigator.pop(dialogContext);
              c.endCall(context: context);
            },
            child: const Text('End call'),
          ),
        ],
      ),
    );
  }
}