import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:image/image.dart' as img;
import '../app_session_service.dart';

/// Groq API üzerinden bitki hastalığı analizi yapar.
/// API anahtarı: console.groq.com adresinden ücretsiz alınır (gsk_... ile başlar)
class GeminiService {
  GeminiService._();

  static const String _groqEndpoint =
      'https://api.groq.com/openai/v1/chat/completions';
  static const String _model = 'meta-llama/llama-4-scout-17b-16e-instruct';

  static Future<String> analizEt({
    required String soru,
    required List<String> seciliBelirtiler,
    File? gorsel,
  }) async {
    final apiKey = await AppSessionService.geminiApiAnahtariniGetir();
    if (apiKey == null || apiKey.isEmpty) {
      throw Exception(
        'API anahtarı bulunamadı.\n'
        'Ayarlar → AI Analiz Ayarları bölümünden Groq API anahtarınızı girin.\n'
        '(console.groq.com adresinden ücretsiz alabilirsiniz)',
      );
    }

    // Görsel sıkıştırma: max 640x640 px, %80 JPEG kalitesi
    String? base64Image;
    if (gorsel != null && await gorsel.exists()) {
      final rawBytes = await gorsel.readAsBytes();
      try {
        final decoded = img.decodeImage(rawBytes);
        if (decoded != null) {
          final resized = img.copyResize(
            decoded,
            width: decoded.width > decoded.height
                ? (decoded.width > 640 ? 640 : decoded.width)
                : -1,
            height: decoded.width <= decoded.height
                ? (decoded.height > 640 ? 640 : decoded.height)
                : -1,
            interpolation: img.Interpolation.linear,
          );
          base64Image = base64Encode(img.encodeJpg(resized, quality: 80));
        } else {
          base64Image = base64Encode(rawBytes);
        }
      } catch (_) {
        base64Image = base64Encode(rawBytes);
      }
    }

    const systemPrompt = '''
Sen "Filiz" adlı uzman bir ziraat mühendisi ve bitki patoloğusun.

ADIM 1 - FOTOĞRAF DOĞRULAMA (önce bunu yap):
Fotoğrafta bir bitki, yaprak, ürün, ekin, tarla veya tarımsal materyal var mı?
- HAYIR ise: Sadece şunu yaz ve dur:
  "❌ Görselde bitki tespit edilemedi. Lütfen analiz etmek istediğiniz bitkinin fotoğrafını gönderin. (İnsan, hayvan, bina vb. görseller analiz edilememektedir.)"

ADIM 2 - BİTKİ ANALİZİ (sadece bitki fotoğrafı ise devam et):
Türkçe, kısa ve net bir rapor hazırla:

**🔬 Filiz'in Teşhisi**
**Bitki Türü:** [Tespit edilen bitki - örn: Domates, Buğday, Bilinmiyor]
**Hastalık/Sorun:** [Spesifik isim - örn: "Septoria Yaprak Lekesi", "Demir Klorozu", "Sağlıklı görünüyor"]
**Etken:** [Mantar / Bakteri / Virüs / Besin eksikliği / Zararlı / Çevre stresi / Yok]
**Güven:** [%oran] - [1 cümle gerekçe]

**⚠️ Aciliyet:** [Düşük / Orta / Yüksek / Yok]
[1 cümle neden]

**💊 Tedavi Planı**
- **Hemen (0-24 saat):** [Eylem veya "Gerekmiyor"]
- **2-7 Gün:** [Spesifik ürün/aktif madde veya "Gerekmiyor"]  
- **Önlem:** [1 öneri]

**👁️ 48 Saat Takip:** [Neye dikkat edilmeli]

⚠️ *Bu değerlendirme ön teşhistir. Kesin tanı için bölgenizdeki ziraat mühendisine başvurunuz.*
''';

    final userText =
        'Soru: "$soru"\nBelirtiler: ${seciliBelirtiler.isNotEmpty ? seciliBelirtiler.join(', ') : "Belirtilmedi"}';

    final List<Map<String, dynamic>> userContentParts;
    if (base64Image != null) {
      userContentParts = [
        {'type': 'text', 'text': userText},
        {
          'type': 'image_url',
          'image_url': {'url': 'data:image/jpeg;base64,$base64Image'},
        },
      ];
    } else {
      userContentParts = [
        {'type': 'text', 'text': userText},
      ];
    }

    final requestBody = {
      'model': _model,
      'messages': [
        {'role': 'system', 'content': systemPrompt},
        {'role': 'user', 'content': userContentParts},
      ],
      'max_tokens': 1000,
      'temperature': 0.1,
    };

    try {
      final response = await http.post(
        Uri.parse(_groqEndpoint),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $apiKey',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 60), onTimeout: () {
        throw Exception('Bağlantı zaman aşımına uğradı. İnternet bağlantınızı kontrol edin.');
      });

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body) as Map<String, dynamic>;
        final choices = json['choices'] as List;
        if (choices.isEmpty) {
          return 'Yapay zeka yanıt veremedi (boş yanıt).';
        }
        final message = choices.first['message'] as Map<String, dynamic>;
        return (message['content'] as String).trim();
      } else if (response.statusCode == 401) {
        throw Exception(
          'API anahtarı geçersiz.\n'
          'Ayarlar → AI Analiz Ayarları → Groq anahtarını kontrol edin.\n'
          '(console.groq.com → gsk_... ile başlayan anahtar)',
        );
      } else if (response.statusCode == 429) {
        throw Exception('Groq API şu an yoğun. Birkaç saniye bekleyip tekrar deneyin.');
      } else {
        String? errMsg;
        try {
          errMsg = (jsonDecode(response.body)['error']['message'] as String?);
        } catch (_) {}
        throw Exception(
          'Groq API Hatası (${response.statusCode}): ${errMsg ?? response.body.substring(0, response.body.length.clamp(0, 300))}',
        );
      }
    } on Exception catch (e) {
      final s = e.toString();
      if (s.contains('Bağlantı') || s.contains('API anahtarı') || s.contains('Groq API')) {
        rethrow;
      }
      throw Exception('Analiz hatası: $s');
    }
  }
}
