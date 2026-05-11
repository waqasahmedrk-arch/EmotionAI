import 'package:flutter/foundation.dart';
import 'eeg_model_service.dart';
import 'models/prediction_result.dart' as custom_models;

class ModelHost extends ChangeNotifier {
  final EegModelService svc = EegModelService();

  bool ready = false;
  String status = 'Not initialized';
  final List<String> logs = [];
  custom_models.PredictionResult? _lastPredictionResult;

  custom_models.PredictionResult? get lastPredictionResult => _lastPredictionResult;

  void _log(String m) {
    logs.add(m);
    if (logs.length > 200) logs.removeRange(0, logs.length - 200);
    notifyListeners();
  }

  Future<void> initModel() async {
    ready = false;
    status = 'Loading model…';
    _log(status);
    notifyListeners();

    try {
      await svc.init();
      ready = true;
      status = 'Model ready\n${svc.summary()}';
      _log(status);
    } catch (e) {
      ready = false;
      status = 'Init error: $e';
      _log(status);
    }
    notifyListeners();
  }

  Future<void> dryRun() async {
    if (!ready) {
      _log('Dry run skipped: model not ready');
      return;
    }
    try {
      _log(await svc.dryRun());
    } catch (e) {
      _log('Dry run failed: $e');
    }
  }

  Future<PredictionResult> predictFromCSV(String csvContent) async {
    if (!ready) throw StateError('Model not ready');
    _log('Starting CSV prediction...');
    notifyListeners();

    try {
      final result = await svc.predictFromCSV(csvContent);

      // UPDATED: Use the probabilities from the model directly
      _lastPredictionResult = custom_models.PredictionResult(
        topLabel: result.topLabel,
        topProb: result.topProb,
        probabilities: result.allProbabilities, // Use actual model output
      );

      _log('Prediction: ${result.topLabel} (${(result.topProb * 100).toStringAsFixed(1)}%)');
      _log('All probabilities: ${result.allProbabilities}');
      notifyListeners();

      return result;
    } catch (e) {
      _log('Prediction failed: $e');
      rethrow;
    }
  }

  void setLastPrediction(custom_models.PredictionResult result) {
    _lastPredictionResult = result;
    notifyListeners();
  }

  void clearLastPrediction() {
    _lastPredictionResult = null;
    notifyListeners();
  }

  @override
  void dispose() {
    svc.close();
    super.dispose();
  }
}