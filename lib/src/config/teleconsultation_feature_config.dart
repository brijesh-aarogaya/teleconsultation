import 'package:flutter/material.dart';

/// Available video quality presets for teleconsultation.
enum VideoQualityPreset {
  low, // 360p @ 15fps ~400kbps (Data Saver)
  standard, // 540p @ 24fps ~1000kbps (Balanced)
  hd, // 720p @ 30fps ~1800kbps (High Clarity)
}

/// Central feature-flag configuration for HMIS Teleconsultation.
///
/// Immutable single source of truth that governs which capabilities are
/// enabled in the UI and enforced in the [TeleConsultationController].
///
/// Can be loaded dynamically from backend JSON / remote config per hospital,
/// per doctor/patient role, or per consultation type.
@immutable
class TeleconsultationFeatures {
  final bool screenShare;
  final bool chat;
  final bool fileShare;
  final bool recording;
  final bool beautyFilter;
  final bool noiseSuppression;
  final bool callStats;
  final bool floatingPip;
  final bool popOutNewTab;
  final bool deviceSelection;
  final bool cameraFlip;
  final bool speakerToggle;
  final bool layoutToggle;
  final bool fitFillToggle;
  final bool fullscreen;
  final bool preCallLobby;
  final bool waitingRoom;
  final bool patientInfoPanel;
  final bool consultationNotes;
  final bool prescriptionShortcut;
  final bool networkTest;
  final bool endCallConfirm;
  final bool autoHideControls;
  final bool keepScreenAwake;
  final bool callFeedback;
  final bool audioOnlyFallback;

  const TeleconsultationFeatures({
    this.screenShare = true,
    this.chat = false,
    this.fileShare = false,
    this.recording = false,
    this.beautyFilter = true,
    this.noiseSuppression = true,
    this.callStats = true,
    this.floatingPip = true,
    this.popOutNewTab = true,
    this.deviceSelection = true,
    this.cameraFlip = true,
    this.speakerToggle = true,
    this.layoutToggle = true,
    this.fitFillToggle = true,
    this.fullscreen = true,
    this.preCallLobby = false,
    this.waitingRoom = true,
    this.patientInfoPanel = false,
    this.consultationNotes = false,
    this.prescriptionShortcut = true,
    this.networkTest = false,
    this.endCallConfirm = true,
    this.autoHideControls = true,
    this.keepScreenAwake = true,
    this.callFeedback = false,
    this.audioOnlyFallback = true,
  });

  /// Standard 1:1 video consultation preset.
  factory TeleconsultationFeatures.standardVideo() =>
      const TeleconsultationFeatures();

  /// Audio-only consultation preset (disables camera, screen share, beauty).
  factory TeleconsultationFeatures.audioOnly() =>
      const TeleconsultationFeatures(
        screenShare: false,
        beautyFilter: false,
        cameraFlip: false,
        fitFillToggle: false,
        fullscreen: false,
        layoutToggle: false,
        patientInfoPanel: true,
        consultationNotes: true,
        prescriptionShortcut: true,
      );

  /// Follow-up consultation preset (quick, streamlined, with clinical notes).
  factory TeleconsultationFeatures.followUp() => const TeleconsultationFeatures(
    screenShare: false,
    preCallLobby: false,
    patientInfoPanel: true,
    consultationNotes: true,
    prescriptionShortcut: true,
    callFeedback: true,
  );

  /// Second-opinion specialist consultation (collaboration focus, screen share, notes).
  factory TeleconsultationFeatures.secondOpinion() =>
      const TeleconsultationFeatures(
        screenShare: true,
        patientInfoPanel: true,
        consultationNotes: true,
        prescriptionShortcut: true,
        callStats: true,
        layoutToggle: true,
        fullscreen: true,
      );

  TeleconsultationFeatures copyWith({
    bool? screenShare,
    bool? chat,
    bool? fileShare,
    bool? recording,
    bool? beautyFilter,
    bool? noiseSuppression,
    bool? callStats,
    bool? floatingPip,
    bool? popOutNewTab,
    bool? deviceSelection,
    bool? cameraFlip,
    bool? speakerToggle,
    bool? layoutToggle,
    bool? fitFillToggle,
    bool? fullscreen,
    bool? preCallLobby,
    bool? waitingRoom,
    bool? patientInfoPanel,
    bool? consultationNotes,
    bool? prescriptionShortcut,
    bool? networkTest,
    bool? endCallConfirm,
    bool? autoHideControls,
    bool? keepScreenAwake,
    bool? callFeedback,
    bool? audioOnlyFallback,
  }) {
    return TeleconsultationFeatures(
      screenShare: screenShare ?? this.screenShare,
      chat: chat ?? this.chat,
      fileShare: fileShare ?? this.fileShare,
      recording: recording ?? this.recording,
      beautyFilter: beautyFilter ?? this.beautyFilter,
      noiseSuppression: noiseSuppression ?? this.noiseSuppression,
      callStats: callStats ?? this.callStats,
      floatingPip: floatingPip ?? this.floatingPip,
      popOutNewTab: popOutNewTab ?? this.popOutNewTab,
      deviceSelection: deviceSelection ?? this.deviceSelection,
      cameraFlip: cameraFlip ?? this.cameraFlip,
      speakerToggle: speakerToggle ?? this.speakerToggle,
      layoutToggle: layoutToggle ?? this.layoutToggle,
      fitFillToggle: fitFillToggle ?? this.fitFillToggle,
      fullscreen: fullscreen ?? this.fullscreen,
      preCallLobby: preCallLobby ?? this.preCallLobby,
      waitingRoom: waitingRoom ?? this.waitingRoom,
      patientInfoPanel: patientInfoPanel ?? this.patientInfoPanel,
      consultationNotes: consultationNotes ?? this.consultationNotes,
      prescriptionShortcut: prescriptionShortcut ?? this.prescriptionShortcut,
      networkTest: networkTest ?? this.networkTest,
      endCallConfirm: endCallConfirm ?? this.endCallConfirm,
      autoHideControls: autoHideControls ?? this.autoHideControls,
      keepScreenAwake: keepScreenAwake ?? this.keepScreenAwake,
      callFeedback: callFeedback ?? this.callFeedback,
      audioOnlyFallback: audioOnlyFallback ?? this.audioOnlyFallback,
    );
  }

  Map<String, dynamic> toJson() => {
    'screenShare': screenShare,
    'chat': chat,
    'fileShare': fileShare,
    'recording': recording,
    'beautyFilter': beautyFilter,
    'noiseSuppression': noiseSuppression,
    'callStats': callStats,
    'floatingPip': floatingPip,
    'popOutNewTab': popOutNewTab,
    'deviceSelection': deviceSelection,
    'cameraFlip': cameraFlip,
    'speakerToggle': speakerToggle,
    'layoutToggle': layoutToggle,
    'fitFillToggle': fitFillToggle,
    'fullscreen': fullscreen,
    'preCallLobby': preCallLobby,
    'waitingRoom': waitingRoom,
    'patientInfoPanel': patientInfoPanel,
    'consultationNotes': consultationNotes,
    'prescriptionShortcut': prescriptionShortcut,
    'networkTest': networkTest,
    'endCallConfirm': endCallConfirm,
    'autoHideControls': autoHideControls,
    'keepScreenAwake': keepScreenAwake,
    'callFeedback': callFeedback,
    'audioOnlyFallback': audioOnlyFallback,
  };

  factory TeleconsultationFeatures.fromJson(Map<String, dynamic> json) {
    bool b(String key, bool fallback) {
      final v = json[key];
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true' || v == '1';
      if (v is num) return v != 0;
      return fallback;
    }

    return TeleconsultationFeatures(
      screenShare: b('screenShare', true),
      chat: b('chat', false),
      fileShare: b('fileShare', false),
      recording: b('recording', false),
      beautyFilter: b('beautyFilter', true),
      noiseSuppression: b('noiseSuppression', true),
      callStats: b('callStats', true),
      floatingPip: b('floatingPip', true),
      popOutNewTab: b('popOutNewTab', true),
      deviceSelection: b('deviceSelection', true),
      cameraFlip: b('cameraFlip', true),
      speakerToggle: b('speakerToggle', true),
      layoutToggle: b('layoutToggle', true),
      fitFillToggle: b('fitFillToggle', true),
      fullscreen: b('fullscreen', true),
      preCallLobby: b('preCallLobby', false),
      waitingRoom: b('waitingRoom', true),
      patientInfoPanel: b('patientInfoPanel', true),
      consultationNotes: b('consultationNotes', true),
      prescriptionShortcut: b('prescriptionShortcut', true),
      networkTest: b('networkTest', false),
      endCallConfirm: b('endCallConfirm', true),
      autoHideControls: b('autoHideControls', true),
      keepScreenAwake: b('keepScreenAwake', true),
      callFeedback: b('callFeedback', false),
      audioOnlyFallback: b('audioOnlyFallback', true),
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TeleconsultationFeatures &&
          runtimeType == other.runtimeType &&
          screenShare == other.screenShare &&
          chat == other.chat &&
          fileShare == other.fileShare &&
          recording == other.recording &&
          beautyFilter == other.beautyFilter &&
          noiseSuppression == other.noiseSuppression &&
          callStats == other.callStats &&
          floatingPip == other.floatingPip &&
          popOutNewTab == other.popOutNewTab &&
          deviceSelection == other.deviceSelection &&
          cameraFlip == other.cameraFlip &&
          speakerToggle == other.speakerToggle &&
          layoutToggle == other.layoutToggle &&
          fitFillToggle == other.fitFillToggle &&
          fullscreen == other.fullscreen &&
          preCallLobby == other.preCallLobby &&
          waitingRoom == other.waitingRoom &&
          patientInfoPanel == other.patientInfoPanel &&
          consultationNotes == other.consultationNotes &&
          prescriptionShortcut == other.prescriptionShortcut &&
          networkTest == other.networkTest &&
          endCallConfirm == other.endCallConfirm &&
          autoHideControls == other.autoHideControls &&
          keepScreenAwake == other.keepScreenAwake &&
          callFeedback == other.callFeedback &&
          audioOnlyFallback == other.audioOnlyFallback;

  @override
  int get hashCode => Object.hashAll([
    screenShare,
    chat,
    fileShare,
    recording,
    beautyFilter,
    noiseSuppression,
    callStats,
    floatingPip,
    popOutNewTab,
    deviceSelection,
    cameraFlip,
    speakerToggle,
    layoutToggle,
    fitFillToggle,
    fullscreen,
    preCallLobby,
    waitingRoom,
    patientInfoPanel,
    consultationNotes,
    prescriptionShortcut,
    networkTest,
    endCallConfirm,
    autoHideControls,
    keepScreenAwake,
    callFeedback,
    audioOnlyFallback,
  ]);
}

/// Configuration for video encoder parameters, layout defaults, and theme styling.
@immutable
class TeleconsultationVideoConfig {
  final VideoQualityPreset preset;
  final int width;
  final int height;
  final int frameRate;
  final int bitrate;
  final int minBitrate;
  final bool
  defaultFitMode; // true => renderModeFit (no crop), false => renderModeHidden
  final int autoHideDelaySeconds;
  final int reconnectTimeoutSeconds;
  final Color primaryColor;
  final Color backgroundColor;
  final Color panelColor;

  const TeleconsultationVideoConfig({
    this.preset = VideoQualityPreset.hd,
    this.width = 1280,
    this.height = 720,
    this.frameRate = 30,
    this.bitrate = 1800,
    this.minBitrate = 400,
    this.defaultFitMode = true,
    this.autoHideDelaySeconds = 5,
    this.reconnectTimeoutSeconds = 30,
    this.primaryColor = const Color(0xFF00A884),
    this.backgroundColor = const Color(0xFF0B141A),
    this.panelColor = const Color(0xFF1F2C34),
  });

  /// Factory preset for HD (720p @ 30fps) - Recommended default for teleconsultations
  factory TeleconsultationVideoConfig.hd() => const TeleconsultationVideoConfig(
    preset: VideoQualityPreset.hd,
    width: 1280,
    height: 720,
    frameRate: 30,
    bitrate: 1800,
    minBitrate: 400,
    defaultFitMode: true,
  );

  /// Factory preset for Standard (540p @ 24fps)
  factory TeleconsultationVideoConfig.standard() =>
      const TeleconsultationVideoConfig(
        preset: VideoQualityPreset.standard,
        width: 960,
        height: 540,
        frameRate: 24,
        bitrate: 1000,
        minBitrate: 300,
        defaultFitMode: true,
      );

  /// Factory preset for Low / Data Saver (360p @ 15fps)
  factory TeleconsultationVideoConfig.low() =>
      const TeleconsultationVideoConfig(
        preset: VideoQualityPreset.low,
        width: 640,
        height: 360,
        frameRate: 15,
        bitrate: 400,
        minBitrate: 150,
        defaultFitMode: true,
      );

  TeleconsultationVideoConfig copyWith({
    VideoQualityPreset? preset,
    int? width,
    int? height,
    int? frameRate,
    int? bitrate,
    int? minBitrate,
    bool? defaultFitMode,
    int? autoHideDelaySeconds,
    int? reconnectTimeoutSeconds,
    Color? primaryColor,
    Color? backgroundColor,
    Color? panelColor,
  }) {
    return TeleconsultationVideoConfig(
      preset: preset ?? this.preset,
      width: width ?? this.width,
      height: height ?? this.height,
      frameRate: frameRate ?? this.frameRate,
      bitrate: bitrate ?? this.bitrate,
      minBitrate: minBitrate ?? this.minBitrate,
      defaultFitMode: defaultFitMode ?? this.defaultFitMode,
      autoHideDelaySeconds: autoHideDelaySeconds ?? this.autoHideDelaySeconds,
      reconnectTimeoutSeconds:
          reconnectTimeoutSeconds ?? this.reconnectTimeoutSeconds,
      primaryColor: primaryColor ?? this.primaryColor,
      backgroundColor: backgroundColor ?? this.backgroundColor,
      panelColor: panelColor ?? this.panelColor,
    );
  }

  Map<String, dynamic> toJson() => {
    'preset': preset.name,
    'width': width,
    'height': height,
    'frameRate': frameRate,
    'bitrate': bitrate,
    'minBitrate': minBitrate,
    'defaultFitMode': defaultFitMode,
    'autoHideDelaySeconds': autoHideDelaySeconds,
    'reconnectTimeoutSeconds': reconnectTimeoutSeconds,
  };

  factory TeleconsultationVideoConfig.fromJson(Map<String, dynamic> json) {
    final pName = json['preset'] as String?;
    final p = VideoQualityPreset.values.firstWhere(
      (e) => e.name == pName,
      orElse: () => VideoQualityPreset.hd,
    );

    int i(String key, int fallback) {
      final v = json[key];
      if (v is int) return v;
      if (v is num) return v.toInt();
      if (v is String) return int.tryParse(v) ?? fallback;
      return fallback;
    }

    bool b(String key, bool fallback) {
      final v = json[key];
      if (v is bool) return v;
      if (v is String) return v.toLowerCase() == 'true';
      return fallback;
    }

    return TeleconsultationVideoConfig(
      preset: p,
      width: i('width', 1280),
      height: i('height', 720),
      frameRate: i('frameRate', 30),
      bitrate: i('bitrate', 1800),
      minBitrate: i('minBitrate', 400),
      defaultFitMode: b('defaultFitMode', true),
      autoHideDelaySeconds: i('autoHideDelaySeconds', 5),
      reconnectTimeoutSeconds: i('reconnectTimeoutSeconds', 30),
    );
  }
}
