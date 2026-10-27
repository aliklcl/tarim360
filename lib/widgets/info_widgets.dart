
import 'package:flutter/material.dart';


// Fallback for globals

class BilgiSatiri extends StatelessWidget {
  const BilgiSatiri({
    super.key,
    required this.ikon,
    required this.renk,
    required this.metin,
  });

  final IconData ikon;
  final Color renk;
  final String metin;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(ikon, color: renk, size: 20),
        const SizedBox(width: 8),
        Expanded(child: Text(metin)),
      ],
    );
  }
}

class BolumBaslikMetni extends StatelessWidget {
  const BolumBaslikMetni({super.key, 
    required this.baslik,
    required this.aciklama,
  });

  final String baslik;
  final String aciklama;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          baslik,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          aciklama,
          style: TextStyle(
            color: Colors.grey.shade700,
            height: 1.35,
          ),
        ),
      ],
    );
  }
}
