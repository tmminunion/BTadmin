# 📋 PLAN.md — BTadmin (Aplikasi Kontrol Admin Panel Bungtemin)

## 1. Tujuan & Gambaran Umum
**BTadmin** (`com.bung.btadmin`) adalah aplikasi mobile Android berbasis **Flutter** khusus untuk **Superadmin & Pengurus Admin Panel Bungtemin (`bungtemin.net/adminpanel`)**.

Aplikasi ini menggabungkan:
1. **Native Command Center**:
   - **Beranda & Statistik Real-Time**: Total anggota Pemandatan, user terhubung Microsoft SSO, jumlah login hari ini, info PHP & waktu server, serta 12 riwayat autentikasi terakhir.
   - **Kontrol Layanan & Protokoler Global Native**: Mengubah mode global (`ONLINE`, `MAINTENANCE`, `SHUTDOWN`), toggle **Microsoft SSO** (`ON`/`OFF`), serta mengubah mode tiap layanan di `ServiceControl` dan menu aplikasi Flutter (`AppMenuConfig`) langsung dari UI native.
   - **Kontrol WA Notifikasi & Antrean Native**: Memantau antrean aktif total, KTA, dan non-KTA, serta tombol **Pause/Resume Semua WA** & **Pause/Resume KTA** langsung tanpa membuka browser.
2. **In-App WebView dengan Tiket Sekali Pakai (60 Detik)**:
   - Setiap kali admin membuka salah satu dari **22 modul Admin Panel** (`/adminpanel/*`), aplikasi memanggil `POST /btapi/AdminApp/web_ticket` menggunakan Bearer Token admin.
   - Server membuat tiket 64-hex sekali pakai berlaku **60 detik** dan mengembalikan URL `/adminpanel/applogin?t=<ticket>`.
   - WebView membuka URL tersebut, server memvalidasi & menghapus tiket secara atomik, mengaktifkan session PHP `$_SESSION['login']` + cookie `loginID`, lalu me-redirect ke modul tujuan **tanpa login ulang**.

---

## 2. Daftar 22 Modul Admin Panel di Dalam APK

1. **Dashboard Web** (`/adminpanel/home`)
2. **Kontrol Layanan** (`/adminpanel/control`)
3. **Katalog Aplikasi** (`/adminpanel/apps`)
4. **Menu Aplikasi Flutter** (`/adminpanel/appmenus`)
5. **Menu Situs Web** (`/adminpanel/menus`)
6. **Promo & Update APK** (`/adminpanel/promo`)
7. **WA Broadcast Center** (`/adminpanel/wanotif`)
8. **Antrean WA & Bailey 1/2** (`/adminpanel/wanotif/antrean`)
9. **Email SMTP Tester** (`/adminpanel/email`)
10. **Pengguna & Anggota** (`/adminpanel/users`)
11. **Log Login Terakhir** (`/adminpanel/logs`)
12. **Microsoft Admin SSO** (`/adminpanel/msadmin`)
13. **Berita & Blogger Sync** (`/adminpanel/berita`)
14. **Moderasi Cerita/Reels** (`/adminpanel/cerita`)
15. **Kalender Kerja TMMIN** (`/adminpanel/kalender`)
16. **Survei & Polling** (`/adminpanel/survey`)
17. **Pembuat Survei Baru** (`/adminpanel/survey/builder`)
18. **CDN & File Manager** (`/adminpanel/cdn`)
19. **Konfigurasi CDN** (`/adminpanel/cdn_setup`)
20. **Backup Database** (`/adminpanel/backup`)
21. **Analitik Sistem** (`/adminpanel/analytics`)
22. **Konsol Server (SSH)** (`/adminpanel/ssh`)
23. **Pengaturan Sistem** (`/adminpanel/setting`)

---

## 3. Arsitektur Keamanan
- **Endpoint Guard**: Semua endpoint `/btapi/AdminApp/*` menolak request browser (`HTTP_ORIGIN` tidak kosong), memverifikasi masa berlaku JWT Bearer token, mengecek baris aktif di `auth_logins (success=1)`, dan memverifikasi otoritas admin via `AdminBaseController::isAdminUser()`.
- **One-Time Atomic Ticket**: Tiket disimpan sebagai hash SHA-256 di `sys_get_temp_dir()` dengan TTL 60 detik dan dikonsumsi menggunakan operasi `rename()` atomik sehingga tidak dapat dipakai ulang (*replay-safe*).
