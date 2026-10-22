import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/material.dart';

import '../controllers/tele_consultation_controller.dart';

/// Diagnostic overlay widget displaying real-time video resolution, fps, bitrate,
/// and network quality for both local doctor and remote patient.
class TeleConsultationStatsOverlay extends StatelessWidget {
  const TeleConsultationStatsOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    final c = TeleConsultationController.instance;

    return Material(
      color: Colors.transparent,
      child: Container(
        width: 280,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.85),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.5),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ValueListenableBuilder<CallStats>(
          valueListenable: c.stats,
          builder: (context, s, _) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.analytics_outlined, color: Color(0xFF00A884), size: 16),
                      SizedBox(width: 6),
                      Text(
                        'Call Diagnostics',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  InkWell(
                    onTap: c.toggleStats,
                    child: const Icon(
                      Icons.close,
                      color: Colors.white70,
                      size: 16,
                    ),
                  ),
                ],
              ),
              const Divider(color: Colors.white24, height: 14),

              // Remote video resolution & metrics
              _row(
                Icons.person_outline,
                'Patient Video',
                s.remoteWidth > 0
                    ? '${s.remoteWidth}×${s.remoteHeight} @ ${s.remoteFps}fps (${s.remoteVideoKbps} kbps)'
                    : 'Waiting for stream…',
              ),

              // Local video resolution & metrics
              _row(
                Icons.videocam_outlined,
                'Doctor Video',
                s.localWidth > 0
                    ? '${s.localWidth}×${s.localHeight} @ ${s.localFps}fps (${s.localVideoKbps} kbps)'
                    : 'Camera off / inactive',
              ),

              // Audio bitrates
              _row(
                Icons.mic_none,
                'Audio Bitrate',
                '↑ ${s.localAudioKbps} | ↓ ${s.remoteAudioKbps} kbps',
              ),

              // Aspect ratio & layout info
              _row(
                Icons.aspect_ratio,
                'Aspect Ratio',
                '${c.remoteAspectRatio.toStringAsFixed(2)}:1 (${c.isRemotePortrait ? 'Portrait' : 'Landscape'})',
              ),

              const SizedBox(height: 8),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  _badge('You', c.localNetworkQuality),
                  _badge('Patient', c.remoteNetworkQuality),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _row(IconData icon, String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 3),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 14, color: Colors.white60),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: const TextStyle(color: Colors.white60, fontSize: 11),
        ),
        Expanded(
          child: Text(
            value,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );

  Widget _badge(String label, QualityType q) {
    Color color;
    String text;
    switch (q) {
      case QualityType.qualityExcellent:
      case QualityType.qualityGood:
        color = Colors.greenAccent;
        text = 'Good';
        break;
      case QualityType.qualityPoor:
        color = Colors.amberAccent;
        text = 'Fair';
        break;
      case QualityType.qualityBad:
      case QualityType.qualityVbad:
      case QualityType.qualityDown:
        color = Colors.redAccent;
        text = 'Poor';
        break;
      default:
        color = Colors.grey;
        text = '…';
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        '$label: $text',
        style: TextStyle(
          color: color,
          fontSize: 10,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}