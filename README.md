# ExamPrima — Halaman Syarat Ujian + Pemeriksaan Keamanan

Splash Screen → **pemeriksaan aplikasi AI terlarang (wajib)** →
halaman Syarat Ujian, untuk aplikasi Android ExamPrima, dibuat
mengikuti mockup referensi.

## ⚠️ Langkah WAJIB sebelum menjalankan: setup AndroidManifest.xml

Project ini dikirim sebagai `lib/` + `assets/` + `pubspec.yaml` saja
(tanpa folder `android/`), jadi drop ke project Flutter Anda yang
sudah ada (`flutter create`), lalu tambahkan blok berikut ke
`android/app/src/main/AndroidManifest.xml`, **di dalam tag
`<manifest>`, sejajar dengan `<application>`** (bukan di dalamnya):

```xml
<queries>
    <package android:name="com.openai.chatgpt" />
    <package android:name="com.google.android.apps.bard" />
    <package android:name="com.microsoft.copilot" />
    <package android:name="com.deepseek.chat" />
    <package android:name="ai.perplexity.app.android" />
    <package android:name="com.anthropic.claude" />
</queries>
```

Tanpa blok `<queries>` ini, Android (11+) akan menyembunyikan info
aplikasi-aplikasi tersebut dari plugin `appcheck` walaupun benar-benar
terpasang di perangkat (package visibility restriction) — hasil
pengecekan jadi selalu "tidak ditemukan" meski sebenarnya ada. Kalau
Anda menambah/mengurangi aplikasi di
`lib/constants/forbidden_ai_apps.dart`, package name-nya juga harus
disinkronkan di sini.

## Cara menjalankan

```bash
flutter pub get
flutter run
```

Pastikan device/emulator dapat mengakses `http://10.10.2.2` (alamat
website ujian) saat tombol "Saya Mengerti, Mulai Ujian" ditekan.

## Struktur proyek

```
lib/
├── main.dart                   # Home: SplashScreen
├── constants/
│   ├── app_colors.dart         # Warna & spacing (sesuai palet mockup)
│   └── forbidden_ai_apps.dart  # Daftar aplikasi AI terlarang (DAPAT DIKONFIGURASI)
├── services/
│   └── ai_app_checker_service.dart  # Wrapper plugin `appcheck`
├── utils/
│   └── design_scale.dart       # Konversi baseline 360x740dp -> layar asli
├── pages/
│   ├── splash_screen.dart      # Splash Screen (halaman pembuka)
│   └── exam_requirement_page.dart   # Dibungkus SecurityCheckGate
└── widgets/
    ├── exam_header.dart        # Header kustom (bukan AppBar bawaan)
    ├── requirement_hero.dart   # Badge, judul "Syarat Ujian", ilustrasi
    ├── exam_type_card.dart     # Card gradient "Ujian Produktif"
    ├── rules_card.dart         # Card "Ketentuan Ujian" (6 poin)
    ├── agreement_card.dart     # Card "Sebelum Mulai" + custom checkbox
    ├── start_exam_button.dart  # Tombol utama (disabled/active + buka URL)
    ├── security_check/
    │   └── security_check_modal.dart  # Modal wajib (blocking) pengecekan AI
    └── splash/
        ├── splash_background.dart   # Gradient langit + foto gedung (crop bawah)
        ├── splash_dots.dart         # Decorative dots 4x3, kecil & subtle
        ├── splash_logo.dart         # Logo diperbesar + glow biru halus
        ├── splash_title.dart        # "ExamPrima" (wordmark, letter-spacing)
        ├── splash_tagline.dart      # Tagline, terpisah dari judul
        ├── splash_hero_group.dart   # Logo+judul+tagline sbg 1 grup visual
        └── splash_loading_card.dart # Card glassmorphism premium + progress bar

assets/
└── images/
    ├── logo_sekolah.png        # Logo SMK PGRI 5 Jember (dari file Anda)
    ├── exam_illustration.png   # PLACEHOLDER — lihat catatan di bawah
    └── bg_sekolah.jpg          # Foto gedung sekolah (dari file Anda)
```

## Pemeriksaan Keamanan (Security Check) — BARU

Alur lengkap sekarang:

```
Splash Screen
     ↓
Halaman Syarat Ujian dibuka
     ↓
Modal "Persiapan Sebelum Ujian" muncul otomatis (blocking)
     ↓
Aplikasi mengecek 6 package AI terlarang (lihat forbidden_ai_apps.dart)
     ↓
Masih ada yang terpasang?
  → Modal tetap tampil, tombol "Periksa Kembali" untuk cek ulang
  → TIDAK bisa ditutup (back Android / tap luar / tombol close semua diblokir)
  → Halaman Syarat Ujian di belakangnya tidak bisa dipakai
     ↓
Sudah bersih → modal berubah jadi status "Perangkat Siap Digunakan"
     ↓
Tekan "Lanjutkan" → modal hilang → halaman Syarat Ujian terlihat penuh
     ↓
Baca ketentuan → centang persetujuan → tombol aktif
     ↓
"Saya Mengerti, Mulai Ujian" → baru di titik ini membuka 10.10.2.2
```

- **`lib/constants/forbidden_ai_apps.dart`** — daftar 6 aplikasi AI
  default (ChatGPT, Google Gemini, Microsoft Copilot, DeepSeek,
  Perplexity, Claude by Anthropic), masing-masing dengan package name
  Android yang sudah saya verifikasi lewat pencarian terbaru. Tinggal
  tambah/hapus entri di list ini kalau Anda mau menyesuaikan daftarnya
  — **ingat juga sinkronkan ke `<queries>` di AndroidManifest.xml**
  (lihat bagian setup di atas).
- **`lib/services/ai_app_checker_service.dart`** — memakai plugin
  [`appcheck`](https://pub.dev/packages/appcheck) untuk mengecek satu
  per satu package tersebut (`isAppInstalled`). Tidak memakai izin
  `QUERY_ALL_PACKAGES` yang lebih invasif — cukup mendaftarkan package
  spesifik di `<queries>`.
- **`lib/widgets/security_check/security_check_modal.dart`** — modal
  custom (bukan `AlertDialog` bawaan), dengan 3 kondisi: checking
  (spinner singkat), blocked (daftar aplikasi terdeteksi + tombol
  "Periksa Kembali"), dan success (icon centang + tombol "Lanjutkan").
  Modal digambar lewat `showDialog(barrierDismissible: false, ...)`
  dan dibungkus `PopScope(canPop: false)` supaya benar-benar tidak
  bisa ditutup selama status masih blocked — hanya bisa hilang lewat
  tombol "Lanjutkan" di status success.
- **Batasan penting (sesuai arahan Anda)**: aplikasi ini **tidak**
  dan **tidak bisa** menghapus aplikasi lain secara otomatis — Android
  tidak mengizinkan itu untuk aplikasi biasa. Siswa tetap harus
  menghapus sendiri lewat pengaturan Android; tombol "Periksa Kembali"
  hanya melakukan pengecekan ulang setelah itu.

## Splash Screen (revisi terbaru: integrasi background foto)

Layout inti (posisi logo, "ExamPrima", tagline, loading card, dots)
**tidak diubah** — revisi ini hanya memperbaiki cara foto sekolah
menyatu dengan background, karena sebelumnya foto terlihat seperti
kotak yang "ditempel" di bagian bawah layar.

- **Foto sekarang full-screen** (`BoxFit.cover`, `alignment:
  Alignment.bottomCenter` supaya gedung tetap prioritas kalau ada
  crop vertikal di rasio layar tertentu) — bukan lagi dipotong hanya
  di 32% bagian bawah.
- **Tidak ada garis batas**: overlay di atasnya adalah gradient
  5-stop yang sangat panjang (biru-putih ~92% opacity di puncak →
  memudar bertahap → transparan penuh di ±66% tinggi layar), jadi
  transisi dari "area UI" ke "foto terlihat jelas" berlangsung
  gradual, plus sentuhan gradient tipis lagi dari bawah (~8% opacity)
  supaya foto tetap senada dengan tema biru tanpa jadi pudar/abu-abu.
- **Warna asli foto dipertahankan** (langit biru, gedung oranye, pohon
  hijau, awan putih) — hanya diberi pengurangan saturasi (~12%) dan
  kontras (~6%) yang sangat halus lewat `ColorFiltered`, plus sedikit
  brightness supaya tidak gelap. Bukan filter biru pekat/monokrom.
- **Loading card** tidak dirombak — tetap glassmorphism seperti
  sebelumnya, dan sekarang foto di baliknya lebih terasa "menyatu"
  karena tidak ada lagi batas kotak.

Kalau setelah dicoba di device area sekitar logo/ExamPrima masih
terasa kurang kontras (karena foto asli hanya px ±20% sky di
bagian atas, jadi gedung ada kemungkinan tersamar di balik gradient
pada area itu), opacity gradient atas (`_EAF7FF` dst. di
`splash_background.dart`) bisa saya naikkan sedikit lagi — tinggal
kabari.

## ⚠️ Catatan penting: ilustrasi hero

`assets/images/exam_illustration.png` saat ini adalah **placeholder**
(kotak biru muda dengan label "ILLUSTRATION PLACEHOLDER"), sesuai
kesepakatan — Anda akan menyediakan file PNG ilustrasi asli
(clipboard/checklist + topi wisuda + buku) nanti.

Layout hero (`lib/widgets/requirement_hero.dart`) sudah disiapkan
dengan `AspectRatio` mendekati proporsi mockup (rasio ±560:430) dan
`BoxFit.contain`, jadi begitu Anda punya file PNG asli:

1. Ganti file `assets/images/exam_illustration.png` dengan PNG asli
   (nama file & lokasi harus sama persis).
2. Tidak perlu mengubah kode apa pun — layout, posisi, dan ukuran
   akan otomatis menyesuaikan.

Jika rasio aspek PNG asli Anda berbeda jauh dari ±1.3:1, beri tahu
saya supaya nilai `aspectRatio` di `requirement_hero.dart` bisa
disesuaikan agar tidak terpotong/terlalu kecil.

## Font

Menggunakan package `google_fonts` (Poppins didownload otomatis saat
runtime, tidak perlu bundel file font manual).

## Perilaku tombol "Saya Mengerti, Mulai Ujian"

- Baru bisa ditekan **setelah** modal pemeriksaan keamanan dilewati
  (status "Perangkat Siap Digunakan" → "Lanjutkan").
- Checkbox "Sebelum Mulai" belum dicentang → tombol nonaktif (warna
  pucat, tidak bisa ditekan).
- Checkbox dicentang → tombol aktif (gradient biru).
- Tombol ditekan → langsung membuka `http://10.10.2.2` di browser
  eksternal via `url_launcher` (`LaunchMode.externalApplication`).
  Tidak ada halaman ujian/soal Flutter perantara — sesuai arahan,
  ini adalah tahap terakhir, bukan langkah pertama.
