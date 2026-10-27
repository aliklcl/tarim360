import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import 'gelir_model.dart';
import 'islem_model.dart';
import 'sinir_noktasi_model.dart';
import 'tarla_model.dart';

class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('tarla.db');
    return _database!;
  }

  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return openDatabase(
      path,
      version: 13,
      onCreate: _createDB,
      onUpgrade: _upgradeDB,
    );
  }

  Future<void> _createDB(Database db, int version) async {
    await db.execute('''
CREATE TABLE tarlalar(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  remoteId TEXT UNIQUE,
  ad TEXT NOT NULL,
  urun TEXT NOT NULL DEFAULT '',
  alan TEXT NOT NULL DEFAULT '',
  alanMetrekare REAL,
  alanDekar REAL,
  enlem REAL,
  boylam REAL,
  notlar TEXT NOT NULL DEFAULT '',
  fotoBase64 TEXT NOT NULL DEFAULT '',
  silinmisMi INTEGER NOT NULL DEFAULT 0,
  silinmeTarihi TEXT,
  sonSulama TEXT,
  sonGubre TEXT,
  sonIlac TEXT
)
''');

    await db.execute('''
CREATE TABLE islemler(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tarlaId INTEGER NOT NULL,
  tur TEXT NOT NULL,
  tarih TEXT NOT NULL,
  detay TEXT NOT NULL DEFAULT '',
  baslangicZamani TEXT,
  kullaniciAdi TEXT NOT NULL DEFAULT '',
  fotoBase64 TEXT NOT NULL DEFAULT '',
  saat TEXT NOT NULL DEFAULT '',
  maliyet REAL,
  FOREIGN KEY (tarlaId) REFERENCES tarlalar(id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE gelirler(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tarlaId INTEGER NOT NULL,
  tarih TEXT NOT NULL,
  miktar REAL NOT NULL,
  aciklama TEXT NOT NULL DEFAULT '',
  FOREIGN KEY (tarlaId) REFERENCES tarlalar(id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE tarla_sinir_noktalari(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tarlaId INTEGER NOT NULL,
  enlem REAL NOT NULL,
  boylam REAL NOT NULL,
  FOREIGN KEY (tarlaId) REFERENCES tarlalar(id) ON DELETE CASCADE
)
''');

    await db.execute('''
CREATE TABLE yapay_zeka_analizleri(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  soru TEXT NOT NULL,
  yanit TEXT NOT NULL,
  tarih TEXT NOT NULL,
  gorsel_yolu TEXT,
  belirtiler TEXT
)
''');
  }

  Future<void> _upgradeDB(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      await db.execute('ALTER TABLE tarlalar ADD COLUMN sonSulama TEXT');
      await db.execute('ALTER TABLE tarlalar ADD COLUMN sonGubre TEXT');
      await db.execute('ALTER TABLE tarlalar ADD COLUMN sonIlac TEXT');
    }

    if (oldVersion < 3) {
      await db.execute('ALTER TABLE tarlalar ADD COLUMN enlem REAL');
      await db.execute('ALTER TABLE tarlalar ADD COLUMN boylam REAL');
    }

    if (oldVersion < 4) {
      await db.execute('ALTER TABLE islemler ADD COLUMN detay TEXT NOT NULL DEFAULT \'\'');
      await db.execute('UPDATE islemler SET detay = saat WHERE detay = \'\'');
    }

    if (oldVersion < 5) {
      await db.execute('ALTER TABLE islemler ADD COLUMN baslangicZamani TEXT');
      await db.execute('''
CREATE TABLE IF NOT EXISTS tarla_sinir_noktalari(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tarlaId INTEGER NOT NULL,
  enlem REAL NOT NULL,
  boylam REAL NOT NULL,
  FOREIGN KEY (tarlaId) REFERENCES tarlalar(id) ON DELETE CASCADE
)
''');
    }

    if (oldVersion < 6) {
      await db.execute('ALTER TABLE tarlalar ADD COLUMN remoteId TEXT');
    }

    if (oldVersion < 7) {
      await db.execute('ALTER TABLE tarlalar ADD COLUMN alanMetrekare REAL');
      await db.execute('ALTER TABLE tarlalar ADD COLUMN alanDekar REAL');
      await db.execute('ALTER TABLE tarlalar ADD COLUMN notlar TEXT NOT NULL DEFAULT \'\'');
      await db.execute(
        'ALTER TABLE tarlalar ADD COLUMN fotoBase64 TEXT NOT NULL DEFAULT \'\'',
      );
    }

    if (oldVersion < 8) {
      await db.execute(
        'ALTER TABLE tarlalar ADD COLUMN silinmisMi INTEGER NOT NULL DEFAULT 0',
      );
    }

    if (oldVersion < 9) {
      await db.execute('ALTER TABLE tarlalar ADD COLUMN silinmeTarihi TEXT');
    }

    if (oldVersion < 10) {
      await db.execute(
        'ALTER TABLE islemler ADD COLUMN kullaniciAdi TEXT NOT NULL DEFAULT \'\'',
      );
    }

    if (oldVersion < 11) {
      await db.execute(
        'ALTER TABLE islemler ADD COLUMN fotoBase64 TEXT NOT NULL DEFAULT \'\'',
      );
    }

    if (oldVersion < 12) {
      await db.execute('ALTER TABLE islemler ADD COLUMN maliyet REAL');
      await db.execute('''
CREATE TABLE IF NOT EXISTS gelirler(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  tarlaId INTEGER NOT NULL,
  tarih TEXT NOT NULL,
  miktar REAL NOT NULL,
  aciklama TEXT NOT NULL DEFAULT '',
  FOREIGN KEY (tarlaId) REFERENCES tarlalar(id) ON DELETE CASCADE
)
''');
    }

    if (oldVersion < 13) {
      await db.execute('''
CREATE TABLE IF NOT EXISTS yapay_zeka_analizleri(
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  soru TEXT NOT NULL,
  yanit TEXT NOT NULL,
  tarih TEXT NOT NULL,
  gorsel_yolu TEXT,
  belirtiler TEXT
)
''');
    }
  }

  Future<int> tarlaEkle(Tarla tarla) async {
    final db = await database;
    return db.insert('tarlalar', tarla.toMap());
  }

  Future<int> tarlaKaydetVeyaGuncelle(Tarla tarla) async {
    final db = await database;
    if (tarla.remoteId != null) {
      final mevcut = await db.query(
        'tarlalar',
        where: 'remoteId = ?',
        whereArgs: [tarla.remoteId],
        limit: 1,
      );

      if (mevcut.isNotEmpty) {
        final id = mevcut.first['id'] as int;
        await db.update(
          'tarlalar',
          tarla.toMap(),
          where: 'id = ?',
          whereArgs: [id],
        );
        return id;
      }
    }

    return db.insert('tarlalar', tarla.toMap());
  }

  Future<List<Tarla>> tumTarlalar({
    bool sadeceSilinenler = false,
    bool hepsiniGetir = false,
  }) async {
    final db = await database;
    final maps = await db.query(
      'tarlalar',
      where: hepsiniGetir
          ? null
          : (sadeceSilinenler ? 'silinmisMi = 1' : 'silinmisMi = 0'),
      orderBy: 'id DESC',
    );
    return maps.map(Tarla.fromMap).toList();
  }

  Future<int> tarlaSil(int id) async {
    final db = await database;
    return db.update(
      'tarlalar',
      {
        'silinmisMi': 1,
        'silinmeTarihi': DateTime.now().toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<int> tarlaGeriYukle(int id) async {
    final db = await database;
    return db.update(
      'tarlalar',
      {
        'silinmisMi': 0,
        'silinmeTarihi': null,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Tarla>> suresiDolmusSilinenTarlalar(DateTime esik) async {
    final db = await database;
    final maps = await db.query(
      'tarlalar',
      where: 'silinmisMi = 1 AND silinmeTarihi IS NOT NULL AND silinmeTarihi <= ?',
      whereArgs: [esik.toIso8601String()],
      orderBy: 'silinmeTarihi ASC',
    );
    return maps.map(Tarla.fromMap).toList();
  }

  Future<int> tarlaKaliciSil(int id) async {
    final db = await database;
    await db.delete('islemler', where: 'tarlaId = ?', whereArgs: [id]);
    await db.delete('tarla_sinir_noktalari', where: 'tarlaId = ?', whereArgs: [id]);
    await db.delete('gelirler', where: 'tarlaId = ?', whereArgs: [id]);
    return db.delete('tarlalar', where: 'id = ?', whereArgs: [id]);
  }

  Future<int> islemEkle(Islem islem) async {
    final db = await database;
    return db.insert('islemler', islem.toMap());
  }

  Future<int> islemGuncelle(Islem islem) async {
    final db = await database;
    return db.update(
      'islemler',
      islem.toMap(),
      where: 'id = ?',
      whereArgs: [islem.id],
    );
  }

  Future<int> islemSil(int id) async {
    final db = await database;
    return db.delete(
      'islemler',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> tarlaIslemleriniYenile(int tarlaId, List<Islem> islemler) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('islemler', where: 'tarlaId = ?', whereArgs: [tarlaId]);
      for (final islem in islemler) {
        await txn.insert(
          'islemler',
          {
            ...islem.toMap(),
            'tarlaId': tarlaId,
          },
        );
      }
    });
  }

  Future<List<Islem>> tarlaIslemleri(int tarlaId) async {
    final db = await database;
    final maps = await db.query(
      'islemler',
      where: 'tarlaId = ?',
      whereArgs: [tarlaId],
      orderBy: 'id DESC',
    );
    return maps.map(Islem.fromMap).toList();
  }

  Future<void> tarlaSonIslemTarihleriniYenidenHesapla(int tarlaId) async {
    final islemler = await tarlaIslemleri(tarlaId);

    DateTime? sonSulama;
    DateTime? sonGubre;
    DateTime? sonIlac;

    for (final islem in islemler) {
      final zaman = DateTime.tryParse(islem.baslangicZamani ?? '');
      if (zaman == null) continue;

      if (islem.tur == 'Sulama' &&
          (sonSulama == null || zaman.isAfter(sonSulama))) {
        sonSulama = zaman;
      }
      if (islem.tur == 'Gubre' &&
          (sonGubre == null || zaman.isAfter(sonGubre))) {
        sonGubre = zaman;
      }
      if (islem.tur == 'Ilac' &&
          (sonIlac == null || zaman.isAfter(sonIlac))) {
        sonIlac = zaman;
      }
    }

    final db = await database;
    await db.update(
      'tarlalar',
      {
        'sonSulama': sonSulama?.toIso8601String(),
        'sonGubre': sonGubre?.toIso8601String(),
        'sonIlac': sonIlac?.toIso8601String(),
      },
      where: 'id = ?',
      whereArgs: [tarlaId],
    );
  }

  Future<int> tarlaGuncelle(Tarla tarla) async {
    final db = await database;
    return db.update(
      'tarlalar',
      tarla.toMap(),
      where: 'id = ?',
      whereArgs: [tarla.id],
    );
  }

  Future<void> sonIslemTarihiGuncelle(
    int tarlaId, {
    DateTime? sonSulama,
    DateTime? sonGubre,
    DateTime? sonIlac,
  }) async {
    final db = await database;
    final values = <String, dynamic>{};

    if (sonSulama != null) {
      values['sonSulama'] = sonSulama.toIso8601String();
    }
    if (sonGubre != null) {
      values['sonGubre'] = sonGubre.toIso8601String();
    }
    if (sonIlac != null) {
      values['sonIlac'] = sonIlac.toIso8601String();
    }

    if (values.isEmpty) return;

    await db.update(
      'tarlalar',
      values,
      where: 'id = ?',
      whereArgs: [tarlaId],
    );
  }

  Future<void> tumVerileriTemizle() async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete('islemler');
      await txn.delete('tarla_sinir_noktalari');
      await txn.delete('gelirler');
      await txn.delete('tarlalar');
    });
  }

  Future<Tarla?> remoteIdIleTarlaGetir(String remoteId) async {
    final db = await database;
    final sonuc = await db.query(
      'tarlalar',
      where: 'remoteId = ?',
      whereArgs: [remoteId],
      limit: 1,
    );
    if (sonuc.isEmpty) return null;
    return Tarla.fromMap(sonuc.first);
  }

  Future<int?> tarlaIdGetirRemoteId(String remoteId) async {
    final db = await database;
    final sonuc = await db.query(
      'tarlalar',
      columns: ['id'],
      where: 'remoteId = ?',
      whereArgs: [remoteId],
      limit: 1,
    );
    if (sonuc.isEmpty) return null;
    return sonuc.first['id'] as int;
  }

  Future<String?> tarlaRemoteIdGetir(int localId) async {
    final db = await database;
    final sonuc = await db.query(
      'tarlalar',
      columns: ['remoteId'],
      where: 'id = ?',
      whereArgs: [localId],
      limit: 1,
    );
    if (sonuc.isEmpty) return null;
    return sonuc.first['remoteId'] as String?;
  }

  Future<int> sinirNoktasiEkle(SinirNoktasi nokta) async {
    final db = await database;
    return db.insert('tarla_sinir_noktalari', nokta.toMap());
  }

  Future<void> tarlaSinirNoktalariYenile(
    int tarlaId,
    List<SinirNoktasi> noktalar,
  ) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'tarla_sinir_noktalari',
        where: 'tarlaId = ?',
        whereArgs: [tarlaId],
      );
      for (final nokta in noktalar) {
        await txn.insert(
          'tarla_sinir_noktalari',
          {
            ...nokta.toMap(),
            'tarlaId': tarlaId,
          },
        );
      }
    });
  }

  Future<List<SinirNoktasi>> tarlaSinirNoktalari(int tarlaId) async {
    final db = await database;
    final maps = await db.query(
      'tarla_sinir_noktalari',
      where: 'tarlaId = ?',
      whereArgs: [tarlaId],
      orderBy: 'id ASC',
    );
    return maps.map(SinirNoktasi.fromMap).toList();
  }

  Future<void> sinirNoktalariSil(int tarlaId) async {
    final db = await database;
    await db.delete(
      'tarla_sinir_noktalari',
      where: 'tarlaId = ?',
      whereArgs: [tarlaId],
    );
  }

  // --- Gelir Metotları ---
  Future<int> gelirEkle(Gelir gelir) async {
    final db = await database;
    return db.insert('gelirler', gelir.toMap());
  }

  Future<void> tarlaGelirleriniYenile(int tarlaId, List<Gelir> gelirler) async {
    final db = await database;
    await db.transaction((txn) async {
      await txn.delete(
        'gelirler',
        where: 'tarlaId = ?',
        whereArgs: [tarlaId],
      );
      for (final gelir in gelirler) {
        await txn.insert(
          'gelirler',
          {
            ...gelir.toMap(),
            'tarlaId': tarlaId,
          },
        );
      }
    });
  }

  Future<int> gelirGuncelle(Gelir gelir) async {
    final db = await database;
    return db.update(
      'gelirler',
      gelir.toMap(),
      where: 'id = ?',
      whereArgs: [gelir.id],
    );
  }

  Future<int> gelirSil(int id) async {
    final db = await database;
    return db.delete(
      'gelirler',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<List<Gelir>> tarlaGelirleri(int tarlaId) async {
    final db = await database;
    final maps = await db.query(
      'gelirler',
      where: 'tarlaId = ?',
      whereArgs: [tarlaId],
      orderBy: 'tarih DESC, id DESC',
    );
    return maps.map(Gelir.fromMap).toList();
  }

  // --- Yapay Zeka Analizleri Metotları ---
  Future<int> yapayZekaAnaliziEkle(Map<String, dynamic> analiz) async {
    final db = await database;
    return db.insert('yapay_zeka_analizleri', analiz);
  }

  Future<List<Map<String, dynamic>>> tumYapayZekaAnalizleri() async {
    final db = await database;
    return db.query('yapay_zeka_analizleri', orderBy: 'tarih DESC');
  }

  Future<int> yapayZekaAnaliziSil(int id) async {
    final db = await database;
    return db.delete('yapay_zeka_analizleri', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> yapayZekaAnalizleriniTemizle() async {
    final db = await database;
    await db.delete('yapay_zeka_analizleri');
  }
}
