import 'package:flutter_test/flutter_test.dart';
import 'package:hmis_teleconsultation/hmis_teleconsultation.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  group('TeleconsultationFeatures Tests', () {
    test('standardVideo preset has default enabled flags', () {
      final f = TeleconsultationFeatures.standardVideo();
      expect(f.screenShare, isTrue);
      expect(f.callStats, isTrue);
      expect(f.floatingPip, isTrue);
      expect(f.fitFillToggle, isTrue);
      expect(f.layoutToggle, isTrue);
      expect(f.patientInfoPanel, isTrue);
      expect(f.consultationNotes, isTrue);
      expect(f.prescriptionShortcut, isTrue);
      expect(f.chat, isFalse);
      expect(f.fileShare, isFalse);
      expect(f.recording, isFalse);
    });

    test('audioOnly preset disables video-related features', () {
      final f = TeleconsultationFeatures.audioOnly();
      expect(f.screenShare, isFalse);
      expect(f.beautyFilter, isFalse);
      expect(f.cameraFlip, isFalse);
      expect(f.fitFillToggle, isFalse);
      expect(f.fullscreen, isFalse);
      expect(f.layoutToggle, isFalse);
      expect(f.patientInfoPanel, isTrue);
      expect(f.consultationNotes, isTrue);
    });

    test('followUp preset has expected flags', () {
      final f = TeleconsultationFeatures.followUp();
      expect(f.screenShare, isFalse);
      expect(f.preCallLobby, isFalse);
      expect(f.patientInfoPanel, isTrue);
      expect(f.consultationNotes, isTrue);
      expect(f.prescriptionShortcut, isTrue);
      expect(f.callFeedback, isTrue);
    });

    test('secondOpinion preset enables collaboration features', () {
      final f = TeleconsultationFeatures.secondOpinion();
      expect(f.screenShare, isTrue);
      expect(f.layoutToggle, isTrue);
      expect(f.patientInfoPanel, isTrue);
      expect(f.consultationNotes, isTrue);
      expect(f.fullscreen, isTrue);
    });

    test('toJson and fromJson round trip preserves all flags', () {
      const original = TeleconsultationFeatures(
        screenShare: false,
        chat: true,
        fileShare: true,
        recording: true,
        beautyFilter: false,
        noiseSuppression: false,
        callStats: false,
        floatingPip: false,
        popOutNewTab: false,
        deviceSelection: false,
        cameraFlip: false,
        speakerToggle: false,
        layoutToggle: false,
        fitFillToggle: false,
        fullscreen: false,
        preCallLobby: true,
        waitingRoom: false,
        patientInfoPanel: false,
        consultationNotes: false,
        prescriptionShortcut: false,
        networkTest: true,
        endCallConfirm: false,
        autoHideControls: false,
        keepScreenAwake: false,
        callFeedback: true,
        audioOnlyFallback: false,
      );

      final json = original.toJson();
      final reconstructed = TeleconsultationFeatures.fromJson(json);

      expect(reconstructed, equals(original));
    });

    test('copyWith updates specified fields correctly', () {
      final f = TeleconsultationFeatures.standardVideo();
      final updated = f.copyWith(
        screenShare: false,
        chat: true,
        recording: true,
      );

      expect(updated.screenShare, isFalse);
      expect(updated.chat, isTrue);
      expect(updated.recording, isTrue);
      expect(updated.floatingPip, isTrue); // unchanged
    });
  });

  group('TeleconsultationVideoConfig Tests', () {
    test('hd preset has 720p dimensions and 1800kbps bitrate', () {
      final cfg = TeleconsultationVideoConfig.hd();
      expect(cfg.preset, equals(VideoQualityPreset.hd));
      expect(cfg.width, equals(1280));
      expect(cfg.height, equals(720));
      expect(cfg.frameRate, equals(30));
      expect(cfg.bitrate, equals(1800));
      expect(cfg.defaultFitMode, isTrue);
    });

    test('standard preset has 540p dimensions', () {
      final cfg = TeleconsultationVideoConfig.standard();
      expect(cfg.preset, equals(VideoQualityPreset.standard));
      expect(cfg.width, equals(960));
      expect(cfg.height, equals(540));
      expect(cfg.frameRate, equals(24));
    });

    test('low preset has 360p dimensions for data saving', () {
      final cfg = TeleconsultationVideoConfig.low();
      expect(cfg.preset, equals(VideoQualityPreset.low));
      expect(cfg.width, equals(640));
      expect(cfg.height, equals(360));
      expect(cfg.frameRate, equals(15));
      expect(cfg.bitrate, equals(400));
    });

    test('toJson and fromJson round trip preserves video configuration', () {
      final original = TeleconsultationVideoConfig.hd();
      final json = original.toJson();
      final reconstructed = TeleconsultationVideoConfig.fromJson(json);

      expect(reconstructed.preset, equals(original.preset));
      expect(reconstructed.width, equals(original.width));
      expect(reconstructed.height, equals(original.height));
      expect(reconstructed.frameRate, equals(original.frameRate));
      expect(reconstructed.bitrate, equals(original.bitrate));
      expect(reconstructed.defaultFitMode, equals(original.defaultFitMode));
    });
  });

  group('Controller Feature Flag Enforcement Tests', () {
    test('disabled fitFillToggle blocks toggleFitFill', () {
      final controller = TeleConsultationController.instance;
      final initialFit = controller.isFitMode;

      // Set features with fitFillToggle disabled
      controller.initCall(
        config: const TeleconsultationConfig(
          channelId: 'test_ch',
          token: 'token',
          uid: 1,
          web: false,
        ),
        features: const TeleconsultationFeatures(fitFillToggle: false),
      );

      controller.toggleFitFill();
      // Should remain unchanged because feature is disabled
      expect(controller.isFitMode, equals(initialFit));
    });

    test('disabled layoutToggle blocks toggleDesktopLayout', () {
      final controller = TeleConsultationController.instance;
      final initialLayout = controller.desktopLayout;

      controller.initCall(
        config: const TeleconsultationConfig(
          channelId: 'test_ch2',
          token: 'token',
          uid: 2,
          web: false,
        ),
        features: const TeleconsultationFeatures(layoutToggle: false),
      );

      controller.toggleDesktopLayout();
      expect(controller.desktopLayout, equals(initialLayout));
    });

    test('disabled callStats blocks toggleStats', () {
      final controller = TeleConsultationController.instance;

      controller.initCall(
        config: const TeleconsultationConfig(
          channelId: 'test_ch3',
          token: 'token',
          uid: 3,
          web: false,
        ),
        features: const TeleconsultationFeatures(callStats: false),
      );

      if (controller.showStats) {
        controller.toggleStats(); // make sure it's false
      }
      expect(controller.showStats, isFalse);

      controller.toggleStats();
      // Should stay false because callStats feature flag is false
      expect(controller.showStats, isFalse);
    });

    test('aspect ratio calculation detects portrait orientation', () {
      final controller = TeleConsultationController.instance;
      // Default aspect ratio when unknown is 16/9 (~1.78)
      expect(controller.isRemotePortrait, isFalse);
      expect(controller.remoteAspectRatio, closeTo(16 / 9, 0.01));
    });
  });
}
