import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:provider/provider.dart';
import 'package:file_picker/file_picker.dart';
import '../model_host.dart';
import '../services/neurosky_bluetooth_service.dart';
import '../services/prediction_history_service.dart';
import '../services/prediction_firebase_service.dart';
import '../models/prediction_result.dart';
import '../models/prediction_history.dart';
import 'chatbot_screen.dart';
import 'headset_connection_screen.dart';
import 'prediction_history_screen.dart';
import 'date_history_screen.dart';
import 'dart:convert';


class PredictPage extends StatefulWidget {
  const PredictPage({super.key});

  @override
  State<PredictPage> createState() => _PredictPageState();
}

class _PredictPageState extends State<PredictPage> with SingleTickerProviderStateMixin {
  String? _selectedFileName;
  String? _csvContent;
  bool _isProcessing = false;
  bool _isLoadingFile = false;
  PredictionResult? _lastResult;
  List<String> _processingSteps = [];
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  // Neurosky Bluetooth service
  final NeuroskyBluetoothService _neuroskyService = NeuroskyBluetoothService();

  // Firebase service
  final PredictionFirebaseService _firebaseService = PredictionFirebaseService();

  // Real-time processing
  List<Map<String, dynamic>> _neuroskyDataLogs = [];
  Timer? _realtimePredictionTimer;
  bool _isRealtimeProcessing = false;
  List<List<double>> _eegDataBuffer = [];
  int _samplesProcessed = 0;

  // Stream subscriptions
  StreamSubscription<bool>? _scanningSubscription;
  StreamSubscription<bool>? _connectingSubscription;
  StreamSubscription<bool>? _connectedSubscription;
  StreamSubscription<Map<String, dynamic>>? _neuroskyDataSubscription;
  StreamSubscription<String>? _statusSubscription;

  // State variables
  bool _showFileOptions = false;
  bool _showProcessingSteps = false;
  DateTime _selectedDay = DateTime.now();
  List<PredictionRecord> _predictionsForSelectedDay = [];
  String _calendarView = 'Weekly';
  DateTime _currentMonth = DateTime.now();
  List<DateTime> _datesWithPredictions = [];
  bool _isLoadingPredictions = false;

  // Color Scheme
  final Color _browseCsvBackgroundColor = const Color(0xFF4699E2);
  final Color _connectHeadsetBackgroundColor = const Color(0xFF3DC75A);
  final Color _startDetectionGradientStart = const Color(0xFF904FCB);
  final Color _startDetectionGradientEnd = const Color(0xFFF545B8);
  final Color _beginSessionBackgroundColor = const Color(0xFFFFFFFF);

  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _cardColor = Colors.white;
  final Color _textPrimary = const Color(0xFF212121);
  final Color _textSecondary = const Color(0xFF757575);
  final Color _successColor = const Color(0xFF4CAF50);
  final Color _warningColor = const Color(0xFFFF9800);
  final Color _errorColor = const Color(0xFFF44336);
  final Color _infoColor = const Color(0xFF2196F3);
  final Color _borderColor = const Color(0xFFE0E0E0);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeAnimations();
      _initializeBluetooth();
      _setupNeuroskyListeners();
      _loadPredictions();
    });
  }

  void _initializeAnimations() {
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 500),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  void _initializeBluetooth() {
    _neuroskyService.initialize();

    _scanningSubscription = _neuroskyService.scanningStream.listen((isScanning) {
      if (mounted) setState(() {});
    });

    _connectingSubscription = _neuroskyService.connectingStream.listen((isConnecting) {
      if (mounted) setState(() {});
    });

    _connectedSubscription = _neuroskyService.connectedStream.listen((isConnected) {
      if (mounted) setState(() {});
    });
  }

  void _setupNeuroskyListeners() {
    _neuroskyDataSubscription = _neuroskyService.neuroskyDataStream.listen((data) {
      _handleNeuroskyData(data);
    });

    _statusSubscription = _neuroskyService.statusStream.listen((status) {
      _addProcessingStep(status, _infoColor);
    });
  }

  Future<void> _loadPredictions() async {
    if (!mounted) return;

    setState(() {
      _isLoadingPredictions = true;
    });

    try {
      // Load dates with predictions
      final dates = await _firebaseService.getDatesWithPredictions();

      // Load predictions for selected day
      final firebaseData = await _firebaseService.getPredictionsForDate(_selectedDay);
      final predictions = firebaseData.map((data) => PredictionRecord.fromMap({
        'id': data['id'] ?? '',
        'dateTime': data['date'].toString(),
        'emotion': data['emotion'] ?? 'Unknown',
        'confidence': data['confidence'] ?? 0.0,
        'method': data['method'] ?? 'unknown',
        'csvFileName': data['csvFileName'],
      })).toList();

      if (mounted) {
        setState(() {
          _datesWithPredictions = dates;
          _predictionsForSelectedDay = predictions;
          _isLoadingPredictions = false;
        });
      }
    } catch (e) {
      print('Error loading predictions: $e');
      if (mounted) {
        setState(() {
          _isLoadingPredictions = false;
        });
      }
    }
  }

  void _handleNeuroskyData(Map<String, dynamic> data) {
    if (!mounted) return;

    setState(() {
      _neuroskyDataLogs.insert(0, {
        'timestamp': DateTime.now(),
        'data': data,
      });

      if (_neuroskyDataLogs.length > 50) {
        _neuroskyDataLogs = _neuroskyDataLogs.sublist(0, 50);
      }
    });

    final rawEeg = data['rawEeg'];
    if (rawEeg != null && rawEeg is List && rawEeg.isNotEmpty) {
      try {
        final eegData = List<double>.from(rawEeg);
        _eegDataBuffer.add(eegData);

        if (_eegDataBuffer.length > 100) {
          _eegDataBuffer = _eegDataBuffer.sublist(_eegDataBuffer.length - 50);
        }

        if (_isRealtimeProcessing && _eegDataBuffer.length >= 10) {
          _processRealtimeEEG();
        }
      } catch (e) {
        print('Error processing EEG data: $e');
      }
    }
  }

  Future<void> _processRealtimeEEG() async {
    if (_eegDataBuffer.isEmpty) return;

    final host = context.read<ModelHost>();
    if (!host.ready) return;

    try {
      final recentSamples = _eegDataBuffer.sublist(
        _eegDataBuffer.length - 10,
        _eegDataBuffer.length,
      );

      final csvData = _convertEEGToCSV(recentSamples);
      final result = await host.predictFromCSV(csvData);

      if (mounted) {
        setState(() {
          _lastResult = host.lastPredictionResult;
          _samplesProcessed += recentSamples.length;
        });

        // Save to Firebase
        if (_lastResult?.topLabel != null) {
          await _firebaseService.savePrediction(
            emotion: _lastResult!.topLabel!,
            confidence: _lastResult!.topProb,
            method: 'realtime',
            result: _lastResult,
          );

          // Refresh predictions
          _loadPredictions();
        }
      }
    } catch (e) {
      _addProcessingStep('❌ Real-time prediction error: $e', _errorColor);
    }
  }

  String _convertEEGToCSV(List<List<double>> eegSamples) {
    final header = 'mean_0_a,mean_1_a,mean_2_a,mean_3_a,mean_4_a\n';
    final rows = eegSamples.map((sample) {
      if (sample.length >= 5) {
        return '${sample[0]},${sample[1]},${sample[2]},${sample[3]},${sample[4]}';
      } else {
        final padded = List<double>.from(sample);
        while (padded.length < 5) {
          padded.add(0.0);
        }
        return '${padded[0]},${padded[1]},${padded[2]},${padded[3]},${padded[4]}';
      }
    }).join('\n');

    return header + rows;
  }

  void _startBluetoothScan() async {
    try {
      final isAvailable = await _neuroskyService.checkBluetoothAvailability();
      if (!isAvailable) {
        _showErrorDialog('Bluetooth Unavailable', 'Please enable Bluetooth and try again.');
        return;
      }

      await _neuroskyService.startScan(timeoutSeconds: 15);
      _showSuccessSnackbar('🔍 Scanning for Neurosky devices...');
    } catch (e) {
      _showErrorDialog('Scan Failed', 'Failed to start scan: ${e.toString()}');
    }
  }

  void _stopBluetoothScan() {
    _neuroskyService.stopScan();
  }

  void _connectToDevice(BluetoothDevice device) async {
    try {
      await _neuroskyService.connectToDevice(device);
      _showSuccessSnackbar('Connected to ${device.platformName}');
    } catch (e) {
      _showErrorDialog('Connection Failed', 'Failed to connect: ${e.toString()}');
    }
  }

  void _disconnectDevice() async {
    try {
      _stopRealtimeProcessing();
      await _neuroskyService.disconnectDevice();
      _showSuccessSnackbar('Disconnected from device');
    } catch (e) {
      _showErrorDialog('Disconnect Failed', 'Failed to disconnect: ${e.toString()}');
    }
  }

  void _startEEGStreaming() async {
    try {
      await _neuroskyService.startEEGStreaming();
      _showSuccessSnackbar('🎯 EEG Streaming started');
    } catch (e) {
      _showErrorDialog('Streaming Failed', 'Failed to start EEG streaming: ${e.toString()}');
    }
  }

  void _stopEEGStreaming() async {
    try {
      await _neuroskyService.stopEEGStreaming();
      _showSuccessSnackbar('⏹️ EEG Streaming stopped');
    } catch (e) {
      _showErrorDialog('Streaming Failed', 'Failed to stop EEG streaming: ${e.toString()}');
    }
  }

  void _startRealtimeProcessing() {
    if (!_neuroskyService.isStreaming) {
      _showErrorDialog('Not Streaming', 'Please start EEG streaming first');
      return;
    }

    setState(() {
      _isRealtimeProcessing = true;
      _eegDataBuffer.clear();
      _samplesProcessed = 0;
    });

    _addProcessingStep('🎯 Real-time emotion detection started', _successColor);
  }

  void _stopRealtimeProcessing() {
    setState(() {
      _isRealtimeProcessing = false;
    });

    _addProcessingStep('⏹️ Real-time emotion detection stopped', _infoColor);
  }

  Future<void> _pickCSVFile() async {
    try {
      setState(() {
        _isLoadingFile = true;
        _selectedFileName = null;
        _csvContent = null;
        _lastResult = null;
        _processingSteps.clear();
        _showFileOptions = false;
      });

      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
        allowMultiple: false,
        withData: true,
      );

      if (result == null || result.files.isEmpty) {
        setState(() => _isLoadingFile = false);
        return;
      }

      final file = result.files.first;
      if (file.bytes == null || file.bytes!.isEmpty) {
        _showErrorDialog('Invalid File', 'Selected file is empty or cannot be read');
        setState(() => _isLoadingFile = false);
        return;
      }

      final fileContent = const Utf8Decoder().convert(file.bytes!);

      if (fileContent.length < 10 || !fileContent.contains(',')) {
        _showErrorDialog('Invalid Format', 'Please select a valid CSV file');
        setState(() => _isLoadingFile = false);
        return;
      }

      setState(() {
        _selectedFileName = file.name;
        _csvContent = fileContent;
        _isLoadingFile = false;
      });

      _analyzeCSVFile(fileContent);
    } catch (e) {
      _showErrorDialog('File Selection Failed', 'Failed to select file: ${e.toString()}');
      setState(() => _isLoadingFile = false);
    }
  }

  void _analyzeCSVFile(String content) {
    try {
      _addProcessingStep('📁 File Selected: $_selectedFileName', _infoColor);
      _addProcessingStep('📊 File size: ${content.length} characters', _infoColor);

      final lines = content.split('\n');
      final nonEmptyLines = lines.where((line) => line.trim().isNotEmpty).toList();

      if (nonEmptyLines.isEmpty) {
        _addProcessingStep('❌ Error: File appears to be empty', _errorColor);
        return;
      }

      final headers = nonEmptyLines[0].split(',').map((e) => e.trim()).toList();
      _addProcessingStep('🔍 Found ${headers.length} columns in header', _infoColor);
      _addProcessingStep('📈 Found ${nonEmptyLines.length - 1} data rows', _infoColor);

      final requiredFeatures = ['mean_0_a', 'mean_1_a', 'mean_2_a', 'mean_3_a', 'mean_4_a'];
      int foundFeatures = 0;
      final List<String> missingFeatures = [];

      for (final feature in requiredFeatures) {
        bool found = headers.any((header) => header.toLowerCase() == feature.toLowerCase());
        if (found) {
          foundFeatures++;
        } else {
          missingFeatures.add(feature);
        }
      }

      _addProcessingStep('🎯 Found $foundFeatures/${requiredFeatures.length} required features',
          foundFeatures == requiredFeatures.length ? _successColor : _warningColor);

      if (missingFeatures.isNotEmpty) {
        _addProcessingStep('⚠️  Missing features: ${missingFeatures.join(', ')}', _warningColor);
      } else {
        _addProcessingStep('✅ All required features present!', _successColor);
      }

      _showSuccessSnackbar('File loaded successfully! Ready for analysis.');
    } catch (e) {
      _addProcessingStep('❌ Error analyzing CSV file: $e', _errorColor);
    }
  }

  void _addProcessingStep(String step, Color color) {
    if (mounted) {
      setState(() {
        _processingSteps.add(step);
      });
    }
  }

  Future<void> _predictFromCSV() async {
    if (_csvContent == null) {
      _showErrorDialog('No File Selected', 'Please select a CSV file first');
      return;
    }

    final host = context.read<ModelHost>();
    if (!host.ready) {
      _showErrorDialog('Model Not Ready', 'Please initialize the model first in Diagnostics tab');
      return;
    }

    setState(() {
      _isProcessing = true;
      _processingSteps.clear();
      _lastResult = null;
      _showProcessingSteps = true;
    });

    try {
      _addProcessingStep('🔄 Starting EEG Data Processing...', _infoColor);
      await Future.delayed(const Duration(milliseconds: 500));

      _addProcessingStep('🔍 Parsing CSV structure...', _infoColor);
      await Future.delayed(const Duration(milliseconds: 300));

      _addProcessingStep('📊 Extracting 5 statistical features...', _infoColor);
      await Future.delayed(const Duration(milliseconds: 400));

      _addProcessingStep('⚙️ Normalizing feature values...', _infoColor);
      await Future.delayed(const Duration(milliseconds: 300));

      _addProcessingStep('🧠 Feeding to neural network...', _infoColor);
      await Future.delayed(const Duration(milliseconds: 600));

      final result = await host.predictFromCSV(_csvContent!);
      _lastResult = host.lastPredictionResult;

      // Save to Firebase
      if (_lastResult?.topLabel != null) {
        await _firebaseService.savePrediction(
          emotion: _lastResult!.topLabel!,
          confidence: _lastResult!.topProb,
          csvFileName: _selectedFileName,
          method: 'csv',
          result: _lastResult,
        );

        // Refresh predictions
        _loadPredictions();
      }

      _addProcessingStep('✅ Prediction completed!', _successColor);
      _addProcessingStep('🎯 Result: ${result.topLabel} (${(result.topProb * 100).toStringAsFixed(1)}% confidence)',
          _successColor);

    } catch (e) {
      _addProcessingStep('❌ Error: ${e.toString()}', _errorColor);
      _showErrorDialog('Prediction Failed', 'Failed to process EEG data: ${e.toString()}');
    } finally {
      if (mounted) {
        setState(() => _isProcessing = false);
      }
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => _ProfessionalDialog(
        title: title,
        message: message,
        type: _DialogType.error,
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(color: Colors.white),
        ),
        backgroundColor: _successColor,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  void _clearSelection() {
    setState(() {
      _selectedFileName = null;
      _csvContent = null;
      _lastResult = null;
      _processingSteps.clear();
      _showFileOptions = false;
    });
    context.read<ModelHost>().clearLastPrediction();
  }

  void _useSampleData() {
    const sampleCSV = '''mean_0_a,mean_1_a,mean_2_a,mean_3_a,mean_4_a,label
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

    setState(() {
      _selectedFileName = 'sample_eeg_emotions.csv';
      _csvContent = sampleCSV;
      _lastResult = null;
      _processingSteps.clear();
      _showFileOptions = false;
    });

    _addProcessingStep('📁 Sample Data Loaded', _infoColor);
    _addProcessingStep('✅ All required features present', _successColor);
    _showSuccessSnackbar('Sample EEG emotion data loaded! Ready for prediction.');
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.7) return _successColor;
    if (confidence > 0.5) return _warningColor;
    return _errorColor;
  }

  String _getEmoji(String emotion) {
    switch (emotion.toLowerCase()) {
      case 'positive': return '😊';
      case 'negative': return '😢';
      case 'neutral': return '😐';
      case 'relaxed': return '😌';
      case 'excited': return '🤩';
      case 'happy': return '😄';
      case 'sad': return '😔';
      case 'angry': return '😠';
      case 'fearful': return '😨';
      case 'surprised': return '😲';
      case 'disgusted': return '🤢';
      case 'focused': return '🧠';
      default: return '🎭';
    }
  }

  Widget _buildBluetoothDeviceList() {
    final devices = _neuroskyService.devices;

    if (devices.isEmpty && !_neuroskyService.isScanning) {
      return _EmptyStateCard(
        icon: Icons.bluetooth_disabled,
        title: 'No Neurosky Devices Found',
        description: 'Start scanning to discover nearby Neurosky Mindwave headsets',
        color: _textSecondary,
        cardColor: _cardColor,
      );
    }

    return Column(
      children: [
        if (_neuroskyService.isScanning)
          _ScanningIndicator(color: _connectHeadsetBackgroundColor, cardColor: _cardColor),
        ...devices.map((device) => _BluetoothDeviceCard(
          device: device,
          isConnecting: _neuroskyService.isConnecting &&
              _neuroskyService.connectedDevice?.remoteId == device.remoteId,
          isConnected: _neuroskyService.connectedDevice?.remoteId == device.remoteId,
          onConnect: () => _connectToDevice(device),
          primaryColor: _connectHeadsetBackgroundColor,
          cardColor: _cardColor,
        )),
      ],
    );
  }

  Widget _buildActivityCalendar() {
    return Card(
      elevation: 0,
      color: _cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: _borderColor, width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with History Screen button
            Row(
              children: [
                Icon(Icons.calendar_today, color: _connectHeadsetBackgroundColor, size: 20),
                const SizedBox(width: 8),
                Text(
                  _isSameDay(_selectedDay, DateTime.now())
                      ? 'Predictions for Today'
                      : 'Predictions for ${_formatDate(_selectedDay)}',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _textPrimary,
                  ),
                ),
                const Spacer(),
                // History button
                IconButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => PredictionHistoryScreen(
                          firebaseService: _firebaseService,
                        ),
                      ),
                    );
                  },
                  icon: Icon(Icons.history, color: _connectHeadsetBackgroundColor),
                  tooltip: 'View Full History',
                ),
                // Refresh button
                if (_isLoadingPredictions)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: _connectHeadsetBackgroundColor,
                      ),
                    ),
                  )
                else
                  IconButton(
                    onPressed: _loadPredictions,
                    icon: Icon(Icons.refresh, color: _connectHeadsetBackgroundColor),
                    tooltip: 'Refresh Predictions',
                  ),
              ],
            ),
            const SizedBox(height: 16),

            // Navigation and Month
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => _changeMonth(-1),
                  icon: Icon(Icons.chevron_left, color: _connectHeadsetBackgroundColor, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: _backgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: _borderColor),
                    ),
                  ),
                ),
                Text(
                  _getCurrentMonthYear(),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 14,
                    color: _textPrimary,
                  ),
                ),
                IconButton(
                  onPressed: () => _changeMonth(1),
                  icon: Icon(Icons.chevron_right, color: _connectHeadsetBackgroundColor, size: 20),
                  style: IconButton.styleFrom(
                    backgroundColor: _backgroundColor,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: _borderColor),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Weekday headers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                  .map((day) => SizedBox(
                width: 32,
                child: Text(
                  day,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: _textSecondary,
                  ),
                ),
              ))
                  .toList(),
            ),
            const SizedBox(height: 8),

            // Calendar dates for current month
            _buildCalendarGrid(),
            const SizedBox(height: 16),

            // Selected day predictions
            _buildSelectedDayHistory(),
          ],
        ),
      ),
    );
  }

  void _changeMonth(int delta) {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + delta);
    });
  }

  Widget _buildCalendarGrid() {
    final firstDay = DateTime(_currentMonth.year, _currentMonth.month, 1);
    final lastDay = DateTime(_currentMonth.year, _currentMonth.month + 1, 0);
    final startingWeekday = firstDay.weekday % 7; // Sunday = 0

    final totalDays = lastDay.day;
    final totalCells = ((totalDays + startingWeekday) / 7).ceil() * 7;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 7,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
      ),
      itemCount: totalCells,
      itemBuilder: (context, index) {
        if (index < startingWeekday || index >= startingWeekday + totalDays) {
          return const SizedBox.shrink();
        }

        final day = index - startingWeekday + 1;
        final currentDate = DateTime(_currentMonth.year, _currentMonth.month, day);
        final hasHistory = _datesWithPredictions.any((date) => _isSameDay(date, currentDate));
        final isToday = _isSameDay(currentDate, DateTime.now());
        final isSelected = _isSameDay(currentDate, _selectedDay);

        return GestureDetector(
          onTap: () {
            _onDateSelected(currentDate);
          },
          child: Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: isToday
                  ? _connectHeadsetBackgroundColor.withOpacity(0.1)
                  : isSelected
                  ? _connectHeadsetBackgroundColor
                  : Colors.transparent,
              shape: BoxShape.circle,
              border: hasHistory
                  ? Border.all(color: _connectHeadsetBackgroundColor, width: 2)
                  : null,
            ),
            child: Center(
              child: Text(
                day.toString(),
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isSelected
                      ? Colors.white
                      : isToday
                      ? _connectHeadsetBackgroundColor
                      : _textPrimary,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onDateSelected(DateTime date) async {
    setState(() {
      _selectedDay = date;
      _isLoadingPredictions = true;
    });

    try {
      final firebaseData = await _firebaseService.getPredictionsForDate(date);
      final predictions = firebaseData.map((data) => PredictionRecord.fromMap({
        'id': data['id'] ?? '',
        'dateTime': data['date'].toString(),
        'emotion': data['emotion'] ?? 'Unknown',
        'confidence': data['confidence'] ?? 0.0,
        'method': data['method'] ?? 'unknown',
        'csvFileName': data['csvFileName'],
      })).toList();

      if (mounted) {
        setState(() {
          _predictionsForSelectedDay = predictions;
          _isLoadingPredictions = false;
        });
      }
    } catch (e) {
      print('Error loading predictions for date: $e');
      if (mounted) {
        setState(() {
          _isLoadingPredictions = false;
        });
      }
    }
  }

  Widget _buildSelectedDayHistory() {
    if (_isLoadingPredictions) {
      return Container(
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          children: [
            SizedBox(
              width: 30,
              height: 30,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: _connectHeadsetBackgroundColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading predictions...',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
              ),
            ),
          ],
        ),
      );
    }

    if (_predictionsForSelectedDay.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: _backgroundColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: _borderColor),
        ),
        child: Column(
          children: [
            Icon(Icons.history_rounded, color: _textSecondary, size: 40),
            const SizedBox(height: 8),
            Text(
              _isSameDay(_selectedDay, DateTime.now())
                  ? 'No predictions for today yet.\nStart a session to log your emotions!'
                  : 'No prediction history found for ${_formatDate(_selectedDay)}',
              style: TextStyle(
                color: _textSecondary,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: _borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                '${_predictionsForSelectedDay.length} prediction${_predictionsForSelectedDay.length > 1 ? 's' : ''}',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _textPrimary,
                  fontSize: 14,
                ),
              ),
              const Spacer(),
              Text(
                '${_formatDate(_selectedDay)}',
                style: TextStyle(
                  color: _textSecondary,
                  fontSize: 12,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ..._predictionsForSelectedDay.map((prediction) => _buildPredictionItem(prediction)),
        ],
      ),
    );
  }

  Widget _buildPredictionItem(PredictionRecord prediction) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: _borderColor),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: _connectHeadsetBackgroundColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              _getEmoji(prediction.emotion),
              style: const TextStyle(fontSize: 16),
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
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: _textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${(prediction.confidence * 100).toStringAsFixed(1)}% confidence',
                  style: TextStyle(
                    fontSize: 11,
                    color: _textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(
                      prediction.method == 'realtime' ? Icons.bluetooth : Icons.upload_file,
                      size: 10,
                      color: _textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      prediction.method == 'realtime' ? 'Live EEG' : 'CSV File',
                      style: TextStyle(
                        fontSize: 10,
                        color: _textSecondary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      width: 3,
                      height: 3,
                      decoration: BoxDecoration(
                        color: _textSecondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(prediction.dateTime),
                      style: TextStyle(
                        fontSize: 10,
                        color: _textSecondary,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = DateTime(now.year, now.month, now.day - 1);

    if (_isSameDay(date, today)) return 'Today';
    if (_isSameDay(date, yesterday)) return 'Yesterday';

    return '${date.day} ${_getMonthName(date.month)} ${date.year}';
  }

  String _formatTime(DateTime dateTime) {
    final hour = dateTime.hour % 12;
    final minute = dateTime.minute.toString().padLeft(2, '0');
    final amPm = dateTime.hour < 12 ? 'AM' : 'PM';
    return '${hour == 0 ? 12 : hour}:$minute $amPm';
  }

  String _getMonthName(int month) {
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return months[month - 1];
  }

  String _getCurrentMonthYear() {
    final months = ['January', 'February', 'March', 'April', 'May', 'June',
      'July', 'August', 'September', 'October', 'November', 'December'
    ];
    return '${months[_currentMonth.month - 1]} ${_currentMonth.year}';
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  Widget _buildResultsSection() {
    if (_lastResult == null) return const SizedBox();

    return FadeTransition(
      opacity: _fadeAnimation,
      child: Card(
        elevation: 0,
        color: _cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: _borderColor, width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.emoji_emotions, color: _connectHeadsetBackgroundColor, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    'Latest Detection Results',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: _textPrimary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildResultContent(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultContent() {
    final topLabel = _lastResult!.topLabel ?? "UNKNOWN";
    final topProb = _lastResult!.topProb;

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _backgroundColor,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: _borderColor),
          ),
          child: Column(
            children: [
              Text(
                'Detected Emotion',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: _textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _getEmoji(topLabel),
                style: const TextStyle(fontSize: 36),
              ),
              const SizedBox(height: 8),
              Text(
                topLabel.toUpperCase(),
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: _connectHeadsetBackgroundColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${(topProb * 100).toStringAsFixed(1)}% Confidence',
                style: TextStyle(
                  fontSize: 14,
                  color: _textSecondary,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    _scanningSubscription?.cancel();
    _connectingSubscription?.cancel();
    _connectedSubscription?.cancel();
    _neuroskyDataSubscription?.cancel();
    _statusSubscription?.cancel();
    _realtimePredictionTimer?.cancel();
    _neuroskyService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final host = context.watch<ModelHost>();

    return Scaffold(
      backgroundColor: _backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Main Action Cards
                Row(
                  children: [
                    Expanded(
                      child: _MainActionCard(
                        title: 'Browse CSV',
                        subtitle: 'Upload emotion data',
                        icon: Icons.upload_file,
                        backgroundColor: _browseCsvBackgroundColor,
                        textColor: Colors.white,
                        iconColor: Colors.white,
                        cardColor: _browseCsvBackgroundColor,
                        onTap: () {
                          setState(() {
                            _showFileOptions = !_showFileOptions;
                          });
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _MainActionCard(
                        title: 'Connect Headset',
                        subtitle: 'Live EEG detection',
                        icon: Icons.bluetooth,
                        backgroundColor: _connectHeadsetBackgroundColor,
                        textColor: Colors.white,
                        iconColor: Colors.white,
                        cardColor: _connectHeadsetBackgroundColor,
                        onTap: () {
                          if (_neuroskyService.connectedDevice == null) {
                            _startBluetoothScan();
                          } else {
                            _showDeviceConnectionScreen();
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // File Options
                if (_showFileOptions) ...[
                  _FileOptionsCard(
                    onBrowseCSV: _pickCSVFile,
                    onUseSample: _useSampleData,
                    primaryColor: _browseCsvBackgroundColor,
                    cardColor: _cardColor,
                  ),
                  const SizedBox(height: 16),
                ],

                // File Status
                if (_selectedFileName != null) ...[
                  _FileStatusCard(
                    fileName: _selectedFileName,
                    isLoading: _isLoadingFile,
                    onClear: _clearSelection,
                    accentColor: _browseCsvBackgroundColor,
                    successColor: _successColor,
                    cardColor: _cardColor,
                  ),
                  const SizedBox(height: 16),
                ],

                // Start Detection Section with Gradient Background
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        _startDetectionGradientStart,
                        _startDetectionGradientEnd,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 10,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(
                          'Start Detection',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Analyze your emotions now',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: ElevatedButton(
                            onPressed: host.ready && _csvContent != null && !_isProcessing && !_isLoadingFile
                                ? _predictFromCSV
                                : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: _beginSessionBackgroundColor,
                              foregroundColor: _startDetectionGradientStart,
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: Text(
                              _isProcessing ? 'Analyzing...' : 'Begin Session',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _startDetectionGradientStart,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // Activity Calendar with Predictions
                _buildActivityCalendar(),
                const SizedBox(height: 16),

                // Results Section
                if (_lastResult != null) ...[
                  _buildResultsSection(),
                  const SizedBox(height: 16),
                ],

                // Bluetooth Devices Section
                if (_neuroskyService.isScanning || _neuroskyService.devices.isNotEmpty) ...[
                  _BluetoothSectionCard(
                    title: 'Available Devices',
                    isScanning: _neuroskyService.isScanning,
                    connectedDevice: _neuroskyService.connectedDevice,
                    onStopScan: _stopBluetoothScan,
                    onDisconnect: _disconnectDevice,
                    primaryColor: _connectHeadsetBackgroundColor,
                    cardColor: _cardColor,
                    child: _buildBluetoothDeviceList(),
                  ),
                  const SizedBox(height: 16),
                ],

                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),

      floatingActionButton: _processingSteps.isNotEmpty
          ? FloatingActionButton(
        onPressed: () {
          setState(() {
            _showProcessingSteps = !_showProcessingSteps;
          });
        },
        backgroundColor: _connectHeadsetBackgroundColor,
        child: const Icon(Icons.list, color: Colors.white),
      )
          : null,

      bottomSheet: _showProcessingSteps
          ? _ProcessingStepsBottomSheet(
        steps: _processingSteps,
        onClose: () {
          setState(() {
            _showProcessingSteps = false;
          });
        },
        cardColor: _cardColor,
      )
          : null,
    );
  }

  void _showDeviceConnectionScreen() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _DeviceConnectionScreen(
        neuroskyService: _neuroskyService,
        onStartScan: _startBluetoothScan,
        onStopScan: _stopBluetoothScan,
        onConnect: _connectToDevice,
        onDisconnect: _disconnectDevice,
        primaryColor: _connectHeadsetBackgroundColor,
        cardColor: _cardColor,
        backgroundColor: _backgroundColor,
      ),
    );
  }
}

// ============ WIDGET CLASSES (Keep all the existing widget classes) ============

class _MainActionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;
  final Color iconColor;
  final Color cardColor;
  final VoidCallback onTap;

  const _MainActionCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
    required this.iconColor,
    required this.cardColor,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: backgroundColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: backgroundColor.withOpacity(0.3), width: 1),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: textColor.withOpacity(0.8),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FileOptionsCard extends StatelessWidget {
  final VoidCallback onBrowseCSV;
  final VoidCallback onUseSample;
  final Color primaryColor;
  final Color cardColor;

  const _FileOptionsCard({
    required this.onBrowseCSV,
    required this.onUseSample,
    required this.primaryColor,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
        elevation: 0,
        color: cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text(
                'Select Data Source',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: primaryColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _OptionButton(
                      text: 'Browse CSV',
                      icon: Icons.upload_file,
                      onPressed: onBrowseCSV,
                      backgroundColor: primaryColor,
                      textColor: Colors.white,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _OptionButton(
                      text: 'Use Sample',
                      icon: Icons.psychology,
                      onPressed: onUseSample,
                      backgroundColor: primaryColor,
                      textColor: Colors.white,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final VoidCallback onPressed;
  final Color backgroundColor;
  final Color textColor;

  const _OptionButton({
    required this.text,
    required this.icon,
    required this.onPressed,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: textColor, size: 18),
      label: Text(
        text,
        style: TextStyle(color: textColor),
      ),
      style: ElevatedButton.styleFrom(
        backgroundColor: backgroundColor,
        foregroundColor: textColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        padding: const EdgeInsets.symmetric(vertical: 12),
      ),
    );
  }
}

class _FileStatusCard extends StatelessWidget {
  final String? fileName;
  final bool isLoading;
  final VoidCallback onClear;
  final Color accentColor;
  final Color successColor;
  final Color cardColor;

  const _FileStatusCard({
    required this.fileName,
    required this.isLoading,
    required this.onClear,
    required this.accentColor,
    required this.successColor,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            if (isLoading)
              SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2, color: accentColor),
              )
            else if (fileName != null)
              Icon(Icons.check_circle, color: successColor, size: 20)
            else
              Icon(Icons.description, color: Colors.grey, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    fileName ?? 'No file selected',
                    style: TextStyle(
                      color: fileName != null ? successColor : Colors.grey,
                      fontWeight: FontWeight.w500,
                      fontSize: 15,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (fileName != null && !isLoading) ...[
                    const SizedBox(height: 2),
                    Text(
                      'Ready for processing',
                      style: TextStyle(
                        color: successColor,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (fileName != null && !isLoading)
              IconButton(
                onPressed: onClear,
                icon: const Icon(Icons.clear, color: Colors.red, size: 18),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProcessingStepsBottomSheet extends StatelessWidget {
  final List<String> steps;
  final VoidCallback onClose;
  final Color cardColor;

  const _ProcessingStepsBottomSheet({
    required this.steps,
    required this.onClose,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 400,
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.list_alt, color: Color(0xFF2196F3)),
                const SizedBox(width: 12),
                const Text(
                  'Processing Steps',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: onClose,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: steps.length,
              itemBuilder: (context, index) => _ProcessingStepItem(
                step: steps[index],
                index: index + 1,
                cardColor: cardColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProcessingStepItem extends StatelessWidget {
  final String step;
  final int index;
  final Color cardColor;

  const _ProcessingStepItem({
    required this.step,
    required this.index,
    required this.cardColor,
  });

  Color _getStepColor(String step) {
    if (step.contains('❌')) return const Color(0xFFF44336);
    if (step.contains('✅')) return const Color(0xFF4CAF50);
    if (step.contains('⚠️')) return const Color(0xFFFF9800);
    return const Color(0xFF2196F3);
  }

  IconData _getStepIcon(String step) {
    if (step.contains('❌')) return Icons.error;
    if (step.contains('✅')) return Icons.check_circle;
    if (step.contains('⚠️')) return Icons.warning;
    return Icons.info;
  }

  @override
  Widget build(BuildContext context) {
    final color = _getStepColor(step);
    final icon = _getStepIcon(step);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              step,
              style: TextStyle(
                fontSize: 14,
                color: Colors.black87,
                fontWeight: step.contains('❌') || step.contains('✅') ? FontWeight.w500 : FontWeight.normal,
                height: 1.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DeviceConnectionScreen extends StatefulWidget {
  final NeuroskyBluetoothService neuroskyService;
  final VoidCallback onStartScan;
  final VoidCallback onStopScan;
  final Function(BluetoothDevice) onConnect;
  final VoidCallback onDisconnect;
  final Color primaryColor;
  final Color cardColor;
  final Color backgroundColor;

  const _DeviceConnectionScreen({
    required this.neuroskyService,
    required this.onStartScan,
    required this.onStopScan,
    required this.onConnect,
    required this.onDisconnect,
    required this.primaryColor,
    required this.cardColor,
    required this.backgroundColor,
  });

  @override
  State<_DeviceConnectionScreen> createState() => _DeviceConnectionScreenState();
}

class _DeviceConnectionScreenState extends State<_DeviceConnectionScreen> {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.8,
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Icon(Icons.bluetooth, color: Color(0xFF2196F3)),
                const SizedBox(width: 12),
                const Text(
                  'Connect Headset',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
          ),
          Expanded(
            child: _BluetoothSectionCard(
              title: 'Neurosky Mindwave Headsets',
              isScanning: widget.neuroskyService.isScanning,
              connectedDevice: widget.neuroskyService.connectedDevice,
              onStopScan: widget.onStopScan,
              onDisconnect: widget.onDisconnect,
              primaryColor: widget.primaryColor,
              cardColor: widget.cardColor,
              child: _buildBluetoothDeviceList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBluetoothDeviceList() {
    final devices = widget.neuroskyService.devices;

    if (devices.isEmpty && !widget.neuroskyService.isScanning) {
      return _EmptyStateCard(
        icon: Icons.bluetooth_disabled,
        title: 'No Neurosky Devices Found',
        description: 'Start scanning to discover nearby Neurosky Mindwave headsets',
        color: Colors.grey,
        cardColor: widget.cardColor,
      );
    }

    return Column(
      children: [
        if (widget.neuroskyService.isScanning)
          _ScanningIndicator(color: widget.primaryColor, cardColor: widget.cardColor),
        ...devices.map((device) => _BluetoothDeviceCard(
          device: device,
          isConnecting: widget.neuroskyService.isConnecting &&
              widget.neuroskyService.connectedDevice?.remoteId == device.remoteId,
          isConnected: widget.neuroskyService.connectedDevice?.remoteId == device.remoteId,
          onConnect: () => widget.onConnect(device),
          primaryColor: widget.primaryColor,
          cardColor: widget.cardColor,
        )),
      ],
    );
  }
}

class _BluetoothSectionCard extends StatelessWidget {
  final String title;
  final bool isScanning;
  final BluetoothDevice? connectedDevice;
  final VoidCallback onStopScan;
  final VoidCallback onDisconnect;
  final Color primaryColor;
  final Color cardColor;
  final Widget child;

  const _BluetoothSectionCard({
    required this.title,
    required this.isScanning,
    required this.connectedDevice,
    required this.onStopScan,
    required this.onDisconnect,
    required this.primaryColor,
    required this.cardColor,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.bluetooth, color: primaryColor, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                if (isScanning)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: TextButton(
                      onPressed: onStopScan,
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.red,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text(
                        'Stop Scan',
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            child,
            if (connectedDevice != null) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: primaryColor),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle, color: primaryColor, size: 24),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Connected to ${connectedDevice!.platformName}',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              color: primaryColor,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Ready for real-time EEG data',
                            style: TextStyle(
                              color: primaryColor,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton(
                      onPressed: onDisconnect,
                      icon: const Icon(Icons.close, color: Colors.red, size: 20),
                      padding: const EdgeInsets.all(4),
                      constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ScanningIndicator extends StatelessWidget {
  final Color color;
  final Color cardColor;

  const _ScanningIndicator({required this.color, required this.cardColor});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: color),
            ),
            const SizedBox(width: 12),
            Text('Scanning for devices...', style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }
}

class _BluetoothDeviceCard extends StatelessWidget {
  final BluetoothDevice device;
  final bool isConnecting;
  final bool isConnected;
  final VoidCallback onConnect;
  final Color primaryColor;
  final Color cardColor;

  const _BluetoothDeviceCard({
    required this.device,
    required this.isConnecting,
    required this.isConnected,
    required this.onConnect,
    required this.primaryColor,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 6),
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(Icons.psychology, color: primaryColor, size: 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    device.platformName.isEmpty ? 'Neurosky Device' : device.platformName,
                    style: const TextStyle(fontWeight: FontWeight.w500),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'ID: ${device.remoteId.toString().substring(0, 8)}...',
                    style: const TextStyle(fontSize: 12, color: Colors.grey),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            isConnecting
                ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2, color: primaryColor),
            )
                : isConnected
                ? const Icon(Icons.check_circle, color: Colors.green, size: 24)
                : OutlinedButton(
              onPressed: onConnect,
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryColor,
                side: BorderSide(color: primaryColor),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                minimumSize: const Size(0, 0),
              ),
              child: const Text('Connect'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyStateCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final Color color;
  final Color cardColor;

  const _EmptyStateCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
    required this.cardColor,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: cardColor,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: Color(0xFFE0E0E0), width: 1),
      ),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          children: [
            Icon(icon, size: 48, color: color),
            const SizedBox(height: 16),
            Text(
              title,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              description,
              style: const TextStyle(color: Colors.grey, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ProfessionalDialog extends StatelessWidget {
  final String title;
  final String message;
  final _DialogType type;

  const _ProfessionalDialog({
    required this.title,
    required this.message,
    required this.type,
  });

  Color _getColor(_DialogType type) {
    switch (type) {
      case _DialogType.error:
        return const Color(0xFFF44336);
      case _DialogType.success:
        return const Color(0xFF4CAF50);
      case _DialogType.warning:
        return const Color(0xFFFF9800);
      case _DialogType.info:
        return const Color(0xFF2196F3);
    }
  }

  IconData _getIcon(_DialogType type) {
    switch (type) {
      case _DialogType.error:
        return Icons.error_outline;
      case _DialogType.success:
        return Icons.check_circle_outline;
      case _DialogType.warning:
        return Icons.warning_amber_outlined;
      case _DialogType.info:
        return Icons.info_outline;
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = _getColor(type);
    final icon = _getIcon(type);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      elevation: 0,
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 32),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: color,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: Colors.black54,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'OK',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

enum _DialogType { error, success, warning, info }