import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/prediction_result.dart';

class PredictionFirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Save prediction to Firebase
  Future<void> savePrediction({
    required String emotion,
    required double confidence,
    String? csvFileName,
    required String method,
    PredictionResult? result,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final now = DateTime.now();
      final dateKey = DateTime(now.year, now.month, now.day);

      final predictionData = {
        'userId': user.uid,
        'emotion': emotion,
        'confidence': confidence,
        'method': method,
        'csvFileName': csvFileName,
        'date': Timestamp.now(),
        'dateKey': dateKey.millisecondsSinceEpoch,
        'timestamp': now.millisecondsSinceEpoch,
        'fullResult': result != null ? result.toMap() : null,
      };

      // Save to user's predictions collection
      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('predictions')
          .add(predictionData);

      print('Prediction saved to Firebase for user: ${user.uid}');
    } catch (e) {
      print('Error saving prediction to Firebase: $e');
      rethrow;
    }
  }

  // Get predictions for a specific date
  Future<List<Map<String, dynamic>>> getPredictionsForDate(DateTime date) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return [];
      }

      final startOfDay = DateTime(date.year, date.month, date.day);
      final endOfDay = DateTime(date.year, date.month, date.day, 23, 59, 59);

      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('predictions')
          .where('date', isGreaterThanOrEqualTo: Timestamp.fromDate(startOfDay))
          .where('date', isLessThanOrEqualTo: Timestamp.fromDate(endOfDay))
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'date': (data['date'] as Timestamp).toDate(),
        };
      }).toList();
    } catch (e) {
      print('Error getting predictions for date: $e');
      return [];
    }
  }

  // Get all dates that have predictions
  Future<List<DateTime>> getDatesWithPredictions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return [];
      }

      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('predictions')
          .orderBy('date', descending: true)
          .get();

      final dates = <DateTime>{};
      for (final doc in querySnapshot.docs) {
        final data = doc.data();
        final date = (data['date'] as Timestamp).toDate();
        final dateKey = DateTime(date.year, date.month, date.day);
        dates.add(dateKey);
      }

      return dates.toList();
    } catch (e) {
      print('Error getting dates with predictions: $e');
      return [];
    }
  }

  // Get all predictions (for history screen)
  Future<List<Map<String, dynamic>>> getAllPredictions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        return [];
      }

      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('predictions')
          .orderBy('date', descending: true)
          .get();

      return querySnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'date': (data['date'] as Timestamp).toDate(),
        };
      }).toList();
    } catch (e) {
      print('Error getting all predictions: $e');
      return [];
    }
  }

  // Delete a prediction
  Future<void> deletePrediction(String predictionId) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('predictions')
          .doc(predictionId)
          .delete();

      print('Prediction deleted: $predictionId');
    } catch (e) {
      print('Error deleting prediction: $e');
      rethrow;
    }
  }

  // Clear all predictions for current user
  Future<void> clearAllPredictions() async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        throw Exception('User not logged in');
      }

      final querySnapshot = await _firestore
          .collection('users')
          .doc(user.uid)
          .collection('predictions')
          .get();

      final batch = _firestore.batch();
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      await batch.commit();
      print('All predictions cleared for user: ${user.uid}');
    } catch (e) {
      print('Error clearing predictions: $e');
      rethrow;
    }
  }
}