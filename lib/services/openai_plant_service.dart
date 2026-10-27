import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

class OpenAiServiceException implements Exception {
  OpenAiServiceException({
    required this.message,
    this.code,
    this.statusCode,
  });

  final String message;
  final String? code;
  final int? statusCode;

  @override
  String toString() => message;
}

class OpenAiPlantService {
  OpenAiPlantService._();

  static Future<String> bitkiAnaliziYap({
    required String apiKey,
    required File imageFile,
    required String soru,
  }) async {
    final key = apiKey.trim();
    if (key.isEmpty) {
      throw Exception('OpenAI API anahtari bos olamaz.');
    }

    final bytes = await imageFile.readAsBytes();
    final base64Image = base64Encode(bytes);
    final dataUri = 'data:image/jpeg;base64,$base64Image';

    final istem = <String, dynamic>{
      'model': 'gpt-4.1-mini',
      'temperature': 0.2,
      'messages': [
        {
          'role': 'system',
          'content':
              'Sen tarim odakli bir danismansin. Kullaniciya net, uygulanabilir ve guvenli oneriler ver. Kesin teshis iddiasi kurma. Cevap sonunda "Bu bir on degerlendirmedir." notu ekle.',
        },
        {
          'role': 'user',
          'content': [
            {
              'type': 'text',
              'text':
                  'Foto uzerinden on analiz yap. Soru: $soru. Cevabi su formatta ver: 1) Olasi durumlar 2) Aciliyet seviyesi 3) Hemen yapilacaklar 4) Izleme listesi',
            },
            {
              'type': 'image_url',
              'image_url': {'url': dataUri},
            },
          ],
        },
      ],
    };

    final response = await http
        .post(
          Uri.parse('https://api.openai.com/v1/chat/completions'),
          headers: {
            HttpHeaders.authorizationHeader: 'Bearer $key',
            HttpHeaders.contentTypeHeader: 'application/json',
          },
          body: jsonEncode(istem),
        )
        .timeout(const Duration(seconds: 60));

    if (response.statusCode < 200 || response.statusCode >= 300) {
      String? code;
      var message = 'OpenAI hatasi olustu.';
      try {
        final errMap = jsonDecode(response.body) as Map<String, dynamic>;
        final err = errMap['error'] as Map<String, dynamic>?;
        code = err?['code']?.toString();
        message = err?['message']?.toString() ?? message;
      } catch (_) {}
      throw OpenAiServiceException(
        message: message,
        code: code,
        statusCode: response.statusCode,
      );
    }

    final map = jsonDecode(response.body) as Map<String, dynamic>;
    final choices = map['choices'];
    if (choices is! List || choices.isEmpty) {
      throw Exception('OpenAI yaniti bos geldi.');
    }

    final message = choices.first['message'] as Map<String, dynamic>?;
    final content = message?['content']?.toString().trim() ?? '';
    if (content.isEmpty) {
      throw OpenAiServiceException(message: 'OpenAI yaniti bos geldi.');
    }
    return content;
  }
}
