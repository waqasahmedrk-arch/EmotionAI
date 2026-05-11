// import 'dart:async';
// import 'package:flutter/material.dart';
// import '../services/mindwave_service.dart';
//
// class MindWaveScreen extends StatefulWidget {
//   const MindWaveScreen({super.key});
//
//   @override
//   State<MindWaveScreen> createState() => _MindWaveScreenState();
// }
//
// class _MindWaveScreenState extends State<MindWaveScreen> {
//   Timer? _timer;
//   bool _connected = false;
//   bool _loading = true;
//   String _error = "";
//
//   int attention = 0;
//   int meditation = 0;
//   int alpha = 0;
//   int beta = 0;
//   int theta = 0;
//   String emotion = "Unknown";
//
//   @override
//   void initState() {
//     super.initState();
//     _initializeConnection();
//   }
//
//   Future<void> _initializeConnection() async {
//     try {
//       final success = await MindWaveService.testConnection();
//       if (success) {
//         setState(() {
//           _connected = true;
//           _loading = false;
//         });
//         _startEEGStream();
//       } else {
//         setState(() {
//           _error = "MindWave connection failed";
//           _loading = false;
//         });
//       }
//     } catch (e) {
//       setState(() {
//         _error = e.toString();
//         _loading = false;
//       });
//     }
//   }
//
//   void _startEEGStream() {
//     _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
//       try {
//         final data = await MindWaveService.fetchMindWaveData();
//         if (!mounted) return;
//
//         setState(() {
//           attention = data["attention"] ?? 0;
//           meditation = data["meditation"] ?? 0;
//           alpha = data["alpha"] ?? 0;
//           beta = data["beta"] ?? 0;
//           theta = data["theta"] ?? 0;
//           emotion = data["emotion"] ?? "Unknown";
//         });
//       } catch (_) {}
//     });
//   }
//
//   @override
//   void dispose() {
//     _timer?.cancel();
//     super.dispose();
//   }
//
//   Widget _infoTile(String title, dynamic value) {
//     return Card(
//       child: ListTile(
//         title: Text(title),
//         trailing: Text(
//           value.toString(),
//           style: const TextStyle(
//             fontSize: 18,
//             fontWeight: FontWeight.bold,
//           ),
//         ),
//       ),
//     );
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     if (_loading) {
//       return const Scaffold(
//         body: Center(child: CircularProgressIndicator()),
//       );
//     }
//
//     if (_error.isNotEmpty) {
//       return Scaffold(
//         appBar: AppBar(title: const Text("MindWave EEG")),
//         body: Center(child: Text(_error)),
//       );
//     }
//
//     return Scaffold(
//       appBar: AppBar(
//         title: const Text("MindWave EEG Live Data"),
//         backgroundColor: _connected ? Colors.green : Colors.red,
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(16),
//         children: [
//           _infoTile("Attention", attention),
//           _infoTile("Meditation", meditation),
//           _infoTile("Alpha", alpha),
//           _infoTile("Beta", beta),
//           _infoTile("Theta", theta),
//           _infoTile("Emotion", emotion),
//         ],
//       ),
//     );
//   }
// }