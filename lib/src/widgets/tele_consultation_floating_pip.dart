import 'dart:math' as math;

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../controllers/tele_consultation_controller.dart';
import '../widgets/participant_avatar.dart';
import '../widgets/tele_consultation_video_slot.dart';

class TeleConsultationFloatingPip extends StatelessWidget {
  const TeleConsultationFloatingPip({super.key});

  static const double _w = 140;
  static const double _h = 200;

  @override
  Widget build(BuildContext context) {
    final c = TeleConsultationController.instance;

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        if (!c.isMinimized || c.engine == null) return const SizedBox.shrink();

        return ValueListenableBuilder<Offset>(
          valueListenable: c.pipPosition,
          builder: (context, pos, _) {
            final size = MediaQuery.sizeOf(context);
            final pad = MediaQuery.paddingOf(context);
            final minTop = pad.top + 8;
            final left = pos.dx.clamp(8.0, math.max(8.0, size.width - _w - 8));
            final top = pos.dy.clamp(
              minTop,
              math.max(minTop, size.height - _h - pad.bottom - 8),
            );

            return Positioned(
              left: left.toDouble(),
              top: top.toDouble(),
              child: GestureDetector(
                onPanUpdate: (d) => c.pipPosition.value = Offset(
                  left + d.delta.dx,
                  top + d.delta.dy,
                ),
                onPanEnd: (_) {
                  // snap to nearest side
                  final x = (left + _w / 2) < size.width / 2
                      ? 12.0
                      : size.width - _w - 12;
                  c.pipPosition.value = Offset(x, top.toDouble());
                },
                onTap: () => c.restoreFullScreen(context),
                child: Material(
                  color: Colors.transparent,
                  child: Container(
                    width: _w,
                    height: _h,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      color: Colors.black,
                      border: Border.all(color: Colors.white30, width: 2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.5),
                          blurRadius: 16,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Stack(
                        children: [
                          Positioned.fill(child: _video(c)),
                          Positioned.fill(
                            child: IgnorePointer(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    begin: Alignment.topCenter,
                                    end: Alignment.bottomCenter,
                                    colors: [
                                      Colors.black.withValues(alpha: 0.55),
                                      Colors.transparent,
                                      Colors.transparent,
                                      Colors.black.withValues(alpha: 0.75),
                                    ],
                                    stops: const [0, 0.25, 0.7, 1],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          // timer + expand
                          Positioned(
                            top: 6,
                            left: 6,
                            right: 6,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: Colors.black.withValues(alpha: 0.6),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: ValueListenableBuilder<int>(
                                    valueListenable: c.callDuration,
                                    builder: (_, s, _) => Text(
                                      c.status == CallStatus.connected
                                          ? c.formatDuration(s)
                                          : (c.status == CallStatus.reconnecting
                                                ? 'Reconnecting'
                                                : 'Waiting…'),
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ),
                                InkWell(
                                  onTap: () => c.restoreFullScreen(context),
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withValues(
                                        alpha: 0.6,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(
                                      Icons.fullscreen,
                                      color: Colors.white,
                                      size: 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          // bottom mini controls
                          Positioned(
                            bottom: 6,
                            left: 4,
                            right: 4,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                              children: [
                                _mini(
                                  c.isMuted ? Icons.mic_off : Icons.mic,
                                  c.isMuted ? Colors.white : Colors.white24,
                                  c.isMuted ? Colors.black : Colors.white,
                                  c.toggleMute,
                                ),
                                _mini(
                                  c.isVideoEnabled && c.hasCamera
                                      ? Icons.videocam
                                      : Icons.videocam_off,
                                  (!c.isVideoEnabled || !c.hasCamera)
                                      ? Colors.white
                                      : Colors.white24,
                                  (!c.isVideoEnabled || !c.hasCamera)
                                      ? Colors.black
                                      : Colors.white,
                                  c.hasCamera ? c.toggleVideo : () {},
                                ),
                                _mini(
                                  Icons.call_end,
                                  const Color(0xFFF15C6D),
                                  Colors.white,
                                  () => c.endCall(),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _mini(IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      customBorder: const CircleBorder(),
      child: Container(
        padding: const EdgeInsets.all(7),
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, color: fg, size: 14),
      ),
    );
  }

  Widget _video(TeleConsultationController c) {
    final engine = c.engine!;
    final eh = identityHashCode(engine);
    final showRemote = c.remoteUid != null && c.remoteVideoEnabled;
    final showLocal = !showRemote && c.hasCamera && c.isVideoEnabled;

    if (showRemote) {
      return IgnorePointer(
        child: TeleVideoSlot.remote(
          key: ValueKey('pip_remote_${c.remoteUid}_${c.localUid}_$eh'),
          engine: engine,
          remoteUid: c.remoteUid!,
          channelId: c.config?.channelId ?? '',
          localUid: c.localUid,
          renderMode: c.remoteRenderMode,
        ),
      );
    }
    if (showLocal) {
      return IgnorePointer(
        child: TeleVideoSlot.local(
          key: ValueKey('pip_local_$eh'),
          engine: engine,
          renderMode: RenderModeType.renderModeHidden,
        ),
      );
    }

    final name = c.config?.patientName ?? '';
    return Container(
      color: const Color(0xFF111B21),
      child: Center(
        child: ParticipantAvatar(
          name: name,
          size: 56,
          fontSize: 24,
        ),
      ),
    );
  }
}
