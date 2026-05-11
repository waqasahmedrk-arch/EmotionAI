// lib/services/neurosky_bluetooth_service.dart
import 'dart:async';
import 'dart:typed_data';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class NeuroskyBluetoothService {
  static final NeuroskyBluetoothService _instance = NeuroskyBluetoothService._internal();
  factory NeuroskyBluetoothService() => _instance;
  NeuroskyBluetoothService._internal();

  // Neurosky Mindwave MW003 Specific UUIDs
  static const String NEUROSKY_SERVICE_UUID = "0000eee0-0000-1000-8000-00805f9b34fb";
  static const String NEUROSKY_DATA_CHARACTERISTIC_UUID = "0000eee1-0000-1000-8000-00805f9b34fb";
  static const String NEUROSKY_CONFIG_CHARACTERISTIC_UUID = "0000eee2-0000-1000-8000-00805f9b34fb";

  // Service state
  bool _isInitialized = false;
  bool _isScanning = false;
  bool _isConnecting = false;
  bool _isConnected = false;
  bool _isStreaming = false;

  // Stream controllers
  final StreamController<bool> _scanningController = StreamController<bool>.broadcast();
  final StreamController<bool> _connectingController = StreamController<bool>.broadcast();
  final StreamController<bool> _connectedController = StreamController<bool>.broadcast();
  final StreamController<List<double>> _eegDataController = StreamController<List<double>>.broadcast();
  final StreamController<Map<String, dynamic>> _neuroskyDataController = StreamController<Map<String, dynamic>>.broadcast();
  final StreamController<String> _statusController = StreamController<String>.broadcast();

  // Bluetooth objects
  BluetoothDevice? _connectedDevice;
  BluetoothCharacteristic? _dataCharacteristic;
  BluetoothCharacteristic? _configCharacteristic;
  StreamSubscription<BluetoothConnectionState>? _connectionSubscription;

  // Data parsing
  List<int> _dataBuffer = [];
  final List<List<double>> _eegSamples = [];

  // Getters
  bool get isScanning => _isScanning;
  bool get isConnecting => _isConnecting;
  bool get isConnected => _isConnected;
  bool get isStreaming => _isStreaming;
  BluetoothDevice? get connectedDevice => _connectedDevice;
  List<BluetoothDevice> get devices => _discoveredDevices;

  // Streams
  Stream<bool> get scanningStream => _scanningController.stream;
  Stream<bool> get connectingStream => _connectingController.stream;
  Stream<bool> get connectedStream => _connectedController.stream;
  Stream<List<double>> get eegDataStream => _eegDataController.stream;
  Stream<Map<String, dynamic>> get neuroskyDataStream => _neuroskyDataController.stream;
  Stream<String> get statusStream => _statusController.stream;

  // Device storage
  final List<BluetoothDevice> _discoveredDevices = [];
  StreamSubscription<List<ScanResult>>? _scanSubscription;

  // Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      // Check Bluetooth availability
      bool isAvailable = await FlutterBluePlus.isAvailable;
      if (!isAvailable) {
        throw Exception('Bluetooth is not available on this device');
      }

      bool isOn = await FlutterBluePlus.isOn;
      if (!isOn) {
        throw Exception('Please enable Bluetooth');
      }

      _isInitialized = true;
      _addStatus('Neurosky Bluetooth Service Initialized');
    } catch (e) {
      _addStatus('Initialization failed: $e');
      rethrow;
    }
  }

  // Start scanning for Neurosky devices
  Future<void> startScan({int timeoutSeconds = 15}) async {
    if (_isScanning) return;

    try {
      _discoveredDevices.clear();
      _isScanning = true;
      _scanningController.add(true);
      _addStatus('🔍 Scanning for Neurosky devices...');

      // Listen for scan results
      _scanSubscription = FlutterBluePlus.scanResults.listen((results) {
        for (ScanResult result in results) {
          _addDiscoveredDevice(result.device);
        }
      });

      // Start scanning
      await FlutterBluePlus.startScan(
        timeout: Duration(seconds: timeoutSeconds),
      );

      // Auto-stop after timeout
      Timer(Duration(seconds: timeoutSeconds), () {
        if (_isScanning) {
          stopScan();
        }
      });

    } catch (e) {
      _isScanning = false;
      _scanningController.add(false);
      _addStatus('❌ Scan failed: $e');
      rethrow;
    }
  }

  // Stop scanning
  Future<void> stopScan() async {
    if (!_isScanning) return;

    try {
      await FlutterBluePlus.stopScan();
      _scanSubscription?.cancel();
      _scanSubscription = null;
      _isScanning = false;
      _scanningController.add(false);
      _addStatus('Scanning stopped. Found ${_discoveredDevices.length} devices.');
    } catch (e) {
      _addStatus('Error stopping scan: $e');
    }
  }

  // Connect to a specific device
  Future<void> connectToDevice(BluetoothDevice device) async {
    if (_isConnecting || _isConnected) return;

    try {
      _isConnecting = true;
      _connectingController.add(true);
      _addStatus('🔗 Connecting to ${device.platformName}...');

      // Listen for connection state changes
      _connectionSubscription = device.connectionState.listen((state) {
        _handleConnectionStateChange(state, device);
      });

      // Connect to device
      await device.connect();
      _connectedDevice = device;

      // Wait a bit for connection to stabilize
      await Future.delayed(Duration(milliseconds: 1000));

      // Discover services
      _addStatus('Discovering services...');
      List<BluetoothService> services = await device.discoverServices();

      // Find Neurosky service and characteristics
      BluetoothService? neuroskyService;
      for (BluetoothService service in services) {
        if (service.uuid.toString().toLowerCase() == NEUROSKY_SERVICE_UUID) {
          neuroskyService = service;
          break;
        }
      }

      if (neuroskyService == null) {
        throw Exception('Neurosky service not found. Device may not be compatible.');
      }

      // Find characteristics
      for (BluetoothCharacteristic characteristic in neuroskyService.characteristics) {
        String charUuid = characteristic.uuid.toString().toLowerCase();

        if (charUuid == NEUROSKY_DATA_CHARACTERISTIC_UUID) {
          _dataCharacteristic = characteristic;
          _addStatus('Found data characteristic');
        } else if (charUuid == NEUROSKY_CONFIG_CHARACTERISTIC_UUID) {
          _configCharacteristic = characteristic;
          _addStatus('Found config characteristic');
        }
      }

      if (_dataCharacteristic == null) {
        throw Exception('Data characteristic not found');
      }

      _isConnecting = false;
      _connectingController.add(false);
      _addStatus('✅ Successfully connected to Neurosky Mindwave');

    } catch (e) {
      _isConnecting = false;
      _connectingController.add(false);
      _connectionSubscription?.cancel();
      await device.disconnect();
      _addStatus('❌ Connection failed: $e');
      rethrow;
    }
  }

  // Handle connection state changes
  void _handleConnectionStateChange(BluetoothConnectionState state, BluetoothDevice device) {
    switch (state) {
      case BluetoothConnectionState.connected:
        _isConnected = true;
        _isConnecting = false;
        _connectedController.add(true);
        _addStatus('✅ Device connected');
        break;

      case BluetoothConnectionState.disconnected:
        _resetState();
        _addStatus('📴 Device disconnected');
        break;

      case BluetoothConnectionState.connecting:
        _isConnecting = true;
        _connectingController.add(true);
        _addStatus('🔄 Connecting to device...');
        break;

      case BluetoothConnectionState.disconnecting:
        _addStatus('🔻 Disconnecting from device...');
        break;
    }
  }

  // Start EEG data streaming
  Future<void> startEEGStreaming() async {
    if (!_isConnected || _dataCharacteristic == null || _isStreaming) return;

    try {
      _addStatus('🎯 Starting EEG data stream...');

      // Enable notifications on data characteristic
      await _dataCharacteristic!.setNotifyValue(true);

// Listen for data stream
      _dataCharacteristic!.value.listen((value) {
        _processNeuroskyData(Uint8List.fromList(value));
      });


      // Send command to start streaming (Neurosky specific command)
      if (_configCharacteristic != null) {
        try {
          // Neurosky command to enable data transmission
          final command = Uint8List.fromList([0x02]); // Enable streaming command
          await _configCharacteristic!.write(command);
          _addStatus('📡 Data streaming enabled');
        } catch (e) {
          _addStatus('⚠️ Config command failed, but data streaming may still work: $e');
        }
      }

      _isStreaming = true;
      _addStatus('✅ EEG Streaming started successfully');

    } catch (e) {
      _addStatus('❌ Failed to start EEG streaming: $e');
      rethrow;
    }
  }

  // Stop EEG data streaming
  Future<void> stopEEGStreaming() async {
    if (!_isStreaming || _dataCharacteristic == null) return;

    try {
      // Disable notifications
      await _dataCharacteristic!.setNotifyValue(false);

      // Send stop command if config characteristic is available
      if (_configCharacteristic != null) {
        try {
          final command = Uint8List.fromList([0x00]); // Disable streaming command
          await _configCharacteristic!.write(command);
        } catch (e) {
          // Ignore config errors when stopping
        }
      }

      _isStreaming = false;
      _eegSamples.clear();
      _dataBuffer.clear();
      _addStatus('⏹️ EEG Streaming stopped');

    } catch (e) {
      _addStatus('Error stopping EEG stream: $e');
    }
  }

  // Process Neurosky data packets
  void _processNeuroskyData(Uint8List data) {
    try {
      _dataBuffer.addAll(data);
      _parseNeuroskyDataChunk(Uint8List.fromList(_dataBuffer));
      if (_dataBuffer.length > 1024) {
        _dataBuffer = _dataBuffer.sublist(_dataBuffer.length - 512);
      }
    } catch (e) {
      _addStatus('Error processing Neurosky data: $e');
    }
  }


  // Parse Neurosky data chunk
  void _parseNeuroskyDataChunk(Uint8List buffer) {
    try {
      // Convert to List<int> for easier manipulation and dynamic removal
      List<int> bufferList = buffer.toList();

      // Look for potential packet start (this is device-specific)
      // Neurosky devices often use 0xAA as packet start byte
      for (int i = 0; i < bufferList.length - 2; i++) {
        if (bufferList[i] == 0xAA && (i == 0 || bufferList[i-1] != 0xAA)) {
          // Potential packet start found
          if (i + 4 < bufferList.length) {
            int payloadLength = bufferList[i + 2];
            int packetLength = 4 + payloadLength; // Header + payload + checksum

            if (i + packetLength <= bufferList.length) {
              // Extract complete packet as Uint8List
              Uint8List packet = Uint8List.fromList(bufferList.sublist(i, i + packetLength));

              // Verify checksum
              if (_verifyChecksum(packet)) {
                _parseNeuroskyPacket(packet);

                // Remove processed packet from buffer
                bufferList.removeRange(i, i + packetLength);
                i = -1; // Restart loop after removal
              }
            }
          }
        }
      }

      // Update the main buffer with the modified list
      _dataBuffer = bufferList;

      // If we have EEG-like data but no clear packet structure, try to extract raw values
      if (_dataBuffer.length >= 10) {
        // ✅ FIXED: Convert List<int> to Uint8List before calling _extractRawEEGValues
        _extractRawEEGValues(Uint8List.fromList(_dataBuffer));

      }
    } catch (e) {
      _addStatus('Error parsing Neurosky data chunk: $e');
    }
  }

  // Verify packet checksum
  bool _verifyChecksum(Uint8List packet) {
    try {
      if (packet.length < 4) return false;

      int calculatedChecksum = 0;
      for (int i = 2; i < packet.length - 1; i++) {
        calculatedChecksum += packet[i];
      }
      calculatedChecksum = ~calculatedChecksum & 0xFF;

      return calculatedChecksum == packet[packet.length - 1];
    } catch (e) {
      return false;
    }
  }

  // Parse Neurosky data packet
  void _parseNeuroskyPacket(Uint8List packet) {
    try {
      if (packet.length < 4) return;

      Map<String, dynamic> neuroskyData = {
        'timestamp': DateTime.now().millisecondsSinceEpoch,
        'rawEeg': [],
        'attention': null,
        'meditation': null,
        'blinkStrength': null,
        'signalQuality': null,
        'delta': null,
        'theta': null,
        'lowAlpha': null,
        'highAlpha': null,
        'lowBeta': null,
        'highBeta': null,
        'lowGamma': null,
        'midGamma': null,
      };

      int payloadLength = packet[2];
      List<int> payload = packet.sublist(3, 3 + payloadLength).toList();

      int i = 0;
      while (i < payload.length) {
        int code = payload[i];
        int dataLength = 1; // Default data length

        // Check for Extended Codes (0x80 or higher) which have an explicit length byte
        if (code >= 0x80) {
          if (i + 1 < payload.length) {
            dataLength = payload[i + 1];
            i++; // Skip the length byte
          } else {
            break; // Malformed
          }
        } else {
          // Standard codes usually have a fixed length
          switch (code) {
            case 0x02: // Poor signal
            case 0x04: // Attention
            case 0x05: // Meditation
            case 0x16: // Blink strength
              dataLength = 1;
              break;
            default:
              dataLength = 1;
          }
        }

        if (i + 1 + dataLength <= payload.length) {
          List<int> data = payload.sublist(i + 1, i + 1 + dataLength);

          switch (code) {
            case 0x02: // Poor signal
              if (data.isNotEmpty) {
                neuroskyData['signalQuality'] = data[0];
              }
              break;

            case 0x04: // Attention
              if (data.isNotEmpty) {
                neuroskyData['attention'] = data[0];
              }
              break;

            case 0x05: // Meditation
              if (data.isNotEmpty) {
                neuroskyData['meditation'] = data[0];
              }
              break;

            case 0x16: // Blink strength
              if (data.isNotEmpty) {
                neuroskyData['blinkStrength'] = data[0];
              }
              break;

            case 0x80: // Raw EEG
              List<double> eegValues = _parseRawEEG(data);
              neuroskyData['rawEeg'] = eegValues;

              // Send to EEG data stream for visualization
              if (eegValues.isNotEmpty) {
                _eegDataController.add(eegValues);
                _eegSamples.add(eegValues);

                // Keep only recent samples
                if (_eegSamples.length > 100) {
                  _eegSamples.removeAt(0);
                }
              }
              break;

            case 0x83: // ASIC EEG POWER (8 bands)
              if (data.length >= 24) { // 8 bands * 3 bytes each
                neuroskyData['delta'] = _parseThreeByteInt(data, 0);
                neuroskyData['theta'] = _parseThreeByteInt(data, 3);
                neuroskyData['lowAlpha'] = _parseThreeByteInt(data, 6);
                neuroskyData['highAlpha'] = _parseThreeByteInt(data, 9);
                neuroskyData['lowBeta'] = _parseThreeByteInt(data, 12);
                neuroskyData['highBeta'] = _parseThreeByteInt(data, 15);
                neuroskyData['lowGamma'] = _parseThreeByteInt(data, 18);
                neuroskyData['midGamma'] = _parseThreeByteInt(data, 21);
              }
              break;
          }
        }

        // Advance past the code and data
        i += 1 + dataLength;
      }

      // Send parsed data to stream
      _neuroskyDataController.add(neuroskyData);

    } catch (e) {
      _addStatus('Error parsing Neurosky packet: $e');
    }
  }

  // Parse three-byte integer for EEG power bands
  int _parseThreeByteInt(List<int> data, int startIndex) {
    if (startIndex + 2 < data.length) {
      return (data[startIndex] << 16) | (data[startIndex + 1] << 8) | data[startIndex + 2];
    }
    return 0;
  }

  // Extract raw EEG values when packet structure is unclear
  void _extractRawEEGValues(Uint8List buffer) {
    try {
      // Try to interpret buffer as raw EEG samples (2-byte signed values)
      List<double> eegValues = [];
      int processedBytes = 0;

      for (int i = 0; i < buffer.length - 1; i += 2) {
        int rawValue = (buffer[i] << 8) | buffer[i + 1];
        // Convert to signed 16-bit
        if (rawValue > 32767) rawValue -= 65536;
        eegValues.add(rawValue.toDouble());
        processedBytes += 2;
      }

      if (eegValues.isNotEmpty) {
        Map<String, dynamic> neuroskyData = {
          'timestamp': DateTime.now().millisecondsSinceEpoch,
          'rawEeg': eegValues,
          'signalQuality': 0, // Unknown
        };

        _neuroskyDataController.add(neuroskyData);
        _eegDataController.add(eegValues);
        _eegSamples.add(eegValues);

        // Keep only recent samples
        if (_eegSamples.length > 100) {
          _eegSamples.removeAt(0);
        }

        // Clear processed data from buffer
        if (processedBytes <= _dataBuffer.length) {
          _dataBuffer.removeRange(0, processedBytes);
        }
      }
    } catch (e) {
      // If extraction fails, clear a small portion of buffer to prevent overflow
      if (_dataBuffer.length > 100) {
        _dataBuffer.removeRange(0, 50);
      }
    }
  }

  // Parse raw EEG data
  List<double> _parseRawEEG(List<int> rawData) {
    try {
      List<double> eegValues = [];

      // Neurosky raw EEG is typically 2-byte signed values
      for (int i = 0; i < rawData.length - 1; i += 2) {
        int value = (rawData[i] << 8) | rawData[i + 1];
        // Convert to signed 16-bit
        if (value > 32767) value -= 65536;
        eegValues.add(value.toDouble());
      }

      return eegValues;
    } catch (e) {
      return [];
    }
  }

  // Get recent EEG samples for prediction
  List<List<double>> getRecentEEGSamples({int count = 10}) {
    if (_eegSamples.isEmpty) return [];
    int startIndex = _eegSamples.length - count;
    if (startIndex < 0) startIndex = 0;
    return _eegSamples.sublist(startIndex);
  }

  // Disconnect from device
  Future<void> disconnectDevice() async {
    try {
      await stopEEGStreaming();
      _connectionSubscription?.cancel();
      _connectionSubscription = null;

      if (_connectedDevice != null) {
        await _connectedDevice!.disconnect();
      }

      _resetState();
      _addStatus('📴 Disconnected from Neurosky device');

    } catch (e) {
      _addStatus('Error disconnecting: $e');
    }
  }

  // Add discovered device (filter for Neurosky)
  void _addDiscoveredDevice(BluetoothDevice device) {
    try {
      // Filter for Neurosky devices (by name or service UUIDs)
      bool isNeurosky = device.platformName.toLowerCase().contains('mindwave') ||
          device.platformName.toLowerCase().contains('neurosky') ||
          device.platformName.toLowerCase().contains('brain') ||
          device.platformName.isEmpty; // Sometimes name is empty but it's Neurosky

      if (isNeurosky && !_discoveredDevices.any((d) => d.remoteId == device.remoteId)) {
        _discoveredDevices.add(device);
        _addStatus('Found Neurosky device: ${device.platformName.isNotEmpty ? device.platformName : "Unknown Neurosky Device"}');
      }
    } catch (e) {
      _addStatus('Error adding discovered device: $e');
    }
  }

  // Add status message
  void _addStatus(String message) {
    print('Neurosky Service: $message');
    _statusController.add('${DateTime.now().toString().split(' ')[1].split('.')[0]} - $message');
  }

  // Reset service state
  void _resetState() {
    _isScanning = false;
    _isConnecting = false;
    _isConnected = false;
    _isStreaming = false;
    _connectedDevice = null;
    _dataCharacteristic = null;
    _configCharacteristic = null;
    _dataBuffer.clear();
    _eegSamples.clear();
    _connectionSubscription?.cancel();
    _connectionSubscription = null;

    _scanningController.add(false);
    _connectingController.add(false);
    _connectedController.add(false);
  }

  // Check Bluetooth availability
  Future<bool> checkBluetoothAvailability() async {
    try {
      bool isAvailable = await FlutterBluePlus.isAvailable;
      bool isOn = await FlutterBluePlus.isOn;
      return isAvailable && isOn;
    } catch (e) {
      return false;
    }
  }

  // Get device information
  Future<Map<String, dynamic>> getDeviceInfo() async {
    if (_connectedDevice == null) {
      return {'error': 'No device connected'};
    }

    try {
      return {
        'name': _connectedDevice!.platformName,
        'id': _connectedDevice!.remoteId.toString(),
        'type': 'Neurosky Mindwave',
        'connected': _isConnected,
        'streaming': _isStreaming,
      };
    } catch (e) {
      return {'error': 'Failed to get device info: $e'};
    }
  }

  // Cleanup
  void dispose() {
    disconnectDevice();
    _resetState();
    _scanSubscription?.cancel();
    _scanSubscription = null;
    _scanningController.close();
    _connectingController.close();
    _connectedController.close();
    _eegDataController.close();
    _neuroskyDataController.close();
    _statusController.close();
  }
}