import 'dart:convert';

import 'package:http/http.dart' as http;

class TarlaHavaDurumu {
  const TarlaHavaDurumu({
    required this.sicaklik,
    required this.hissedilen,
    required this.nem,
    required this.ruzgar,
    required this.aciklama,
    required this.gunlukMin,
    required this.gunlukMax,
    required this.yagisOlasiligi,
    required this.mgmDetayUrl,
    required this.mgmEtiketi,
  });

  final double sicaklik;
  final double hissedilen;
  final int nem;
  final double ruzgar;
  final String aciklama;
  final double gunlukMin;
  final double gunlukMax;
  final int yagisOlasiligi;
  final String mgmDetayUrl;
  final String mgmEtiketi;
}

class WeatherService {
  static const Duration _agTimeout = Duration(seconds: 12);

  static Future<TarlaHavaDurumu> havaDurumuGetir({
    required double enlem,
    required double boylam,
  }) async {
    final uri = Uri.https(
      'api.open-meteo.com',
      '/v1/forecast',
      {
        'latitude': enlem.toString(),
        'longitude': boylam.toString(),
        'current':
            'temperature_2m,apparent_temperature,relative_humidity_2m,weather_code,wind_speed_10m',
        'daily':
            'temperature_2m_max,temperature_2m_min,precipitation_probability_max',
        'timezone': 'auto',
        'forecast_days': '1',
      },
    );

    final response = await http.get(uri).timeout(_agTimeout);
    if (response.statusCode != 200) {
      throw Exception('Hava durumu servisine ulasilamadi');
    }

    final mgmBilgisi = await _mgmKonumBilgisiGetir(
      enlem: enlem,
      boylam: boylam,
    );
    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final current = json['current'] as Map<String, dynamic>? ?? {};
    final daily = json['daily'] as Map<String, dynamic>? ?? {};

    return TarlaHavaDurumu(
      sicaklik: (current['temperature_2m'] as num?)?.toDouble() ?? 0,
      hissedilen: (current['apparent_temperature'] as num?)?.toDouble() ?? 0,
      nem: (current['relative_humidity_2m'] as num?)?.toInt() ?? 0,
      ruzgar: (current['wind_speed_10m'] as num?)?.toDouble() ?? 0,
      aciklama: _havaKoduMetni((current['weather_code'] as num?)?.toInt() ?? 0),
      gunlukMin: _listedekiIlkSayiyiAl(daily['temperature_2m_min'])?.toDouble() ?? 0,
      gunlukMax: _listedekiIlkSayiyiAl(daily['temperature_2m_max'])?.toDouble() ?? 0,
      yagisOlasiligi:
          _listedekiIlkSayiyiAl(daily['precipitation_probability_max'])?.toInt() ?? 0,
      mgmDetayUrl: mgmBilgisi.url,
      mgmEtiketi: mgmBilgisi.etiket,
    );
  }

  static Future<_MgmKonumBilgisi> _mgmKonumBilgisiGetir({
    required double enlem,
    required double boylam,
  }) async {
    final uri = Uri.https(
      'nominatim.openstreetmap.org',
      '/reverse',
      {
        'lat': enlem.toString(),
        'lon': boylam.toString(),
        'format': 'jsonv2',
        'accept-language': 'tr',
        'zoom': '10',
      },
    );

    try {
      final response = await http
          .get(
            uri,
            headers: const {'User-Agent': 'tarla_takip/1.0'},
          )
          .timeout(_agTimeout);
      if (response.statusCode != 200) {
        return const _MgmKonumBilgisi(
          url: 'https://www.mgm.gov.tr/tahmin/il-ve-ilceler.aspx',
          etiket: 'MGM detay',
        );
      }

      final json = jsonDecode(response.body) as Map<String, dynamic>;
      final adres = json['address'] as Map<String, dynamic>? ?? {};
      final il = _adresAl(adres, ['city', 'province', 'state']);
      final ilce = _adresAl(
        adres,
        ['town', 'municipality', 'county', 'state_district'],
      );

      final query = <String, String>{};
      final etiketParcalari = <String>[];
      if (il.isNotEmpty) {
        query['il'] = il;
        etiketParcalari.add(il);
      }
      if (ilce.isNotEmpty) {
        query['ilce'] = ilce;
        etiketParcalari.insert(0, ilce);
      }

      if (query.isEmpty) {
        return const _MgmKonumBilgisi(
          url: 'https://www.mgm.gov.tr/tahmin/il-ve-ilceler.aspx',
          etiket: 'MGM detay',
        );
      }

      final mgmUrl = Uri.https(
        'www.mgm.gov.tr',
        '/tahmin/il-ve-ilceler.aspx',
        query,
      ).toString();

      return _MgmKonumBilgisi(
        url: mgmUrl,
        etiket: etiketParcalari.join(' / '),
      );
    } catch (_) {
      return const _MgmKonumBilgisi(
        url: 'https://www.mgm.gov.tr/tahmin/il-ve-ilceler.aspx',
        etiket: 'MGM detay',
      );
    }
  }

  static String _adresAl(Map<String, dynamic> adres, List<String> anahtarlar) {
    for (final anahtar in anahtarlar) {
      final deger = adres[anahtar];
      if (deger is String && deger.trim().isNotEmpty) {
        return deger.trim();
      }
    }
    return '';
  }

  static num? _listedekiIlkSayiyiAl(dynamic value) {
    if (value is List && value.isNotEmpty && value.first is num) {
      return value.first as num;
    }
    return null;
  }

  static String _havaKoduMetni(int kod) {
    switch (kod) {
      case 0:
        return 'A\u00e7\u0131k';
      case 1:
      case 2:
      case 3:
        return 'Par\u00e7al\u0131 bulutlu';
      case 45:
      case 48:
        return 'Sisli';
      case 51:
      case 53:
      case 55:
      case 56:
      case 57:
        return '\u00c7isenti';
      case 61:
      case 63:
      case 65:
      case 66:
      case 67:
        return 'Ya\u011fmurlu';
      case 71:
      case 73:
      case 75:
      case 77:
        return 'Kar';
      case 80:
      case 81:
      case 82:
        return 'Sa\u011fanak';
      case 95:
      case 96:
      case 99:
        return 'F\u0131rt\u0131na';
      default:
        return 'De\u011fi\u015fken';
    }
  }
}

class _MgmKonumBilgisi {
  const _MgmKonumBilgisi({
    required this.url,
    required this.etiket,
  });

  final String url;
  final String etiket;
}
