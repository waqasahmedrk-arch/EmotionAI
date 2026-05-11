import 'package:flutter/material.dart';
import '../services/prediction_firebase_service.dart';
import '../models/prediction_history.dart';
import 'date_history_screen.dart';

class PredictionHistoryScreen extends StatefulWidget {
  final PredictionFirebaseService firebaseService;

  const PredictionHistoryScreen({super.key, required this.firebaseService});

  @override
  State<PredictionHistoryScreen> createState() => _PredictionHistoryScreenState();
}

class _PredictionHistoryScreenState extends State<PredictionHistoryScreen> {
  final Color _primaryColor = const Color(0xFF3DC75A);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _cardColor = Colors.white;
  final Color _textPrimary = const Color(0xFF212121);
  final Color _textSecondary = const Color(0xFF757575);
  final Color _borderColor = const Color(0xFFE0E0E0);

  List<PredictionRecord> _allPredictions = [];
  Map<DateTime, List<PredictionRecord>> _groupedHistory = {};
  List<DateTime> _datesWithHistory = [];
  bool _isLoading = true;
  String _viewMode = 'All'; // 'All', 'Today', 'Week', 'Month'

  @override
  void initState() {
    super.initState();
    _loadPredictions();
  }

  Future<void> _loadPredictions() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final data = await widget.firebaseService.getAllPredictions();
      final predictions = data.map((item) => PredictionRecord.fromMap({
        'id': item['id'] ?? '',
        'dateTime': item['date'].toString(),
        'emotion': item['emotion'] ?? 'Unknown',
        'confidence': item['confidence'] ?? 0.0,
        'method': item['method'] ?? 'unknown',
        'csvFileName': item['csvFileName'],
      })).toList();

      // Group predictions by date
      final grouped = <DateTime, List<PredictionRecord>>{};
      final dates = <DateTime>{};

      for (final prediction in predictions) {
        final dateKey = DateTime(
          prediction.dateTime.year,
          prediction.dateTime.month,
          prediction.dateTime.day,
        );

        if (!grouped.containsKey(dateKey)) {
          grouped[dateKey] = [];
        }
        grouped[dateKey]!.add(prediction);
        dates.add(dateKey);
      }

      setState(() {
        _allPredictions = predictions;
        _groupedHistory = grouped;
        _datesWithHistory = dates.toList()..sort((a, b) => b.compareTo(a));
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading predictions: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  Map<String, int> _getEmotionDistribution() {
    final distribution = <String, int>{};
    for (final prediction in _allPredictions) {
      distribution.update(
        prediction.emotion,
            (value) => value + 1,
        ifAbsent: () => 1,
      );
    }
    return distribution;
  }

  double _getAverageConfidence() {
    if (_allPredictions.isEmpty) return 0.0;
    final totalConfidence = _allPredictions.fold(
      0.0,
          (sum, prediction) => sum + prediction.confidence,
    );
    return totalConfidence / _allPredictions.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      appBar: AppBar(
        title: const Text('Prediction History'),
        actions: [
          if (_allPredictions.isNotEmpty)
            IconButton(
              onPressed: _showClearConfirmation,
              icon: const Icon(Icons.delete_outline),
              tooltip: 'Clear History',
            ),
          IconButton(
            onPressed: _loadPredictions,
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh',
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _allPredictions.isEmpty
          ? _buildEmptyState()
          : Column(
        children: [
          // Stats Card
          _buildStatsCard(),

          // View Mode Filter
          _buildViewModeFilter(),

          // History List
          Expanded(
            child: RefreshIndicator(
              onRefresh: _loadPredictions,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  if (_viewMode == 'All')
                    ..._buildAllHistoryList()
                  else
                    ..._buildFilteredHistoryList(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.history_rounded,
            size: 80,
            color: _textSecondary,
          ),
          const SizedBox(height: 16),
          Text(
            'No Prediction History',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: _textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your emotion detection sessions will appear here',
            style: TextStyle(
              fontSize: 14,
              color: _textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildStatsCard() {
    final emotionDistribution = _getEmotionDistribution();
    final mostFrequentEmotion = emotionDistribution.isNotEmpty
        ? emotionDistribution.entries.reduce((a, b) => a.value > b.value ? a : b).key
        : 'None';
    final avgConfidence = _getAverageConfidence();

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Card(
        elevation: 0,
        color: _primaryColor,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Sessions',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        _allPredictions.length.toString(),
                        style: const TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.emoji_emotions, color: Colors.white, size: 32),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  Column(
                    children: [
                      Text(
                        'Most Frequent',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        mostFrequentEmotion,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    width: 1,
                    height: 40,
                    color: Colors.white.withOpacity(0.3),
                  ),
                  Column(
                    children: [
                      Text(
                        'Avg Confidence',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                      Text(
                        '${(avgConfidence * 100).toStringAsFixed(0)}%',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildViewModeFilter() {
    final options = ['All', 'Today', 'Week', 'Month'];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: options.map((option) {
          final isSelected = _viewMode == option;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(option),
              selected: isSelected,
              onSelected: (_) {
                setState(() {
                  _viewMode = option;
                });
              },
              selectedColor: _primaryColor,
              labelStyle: TextStyle(
                color: isSelected ? Colors.white : _textPrimary,
              ),
              backgroundColor: _cardColor,
              side: BorderSide(color: _borderColor),
            ),
          );
        }).toList(),
      ),
    );
  }

  List<Widget> _buildAllHistoryList() {
    return _datesWithHistory.map((date) {
      final predictions = _groupedHistory[date]!;
      final dominantEmotion = _getDominantEmotion(predictions);

      return Card(
        margin: const EdgeInsets.only(bottom: 12),
        elevation: 0,
        color: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _borderColor, width: 1),
        ),
        child: InkWell(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => DateHistoryScreen(
                  date: date,
                  predictions: predictions,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Date Header
                Row(
                  children: [
                    Text(
                      _formatDateHeader(date),
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _textPrimary,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: _primaryColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${predictions.length} session${predictions.length > 1 ? 's' : ''}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _primaryColor,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Sample Predictions (show max 2)
                ...predictions.take(2).map((prediction) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _buildHistoryItem(prediction),
                )),

                if (predictions.length > 2) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: Text(
                      '+ ${predictions.length - 2} more →',
                      style: TextStyle(
                        fontSize: 12,
                        color: _primaryColor,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildFilteredHistoryList() {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime weekAgo = today.subtract(const Duration(days: 6));
    DateTime monthAgo = DateTime(now.year, now.month - 1, now.day);

    List<PredictionRecord> filteredPredictions = _allPredictions.where((pred) {
      final predDate = DateTime(pred.dateTime.year, pred.dateTime.month, pred.dateTime.day);

      switch (_viewMode) {
        case 'Today':
          return predDate == today;
        case 'Week':
          return predDate.isAfter(weekAgo.subtract(const Duration(days: 1)));
        case 'Month':
          return predDate.isAfter(monthAgo.subtract(const Duration(days: 1)));
        default:
          return true;
      }
    }).toList();

    if (filteredPredictions.isEmpty) {
      return [
        Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text(
              'No predictions found for $_viewMode',
              style: TextStyle(
                fontSize: 16,
                color: _textSecondary,
              ),
            ),
          ),
        ),
      ];
    }

    return filteredPredictions.map((prediction) => _buildHistoryCard(prediction)).toList();
  }

  Widget _buildHistoryCard(PredictionRecord prediction) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: _buildHistoryItem(prediction),
      ),
    );
  }

  Widget _buildHistoryItem(PredictionRecord prediction) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: _primaryColor.withOpacity(0.1),
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
                  color: _textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                '${(prediction.confidence * 100).toStringAsFixed(1)}% confidence',
                style: TextStyle(
                  fontSize: 12,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 4),
              if (prediction.method != null)
                Row(
                  children: [
                    Icon(
                      prediction.method == 'realtime' ? Icons.bluetooth : Icons.upload_file,
                      size: 12,
                      color: _textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      prediction.method == 'realtime' ? 'Live EEG' : 'CSV File',
                      style: TextStyle(
                        fontSize: 11,
                        color: _textSecondary,
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
                color: _textPrimary,
              ),
            ),
            Text(
              _formatDateShort(prediction.dateTime),
              style: TextStyle(
                fontSize: 12,
                color: _textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _getDominantEmotion(List<PredictionRecord> predictions) {
    if (predictions.isEmpty) return '';

    final emotionCount = <String, int>{};
    for (final pred in predictions) {
      emotionCount.update(pred.emotion, (value) => value + 1, ifAbsent: () => 1);
    }

    final dominant = emotionCount.entries.reduce((a, b) => a.value > b.value ? a : b);
    return dominant.key;
  }

  String _formatDateHeader(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    if (date == today) return 'Today';
    if (date == yesterday) return 'Yesterday';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    final dayOfWeek = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'][date.weekday % 7];

    return '$dayOfWeek, ${date.day} ${months[date.month - 1]} ${date.year}';
  }

  String _formatDateShort(DateTime dateTime) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final date = DateTime(dateTime.year, dateTime.month, dateTime.day);

    if (date == today) return 'Today';

    final months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

    return '${date.day} ${months[date.month - 1]}';
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

  void _showClearConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear History'),
        content: const Text('Are you sure you want to clear all prediction history? This action cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              await widget.firebaseService.clearAllPredictions();
              Navigator.pop(context);
              await _loadPredictions();
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('History cleared successfully'),
                  duration: Duration(seconds: 2),
                ),
              );
            },
            child: const Text(
              'Clear',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }
}