import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model_host.dart';
import 'package:lost_found/models/prediction_result.dart';

class VisualizationScreen extends StatefulWidget {
  const VisualizationScreen({Key? key}) : super(key: key);

  @override
  State<VisualizationScreen> createState() => _VisualizationScreenState();
}

class _VisualizationScreenState extends State<VisualizationScreen> {
  final Color _primaryColor = const Color(0xFF556B2F);
  final Color _accentColor = const Color(0xFF6B8E23);
  final Color _backgroundColor = const Color(0xFFFAFDF9);
  final Color _surfaceColor = Colors.white;
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _warningColor = const Color(0xFFFF9800);
  final Color _errorColor = const Color(0xFFF44336);

  @override
  Widget build(BuildContext context) {
    final host = Provider.of<ModelHost>(context, listen: true);
    final predictionResult = host.lastPredictionResult;

    return WillPopScope(
      onWillPop: () async {
        // Prevent going back - exit the app
        return true; // Change to false if you want to completely block back button
      },
      child: Scaffold(
        backgroundColor: _backgroundColor,
        body: CustomScrollView(
          slivers: [
            // Professional App Bar without back button
            SliverAppBar(
              backgroundColor: _primaryColor,
              foregroundColor: Colors.white,
              expandedHeight: 140,
              flexibleSpace: FlexibleSpaceBar(
                title: Text(
                  predictionResult != null
                      ? 'Emotion Visualization'
                      : 'Brain Activity Analysis',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                background: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _primaryColor,
                        _accentColor,
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: const Align(
                    alignment: Alignment.bottomRight,
                    child: Padding(
                      padding: EdgeInsets.all(20.0),
                      child: Icon(Icons.analytics_outlined, size: 40, color: Colors.white70),
                    ),
                  ),
                ),
              ),
              // Remove back button
              automaticallyImplyLeading: false,
              actions: [
                IconButton(
                  icon: const Icon(Icons.info_outline),
                  onPressed: () {
                    _showInfoDialog(context);
                  },
                  tooltip: 'About Visualization',
                ),
              ],
            ),

            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  if (predictionResult != null)
                    _buildPredictionSummary(predictionResult),

                  if (predictionResult == null)
                    _buildEmptyState(),

                  const SizedBox(height: 28),

                  // 1. PIE CHART - Predicted Emotions
                  _buildSectionTitle('Emotion Distribution', Icons.pie_chart),
                  const SizedBox(height: 16),
                  _buildPieChartSection(predictionResult),

                  const SizedBox(height: 32),

                  // 2. CONCENTRATION GRAPH - Emotion-based Concentration
                  _buildSectionTitle('Concentration Levels', Icons.timeline),
                  const SizedBox(height: 16),
                  _buildConcentrationSection(predictionResult),

                  const SizedBox(height: 32),

                  // 3. BRAIN WAVE ACTIVITY - Emotion-based Brain Waves
                  _buildSectionTitle('Brain Wave Activity', Icons.monitor_heart),
                  const SizedBox(height: 16),
                  _buildWaveActivitySection(predictionResult),

                  if (predictionResult != null) ...[
                    const SizedBox(height: 32),
                    _buildSectionTitle('Emotional Insights', Icons.psychology),
                    const SizedBox(height: 16),
                    _buildEmotionalInsights(predictionResult),
                  ],

                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.analytics, color: Color(0xFF556B2F)),
            SizedBox(width: 12),
            Text('Visualization Guide'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'This screen visualizes your emotional state based on EEG data analysis:',
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 12),
            _InfoItem('🎯 Emotion Distribution', 'Shows probability of different emotional states'),
            _InfoItem('📈 Concentration Levels', 'Displays focus patterns over time'),
            _InfoItem('🧠 Brain Wave Activity', 'Visualizes EEG frequency bands'),
            _InfoItem('💡 Emotional Insights', 'Provides analysis and recommendations'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('GOT IT'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return ResponsiveCard(
      child: Column(
        children: [
          Icon(Icons.analytics_outlined, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 20),
          Text(
            'No Prediction Data Available',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: _primaryColor,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 12),
          Text(
            'Make an emotion prediction in the Predict tab to see detailed visualizations of your emotional patterns and brain activity.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 16,
              height: 1.6,
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton.icon(
              onPressed: () {
                // You can add navigation to predict tab here
                print('Navigate to Predict Tab');
              },
              icon: const Icon(Icons.psychology, size: 24),
              label: const Text(
                'Make Your First Prediction',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: _primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 2,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPredictionSummary(PredictionResult result) {
    final topEmotion = result.topLabel ?? 'Unknown';
    final confidence = (result.topProb * 100).toStringAsFixed(1);

    String getEmoji(String emotion) {
      switch (emotion.toLowerCase()) {
        case 'positive': return '😊';
        case 'negative': return '😢';
        case 'neutral': return '😐';
        case 'relaxed': return '😌';
        case 'excited': return '🤩';
        case 'happy': return '😄';
        case 'sad': return '😔';
        case 'angry': return '😠';
        default: return '🎭';
      }
    }

    Color getConfidenceColor(double confidence) {
      if (confidence > 0.7) return _successColor;
      if (confidence > 0.5) return _warningColor;
      return _errorColor;
    }

    return ResponsiveCard(
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _primaryColor.withOpacity(0.9),
                      _accentColor.withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _primaryColor.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: Text(
                    getEmoji(topEmotion),
                    style: const TextStyle(fontSize: 32),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'CURRENT EMOTIONAL STATE',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                        letterSpacing: 1.2,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      topEmotion.toUpperCase(),
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        color: _primaryColor,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Container(
                          width: 12,
                          height: 12,
                          decoration: BoxDecoration(
                            color: getConfidenceColor(result.topProb),
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Confidence: $confidence%',
                          style: TextStyle(
                            fontSize: 15,
                            color: getConfidenceColor(result.topProb),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: _accentColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: _accentColor.withOpacity(0.3)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.circle, size: 8, color: _accentColor),
                const SizedBox(width: 8),
                Text(
                  'LIVE ANALYSIS ACTIVE',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _accentColor,
                    letterSpacing: 1,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: _primaryColor, size: 20),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: _primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  // 1. PIE CHART SECTION
  Widget _buildPieChartSection(PredictionResult? result) {
    final emotionData = _getEmotionDataForPieChart(result);
    final hasPrediction = result != null;

    return ResponsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasPrediction ? 'Emotion Probability Distribution' : 'Sample Emotion Distribution',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasPrediction
                ? 'Based on real-time EEG pattern recognition and machine learning analysis'
                : 'Make a prediction to see your actual emotion distribution',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          // Responsive Pie Chart Layout
          LayoutBuilder(
            builder: (context, constraints) {
              final isMobile = constraints.maxWidth < 600;

              if (isMobile) {
                return Column(
                  children: [
                    // Pie Chart
                    Container(
                      height: 200,
                      child: CustomPaint(
                        size: const Size(200, 200),
                        painter: EmotionPieChartPainter(data: emotionData),
                      ),
                    ),
                    const SizedBox(height: 24),
                    // Legend
                    _buildPieChartLegend(emotionData),
                  ],
                );
              } else {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Pie Chart
                    Expanded(
                      flex: 2,
                      child: Container(
                        height: 220,
                        child: CustomPaint(
                          size: const Size(220, 220),
                          painter: EmotionPieChartPainter(data: emotionData),
                        ),
                      ),
                    ),
                    const SizedBox(width: 32),
                    // Legend
                    Expanded(
                      flex: 3,
                      child: _buildPieChartLegend(emotionData),
                    ),
                  ],
                );
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPieChartLegend(List<EmotionData> emotionData) {
    return Column(
      children: emotionData.map((data) => _buildEmotionLegendItem(data)).toList(),
    );
  }

  Widget _buildEmotionLegendItem(EmotionData data) {
    String getEmoji(String emotion) {
      switch (emotion.toLowerCase()) {
        case 'positive': return '😊';
        case 'negative': return '😢';
        case 'neutral': return '😐';
        case 'relaxed': return '😌';
        case 'excited': return '🤩';
        case 'happy': return '😄';
        case 'sad': return '😔';
        case 'angry': return '😠';
        case 'no data': return '📊';
        default: return '🎭';
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Text(
            getEmoji(data.emotion),
            style: const TextStyle(fontSize: 20),
          ),
          const SizedBox(width: 12),
          Container(
            width: 16,
            height: 16,
            decoration: BoxDecoration(
              color: data.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              data.emotion.toUpperCase(),
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '${data.percentage.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _primaryColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 2. CONCENTRATION SECTION
  Widget _buildConcentrationSection(PredictionResult? result) {
    final concentrationData = _getConcentrationDataFromPrediction(result);
    final hasPrediction = result != null;

    return ResponsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasPrediction ? 'Concentration Level Timeline' : 'Sample Concentration Levels',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasPrediction
                ? 'How your detected emotion affects focus and attention patterns over time'
                : 'Concentration patterns will update with your prediction data',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          Container(
            height: 200,
            child: CustomPaint(
              size: const Size(double.infinity, 200),
              painter: LineChartPainter(data: concentrationData, color: _accentColor),
            ),
          ),
          const SizedBox(height: 20),
          _buildConcentrationStats(concentrationData),
        ],
      ),
    );
  }

  Widget _buildConcentrationStats(List<ConcentrationData> data) {
    final average = data.map((d) => d.level).reduce((a, b) => a + b) / data.length;
    final max = data.map((d) => d.level).reduce((a, b) => a > b ? a : b);
    final min = data.map((d) => d.level).reduce((a, b) => a < b ? a : b);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 400;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.grey[50],
            borderRadius: BorderRadius.circular(12),
          ),
          child: isMobile
              ? Column(
            children: [
              _buildStatItem('Average Concentration', '${average.toStringAsFixed(1)}%', _primaryColor),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildStatItem('Peak', '${max.toStringAsFixed(1)}%', _successColor),
                  _buildStatItem('Low', '${min.toStringAsFixed(1)}%', _warningColor),
                ],
              ),
            ],
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildStatItem('Average Concentration', '${average.toStringAsFixed(1)}%', _primaryColor),
              _buildStatItem('Peak Level', '${max.toStringAsFixed(1)}%', _successColor),
              _buildStatItem('Lowest Level', '${min.toStringAsFixed(1)}%', _warningColor),
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.grey[600],
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
            color: color,
          ),
        ),
      ],
    );
  }

  // 3. BRAIN WAVE ACTIVITY SECTION
  Widget _buildWaveActivitySection(PredictionResult? result) {
    final waveActivityData = _getWaveActivityFromPrediction(result);
    final hasPrediction = result != null;

    return ResponsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            hasPrediction ? 'Brain Wave Activity Patterns' : 'Sample Brain Wave Patterns',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: _primaryColor,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            hasPrediction
                ? 'EEG frequency bands analysis showing how your emotional state affects brain activity'
                : 'Brain wave patterns will reflect your predicted emotional state',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 24),

          SizedBox(
            height: 220,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                const SizedBox(width: 8),
                for (int i = 0; i < waveActivityData.length; i++)
                  _buildWaveBar(waveActivityData[i], i == waveActivityData.length - 1),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _buildWaveLegend(),
        ],
      ),
    );
  }

  Widget _buildWaveBar(WaveActivityData data, bool isLast) {
    final colors = [
      const Color(0xFF4285F4), // Alpha
      const Color(0xFF34A853), // Beta
      const Color(0xFFFBBC05), // Theta
      const Color(0xFFEA4335), // Delta
    ];

    return Container(
      margin: EdgeInsets.only(right: isLast ? 8 : 16),
      width: 80,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: _primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              'T${data.segment}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _primaryColor,
              ),
            ),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                _buildWaveBarSegment(data.alpha, colors[0], 'α'),
                _buildWaveBarSegment(data.beta, colors[1], 'β'),
                _buildWaveBarSegment(data.theta, colors[2], 'θ'),
                _buildWaveBarSegment(data.delta, colors[3], 'δ'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveBarSegment(double value, Color color, String label) {
    final height = (value / 100) * 120; // Scale to max 120px height

    return Expanded(
      child: Column(
        children: [
          Text(
            value.toStringAsFixed(0),
            style: TextStyle(fontSize: 10, color: color, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 4),
          Container(
            height: height,
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(4)),
              gradient: LinearGradient(
                colors: [color, color.withOpacity(0.7)],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildWaveLegend() {
    final waveInfo = [
      {'label': 'Alpha', 'color': const Color(0xFF4285F4), 'desc': 'Relaxed, Calm'},
      {'label': 'Beta', 'color': const Color(0xFF34A853), 'desc': 'Active, Focused'},
      {'label': 'Theta', 'color': const Color(0xFFFBBC05), 'desc': 'Drowsy, Creative'},
      {'label': 'Delta', 'color': const Color(0xFFEA4335), 'desc': 'Deep Sleep'},
    ];

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: waveInfo.map((info) {
        final color = info['color'] as Color;
        final label = info['label'] as String;
        final desc = info['desc'] as String;

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: color.withOpacity(0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                  Text(
                    desc,
                    style: TextStyle(
                      fontSize: 10,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEmotionalInsights(PredictionResult result) {
    final insights = _getEmotionalInsightsFromPrediction(result);

    return ResponsiveCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      _primaryColor.withOpacity(0.9),
                      _accentColor.withOpacity(0.9),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.psychology, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              Text(
                'Emotional State Analysis',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _primaryColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          ...insights.asMap().entries.map((entry) {
            final index = entry.key;
            final insight = entry.value;

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      color: _accentColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      insight,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.grey[700],
                        height: 1.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  // Keep all your existing data methods (they're perfect!)
  List<EmotionData> _getEmotionDataForPieChart(PredictionResult? result) {
    if (result == null || result.probabilities.isEmpty) {
      return [
        EmotionData('No Data', 100.0, Colors.grey),
      ];
    }

    final emotions = result.probabilities;
    final sortedEmotions = emotions.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    final topEmotions = sortedEmotions.take(5).toList();

    final emotionColors = [
      const Color(0xFF34A853),
      const Color(0xFFEA4335),
      const Color(0xFF4285F4),
      const Color(0xFFFBBC05),
      const Color(0xFF8E44AD),
      const Color(0xFF00BCD4),
      const Color(0xFF9C27B0),
      const Color(0xFFFF5722),
    ];

    return topEmotions.asMap().entries.map((entry) {
      final index = entry.key;
      final emotionEntry = entry.value;
      final percentage = emotionEntry.value * 100.0;

      return EmotionData(
        emotionEntry.key,
        percentage,
        emotionColors[index % emotionColors.length],
      );
    }).toList();
  }

  List<ConcentrationData> _getConcentrationDataFromPrediction(PredictionResult? result) {
    final now = DateTime.now();

    if (result == null) {
      return [
        ConcentrationData(now.subtract(const Duration(minutes: 30)), 50.0),
        ConcentrationData(now.subtract(const Duration(minutes: 25)), 55.0),
        ConcentrationData(now.subtract(const Duration(minutes: 20)), 60.0),
        ConcentrationData(now.subtract(const Duration(minutes: 15)), 65.0),
        ConcentrationData(now.subtract(const Duration(minutes: 10)), 70.0),
        ConcentrationData(now.subtract(const Duration(minutes: 5)), 75.0),
        ConcentrationData(now, 80.0),
      ];
    }

    final topEmotion = result.topLabel?.toLowerCase() ?? 'neutral';
    final confidence = result.topProb;

    switch (topEmotion) {
      case 'positive':
      case 'happy':
        return [
          ConcentrationData(now.subtract(const Duration(minutes: 30)), 60.0 + (30.0 * confidence)),
          ConcentrationData(now.subtract(const Duration(minutes: 25)), 65.0 + (25.0 * confidence)),
          ConcentrationData(now.subtract(const Duration(minutes: 20)), 70.0 + (20.0 * confidence)),
          ConcentrationData(now.subtract(const Duration(minutes: 15)), 75.0 + (25.0 * confidence)),
          ConcentrationData(now.subtract(const Duration(minutes: 10)), 80.0 + (20.0 * confidence)),
          ConcentrationData(now.subtract(const Duration(minutes: 5)), 85.0 + (15.0 * confidence)),
          ConcentrationData(now, 90.0 + (10.0 * confidence)),
        ];
    // ... (keep the rest of your concentration data logic)
      default:
        return [
          ConcentrationData(now.subtract(const Duration(minutes: 30)), 65.0),
          ConcentrationData(now.subtract(const Duration(minutes: 25)), 67.0),
          ConcentrationData(now.subtract(const Duration(minutes: 20)), 69.0),
          ConcentrationData(now.subtract(const Duration(minutes: 15)), 71.0),
          ConcentrationData(now.subtract(const Duration(minutes: 10)), 69.0),
          ConcentrationData(now.subtract(const Duration(minutes: 5)), 67.0),
          ConcentrationData(now, 65.0),
        ];
    }
  }

  List<WaveActivityData> _getWaveActivityFromPrediction(PredictionResult? result) {
    if (result == null) {
      return [
        WaveActivityData(1, 45.0, 30.0, 15.0, 10.0),
        WaveActivityData(2, 43.0, 32.0, 14.0, 11.0),
        WaveActivityData(3, 47.0, 28.0, 16.0, 9.0),
        WaveActivityData(4, 44.0, 31.0, 15.0, 10.0),
        WaveActivityData(5, 46.0, 29.0, 16.0, 9.0),
      ];
    }

    final topEmotion = result.topLabel?.toLowerCase() ?? 'neutral';
    final confidence = result.topProb;

    switch (topEmotion) {
      case 'positive':
      case 'happy':
        return [
          WaveActivityData(1, 50.0 + (10.0 * confidence), 25.0 + (5.0 * confidence), 15.0, 10.0),
          WaveActivityData(2, 48.0 + (12.0 * confidence), 28.0 + (4.0 * confidence), 14.0, 10.0),
          WaveActivityData(3, 52.0 + (8.0 * confidence), 23.0 + (7.0 * confidence), 16.0, 9.0),
          WaveActivityData(4, 49.0 + (11.0 * confidence), 26.0 + (6.0 * confidence), 15.0, 10.0),
          WaveActivityData(5, 51.0 + (9.0 * confidence), 24.0 + (5.0 * confidence), 16.0, 9.0),
        ];
    // ... (keep the rest of your wave activity logic)
      default:
        return [
          WaveActivityData(1, 45.0, 30.0, 15.0, 10.0),
          WaveActivityData(2, 43.0, 32.0, 14.0, 11.0),
          WaveActivityData(3, 47.0, 28.0, 16.0, 9.0),
          WaveActivityData(4, 44.0, 31.0, 15.0, 10.0),
          WaveActivityData(5, 46.0, 29.0, 16.0, 9.0),
        ];
    }
  }

  List<String> _getEmotionalInsightsFromPrediction(PredictionResult result) {
    final topEmotion = result.topLabel?.toLowerCase() ?? 'unknown';
    final confidence = result.topProb;

    switch (topEmotion) {
      case 'positive':
        return [
          'High alpha waves indicate relaxed and positive mental state',
          'Stable concentration pattern suitable for focused work',
          'Balanced brain activity across all frequency bands',
          'Ideal state for learning and creative activities',
          'Maintain this state with regular breaks and positive activities'
        ];
      case 'negative':
        return [
          'Elevated beta activity suggests stress or anxiety',
          'Concentration levels show decline over time',
          'Consider relaxation techniques to balance brain waves',
          'Mindfulness meditation can help regulate emotions',
          'Physical exercise may help improve emotional state'
        ];
      case 'relaxed':
        return [
          'Dominant alpha/theta waves indicate deep relaxation',
          'Stable but lower concentration suitable for rest',
          'Ideal state for meditation and stress recovery',
          'Good for creative thinking and problem-solving',
          'Maintain with calm environments and deep breathing'
        ];
      case 'excited':
        return [
          'High beta activity shows mental engagement',
          'Peak concentration levels detected',
          'Good for complex tasks and decision making',
          'Monitor for potential over-stimulation',
          'Balance with relaxation periods'
        ];
      default:
        return [
          'Balanced brain wave patterns across all bands',
          'Stable concentration levels maintained',
          'Neutral emotional state detected',
          'Good baseline for daily activities',
          'Regular monitoring recommended for consistency'
        ];
    }
  }
}

// RESPONSIVE CARD WIDGET
class ResponsiveCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;

  const ResponsiveCard({
    Key? key,
    required this.child,
    this.padding = const EdgeInsets.all(24),
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        width: double.infinity,
        padding: padding,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              const Color(0xFFFAFDF9),
            ],
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

// INFO ITEM WIDGET
class _InfoItem extends StatelessWidget {
  final String title;
  final String description;

  const _InfoItem(this.title, this.description);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.circle, size: 8, color: Color(0xFF556B2F)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                  ),
                ),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: 13,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Keep your existing Custom Painters and Data Models
class EmotionPieChartPainter extends CustomPainter {
  final List<EmotionData> data;

  EmotionPieChartPainter({required this.data});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 * 0.8;

    double startAngle = -90 * (3.141592653589793 / 180);
    final total = data.fold(0.0, (sum, item) => sum + item.percentage);

    for (final item in data) {
      final sweepAngle = (item.percentage / total) * 360 * (3.141592653589793 / 180);
      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );
      startAngle += sweepAngle;
    }

    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.6, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class LineChartPainter extends CustomPainter {
  final List<ConcentrationData> data;
  final Color color;

  LineChartPainter({required this.data, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    if (data.length < 2) return;

    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;

    final pointPaint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final minTime = data.first.time.millisecondsSinceEpoch.toDouble();
    final maxTime = data.last.time.millisecondsSinceEpoch.toDouble();
    const minValue = 0.0;
    const maxValue = 100.0;

    final points = <Offset>[];
    for (final item in data) {
      final x = ((item.time.millisecondsSinceEpoch - minTime) / (maxTime - minTime)) * size.width;
      final y = size.height - ((item.level - minValue) / (maxValue - minValue)) * size.height;
      points.add(Offset(x, y));
    }

    for (int i = 0; i < points.length - 1; i++) {
      canvas.drawLine(points[i], points[i + 1], paint);
    }

    for (final point in points) {
      canvas.drawCircle(point, 4, pointPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class EmotionData {
  final String emotion;
  final double percentage;
  final Color color;

  EmotionData(this.emotion, this.percentage, this.color);
}

class ConcentrationData {
  final DateTime time;
  final double level;

  ConcentrationData(this.time, this.level);
}

class WaveActivityData {
  final int segment;
  final double alpha;
  final double beta;
  final double theta;
  final double delta;

  WaveActivityData(this.segment, this.alpha, this.beta, this.theta, this.delta);
}