import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../config/teleconsultation_feature_config.dart';
import '../controllers/tele_consultation_controller.dart';

class TeleConsultationSettingsSheet extends StatelessWidget {
  const TeleConsultationSettingsSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => const TeleConsultationSettingsSheet(),
    );
  }

  String? _valid(String? id, Iterable<String?> ids) =>
      ids.contains(id) ? id : null;

  Widget _label(String t) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: Text(
      t,
      style: const TextStyle(
        color: Colors.white70,
        fontSize: 13,
        fontWeight: FontWeight.w600,
      ),
    ),
  );

  Widget _dropdown({
    required String? value,
    required List<DropdownMenuItem<String>> items,
    required ValueChanged<String?> onChanged,
  }) => Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.symmetric(horizontal: 12),
    decoration: BoxDecoration(
      color: Colors.white.withValues(alpha: 0.05),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.white12),
    ),
    child: DropdownButton<String>(
      isExpanded: true,
      value: value,
      dropdownColor: const Color(0xFF2A3942),
      underline: const SizedBox.shrink(),
      style: const TextStyle(color: Colors.white, fontSize: 13),
      items: items,
      onChanged: onChanged,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final c = TeleConsultationController.instance;
    final f = c.features;

    return ListenableBuilder(
      listenable: c,
      builder: (context, _) {
        return Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(context).height * 0.85,
          ),
          padding: EdgeInsets.only(
            top: 16,
            left: 20,
            right: 20,
            bottom: MediaQuery.viewInsetsOf(context).bottom +
                MediaQuery.paddingOf(context).bottom +
                16,
          ),
          decoration: const BoxDecoration(
            color: Color(0xFF1F2C34),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(Icons.tune, color: Color(0xFF00A884), size: 20),
                    const SizedBox(width: 8),
                    const Expanded(
                      child: Text(
                        'Call Settings',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: const Icon(Icons.close, color: Colors.white70),
                    ),
                  ],
                ),
                const Divider(color: Colors.white12, height: 20),

                // Video Quality Selector (HD / Standard / Low)
                _label('Video Quality (Resolution & Bandwidth)'),
                _dropdown(
                  value: c.videoConfig.preset.name,
                  items: const [
                    DropdownMenuItem(
                      value: 'hd',
                      child: Text('HD 720p (Recommended for Doctor)'),
                    ),
                    DropdownMenuItem(
                      value: 'standard',
                      child: Text('Standard 540p (Balanced)'),
                    ),
                    DropdownMenuItem(
                      value: 'low',
                      child: Text('Data Saver 360p (Low Bandwidth)'),
                    ),
                  ],
                  onChanged: (v) {
                    if (v == 'low') {
                      c.setVideoQualityPreset(VideoQualityPreset.low);
                    } else if (v == 'standard') {
                      c.setVideoQualityPreset(VideoQualityPreset.standard);
                    } else if (v == 'hd') {
                      c.setVideoQualityPreset(VideoQualityPreset.hd);
                    }
                  },
                ),

                // Fit / Fill aspect ratio toggle
                if (f.fitFillToggle)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Fit Video (Prevent Cropping)',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: Text(
                      c.isFitMode
                          ? 'Showing full patient frame (letterboxed, no zooming)'
                          : 'Filling window (cropped)',
                      style: const TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    value: c.isFitMode,
                    activeThumbColor: const Color(0xFF00A884),
                    onChanged: (_) => c.toggleFitFill(),
                  ),

                // Device Selection on Web/Desktop
                if (f.deviceSelection && kIsWeb) ...[
                  if (c.videoDevices.isNotEmpty) ...[
                    _label('Camera Device'),
                    _dropdown(
                      value: _valid(
                        c.currentCameraId,
                        c.videoDevices.map((d) => d.deviceId),
                      ),
                      items: c.videoDevices
                          .where((d) => d.deviceId != null)
                          .map(
                            (d) => DropdownMenuItem<String>(
                              value: d.deviceId,
                              child: Text(
                                d.deviceName ?? 'Camera',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) c.setCamera(v);
                      },
                    ),
                  ],
                  if (c.audioDevices.isNotEmpty) ...[
                    _label('Microphone Device'),
                    _dropdown(
                      value: _valid(
                        c.currentMicrophoneId,
                        c.audioDevices.map((d) => d.deviceId),
                      ),
                      items: c.audioDevices
                          .where((d) => d.deviceId != null)
                          .map(
                            (d) => DropdownMenuItem<String>(
                              value: d.deviceId,
                              child: Text(
                                d.deviceName ?? 'Microphone',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) c.setMicrophone(v);
                      },
                    ),
                  ],
                  if (c.playbackDevices.isNotEmpty) ...[
                    _label('Audio Output / Speaker'),
                    _dropdown(
                      value: _valid(
                        c.currentPlaybackDeviceId,
                        c.playbackDevices.map((d) => d.deviceId),
                      ),
                      items: c.playbackDevices
                          .where((d) => d.deviceId != null)
                          .map(
                            (d) => DropdownMenuItem<String>(
                              value: d.deviceId,
                              child: Text(
                                d.deviceName ?? 'Speaker / Headphones',
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (v) {
                        if (v != null) c.setPlaybackDevice(v);
                      },
                    ),
                  ],
                ],

                // AI Noise Suppression (Native only)
                if (f.noiseSuppression && !kIsWeb)
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'AI Noise Suppression',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Reduces background fan/clinic noise and enhances voice',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    value: c.noiseSuppressionEnabled,
                    activeThumbColor: const Color(0xFF00A884),
                    onChanged: c.toggleNoiseSuppression,
                  ),

                // Touch up appearance (Native only)
                if (f.beautyFilter && !kIsWeb && c.hasCamera) ...[
                  const Divider(color: Colors.white12, height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Touch Up Appearance',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Skin smoothing and professional clinic lighting',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    value: c.beautyEnabled,
                    activeThumbColor: const Color(0xFF00A884),
                    onChanged: c.setBeautyEnabled,
                  ),
                  if (c.beautyEnabled) ...[
                    _slider('Smoothness', c.beautyLevel,
                        (v) => c.setBeautyLevels(smoothness: v)),
                    _slider('Brightness', c.brightnessLevel,
                        (v) => c.setBeautyLevels(brightness: v)),
                  ],
                ],

                // Call Diagnostics Overlay
                if (f.callStats) ...[
                  const Divider(color: Colors.white12, height: 20),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text(
                      'Show Call Diagnostics',
                      style: TextStyle(color: Colors.white, fontSize: 14),
                    ),
                    subtitle: const Text(
                      'Real-time bitrate, fps, resolution, and network quality',
                      style: TextStyle(color: Colors.white54, fontSize: 11),
                    ),
                    value: c.showStats,
                    activeThumbColor: const Color(0xFF00A884),
                    onChanged: (_) => c.toggleStats(),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _slider(String label, double value, ValueChanged<double> onChanged) {
    return Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ),
        Expanded(
          child: Slider(
            value: value,
            divisions: 10,
            activeColor: const Color(0xFF00A884),
            onChanged: onChanged,
          ),
        ),
      ],
    );
  }
}