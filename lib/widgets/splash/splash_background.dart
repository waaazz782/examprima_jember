import 'package:flutter/material.dart';

/// Background splash screen: foto sekolah full-screen (BoxFit.cover)
/// dengan overlay gradient biru-putih yang sangat halus dan bertahap,
/// sehingga foto terasa menyatu sebagai satu background — bukan
/// "ditempel" sebagai kotak terpisah di bawah layar.
///
/// Susunan:
/// 1. Foto asli, sedikit dikurangi saturasi & kontrasnya (subtle, foto
///    tetap jelas, tidak digelapkan) supaya tidak bersaing dengan UI.
/// 2. Gradient atas: biru-putih sangat transparan di puncak, memudar
///    panjang menuju transparan penuh di area tengah — inilah yang
///    membuat logo/ExamPrima/tagline tetap terbaca tanpa membuat garis
///    batas dengan foto.
/// 3. Gradient bawah: overlay biru/putih sangat tipis agar foto tetap
///    senada dengan tema biru aplikasi, tanpa membuatnya pudar/abu-abu.
class SplashBackground extends StatelessWidget {
  const SplashBackground({super.key});

  // Matriks warna untuk sedikit mengurangi saturasi (~12%) — warna asli
  // foto (langit biru, gedung oranye, pohon hijau) tetap terlihat natural,
  // hanya sedikit dilembutkan.
  static const List<double> _desaturateMatrix = [
    0.9159, 0.0704, 0.0137, 0, 0,
    0.0359, 0.9504, 0.0137, 0, 0,
    0.0359, 0.0704, 0.8937, 0, 0,
    0, 0, 0, 1, 0,
  ];

  // Matriks untuk sedikit mengurangi kontras + sedikit menaikkan
  // brightness (foto jangan sampai gelap).
  static const List<double> _contrastBrightnessMatrix = [
    0.94, 0, 0, 0, 20,
    0, 0.94, 0, 0, 20,
    0, 0, 0.94, 0, 20,
    0, 0, 0, 1, 0,
  ];

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // ---------- Foto sekolah, full-screen ----------
        ColorFiltered(
          colorFilter: const ColorFilter.matrix(_contrastBrightnessMatrix),
          child: ColorFiltered(
            colorFilter: const ColorFilter.matrix(_desaturateMatrix),
            child: Image.asset(
              'assets/images/bg_sekolah.jpg',
              fit: BoxFit.cover,
              alignment: Alignment.bottomCenter,
            ),
          ),
        ),

        // ---------- Gradient atas: panjang & bertahap, bukan blok solid ----------
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xEBEAF7FF), // ~92% - puncak, area dots & logo
                Color(0xB8D9F0FF), // ~72% - area logo/ExamPrima
                Color(0x66BFE5FF), // ~40% - area tagline
                Color(0x22BFE5FF), // ~13% - mulai memudar
                Colors.transparent, // foto terlihat jelas
              ],
              stops: [0.0, 0.20, 0.38, 0.52, 0.66],
            ),
          ),
        ),

        // ---------- Gradient bawah: sentuhan biru sangat tipis ----------
        const DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Colors.transparent,
                Color(0x14E8F4FF), // ~8%, hanya penyatu warna
              ],
              stops: [0.72, 1.0],
            ),
          ),
        ),
      ],
    );
  }
}
