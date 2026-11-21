# TODO Sinkronisasi BTadmin ↔ Adminpanel Web

Daftar pekerjaan sinkronisasi fitur terbaru Adminpanel Web ke aplikasi Flutter **BTadmin**:

- [x] **1. Backend API `btapi/AdminApp.php`**
  - [x] Tambah `wanotif_subscribe()` untuk tambah subscriber WA (1/banyak nomor, dedup, auto lookup nama).
  - [x] Tambah API Webhook & Auto-Table Manager: `webhooks_list()`, `webhook_save()`, `webhook_toggle()`, `webhook_delete()`, `webhook_test()`, `webhook_table_data()`, `webhook_retry_log()`.
  - [x] Sempurnakan `inbox_save()`: bersihkan `<head>`/`<style>`/HTML pada snippet Push FCM.
  - [x] Verifikasi `php -l` dan deploy ke produksi.
- [x] **2. BTadmin Wanotif (`native_wanotif_screen.dart`)**
  - [x] Tambah form **Tambah Subscriber WA** (Nama, Noreg opsional, Nomor WA) pada tab **Subscriber WA** bersama **Cabut Subscribe**.
- [x] **3. BTadmin Broadcast Inbox (`native_inbox_screen.dart`)**
  - [x] Tambah tombol **Paste HTML BEE / Studio** (`Clipboard`) dan **Copy HTML**.
- [x] **4. BTadmin Webhook & Auto-Table Manager (`native_webhook_screen.dart` + `admin_shell_screen.dart`)**
  - [x] Buat modul native `NativeWebhookScreen` (3 tab: Daftar Webhook + Test Ping + Lihat Tabel `bunp2332_prisma`, Form Tambah/Edit Outgoing & Incoming, Delivery Logs + Inspector Payload + Retry).
  - [x] Daftarkan modul `webhook` di `admin_shell_screen.dart`.
- [x] **5. Audit Logs (`native_logs_screen.dart`)**
  - [x] Verifikasi avatar default aman dari bad link (menggunakan `errorBuilder` fallback inisial).
- [x] **6. Finalisasi & Push**
  - [x] Tandai semua item selesai di `TODO.md`.
  - [x] Commit & push repo `BTadmin` ke GitHub (`main`) tanpa mengubah versi `pubspec.yaml`.
