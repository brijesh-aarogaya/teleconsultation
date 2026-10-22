/// HMIS Teleconsultation package
/// Provides self-contained Agora RTC-based video & audio teleconsultation functionality.
library;

// Configuration & Feature Flags
export 'src/config/teleconsultation_config.dart';
export 'src/config/teleconsultation_feature_config.dart';

// Clinical Data Models & Interfaces
export 'src/models/teleconsultation_clinical_data.dart';


// Controller, CallStatus & CallStats
export 'src/controllers/tele_consultation_controller.dart';

// Screens & Views
export 'src/screens/tele_consultation_page.dart';
export 'src/screens/tele_consultation_call_view.dart';

// Widgets
export 'src/widgets/participant_avatar.dart';
export 'src/widgets/tele_consultation_clinical_panel.dart';
export 'src/widgets/tele_consultation_floating_pip.dart';
export 'src/widgets/tele_consultation_settings_sheet.dart';
export 'src/widgets/tele_consultation_stats_overlay.dart';
export 'src/widgets/tele_consultation_video_slot.dart';

// Utilities
export 'src/utils/teleconsultation_logger.dart';
export 'src/utils/web_agora_script_loader.dart';
export 'src/utils/web_device_checker.dart';
export 'src/utils/web_fullscreen.dart';
