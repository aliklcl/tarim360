import 'package:flutter_test/flutter_test.dart';
import 'package:tarla_takip/islem_model.dart';
import 'package:tarla_takip/sinir_noktasi_model.dart';
import 'package:tarla_takip/tarla_model.dart';

void main() {
  test('Tarla map donusumu konum ve tarih alanlarini korur', () {
    final simdi = DateTime(2026, 3, 17, 21, 30);
    final tarla = Tarla(
      id: 1,
      ad: 'Deneme Tarla',
      urun: 'Bugday',
      alan: '12 donum',
      enlem: 40.12345,
      boylam: 29.98765,
      sonSulama: simdi,
      sonGubre: simdi,
      sonIlac: simdi,
    );

    final sonuc = Tarla.fromMap(tarla.toMap());

    expect(sonuc.id, 1);
    expect(sonuc.ad, 'Deneme Tarla');
    expect(sonuc.urun, 'Bugday');
    expect(sonuc.alan, '12 donum');
    expect(sonuc.enlem, 40.12345);
    expect(sonuc.boylam, 29.98765);
    expect(sonuc.sonSulama, simdi);
    expect(sonuc.sonGubre, simdi);
    expect(sonuc.sonIlac, simdi);
  });

  test('Islem map donusumu detay ve kullanici alanini korur', () {
    final islem = Islem(
      id: 3,
      tarlaId: 1,
      tur: 'Gubre',
      tarih: '17 Mart 2026 21:30',
      detay: 'Kompoze 20-20',
      baslangicZamani: '2026-03-17T21:30:00.000',
      kullaniciAdi: 'Ali',
    );

    final sonuc = Islem.fromMap(islem.toMap());

    expect(sonuc.id, 3);
    expect(sonuc.tarlaId, 1);
    expect(sonuc.tur, 'Gubre');
    expect(sonuc.tarih, '17 Mart 2026 21:30');
    expect(sonuc.detay, 'Kompoze 20-20');
    expect(sonuc.baslangicZamani, '2026-03-17T21:30:00.000');
    expect(sonuc.kullaniciAdi, 'Ali');
  });

  test('Sinir noktasi map donusumu koordinati korur', () {
    final nokta = SinirNoktasi(
      id: 5,
      tarlaId: 1,
      enlem: 40.1001,
      boylam: 29.9001,
    );

    final sonuc = SinirNoktasi.fromMap(nokta.toMap());

    expect(sonuc.id, 5);
    expect(sonuc.tarlaId, 1);
    expect(sonuc.enlem, 40.1001);
    expect(sonuc.boylam, 29.9001);
  });
}
