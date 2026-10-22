# HMIS Teleconsultation Package (`hmis_teleconsultation`)

A modular, self-contained Flutter plugin package providing Agora RTC-based Teleconsultation, Video & Audio calling, PiP overlay, and channel lifecycle management for HMIS (Web, Android, iOS).

---

## Key Enhancements in this Release

1. **Clear Video on Desktop Web (Doctor Landscape <-> Phone Patient Portrait)**:
   - Dynamic aspect-ratio tracking (`remoteAspectRatio` computed live from `onVideoSizeChanged` and `onRemoteVideoStats`).
   - "Patient focus" layout on desktop web: patient video container matches remote portrait aspect ratio (letterboxed, centered, no zooming/cropping).
   - "Side-by-side" layout on desktop web: doctor and patient in balanced side-by-side views.
   - Dynamic render mode toggle between **Fit** (`RenderModeType.renderModeFit`, default for mismatched aspect ratios) and **Fill** (`RenderModeType.renderModeHidden`).
   - Video encoder preset: default **HD 720p @ 30fps (1800kbps)** with `maintainQuality` degradation preference (maintains crisp detail over high framerate for clinical diagnostics).
   - Dual-stream mode enabled (`SimulcastStreamMode.autoSimulcastStream`) and remote stream explicitly requests `VideoStreamType.videoStreamHigh` for main video.

2. **Voice & Audio Enhancement**:
   - Audio profile: `AudioProfileType.audioProfileSpeechStandard` (speech-optimized, mono, 32kHz).
   - Audio scenario: `AudioScenarioType.audioScenarioMeeting` (acoustic echo cancellation, noise suppression).
   - Native AI Noise Suppression (`setAINSMode` on Android/iOS/macOS/Windows; Web uses browser WebRTC AGC/AEC/ANS).
   - Speaking indicators (`localSpeaking`, `remoteSpeaking`) via `enableAudioVolumeIndication`.
   - Audio output / speaker selection on Web/Desktop via `AudioDeviceManager.enumeratePlaybackDevices()`.

3. **Single Source of Truth Feature Configuration (`TeleconsultationFeatures`)**:
   - Centrally configure and toggle capabilities per hospital, per consultation type, or per role.
   - Enforced in `TeleConsultationController` (disabled flags block both UI and controller APIs).
   - Named presets: `standardVideo`, `audioOnly`, `followUp`, `secondOpinion`.

4. **Clinical HMIS Integration**:
   - In-call clinical side panel (desktop) and bottom sheet (mobile) for demographics, vitals, allergies, past visits.
   - Consultation notes with auto-save callback.
   - Quick prescription shortcut button.
   - Fully decoupled via `TeleconsultationClinicalDataProvider` contract.

5. **Single-Center-State Waiting Screen & ParticipantAvatar (Fix for Overlapping UI)**:
   - Fixed ghost 'Y' avatar and blurry double text during "Ringing… waiting for patient to join".
   - State machine guarantees only ONE central UI state is rendered.
   - `ParticipantAvatar` correctly handles non-Latin graphemes (Gujarati `મ`, Hindi `रा`), accents, trimmed spaces, and long names.
   - Clear camera/mic unavailable warning banner with a "Check devices" recovery action without dropping call.

---

## Feature Flag Reference (`TeleconsultationFeatures`)

| Flag Name | Default | Platforms | Description / What it Controls |
|---|---|---|---|
| `screenShare` | `true` | Web, Desktop | Enables screen sharing track (`publishScreenTrack`). Blocked on unsupported platforms. |
| `chat` | `false` | All | In-call text messaging interface (requires backend RTM/WebSocket). |
| `fileShare` | `false` | All | In-call medical document / report sharing. |
| `recording` | `false` | Server-side | Client trigger/consent UI for Agora Cloud Recording (server-side). |
| `beautyFilter` | `true` | Android, iOS | Skin smoothing and lighting enhancement (`setBeautyEffectOptions`). Hidden on Web. |
| `noiseSuppression` | `true` | Android, iOS | AI Noise Suppression (`setAINSMode`). Hidden on Web (Web uses browser WebRTC ANS). |
| `callStats` | `true` | All | Diagnostic overlay displaying live video resolution, fps, bitrate, and network quality. |
| `floatingPip` | `true` | All | Draggable floating picture-in-picture window overlay on call minimize. |
| `popOutNewTab` | `true` | Web only | Opens consultation in an independent browser tab (`_blank`). |
| `deviceSelection` | `true` | Web, Desktop | Multi-device camera, microphone, and speaker selection dropdowns. |
| `cameraFlip` | `true` | Android, iOS, Web | Switches between front/back camera (or next camera on Web). |
| `speakerToggle` | `true` | Android, iOS | Toggles between device loudspeaker and earpiece (`setEnableSpeakerphone`). |
| `layoutToggle` | `true` | Desktop / Web | Toggles between "Patient focus" and "Side-by-side" layout. |
| `fitFillToggle` | `true` | All | Toggles remote video render mode between Fit (`renderModeFit`) and Fill (`renderModeHidden`). |
| `fullscreen` | `true` | Web | Toggles browser native fullscreen mode via HTML5 Fullscreen API. |
| `preCallLobby` | `false` | All | Pre-call device check, mic level meter, and test lobby before joining channel. |
| `waitingRoom` | `true` | All | Waiting UI state while waiting for remote peer to join. |
| `patientInfoPanel` | `true` | All | Clinical side panel (desktop) / bottom sheet (mobile) showing demographics, vitals, allergies. |
| `consultationNotes` | `true` | All | In-call clinical observations notes field with save callback. |
| `prescriptionShortcut`| `true` | All | Quick "Write Prescription" button triggering host app prescription workflow. |
| `networkTest` | `false` | All | Pre-call network probe and bandwidth assessment. |
| `endCallConfirm` | `true` | All | Confirmation dialog before ending the consultation. |
| `autoHideControls` | `true` | All | Automatically hides header and dock after inactivity delay during connected calls. |
| `keepScreenAwake` | `true` | Mobile | Keeps device display awake during consultation. |
| `callFeedback` | `false` | All | Post-call rating and feedback dialog. |
| `audioOnlyFallback` | `true` | All | Automatically prioritizes audio bitrate when network quality is poor/down. |

---

## Video Configuration Reference (`TeleconsultationVideoConfig`)

| Preset | Resolution | Frame Rate | Target Bitrate | Min Bitrate | Ideal Use Case |
|---|---|---|---|---|---|
| `hd` (Default) | 1280 × 720 (720p) | 30 fps | 1800 kbps | 400 kbps | High-clarity medical consultation (Doctor desktop & broadband). |
| `standard` | 960 × 540 (540p) | 24 fps | 1000 kbps | 300 kbps | Standard 4G mobile consultation. |
| `low` | 640 × 360 (360p) | 15 fps | 400 kbps | 150 kbps | Low-bandwidth mobile data / rural clinic data saver mode. |

- **Degradation Preference**: `DegradationPreference.maintainQuality` ensures resolution and clinical clarity are maintained when network fluctuates, sacrificing framerate rather than turning blurry.
- **Orientation Mode**: `OrientationMode.orientationModeAdaptive` adapts to phone portrait/landscape rotation.
- **Default Fit Mode**: `defaultFitMode: true` uses `RenderModeType.renderModeFit` to guarantee portrait video is not cropped on landscape displays.

---

## Platform Support Matrix

| Feature | Android | iOS | Web |
|---|---|---|---|
| Agora Video & Audio | Yes | Yes | Yes |
| HD 720p Video Encoding | Yes | Yes | Yes |
| RenderMode Fit / Fill Toggle | Yes | Yes | Yes |
| Dual-Stream (High / Low) | Yes | Yes | Yes |
| Patient Focus Layout | Yes | Yes | Yes |
| Side-by-side Layout | Yes | Yes | Yes |
| Speaking Indicator (VAD) | Yes | Yes | Yes |
| Device Selection Dropdowns | N/A | N/A | Yes |
| Speaker / Earpiece Toggle | Yes | Yes | N/A (OS / browser handled) |
| Native AI Noise Suppression | Yes | Yes | N/A (handled via WebRTC browser constraints) |
| Touch Up / Beauty Filter | Yes | Yes | N/A (Iris Web limitation) |
| Browser Fullscreen API | N/A | N/A | Yes |
| Draggable Floating PiP | Yes | Yes | Yes |
| Clinical Side Panel | Bottom Sheet | Bottom Sheet | Side Panel |

---

## Usage Example

### Starting a Call with Features and Clinical Provider

```dart
import 'package:hmis_teleconsultation/hmis_teleconsultation.dart';

void openConsultation(BuildContext context, TeleconsultationConfig config) {
  Navigator.push(
    context,
    MaterialPageRoute(
      builder: (_) => TeleConsultationPage(
        config: config,
        features: TeleconsultationFeatures.standardVideo(),
        videoConfig: TeleconsultationVideoConfig.hd(),
        clinicalDataProvider: MyHospitalClinicalDataProvider(),
        onEndCall: () {
          // Handle backend session termination
        },
      ),
    ),
  );
}
```

### Implementing `TeleconsultationClinicalDataProvider`

```dart
class MyHospitalClinicalDataProvider implements TeleconsultationClinicalDataProvider {
  @override
  PatientClinicalInfo? get patientInfo => PatientClinicalInfo(
    uhid: 'UHID-98213',
    patientName: 'Mayani Tisha',
    age: '28 Y',
    gender: 'Female',
    contactNumber: '+91 98765 43210',
    allergies: ['Penicillin', 'Sulfa drugs'],
    vitals: PatientVitals(
      bloodPressure: '120/80 mmHg',
      pulse: '74 bpm',
      spo2: '99%',
      temperature: '98.4 °F',
      weight: '62 kg',
      bmi: '22.4',
    ),
    pastVisits: [
      PatientVisitRecord(
        date: '12 Sep 2026',
        doctorName: 'Dr. Patel',
        diagnosis: 'Acute Pharyngitis',
        notes: 'Advised rest and warm fluids.',
      ),
    ],
  );

  @override
  void onSaveConsultationNotes(String notes) {
    // Save to EMR backend
  }

  @override
  void onPrescriptionRequested() {
    // Open prescription creator in host app
  }

  @override
  void onAddAttachmentRequested() {
    // File upload workflow
  }
}
```

---

## Verification & Testing

Run all unit & widget tests:
```bash
cd packages/hmis_teleconsultation
flutter test
flutter analyze
```
All tests verify feature configs, controller enforcement, aspect ratio layout containers, grapheme extraction, and single-avatar waiting state tree assertions.
# teleconsultation
