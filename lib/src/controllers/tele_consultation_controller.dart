import 'dart:async';

import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import '../config/teleconsultation_config.dart';
import '../config/teleconsultation_feature_config.dart';
import '../models/teleconsultation_clinical_data.dart';
import '../screens/tele_consultation_call_view.dart';
import '../utils/teleconsultation_logger.dart';
import '../utils/web_agora_script_loader.dart';
import '../utils/web_device_checker.dart';
import '../widgets/tele_consultation_floating_pip.dart';

enum CallStatus {
  idle,
  connecting, // engine starting / joining
  ringing, // joined, waiting for the other person
  connected, // both in channel
  reconnecting, // network drop
  remoteLeft, // other person left, we are still in channel
  failed,
  ended,
}

enum TeleconsultationDesktopLayout {
  patientFocus, // Patient video centered in aspect ratio container, doctor small
  sideBySide, // Doctor and patient video in equal columns
}

@immutable
class CallStats {
  final int localVideoKbps;
  final int localAudioKbps;
  final int remoteVideoKbps;
  final int remoteAudioKbps;
  final int localWidth;
  final int localHeight;
  final int localFps;
  final int remoteWidth;
  final int remoteHeight;
  final int remoteFps;

  const CallStats({
    this.localVideoKbps = 0,
    this.localAudioKbps = 0,
    this.remoteVideoKbps = 0,
    this.remoteAudioKbps = 0,
    this.localWidth = 0,
    this.localHeight = 0,
    this.localFps = 0,
    this.remoteWidth = 0,
    this.remoteHeight = 0,
    this.remoteFps = 0,
  });

  CallStats copyWith({
    int? localVideoKbps,
    int? localAudioKbps,
    int? remoteVideoKbps,
    int? remoteAudioKbps,
    int? localWidth,
    int? localHeight,
    int? localFps,
    int? remoteWidth,
    int? remoteHeight,
    int? remoteFps,
  }) => CallStats(
    localVideoKbps: localVideoKbps ?? this.localVideoKbps,
    localAudioKbps: localAudioKbps ?? this.localAudioKbps,
    remoteVideoKbps: remoteVideoKbps ?? this.remoteVideoKbps,
    remoteAudioKbps: remoteAudioKbps ?? this.remoteAudioKbps,
    localWidth: localWidth ?? this.localWidth,
    localHeight: localHeight ?? this.localHeight,
    localFps: localFps ?? this.localFps,
    remoteWidth: remoteWidth ?? this.remoteWidth,
    remoteHeight: remoteHeight ?? this.remoteHeight,
    remoteFps: remoteFps ?? this.remoteFps,
  );
}

class _CallSetupException implements Exception {
  final String message;
  _CallSetupException(this.message);
  @override
  String toString() => message;
}

class TeleConsultationController extends ChangeNotifier {
  TeleConsultationController._();
  static final TeleConsultationController instance =
      TeleConsultationController._();

  /// Set this to your ROOT navigator key in MaterialApp.
  static GlobalKey<NavigatorState>? navigatorKey;

  // ------------------------------------------------------------- configurations
  TeleconsultationConfig? _config;
  TeleconsultationConfig? get config => _config;

  TeleconsultationFeatures _features = const TeleconsultationFeatures();
  TeleconsultationFeatures get features => _features;

  TeleconsultationVideoConfig _videoConfig =
      const TeleconsultationVideoConfig();
  TeleconsultationVideoConfig get videoConfig => _videoConfig;

  TeleconsultationClinicalDataProvider? _clinicalDataProvider;
  TeleconsultationClinicalDataProvider? get clinicalDataProvider =>
      _clinicalDataProvider;

  void setClinicalDataProvider(TeleconsultationClinicalDataProvider? provider) {
    _clinicalDataProvider = provider;
    _notify();
  }

  // ---------------------------------------------------------------- session
  RtcEngine? _engine;
  RtcEngine? get engine => _engine;

  RtcEngineEventHandler? _handler;
  int _sessionId = 0;
  bool _isInitializing = false;
  VoidCallback? _onEndCallCallback;
  Future<String?> Function()? _tokenProvider;

  CallStatus _status = CallStatus.idle;
  CallStatus get status => _status;

  String _errorMessage = '';
  String get errorMessage => _errorMessage;

  bool _needsAppSettings = false;
  bool get needsAppSettings => _needsAppSettings;

  String? _deviceWarningBanner;
  String? get deviceWarningBanner => _deviceWarningBanner;

  void dismissDeviceWarning() {
    _deviceWarningBanner = null;
    _notify();
  }

  int? _localUid;
  int get localUid => _localUid ?? _config?.uid ?? 0;

  int? _remoteUid;
  int? get remoteUid => _remoteUid;
  bool _hadRemote = false;

  bool _remoteVideoEnabled = false;
  bool get remoteVideoEnabled => _remoteVideoEnabled;

  bool _remoteAudioMuted = false;
  bool get remoteAudioMuted => _remoteAudioMuted;

  // -------------------------------------------------- live video aspect & stats
  int _remoteVideoWidth = 0;
  int get remoteVideoWidth => _remoteVideoWidth;
  int _remoteVideoHeight = 0;
  int get remoteVideoHeight => _remoteVideoHeight;
  int _remoteFps = 0;
  int get remoteFps => _remoteFps;
  int _remoteBitrate = 0;
  int get remoteBitrate => _remoteBitrate;

  int _localVideoWidth = 0;
  int get localVideoWidth => _localVideoWidth;
  int _localVideoHeight = 0;
  int get localVideoHeight => _localVideoHeight;
  int _localFps = 0;
  int get localFps => _localFps;
  int _localBitrate = 0;
  int get localBitrate => _localBitrate;

  double get remoteAspectRatio =>
      (_remoteVideoWidth > 0 && _remoteVideoHeight > 0)
          ? (_remoteVideoWidth / _remoteVideoHeight)
          : (16 / 9);

  bool get isRemotePortrait => remoteAspectRatio < 0.95;

  // Fit vs Fill user toggle
  bool _isFitMode = true;
  bool get isFitMode => _isFitMode;
  RenderModeType get remoteRenderMode =>
      _isFitMode ? RenderModeType.renderModeFit : RenderModeType.renderModeHidden;

  void toggleFitFill() {
    if (!_features.fitFillToggle) return;
    _isFitMode = !_isFitMode;
    _notify();
  }

  // Desktop layout: Patient focus vs Side-by-Side
  TeleconsultationDesktopLayout _desktopLayout =
      TeleconsultationDesktopLayout.patientFocus;
  TeleconsultationDesktopLayout get desktopLayout => _desktopLayout;

  void toggleDesktopLayout() {
    if (!_features.layoutToggle) return;
    _desktopLayout =
        (_desktopLayout == TeleconsultationDesktopLayout.patientFocus)
            ? TeleconsultationDesktopLayout.sideBySide
            : TeleconsultationDesktopLayout.patientFocus;
    _notify();
  }

  void setDesktopLayout(TeleconsultationDesktopLayout layout) {
    if (!_features.layoutToggle) return;
    _desktopLayout = layout;
    _notify();
  }

  // Side clinical info panel
  bool _showSidePanel = true;
  bool get showSidePanel => _showSidePanel;

  void toggleSidePanel() {
    _showSidePanel = !_showSidePanel;
    _notify();
  }

  // ------------------------------------------------------------ local state
  bool _hasCamera = true;
  bool get hasCamera => _hasCamera;
  bool _hasMicrophone = true;
  bool get hasMicrophone => _hasMicrophone;

  bool _isMuted = false;
  bool get isMuted => _isMuted;
  bool _isVideoEnabled = true;
  bool get isVideoEnabled => _isVideoEnabled;
  bool _isSpeakerEnabled = true;
  bool get isSpeakerEnabled => _isSpeakerEnabled;
  bool _isFrontCamera = true;
  bool get isFrontCamera => _isFrontCamera;
  bool _isScreenSharing = false;
  bool get isScreenSharing => _isScreenSharing;
  bool get canScreenShare =>
      kIsWeb ||
      defaultTargetPlatform == TargetPlatform.windows ||
      defaultTargetPlatform == TargetPlatform.macOS ||
      defaultTargetPlatform == TargetPlatform.linux;

  // user preferences
  bool _beautyEnabled = false;
  bool get beautyEnabled => _beautyEnabled;
  double _beautyLevel = 0.5;
  double get beautyLevel => _beautyLevel;
  double _brightnessLevel = 0.7;
  double get brightnessLevel => _brightnessLevel;
  bool _noiseSuppressionEnabled = true;
  bool get noiseSuppressionEnabled => _noiseSuppressionEnabled;
  bool _showStats = false;
  bool get showStats => _showStats;

  QualityType _localNetworkQuality = QualityType.qualityUnknown;
  QualityType get localNetworkQuality => _localNetworkQuality;
  QualityType _remoteNetworkQuality = QualityType.qualityUnknown;
  QualityType get remoteNetworkQuality => _remoteNetworkQuality;

  final ValueNotifier<int> callDuration = ValueNotifier<int>(0);
  final ValueNotifier<CallStats> stats = ValueNotifier<CallStats>(
    const CallStats(),
  );
  final ValueNotifier<bool> localSpeaking = ValueNotifier<bool>(false);
  final ValueNotifier<bool> remoteSpeaking = ValueNotifier<bool>(false);
  Timer? _callTimer;

  // ------------------------------------------------- web / desktop devices
  VideoDeviceManager? _videoDeviceManager;
  List<VideoDeviceInfo> _videoDevices = [];
  List<VideoDeviceInfo> get videoDevices => _videoDevices;
  String? _currentCameraId;
  String? get currentCameraId => _currentCameraId;

  AudioDeviceManager? _audioDeviceManager;
  List<AudioDeviceInfo> _audioDevices = [];
  List<AudioDeviceInfo> get audioDevices => _audioDevices;
  String? _currentMicrophoneId;
  String? get currentMicrophoneId => _currentMicrophoneId;

  List<AudioDeviceInfo> _playbackDevices = [];
  List<AudioDeviceInfo> get playbackDevices => _playbackDevices;
  String? _currentPlaybackDeviceId;
  String? get currentPlaybackDeviceId => _currentPlaybackDeviceId;

  // --------------------------------------------------------- floating PiP
  bool _isMinimized = false;
  bool get isMinimized => _isMinimized;
  OverlayEntry? _pipOverlayEntry;
  final ValueNotifier<Offset> pipPosition = ValueNotifier<Offset>(
    const Offset(16, 80),
  );

  bool get hasActiveCall =>
      _engine != null &&
      const {
        CallStatus.connecting,
        CallStatus.ringing,
        CallStatus.connected,
        CallStatus.reconnecting,
        CallStatus.remoteLeft,
      }.contains(_status);

  void _notify() => notifyListeners();

  // =======================================================================
  // PUBLIC: start / init
  // =======================================================================

  /// Pushes the call screen IMMEDIATELY (shows "Connecting…"), then starts Agora.
  Future<void> startCall(
    BuildContext context, {
    required TeleconsultationConfig config,
    TeleconsultationFeatures? features,
    TeleconsultationVideoConfig? videoConfig,
    TeleconsultationClinicalDataProvider? clinicalDataProvider,
    VoidCallback? onEndCall,
    Future<String?> Function()? onRefreshToken,
  }) async {
    final nav = navigatorKey?.currentState ?? Navigator.of(context);
    nav.push(
      MaterialPageRoute(builder: (_) => const TeleConsultationCallView()),
    );
    await initCall(
      config: config,
      features: features,
      videoConfig: videoConfig,
      clinicalDataProvider: clinicalDataProvider,
      onEndCall: onEndCall,
      onRefreshToken: onRefreshToken,
    );
  }

  /// Use when the call screen is already on screen (e.g. TeleConsultationPage).
  Future<void> initCall({
    required TeleconsultationConfig config,
    TeleconsultationFeatures? features,
    TeleconsultationVideoConfig? videoConfig,
    TeleconsultationClinicalDataProvider? clinicalDataProvider,
    VoidCallback? onEndCall,
    Future<String?> Function()? onRefreshToken,
  }) async {
    if (features != null) _features = features;
    if (videoConfig != null) {
      _videoConfig = videoConfig;
      _isFitMode = videoConfig.defaultFitMode;
    }
    if (clinicalDataProvider != null) {
      _clinicalDataProvider = clinicalDataProvider;
    }

    // Same call already running or initializing
    if ((_isInitializing || hasActiveCall) &&
        _config?.channelId == config.channelId) {
      _onEndCallCallback = onEndCall ?? _onEndCallCallback;
      _removePipOverlay();
      _isMinimized = false;
      _notify();
      return;
    }

    _isInitializing = true;
    try {
      await _teardownEngine();
      final sid = ++_sessionId;

      _config = config;
      _onEndCallCallback = onEndCall;
      _tokenProvider = onRefreshToken;
      _resetSessionState();
      _status = CallStatus.connecting;
      _notify();

      await _initializeAgora(sid);
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> retry() async {
    final cfg = _config;
    if (cfg == null) return;
    await initCall(
      config: cfg,
      features: _features,
      videoConfig: _videoConfig,
      clinicalDataProvider: _clinicalDataProvider,
      onEndCall: _onEndCallCallback,
      onRefreshToken: _tokenProvider,
    );
  }

  void _resetSessionState() {
    _errorMessage = '';
    _needsAppSettings = false;
    _deviceWarningBanner = null;
    _localUid = null;
    _remoteUid = null;
    _hadRemote = false;
    _remoteVideoEnabled = false;
    _remoteAudioMuted = false;
    _remoteVideoWidth = 0;
    _remoteVideoHeight = 0;
    _remoteFps = 0;
    _localVideoWidth = 0;
    _localVideoHeight = 0;
    _localFps = 0;
    _isMuted = false;
    _isVideoEnabled = true;
    _isSpeakerEnabled = true;
    _isFrontCamera = true;
    _isScreenSharing = false;
    _hasCamera = true;
    _hasMicrophone = true;
    _localNetworkQuality = QualityType.qualityUnknown;
    _remoteNetworkQuality = QualityType.qualityUnknown;
    _videoDevices = [];
    _audioDevices = [];
    _playbackDevices = [];
    _currentCameraId = null;
    _currentMicrophoneId = null;
    _currentPlaybackDeviceId = null;
    callDuration.value = 0;
    stats.value = const CallStats();
    localSpeaking.value = false;
    remoteSpeaking.value = false;
    _isMinimized = false;
    _removePipOverlay();
  }

  // =======================================================================
  // DEVICE DETECTION & INITIALIZATION
  // =======================================================================

  Future<void> _prepareDevices() async {
    if (kIsWeb) {
      final d = await WebDeviceChecker.checkDevices();
      _hasCamera = d.hasCamera;
      _hasMicrophone = d.hasMicrophone;
      teleconsultationLog(
        'Web devices checked — cam: $_hasCamera mic: $_hasMicrophone',
      );
      if (!_hasCamera) {
        _isVideoEnabled = false;
        _deviceWarningBanner =
            'No camera found or camera blocked in browser. Click the lock icon in the address bar to allow camera access.';
      }
      if (!_hasMicrophone) {
        _isMuted = true;
        _deviceWarningBanner =
            'No microphone found or microphone blocked. Click the lock icon in the address bar to allow microphone access.';
      }
      return;
    }

    final res = await <Permission>[
      Permission.camera,
      Permission.microphone,
    ].request();
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await Permission.bluetoothConnect.request();
      } catch (_) {}
    }

    final mic = res[Permission.microphone];
    final cam = res[Permission.camera];
    _hasMicrophone = mic?.isGranted ?? false;
    _hasCamera = cam?.isGranted ?? false;

    if (!_hasMicrophone) {
      _needsAppSettings = mic?.isPermanentlyDenied ?? false;
      throw _CallSetupException(
        'Microphone permission is required for the consultation.\n'
        'Please allow it in system settings and try again.',
      );
    }
    if (!_hasCamera) {
      teleconsultationLog('Camera permission denied — continuing in audio-only mode');
      _isVideoEnabled = false;
    }
  }

  /// Re-checks browser / OS devices without ending the call, allowing recovery
  /// if user unblocks camera or plugs in a headset mid-call.
  Future<void> checkDevicesAndRejoin() async {
    teleconsultationLog('Re-checking devices mid-call...');
    await _prepareDevices();
    final engine = _engine;
    if (engine == null) return;

    if (kIsWeb) {
      await _enumerateWebDevices(engine);
    }

    try {
      if (_hasCamera && !_isVideoEnabled) {
        await engine.enableVideo();
        await engine.startPreview();
        _isVideoEnabled = true;
      }
      if (_hasMicrophone && _isMuted) {
        await engine.muteLocalAudioStream(false);
        _isMuted = false;
      }
      await engine.updateChannelMediaOptions(
        ChannelMediaOptions(
          publishCameraTrack: _hasCamera && _isVideoEnabled && !_isScreenSharing,
          publishMicrophoneTrack: _hasMicrophone && !_isMuted,
        ),
      );
      _deviceWarningBanner = null;
      _notify();
    } catch (e) {
      teleconsultationLog('checkDevicesAndRejoin error: $e');
    }
  }

  Future<void> _initializeAgora(int sid) async {
    try {
      await _prepareDevices();
      if (sid != _sessionId) return;

      if (kIsWeb) {
        await WebAgoraScriptLoader.ensureScriptsLoaded();
        if (sid != _sessionId) return;
      }

      var appId = _config?.appId ?? '';
      if (appId.isEmpty) appId = TeleconsultationConfig.defaultAppId;
      if (appId.isEmpty) throw _CallSetupException('Agora App ID is missing.');

      final engine = createAgoraRtcEngine();
      _engine = engine;

      await engine.initialize(
        RtcEngineContext(
          appId: appId,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          audioScenario: AudioScenarioType.audioScenarioMeeting,
          areaCode: AreaCode.areaCodeGlob.value(),
        ),
      );
      if (sid != _sessionId) return;

      _registerEventHandlers(engine, sid);

      await engine.enableAudio();
      // Configure audio profile for speech (mono, standard speech coding)
      await engine.setAudioProfile(
        profile: AudioProfileType.audioProfileSpeechStandard,
        scenario: AudioScenarioType.audioScenarioMeeting,
      );

      // Video configuration per videoConfig preset
      if (_hasCamera) {
        await engine.enableVideo();
        await _applyVideoEncoderConfiguration(engine);
      } else {
        _isVideoEnabled = false;
      }

      // 1v1 video consultation scenario
      try {
        await engine.setVideoScenario(
          VideoApplicationScenarioType.applicationScenario1v1,
        );
      } catch (e) {
        teleconsultationLog('setVideoScenario note: $e');
      }

      // Enable dual-stream mode so high stream is sent for main video and low stream for thumbnail
      try {
        await engine.setDualStreamMode(
          mode: SimulcastStreamMode.autoSimulcastStream,
        );
      } catch (e) {
        teleconsultationLog('setDualStreamMode note: $e');
      }

      await engine.setClientRole(role: ClientRoleType.clientRoleBroadcaster);
      await _enableAdvancedFeatures(engine);

      if (!kIsWeb) {
        _isSpeakerEnabled = _hasCamera; // video call → speaker, audio → ear
        try {
          await engine.setDefaultAudioRouteToSpeakerphone(_isSpeakerEnabled);
        } catch (_) {}
      }

      if (_hasCamera) await engine.startPreview();
      if (sid != _sessionId) return;

      _notify();

      if (kIsWeb) await _enumerateWebDevices(engine);
      if (sid != _sessionId) return;

      await engine.joinChannel(
        token: _config?.token ?? '',
        channelId: _config?.channelId ?? '',
        uid: _config?.uid ?? 0,
        options: ChannelMediaOptions(
          clientRoleType: ClientRoleType.clientRoleBroadcaster,
          channelProfile: ChannelProfileType.channelProfileCommunication,
          autoSubscribeAudio: true,
          autoSubscribeVideo: true,
          publishCameraTrack: _hasCamera && _isVideoEnabled,
          publishMicrophoneTrack: _hasMicrophone && !_isMuted,
          publishScreenTrack: false,
          publishCustomAudioTrack: false,
          publishCustomVideoTrack: false,
        ),
      );
    } catch (e) {
      if (sid != _sessionId) return;
      teleconsultationLog('Agora init error: $e');
      final msg = e.toString();
      if (e is _CallSetupException) {
        _fail(e.message, needsSettings: _needsAppSettings);
      } else if (msg.contains('createPlatformBindingsProvider') ||
          e is UnimplementedError) {
        _fail(
          'Video consultation is not supported in WebAssembly (Wasm) mode.\n'
          'Please access via standard web build or use a supported browser.',
        );
      } else if (msg.contains('NotFoundError') || msg.contains('not found')) {
        _fail(
          'Camera or microphone not found.\n'
          'Connect a device, allow browser access and retry.',
        );
      } else {
        _fail('Failed to connect: $msg');
      }
    }
  }

  Future<void> _applyVideoEncoderConfiguration(RtcEngine engine) async {
    final cfg = _videoConfig;
    teleconsultationLog(
      'Configuring video encoder: ${cfg.width}x${cfg.height} @ ${cfg.frameRate}fps, ${cfg.bitrate}kbps (maintainQuality)',
    );
    await engine.setVideoEncoderConfiguration(
      VideoEncoderConfiguration(
        dimensions: VideoDimensions(width: cfg.width, height: cfg.height),
        frameRate: cfg.frameRate,
        bitrate: cfg.bitrate,
        minBitrate: cfg.minBitrate,
        orientationMode: OrientationMode.orientationModeAdaptive,
        degradationPreference: DegradationPreference.maintainQuality,
        mirrorMode: VideoMirrorModeType.videoMirrorModeAuto,
      ),
    );
  }

  Future<void> setVideoQualityPreset(VideoQualityPreset preset) async {
    switch (preset) {
      case VideoQualityPreset.low:
        _videoConfig = TeleconsultationVideoConfig.low();
        break;
      case VideoQualityPreset.standard:
        _videoConfig = TeleconsultationVideoConfig.standard();
        break;
      case VideoQualityPreset.hd:
        _videoConfig = TeleconsultationVideoConfig.hd();
        break;
    }
    _notify();
    final engine = _engine;
    if (engine != null && _hasCamera) {
      try {
        await _applyVideoEncoderConfiguration(engine);
      } catch (e) {
        teleconsultationLog('setVideoQualityPreset error: $e');
      }
    }
  }

  Future<void> _enableAdvancedFeatures(RtcEngine engine) async {
    try {
      await engine.enableAudioVolumeIndication(
        interval: 250,
        smooth: 3,
        reportVad: true,
      );
    } catch (e) {
      teleconsultationLog('Volume indication warning: $e');
    }
    if (!kIsWeb && _features.noiseSuppression) {
      try {
        await engine.setAINSMode(
          enabled: _noiseSuppressionEnabled,
          mode: AudioAinsMode.ainsModeBalanced,
        );
      } catch (_) {}
    }
  }

  Future<void> _enumerateWebDevices(RtcEngine engine) async {
    try {
      if (_hasCamera) {
        _videoDeviceManager = engine.getVideoDeviceManager();
        _videoDevices = await _videoDeviceManager!.enumerateVideoDevices();
        if (_videoDevices.isNotEmpty && _currentCameraId == null) {
          _currentCameraId = _videoDevices.first.deviceId;
        }
      }
      _audioDeviceManager = engine.getAudioDeviceManager();
      _audioDevices = await _audioDeviceManager!.enumerateRecordingDevices();
      if (_audioDevices.isNotEmpty && _currentMicrophoneId == null) {
        _currentMicrophoneId = _audioDevices.first.deviceId;
      }
      _playbackDevices = await _audioDeviceManager!.enumeratePlaybackDevices();
      if (_playbackDevices.isNotEmpty && _currentPlaybackDeviceId == null) {
        _currentPlaybackDeviceId = _playbackDevices.first.deviceId;
      }
    } catch (e) {
      teleconsultationLog('Device enumeration warning: $e');
    }
  }

  void _fail(String message, {bool needsSettings = false}) {
    _status = CallStatus.failed;
    _errorMessage = message;
    _needsAppSettings = needsSettings;
    _stopCallTimer();
    _notify();
  }

  CallStatus _statusFromPeers() => _remoteUid != null
      ? CallStatus.connected
      : (_hadRemote ? CallStatus.remoteLeft : CallStatus.ringing);

  // =======================================================================
  // EVENTS
  // =======================================================================

  void _registerEventHandlers(RtcEngine engine, int sid) {
    bool stale() => sid != _sessionId;

    final handler = RtcEngineEventHandler(
      onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
        if (stale()) return;
        teleconsultationLog('Joined as localUid ${connection.localUid}');
        _localUid = connection.localUid;
        _status = _statusFromPeers();
        if (!kIsWeb) {
          unawaited(
            engine.setEnableSpeakerphone(_isSpeakerEnabled).catchError((_) {}),
          );
        }
        _notify();
      },
      onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
        if (stale()) return;
        teleconsultationLog('Remote user joined: $remoteUid');
        _remoteUid = remoteUid;
        _hadRemote = true;
        _remoteVideoEnabled = true;
        _remoteAudioMuted = false;
        _status = CallStatus.connected;

        // Explicitly request HIGH stream for main remote video
        unawaited(
          engine
              .setRemoteVideoStreamType(
                uid: remoteUid,
                streamType: VideoStreamType.videoStreamHigh,
              )
              .catchError((e) {
                teleconsultationLog('setRemoteVideoStreamType note: $e');
              }),
        );

        if (!kIsWeb) {
          unawaited(
            engine.setEnableSpeakerphone(_isSpeakerEnabled).catchError((_) {}),
          );
        }
        _startCallTimer();
        _notify();
      },
      onUserOffline:
          (
            RtcConnection connection,
            int remoteUid,
            UserOfflineReasonType reason,
          ) {
            if (stale() || _remoteUid != remoteUid) return;
            teleconsultationLog('Remote offline: $remoteUid ($reason)');
            _remoteUid = null;
            _remoteVideoEnabled = false;
            _remoteAudioMuted = false;
            _remoteVideoWidth = 0;
            _remoteVideoHeight = 0;
            _remoteFps = 0;
            _remoteNetworkQuality = QualityType.qualityUnknown;
            remoteSpeaking.value = false;
            _status = CallStatus.remoteLeft;
            _stopCallTimer();
            _notify();
          },
      onLeaveChannel: (RtcConnection connection, RtcStats rtcStats) {
        if (stale()) return;
        _remoteUid = null;
        _remoteVideoEnabled = false;
        _stopCallTimer();
      },
      onConnectionStateChanged:
          (
            RtcConnection connection,
            ConnectionStateType state,
            ConnectionChangedReasonType reason,
          ) {
            if (stale()) return;
            switch (state) {
              case ConnectionStateType.connectionStateReconnecting:
                _status = CallStatus.reconnecting;
                _notify();
                break;
              case ConnectionStateType.connectionStateConnected:
                if (_status == CallStatus.reconnecting ||
                    _status == CallStatus.connecting) {
                  _status = _statusFromPeers();
                  _notify();
                }
                break;
              case ConnectionStateType.connectionStateFailed:
                _fail(
                  'Connection to consultation server failed.\n'
                  'Please check your network connection and retry.',
                );
                break;
              default:
                break;
            }
          },
      onTokenPrivilegeWillExpire:
          (RtcConnection connection, String token) async {
            final provider = _tokenProvider;
            if (provider == null) return;
            try {
              final fresh = await provider();
              if (fresh != null && fresh.isNotEmpty && !stale()) {
                await engine.renewToken(fresh);
                teleconsultationLog('Agora token renewed successfully');
              }
            } catch (e) {
              teleconsultationLog('Token renew failed: $e');
            }
          },
      onRequestToken: (RtcConnection connection) {
        if (stale()) return;
        _fail('Your consultation session token has expired. Please rejoin.');
      },
      onError: (ErrorCodeType err, String msg) {
        if (stale()) return;
        teleconsultationLog('Agora error: $err - $msg');
        const fatal = {
          ErrorCodeType.errInvalidAppId,
          ErrorCodeType.errInvalidChannelName,
          ErrorCodeType.errInvalidToken,
          ErrorCodeType.errTokenExpired,
          ErrorCodeType.errJoinChannelRejected,
        };
        if (fatal.contains(err)) {
          _fail(msg.isNotEmpty ? msg : 'Unable to join consultation ($err).');
        }
      },
      onVideoSizeChanged:
          (
            RtcConnection connection,
            VideoSourceType sourceType,
            int uid,
            int width,
            int height,
            int rotation,
          ) {
            if (stale()) return;
            teleconsultationLog(
              'onVideoSizeChanged: uid=$uid, ${width}x$height, rotation=$rotation',
            );
            if (uid == _remoteUid || (uid != 0 && _remoteUid == null)) {
              _remoteVideoWidth = width;
              _remoteVideoHeight = height;
              stats.value = stats.value.copyWith(
                remoteWidth: width,
                remoteHeight: height,
              );
              _notify();
            } else if (uid == 0 || uid == _localUid) {
              _localVideoWidth = width;
              _localVideoHeight = height;
              stats.value = stats.value.copyWith(
                localWidth: width,
                localHeight: height,
              );
              _notify();
            }
          },
      onFirstRemoteVideoFrame:
          (
            RtcConnection connection,
            int remoteUid,
            int width,
            int height,
            int elapsed,
          ) {
            if (stale()) return;
            teleconsultationLog(
              'onFirstRemoteVideoFrame: uid=$remoteUid, ${width}x$height',
            );
            _remoteUid = remoteUid;
            _remoteVideoWidth = width;
            _remoteVideoHeight = height;
            _remoteVideoEnabled = true;
            stats.value = stats.value.copyWith(
              remoteWidth: width,
              remoteHeight: height,
            );
            _notify();
          },
      onRemoteVideoStateChanged:
          (
            RtcConnection connection,
            int remoteUid,
            RemoteVideoState state,
            RemoteVideoStateReason reason,
            int elapsed,
          ) {
            if (stale()) return;
            _remoteUid ??= remoteUid;
            if (_remoteUid != remoteUid) return;
            final on =
                state == RemoteVideoState.remoteVideoStateDecoding ||
                state == RemoteVideoState.remoteVideoStateStarting;
            final off =
                state == RemoteVideoState.remoteVideoStateStopped ||
                state == RemoteVideoState.remoteVideoStateFailed ||
                state == RemoteVideoState.remoteVideoStateFrozen;
            if (on && !_remoteVideoEnabled) {
              _remoteVideoEnabled = true;
              _notify();
            } else if (off && _remoteVideoEnabled) {
              _remoteVideoEnabled = false;
              _notify();
            }
          },
      onRemoteAudioStateChanged:
          (
            RtcConnection connection,
            int remoteUid,
            RemoteAudioState state,
            RemoteAudioStateReason reason,
            int elapsed,
          ) {
            if (stale() || _remoteUid != remoteUid) return;
            if (reason == RemoteAudioStateReason.remoteAudioReasonRemoteMuted) {
              _remoteAudioMuted = true;
              _notify();
            } else if (reason ==
                RemoteAudioStateReason.remoteAudioReasonRemoteUnmuted) {
              _remoteAudioMuted = false;
              _notify();
            }
          },
      onNetworkQuality:
          (
            RtcConnection connection,
            int remoteUid,
            QualityType txQuality,
            QualityType rxQuality,
          ) {
            if (stale()) return;
            var changed = false;
            if (remoteUid == 0 && _localNetworkQuality != txQuality) {
              _localNetworkQuality = txQuality;
              changed = true;
              // Audio-only fallback if network is severely degraded
              if (_features.audioOnlyFallback &&
                  (txQuality == QualityType.qualityDown ||
                      txQuality == QualityType.qualityVbad)) {
                teleconsultationLog(
                  'Poor network detected (quality=$txQuality) — prioritizing audio clarity',
                );
              }
            } else if (remoteUid == _remoteUid &&
                _remoteNetworkQuality != rxQuality) {
              _remoteNetworkQuality = rxQuality;
              changed = true;
            }
            if (changed) _notify();
          },
      onLocalVideoStats:
          (
            RtcConnection connection,
            VideoSourceType sourceType,
            LocalVideoStats s,
          ) {
            if (s.encodedFrameWidth != null && s.encodedFrameWidth! > 0) {
              _localVideoWidth = s.encodedFrameWidth!;
            }
            if (s.encodedFrameHeight != null && s.encodedFrameHeight! > 0) {
              _localVideoHeight = s.encodedFrameHeight!;
            }
            _localFps = s.sentFrameRate ?? 0;
            _localBitrate = s.sentBitrate ?? 0;
            stats.value = stats.value.copyWith(
              localVideoKbps: s.sentBitrate ?? 0,
              localWidth: _localVideoWidth,
              localHeight: _localVideoHeight,
              localFps: _localFps,
            );
          },
      onLocalAudioStats: (RtcConnection connection, LocalAudioStats s) {
        stats.value = stats.value.copyWith(localAudioKbps: s.sentBitrate ?? 0);
      },
      onRemoteVideoStats: (RtcConnection connection, RemoteVideoStats s) {
        if (s.width != null && s.width! > 0) _remoteVideoWidth = s.width!;
        if (s.height != null && s.height! > 0) _remoteVideoHeight = s.height!;
        _remoteFps = s.rendererOutputFrameRate ?? s.decoderOutputFrameRate ?? 0;
        _remoteBitrate = s.receivedBitrate ?? 0;
        stats.value = stats.value.copyWith(
          remoteVideoKbps: s.receivedBitrate ?? 0,
          remoteWidth: _remoteVideoWidth,
          remoteHeight: _remoteVideoHeight,
          remoteFps: _remoteFps,
        );
      },
      onRemoteAudioStats: (RtcConnection connection, RemoteAudioStats s) {
        stats.value = stats.value.copyWith(
          remoteAudioKbps: s.receivedBitrate ?? 0,
        );
      },
      onAudioVolumeIndication:
          (
            RtcConnection connection,
            List<AudioVolumeInfo> speakers,
            int speakerNumber,
            int totalVolume,
          ) {
            var local = false;
            var remote = false;
            for (final s in speakers) {
              final speaking = (s.volume ?? 0) > 20;
              if (s.uid == 0 || s.uid == _localUid) {
                local = speaking;
              } else if (s.uid == _remoteUid) {
                remote = speaking;
              }
            }
            if (localSpeaking.value != local) localSpeaking.value = local;
            if (remoteSpeaking.value != remote) remoteSpeaking.value = remote;
          },
    );

    _handler = handler;
    engine.registerEventHandler(handler);
  }

  // =======================================================================
  // TIMER
  // =======================================================================

  void _startCallTimer() {
    if (_callTimer != null) return;
    _callTimer = Timer.periodic(const Duration(seconds: 1), (_) {
      callDuration.value++;
    });
  }

  void _stopCallTimer() {
    _callTimer?.cancel();
    _callTimer = null;
  }

  String formatDuration([int? seconds]) {
    final total = seconds ?? callDuration.value;
    final h = total ~/ 3600;
    final m = (total % 3600) ~/ 60;
    final s = total % 60;
    String two(int v) => v.toString().padLeft(2, '0');
    return h > 0 ? '${two(h)}:${two(m)}:${two(s)}' : '${two(m)}:${two(s)}';
  }

  // =======================================================================
  // CONTROLS & FEATURE ENFORCEMENT
  // =======================================================================

  Future<void> toggleMute() async {
    final engine = _engine;
    if (engine == null || !_hasMicrophone) return;
    _isMuted = !_isMuted;
    _notify();
    try {
      await engine.muteLocalAudioStream(_isMuted);
    } catch (e) {
      _isMuted = !_isMuted;
      _notify();
      teleconsultationLog('Mute error: $e');
    }
  }

  Future<void> toggleVideo() async {
    final engine = _engine;
    if (engine == null || !_hasCamera) return;
    _isVideoEnabled = !_isVideoEnabled;
    _notify();
    try {
      await engine.enableLocalVideo(_isVideoEnabled);
      await engine.muteLocalVideoStream(!_isVideoEnabled);
    } catch (e) {
      _isVideoEnabled = !_isVideoEnabled;
      _notify();
      teleconsultationLog('Video toggle error: $e');
    }
  }

  Future<void> switchCamera() async {
    if (!_features.cameraFlip) return;
    final engine = _engine;
    if (engine == null || !_hasCamera) return;
    if (kIsWeb) {
      if (_videoDevices.length > 1) {
        final i = _videoDevices.indexWhere(
          (d) => d.deviceId == _currentCameraId,
        );
        final next = (i + 1) % _videoDevices.length;
        await setCamera(_videoDevices[next].deviceId ?? '');
      }
      return;
    }
    try {
      await engine.switchCamera();
      _isFrontCamera = !_isFrontCamera;
      _notify();
    } catch (e) {
      teleconsultationLog('Switch camera error: $e');
    }
  }

  Future<void> setCamera(String deviceId) async {
    if (!_features.deviceSelection) return;
    if (_videoDeviceManager == null) return;
    try {
      await _videoDeviceManager!.setDevice(deviceId);
      _currentCameraId = deviceId;
      _notify();
    } catch (e) {
      teleconsultationLog('Set camera error: $e');
    }
  }

  Future<void> setMicrophone(String deviceId) async {
    if (!_features.deviceSelection) return;
    if (_audioDeviceManager == null) return;
    try {
      await _audioDeviceManager!.setRecordingDevice(deviceId);
      _currentMicrophoneId = deviceId;
      _notify();
    } catch (e) {
      teleconsultationLog('Set mic error: $e');
    }
  }

  Future<void> setPlaybackDevice(String deviceId) async {
    if (!_features.deviceSelection) return;
    if (_audioDeviceManager == null) return;
    try {
      await _audioDeviceManager!.setPlaybackDevice(deviceId);
      _currentPlaybackDeviceId = deviceId;
      _notify();
    } catch (e) {
      teleconsultationLog('Set playback device error: $e');
    }
  }

  Future<void> toggleSpeaker() async {
    if (!_features.speakerToggle || kIsWeb) return;
    final engine = _engine;
    if (engine == null) return;
    _isSpeakerEnabled = !_isSpeakerEnabled;
    _notify();
    try {
      await engine.setEnableSpeakerphone(_isSpeakerEnabled);
    } catch (e) {
      _isSpeakerEnabled = !_isSpeakerEnabled;
      _notify();
    }
  }

  Future<void> setBeautyEnabled(bool value) async {
    if (!_features.beautyFilter || kIsWeb) return;
    _beautyEnabled = value;
    await _applyBeauty();
  }

  Future<void> setBeautyLevels({double? smoothness, double? brightness}) async {
    if (!_features.beautyFilter || kIsWeb) return;
    if (smoothness != null) _beautyLevel = smoothness;
    if (brightness != null) _brightnessLevel = brightness;
    await _applyBeauty();
  }

  Future<void> _applyBeauty() async {
    _notify();
    final engine = _engine;
    if (engine == null || !_hasCamera || kIsWeb) return;
    try {
      await engine.setBeautyEffectOptions(
        enabled: _beautyEnabled,
        options: BeautyOptions(
          lighteningContrastLevel:
              LighteningContrastLevel.lighteningContrastNormal,
          lighteningLevel: _brightnessLevel,
          smoothnessLevel: _beautyLevel,
          rednessLevel: 0.1,
          sharpnessLevel: 0.3,
        ),
      );
    } catch (e) {
      teleconsultationLog('Beauty error: $e');
    }
  }

  Future<void> toggleScreenShare() async {
    if (!_features.screenShare || !canScreenShare) return;
    final engine = _engine;
    if (engine == null) return;
    final start = !_isScreenSharing;
    try {
      if (start) {
        await engine.startScreenCapture(
          const ScreenCaptureParameters2(
            captureAudio: true,
            captureVideo: true,
          ),
        );
        await engine.updateChannelMediaOptions(
          const ChannelMediaOptions(
            publishScreenTrack: true,
            publishCameraTrack: false,
          ),
        );
      } else {
        await engine.stopScreenCapture();
        await engine.updateChannelMediaOptions(
          ChannelMediaOptions(
            publishScreenTrack: false,
            publishCameraTrack: _hasCamera && _isVideoEnabled,
          ),
        );
      }
      _isScreenSharing = start;
    } catch (e) {
      teleconsultationLog('Screen share error: $e');
      _isScreenSharing = false;
    }
    _notify();
  }

  Future<void> toggleNoiseSuppression(bool enable) async {
    if (!_features.noiseSuppression || kIsWeb) return;
    _noiseSuppressionEnabled = enable;
    _notify();
    final engine = _engine;
    if (engine == null) return;
    try {
      await engine.setAINSMode(
        enabled: enable,
        mode: AudioAinsMode.ainsModeBalanced,
      );
    } catch (_) {}
  }

  void toggleStats() {
    if (!_features.callStats) return;
    _showStats = !_showStats;
    _notify();
  }

  // =======================================================================
  // FLOATING PIP
  // =======================================================================

  void minimizeCall(BuildContext context) {
    if (!_features.floatingPip || _isMinimized || _engine == null) return;
    final overlay =
        navigatorKey?.currentState?.overlay ??
        Overlay.maybeOf(context, rootOverlay: true);
    final nav = navigatorKey?.currentState ?? Navigator.of(context);

    _isMinimized = true;
    if (nav.canPop()) nav.pop();
    _attachPipOverlay(overlay);
    _notify();
  }

  void restoreFullScreen(BuildContext context) {
    if (!_isMinimized) return;
    final nav = navigatorKey?.currentState ?? Navigator.maybeOf(context);
    _removePipOverlay();
    _isMinimized = false;
    _notify();
    nav?.push(
      MaterialPageRoute(builder: (_) => const TeleConsultationCallView()),
    );
  }

  void _attachPipOverlay(OverlayState? overlay) {
    _removePipOverlay();
    if (overlay == null) return;
    _pipOverlayEntry = OverlayEntry(
      builder: (_) => const TeleConsultationFloatingPip(),
    );
    overlay.insert(_pipOverlayEntry!);
  }

  void _removePipOverlay() {
    _pipOverlayEntry?.remove();
    _pipOverlayEntry?.dispose();
    _pipOverlayEntry = null;
  }

  // =======================================================================
  // END
  // =======================================================================

  /// Web only. Opens call in new tab, then leaves this one.
  Future<void> popOutToNewTab({BuildContext? context}) async {
    if (!_features.popOutNewTab || !kIsWeb || _config == null) return;
    final url = _config!.toWebUrl(Uri.base.origin);
    await launchUrl(Uri.parse(url), webOnlyWindowName: '_blank');
    if (context != null && !context.mounted) return;
    await endCall(context: context, notifyEnd: false);
  }

  Future<void> _teardownEngine() async {
    final engine = _engine;
    final handler = _handler;
    _engine = null;
    _handler = null;
    _stopCallTimer();
    if (engine == null) return;
    try {
      if (handler != null) engine.unregisterEventHandler(handler);
    } catch (_) {}
    try {
      await engine.leaveChannel();
    } catch (e) {
      teleconsultationLog('leaveChannel error: $e');
    }
    try {
      await engine.release();
    } catch (e) {
      teleconsultationLog('release error: $e');
    }
  }

  Future<void> endCall({BuildContext? context, bool notifyEnd = true}) async {
    _sessionId++; // cancel any in-flight init
    _removePipOverlay();
    _isMinimized = false;
    _status = CallStatus.ended;
    _notify();

    await _teardownEngine();

    _remoteUid = null;
    _remoteVideoEnabled = false;
    _localUid = null;

    final cb = _onEndCallCallback;
    _onEndCallCallback = null;
    if (notifyEnd) cb?.call();

    _notify();

    if (context != null && context.mounted) {
      final nav = Navigator.of(context);
      if (nav.canPop()) nav.pop();
    }
  }

  @override
  void dispose() {
    _stopCallTimer();
    _removePipOverlay();
    unawaited(_teardownEngine());
    super.dispose();
  }
}
