import 'package:flutter_blue_plus/flutter_blue_plus.dart';

class EEGBluetoothService {
  bool isScanning = false;
  bool isConnected = false;

  BluetoothDevice? connectedDevice;
  List<BluetoothDevice> devices = [];

  Future<void> initialize() async {
    // Placeholder
  }

  Future<void> startScan({int timeoutSeconds = 10}) async {
    isScanning = true;
    FlutterBluePlus.startScan(
      timeout: Duration(seconds: timeoutSeconds),
    );

    FlutterBluePlus.scanResults.listen((results) {
      for (var r in results) {
        if (!devices.contains(r.device)) {
          devices.add(r.device);
        }
      }
    });
  }

  Future<void> stopScan() async {
    FlutterBluePlus.stopScan();
    isScanning = false;
  }

  Future<void> connectToDevice(BluetoothDevice device) async {
    await device.connect(autoConnect: false);
    connectedDevice = device;
    isConnected = true;
  }

  Future<void> disconnectDevice() async {
    await connectedDevice?.disconnect();
    connectedDevice = null;
    isConnected = false;
  }

  void dispose() {}
}
