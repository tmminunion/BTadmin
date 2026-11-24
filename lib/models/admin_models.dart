import 'package:flutter/material.dart';

class AdminModuleItem {
  const AdminModuleItem({
    required this.key,
    required this.category,
    required this.title,
    required this.desc,
    required this.iconName,
    required this.path,
  });

  final String key;
  final String category;
  final String title;
  final String desc;
  final String iconName;
  final String path;

  factory AdminModuleItem.fromJson(Map<String, dynamic> j) {
    return AdminModuleItem(
      key: (j['key'] ?? '').toString(),
      category: (j['category'] ?? 'Modul Admin').toString(),
      title: (j['title'] ?? '').toString(),
      desc: (j['desc'] ?? '').toString(),
      iconName: (j['icon'] ?? 'dashboard').toString(),
      path: (j['path'] ?? '/adminpanel/home').toString(),
    );
  }

  IconData get iconData {
    switch (iconName) {
      case 'dashboard':
        return Icons.space_dashboard_rounded;
      case 'tune':
        return Icons.tune_rounded;
      case 'whatsapp':
        return Icons.chat_rounded;
      case 'queue':
        return Icons.playlist_add_check_circle_rounded;
      case 'people':
        return Icons.people_alt_rounded;
      case 'history':
        return Icons.history_rounded;
      case 'apps':
        return Icons.grid_view_rounded;
      case 'menu':
        return Icons.widgets_rounded;
      case 'list':
        return Icons.menu_open_rounded;
      case 'article':
        return Icons.newspaper_rounded;
      case 'stories':
        return Icons.auto_stories_rounded;
      case 'campaign':
        return Icons.campaign_rounded;
      case 'calendar':
        return Icons.calendar_month_rounded;
      case 'poll':
        return Icons.poll_rounded;
      case 'edit_note':
        return Icons.edit_note_rounded;
      case 'email':
        return Icons.mark_email_read_rounded;
      case 'cloud':
        return Icons.cloud_sync_rounded;
      case 'cdn':
        return Icons.folder_special_rounded;
      case 'storage':
        return Icons.dns_rounded;
      case 'backup':
        return Icons.backup_rounded;
      case 'analytics':
        return Icons.query_stats_rounded;
      case 'terminal':
        return Icons.terminal_rounded;
      case 'settings':
        return Icons.settings_suggest_rounded;
      default:
        return Icons.extension_rounded;
    }
  }

  static const List<AdminModuleItem> defaults = [
    AdminModuleItem(
      key: 'home',
      category: 'Kontrol Utama',
      title: 'Dashboard Web',
      desc: 'Ringkasan & kontrol utama adminpanel',
      iconName: 'dashboard',
      path: '/adminpanel/home',
    ),
    AdminModuleItem(
      key: 'control',
      category: 'Kontrol Utama',
      title: 'Kontrol Layanan',
      desc: 'ON / Maintenance / Nonaktif seluruh layanan',
      iconName: 'tune',
      path: '/adminpanel/control',
    ),
    AdminModuleItem(
      key: 'apps',
      category: 'Kontrol Utama',
      title: 'Katalog Aplikasi',
      desc: 'Daftar modul & status layanan Bungtemin',
      iconName: 'apps',
      path: '/adminpanel/apps',
    ),
    AdminModuleItem(
      key: 'appmenus',
      category: 'Kontrol Utama',
      title: 'Menu Aplikasi Flutter',
      desc: 'Atur ON / Maintenance / OFF menu mobile',
      iconName: 'menu',
      path: '/adminpanel/appmenus',
    ),
    AdminModuleItem(
      key: 'menus',
      category: 'Kontrol Utama',
      title: 'Menu Situs Web',
      desc: 'Kelola struktur navigasi menu web',
      iconName: 'list',
      path: '/adminpanel/menus',
    ),
    AdminModuleItem(
      key: 'promo',
      category: 'Kontrol Utama',
      title: 'Promo & Update APK',
      desc: 'Banner promo & paksa update versi aplikasi',
      iconName: 'campaign',
      path: '/adminpanel/promo',
    ),
    AdminModuleItem(
      key: 'feedback',
      category: 'Komunikasi & Saran',
      title: 'Saran Aplikasi',
      desc: 'Pantau masukan UX, bug & ide fitur dari anggota',
      path: '/adminpanel/feedback',
      iconName: 'comment',
    ),
    AdminModuleItem(
      key: 'wanotif',
      category: 'WA & Broadcast',
      title: 'WA Broadcast Center',
      desc: 'Broadcast WhatsApp & Push Notification FCM',
      iconName: 'whatsapp',
      path: '/adminpanel/wanotif',
    ),
    AdminModuleItem(
      key: 'wanotif_antrean',
      category: 'WA & Broadcast',
      title: 'Antrean WA & Bailey',
      desc: 'Follow-up antrean, balance Bailey 1/2 & dedup',
      iconName: 'queue',
      path: '/adminpanel/wanotif/antrean',
    ),
    AdminModuleItem(
      key: 'wanotif_fcm',
      category: 'WA & Broadcast',
      title: 'Push Notifikasi FCM',
      desc: 'Kirim push notifikasi ke topik & anggota',
      iconName: 'campaign',
      path: '/adminpanel/wanotif',
    ),
    AdminModuleItem(
      key: 'inbox',
      category: 'WA & Broadcast',
      title: 'Broadcast Inbox App',
      desc: 'Kirim pengumuman, PDF, link, konfirmasi & multi-form',
      iconName: 'inbox',
      path: '/adminpanel/inbox',
    ),
    AdminModuleItem(
      key: 'email',
      category: 'WA & Broadcast',
      title: 'Email SMTP Tester',
      desc: 'Uji & kirim email notifikasi sistem',
      iconName: 'email',
      path: '/adminpanel/email',
    ),
    AdminModuleItem(
      key: 'users',
      category: 'Anggota & Akses',
      title: 'Pengguna & Anggota',
      desc: 'Data anggota, filter SSO/WA/Email & hak akses',
      iconName: 'people',
      path: '/adminpanel/users',
    ),
    AdminModuleItem(
      key: 'logs',
      category: 'Anggota & Akses',
      title: 'Log Login Terakhir',
      desc: 'Riwayat autentikasi aplikasi mobile & web',
      iconName: 'history',
      path: '/adminpanel/logs',
    ),
    AdminModuleItem(
      key: 'applogin',
      category: 'Anggota & Akses',
      title: 'Sesi App Login',
      desc: 'Pantau sesi login aplikasi mobile & token aktif',
      iconName: 'vpn_key',
      path: '/adminpanel/applogin',
    ),
    AdminModuleItem(
      key: 'feedback',
      category: 'Anggota & Akses',
      title: 'Saran & Feedback App',
      desc: 'Moderasi masukan & laporan bug dari pengguna',
      iconName: 'feedback',
      path: '/adminpanel/feedback',
    ),
    AdminModuleItem(
      key: 'msadmin',
      category: 'Anggota & Akses',
      title: 'Microsoft Admin SSO',
      desc: 'OAuth Microsoft Graph & SharePoint access',
      iconName: 'cloud',
      path: '/adminpanel/msadmin',
    ),
    AdminModuleItem(
      key: 'berita',
      category: 'Konten & Media',
      title: 'Berita & Blogger Sync',
      desc: 'Sinkronisasi artikel & push FCM berita terbaru',
      iconName: 'article',
      path: '/adminpanel/berita',
    ),
    AdminModuleItem(
      key: 'cerita',
      category: 'Konten & Media',
      title: 'Moderasi Cerita/Reels',
      desc: 'Moderasi foto stories, video reels & komentar',
      iconName: 'stories',
      path: '/adminpanel/cerita',
    ),
    AdminModuleItem(
      key: 'kalender',
      category: 'Konten & Media',
      title: 'Kalender Kerja TMMIN',
      desc: 'Kelola hari libur, cuti bersama & cache key',
      iconName: 'calendar',
      path: '/adminpanel/kalender',
    ),
    AdminModuleItem(
      key: 'survey',
      category: 'Konten & Media',
      title: 'Survei & Polling',
      desc: 'Daftar survei, form builder & analitik jawaban',
      iconName: 'poll',
      path: '/adminpanel/survey',
    ),
    AdminModuleItem(
      key: 'survey_builder',
      category: 'Konten & Media',
      title: 'Pembuat Survei Baru',
      desc: 'Editor pertanyaan survei anggota',
      iconName: 'edit_note',
      path: '/adminpanel/survey/builder',
    ),
    AdminModuleItem(
      key: 'cdn',
      category: 'Sistem & Server',
      title: 'CDN & File Manager',
      desc: 'Kelola berkas CDN & generator Ollama AI',
      iconName: 'cdn',
      path: '/adminpanel/cdn',
    ),
    AdminModuleItem(
      key: 'cdn_setup',
      category: 'Sistem & Server',
      title: 'Konfigurasi CDN',
      desc: 'Pengaturan endpoint & penyimpanan CDN',
      iconName: 'storage',
      path: '/adminpanel/cdn_setup',
    ),
    AdminModuleItem(
      key: 'backup',
      category: 'Sistem & Server',
      title: 'Backup Database',
      desc: 'Cadangan database & snapshot sistem',
      iconName: 'backup',
      path: '/adminpanel/backup',
    ),
    AdminModuleItem(
      key: 'analytics',
      category: 'Sistem & Server',
      title: 'Analitik Sistem',
      desc: 'Statistik trafik & penggunaan fitur',
      iconName: 'analytics',
      path: '/adminpanel/analytics',
    ),
    AdminModuleItem(
      key: 'ssh',
      category: 'Sistem & Server',
      title: 'Konsol Server (SSH)',
      desc: 'Terminal eksekusi perintah server',
      iconName: 'terminal',
      path: '/adminpanel/ssh',
    ),
    AdminModuleItem(
      key: 'setting',
      category: 'Sistem & Server',
      title: 'Pengaturan Sistem',
      desc: 'Konfigurasi parameter utama Bungtemin',
      iconName: 'settings',
      path: '/adminpanel/setting',
    ),
  ];
}

class AdminServiceItem {
  const AdminServiceItem({
    required this.key,
    required this.name,
    required this.group,
    required this.mode,
    required this.reason,
  });

  final String key;
  final String name;
  final String group;
  final String mode;
  final String reason;

  factory AdminServiceItem.fromJson(Map<String, dynamic> j) {
    return AdminServiceItem(
      key: (j['key'] ?? '').toString(),
      name: (j['name'] ?? '').toString(),
      group: (j['group'] ?? '').toString(),
      mode: (j['mode'] ?? 'online').toString(),
      reason: (j['reason'] ?? '').toString(),
    );
  }
}

class AdminAppMenuItem {
  const AdminAppMenuItem({
    required this.key,
    required this.label,
    required this.route,
    required this.group,
    required this.mode,
    required this.maintenanceMessage,
  });

  final String key;
  final String label;
  final String route;
  final String group;
  final String mode;
  final String maintenanceMessage;

  factory AdminAppMenuItem.fromJson(Map<String, dynamic> j) {
    return AdminAppMenuItem(
      key: (j['key'] ?? '').toString(),
      label: (j['label'] ?? '').toString(),
      route: (j['route'] ?? '').toString(),
      group: (j['group'] ?? 'main').toString(),
      mode: (j['mode'] ?? 'online').toString(),
      maintenanceMessage: (j['maintenance_message'] ?? '').toString(),
    );
  }
}

class AdminLoginLogItem {
  const AdminLoginLogItem({
    required this.noreg,
    required this.nama,
    required this.ipAddress,
    required this.via,
    required this.device,
    required this.success,
    required this.createdAt,
  });

  final String noreg;
  final String nama;
  final String ipAddress;
  final String via;
  final String device;
  final bool success;
  final String createdAt;

  factory AdminLoginLogItem.fromJson(Map<String, dynamic> j) {
    return AdminLoginLogItem(
      noreg: (j['noreg'] ?? '').toString(),
      nama: (j['nama'] ?? '').toString(),
      ipAddress: (j['ip_address'] ?? '').toString(),
      via: (j['via'] ?? '').toString(),
      device: (j['device'] ?? '').toString(),
      success: j['success'] == true || j['success'] == 1,
      createdAt: (j['created_at'] ?? '').toString(),
    );
  }
}

class AdminDashboardData {
  const AdminDashboardData({
    required this.adminNoreg,
    required this.adminNama,
    required this.adminJob,
    required this.totalAnggota,
    required this.userTerhubung,
    required this.loginHariIni,
    required this.ssoEnabled,
    required this.globalMode,
    required this.globalReason,
    required this.services,
    required this.appMenus,
    required this.waPauseAll,
    required this.waPauseKta,
    required this.waQueueTotal,
    required this.waQueueKta,
    required this.waQueueNonKta,
    this.waPreferredBot = 1,
    this.waActiveBot = 1,
    this.waFailover = false,
    this.waBot1Online = true,
    this.waBot2Online = true,
    required this.latestLogins,
    required this.modules,
    required this.phpVersion,
    required this.serverTime,
  });

  final String adminNoreg;
  final String adminNama;
  final String adminJob;
  final int totalAnggota;
  final int userTerhubung;
  final int loginHariIni;
  final bool ssoEnabled;
  final String globalMode;
  final String globalReason;
  final List<AdminServiceItem> services;
  final List<AdminAppMenuItem> appMenus;
  final bool waPauseAll;
  final bool waPauseKta;
  final int waQueueTotal;
  final int waQueueKta;
  final int waQueueNonKta;
  final int waPreferredBot;
  final int waActiveBot;
  final bool waFailover;
  final bool waBot1Online;
  final bool waBot2Online;
  final List<AdminLoginLogItem> latestLogins;
  final List<AdminModuleItem> modules;
  final String phpVersion;
  final String serverTime;

  factory AdminDashboardData.fromJson(Map<String, dynamic> d) {
    final admin = (d['admin'] as Map<String, dynamic>?) ?? const {};
    final stats = (d['stats'] as Map<String, dynamic>?) ?? const {};
    final global = (d['service_global'] as Map<String, dynamic>?) ?? const {};
    final wa = (d['wanotif'] as Map<String, dynamic>?) ?? const {};
    final srv = (d['server'] as Map<String, dynamic>?) ?? const {};

    final rawServices = (d['services'] as List?) ?? const [];
    final rawAppMenus = (d['app_menus'] as List?) ?? const [];
    final rawLogs = (d['latest_logins'] as List?) ?? const [];
    final rawModules = (d['modules'] as List?) ?? const [];

    final parsedModules = rawModules
        .whereType<Map<String, dynamic>>()
        .map(AdminModuleItem.fromJson)
        .toList();

    return AdminDashboardData(
      adminNoreg: (admin['noreg'] ?? '').toString(),
      adminNama: (admin['nama'] ?? '').toString(),
      adminJob: (admin['job'] ?? '').toString(),
      totalAnggota: int.tryParse((stats['total_anggota'] ?? '0').toString()) ?? 0,
      userTerhubung: int.tryParse((stats['user_terhubung'] ?? '0').toString()) ?? 0,
      loginHariIni: int.tryParse((stats['login_hari_ini'] ?? '0').toString()) ?? 0,
      ssoEnabled: d['sso_enabled'] == true,
      globalMode: (global['mode'] ?? 'online').toString(),
      globalReason: (global['reason'] ?? '').toString(),
      services: rawServices
          .whereType<Map<String, dynamic>>()
          .map(AdminServiceItem.fromJson)
          .toList(),
      appMenus: rawAppMenus
          .whereType<Map<String, dynamic>>()
          .map(AdminAppMenuItem.fromJson)
          .toList(),
      waPauseAll: wa['pause_all'] == true,
      waPauseKta: wa['pause_kta'] == true,
      waQueueTotal: int.tryParse((wa['queue_total'] ?? '0').toString()) ?? 0,
      waQueueKta: int.tryParse((wa['queue_kta'] ?? '0').toString()) ?? 0,
      waQueueNonKta: int.tryParse((wa['queue_non_kta'] ?? '0').toString()) ?? 0,
      waPreferredBot: (int.tryParse((wa['preferred_bot'] ?? '1').toString()) ?? 1) == 2 ? 2 : 1,
      waActiveBot: (int.tryParse((wa['active_bot'] ?? '1').toString()) ?? 1) == 2 ? 2 : 1,
      waFailover: wa['failover'] == true,
      waBot1Online: wa['bot1_online'] != false,
      waBot2Online: wa['bot2_online'] != false,
      latestLogins: rawLogs
          .whereType<Map<String, dynamic>>()
          .map(AdminLoginLogItem.fromJson)
          .toList(),
      modules: parsedModules.isNotEmpty ? parsedModules : AdminModuleItem.defaults,
      phpVersion: (srv['php'] ?? '').toString(),
      serverTime: (srv['time'] ?? '').toString(),
    );
  }
}
