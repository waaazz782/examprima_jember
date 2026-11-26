package com.example.examprimajember

import android.app.admin.DeviceAdminReceiver

/**
 * Device Admin Receiver khusus untuk Exam Mode / Kiosk Mode ExamPrima.
 *
 * Class ini WAJIB ada agar aplikasi bisa didaftarkan sebagai Device
 * Owner (lihat instruksi adb di MainActivity.kt), yang diperlukan
 * supaya startLockTask() bisa mengunci perangkat secara penuh
 * (memblokir Home, Recent Apps, dan notification shade) selama Exam
 * Mode aktif.
 *
 * Tidak ada logika tambahan yang diperlukan di sini - class ini hanya
 * bertindak sebagai "identitas" admin yang didaftarkan ke sistem
 * Android melalui res/xml/device_admin_receiver.xml.
 */
class KioskDeviceAdminReceiver : DeviceAdminReceiver()