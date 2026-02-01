import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../models/report_model.dart';

class ClaudeService {
  static const String _baseUrl = 'http://localhost:8080/claude';
  final FlutterSecureStorage _storage = const FlutterSecureStorage();

  Future<String?> get _apiKey => _storage.read(key: 'claude_api_key');

  Future<void> setApiKey(String key) async {
    await _storage.write(key: 'claude_api_key', value: key);
  }

  Future<Map<String, dynamic>?> extractFormData(
    String freeText,
    List<FormSection> sections,
  ) async {
    final apiKey = await _apiKey;
    if (apiKey == null) {
      throw Exception('Claude API key not set. Go to Settings to add it.');
    }

    final fieldDescriptions = sections
        .expand((s) => s.fields)
        .map((f) => '- ${f.id} (${f.type.name}): ${f.label}')
        .join('\n');

    final prompt =
        '''You are a medical data extraction assistant. Given the following free-text paramedic report, extract structured data for these form fields.

Available fields:
$fieldDescriptions

Free-text report:
$freeText

Return ONLY a JSON object mapping field IDs to their values. For tick fields, use true/false. For number fields, use numbers. For text fields, use strings. Only include fields that have clear values in the text. Do not guess or fabricate data.''';

    try {
      final response = await http.post(
        Uri.parse(_baseUrl),
        headers: {
          'Content-Type': 'application/json',
          'x-api-key': apiKey,
          'anthropic-version': '2023-06-01',
        },
        body: jsonEncode({
          'model': 'claude-sonnet-4-20250514',
          'max_tokens': 2048,
          'messages': [
            {'role': 'user', 'content': prompt},
          ],
        }),
      );

      if (response.statusCode != 200) {
        throw Exception('AI service error (${response.statusCode}): ${response.body}');
      }

      final data = jsonDecode(response.body);
      final text = data['content'][0]['text'] as String;
      // Extract JSON from response
      final jsonMatch = RegExp(r'\{[\s\S]*\}').firstMatch(text);
      if (jsonMatch != null) {
        return jsonDecode(jsonMatch.group(0)!) as Map<String, dynamic>;
      }
      throw Exception('Could not parse AI response');
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }
      throw Exception('Network error - check your connection');
    }
  }
}
