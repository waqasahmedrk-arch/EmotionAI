import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/patient_model.dart';
import '../models/prediction_result.dart';

class PatientReportsScreen extends StatefulWidget {
  const PatientReportsScreen({super.key});

  @override
  State<PatientReportsScreen> createState() => _PatientReportsScreenState();
}

class _PatientReportsScreenState extends State<PatientReportsScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  List<Patient> _allPatients = [];
  List<Patient> _filteredPatients = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _sortBy = 'date';
  bool _sortDescending = true;

  @override
  void initState() {
    super.initState();
    _loadAllPatients();
  }

  Future<void> _loadAllPatients() async {
    final user = _auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('patient_reports')
          .orderBy('createdAt', descending: true)
          .get();

      final patients = querySnapshot.docs.map((doc) {
        final data = doc.data();
        return Patient.fromMap({
          'id': doc.id,
          'name': data['name'] ?? '',
          'phoneNumber': data['phoneNumber'] ?? '',
          'age': data['age'] ?? 0,
          'gender': data['gender'] ?? 'Male',
          'date': (data['date'] as int),
          'bloodGroup': data['bloodGroup'],
          'email': data['email'],
          'additionalNotes': data['additionalNotes'],
          'emotionResults': data['emotionResults'],
        });
      }).toList();

      setState(() {
        _allPatients = patients;
        _filteredPatients = patients;
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading patients: $e');
      setState(() => _isLoading = false);
    }
  }

  void _filterPatients() {
    if (_searchQuery.isEmpty) {
      setState(() => _filteredPatients = _allPatients);
    } else {
      final filtered = _allPatients.where((patient) {
        final name = patient.name.toLowerCase();
        final phone = patient.phoneNumber.toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || phone.contains(query);
      }).toList();
      setState(() => _filteredPatients = filtered);
    }
  }

  void _sortPatients() {
    List<Patient> sorted = List.from(_filteredPatients);
    sorted.sort((a, b) {
      int comparison;
      switch (_sortBy) {
        case 'name':
          comparison = a.name.compareTo(b.name);
          break;
        case 'age':
          comparison = a.age.compareTo(b.age);
          break;
        case 'date':
        default:
          comparison = a.date.compareTo(b.date);
          break;
      }
      return _sortDescending ? -comparison : comparison;
    });
    setState(() => _filteredPatients = sorted);
  }

  Future<void> _deletePatient(Patient patient) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Report'),
        content: Text('Delete ${patient.name}\'s report permanently?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('Delete', style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirmed == true) {
      final user = _auth.currentUser;
      if (user == null) return;

      try {
        await _firestore.collection('users').doc(user.uid).collection('patient_reports').doc(patient.id).delete();
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${patient.name}\'s report deleted'), backgroundColor: Colors.green));
        _loadAllPatients();
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color oliveGreen = const Color(0xFF556B2F);
    final Color lightOlive = const Color(0xFF8FBC8F);
    final Color backgroundColor = const Color(0xFFF8F9F7);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: const Text('Patient Reports'),
        backgroundColor: oliveGreen,
        foregroundColor: Colors.white,
        actions: [IconButton(onPressed: _loadAllPatients, icon: const Icon(Icons.refresh))],
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            color: Colors.white,
            child: Column(
              children: [
                Container(
                  decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                  child: TextField(
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      _filterPatients();
                    },
                    decoration: const InputDecoration(hintText: 'Search by name or phone...', prefixIcon: Icon(Icons.search), border: InputBorder.none, contentPadding: EdgeInsets.symmetric(horizontal: 12)),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _sortBy,
                        decoration: const InputDecoration(labelText: 'Sort by', isDense: true, contentPadding: EdgeInsets.symmetric(horizontal: 8)),
                        items: [
                          DropdownMenuItem(value: 'date', child: Text('Date', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'name', child: Text('Name', style: TextStyle(fontSize: 12))),
                          DropdownMenuItem(value: 'age', child: Text('Age', style: TextStyle(fontSize: 12))),
                        ],
                        onChanged: (value) {
                          setState(() => _sortBy = value!);
                          _sortPatients();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    IconButton(
                      onPressed: () {
                        setState(() => _sortDescending = !_sortDescending);
                        _sortPatients();
                      },
                      icon: Icon(_sortDescending ? Icons.arrow_downward : Icons.arrow_upward, color: oliveGreen),
                      tooltip: _sortDescending ? 'Descending' : 'Ascending',
                    ),
                  ],
                ),
              ],
            ),
          ),

          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _filteredPatients.isEmpty
                ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.people, size: 60, color: Colors.grey[400]),
                  const SizedBox(height: 16),
                  Text(_searchQuery.isEmpty ? 'No patient reports yet' : 'No patients found', style: TextStyle(color: Colors.grey[600], fontSize: 16)),
                  if (_searchQuery.isNotEmpty) TextButton(onPressed: () {
                    setState(() => _searchQuery = '');
                    _filterPatients();
                  }, child: const Text('Clear search')),
                ],
              ),
            )
                : ListView.builder(
              itemCount: _filteredPatients.length,
              itemBuilder: (context, index) => _buildPatientCard(_filteredPatients[index], oliveGreen),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatientCard(Patient patient, Color oliveGreen) {
    return Card(
      margin: const EdgeInsets.all(8),
      elevation: 2,
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: Container(
          width: 48,
          height: 48,
          decoration: BoxDecoration(color: oliveGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(24)),
          child: Center(child: Text(patient.name.substring(0, 1).toUpperCase(), style: TextStyle(color: oliveGreen, fontWeight: FontWeight.bold, fontSize: 20))),
        ),
        title: Text(patient.name, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.grey[800])),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text('${patient.age} years • ${patient.gender} • ${patient.bloodGroup ?? 'N/A'}', style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 2),
            Text(patient.phoneNumber, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            const SizedBox(height: 2),
            Text(_formatDate(patient.date), style: TextStyle(color: Colors.grey[500], fontSize: 11)),
          ],
        ),
        trailing: IconButton(icon: const Icon(Icons.more_vert), onPressed: () => _showPatientOptions(patient)),
        onTap: () {
          Navigator.push(context, MaterialPageRoute(builder: (context) => PatientDetailScreen(patient: patient, onUpdate: _loadAllPatients)));
        },
      ),
    );
  }

  void _showPatientOptions(Patient patient) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(leading: const Icon(Icons.visibility, color: Colors.blue), title: const Text('View Details'), onTap: () {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (context) => PatientDetailScreen(patient: patient, onUpdate: _loadAllPatients)));
              }),
              ListTile(leading: const Icon(Icons.phone, color: Colors.green), title: const Text('Call Patient'), onTap: () {
                Navigator.pop(context);
                _callPatient(patient.phoneNumber);
              }),
              ListTile(leading: const Icon(Icons.email, color: Colors.orange), title: const Text('Email Report'), onTap: () {
                Navigator.pop(context);
                _emailPatient(patient);
              }),
              ListTile(leading: const Icon(Icons.share, color: Colors.purple), title: const Text('Share Report'), onTap: () {
                Navigator.pop(context);
                _shareReport(patient);
              }),
              ListTile(leading: const Icon(Icons.delete, color: Colors.red), title: const Text('Delete Report'), onTap: () {
                Navigator.pop(context);
                _deletePatient(patient);
              }),
            ],
          ),
        );
      },
    );
  }

  void _callPatient(String phoneNumber) async {
    final Uri launchUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrl(launchUri)) {
      await launchUrl(launchUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot make phone call'), backgroundColor: Colors.red));
    }
  }

  void _emailPatient(Patient patient) async {
    final emailAddress = patient.email ?? '';
    final subject = 'EEG Emotion Analysis Report - ${patient.name}';
    final body = 'Dear ${patient.name},\n\nPlease find attached your EEG emotion analysis report.\n\nBest regards';

    final Uri emailUri = Uri(scheme: 'mailto', path: emailAddress, queryParameters: {'subject': subject, 'body': body});

    if (await canLaunchUrl(emailUri)) {
      await launchUrl(emailUri);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cannot open email app'), backgroundColor: Colors.red));
    }
  }

  void _shareReport(Patient patient) {
    final emotionText = patient.emotionResults != null
        ? 'Primary Emotion: ${patient.emotionResults!.topLabel?.toUpperCase() ?? "UNKNOWN"} (${(patient.emotionResults!.topProb * 100).toStringAsFixed(1)}%)'
        : 'No emotion analysis available';

    Share.share(
      'EEG Emotion Analysis Report\n\n'
          'Patient: ${patient.name}\n'
          'Age: ${patient.age} years\n'
          'Gender: ${patient.gender}\n'
          'Phone: ${patient.phoneNumber}\n'
          'Blood Group: ${patient.bloodGroup ?? 'N/A'}\n'
          'Date: ${_formatDate(patient.date)}\n\n'
          '$emotionText\n\n'
          'Generated by NeuroEmotions Diagnostic App',
      subject: 'EEG Report - ${patient.name}',
    );
  }

  String _formatDate(DateTime date) {
    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return '${date.day} ${months[date.month - 1]} ${date.year}';
  }
}

class PatientDetailScreen extends StatefulWidget {
  final Patient patient;
  final VoidCallback? onUpdate;

  const PatientDetailScreen({super.key, required this.patient, this.onUpdate});

  @override
  State<PatientDetailScreen> createState() => _PatientDetailScreenState();
}

class _PatientDetailScreenState extends State<PatientDetailScreen> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  bool _isEditing = false;
  late TextEditingController _nameController;
  late TextEditingController _phoneController;
  late TextEditingController _ageController;
  late TextEditingController _emailController;
  late TextEditingController _notesController;
  late String _selectedGender;
  late String _selectedBloodGroup;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.patient.name);
    _phoneController = TextEditingController(text: widget.patient.phoneNumber);
    _ageController = TextEditingController(text: widget.patient.age.toString());
    _emailController = TextEditingController(text: widget.patient.email ?? '');
    _notesController = TextEditingController(text: widget.patient.additionalNotes ?? '');
    _selectedGender = widget.patient.gender;
    _selectedBloodGroup = widget.patient.bloodGroup ?? 'A+';
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    _ageController.dispose();
    _emailController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  Future<void> _saveChanges() async {
    final user = _auth.currentUser;
    if (user == null || widget.patient.id == null) return;

    try {
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('patient_reports')
          .doc(widget.patient.id)
          .update({
        'name': _nameController.text,
        'phoneNumber': _phoneController.text,
        'age': int.parse(_ageController.text),
        'gender': _selectedGender,
        'bloodGroup': _selectedBloodGroup,
        'email': _emailController.text.isNotEmpty ? _emailController.text : null,
        'additionalNotes': _notesController.text.isNotEmpty ? _notesController.text : null,
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Patient updated successfully'), backgroundColor: Colors.green));
      setState(() => _isEditing = false);
      widget.onUpdate?.call();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e'), backgroundColor: Colors.red));
    }
  }

  @override
  Widget build(BuildContext context) {
    final Color oliveGreen = const Color(0xFF556B2F);
    final Color backgroundColor = const Color(0xFFF8F9F7);

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(widget.patient.name),
        backgroundColor: oliveGreen,
        foregroundColor: Colors.white,
        actions: [
          if (!_isEditing)
            IconButton(icon: const Icon(Icons.share), onPressed: () => _shareReport()),
          IconButton(
            icon: Icon(_isEditing ? Icons.save : Icons.edit),
            onPressed: () {
              if (_isEditing) {
                _saveChanges();
              } else {
                setState(() => _isEditing = true);
              }
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              elevation: 2,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Patient Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF556B2F))),
                    const SizedBox(height: 16),
                    if (_isEditing) ...[
                      _buildEditField('Full Name', _nameController),
                      _buildEditField('Phone Number', _phoneController, keyboardType: TextInputType.phone),
                      _buildEditField('Age', _ageController, keyboardType: TextInputType.number),
                      _buildEditField('Email', _emailController, keyboardType: TextInputType.emailAddress),
                      _buildDropdown('Gender', _selectedGender, ['Male', 'Female', 'Other'], (v) => setState(() => _selectedGender = v!)),
                      _buildDropdown('Blood Group', _selectedBloodGroup, ['A+', 'A-', 'B+', 'B-', 'AB+', 'AB-', 'O+', 'O-'], (v) => setState(() => _selectedBloodGroup = v!)),
                      _buildEditField('Notes', _notesController, maxLines: 3),
                    ] else ...[
                      _buildInfoRow('Full Name', widget.patient.name),
                      _buildInfoRow('Age', '${widget.patient.age} years'),
                      _buildInfoRow('Gender', widget.patient.gender),
                      _buildInfoRow('Phone Number', widget.patient.phoneNumber),
                      if (widget.patient.email != null) _buildInfoRow('Email', widget.patient.email!),
                      if (widget.patient.bloodGroup != null) _buildInfoRow('Blood Group', widget.patient.bloodGroup!),
                      _buildInfoRow('Report Date', _formatDate(widget.patient.date)),
                      if (widget.patient.additionalNotes != null) ...[
                        const SizedBox(height: 8),
                        const Text('Clinical Notes:', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text(widget.patient.additionalNotes!, style: const TextStyle(color: Colors.grey)),
                      ],
                    ],
                  ],
                ),
              ),
            ),

            const SizedBox(height: 16),

            if (widget.patient.emotionResults != null) ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Emotion Analysis', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF556B2F))),
                      const SizedBox(height: 16),
                      _buildEmotionResults(widget.patient.emotionResults!),
                    ],
                  ),
                ),
              ),
            ] else ...[
              Card(
                elevation: 2,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      Icon(Icons.info_outline, size: 48, color: Colors.grey[400]),
                      const SizedBox(height: 12),
                      Text('No Emotion Analysis Available', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.grey[600])),
                      const SizedBox(height: 8),
                      Text('This report was created without emotion analysis data', style: TextStyle(color: Colors.grey[500], fontSize: 12), textAlign: TextAlign.center),
                    ],
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildEditField(String label, TextEditingController controller, {TextInputType keyboardType = TextInputType.text, int maxLines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        maxLines: maxLines,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.all(12)),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, void Function(String?) onChanged) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: DropdownButtonFormField<String>(
        value: value,
        decoration: InputDecoration(labelText: label, border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)), contentPadding: const EdgeInsets.all(12)),
        items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
        onChanged: onChanged,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(flex: 2, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w600, color: Colors.grey))),
          Expanded(flex: 3, child: Text(value, style: const TextStyle(fontWeight: FontWeight.w500, color: Colors.black87))),
        ],
      ),
    );
  }

  Widget _buildEmotionResults(PredictionResult results) {
    final sortedEmotions = results.sortedProbabilities;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Icon(Icons.emoji_emotions, color: Colors.blue, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text('Primary Emotion: ${results.topLabel?.toUpperCase() ?? "UNKNOWN"}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16))),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(color: _getConfidenceColor(results.topProb), borderRadius: BorderRadius.circular(12)),
              child: Text('${(results.topProb * 100).toStringAsFixed(1)}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        ...sortedEmotions.map((entry) => Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Row(
            children: [
              Expanded(child: Text(entry.key, style: const TextStyle(fontWeight: FontWeight.w500))),
              const SizedBox(width: 12),
              SizedBox(
                width: 100,
                child: LinearProgressIndicator(value: entry.value, backgroundColor: Colors.grey[200], color: _getConfidenceColor(entry.value), minHeight: 8),
              ),
              const SizedBox(width: 12),
              SizedBox(width: 50, child: Text('${(entry.value * 100).toStringAsFixed(1)}%', style: TextStyle(fontWeight: FontWeight.bold, color: _getConfidenceColor(entry.value)))),
            ],
          ),
        )),
      ],
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.7) return Colors.green;
    if (confidence > 0.5) return Colors.orange;
    return Colors.red;
  }

  String _formatDate(DateTime date) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
    return '${date.day} ${months[date.month - 1]}, ${date.year}';
  }

  void _shareReport() {
    final emotionText = widget.patient.emotionResults != null
        ? 'Primary Emotion: ${widget.patient.emotionResults!.topLabel?.toUpperCase() ?? "UNKNOWN"} (${(widget.patient.emotionResults!.topProb * 100).toStringAsFixed(1)}%)'
        : 'No emotion analysis available';

    Share.share(
      'EEG Emotion Analysis Report\n\n'
          'Patient: ${widget.patient.name}\n'
          'Age: ${widget.patient.age} years\n'
          'Gender: ${widget.patient.gender}\n'
          'Phone: ${widget.patient.phoneNumber}\n'
          'Blood Group: ${widget.patient.bloodGroup ?? 'N/A'}\n'
          'Date: ${_formatDate(widget.patient.date)}\n\n'
          '$emotionText\n\n'
          'Generated by NeuroEmotions Diagnostic App',
      subject: 'EEG Report - ${widget.patient.name}',
    );
  }
}