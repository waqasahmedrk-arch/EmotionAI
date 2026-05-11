import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import '../models/patient_model.dart';
import '../models/prediction_result.dart';

class PDFService {
  Future<File> generatePatientReport(Patient patient) async {
    final pdf = pw.Document();

    // Emotion analysis summary
    String emotionSummary = _generateEmotionSummary(patient.emotionResults!);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) => [
          // Header
          _buildHeader(patient),
          pw.SizedBox(height: 20),

          // Patient Information
          _buildPatientInfo(patient),
          pw.SizedBox(height: 20),

          // Emotion Analysis Results
          _buildEmotionAnalysis(patient.emotionResults!),
          pw.SizedBox(height: 15),

          // Emotion Summary
          _buildEmotionSummary(emotionSummary),
          pw.SizedBox(height: 20),

          // Clinical Notes (if any)
          if (patient.additionalNotes != null && patient.additionalNotes!.isNotEmpty)
            _buildClinicalNotes(patient.additionalNotes!),

          // Footer
          pw.SizedBox(height: 30),
          _buildFooter(),
        ],
      ),
    );

    // Save PDF
    final output = await getTemporaryDirectory();
    final file = File("${output.path}/patient_report_${patient.name}_${DateTime.now().millisecondsSinceEpoch}.pdf");
    await file.writeAsBytes(await pdf.save());

    return file;
  }

  // Header Section
  pw.Widget _buildHeader(Patient patient) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          'EEG EMOTION ANALYSIS REPORT',
          style: pw.TextStyle(
            fontSize: 18,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.green,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          'NeuroEmotions Diagnostic Center',
          style: pw.TextStyle(fontSize: 12, color: PdfColors.grey),
        ),
        pw.Divider(thickness: 2, color: PdfColors.green),
      ],
    );
  }

  // Patient Information Section
  pw.Widget _buildPatientInfo(Patient patient) {
    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey, width: 1),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'PATIENT INFORMATION',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.green,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildInfoItem('Name', patient.name),
              ),
              pw.Expanded(
                child: _buildInfoItem('Age', '${patient.age} years'),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildInfoItem('Gender', patient.gender),
              ),
              pw.Expanded(
                child: _buildInfoItem('Phone', patient.phoneNumber),
              ),
            ],
          ),
          pw.SizedBox(height: 5),
          pw.Row(
            children: [
              pw.Expanded(
                child: _buildInfoItem('Blood Group', patient.bloodGroup ?? 'Not specified'),
              ),
              pw.Expanded(
                child: _buildInfoItem('Date', _formatDate(patient.date)),
              ),
            ],
          ),
          if (patient.email != null && patient.email!.isNotEmpty) ...[
            pw.SizedBox(height: 5),
            _buildInfoItem('Email', patient.email!),
          ],
        ],
      ),
    );
  }

  // Emotion Analysis Section
  pw.Widget _buildEmotionAnalysis(PredictionResult emotionResults) {
    final sortedEmotions = emotionResults.probabilities.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.blue, width: 1),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'EMOTION ANALYSIS RESULTS',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue,
            ),
          ),
          pw.SizedBox(height: 10),

          // Primary Emotion with Confidence
          pw.Container(
            padding: pw.EdgeInsets.all(10),
            decoration: pw.BoxDecoration(
              color: PdfColors.lightBlue,
              borderRadius: pw.BorderRadius.circular(5),
            ),
            child: pw.Row(
              children: [
                pw.Text(
                  'Primary Emotion: ',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.Text(
                  '${emotionResults.topLabel?.toUpperCase() ?? "UNKNOWN"}',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColors.blue,
                  ),
                ),
                pw.Spacer(),
                pw.Text(
                  'Confidence: ${(emotionResults.topProb * 100).toStringAsFixed(1)}%',
                  style: pw.TextStyle(
                    fontWeight: pw.FontWeight.bold,
                    color: _getConfidenceColor(emotionResults.topProb),
                  ),
                ),
              ],
            ),
          ),
          pw.SizedBox(height: 15),

          // All Emotions with Progress Bars
          pw.Text(
            'Detailed Emotion Probabilities:',
            style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 10),

          ...sortedEmotions.map((entry) => pw.Column(
            children: [
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text(
                      entry.key,
                      style: pw.TextStyle(fontSize: 10),
                    ),
                  ),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Container(
                      height: 8,
                      decoration: pw.BoxDecoration(
                        color: PdfColors.grey300,
                        borderRadius: pw.BorderRadius.circular(4),
                      ),
                      child: pw.Stack(
                        children: [
                          pw.Container(
                            width: entry.value * 100,
                            decoration: pw.BoxDecoration(
                              color: _getConfidenceColor(entry.value),
                              borderRadius: pw.BorderRadius.circular(4),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  pw.Expanded(
                    flex: 1,
                    child: pw.Text(
                      '${(entry.value * 100).toStringAsFixed(1)}%',
                      style: pw.TextStyle(
                        fontSize: 8,
                        fontWeight: pw.FontWeight.bold,
                      ),
                      textAlign: pw.TextAlign.right,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 5),
            ],
          )),
        ],
      ),
    );
  }

  // Emotion Summary Section
  pw.Widget _buildEmotionSummary(String summary) {
    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.orange, width: 1),
        borderRadius: pw.BorderRadius.circular(5),
        color: PdfColors.orange50,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Row(
            children: [
              pw.Text(
                'EMOTION ANALYSIS SUMMARY',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.orange,
                ),
              ),
            ],
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            summary,
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey700,
            ),
            textAlign: pw.TextAlign.justify,
          ),
        ],
      ),
    );
  }

  // Clinical Notes Section
  pw.Widget _buildClinicalNotes(String notes) {
    return pw.Container(
      padding: pw.EdgeInsets.all(15),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.purple, width: 1),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'CLINICAL NOTES',
            style: pw.TextStyle(
              fontSize: 14,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.purple,
            ),
          ),
          pw.SizedBox(height: 10),
          pw.Text(
            notes,
            style: pw.TextStyle(fontSize: 11),
            textAlign: pw.TextAlign.justify,
          ),
        ],
      ),
    );
  }

  // Footer Section
  pw.Widget _buildFooter() {
    return pw.Column(
      children: [
        pw.Divider(thickness: 1, color: PdfColors.grey),
        pw.SizedBox(height: 10),
        pw.Text(
          'Generated by NeuroEmotions Diagnostic App',
          style: pw.TextStyle(
            fontSize: 10,
            color: PdfColors.grey,
            fontStyle: pw.FontStyle.italic,
          ),
          textAlign: pw.TextAlign.center,
        ),
        pw.Text(
          'Confidential Medical Report - For authorized use only',
          style: pw.TextStyle(
            fontSize: 8,
            color: PdfColors.grey,
          ),
          textAlign: pw.TextAlign.center,
        ),
      ],
    );
  }

  // Helper method for info items
  pw.Widget _buildInfoItem(String label, String value) {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 9,
            color: PdfColors.grey,
            fontWeight: pw.FontWeight.bold,
          ),
        ),
        pw.Text(
          value,
          style: pw.TextStyle(fontSize: 10),
        ),
      ],
    );
  }

  // Generate emotion summary based on predicted emotions
  String _generateEmotionSummary(PredictionResult emotionResults) {
    final topEmotion = emotionResults.topLabel?.toLowerCase() ?? 'unknown';
    final confidence = emotionResults.topProb;

    Map<String, String> emotionSummaries = {
      'happy': '''
Based on the EEG analysis, the patient exhibits strong patterns associated with happiness and positive emotional states. The neural activity shows increased activity in the left prefrontal cortex, which is typically associated with positive affect and approach-related emotions.

This emotional state suggests:
• Positive mood and well-being
• Engagement with environment
• Potential for good social interactions
• Overall psychological comfort

Confidence level: ${(confidence * 100).toStringAsFixed(1)}% - This indicates a reliable detection of happy emotional state.
''',
      'sad': '''
The EEG analysis indicates patterns consistent with sadness or low mood states. Neural activity shows characteristic changes in the right prefrontal cortex and limbic system regions associated with negative affect and withdrawal emotions.

Clinical observations may include:
• Reduced positive emotional responsiveness
• Possible anhedonia (reduced pleasure)
• Withdrawal tendencies
• Need for emotional support

Confidence level: ${(confidence * 100).toStringAsFixed(1)}% - Suggests significant presence of sad emotional patterns.
''',
      'angry': '''
EEG patterns show signatures associated with anger or frustration. There is increased activity in the amygdala and anterior cingulate cortex, regions linked to emotional intensity and conflict processing.

This may indicate:
• Heightened emotional arousal
• Potential irritability
• Frustration with current situation
• Need for conflict resolution strategies

Confidence level: ${(confidence * 100).toStringAsFixed(1)}% - Strong indication of angry emotional state.
''',
      'fear': '''
The analysis reveals neural patterns characteristic of fear or anxiety states. Activity in the amygdala and insula shows typical fear-response patterns, indicating heightened alertness to potential threats.

Clinical implications:
• Increased anxiety levels
• Hyper-vigilance state
• Possible stress response
• Need for calming interventions

Confidence level: ${(confidence * 100).toStringAsFixed(1)}% - Clear detection of fear-related neural activity.
''',
      'neutral': '''
EEG analysis shows balanced emotional state with neutral affect. The neural patterns indicate emotional stability without significant positive or negative bias, suggesting a baseline resting state.

Characteristics include:
• Emotional equilibrium
• Balanced prefrontal activity
• Stable mood state
• Normal resting brain function

Confidence level: ${(confidence * 100).toStringAsFixed(1)}% - Indicates reliable neutral state detection.
''',
      'surprise': '''
Patterns indicate a surprised emotional state, characterized by rapid changes in neural activity across multiple brain regions. This suggests unexpected stimulus processing or novel situation response.

Features observed:
• Rapid orienting response
• Increased attention allocation
• Cognitive processing engagement
• Adaptive response to novelty

Confidence level: ${(confidence * 100).toStringAsFixed(1)}% - Clear surprise pattern detection.
''',
    };

    // Default summary if emotion not found
    return emotionSummaries[topEmotion] ?? '''
Based on the EEG emotional analysis, the patient shows predominant ${topEmotion} patterns with ${(confidence * 100).toStringAsFixed(1)}% confidence level. 

This emotional state reflects specific neural activation patterns that provide insights into the patient's current psychological condition. Further clinical correlation is recommended for comprehensive assessment.

The analysis was conducted using advanced machine learning algorithms trained on EEG emotional response patterns, providing objective assessment of emotional states through neural activity monitoring.
''';
  }

  // Helper methods
  PdfColor _getConfidenceColor(double confidence) {
    if (confidence > 0.7) return PdfColors.green;
    if (confidence > 0.5) return PdfColors.orange;
    return PdfColors.red;
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}