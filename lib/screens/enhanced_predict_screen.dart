// enhanced_predict_screen.dart
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../model_host.dart';
import '../services/enhanced_bluetooth_service.dart';
import '../models/prediction_result.dart';

class EnhancedPredictScreen extends StatefulWidget {
  const EnhancedPredictScreen({super.key});

  @override
  State<EnhancedPredictScreen> createState() => _EnhancedPredictScreenState();
}

class _EnhancedPredictScreenState extends State<EnhancedPredictScreen> {
  final EEGRealTimeBluetoothService _bluetoothService = EEGRealTimeBluetoothService();

  // UI state variables
  bool _isProcessingRealtime = false;
  List<List<double>> _realtimeDataBuffer = [];
  List<Map<String, dynamic>> _connectionLogs = [];
  Timer? _predictionTimer;

  // Real-time prediction state
  PredictionResult? _realtimeResult;
  List<double> _lastEEGData = [];
  int _samplesCollected = 0;

  // Color Scheme
  final Color _primaryColor = const Color(0xFF556B2F);
  final Color _accentColor = const Color(0xFF6B8E23);
  final Color _lightOlive = const Color(0xFF8FBC8F);
  final Color _backgroundColor = const Color(0xFFF8F9F7);
  final Color _cardColor = Colors.white;
  final Color _textColor = const Color(0xFF2F3E1F);
  final Color _realtimeColor = const Color(0xFF2196F3);

  @override
  void initState() {
    super.initState();
    _initializeBluetooth();
  }

  void _initializeBluetooth() {
    _bluetoothService.initialize();

    // Listen for EEG data stream
    _bluetoothService.eegDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _lastEEGData = data;
          _realtimeDataBuffer.add(List.from(data));
          _samplesCollected++;
        });
      }
    });

    // Listen for status updates
    _bluetoothService.statusStream.listen((status) {
      _addConnectionLog(status);
    });
  }

  // Start real-time prediction
  void _startRealtimePrediction() {
    if (!_bluetoothService.isStreaming) return;

    setState(() {
      _isProcessingRealtime = true;
      _realtimeDataBuffer.clear();
      _samplesCollected = 0;
    });

    // Start periodic predictions
    _predictionTimer = Timer.periodic(Duration(milliseconds: 500), (timer) {
      if (_realtimeDataBuffer.length >= 10) { // Buffer of 10 samples
        _processRealtimeData();
      }
    });

    _addConnectionLog('🎯 Real-time emotion detection started');
  }

  // Stop real-time prediction
  void _stopRealtimePrediction() {
    _predictionTimer?.cancel();
    _predictionTimer = null;

    setState(() {
      _isProcessingRealtime = false;
      _realtimeDataBuffer.clear();
      _samplesCollected = 0;
    });

    _addConnectionLog('⏹️ Real-time emotion detection stopped');
  }

  // Process real-time EEG data
  Future<void> _processRealtimeData() async {
    if (_realtimeDataBuffer.isEmpty) return;

    final host = context.read<ModelHost>();
    if (!host.ready) return;

    try {
      // Convert buffer to CSV format
      final csvData = _convertBufferToCSV(_realtimeDataBuffer);

      // Make prediction
      final result = await host.predictFromCSV(csvData);

      setState(() {
        _realtimeResult = host.lastPredictionResult;
      });

      // Keep only recent data in buffer
      if (_realtimeDataBuffer.length > 20) {
        _realtimeDataBuffer = _realtimeDataBuffer.sublist(_realtimeDataBuffer.length - 10);
      }

    } catch (e) {
      _addConnectionLog('❌ Prediction error: $e');
    }
  }

  String _convertBufferToCSV(List<List<double>> buffer) {
    final header = 'mean_0_a,mean_1_a,mean_2_a,mean_3_a,mean_4_a\n';
    final rows = buffer.map((sample) {
      if (sample.length >= 5) {
        return '${sample[0]},${sample[1]},${sample[2]},${sample[3]},${sample[4]}';
      }
      return '0.0,0.0,0.0,0.0,0.0';
    }).join('\n');

    return header + rows;
  }

  void _addConnectionLog(String message) {
    setState(() {
      _connectionLogs.insert(0, {
        'timestamp': DateTime.now(),
        'message': message,
        'type': _getLogType(message),
      });

      // Keep only last 50 logs
      if (_connectionLogs.length > 50) {
        _connectionLogs = _connectionLogs.sublist(0, 50);
      }
    });
  }

  String _getLogType(String message) {
    if (message.contains('✅') || message.contains('🎯')) return 'success';
    if (message.contains('❌') || message.contains('⚠️')) return 'error';
    if (message.contains('🔗') || message.contains('📴')) return 'connection';
    return 'info';
  }

  Color _getLogColor(String type) {
    switch (type) {
      case 'success': return Colors.green;
      case 'error': return Colors.red;
      case 'connection': return _realtimeColor;
      default: return _textColor;
    }
  }

  Widget _buildRealtimeConnectionPanel() {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(Icons.bluetooth_connected, color: _realtimeColor, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Real-time EEG Connection',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: _realtimeColor,
                        ),
                      ),
                      Text(
                        'Connect to EEG headset for live emotion detection',
                        style: TextStyle(color: _textColor.withOpacity(0.7)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Connection Status
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: _bluetoothService.connectedDevice != null
                    ? Colors.green.withOpacity(0.1)
                    : Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _bluetoothService.connectedDevice != null
                      ? Colors.green
                      : Colors.orange,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _bluetoothService.connectedDevice != null
                        ? Icons.check_circle
                        : Icons.bluetooth_disabled,
                    color: _bluetoothService.connectedDevice != null
                        ? Colors.green
                        : Colors.orange,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _bluetoothService.connectedDevice != null
                              ? 'Connected to ${_bluetoothService.connectedDevice!.platformName}'
                              : 'No device connected',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: _bluetoothService.connectedDevice != null
                                ? Colors.green
                                : Colors.orange,
                          ),
                        ),
                        if (_bluetoothService.connectedDevice != null)
                          Text(
                            _bluetoothService.isStreaming
                                ? 'Streaming EEG data...'
                                : 'Ready to stream',
                            style: TextStyle(
                              color: _textColor.withOpacity(0.7),
                              fontSize: 12,
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Control Buttons
            Row(
              children: [
                // Scan Button
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      boxShadow: [
                        BoxShadow(
                          color: _realtimeColor.withOpacity(0.3),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _bluetoothService.isScanning
                          ? _bluetoothService.stopScan
                          : () => _bluetoothService.startScan(timeoutSeconds: 15),
                      icon: Icon(
                        _bluetoothService.isScanning
                            ? Icons.bluetooth_searching
                            : Icons.bluetooth,
                        color: Colors.white,
                      ),
                      label: Text(
                        _bluetoothService.isScanning ? 'Scanning...' : 'Scan Devices',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _realtimeColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),

                // Stream Control
                if (_bluetoothService.connectedDevice != null)
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _bluetoothService.isStreaming
                                ? Colors.red.withOpacity(0.3)
                                : Colors.green.withOpacity(0.3),
                            blurRadius: 10,
                            spreadRadius: 2,
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: _bluetoothService.isStreaming
                            ? _bluetoothService.stopEEGStreaming
                            : _bluetoothService.startEEGStreaming,
                        icon: Icon(
                          _bluetoothService.isStreaming
                              ? Icons.stop
                              : Icons.play_arrow,
                          color: Colors.white,
                        ),
                        label: Text(
                          _bluetoothService.isStreaming ? 'Stop Stream' : 'Start Stream',
                          style: const TextStyle(color: Colors.white),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _bluetoothService.isStreaming
                              ? Colors.red
                              : Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            // Real-time Prediction Control
            if (_bluetoothService.isStreaming) ...[
              const SizedBox(height: 16),
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: _isProcessingRealtime
                          ? Colors.orange.withOpacity(0.3)
                          : _accentColor.withOpacity(0.3),
                      blurRadius: 10,
                      spreadRadius: 2,
                    ),
                  ],
                ),
                child: SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton.icon(
                    onPressed: _isProcessingRealtime
                        ? _stopRealtimePrediction
                        : _startRealtimePrediction,
                    icon: _isProcessingRealtime
                        ? const Icon(Icons.stop, color: Colors.white)
                        : const Icon(Icons.psychology, color: Colors.white),
                    label: Text(
                      _isProcessingRealtime
                          ? 'Stop Detection'
                          : 'Start Emotion Detection',
                      style: const TextStyle(color: Colors.white, fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isProcessingRealtime
                          ? Colors.orange
                          : _accentColor,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDeviceList() {
    if (_bluetoothService.devices.isEmpty && !_bluetoothService.isScanning) {
      return Container();
    }

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.devices, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Available EEG Headsets',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                if (_bluetoothService.isScanning)
                  SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2, color: _realtimeColor),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            ..._bluetoothService.devices.map((device) => Card(
              margin: const EdgeInsets.symmetric(vertical: 4),
              child: ListTile(
                leading: const Icon(Icons.psychology, color: Colors.blue),
                title: Text(
                  device.platformName.isEmpty ? 'Unknown EEG Device' : device.platformName,
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                subtitle: Text('ID: ${device.remoteId.toString().substring(0, 8)}...'),
                trailing: _bluetoothService.isConnecting &&
                    _bluetoothService.connectedDevice?.remoteId == device.remoteId
                    ? SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2, color: _realtimeColor),
                )
                    : _bluetoothService.connectedDevice?.remoteId == device.remoteId
                    ? Wrap(
                  spacing: 8,
                  children: [
                    const Icon(Icons.check_circle, color: Colors.green),
                    if (_bluetoothService.isStreaming)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'LIVE',
                          style: TextStyle(color: Colors.white, fontSize: 10),
                        ),
                      ),
                  ],
                )
                    : ElevatedButton(
                  onPressed: () => _bluetoothService.connectToDevice(device),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _realtimeColor,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Connect'),
                ),
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeDataPanel() {
    return StreamBuilder<List<double>>(
      stream: _bluetoothService.eegDataStream,
      builder: (context, snapshot) {
        final eegData = snapshot.data ?? _lastEEGData;

        return Card(
          elevation: 2,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.show_chart, color: _realtimeColor, size: 24),
                    const SizedBox(width: 8),
                    const Text(
                      'Real-time EEG Data',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    const Spacer(),
                    if (_bluetoothService.isStreaming)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.circle, color: Colors.white, size: 8),
                            SizedBox(width: 4),
                            Text(
                              'LIVE',
                              style: TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),

                // EEG Data Visualization
                if (eegData.isNotEmpty) ...[
                  Container(
                    height: 120,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _lightOlive.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: eegData.asMap().entries.map((entry) {
                        final index = entry.key;
                        final value = entry.value;
                        return Expanded(
                          child: Column(
                            children: [
                              Expanded(
                                child: Container(
                                  width: 20,
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  decoration: BoxDecoration(
                                    color: _realtimeColor.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                  child: Align(
                                    alignment: Alignment.bottomCenter,
                                    child: Container(
                                      width: 16,
                                      height: (value.abs() * 3).clamp(10, 100).toDouble(),
                                      decoration: BoxDecoration(
                                        color: _realtimeColor,
                                        borderRadius: BorderRadius.circular(2),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Ch${index + 1}',
                                style: const TextStyle(fontSize: 10),
                              ),
                              Text(
                                value.toStringAsFixed(1),
                                style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold),
                              ),
                            ],
                          ),
                        );
                      }).toList(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Buffer: ${_realtimeDataBuffer.length} samples | Collected: $_samplesCollected',
                    style: TextStyle(fontSize: 12, color: _textColor.withOpacity(0.7)),
                  ),
                ] else ...[
                  Container(
                    height: 100,
                    decoration: BoxDecoration(
                      color: _backgroundColor,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _lightOlive.withOpacity(0.3)),
                    ),
                    child: const Center(
                      child: Text(
                        'No EEG data received\nConnect and start streaming',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: Colors.grey),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionLogs() {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.list_alt, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Connection Log',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => setState(() => _connectionLogs.clear()),
                  icon: const Icon(Icons.clear_all, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 12),

            Container(
              height: 200,
              decoration: BoxDecoration(
                color: _backgroundColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: _lightOlive.withOpacity(0.3)),
              ),
              child: _connectionLogs.isEmpty
                  ? const Center(
                child: Text(
                  'No logs yet\nConnection events will appear here',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey),
                ),
              )
                  : ListView.builder(
                reverse: true,
                itemCount: _connectionLogs.length,
                itemBuilder: (context, index) {
                  final log = _connectionLogs[index];
                  return Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: index < _connectionLogs.length - 1
                            ? BorderSide(color: _lightOlive.withOpacity(0.2))
                            : BorderSide.none,
                      ),
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${log['timestamp'].toString().split(' ')[1].split('.')[0]}',
                          style: TextStyle(
                            fontSize: 10,
                            color: _textColor.withOpacity(0.5),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            log['message'],
                            style: TextStyle(
                              fontSize: 12,
                              color: _getLogColor(log['type']),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRealtimeResults() {
    if (_realtimeResult == null || !_isProcessingRealtime) {
      return const SizedBox();
    }

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.emoji_events, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Live Emotion Detection',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.orange,
                  ),
                ),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.orange,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Text(
                    'LIVE',
                    style: TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Real-time emotion display
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.withOpacity(0.3)),
              ),
              child: Column(
                children: [
                  Text(
                    _getEmoji(_realtimeResult!.topLabel ?? "UNKNOWN"),
                    style: const TextStyle(fontSize: 48),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _realtimeResult!.topLabel?.toUpperCase() ?? "UNKNOWN",
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.orange,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Confidence: ${(_realtimeResult!.topProb * 100).toStringAsFixed(1)}%',
                    style: const TextStyle(fontSize: 16, color: Colors.orange),
                  ),
                  const SizedBox(height: 12),
                  LinearProgressIndicator(
                    value: _realtimeResult!.topProb,
                    backgroundColor: Colors.grey[300],
                    color: _getConfidenceColor(_realtimeResult!.topProb),
                    minHeight: 8,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getConfidenceColor(double confidence) {
    if (confidence > 0.7) return Colors.green;
    if (confidence > 0.5) return Colors.orange;
    return Colors.red;
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

  @override
  void dispose() {
    _predictionTimer?.cancel();
    _bluetoothService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: CustomScrollView(
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.all(16),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Real-time Connection Panel
                _buildRealtimeConnectionPanel(),
                const SizedBox(height: 20),

                // Device List
                _buildDeviceList(),
                const SizedBox(height: 20),

                // Real-time Data Panel
                _buildRealtimeDataPanel(),
                const SizedBox(height: 20),

                // Connection Logs
                _buildConnectionLogs(),
                const SizedBox(height: 20),

                // Real-time Results (if available)
                _buildRealtimeResults(),
                const SizedBox(height: 20),
              ]),
            ),
          ),
        ],
      ),
    );
  }
}