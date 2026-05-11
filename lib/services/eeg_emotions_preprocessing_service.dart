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
    // Note: Aapke pichle context ke labels (0: happy, 1: sad, 2: calm)
    // aur is code ke labels (0: NEGATIVE, 1: NEUTRAL, 2: POSITIVE, etc.)
    // mein farq hai. Kripya apne TFLite model ke output ke saath inko confirm karein.
    0: 'NEGATIVE',
    1: 'NEUTRAL',
    2: 'POSITIVE',
    3: 'RELAXED',
    4: 'EXCITED',
  };

  /// Parse and validate CSV from birdy654 dataset
  static Map<String, dynamic> parseAndValidateCSV(String csvContent) {
    // 1. CSV content ko basic clean karein
    final cleanedContent = csvContent
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
    // FIX: Saare double quotes ko hata dein taaki simple split kaam kare
        .replaceAll('"', '')
        .trim();

    final lines = cleanedContent.split('\n');
    if (lines.isEmpty) throw Exception('CSV is empty');

    // 2. Parse headers
    // Ab headers mein quotes nahi honge
    final headers = lines[0].split(',').map((e) => e.trim()).toList();
    print('🔍 Found headers: $headers');

    // 3. Parse data rows
    final dataRows = <List<String>>[];
    for (int i = 1; i < lines.length; i++) {
      final line = lines[i].trim();
      if (line.isNotEmpty) {
        // Ab row mein bhi quotes nahi honge
        final row = line.split(',').map((e) => e.trim()).toList();
        dataRows.add(row);
      }
    }

    print('📊 Total data rows: ${dataRows.length}');

    // 4. Feature matching (Yeh logic ab sahi kaam karega)
    final featureIndices = <String, int>{};
    for (final feature in requiredFeatures) {
      // Headers mein ab sirf 'mean_0_a' hoga, '"mean_0_a' nahi
      final index = headers.indexWhere(
              (h) => h.toLowerCase() == feature.toLowerCase()
      );

      if (index == -1) {
        throw Exception('Missing required feature: $feature');
      }

      featureIndices[feature] = index;
      print('✅ Feature "$feature" found at index $index');
    }

    // ... (Baaki label/data extraction logic remains the same) ...
    // Note: Agar aap data parsing mein sirf trim() par bharosa karte hain,
    // toh aapko is code ke andar ka `double.tryParse(row[idx])` bhi ab sahi values dega.

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

  // ... (Baaki normalizeFeatures, standardizeFeatures, etc. methods remains the same) ...

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
4.070241,11.187129,-7.3446016,-10.048934,-4.3592796,0
9.652575,18.738031,10.438069,2.5281003,8.505379,2
-2.341562,5.234891,-12.456732,-8.234561,-6.789234,1
6.234567,14.567890,-5.123456,-8.765432,-3.456789,0
12.345678,21.987654,15.678901,5.432109,11.234567,2
-5.123456,3.456789,-15.678901,-12.345678,-8.901234,1
7.890123,16.789012,-3.456789,-6.789012,-2.345678,0
15.678901,25.678901,18.901234,8.901234,14.567890,2''';
  }

  /// Get emotion name from label index
  static String getEmotionLabel(int labelIndex) {
    return emotionLabels[labelIndex] ?? 'UNKNOWN';
  }
}