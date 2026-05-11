import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../services/neurosky_bluetooth_service.dart';

class HeadsetConnectionScreen extends StatefulWidget {
  const HeadsetConnectionScreen({super.key});

  @override
  State<HeadsetConnectionScreen> createState() => _HeadsetConnectionScreenState();
}

class _HeadsetConnectionScreenState extends State<HeadsetConnectionScreen> with TickerProviderStateMixin {
  final NeuroskyBluetoothService _neuroskyService = NeuroskyBluetoothService();

  // Stream subscriptions
  StreamSubscription<bool>? _scanningSubscription;
  StreamSubscription<bool>? _connectingSubscription;
  StreamSubscription<bool>? _connectedSubscription;
  StreamSubscription<Map<String, dynamic>>? _neuroskyDataSubscription;
  StreamSubscription<String>? _statusSubscription;

  // State variables
  List<String> _statusLogs = [];
  bool _isConnected = false;
  BluetoothDevice? _connectedDevice;
  bool _isStreaming = false;
  Map<String, dynamic>? _latestData;

  // Animation controllers
  late AnimationController _pulseController;
  late AnimationController _fadeController;
  late Animation<double> _pulseAnimation;
  late Animation<double> _fadeAnimation;

  // Colors
  final Color _primaryColor = const Color(0xFF3DC75A);
  final Color _accentColor = const Color(0xFF4699E2);
  final Color _backgroundColor = const Color(0xFFF8F9FA);
  final Color _cardColor = Colors.white;
  final Color _errorColor = const Color(0xFFF44336);
  final Color _warningColor = const Color(0xFFFF9800);

  @override
  void initState() {
    super.initState();
    _initializeAnimations();
    _neuroskyService.initialize();
    _setupListeners();
    _checkBluetoothAndStart();
  }

  void _initializeAnimations() {
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fadeController, curve: Curves.easeIn),
    );

    _fadeController.forward();
  }

  void _setupListeners() {
    _scanningSubscription = _neuroskyService.scanningStream.listen((isScanning) {
      if (mounted) setState(() {});
    });

    _connectingSubscription = _neuroskyService.connectingStream.listen((isConnecting) {
      if (mounted) setState(() {});
    });

    _connectedSubscription = _neuroskyService.connectedStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
          _connectedDevice = _neuroskyService.connectedDevice;
        });
      }
    });

    _neuroskyDataSubscription = _neuroskyService.neuroskyDataStream.listen((data) {
      if (mounted) {
        setState(() {
          _latestData = data;
        });
      }
    });

    _statusSubscription = _neuroskyService.statusStream.listen((status) {
      _addStatusLog(status);
    });
  }

  void _addStatusLog(String log) {
    if (mounted) {
      setState(() {
        _statusLogs.insert(0, log);
        if (_statusLogs.length > 50) {
          _statusLogs = _statusLogs.sublist(0, 50);
        }
      });
    }
  }

  Future<void> _checkBluetoothAndStart() async {
    final isAvailable = await _neuroskyService.checkBluetoothAvailability();
    if (isAvailable) {
      _startScan();
    } else {
      _showErrorDialog(
        'Bluetooth Required',
        'Please enable Bluetooth to connect to your Neurosky headset.',
      );
    }
  }

  Future<void> _startScan() async {
    try {
      await _neuroskyService.startScan(timeoutSeconds: 30);
    } catch (e) {
      _showErrorDialog('Scan Failed', 'Failed to start scanning: ${e.toString()}');
    }
  }

  Future<void> _connectToDevice(BluetoothDevice device) async {
    try {
      await _neuroskyService.connectToDevice(device);
      _showSuccessSnackbar('Connected to ${device.platformName}');
    } catch (e) {
      _showErrorDialog('Connection Failed', 'Failed to connect: ${e.toString()}');
    }
  }

  Future<void> _disconnectDevice() async {
    try {
      await _neuroskyService.disconnectDevice();
      _showSuccessSnackbar('Disconnected from device');
    } catch (e) {
      _showErrorDialog('Disconnect Failed', 'Failed to disconnect: ${e.toString()}');
    }
  }

  Future<void> _startStreaming() async {
    try {
      await _neuroskyService.startEEGStreaming();
      setState(() {
        _isStreaming = true;
      });
      _showSuccessSnackbar('🎯 EEG Streaming started');
    } catch (e) {
      _showErrorDialog('Streaming Failed', 'Failed to start streaming: ${e.toString()}');
    }
  }

  Future<void> _stopStreaming() async {
    try {
      await _neuroskyService.stopEEGStreaming();
      setState(() {
        _isStreaming = false;
      });
      _showSuccessSnackbar('⏹️ EEG Streaming stopped');
    } catch (e) {
      _showErrorDialog('Stop Failed', 'Failed to stop streaming: ${e.toString()}');
    }
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            Icon(Icons.error_outline, color: _errorColor),
            const SizedBox(width: 8),
            Text(title),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: _primaryColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [_primaryColor, _accentColor],
        ),
      ),
      child: SafeArea(
        child: Column(
          children: [
            Row(
              children: [
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.arrow_back, color: Colors.white),
                ),
                const Expanded(
                  child: Text(
                    'Connect Headset',
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (_neuroskyService.isScanning)
                  IconButton(
                    onPressed: () => _neuroskyService.stopScan(),
                    icon: const Icon(Icons.stop, color: Colors.white),
                  )
                else if (!_isConnected)
                  IconButton(
                    onPressed: _startScan,
                    icon: const Icon(Icons.refresh, color: Colors.white),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            if (_isConnected && _connectedDevice != null)
              _buildConnectionStatus()
            else
              _buildScanningStatus(),
          ],
        ),
      ),
    );
  }

  Widget _buildConnectionStatus() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          ScaleTransition(
            scale: _pulseAnimation,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.white,
                shape: BoxShape.circle,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _connectedDevice!.platformName.isEmpty
                      ? 'Neurosky Device'
                      : _connectedDevice!.platformName,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  _isStreaming ? '🎯 Streaming EEG Data' : '✅ Connected',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: _disconnectDevice,
            icon: const Icon(Icons.close, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningStatus() {
    if (_neuroskyService.isScanning) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.2),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Scanning for devices...',
              style: TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.bluetooth_searching, color: Colors.white),
          SizedBox(width: 12),
          Text(
            'Ready to scan',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDevicesList() {
    final devices = _neuroskyService.devices;

    if (devices.isEmpty && !_neuroskyService.isScanning) {
      return _buildEmptyState();
    }

    if (devices.isEmpty && _neuroskyService.isScanning) {
      return _buildScanningEmptyState();
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: devices.length,
      itemBuilder: (context, index) {
        final device = devices[index];
        final isConnecting = _neuroskyService.isConnecting &&
            _neuroskyService.connectedDevice?.remoteId == device.remoteId;
        final isConnected = _neuroskyService.connectedDevice?.remoteId == device.remoteId;

        return _buildDeviceCard(device, isConnecting, isConnected);
      },
    );
  }

  Widget _buildDeviceCard(BluetoothDevice device, bool isConnecting, bool isConnected) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      elevation: isConnected ? 4 : 2,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(
          color: isConnected ? _primaryColor : Colors.transparent,
          width: 2,
        ),
      ),
      child: InkWell(
        onTap: isConnected || isConnecting ? null : () => _connectToDevice(device),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  color: (isConnected ? _primaryColor : _accentColor).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.psychology,
                  color: isConnected ? _primaryColor : _accentColor,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      device.platformName.isEmpty ? 'Neurosky Device' : device.platformName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'ID: ${device.remoteId.toString().substring(0, 17)}...',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                      ),
                    ),
                    if (isConnected) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: _primaryColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Connected',
                            style: TextStyle(
                              fontSize: 12,
                              color: _primaryColor,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              if (isConnecting)
                SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: _accentColor,
                  ),
                )
              else if (isConnected)
                Icon(Icons.check_circle, color: _primaryColor, size: 32)
              else
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: _accentColor,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Connect',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.bluetooth_disabled,
              size: 80,
              color: Colors.grey[400],
            ),
            const SizedBox(height: 16),
            Text(
              'No Devices Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Make sure your Neurosky headset is turned on and nearby',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: _startScan,
              icon: const Icon(Icons.refresh),
              label: const Text('Scan Again'),
              style: ElevatedButton.styleFrom(
                backgroundColor: _accentColor,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildScanningEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ScaleTransition(
              scale: _pulseAnimation,
              child: Icon(
                Icons.bluetooth_searching,
                size: 80,
                color: _accentColor,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Searching for Devices',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: Colors.grey[700],
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Please wait while we scan for nearby Neurosky headsets...',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: Colors.grey[600],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStreamingControls() {
    if (!_isConnected) return const SizedBox();

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.settings_input_antenna, color: _primaryColor),
                const SizedBox(width: 8),
                const Text(
                  'EEG Data Streaming',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isStreaming ? _stopStreaming : _startStreaming,
                    icon: Icon(_isStreaming ? Icons.stop : Icons.play_arrow),
                    label: Text(_isStreaming ? 'Stop Streaming' : 'Start Streaming'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _isStreaming ? _errorColor : _primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            if (_isStreaming && _latestData != null) ...[
              const SizedBox(height: 16),
              _buildDataPreview(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildDataPreview() {
    final signalQuality = _latestData!['signalQuality'] as int? ?? 200;
    final attention = _latestData!['attention'] as int? ?? 0;
    final meditation = _latestData!['meditation'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _backgroundColor,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Live Data Preview',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 12),
          _buildMetric('Signal Quality', _getSignalQualityText(signalQuality),
              _getSignalQualityColor(signalQuality)),
          const SizedBox(height: 8),
          _buildMetric('Attention', '$attention%', _getPowerColor(attention)),
          const SizedBox(height: 8),
          _buildMetric('Meditation', '$meditation%', _getPowerColor(meditation)),
        ],
      ),
    );
  }

  Widget _buildMetric(String label, String value, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 13,
            color: Colors.grey[700],
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  String _getSignalQualityText(int quality) {
    if (quality == 0) return 'Perfect';
    if (quality < 50) return 'Good';
    if (quality < 100) return 'Fair';
    if (quality < 200) return 'Poor';
    return 'No Signal';
  }

  Color _getSignalQualityColor(int quality) {
    if (quality < 50) return _primaryColor;
    if (quality < 100) return Colors.blue;
    if (quality < 200) return _warningColor;
    return _errorColor;
  }

  Color _getPowerColor(int value) {
    if (value > 70) return _primaryColor;
    if (value > 40) return Colors.blue;
    return _warningColor;
  }

  Widget _buildStatusLogs() {
    if (_statusLogs.isEmpty) return const SizedBox();

    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Icon(Icons.description, color: _accentColor),
                const SizedBox(width: 8),
                const Text(
                  'Activity Log',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {
                    setState(() {
                      _statusLogs.clear();
                    });
                  },
                  icon: const Icon(Icons.clear_all, size: 20),
                ),
              ],
            ),
          ),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: _statusLogs.length > 10 ? 10 : _statusLogs.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '•',
                        style: TextStyle(
                          color: _accentColor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _statusLogs[index],
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[700],
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
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _scanningSubscription?.cancel();
    _connectingSubscription?.cancel();
    _connectedSubscription?.cancel();
    _neuroskyDataSubscription?.cancel();
    _statusSubscription?.cancel();
    // Don't dispose the service if we want to keep connection on navigation
    // _neuroskyService.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _backgroundColor,
      body: FadeTransition(
        opacity: _fadeAnimation,
        child: Column(
          children: [
            _buildHeader(),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 16),
                    if (_isConnected) ...[
                      _buildStreamingControls(),
                    ],
                    _buildDevicesList(),
                    _buildStatusLogs(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: _isConnected
          ? FloatingActionButton.extended(
        onPressed: () {
          Navigator.pop(context, {
            'connected': true,
            'device': _connectedDevice,
            'service': _neuroskyService,
          });
        },
        backgroundColor: _primaryColor,
        icon: const Icon(Icons.check),
        label: const Text('Done'),
      )
          : null,
    );
  }
}