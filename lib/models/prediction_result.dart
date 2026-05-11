class PredictionResult {
  final Map<String, double> probabilities;
  final String? topLabel;
  final double topProb;

  PredictionResult({
    required this.probabilities,
    this.topLabel,
    this.topProb = 0.0,
  });

  // Factory constructor from map
  factory PredictionResult.fromMap(Map<String, dynamic> map) {
    final probabilitiesMap = <String, double>{};
    if (map['probabilities'] != null) {
      (map['probabilities'] as Map).forEach((key, value) {
        probabilitiesMap[key.toString()] = (value as num).toDouble();
      });
    }

    // Calculate top label and probability if not provided
    String? calculatedTopLabel;
    double calculatedTopProb = 0.0;

    if (probabilitiesMap.isNotEmpty) {
      var topEntry = probabilitiesMap.entries.first;
      for (var entry in probabilitiesMap.entries) {
        if (entry.value > topEntry.value) {
          topEntry = entry;
        }
      }
      calculatedTopLabel = topEntry.key;
      calculatedTopProb = topEntry.value;
    }

    return PredictionResult(
      probabilities: probabilitiesMap,
      topLabel: map['topLabel'] as String? ?? calculatedTopLabel,
      topProb: (map['topProb'] as num?)?.toDouble() ?? calculatedTopProb,
    );
  }

  // Convert to map
  Map<String, dynamic> toMap() {
    return {
      'probabilities': probabilities,
      'topLabel': topLabel,
      'topProb': topProb,
    };
  }

  // Get sorted emotions by confidence (highest first)
  List<MapEntry<String, double>> get sortedProbabilities {
    final entries = probabilities.entries.toList();
    entries.sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  // Get top N emotions
  List<MapEntry<String, double>> getTopEmotions(int count) {
    final sorted = sortedProbabilities;
    return sorted.take(count).toList();
  }

  // Get confidence for a specific emotion
  double getConfidenceForEmotion(String emotion) {
    return probabilities[emotion] ?? 0.0;
  }

  // Confidence level helpers
  bool get isHighConfidence => topProb > 0.7;
  bool get isMediumConfidence => topProb > 0.5 && topProb <= 0.7;
  bool get isLowConfidence => topProb <= 0.5;

  @override
  String toString() {
    return 'PredictionResult{topLabel: $topLabel, topProb: ${(topProb * 100).toStringAsFixed(1)}%, probabilities: $probabilities}';
  }
}