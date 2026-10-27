
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';


// Fallback for globals

class QrKodTarayiciSayfasi extends StatefulWidget {
  const QrKodTarayiciSayfasi({super.key});

  @override
  State<QrKodTarayiciSayfasi> createState() => _QrKodTarayiciSayfasiState();
}

class _QrKodTarayiciSayfasiState extends State<QrKodTarayiciSayfasi> {
  bool _okundu = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('QR kod tara')),
      body: MobileScanner(
        onDetect: (capture) {
          if (_okundu) return;
          final kod = capture.barcodes.firstOrNull?.rawValue?.trim();
          if (kod == null || kod.isEmpty) return;
          _okundu = true;
          if (!mounted) return;
          Navigator.of(context).pop(kod);
        },
      ),
    );
  }
}