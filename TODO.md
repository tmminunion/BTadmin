# ✅ TODO.md — BTadmin Execution Checklist

## 1. Backend (`bungtemin.net`)
- [x] Buat controller API `router/btapi/AdminApp.php`:
  - [x] `GET /btapi/AdminApp/home` (Statistik, ServiceControl, AppMenuConfig, Wanotif, Latest Logins, 22 Modules)
  - [x] `GET /btapi/AdminApp/modules` (Katalog 22 modul Admin Panel)
  - [x] `POST /btapi/AdminApp/update_service` (Native toggle mode layanan `online` / `maintenance` / `shutdown`)
  - [x] `POST /btapi/AdminApp/update_global` (Native toggle protokoler global)
  - [x] `POST /btapi/AdminApp/toggle_sso` (Native toggle Microsoft SSO)
  - [x] `POST /btapi/AdminApp/toggle_wanotif` (Native toggle `pause_all` & `pause_kta`)
  - [x] `POST /btapi/AdminApp/update_appmenu` (Native toggle mode menu aplikasi Flutter)
  - [x] `POST /btapi/AdminApp/web_ticket` (Tiket 1x pakai TTL 60 detik untuk WebView)
- [x] Buat controller penukar tiket `router/adminpanel/applogin.php` (`GET /adminpanel/applogin?t=<ticket>`)
- [x] Validasi syntax `php -l` & deploy ke FTP `bungtemin.net` (`/ALLNEW/router/...`)
- [x] Verifikasi endpoint live di `https://bungtemin.net/btapi/AdminApp/home` dan `https://bungtemin.net/adminpanel/applogin`

## 2. Aplikasi Flutter (`BTadmin`)
- [x] Konfigurasi `pubspec.yaml`, tema Dark Command Center (`lib/core/admin_theme.dart`), dan penyimpanan sesi (`lib/core/admin_session.dart`)
- [x] Buat model data (`lib/models/admin_models.dart`) untuk Dashboard, Layanan, Menu App, Wanotif, Log Login, dan 22 Modul Admin Panel
- [x] Buat API Service (`lib/services/bt_admin_api.dart`) untuk Login (Password/PIN & Request OTP WA), Dashboard, Kontrol Native, dan Web Ticket
- [x] Buat Halaman Login Admin (`lib/features/auth/admin_login_screen.dart`) dengan dukungan Request OTP WhatsApp & validasi akses Admin
- [x] Buat Halaman Utama 4-Tab (`lib/features/shell/admin_shell_screen.dart`):
  - [x] **Tab 1 — Dashboard**: Statistik anggota, SSO, login hari ini, kartu akses cepat, & 12 riwayat login terakhir
  - [x] **Tab 2 — Layanan & Menu**: Toggle SSO Microsoft, mode protokoler global, kontrol 1-klik tiap layanan web & menu aplikasi Flutter
  - [x] **Tab 3 — WA & Broadcast**: Statistik antrean WA (Total, KTA, Non-KTA), switch Pause Semua WA & Pause KTA, shortcut ke Broadcast Center & Antrean Bailey 1/2
  - [x] **Tab 4 — 22 Modul Web**: Grid semua modul `/adminpanel/*` dengan filter kategori & pencarian cepat
- [x] Buat Halaman In-App WebView (`lib/features/webview/admin_webview_screen.dart`) dengan auto-login tiket 60 detik, progress indicator, quick module switcher, reload tiket baru, dan buka di browser eksternal
- [x] Buat unit & widget tests (`test/widget_test.dart`)

## 3. Repository GitHub, Keystore, Secrets & CI/CD Release
- [x] Buat repo private `tmminunion/BTadmin`
- [x] Generate keystore Android baru (`btadmin-release.jks`) & daftarkan GitHub Secrets (`KEYSTORE_BASE64`, `KEY_ALIAS`, `KEY_PASSWORD`, `STORE_PASSWORD`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`)
- [x] Buat workflow `.github/workflows/build-apk.yml` (Analyze, Test, Build Signed APK, Publish GitHub Release, & Kirim APK ke Telegram)
