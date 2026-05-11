import 'package:flutter/material.dart';
import '../models/prediction_history.dart';

class DateHistoryScreen extends StatelessWidget {
  final DateTime date;
  final List<PredictionRecord> predictions;

  const DateHistoryScreen({
    super.key,
    required this.date,
    required this.predictions,
  });

  @override
  Widget build(BuildContext context) {
    final Color primaryColor = const Color(0xFF3DC75A);
    final Color backgroundColor = const Color(0xFFF8F9FA);
    final Color cardColor = Colors.white;
    final Color textPrimary = const Color(0xFF212121);
    final Color textSecondary = const Color(0xFF757575);
    final Color borderColor = const Color(0xFFE0E0E0);

    // Sort predictions by time (newest first)
    predictions.sort((a, b) => b.dateTime.compareTo(a.dateTime));

    // Calculate statistics
    final emotionCount = <String, int>{};
    double totalConfidence = 0;
    for (final pred in predictions) {
      emotionCount.update(pred.emotion, (value) => value + 1, ifAbsent: () => 1);
      totalConfidence += pred.confidence;
    }
    final avgConfidence = totalConfidence / predictions.length;
    final mostFrequentEmotion = emotionCount.isNotEmpty
        ? emotionCount.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : 'None';

    return Scaffold(
      backgroundColor: backgroundColor,
      appBar: AppBar(
        title: Text(_formatDate(date)),
      ),
      body: Column(
        children: [
          // Statistics Card
          Card(
            margin: const EdgeInsets.all(16),
            elevation: 0,
            color: primaryColor,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Summary',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.8),
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          '${predictions.length} Sessions',
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Most frequent: $mostFrequentEmotion',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          _getEmoji(mostFrequentEmotion),
                          style: const TextStyle(fontSize: 24),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '${(avgConfidence * 100).toStringAsFixed(0)}% avg',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          // Emotion Distribution
          if (emotionCount.length > 1)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Card(
                elevation: 0,
                color: cardColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: borderColor, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Emotion Distribution',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ...emotionCount.entries.map((entry) => Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: primaryColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                _getEmoji(entry.key),
                                style: const TextStyle(fontSize: 14),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                entry.key,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: textPrimary,
                                ),
                              ),
                            ),
                            Text(
                              '${entry.value} time${entry.value > 1 ? 's' : ''}',
                              style: TextStyle(
                                fontSize: 14,
                                color: textSecondary,
                              ),
                            ),
                          ],
                        ),
                      )).toList(),
                    ],
                  ),
                ),
              ),
            ),

          const SizedBox(height: 16),

          // All Predictions List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: predictions.length,
              itemBuilder: (context, index) {
                final prediction = predictions[index];
                return Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  elevation: 0,
                  color: cardColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: borderColor, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            _getEmoji(prediction.emotion),
                            style: const TextStyle(fontSize: 20),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                prediction.emotion,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: textPrimary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${(prediction.confidence * 100).toStringAsFixed(1)}% confidence',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: textSecondary,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    prediction.method == 'realtime'
                                        ? Icons.bluetooth
                                        : Icons.upload_file,
                                    size: 12,
                                    color: textSecondary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    prediction.method == 'realtime'
                                        ? 'Live EEG Session'
                                        : 'CSV Analysis',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              _formatTime(prediction.dateTime),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: textPrimary,
                              ),
                            ),
                            Text(
                              prediction.method == 'csv' && prediction.csvFileName != null
                                  ? 'File: ${prediction.csvFileName!.split('/').last}'
                                  : 'Direct Session',
                              style: TextStyle(
                                fontSize: 11,
                                color: textSecondary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'];
    final dayOfWeek = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday'][date.weekday % 7];
    return '$dayOfWeek, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = dateTime.hour < 12 ? 'AM' : 'PM';
    return '${hour == 0 ? 12 : hour}:$minute $amPm';
  }

  String _getEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'positive': return '😊';
      case 'negative': return '😢';
      case 'neutral': return '😐';
      case 'happy': return '😄';
      case 'sad': return '😔';
      case 'angry': return '😠';
      case 'fearful': return '😨';
      case 'surprised': return '😲';
      case 'disgusted': return '🤢';
      case 'focused': return '🧠';
      case 'excited': return '🤩';
      case 'calm': return '😌';
      case 'relaxed': return '😌';
      default: return '🎭';
    }
  }
}