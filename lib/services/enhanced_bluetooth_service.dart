// lib/services/enhanced_bluetooth_service.dart
import 'dart:async';
import 'dart:convert';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:permission_handler/permission_handler.dart';

class EEGRealTimeBluetoothService {
  // Stream controllers
  final StreamController<bool> _scanningController = StreamController<bool>.broadcast();
  final StreamController<bool> _connectingController = StreamController<bool>.broadcast();
  final StreamController<List<BluetoothDevice>> _devicesController = StreamController<List<BluetoothDevice>>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();
  final StreamController<List<double>> _eegDataController = StreamController<List<double>>.broadcast();
  final StreamController<Map<String, dynamic>> _deviceDataController = StreamController<Map<String, dynamic>>.broadcast();

  // State variables
  List<BluetoothDevice> _connectedDevices = [];
  List<BluetoothDevice> _discoveredDevices = [];
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isStreaming = false;

  // EEG Data characteristics
  BluetoothCharacteristic? _eegDataCharacteristic;
  BluetoothCharacteristic? _controlCharacteristic;
  StreamSubscription<List<int>>? _eegDataSubscription;

  // Common EEG Service UUIDs
  static const String EEG_SERVICE_UUID = "0000fff0-0000-1000-8000-00805f9b34fb";
  static const String EEG_DATA_CHARACTERISTIC_UUID = "0000fff1-0000-1000-8000-00805f9b34fb";
  static const String CONTROL_CHARACTERISTIC_UUID = "0000fff2-0000-1000-8000-00805f9b34fb";

  // Device configuration
  Map<String, dynamic> _currentDeviceConfig = {
    'samplingRate': 256,
    'channels': 5,
    'bytesPerSample': 4,
    'isLittleEndian': true,
  };

  // Getters
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  bool get isStreaming => _isStreaming;
  List<BluetoothDevice> get connectedDevices => _connectedDevices;
  List<BluetoothDevice> get devices => _discoveredDevices;
  BluetoothDevice? get connectedDevice => _connectedDevices.isNotEmpty ? _connectedDevices.first : null;

  // Stream getters
  Stream<bool> get scanningStream => _scanningController.stream;
  Stream<bool> get connectingStream => _connectingController.stream;
  Stream<List<BluetoothDevice>> get devicesStream => _devicesController.stream;
  Stream<String> get statusStream => _statusController.stream;
  Stream<List<double>> get eegDataStream => _eegDataController.stream;
  Stream<Map<String, dynamic>> get deviceDataStream => _deviceDataController.stream;

  // Initialize Bluetooth service
  Future<void> initialize() async {
    try {
      _addStatus('Initializing Real-time Bluetooth service...');

      // Check Bluetooth availability
      if (!await FlutterBluePlus.isAvailable) {
        throw Exception('Bluetooth not available on this device');
      }

      // Listen for adapter state changes
      FlutterBluePlus.adapterState.listen((state) {
        _addStatus('Bluetooth adapter state: $state');
        if (state == BluetoothAdapterState.off) {
          _stopAllOperations();
          _addStatus('Bluetooth turned off - stopping all operations');
        }
      });

      // Get currently connected devices
      _connectedDevices = await FlutterBluePlus.connectedDevices;
      _addStatus('Found ${_connectedDevices.length} connected devices');

      _devicesController.add(_discoveredDevices);
      _addStatus('Real-time Bluetooth service initialized');

    } catch (e) {
      _addStatus('Initialization failed: $e');
      rethrow;
    }
  }

  // Start scanning for EEG devices
  Future<void> startScan({int timeoutSeconds = 15}) async {
    if (_isScanning) return;

    try {
      _addStatus('Starting EEG device scan...');

      // Check permissions
      if (!await _checkPermissions()) {
        throw Exception('Bluetooth permissions not granted');
      }

      // Check if Bluetooth is on
      if (!await FlutterBluePlus.isOn) {
        throw Exception('Please enable Bluetooth');
      }

      _isScanning = true;
      _scanningController.add(true);
      _discoveredDevices.clear();
      _devicesController.add(_discoveredDevices);

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: timeoutSeconds),
        continuousUpdates: true,
      );

      // Listen for scan results
      FlutterBluePlus.scanResults.listen((results) {
        _processScanResults(results);
      });

      _addStatus('Scanning for EEG devices...');

      // Auto-stop after timeout
      Timer(Duration(seconds: timeoutSeconds), () {
        if (_isScanning) stopScan();
      });

    } catch (e) {
      _isScanning = false;
      _scanningController.add(false);
      _addStatus('Scan failed: $e');
      rethrow;
    }
  }

  // Process scan results with better EEG device detection
  void _processScanResults(List<ScanResult> results) {
    bool newDeviceFound = false;

    for (var result in results) {
      if (_isEEGDevice(result)) {
        final device = result.device;

        // Check if device is already in list
        final existingIndex = _discoveredDevices.indexWhere(
                (d) => d.remoteId == device.remoteId
        );

        if (existingIndex == -1) {
          // New device found
          _discoveredDevices.add(device);
          newDeviceFound = true;
          _addStatus('🎯 Found EEG device: ${device.platformName} | RSSI: ${result.rssi}dBm');
        } else {
          // Update existing device RSSI
          _discoveredDevices[existingIndex] = device;
        }
      }
    }

    if (newDeviceFound) {
      _devicesController.add(List.from(_discoveredDevices));
    }
  }

  // Enhanced EEG device detection
  bool _isEEGDevice(ScanResult result) {
    final device = result.device;
    final name = device.platformName.toLowerCase();
    final ad = result.advertisementData;

    // EEG device keywords
    final eegKeywords = [
      'eeg', 'neuro', 'brain', 'mind', 'muse', 'emotiv', 'neurosky',
      'openbci', 'cyton', 'ganglion', 'mentalab', 'brainflow', 'bci'
    ];

    // Check name for keywords
    for (var keyword in eegKeywords) {
      if (name.contains(keyword)) return true;
    }

    // Check service UUIDs
    for (var uuid in ad.serviceUuids) {
      if (_isEEGService(uuid)) return true;
    }

    // Check manufacturer data for EEG devices
    if (ad.manufacturerData.isNotEmpty) {
      // Common EEG manufacturer IDs
      final eegManufacturers = [0x0001, 0x0002, 0x000D, 0x001B];
      for (var key in ad.manufacturerData.keys) {
        if (eegManufacturers.contains(key)) return true;
      }
    }

    // Accept devices with strong signal that don't match common non-EEG patterns
    if (result.rssi > -60 &&
        !name.contains('phone') &&
        !name.contains('watch') &&
        !name.contains('tablet')) {
      return true;
    }

    return false;
  }

  bool _isEEGService(Guid uuid) {
    final eegServices = [
      Guid(EEG_SERVICE_UUID),
      Guid('0000180d-0000-1000-8000-00805f9b34fb'), // Heart Rate
      Guid('0000180a-0000-1000-8000-00805f9b34fb'), // Device Info
      Guid('0000ffe0-0000-1000-8000-00805f9b34fb'), // Custom EEG
      Guid('0000ffb0-0000-1000-8000-00805f9b34fb'), // EEG Data
    ];
    return eegServices.any((eegUuid) => eegUuid == uuid);
  }

  // Connect to EEG device
  Future<void> connectToDevice(BluetoothDevice device) async {
    if (_isConnecting) {
      _addStatus('Connection in progress, please wait...');
      return;
    }

    try {
      _isConnecting = true;
      _connectingController.add(true);
      _addStatus('Connecting to ${device.platformName}...');

      // Set up connection state listener
      final connectionSubscription = device.connectionState.listen((state) {
        _handleConnectionStateChange(device, state);
      });

      // Connect with timeout
      await device.connect(timeout: Duration(seconds: 20));

      // Wait for connection to stabilize
      await Future.delayed(Duration(milliseconds: 500));

      // Discover services
      _addStatus('Discovering services...');
      final services = await device.discoverServices();

      // Find EEG services and characteristics
      await _setupEEGService(device, services);

      await connectionSubscription.cancel();

      _addStatus('✅ Successfully connected to ${device.platformName}');
      _isConnecting = false;
      _connectingController.add(false);

    } catch (e) {
      _isConnecting = false;
      _connectingController.add(false);
      _addStatus('❌ Connection failed: $e');
      rethrow;
    }
  }

  // Handle connection state changes
  void _handleConnectionStateChange(BluetoothDevice device, BluetoothConnectionState state) {
    switch (state) {
      case BluetoothConnectionState.connected:
        if (!_connectedDevices.any((d) => d.remoteId == device.remoteId)) {
          _connectedDevices.add(device);
        }
        _devicesController.add(List.from(_discoveredDevices));
        _addStatus('🔗 Connected to ${device.platformName}');
        break;

      case BluetoothConnectionState.disconnected:
        _connectedDevices.removeWhere((d) => d.remoteId == device.remoteId);
        _devicesController.add(List.from(_discoveredDevices));
        _stopEEGStreaming();
        _addStatus('🔌 Disconnected from ${device.platformName}');
        break;

      case BluetoothConnectionState.connecting:
        _addStatus('🔄 Connecting to ${device.platformName}...');
        break;

      case BluetoothConnectionState.disconnecting:
        _addStatus('📴 Disconnecting from ${device.platformName}...');
        break;
    }
  }

  // Setup EEG service and characteristics
  Future<void> _setupEEGService(BluetoothDevice device, List<BluetoothService> services) async {
    _addStatus('Setting up EEG service...');

    for (var service in services) {
      _addStatus('Service: ${service.serviceUuid}');

      // Look for EEG service
      if (service.serviceUuid == Guid(EEG_SERVICE_UUID) ||
          _isCustomEEGService(service)) {

        for (var characteristic in service.characteristics) {
          _addStatus('Characteristic: ${characteristic.characteristicUuid}');

          // Identify EEG data characteristic
          if (characteristic.characteristicUuid == Guid(EEG_DATA_CHARACTERISTIC_UUID) ||
              _isEEGDataCharacteristic(characteristic)) {
            _eegDataCharacteristic = characteristic;
            _addStatus('✅ Found EEG data characteristic');
          }

          // Identify control characteristic
          if (characteristic.characteristicUuid == Guid(CONTROL_CHARACTERISTIC_UUID) ||
              _isControlCharacteristic(characteristic)) {
            _controlCharacteristic = characteristic;
            _addStatus('✅ Found control characteristic');
          }
        }
      }
    }

    if (_eegDataCharacteristic == null) {
      throw Exception('Could not find EEG data characteristic');
    }

    // Configure device for EEG streaming
    await _configureEEGDevice();
  }

  bool _isCustomEEGService(BluetoothService service) {
    // Check if service has characteristics that look like EEG data
    return service.characteristics.any((char) =>
    char.properties.read || char.properties.notify);
  }

  bool _isEEGDataCharacteristic(BluetoothCharacteristic characteristic) {
    return characteristic.properties.notify &&
        characteristic.properties.read;
  }

  bool _isControlCharacteristic(BluetoothCharacteristic characteristic) {
    return characteristic.properties.write;
  }

  // Configure EEG device for streaming
  Future<void> _configureEEGDevice() async {
    try {
      _addStatus('Configuring EEG device...');

      // Send start command to control characteristic if available
      if (_controlCharacteristic != null) {
        final startCommand = [0x01, 0x80, 0x00, 0x01]; // Example start command
        await _controlCharacteristic!.write(startCommand);
        _addStatus('📝 Sent start command to device');
      }

      // Enable notifications for EEG data
      await _eegDataCharacteristic!.setNotifyValue(true);
      _addStatus('🔔 Enabled EEG data notifications');

      // Set up data streaming
      _setupEEGDataStreaming();

    } catch (e) {
      _addStatus('Configuration failed: $e');
      rethrow;
    }
  }

  // Setup EEG data streaming
  void _setupEEGDataStreaming() {
    _eegDataSubscription = _eegDataCharacteristic!.onValueReceived.listen((data) {
      _processEEGData(data);
    });

    _isStreaming = true;
    _addStatus('🎯 EEG data streaming started');

    // Send device data update
    _deviceDataController.add({
      'type': 'streaming_started',
      'timestamp': DateTime.now().millisecondsSinceEpoch,
      'status': 'streaming',
      'samplingRate': _currentDeviceConfig['samplingRate'],
      'channels': _currentDeviceConfig['channels'],
    });
  }

  // Process incoming EEG data
  void _processEEGData(List<int> rawData) {
    try {
      // Convert raw bytes to EEG values
      final eegValues = _parseEEGData(rawData);

      if (eegValues.isNotEmpty) {
        // Send to data stream
        _eegDataController.add(eegValues);

        // Send to device data stream for UI updates
        _deviceDataController.add({
          'type': 'eeg_data',
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'data': eegValues,
          'channelCount': eegValues.length,
          'rawDataLength': rawData.length,
        });
      }
    } catch (e) {
      _addStatus('EEG data processing error: $e');
    }
  }

  // Parse EEG data from bytes to double values
  List<double> _parseEEGData(List<int> data) {
    try {
      // Example parsing for 5 channels of 32-bit float data
      if (data.length < 20) return []; // Need at least 5 floats * 4 bytes

      List<double> values = [];
      for (int i = 0; i < data.length; i += 4) {
        if (i + 4 <= data.length) {
          // Convert 4 bytes to 32-bit float
          final bytes = data.sublist(i, i + 4);
          final value = _bytesToFloat(bytes, _currentDeviceConfig['isLittleEndian']);
          values.add(value);

          if (values.length >= 5) break; // We only need 5 channels
        }
      }

      return values;
    } catch (e) {
      _addStatus('Data parsing error: $e');
      return [];
    }
  }

  double _bytesToFloat(List<int> bytes, bool isLittleEndian) {
    // Simple conversion - in real app, use proper IEEE 754 conversion
    if (bytes.length != 4) return 0.0;

    // This is a simplified conversion - replace with proper implementation
    // based on your specific EEG device's data format
    final value = (bytes[0] + bytes[1] + bytes[2] + bytes[3]) / 4.0;
    return value.toDouble();
  }

  // Start EEG data streaming
  Future<void> startEEGStreaming() async {
    if (!_isStreaming && _eegDataCharacteristic != null) {
      await _eegDataCharacteristic!.setNotifyValue(true);
      _isStreaming = true;
      _addStatus('🎯 EEG streaming started');
    }
  }

  // Stop EEG data streaming
  Future<void> stopEEGStreaming() async {
    if (_isStreaming && _eegDataCharacteristic != null) {
      await _eegDataCharacteristic!.setNotifyValue(false);
      _stopEEGStreaming();
      _addStatus('⏹️ EEG streaming stopped');

      _deviceDataController.add({
        'type': 'streaming_stopped',
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'status': 'idle',
      });
    }
  }

  // Internal method to stop EEG streaming
  void _stopEEGStreaming() {
    if (_isStreaming) {
      _isStreaming = false;
      _eegDataSubscription?.cancel();
      _eegDataSubscription = null;

      // Send stop command to device if control characteristic is available
      if (_controlCharacteristic != null) {
        try {
          final stopCommand = [0x01, 0x00, 0x00, 0x00]; // Example stop command
          _controlCharacteristic!.write(stopCommand);
        } catch (e) {
          _addStatus('Error sending stop command: $e');
        }
      }

      _addStatus('EEG streaming stopped internally');
    }
  }

  // Stop all operations
  void _stopAllOperations() {
    stopScan();
    stopEEGStreaming();
  }

  // Disconnect from device
  Future<void> disconnectDevice() async {
    if (connectedDevice != null) {
      _addStatus('Disconnecting from ${connectedDevice!.platformName}...');
      await stopEEGStreaming();
      await connectedDevice!.disconnect();
      _connectedDevices.clear();
      _devicesController.add(_discoveredDevices);
    }
  }

  // Check Bluetooth permissions
  Future<bool> _checkPermissions() async {
    try {
      if (await Permission.bluetoothConnect.request().isGranted &&
          await Permission.bluetoothScan.request().isGranted) {
        return true;
      }
      return await Permission.locationWhenInUse.request().isGranted;
    } catch (e) {
      return false;
    }
  }

  // Get device information
  Future<Map<String, dynamic>> getDeviceInfo() async {
    if (connectedDevice == null) return {};

    try {
      final services = await connectedDevice!.discoverServices();
      Map<String, dynamic> info = {
        'name': connectedDevice!.platformName,
        'id': connectedDevice!.remoteId.toString(),
        'services': services.length,
        'streaming': _isStreaming,
        'config': _currentDeviceConfig,
      };

      return info;
    } catch (e) {
      return {'error': e.toString()};
    }
  }

  // Stop scanning
  Future<void> stopScan() async {
    if (!_isScanning) return;

    try {
      _addStatus('Stopping scan...');
      await FlutterBluePlus.stopScan();
      _isScanning = false;
      _scanningController.add(false);
      _addStatus('Scan stopped. Found ${_discoveredDevices.length} devices');
    } catch (e) {
      _isScanning = false;
      _scanningController.add(false);
      _addStatus('Error stopping scan: $e');
      rethrow;
    }
  }

  // Add status message
  void _addStatus(String message) {
    final timestamp = DateTime.now().toString().split(' ')[1].split('.')[0];
    print('[$timestamp] EEGRealTime: $message');
    if (!_statusController.isClosed) {
      _statusController.add('[$timestamp] $message');
    }
  }

  // Cleanup
  void dispose() {
    _addStatus('Disposing Real-time Bluetooth service...');

    _stopAllOperations();
    _eegDataSubscription?.cancel();

    _scanningController.close();
    _connectingController.close();
    _devicesController.close();
    _statusController.close();
    _eegDataController.close();
    _deviceDataController.close();

    _addStatus('Real-time Bluetooth service disposed');
  }
}