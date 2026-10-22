import 'package:flutter/foundation.dart';

void teleconsultationLog(dynamic message, {String logName = 'Teleconsultation'}) {
  if (kDebugMode) {
    debugPrint('[$logName] $message');
  }
}
