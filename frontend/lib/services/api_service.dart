import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../backend_contract.dart';

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  // --- Network Connection Configuration Options ---
  // Option A (Production): Google Cloud Run URL
  static const String optionA_productionUrl =
      'https://snapcity-api-61109416596.us-central1.run.app';
  // Option B (LDPlayer Local Network Host IP):
  static const String optionB_ldPlayerLocalUrl = 'http://192.168.0.104:8000';
  // Option C (Standard Android Emulator Default):
  static const String optionC_emulatorDefaultUrl = 'http://10.0.2.2:8000';

  // Active configuration runtime variable - Toggle this instantly for local testing!
  static const String activeBaseUrl =
      optionA_productionUrl; // Set to optionC_emulatorDefaultUrl for emulator testing!

  bool _isSupabaseInitialized = false;

  /// Initialize Supabase with robust fallback if URL or AnonKey are empty or invalid
  Future<void> initializeSupabase(
      {required String url, required String anonKey}) async {
    try {
      if (url.isEmpty || anonKey.isEmpty) {
        print(
            '⚠️ Supabase credentials missing. Operating in local Mock Storage mode.');
        return;
      }
      await Supabase.initialize(url: url, anonKey: anonKey);
      _isSupabaseInitialized = true;
      print('🚀 Supabase Initialized Successfully');
    } catch (e) {
      print('❌ Supabase Init Error: $e. Falling back to mock.');
    }
  }

  /// Uploads a captured civic image file to Supabase storage bucket.
  /// Throws an exception if upload fails to prevent stock photo fallbacks.
  Future<String> uploadImageToSupabase(String localPath) async {
    if (!_isSupabaseInitialized) {
      throw Exception(
          'Supabase not initialized. Please check your configuration.');
    }

    try {
      final file = File(localPath);
      if (!await file.exists()) {
        throw Exception('Image file not found on device: $localPath');
      }

      final fileName = 'report_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final path =
          '$fileName'; // Upload directly to bucket root or specific folder

      print('📡 Uploading image to Supabase bucket "uploads": $path...');

      // Target the 'uploads' bucket specifically as requested
      // Clean upload call without conflicting session headers for anonymous public writes
      await Supabase.instance.client.storage.from('uploads').upload(
            path,
            file,
            fileOptions: const FileOptions(
              cacheControl: '3600',
              upsert: false,
              contentType: 'image/jpeg',
            ),
          );

      final imageUrl =
          Supabase.instance.client.storage.from('uploads').getPublicUrl(path);

      print('📸 Image verified on Supabase: $imageUrl');
      return imageUrl;
    } catch (e) {
      print('❌ Supabase Upload Error: $e');
      throw Exception('Failed to upload image to cloud storage: $e');
    }
  }

  /// Primary multi-modal report submission function combining upload and API POST.
  Future<AgentReportResponse> submitCivicReport({
    required String reportId,
    required String localImagePath,
    required double lat,
    required double lng,
    required String voiceNoteTranscript,
    String? locationName,
  }) async {
    // Step A: Upload image to Supabase
    // Ensure the asynchronous Supabase bucket upload completes perfectly first
    final imageUrl = await uploadImageToSupabase(localImagePath);

    // Step B: Construct payload using contract
    // Bind live device coordinates directly into the outbound report payload
    final requestPayload = ReportRequest(
      reportId: reportId,
      imageUrl: imageUrl,
      lat: lat,
      lng: lng,
      voiceNoteTranscript: voiceNoteTranscript,
      locationName: locationName,
    );

    final payloadJson = requestPayload.toJson();

    // Step C: POST JSON payload to backend server
    http.Response response;

    try {
      final requestUrl = '$activeBaseUrl/api/v1/report';
      print('🚨 DEBUG API CALL: Requesting URL -> $requestUrl');
      print('📡 Sending report $reportId to backend API: $activeBaseUrl...');
      print('📦 Payload: ${jsonEncode(payloadJson)}');

      response = await http
          .post(
            Uri.parse(requestUrl),
            headers: {
              'Content-Type': 'application/json',
              'Accept': 'application/json',
            },
            body: jsonEncode(payloadJson),
          )
          .timeout(
              const Duration(seconds: 60)); // Increased for AI Agent Cold Start
    } on SocketException {
      throw Exception(
          'Network Error: Please check your internet connection and try again.');
    } on TimeoutException {
      throw Exception(
          'The AI Swarm is taking longer than expected to process this complex report (Cloud Run Cold Start). Please wait a moment and try again.');
    } catch (e) {
      // ... existing fallback logic ...
      throw Exception('Backend communication error: $e');
    }

    // Step D: Trap any HTTP 400 validation responses and raise explicit error
    if (response.statusCode == 400) {
      print('❌ Backend rejected image: ${response.body}');
      throw Exception(
          'Invalid Image: Please upload a clear photo of the civic issue.');
    } else if (response.statusCode != 200) {
      final body = jsonDecode(response.body);
      final errMsg = body['detail'] ?? 'Orchestration Failed';
      throw Exception('Server Error (${response.statusCode}): $errMsg');
    }

    // Success response parsing
    final Map<String, dynamic> responseJson = jsonDecode(response.body);
    print('🎉 Incident $reportId fully orchestrated by Swarm agents!');
    return AgentReportResponse.fromJson(responseJson);
  }

  Future<List<AgentReportResponse>> fetchGlobalCases() async {
    try {
      final requestUrl = '$activeBaseUrl/api/v1/cases';
      print('📡 Fetching global cases from: $requestUrl');

      final response = await http
          .get(
            Uri.parse(requestUrl),
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () =>
                throw Exception('API request timed out after 30 seconds'),
          );

      print('📊 API Response Status: ${response.statusCode}');

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final List cases = data['cases'] ?? [];
        print('✅ Successfully fetched ${cases.length} cases from API');
        return cases.map((c) => AgentReportResponse.fromJson(c)).toList();
      } else if (response.statusCode == 404) {
        throw Exception(
            'Cases endpoint not found (404). Check API URL: $requestUrl');
      } else if (response.statusCode >= 500) {
        throw Exception(
            'Server Error (${response.statusCode}): ${response.body}');
      } else {
        throw Exception('HTTP ${response.statusCode}: ${response.body}');
      }
    } on SocketException catch (e) {
      throw Exception(
          'Network Error: ${e.message}. Check internet connection.');
    } on TimeoutException catch (e) {
      throw Exception('Request timeout: ${e.message}');
    } catch (e) {
      print('❌ Error fetching global cases: $e');
      rethrow;
    }
  }
}
