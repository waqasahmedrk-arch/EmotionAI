// import 'dart:convert';
// import 'package:http/http.dart' as http;
//
// class MindWaveService {
//   static const String baseUrl =
//       "https://furfuraceously-unmaterial-anh.ngrok-free.dev";
//
//   static Future<bool> testConnection() async {
//     final response =
//     await http.get(Uri.parse("$baseUrl/connection_test"));
//
//     if (response.statusCode == 200) {
//       final data = json.decode(response.body);
//       return data["status"] == "success";
//     } else {
//       throw Exception("Connection test failed");
//     }
//   }
//
//   static Future<Map<String, dynamic>> fetchMindWaveData() async {
//     final response =
//     await http.get(Uri.parse("$baseUrl/mindwave_data"));
//
//     if (response.statusCode == 200) {
//       return json.decode(response.body);
//     } else {
//       throw Exception("Failed to fetch EEG data");
//     }
//   }
// }