import 'package:tflite_flutter/tflite_flutter.dart';
import 'services/eeg_emotions_preprocessing_service.dart';
import 'dart:math' as math;

class PredictionResult {
  final String topLabel;
  final double topProb;
  final Map<String, double> allProbabilities;

  PredictionResult({
    required this.topLabel,
    required this.topProb,
    required this.allProbabilities,
  });
}

class EegModelService {
  Interpreter? _interpreter;
  List<int>? _inputShape;
  List<int>? _outputShape;

  // Emotion labels for 3-class model
  final List<String> _labels = ['NEGATIVE', 'NEUTRAL', 'POSITIVE'];

  bool get isReady => _interpreter != null;

  Future<void> init() async {
    try {
      print('🔄 Loading TFLite model...');
      _interpreter = await Interpreter.fromAsset('assets/models/emotion_model.tflite');

      _inputShape = _interpreter!.getInputTensor(0).shape;
      _outputShape = _interpreter!.getOutputTensor(0).shape;

      print('✅ Model loaded successfully!');
      print('📥 Input shape: $_inputShape');
      print('📤 Output shape: $_outputShape');
    } catch (e) {
      print('❌ Model initialization failed: $e');
      rethrow;
    }
  }

  String summary() {
    if (_interpreter == null) return 'Model not loaded';
    return 'Input: $_inputShape (float32)\nOutput: $_outputShape (float32)\nLabels: ${_labels.length}';
  }

  Future<String> dryRun() async {
    if (_interpreter == null) throw StateError('Model not initialized');

    try {
      print('🧪 Running dry run with zeros...');

      // Create input: [1, 5] filled with zeros
      final input = [List<double>.filled(5, 0.0)];

      // Create output buffer based on actual shape
      final output = _createOutputBuffer();

      _interpreter!.run(input, output);

      print('✅ Dry run successful!');
      print('📊 Output: $output');

      return 'Dry run OK\nOutput shape: ${_outputShape}\nSample output: $output';
    } catch (e) {
      print('❌ Dry run failed: $e');
      return 'Dry run failed: $e';
    }
  }

  Future<PredictionResult> predictFromCSV(String csvContent) async {
    if (_interpreter == null) throw StateError('Model not initialized');

    try {
      print('🔄 Processing CSV for prediction...');

      // Preprocess CSV
      final features = EEGEmotionsPreprocessingService.csvToModelInput(
        csvContent,
        normalize: true,
      );

      if (features.isEmpty) {
        throw Exception('No features extracted from CSV');
      }

      // Use first sample
      final input = [features[0]]; // [1, 5]
      print('📊 Input: $input');

      // Create output buffer
      final output = _createOutputBuffer();

      print('🧠 Running inference...');
      _interpreter!.run(input, output);
      print('📊 Raw output: $output');

      // Process output
      final probabilities = _processOutput(output);
      print('📊 Processed probabilities: $probabilities');

      // Get top prediction
      final sortedEntries = probabilities.entries.toList()
        ..sort((a, b) => b.value.compareTo(a.value));

      final topLabel = sortedEntries.first.key;
      final topProb = sortedEntries.first.value;

      return PredictionResult(
        topLabel: topLabel,
        topProb: topProb,
        allProbabilities: probabilities,
      );
    } catch (e) {
      print('❌ Prediction failed: $e');
      rethrow;
    }
  }

  /// Create output buffer with correct shape
  dynamic _createOutputBuffer() {
    if (_outputShape == null) throw StateError('Output shape not available');

    // Handle different output shapes
    if (_outputShape!.length == 2) {
      // Shape: [batch, classes] e.g., [1, 3] or [5, 3]
      final rows = _outputShape![0];
      final cols = _outputShape![1];
      return List.generate(rows, (_) => List<double>.filled(cols, 0.0));
    } else if (_outputShape!.length == 1) {
      // Shape: [classes] e.g., [3]
      return List<double>.filled(_outputShape![0], 0.0);
    } else {
      throw Exception('Unsupported output shape: $_outputShape');
    }
  }

  /// Process model output to get probabilities
  Map<String, double> _processOutput(dynamic output) {
    List<double> logits;

    if (output is List<List<double>>) {
      // Output is [5, 3] or [1, 3]
      print('📊 Output is 2D: ${output.length}x${output[0].length}');

      if (output.length == 1) {
        // [1, 3] - use directly
        logits = output[0];
      } else {
        // [5, 3] - average across rows
        logits = _averageRows(output);
      }
    } else if (output is List<double>) {
      // Output is [3]
      logits = output;
    } else {
      throw Exception('Unexpected output type: ${output.runtimeType}');
    }

    print('📊 Logits before softmax: $logits');

    // Apply softmax
    final probabilities = _softmax(logits);
    print('📊 Probabilities after softmax: $probabilities');

    // Map to labels
    final result = <String, double>{};
    for (int i = 0; i < math.min(probabilities.length, _labels.length); i++) {
      result[_labels[i]] = probabilities[i];
    }

    return result;
  }

  /// Average across multiple rows
  List<double> _averageRows(List<List<double>> output) {
    final numCols = output[0].length;
    final averaged = List<double>.filled(numCols, 0.0);

    for (final row in output) {
      for (int i = 0; i < numCols; i++) {
        averaged[i] += row[i];
      }
    }

    for (int i = 0; i < numCols; i++) {
      averaged[i] /= output.length;
    }

    print('📊 Averaged output: $averaged');
    return averaged;
  }

  /// Apply softmax to convert logits to probabilities
  List<double> _softmax(List<double> logits) {
    // Find max for numerical stability
    final maxLogit = logits.reduce((a, b) => a > b ? a : b);

    // Compute exp(x - max)
    final expValues = logits.map((x) => math.exp(x - maxLogit)).toList();

    // Sum of exp values
    final sumExp = expValues.reduce((a, b) => a + b);

    // Normalize
    return expValues.map((x) => x / sumExp).toList();
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
  }
}