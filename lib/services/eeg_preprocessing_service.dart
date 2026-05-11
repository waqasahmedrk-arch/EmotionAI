import 'dart:math' as math;

class EEGEmotionsPreprocessingService {
  // Required features for birdy654 EEG emotions dataset
  static const List<String> requiredFeatures = [
    'mean_0_a',
    'mean_1_a',
    'mean_2_a',
    'mean_3_a',
    'mean_4_a'
  ];

  // Emotion labels
  static const Map<int, String> emotionLabels = {
    0: 'NEGATIVE',
    1: 'NEUTRAL',
    2: 'POSITIVE',
    3: 'RELAXED',
    4: 'EXCITED',
  };

  /// Parse and validate CSV from birdy654 dataset
  static Map<String, dynamic> parseAndValidateCSV(String csvContent) {
    // Clean CSV content
    final cleanedContent = csvContent
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .trim();

    final lines = cleanedContent.split('\n');
    if (lines.isEmpty) throw Exception('CSV is empty');

    // Parse headers
    final headers = lines[0].split(',').map((e) => e.trim()).toList();
    print('🔍 Found headers: $headers');

    // Parse data rows
    final dataRows = <List<String>>[];
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) {
        final row = line.split(',').map((e) => e.trim()).toList();
        dataRows.add(row);
      }
    }

    print('📊 Total data rows: ${dataRows.length}');

    // Case-insensitive feature matching
    final featureIndices = <String, int>{};
    for (final feature in requiredFeatures) {
      final index = headers.indexWhere(
              (h) => h.toLowerCase() == feature.toLowerCase()
      );

      if (index == -1) {
        throw Exception('Missing required feature: $feature');
      }

      featureIndices[feature] = index;
      print('✅ Feature "$feature" found at index $index');
    }

    // Check for label column (optional)
    int? labelIndex;
    final labelHeaders = ['label', 'emotion', 'class', 'target'];
    for (final labelHeader in labelHeaders) {
      labelIndex = headers.indexWhere(
              (h) => h.toLowerCase() == labelHeader.toLowerCase()
      );
      if (labelIndex != -1) {
        print('✅ Label column found: ${headers[labelIndex]} at index $labelIndex');
        break;
      }
    }

    // Extract feature data
    final features = <List<double>>[];
    final labels = <int>[];

    for (int rowIdx = 0; rowIdx < dataRows.length; rowIdx++) {
      final row = dataRows[rowIdx];
      final featureRow = <double>[];

      try {
        // Extract 5 features in order
        for (final feature in requiredFeatures) {
          final idx = featureIndices[feature]!;
          if (idx < row.length) {
            final value = double.tryParse(row[idx]) ?? 0.0;
            featureRow.add(value);
          } else {
            featureRow.add(0.0);
          }
        }

        features.add(featureRow);

        // Extract label if available
        if (labelIndex != null && labelIndex < row.length) {
          final labelValue = int.tryParse(row[labelIndex]) ?? 0;
          labels.add(labelValue);
        }
      } catch (e) {
        print('⚠️  Error parsing row $rowIdx: $e');
        continue;
      }
    }

    print('✅ Parsed ${features.length} samples with 5 features each');

    return {
      'features': features,
      'labels': labels,
      'samples': features.length,
      'featureNames': requiredFeatures,
    };
  }

  /// Normalize features using min-max scaling
  static List<List<double>> normalizeFeatures(List<List<double>> features) {
    if (features.isEmpty) return features;

    final numFeatures = features[0].length;
    final mins = List<double>.filled(numFeatures, double.infinity);
    final maxs = List<double>.filled(numFeatures, -double.infinity);

    // Find min and max for each feature
    for (final sample in features) {
      for (int i = 0; i < numFeatures; i++) {
        if (sample[i] < mins[i]) mins[i] = sample[i];
        if (sample[i] > maxs[i]) maxs[i] = sample[i];
      }
    }

    // Normalize each feature to [0, 1]
    final normalized = <List<double>>[];
    for (final sample in features) {
      final normalizedSample = <double>[];
      for (int i = 0; i < numFeatures; i++) {
        final range = maxs[i] - mins[i];
        if (range > 0) {
          normalizedSample.add((sample[i] - mins[i]) / range);
        } else {
          normalizedSample.add(0.5); // If all values are same, use middle value
        }
      }
      normalized.add(normalizedSample);
    }

    print('✅ Normalized ${normalized.length} samples');
    return normalized;
  }

  /// Standardize features using z-score normalization
  static List<List<double>> standardizeFeatures(List<List<double>> features) {
    if (features.isEmpty) return features;

    final numFeatures = features[0].length;
    final means = List<double>.filled(numFeatures, 0.0);
    final stds = List<double>.filled(numFeatures, 0.0);

    // Calculate means
    for (final sample in features) {
      for (int i = 0; i < numFeatures; i++) {
        means[i] += sample[i];
      }
    }
    for (int i = 0; i < numFeatures; i++) {
      means[i] /= features.length;
    }

    // Calculate standard deviations
    for (final sample in features) {
      for (int i = 0; i < numFeatures; i++) {
        stds[i] += math.pow(sample[i] - means[i], 2);
      }
    }
    for (int i = 0; i < numFeatures; i++) {
      stds[i] = math.sqrt(stds[i] / features.length);
    }

    // Standardize
    final standardized = <List<double>>[];
    for (final sample in features) {
      final standardizedSample = <double>[];
      for (int i = 0; i < numFeatures; i++) {
        if (stds[i] > 0) {
          standardizedSample.add((sample[i] - means[i]) / stds[i]);
        } else {
          standardizedSample.add(0.0);
        }
      }
      standardized.add(standardizedSample);
    }

    print('✅ Standardized ${standardized.length} samples');
    return standardized;
  }

  /// Convert CSV to model input format: [1, 5] (float32)
  static List<List<double>> csvToModelInput(
      String csvContent, {
        bool normalize = true,
        bool standardize = false,
      }) {
    print('🔄 Starting CSV to model input conversion...');

    final parsed = parseAndValidateCSV(csvContent);
    var features = parsed['features'] as List<List<double>>;

    if (features.isEmpty) {
      throw Exception('No valid features extracted from CSV');
    }

    // Apply preprocessing
    if (standardize) {
      features = standardizeFeatures(features);
    } else if (normalize) {
      features = normalizeFeatures(features);
    }

    print('✅ Model input ready: [${features.length}, 5]');
    print('📊 First sample: ${features[0]}');

    return features;
  }

  /// Convert single row of features to model input
  static List<List<double>> featuresToModelInput(List<double> features) {
    if (features.length != 5) {
      throw Exception('Expected 5 features, got ${features.length}');
    }

    return [features];
  }

  /// Create sample test data
  static String generateSampleCSV() {
    return '''mean_0_a,mean_1_a,mean_2_a,mean_3_a,mean_4_a,label
8.234567,15.678901,6.543210,-2.345678,9.876543,0
9.123456,17.345678,8.234567,-1.234567,10.987654,0
7.890123,14.567890,5.432109,-3.456789,8.765432,0
8.765432,16.234567,7.890123,-1.987654,11.234567,0
9.876543,18.456789,9.123456,-0.876543,12.345678,0
8.345678,15.987654,6.789012,-2.123456,10.123456,0
7.654321,13.890123,4.567890,-4.321098,7.654321,0
9.234567,17.123456,8.765432,-1.345678,11.876543,0
8.123456,14.456789,5.678901,-3.123456,9.234567,0
9.345678,16.789012,7.456789,-2.234567,10.456789,0
''';
  }

  /// Get emotion name from label index
  static String getEmotionLabel(int labelIndex) {
    return emotionLabels[labelIndex] ?? 'UNKNOWN';
  }
}


