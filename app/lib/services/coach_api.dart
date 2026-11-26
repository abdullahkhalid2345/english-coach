import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../config.dart';
import '../models/analysis_result.dart';

/// A problem talking to the backend. [message] is friendly and safe to show.
class CoachApiException implements Exception {
  final String message;
  CoachApiException(this.message);

  @override
  String toString() => message;
}

/// Talks to the FastAPI backend.
class CoachApi {
  /// Sends the recording to POST /analyze and returns the coach's feedback.
  /// Throws [CoachApiException] with a friendly message if anything goes wrong.
  Future<AnalysisResult> analyze(String audioFilePath) async {
    // Remove a trailing "/" from the address, if there is one, then add /analyze.
    final baseUrl = backendUrl.endsWith('/')
        ? backendUrl.substring(0, backendUrl.length - 1)
        : backendUrl;
    final url = Uri.parse('$baseUrl/analyze');

    // A "multipart" request is how files are uploaded over http.
    // The backend expects the file in a field called "audio".
    final request = http.MultipartRequest('POST', url);
    request.files.add(
      await http.MultipartFile.fromPath('audio', audioFilePath, filename: 'recording.m4a'),
    );

    final http.Response response;
    try {
      final streamed = await request.send().timeout(requestTimeout);
      response = await http.Response.fromStream(streamed).timeout(requestTimeout);
    } on TimeoutException {
      throw CoachApiException(
        'Your coach took too long to answer. Please check your connection and try again.',
      );
    } on SocketException {
      throw CoachApiException(
        "Can't reach your coach.\n\n"
        '• Is the backend running on your laptop (with --host 0.0.0.0)?\n'
        '• Are your phone and laptop on the same Wi-Fi?\n'
        '• Is the address in lib/config.dart correct? (now: $backendUrl)',
      );
    } on http.ClientException {
      throw CoachApiException(
        "Can't reach your coach. Check that the backend is running and the address in "
        'lib/config.dart is correct (now: $backendUrl).',
      );
    }

    // Read the JSON answer.
    Map<String, dynamic> json;
    try {
      json = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
    } catch (_) {
      throw CoachApiException(
        'Your coach sent an answer the app could not understand (status ${response.statusCode}).',
      );
    }

    // The backend puts a clear error message in "detail" when something fails.
    if (response.statusCode != 200) {
      final detail = json['detail'];
      throw CoachApiException(
        detail is String ? detail : 'Something went wrong (status ${response.statusCode}).',
      );
    }

    return AnalysisResult.fromJson(json);
  }
}
