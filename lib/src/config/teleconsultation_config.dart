class TeleconsultationConfig {
  static String defaultAppId = "9fc56c46632c4768b624b4877b65f5ab";

  final String? channelId;
  final String? token;
  final int? uid;
  final bool web;
  final String? appId;
  final String? patientName;
  final String? doctorName;
  final String? appointmentId;
  final String? sessionToken;

  const TeleconsultationConfig({
    required this.channelId,
    required this.token,
    required this.uid,
    required this.web,
    this.appId,
    this.patientName,
    this.doctorName,
    this.appointmentId,
    this.sessionToken,
  });

  factory TeleconsultationConfig.fromUri(Uri uri) {
    final params = uri.queryParameters;
    int? parsedUid;
    if (params['uid'] != null) {
      parsedUid = int.tryParse(params['uid']!);
    }
    return TeleconsultationConfig(
      channelId: params['channelId'],
      token: params['token'],
      uid: parsedUid,
      web: params['web'] == 'true' || params['isWeb'] == 'true',
      appId: params['appId'],
      patientName: params['patientName'],
      doctorName: params['doctorName'],
      appointmentId: params['appointmentId'],
      sessionToken: params['sessionToken'],
    );
  }

  TeleconsultationConfig copyWith({
    String? channelId,
    String? token,
    int? uid,
    bool? web,
    String? appId,
    String? patientName,
    String? doctorName,
    String? appointmentId,
    String? sessionToken,
  }) {
    return TeleconsultationConfig(
      channelId: channelId ?? this.channelId,
      token: token ?? this.token,
      uid: uid ?? this.uid,
      web: web ?? this.web,
      appId: appId ?? this.appId,
      patientName: patientName ?? this.patientName,
      doctorName: doctorName ?? this.doctorName,
      appointmentId: appointmentId ?? this.appointmentId,
      sessionToken: sessionToken ?? this.sessionToken,
    );
  }

  String toWebUrl(String baseUrl) {
    final queryParams = <String, String>{
      if (web) 'web': web.toString(),
      'channelId': ?channelId,
      'token': ?token,
      'uid': ?uid?.toString(),
      'appId': ?appId,
      'patientName': ?patientName,
      'doctorName': ?doctorName,
      'appointmentId': ?appointmentId,
      'sessionToken': ?sessionToken,
    };
    final baseUri = Uri.parse(baseUrl);
    final finalUri = baseUri.replace(queryParameters: queryParams);
    return finalUri.toString();
  }
}

/// Backward compatibility alias for AgoraConfig
typedef AgoraConfig = TeleconsultationConfig;
