import 'package:flutter/foundation.dart';

/// Patient vitals data model for the in-call clinical panel.
@immutable
class PatientVitals {
  final String? bloodPressure; // e.g. "120/80 mmHg"
  final String? pulse; // e.g. "72 bpm"
  final String? spo2; // e.g. "98%"
  final String? temperature; // e.g. "98.6 °F"
  final String? weight; // e.g. "68 kg"
  final String? height; // e.g. "172 cm"
  final String? bmi; // e.g. "23.0"
  final String? recordedAt;

  const PatientVitals({
    this.bloodPressure,
    this.pulse,
    this.spo2,
    this.temperature,
    this.weight,
    this.height,
    this.bmi,
    this.recordedAt,
  });

  Map<String, dynamic> toJson() => {
    'bloodPressure': bloodPressure,
    'pulse': pulse,
    'spo2': spo2,
    'temperature': temperature,
    'weight': weight,
    'height': height,
    'bmi': bmi,
    'recordedAt': recordedAt,
  };

  factory PatientVitals.fromJson(Map<String, dynamic> json) => PatientVitals(
    bloodPressure: json['bloodPressure'] as String?,
    pulse: json['pulse'] as String?,
    spo2: json['spo2'] as String?,
    temperature: json['temperature'] as String?,
    weight: json['weight'] as String?,
    height: json['height'] as String?,
    bmi: json['bmi'] as String?,
    recordedAt: json['recordedAt'] as String?,
  );
}

/// Past visit or consultation record.
@immutable
class PatientVisitRecord {
  final String date;
  final String doctorName;
  final String diagnosis;
  final String? notes;

  const PatientVisitRecord({
    required this.date,
    required this.doctorName,
    required this.diagnosis,
    this.notes,
  });

  Map<String, dynamic> toJson() => {
    'date': date,
    'doctorName': doctorName,
    'diagnosis': diagnosis,
    'notes': notes,
  };

  factory PatientVisitRecord.fromJson(Map<String, dynamic> json) =>
      PatientVisitRecord(
        date: json['date'] as String? ?? '',
        doctorName: json['doctorName'] as String? ?? '',
        diagnosis: json['diagnosis'] as String? ?? '',
        notes: json['notes'] as String?,
      );
}

/// Patient demographic and clinical info for display in the teleconsultation panel.
@immutable
class PatientClinicalInfo {
  final String? uhid;
  final String? patientName;
  final String? age;
  final String? gender;
  final String? contactNumber;
  final List<String> allergies;
  final List<String> chronicConditions;
  final PatientVitals? vitals;
  final List<PatientVisitRecord> pastVisits;

  const PatientClinicalInfo({
    this.uhid,
    this.patientName,
    this.age,
    this.gender,
    this.contactNumber,
    this.allergies = const [],
    this.chronicConditions = const [],
    this.vitals,
    this.pastVisits = const [],
  });

  Map<String, dynamic> toJson() => {
    'uhid': uhid,
    'patientName': patientName,
    'age': age,
    'gender': gender,
    'contactNumber': contactNumber,
    'allergies': allergies,
    'chronicConditions': chronicConditions,
    'vitals': vitals?.toJson(),
    'pastVisits': pastVisits.map((v) => v.toJson()).toList(),
  };

  factory PatientClinicalInfo.fromJson(Map<String, dynamic> json) =>
      PatientClinicalInfo(
        uhid: json['uhid'] as String?,
        patientName: json['patientName'] as String?,
        age: json['age'] as String?,
        gender: json['gender'] as String?,
        contactNumber: json['contactNumber'] as String?,
        allergies:
            (json['allergies'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        chronicConditions:
            (json['chronicConditions'] as List<dynamic>?)
                ?.map((e) => e.toString())
                .toList() ??
            const [],
        vitals: json['vitals'] != null
            ? PatientVitals.fromJson(json['vitals'] as Map<String, dynamic>)
            : null,
        pastVisits:
            (json['pastVisits'] as List<dynamic>?)
                ?.map(
                  (e) => PatientVisitRecord.fromJson(e as Map<String, dynamic>),
                )
                .toList() ??
            const [],
      );
}

/// Abstract contract implemented by host applications to provide clinical data
/// without coupling the package to any specific host app data layer.
abstract class TeleconsultationClinicalDataProvider {
  PatientClinicalInfo? get patientInfo;
  void onSaveConsultationNotes(String notes);
  void onPrescriptionRequested();
  void onAddAttachmentRequested();
}
