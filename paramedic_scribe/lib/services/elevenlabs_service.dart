import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class ElevenLabsService {
  static const String _baseUrl = 'http://localhost:8080';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> get _apiKey => _storage.read(key: 'elevenlabs_api_key');

  Future<void> setApiKey(String key) async {
    await _storage.write(key: 'elevenlabs_api_key', value: key);
  }

  /// Transcribe audio bytes to text using ElevenLabs speech-to-text
  Future<String?> transcribeAudio(Uint8List audioBytes) async {
    final apiKey = await _apiKey;
    if (apiKey == null) return null;

    try {
      final request = http.MultipartRequest(
        'POST',
        Uri.parse('$_baseUrl/transcribe'),
      );
      request.headers['xi-api-key'] = apiKey;
      request.files.add(http.MultipartFile.fromBytes(
        'file',
        audioBytes,
        filename: 'recording.wav',
      ));
      request.fields['model_id'] = 'scribe_v1';

      final response = await request.send();
      if (response.statusCode == 200) {
        final body = await response.stream.bytesToString();
        final data = jsonDecode(body);
        return data['text'] as String?;
      }
    } catch (e) {
      // Silently fail
    }
    return null;
  }
}
