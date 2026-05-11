import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model_host.dart';
import '../services/pdf_service.dart';
import '../models/patient_model.dart';
import '../models/prediction_result.dart';
import 'patient_reports_screen.dart';

class DiagnosticPage extends StatefulWidget {
  const DiagnosticPage({super.key});

  @override
  State<DiagnosticPage> createState() => _DiagnosticPageState();
}

class _DiagnosticPageState extends State<DiagnosticPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  List<Patient> _recentPatients = [];
  bool _isLoadingPatients = false;
  int _totalReportsCount = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _loadRecentPatients();
    });
  }

  Future<void> _loadRecentPatients() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingPatients = true;
    });

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('patient_reports')
          .orderBy('createdAt', descending: true)
          .limit(5)
          .get();

      final patients = querySnapshot.docs.map((doc) {
        final data = doc.data();

        final ageData = data['age'];
        final age = ageData is int ? ageData :
        ageData is double ? ageData.toInt() :
        ageData is num ? ageData.toInt() : 0;

        final dateData = data['date'];
        final date = dateData is int ? dateData :
        dateData is Timestamp ? dateData.millisecondsSinceEpoch :
        DateTime.now().millisecondsSinceEpoch;

        return Patient.fromMap({
          'id': doc.id,
          'name': data['name'] ?? '',
          'phoneNumber': data['phoneNumber'] ?? '',
          'age': age,
          'gender': data['gender'] ?? 'Male',
          'date': date,
          'bloodGroup': data['bloodGroup'],
          'email': data['email'],
          'additionalNotes': data['additionalNotes'],
          'emotionResults': data['emotionResults'],
        });
      }).toList();

      final countSnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('patient_reports')
          .count()
          .get();

      setState(() {
        _recentPatients = patients;
        _totalReportsCount = countSnapshot.count ?? 0;
        _isLoadingPatients = false;
      });
    } catch (e) {
      print('Error loading patients: $e');
      setState(() {
        _isLoadingPatients = false;
      });
    }
  }

  Future<void> _savePatientToFirebase(Patient patient) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final patientData = {
        'userId': user.uid,
        'name': patient.name,
        'phoneNumber': patient.phoneNumber,
        'age': patient.age,
        'gender': patient.gender,
        'date': patient.date.millisecondsSinceEpoch,
        'bloodGroup': patient.bloodGroup,
        'email': patient.email,
        'additionalNotes': patient.additionalNotes,
        'createdAt': DateTime.now().millisecondsSinceEpoch,
        'emotionResults': patient.emotionResults?.toMap(),
      };

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('patient_reports')
          .add(patientData);

      print('Patient saved to Firebase');
      _loadRecentPatients();
    } catch (e) {
      print('Error saving patient: $e');
      rethrow;
    }
  }

  void _showPatientInfoDialog(BuildContext context) {
    final host = Provider.of<ModelHost>(context, listen: false);
    final actualEmotionResults = host.lastPredictionResult;

    showDialog(
      context: context,
      builder: (context) => PatientInfoDialog(
        emotionResults: actualEmotionResults,
        onPatientSaved: _savePatientToFirebase,
      ),
    ).then((_) {
      _loadRecentPatients();
    });
  }

  void _navigateToPatientReports(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const PatientReportsScreen(),
      ),
    );
  }

  void _navigateToPatientDetail(BuildContext context, Patient patient) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => PatientDetailScreen(patient: patient),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final host = context.watch<ModelHost>();
    final Color oliveGreen = const Color(0xFF556B2F);
    final Color lightOlive = const Color(0xFF8FBC8F);
    final Color backgroundColor = const Color(0xFFF8F9F7);
    final Color cardColor = Colors.white;

    return Container(
      color: backgroundColor,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Diagnostics',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  color: oliveGreen,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: lightOlive.withOpacity(0.3)),
                ),
                child: SelectableText(
                  host.status,
                  style: TextStyle(color: Colors.grey[700], fontSize: 12),
                ),
              ),
              const SizedBox(height: 12),

              _buildRecentPatientsSection(oliveGreen, lightOlive, cardColor),

              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _showPatientInfoDialog(context),
                  icon: const Icon(Icons.person_add, color: Colors.white, size: 18),
                  label: const Text('Add Patient', style: TextStyle(color: Colors.white, fontSize: 13)),
                  style: FilledButton.styleFrom(
                    backgroundColor: oliveGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: host.initModel,
                    icon: const Icon(Icons.restart_alt, color: Colors.white, size: 16),
                    label: const Text('Re-init', style: TextStyle(color: Colors.white, fontSize: 11)),
                    style: FilledButton.styleFrom(
                      backgroundColor: oliveGreen,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  OutlinedButton.icon(
                    onPressed: host.ready ? host.dryRun : null,
                    icon: Icon(Icons.play_arrow, color: host.ready ? oliveGreen : Colors.grey, size: 16),
                    label: Text('Dry run', style: TextStyle(color: host.ready ? oliveGreen : Colors.grey, fontSize: 11)),
                    style: OutlinedButton.styleFrom(
                      side: BorderSide(color: host.ready ? oliveGreen : Colors.grey, width: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  if (_totalReportsCount > 0)
                    FilledButton.icon(
                      onPressed: () => _navigateToPatientReports(context),
                      icon: const Icon(Icons.history, color: Colors.white, size: 16),
                      label: Text('Reports ($_totalReportsCount)', style: const TextStyle(color: Colors.white, fontSize: 11)),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.blue,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Logs',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: oliveGreen,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    color: cardColor,
                    border: Border.all(color: lightOlive.withOpacity(0.3)),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: const EdgeInsets.all(12),
                  child: ListView.builder(
                    itemCount: host.logs.length,
                    itemBuilder: (_, i) => Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Text(
                        host.logs[i],
                        style: TextStyle(color: Colors.grey[700], fontSize: 10, fontFamily: 'Monospace'),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentPatientsSection(Color oliveGreen, Color lightOlive, Color cardColor) {
    if (_isLoadingPatients) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: lightOlive.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: oliveGreen)),
            const SizedBox(width: 12),
            Text('Loading...', style: TextStyle(color: oliveGreen, fontSize: 11)),
          ],
        ),
      );
    }

    if (_recentPatients.isEmpty) {
      return Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: lightOlive.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: oliveGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
              child: Icon(Icons.person, color: oliveGreen, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('No Reports Yet', style: TextStyle(color: oliveGreen, fontWeight: FontWeight.w600, fontSize: 12)),
                  Text('Add your first patient', style: TextStyle(color: Colors.grey[600], fontSize: 10)),
                ],
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      constraints: const BoxConstraints(maxHeight: 180),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: lightOlive.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(color: oliveGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(14)),
                  child: Icon(Icons.recent_actors, color: oliveGreen, size: 14),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Recent Patients', style: TextStyle(color: oliveGreen, fontWeight: FontWeight.w600, fontSize: 12)),
                      Text('$_totalReportsCount total', style: TextStyle(color: Colors.grey[600], fontSize: 9)),
                    ],
                  ),
                ),
                if (_totalReportsCount > 5)
                  TextButton(
                    onPressed: () => _navigateToPatientReports(context),
                    style: TextButton.styleFrom(foregroundColor: Colors.blue, padding: EdgeInsets.zero, minimumSize: Size.zero, tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                    child: const Text('View All', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w500)),
                  ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _recentPatients.length,
              itemBuilder: (context, index) => _buildPatientItem(_recentPatients[index], oliveGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientItem(Patient patient, Color oliveGreen) {
    return InkWell(
      onTap: () => _navigateToPatientDetail(context, patient),
      child: Container(
        decoration: BoxDecoration(border: Border(top: BorderSide(color: Colors.grey[200]!))),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(color: oliveGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(16)),
              child: Center(
                child: Text(
                  patient.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(color: oliveGreen, fontWeight: FontWeight.bold, fontSize: 14),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(patient.name, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11, color: Colors.grey[800]), maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text('${patient.age} yrs • ${patient.gender}', style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                  Text(_formatDate(patient.date), style: TextStyle(fontSize: 8, color: Colors.grey[500])),
                ],
              ),
            ),
            Icon(Icons.chevron_right, color: oliveGreen, size: 18),
          ],
        ),
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final patientDate = DateTime(date.year, date.month, date.day);

    if (patientDate == today) return 'Today';
    final yesterday = DateTime(now.year, now.month, now.day - 1);
    if (patientDate == yesterday) return 'Yesterday';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${patientDate.day} ${months[patientDate.month - 1]}';
  }
}

class PatientInfoDialog extends StatefulWidget {
  final PredictionResult? emotionResults;
  final Function(Patient) onPatientSaved;

  const PatientInfoDialog({super.key, this.emotionResults, required this.onPatientSaved});

  @override
  _PatientInfoDialogState createState() => _PatientInfoDialogState();
}

class _PatientInfoDialogState extends State<PatientInfoDialog> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  String _selectedGender = 'Male';
  String _selectedBloodGroup = 'A+';
  final List<String> _genders = ['Male', 'Female', 'Other'];
  final List<String> _bloodGroups = ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'];

  bool _isGeneratingPDF = false;

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _generateAndSaveReport() async {
    if (_formKey.currentState!.validate()) {
      setState(() => _isGeneratingPDF = true);

      try {
        if (widget.emotionResults == null && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No emotion analysis data. Please run analysis first.'), backgroundColor: Colors.orange),
          );
          return;
        }

        final patient = Patient(
          name: _nameController.text,
          phoneNumber: _phoneController.text,
          age: int.parse(_ageController.text),
          gender: _selectedGender,
          date: DateTime.now(),
          emotionResults: widget.emotionResults,
          bloodGroup: _selectedBloodGroup,
          additionalNotes: _notesController.text.isNotEmpty ? _notesController.text : null,
          email: _emailController.text.isNotEmpty ? _emailController.text : null,
        );

        await widget.onPatientSaved(patient);

        final pdfService = PDFService();
        final pdfFile = await pdfService.generatePatientReport(patient);

        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Report saved and PDF generated!'), backgroundColor: Colors.green),
          );

          Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => PDFViewerScreen(pdfFile: pdfFile, patient: patient)));
        }
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
        }
      } finally {
        if (mounted) setState(() => _isGeneratingPDF = false);
      }
    }
  }

  Widget _buildEmotionPreview() {
    if (widget.emotionResults == null) {
      return Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: const Color(0xFF556B2F).withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF8FBC8F).withOpacity(0.3)),
        ),
        child: const Column(
          children: [
            Icon(Icons.info, color: Colors.grey, size: 20),
            SizedBox(height: 4),
            Text('No emotion data', style: TextStyle(color: Colors.grey, fontSize: 10), textAlign: TextAlign.center),
          ],
        ),
      );
    }

    final emotionResults = widget.emotionResults!;
    final sortedEmotions = emotionResults.sortedProbabilities;

    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.blue.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blue.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.emoji_emotions, color: Colors.blue, size: 14),
              const SizedBox(width: 6),
              const Expanded(child: Text('Emotion Analysis', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 11))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: _getConfidenceColor(emotionResults.topProb), borderRadius: BorderRadius.circular(8)),
                child: Text('${(emotionResults.topProb * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text('Primary: ${emotionResults.topLabel?.toUpperCase() ?? "UNKNOWN"}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
          const SizedBox(height: 4),
          ...sortedEmotions.take(2).map((entry) => Padding(
            padding: const EdgeInsets.symmetric(vertical: 1),
            child: Row(
              children: [
                Expanded(child: Text(entry.key, style: const TextStyle(fontSize: 9))),
                SizedBox(width: 30, child: LinearProgressIndicator(value: entry.value, backgroundColor: Colors.grey[300], color: _getConfidenceColor(entry.value), minHeight: 3)),
                const SizedBox(width: 4),
                SizedBox(width: 28, child: Text('${(entry.value * 100).toStringAsFixed(1)}%', style: TextStyle(fontSize: 8, fontWeight: FontWeight.bold, color: _getConfidenceColor(entry.value)))),
              ],
            ),
          )),
          if (sortedEmotions.length > 2) ...[
            const SizedBox(height: 2),
            Text('+ ${sortedEmotions.length - 2} more', style: const TextStyle(fontSize: 8, color: Colors.grey)),
          ],
        ],
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.7) return Colors.green;
    if (confidence > 0.5) return Colors.orange;
    return Colors.red;
  }

  @override
  Widget build(BuildContext context) {
    final Color oliveGreen = const Color(0xFF556B2F);
    final Color backgroundColor = const Color(0xFFF8F9F7);

    return Dialog(
      backgroundColor: backgroundColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.9, maxHeight: MediaQuery.of(context).size.height * 0.85),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: oliveGreen,
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), topRight: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(14)),
                    child: const Icon(Icons.person, color: Colors.white, size: 16),
                  ),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Patient Information', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                        Text('Save & generate PDF', style: TextStyle(color: Colors.white70, fontSize: 9)),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            if (widget.emotionResults != null) Padding(padding: const EdgeInsets.all(10), child: _buildEmotionPreview()),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(10),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildSectionHeader(icon: Icons.person_outline, title: 'Personal Info'),
                      const SizedBox(height: 6),
                      _buildTextField(controller: _nameController, label: 'Full Name', hintText: 'Enter name', prefixIcon: Icons.badge, validator: (v) => v == null || v.isEmpty ? 'Required' : null),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(flex: 2, child: _buildTextField(controller: _ageController, label: 'Age', hintText: 'Age', prefixIcon: Icons.cake, keyboardType: TextInputType.number, validator: (v) {
                            if (v == null || v.isEmpty) return 'Required';
                            final age = int.tryParse(v);
                            if (age == null || age < 1 || age > 120) return 'Invalid';
                            return null;
                          })),
                          const SizedBox(width: 6),
                          Expanded(flex: 3, child: _buildGenderDropdown()),
                        ],
                      ),
                      const SizedBox(height: 10),
                      _buildSectionHeader(icon: Icons.contact_phone, title: 'Contact Info'),
                      const SizedBox(height: 6),
                      _buildTextField(controller: _phoneController, label: 'Phone', hintText: '+92 300 0000000', prefixIcon: Icons.phone, keyboardType: TextInputType.phone, validator: (v) => v == null || v.isEmpty ? 'Required' : v.length < 10 ? 'Invalid' : null),
                      const SizedBox(height: 6),
                      _buildTextField(controller: _emailController, label: 'Email (Optional)', hintText: 'email@example.com', prefixIcon: Icons.email, keyboardType: TextInputType.emailAddress),
                      const SizedBox(height: 10),
                      _buildSectionHeader(icon: Icons.medical_services, title: 'Medical Info'),
                      const SizedBox(height: 6),
                      _buildBloodGroupDropdown(),
                      const SizedBox(height: 6),
                      _buildNotesField(),
                    ],
                  ),
                ),
              ),
            ),

            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: oliveGreen.withOpacity(0.3))),
                borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(16), bottomRight: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _isGeneratingPDF ? null : () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(foregroundColor: oliveGreen, side: BorderSide(color: oliveGreen), padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: const Text('Cancel', style: TextStyle(fontSize: 12)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton(
                      onPressed: _isGeneratingPDF ? null : _generateAndSaveReport,
                      style: FilledButton.styleFrom(backgroundColor: oliveGreen, padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                      child: _isGeneratingPDF
                          ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation(Colors.white)))
                          : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.save, size: 12), SizedBox(width: 4), Text('Save', style: TextStyle(fontSize: 12))]),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionHeader({required IconData icon, required String title}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(6),
      decoration: BoxDecoration(color: const Color(0xFF556B2F).withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF8FBC8F).withOpacity(0.3))),
      child: Row(
        children: [
          Container(width: 20, height: 20, decoration: BoxDecoration(color: const Color(0xFF556B2F), borderRadius: BorderRadius.circular(10)), child: Icon(icon, color: Colors.white, size: 10)),
          const SizedBox(width: 6),
          Text(title, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF556B2F))),
        ],
      ),
    );
  }

  Widget _buildTextField({required TextEditingController controller, required String label, required String hintText, required IconData prefixIcon, TextInputType keyboardType = TextInputType.text, String? Function(String?)? validator}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF556B2F))),
        const SizedBox(height: 3),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 2, offset: const Offset(0, 1))]),
          child: TextFormField(
            controller: controller,
            keyboardType: keyboardType,
            validator: validator,
            style: const TextStyle(fontSize: 11),
            decoration: InputDecoration(hintText: hintText, hintStyle: const TextStyle(fontSize: 10), prefixIcon: Icon(prefixIcon, color: const Color(0xFF556B2F), size: 14), border: OutlineInputBorder(borderRadius: BorderRadius.circular(6), borderSide: BorderSide.none), filled: true, fillColor: Colors.white, contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6), isDense: true),
          ),
        ),
      ],
    );
  }

  Widget _buildGenderDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Gender', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF556B2F))),
        const SizedBox(height: 3),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF8FBC8F).withOpacity(0.5))),
          child: DropdownButtonFormField<String>(
            value: _selectedGender,
            isDense: true,
            style: const TextStyle(fontSize: 11, color: Colors.black),
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 4), prefixIcon: Icon(Icons.people, size: 14), isDense: true),
            items: _genders.map((gender) => DropdownMenuItem<String>(value: gender, child: Text(gender, style: const TextStyle(fontSize: 10)))).toList(),
            onChanged: (v) => setState(() => _selectedGender = v!),
            validator: (v) => v == null || v.isEmpty ? 'Required' : null,
          ),
        ),
      ],
    );
  }

  Widget _buildBloodGroupDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Blood Group', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF556B2F))),
        const SizedBox(height: 3),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF8FBC8F).withOpacity(0.5))),
          child: DropdownButtonFormField<String>(
            value: _selectedBloodGroup,
            isDense: true,
            style: const TextStyle(fontSize: 11, color: Colors.black),
            decoration: const InputDecoration(border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 4), prefixIcon: Icon(Icons.bloodtype, size: 14), isDense: true),
            items: _bloodGroups.map((bg) => DropdownMenuItem<String>(value: bg, child: Text(bg, style: const TextStyle(fontSize: 10)))).toList(),
            onChanged: (v) => setState(() => _selectedBloodGroup = v!),
          ),
        ),
      ],
    );
  }

  Widget _buildNotesField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Notes (Optional)', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: Color(0xFF556B2F))),
        const SizedBox(height: 3),
        Container(
          decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(6), border: Border.all(color: const Color(0xFF8FBC8F).withOpacity(0.5))),
          child: TextFormField(controller: _notesController, maxLines: 1, style: const TextStyle(fontSize: 11), decoration: const InputDecoration(hintText: 'Additional information...', hintStyle: TextStyle(fontSize: 10), border: InputBorder.none, contentPadding: EdgeInsets.all(8), isDense: true)),
        ),
      ],
    );
  }
}

class PDFViewerScreen extends StatelessWidget {
  final File pdfFile;
  final Patient patient;

  const PDFViewerScreen({Key? key, required this.pdfFile, required this.patient}) : super(key: key);

  void _sharePDF(BuildContext context) async {
    try {
      await Share.shareXFiles([XFile(pdfFile.path)], text: 'EEG Emotion Analysis Report for ${patient.name}\n\nGenerated by NeuroEmotions', subject: 'EEG Report - ${patient.name}');
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error sharing PDF: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color oliveGreen = const Color(0xFF556B2F);
    final Color backgroundColor = const Color(0xFFF8F9F7);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(title: Text('Report - ${patient.name}', overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 16)), backgroundColor: oliveGreen, foregroundColor: Colors.white, elevation: 0, actions: [IconButton(icon: const Icon(Icons.share, size: 20), onPressed: () => _sharePDF(context))]),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 70, height: 70, decoration: BoxDecoration(color: oliveGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(35), border: Border.all(color: oliveGreen, width: 1.5)), child: Icon(Icons.check_circle, size: 35, color: oliveGreen)),
              const SizedBox(height: 14),
              Text('Report Generated!', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: oliveGreen), textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text('PDF created with confidence levels', style: TextStyle(color: Colors.grey[600], fontSize: 11), textAlign: TextAlign.center),
              const SizedBox(height: 14),
              if (patient.emotionResults != null) _buildEmotionPreview(patient.emotionResults!),
              const SizedBox(height: 14),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 4, offset: const Offset(0, 2))]),
                child: Column(children: [_buildInfoRow('Patient', patient.name), _buildInfoRow('Age', '${patient.age} years'), _buildInfoRow('Gender', patient.gender), _buildInfoRow('Phone', patient.phoneNumber), if (patient.bloodGroup != null) _buildInfoRow('Blood', patient.bloodGroup!), _buildInfoRow('Date', _formatDate(patient.date)), if (patient.additionalNotes != null && patient.additionalNotes!.isNotEmpty) _buildInfoRow('Notes', patient.additionalNotes!)]),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: FilledButton.icon(onPressed: () => _sharePDF(context), icon: const Icon(Icons.share, size: 14), label: const Text('Share', style: TextStyle(fontSize: 11)), style: FilledButton.styleFrom(backgroundColor: Colors.blue, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))))),
                  const SizedBox(width: 12),
                  Expanded(child: OutlinedButton.icon(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.arrow_back, size: 14), label: const Text('Back', style: TextStyle(fontSize: 11)), style: OutlinedButton.styleFrom(foregroundColor: oliveGreen, side: BorderSide(color: oliveGreen), padding: const EdgeInsets.symmetric(vertical: 10)))),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmotionPreview(PredictionResult results) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.blue.withOpacity(0.3))),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(children: [Icon(Icons.emoji_emotions, color: Colors.blue, size: 14), SizedBox(width: 6), Text('Emotion Analysis', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blue, fontSize: 11))]),
          const SizedBox(height: 6),
          Text('Primary: ${results.topLabel?.toUpperCase() ?? "UNKNOWN"}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 11)),
          const SizedBox(height: 4),
          Text('Confidence: ${(results.topProb * 100).toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: _getConfidenceColor(results.topProb), fontSize: 10)),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [Expanded(flex: 2, child: Text(label, style: TextStyle(fontWeight: FontWeight.w600, color: Colors.grey[700], fontSize: 10))), Expanded(flex: 3, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, color: Color(0xFF556B2F), fontSize: 10), overflow: TextOverflow.ellipsis, maxLines: 2))]),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.7) return Colors.green;
    if (confidence > 0.5) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}