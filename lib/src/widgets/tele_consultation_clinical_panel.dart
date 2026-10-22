import 'package:flutter/material.dart';

import '../controllers/tele_consultation_controller.dart';
import '../models/teleconsultation_clinical_data.dart';

/// In-call clinical side panel (desktop) or bottom sheet (mobile).
///
/// Displays patient demographics, allergies, vitals, past visits,
/// and allows the doctor to take consultation notes and trigger prescriptions.
class TeleConsultationClinicalPanel extends StatefulWidget {
  final VoidCallback? onClose;

  const TeleConsultationClinicalPanel({super.key, this.onClose});

  static Future<void> showBottomSheet(BuildContext context) {
    return showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      useRootNavigator: true,
      builder: (_) => const TeleConsultationClinicalPanel(),
    );
  }

  @override
  State<TeleConsultationClinicalPanel> createState() =>
      _TeleConsultationClinicalPanelState();
}

class _TeleConsultationClinicalPanelState
    extends State<TeleConsultationClinicalPanel> {
  final TextEditingController _notesController = TextEditingController();
  final TeleConsultationController c = TeleConsultationController.instance;

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  void _saveNotes() {
    final text = _notesController.text.trim();
    if (text.isNotEmpty) {
      c.clinicalDataProvider?.onSaveConsultationNotes(text);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Consultation notes saved'),
          duration: Duration(seconds: 2),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final info = c.clinicalDataProvider?.patientInfo;
    final f = c.features;

    return Container(
      width: 360,
      decoration: const BoxDecoration(
        color: Color(0xFF182229),
        border: Border(left: BorderSide(color: Colors.white12, width: 1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            color: const Color(0xFF1F2C34),
            child: Row(
              children: [
                const Icon(
                  Icons.medical_information_outlined,
                  color: Color(0xFF00A884),
                  size: 20,
                ),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Patient Clinical Info',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                if (widget.onClose != null)
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70, size: 18),
                    onPressed: widget.onClose,
                  ),
              ],
            ),
          ),

          // Scrollable Body
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                // Demographics
                _sectionHeader(Icons.person, 'Demographics'),
                _infoCard([
                  _infoRow('Name', info?.patientName ?? c.config?.patientName ?? 'Patient'),
                  if (info?.uhid != null) _infoRow('UHID / MRN', info!.uhid!),
                  if (info?.age != null || info?.gender != null)
                    _infoRow('Age / Gender', '${info?.age ?? '-'} / ${info?.gender ?? '-'}'),
                  if (info?.contactNumber != null)
                    _infoRow('Phone', info!.contactNumber!),
                ]),
                const SizedBox(height: 16),

                // Allergies
                if (info?.allergies != null && info!.allergies.isNotEmpty) ...[
                  _sectionHeader(Icons.warning_amber_rounded, 'Allergies', color: Colors.orangeAccent),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: info.allergies
                        .map(
                          (a) => Chip(
                            label: Text(a, style: const TextStyle(fontSize: 11, color: Colors.white)),
                            backgroundColor: Colors.redAccent.withValues(alpha: 0.25),
                            side: const BorderSide(color: Colors.redAccent, width: 0.8),
                          ),
                        )
                        .toList(),
                  ),
                  const SizedBox(height: 16),
                ],

                // Vitals
                if (info?.vitals != null) ...[
                  _sectionHeader(Icons.favorite_outline, 'Recent Vitals'),
                  _vitalsGrid(info!.vitals!),
                  const SizedBox(height: 16),
                ],

                // Consultation Notes
                if (f.consultationNotes) ...[
                  _sectionHeader(Icons.edit_note, 'Consultation Notes'),
                  TextField(
                    controller: _notesController,
                    maxLines: 4,
                    style: const TextStyle(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Enter clinical observations, advice...',
                      hintStyle: const TextStyle(color: Colors.white38, fontSize: 12),
                      filled: true,
                      fillColor: Colors.white.withValues(alpha: 0.05),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Colors.white12),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10),
                        borderSide: const BorderSide(color: Color(0xFF00A884)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: ElevatedButton.icon(
                      onPressed: _saveNotes,
                      icon: const Icon(Icons.check, size: 14),
                      label: const Text('Save Notes', style: TextStyle(fontSize: 12)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF00A884),
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Quick Prescription Shortcut
                if (f.prescriptionShortcut) ...[
                  ElevatedButton.icon(
                    onPressed: () {
                      c.clinicalDataProvider?.onPrescriptionRequested();
                    },
                    icon: const Icon(Icons.receipt_long, size: 18),
                    label: const Text('Write Prescription'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent.shade700,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Past visits
                if (info?.pastVisits != null && info!.pastVisits.isNotEmpty) ...[
                  _sectionHeader(Icons.history, 'Past Consultations'),
                  ...info.pastVisits.map(
                    (v) => Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.04),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white10),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(v.date, style: const TextStyle(color: Colors.white54, fontSize: 11)),
                              Text(v.doctorName, style: const TextStyle(color: Color(0xFF00A884), fontSize: 11, fontWeight: FontWeight.bold)),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(v.diagnosis, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                          if (v.notes != null) ...[
                            const SizedBox(height: 2),
                            Text(v.notes!, style: const TextStyle(color: Colors.white70, fontSize: 11)),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _sectionHeader(IconData icon, String title, {Color color = const Color(0xFF00A884)}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          Icon(icon, color: color, size: 16),
          const SizedBox(width: 6),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _infoCard(List<Widget> children) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.white12),
      ),
      child: Column(children: children),
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.white54, fontSize: 12)),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _vitalsGrid(PatientVitals vitals) {
    final items = <MapEntry<String, String>>[
      if (vitals.bloodPressure != null) MapEntry('BP', vitals.bloodPressure!),
      if (vitals.pulse != null) MapEntry('Pulse', vitals.pulse!),
      if (vitals.spo2 != null) MapEntry('SpO2', vitals.spo2!),
      if (vitals.temperature != null) MapEntry('Temp', vitals.temperature!),
      if (vitals.weight != null) MapEntry('Weight', vitals.weight!),
      if (vitals.bmi != null) MapEntry('BMI', vitals.bmi!),
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: items.map((entry) {
        return Container(
          width: 96,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(entry.key, style: const TextStyle(color: Colors.white54, fontSize: 10)),
              const SizedBox(height: 2),
              Text(
                entry.value,
                style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}
