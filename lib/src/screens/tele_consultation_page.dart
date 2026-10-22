import 'package:flutter/material.dart';

import '../config/teleconsultation_config.dart';
import '../config/teleconsultation_feature_config.dart';
import '../controllers/tele_consultation_controller.dart';
import '../models/teleconsultation_clinical_data.dart';
import 'tele_consultation_call_view.dart';

class TeleConsultationPage extends StatefulWidget {
  final TeleconsultationConfig config;
  final VoidCallback onEndCall;
  final TeleconsultationFeatures? features;
  final TeleconsultationVideoConfig? videoConfig;
  final TeleconsultationClinicalDataProvider? clinicalDataProvider;
  final Future<String?> Function()? onRefreshToken;

  const TeleConsultationPage({
    super.key,
    required this.config,
    required this.onEndCall,
    this.features,
    this.videoConfig,
    this.clinicalDataProvider,
    this.onRefreshToken,
  });

  @override
  State<TeleConsultationPage> createState() => _TeleConsultationPageState();
}

class _TeleConsultationPageState extends State<TeleConsultationPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      TeleConsultationController.instance.initCall(
        config: widget.config,
        features: widget.features,
        videoConfig: widget.videoConfig,
        clinicalDataProvider: widget.clinicalDataProvider,
        onEndCall: widget.onEndCall,
        onRefreshToken: widget.onRefreshToken,
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return const TeleConsultationCallView();
  }
}

/// Alias matching requested public API naming convention
typedef TeleconsultationScreen = TeleConsultationPage;
