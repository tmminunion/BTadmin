import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/admin_session.dart';
import '../../core/admin_theme.dart';
import '../../core/date_format.dart';
import '../../models/admin_models.dart';
import '../../services/bt_admin_api.dart';
import '../../services/deep_link_service.dart';
import '../modules/native_berita_screen.dart';
import '../modules/native_cerita_screen.dart';
import '../modules/native_email_survey_screen.dart';
import '../modules/native_kalender_screen.dart';
import '../modules/native_logs_screen.dart';
import '../modules/native_promo_screen.dart';
import '../modules/native_users_screen.dart';
import '../modules/native_extra_screens.dart';
import '../modules/native_inbox_screen.dart';
import '../modules/native_wanotif_screen.dart';
import '../modules/native_webhook_screen.dart';
import '../webview/admin_webview_screen.dart';

class AdminShellScreen extends StatefulWidget {
  const AdminShellScreen({
    super.key,
    required this.session,
    this.initialDashboard,
    required this.onLogout,
  });

  final AdminSession session;
  final AdminDashboardData? initialDashboard;
  final VoidCallback onLogout;

  @override
  State<AdminShellScreen> createState() => _AdminShellScreenState();
}

class _AdminShellScreenState extends State<AdminShellScreen> {
  final _api = BtAdminApi();
  final _searchCtrl = TextEditingController();
  StreamSubscription<Uri>? _deepLinkSub;

  int _tabIndex = 0;
  int _controlSubTab = 0;
  AdminDashboardData? _dash;
  bool _loading = true;
  bool _busyAction = false;
  String? _error;
  String _selectedCategory = 'Semua';

  static const _nativeKeys = {
    'home',
    'control',
    'apps',
    'appmenus',
    'users',
    'logs',
    'berita',
    'cerita',
    'promo',
    'kalender',
    'wanotif',
    'wanotif_antrean',
    'webhook',
    'email',
    'survey',
  };

  @override
  void initState() {
    super.initState();
    _dash = widget.initialDashboard;
    _loading = _dash == null;
    _loadDashboard();
    _deepLinkSub = AdminDeepLinkService.instance.onUri.listen(_handleDeepLinkUri);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final pending = AdminDeepLinkService.instance.consumePendingUri();
      if (pending != null && mounted) {
        _handleDeepLinkUri(pending);
      }
    });
  }

  @override
  void dispose() {
    _deepLinkSub?.cancel();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadDashboard() async {
    if (_dash == null) {
      final cached = await _api.loadCachedHome();
      if (cached != null && mounted) {
        setState(() {
          _dash = cached;
          _loading = false;
        });
      }
    }
    try {
      final fresh = await _api.fetchHome(widget.session.token);
      if (!mounted) return;
      setState(() {
        _dash = fresh;
        _loading = false;
        _error = null;
      });
    } on BtAdminApiException catch (e) {
      if (!mounted) return;
      if (e.statusCode == 401 || e.statusCode == 403) {
        _snack(e.message, isError: true);
        widget.onLogout();
        return;
      }
      setState(() {
        _loading = false;
        _error = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _error = e.toString();
      });
    }
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg, style: const TextStyle(fontWeight: FontWeight.w600)),
        backgroundColor: isError ? AdminColors.danger : AdminColors.emerald,
      ),
    );
  }

  void _openWebModule(AdminModuleItem mod) {
    final all = _dash?.modules ?? AdminModuleItem.defaults;
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AdminWebViewScreen(
          token: widget.session.token,
          module: mod,
          allModules: all,
        ),
      ),
    );
  }

  void _handleDeepLinkUri(Uri uri) {
    if (!mounted) return;
    final target = AdminDeepLinkService.resolveTarget(uri);
    final mod = AdminModuleItem(
      key: target.key,
      category: 'Deep Link',
      title: target.key.toUpperCase(),
      desc: '',
      iconName: 'dashboard',
      path: target.path,
    );
    _openModule(mod);
  }

  void _openModule(AdminModuleItem mod) {
    Widget? screen;
    switch (mod.key) {
      case 'home':
        setState(() => _tabIndex = 0);
        return;
      case 'control':
      case 'apps':
        setState(() {
          _tabIndex = 1;
          _controlSubTab = 0;
        });
        return;
      case 'appmenus':
        setState(() {
          _tabIndex = 1;
          _controlSubTab = 1;
        });
        return;
      case 'users':
        screen = NativeUsersScreen(
          token: widget.session.token,
          onOpenWeb: () => _openWebModule(mod),
        );
      case 'logs':
        screen = NativeLogsScreen(
          token: widget.session.token,
          onOpenWeb: () => _openWebModule(mod),
        );
      case 'berita':
        screen = NativeBeritaScreen(
          token: widget.session.token,
          onOpenWeb: () => _openWebModule(mod),
        );
      case 'cerita':
        screen = NativeCeritaScreen(
          token: widget.session.token,
          onOpenWeb: () => _openWebModule(mod),
        );
      case 'promo':
        screen = NativePromoScreen(
          token: widget.session.token,
          onOpenWeb: () => _openWebModule(mod),
        );
      case 'kalender':
        screen = NativeKalenderScreen(
          token: widget.session.token,
          onOpenWeb: () => _openWebModule(mod),
        );
      case 'wanotif':
        screen = NativeWanotifScreen(
          token: widget.session.token,
          initialTab: 1,
          onOpenWeb: () => _openWebModule(mod),
        );
      case 'wanotif_antrean':
        screen = NativeWanotifScreen(
          token: widget.session.token,
          initialTab: 0,
          onOpenWeb: () => _openWebModule(mod),
        );
      case 'email':
        screen = NativeEmailScreen(
          token: widget.session.token,
          onOpenWeb: () => _openWebModule(mod),
        );
      case 'survey':
        screen = NativeSurveyScreen(
          token: widget.session.token,
          onOpenWeb: () => _openWebModule(mod),
        );
      case 'feedback':
        screen = NativeFeedbackScreen(token: widget.session.token);
      case 'menus':
        screen = NativeMenusScreen(token: widget.session.token);
      case 'analytics':
        screen = NativeAnalyticsScreen(token: widget.session.token);
      case 'wanotif_fcm':
        screen = NativeWanotifScreen(
          token: widget.session.token,
          initialTab: 2,
        );
      case 'webhook':
        screen = NativeWebhookScreen(token: widget.session.token);
        break;
      case 'inbox':
        screen = NativeInboxScreen(
          token: widget.session.token,
          onOpenWeb: () => _openWebModule(mod),
        );
      default:
        _openWebModule(mod);
        return;
    }
    final target = screen;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => target),
    );
  }

  void _openModuleByKey(String key) {
    final all = _dash?.modules ?? AdminModuleItem.defaults;
    final found = all.firstWhere(
      (m) => m.key == key,
      orElse: () => all.first,
    );
    _openModule(found);
  }

  Future<void> _runAction(Future<String> Function() action) async {
    if (_busyAction) return;
    setState(() => _busyAction = true);
    try {
      final msg = await action();
      _snack(msg);
      await _loadDashboard();
    } catch (e) {
      _snack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _busyAction = false);
    }
  }

  Future<void> _changeGlobalMode(String mode) async {
    final reasonCtrl = TextEditingController(text: _dash?.globalReason ?? '');
    var applyAll = false;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          backgroundColor: AdminColors.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
            side: const BorderSide(color: AdminColors.border),
          ),
          title: Text('Mode Global → ${mode.toUpperCase()}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Alasan / Pesan ke Anggota',
                  hintText: 'Opsional',
                ),
              ),
              const SizedBox(height: 10),
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                value: applyAll,
                onChanged: (v) => setS(() => applyAll = v ?? false),
                title: const Text(
                  'Terapkan ke semua layanan sekaligus',
                  style: TextStyle(fontSize: 13),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Batal'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
    if (confirm != true) return;
    await _runAction(
      () => _api.updateGlobal(
        token: widget.session.token,
        mode: mode,
        reason: reasonCtrl.text.trim(),
        applyAll: applyAll,
      ),
    );
  }

  Future<void> _changeServiceMode(AdminServiceItem svc, String mode) async {
    await _runAction(
      () => _api.updateService(
        token: widget.session.token,
        serviceKey: svc.key,
        mode: mode,
        reason: mode == 'online'
            ? ''
            : 'Sedang dalam pemeliharaan oleh Admin Panel.',
      ),
    );
  }

  Future<void> _changeAppMenuMode(AdminAppMenuItem item, String mode) async {
    await _runAction(
      () => _api.updateAppMenu(
        token: widget.session.token,
        key: item.key,
        mode: mode,
        group: item.group,
        maintenanceMessage: item.maintenanceMessage,
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty || parts.first.isEmpty) return 'A';
    if (parts.length == 1) return parts.first[0].toUpperCase();
    return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
  }

  Widget _buildSidebarDrawer(AdminDashboardData? dash) {
    final modules = List<AdminModuleItem>.from(
      dash?.modules.isNotEmpty == true ? dash!.modules : AdminModuleItem.defaults,
    );
    if (!modules.any((m) => m.key == 'feedback')) {
      modules.add(
        const AdminModuleItem(
          key: 'feedback',
          category: 'Komunikasi & Saran',
          title: 'Saran Aplikasi',
          desc: 'Masukan UX, bug & ide fitur dari anggota',
          path: '/adminpanel/feedback',
          iconName: 'comment',
        ),
      );
    }
    if (!modules.any((m) => m.key == 'wanotif_fcm')) {
      modules.add(
        const AdminModuleItem(
          key: 'wanotif_fcm',
          category: 'WA & Broadcast',
          title: 'Push Notifikasi FCM',
          desc: 'Broadcast push notif & gambar ke HP anggota',
          path: '/adminpanel/wanotif',
          iconName: 'bell',
        ),
      );
    }
    if (!modules.any((m) => m.key == 'webhook')) {
      modules.add(
        const AdminModuleItem(
          key: 'webhook',
          category: 'WA & Broadcast',
          title: 'Webhook & Auto-Table',
          desc: 'Webhook hybrid, Auto-Table bunp2332_prisma & Logs',
          path: '/adminpanel/webhook',
          iconName: 'plug',
        ),
      );
    }

    final grouped = <String, List<AdminModuleItem>>{};
    for (final m in modules) {
      grouped.putIfAbsent(m.category, () => []).add(m);
    }

    IconData iconFor(String key) {
      switch (key) {
        case 'home':
          return Icons.space_dashboard_rounded;
        case 'control':
        case 'apps':
          return Icons.public_rounded;
        case 'appmenus':
          return Icons.apps_rounded;
        case 'menus':
          return Icons.account_tree_rounded;
        case 'promo':
          return Icons.campaign_rounded;
        case 'wanotif':
          return Icons.chat_rounded;
        case 'wanotif_antrean':
          return Icons.playlist_add_check_rounded;
        case 'wanotif_fcm':
          return Icons.notifications_active_rounded;
        case 'webhook':
          return Icons.hub_rounded;
        case 'feedback':
          return Icons.rate_review_rounded;
        case 'email':
          return Icons.email_rounded;
        case 'users':
          return Icons.manage_accounts_rounded;
        case 'logs':
          return Icons.history_rounded;
        case 'berita':
          return Icons.newspaper_rounded;
        case 'cerita':
          return Icons.movie_creation_rounded;
        case 'kalender':
          return Icons.calendar_month_rounded;
        case 'survey':
          return Icons.poll_rounded;
        case 'analytics':
          return Icons.analytics_rounded;
        default:
          return Icons.settings_applications_rounded;
      }
    }

    return Drawer(
      backgroundColor: AdminColors.surface,
      child: SafeArea(
        child: Column(
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
              decoration: const BoxDecoration(
                gradient: AdminColors.heroGradient,
                border: Border(bottom: BorderSide(color: AdminColors.border)),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 22,
                    backgroundColor: AdminColors.gold.withValues(alpha: 0.18),
                    child: Text(
                      _initials(widget.session.nama),
                      style: const TextStyle(
                        fontWeight: FontWeight.w900,
                        color: AdminColors.gold,
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.session.nama,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        Text(
                          '${widget.session.noreg} • ${widget.session.job}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
                children: [
                  for (final entry in grouped.entries) ...[
                    Padding(
                      padding: const EdgeInsets.fromLTRB(10, 12, 10, 4),
                      child: Text(
                        entry.key.toUpperCase(),
                        style: const TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w800,
                          letterSpacing: 0.9,
                          color: AdminColors.gold,
                        ),
                      ),
                    ),
                    for (final mod in entry.value)
                      ListTile(
                        dense: true,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        leading: Icon(
                          iconFor(mod.key),
                          size: 20,
                          color: AdminColors.sky,
                        ),
                        title: Text(
                          mod.title,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        onTap: () {
                          Navigator.of(context).pop();
                          _openModule(mod);
                        },
                      ),
                  ],
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onLogout();
                  },
                  icon: const Icon(Icons.logout_rounded, size: 18),
                  label: const Text('Keluar Sesi'),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final dash = _dash;
    return Scaffold(
      drawer: _buildSidebarDrawer(dash),
      appBar: AppBar(
        toolbarHeight: 64,
        title: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                gradient: AdminColors.heroGradient,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: AdminColors.gold.withValues(alpha: 0.5),
                ),
              ),
              child: Center(
                child: Text(
                  _initials(widget.session.nama),
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 13.5,
                    color: AdminColors.gold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Text(
                        'BTadmin',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 16.5,
                          letterSpacing: -0.2,
                          color: AdminColors.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1.5,
                        ),
                        decoration: BoxDecoration(
                          color: AdminColors.emerald.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: const Text(
                          'PRO',
                          style: TextStyle(
                            fontSize: 9,
                            fontWeight: FontWeight.w900,
                            color: AdminColors.emerald,
                          ),
                        ),
                      ),
                    ],
                  ),
                  Text(
                    '${widget.session.nama} • ${widget.session.noreg}',
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 11.5,
                      color: AdminColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (_busyAction)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10),
              child: Center(
                child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            ),
          IconButton(
            tooltip: 'Segarkan Data',
            icon: const Icon(Icons.refresh_rounded, size: 22),
            onPressed: _loadDashboard,
          ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout_rounded, size: 21),
            onPressed: widget.onLogout,
          ),
        ],
        bottom: const PreferredSize(
          preferredSize: Size.fromHeight(1),
          child: Divider(height: 1),
        ),
      ),
      body: _loading && dash == null
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDashboard,
              child: IndexedStack(
                index: _tabIndex,
                children: [
                  _buildDashboardTab(dash),
                  _buildControlTab(dash),
                  _buildWaTab(dash),
                  _buildModulesTab(dash),
                ],
              ),
            ),
      bottomNavigationBar: Container(
        decoration: const BoxDecoration(
          border: Border(top: BorderSide(color: AdminColors.border)),
        ),
        child: NavigationBar(
          height: 66,
          backgroundColor: AdminColors.surface,
          indicatorColor: AdminColors.gold.withValues(alpha: 0.18),
          selectedIndex: _tabIndex,
          onDestinationSelected: (i) => setState(() => _tabIndex = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.space_dashboard_outlined),
              selectedIcon:
                  Icon(Icons.space_dashboard_rounded, color: AdminColors.gold),
              label: 'Beranda',
            ),
            NavigationDestination(
              icon: Icon(Icons.tune_outlined),
              selectedIcon: Icon(Icons.tune_rounded, color: AdminColors.gold),
              label: 'Layanan',
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_bubble_outline_rounded),
              selectedIcon:
                  Icon(Icons.chat_bubble_rounded, color: AdminColors.gold),
              label: 'WA & Notif',
            ),
            NavigationDestination(
              icon: Icon(Icons.grid_view_outlined),
              selectedIcon:
                  Icon(Icons.grid_view_rounded, color: AdminColors.gold),
              label: '23 Modul',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDashboardTab(AdminDashboardData? dash) {
    if (dash == null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_error != null)
            Text(_error!, style: const TextStyle(color: AdminColors.danger)),
        ],
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdminColors.danger.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AdminColors.danger.withValues(alpha: 0.4)),
            ),
            child: Text(_error!, style: const TextStyle(fontSize: 12.5)),
          ),
        _StatusHeroCard(dash: dash),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Total Anggota',
                value: '${dash.totalAnggota}',
                icon: Icons.groups_rounded,
                color: AdminColors.sky,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'User SSO',
                value: '${dash.userTerhubung}',
                icon: Icons.verified_user_rounded,
                color: AdminColors.emerald,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Login Hari Ini',
                value: '${dash.loginHariIni}',
                icon: Icons.login_rounded,
                color: AdminColors.gold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 22),
        const _SectionHeader(
          title: 'Akses Cepat Operasional',
          subtitle: 'Buka fitur manajemen inti secara native',
        ),
        const SizedBox(height: 10),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 4,
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 0.92,
          children: [
            _QuickActionTile(
              icon: Icons.people_alt_rounded,
              label: 'Pengguna',
              color: AdminColors.sky,
              onTap: () => _openModuleByKey('users'),
            ),
            _QuickActionTile(
              icon: Icons.newspaper_rounded,
              label: 'Berita',
              color: AdminColors.emerald,
              onTap: () => _openModuleByKey('berita'),
            ),
            _QuickActionTile(
              icon: Icons.auto_stories_rounded,
              label: 'Cerita',
              color: AdminColors.gold,
              onTap: () => _openModuleByKey('cerita'),
            ),
            _QuickActionTile(
              icon: Icons.campaign_rounded,
              label: 'Promo',
              color: AdminColors.indigo,
              onTap: () => _openModuleByKey('promo'),
            ),
            _QuickActionTile(
              icon: Icons.calendar_month_rounded,
              label: 'Kalender',
              color: AdminColors.sky,
              onTap: () => _openModuleByKey('kalender'),
            ),
            _QuickActionTile(
              icon: Icons.playlist_add_check_circle_rounded,
              label: 'Antrean',
              color: AdminColors.emerald,
              onTap: () => _openModuleByKey('wanotif_antrean'),
            ),
            _QuickActionTile(
              icon: Icons.mark_email_read_rounded,
              label: 'Email',
              color: AdminColors.gold,
              onTap: () => _openModuleByKey('email'),
            ),
            _QuickActionTile(
              icon: Icons.terminal_rounded,
              label: 'SSH Web',
              color: AdminColors.textSecondary,
              onTap: () => _openModuleByKey('ssh'),
            ),
          ],
        ),
        const SizedBox(height: 22),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const _SectionHeader(
              title: 'Aktivitas Login Terkini',
              subtitle: 'Autentikasi aplikasi & portal web',
            ),
            TextButton(
              onPressed: () => _openModuleByKey('logs'),
              child: const Text('Semua Log'),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ...dash.latestLogins.map(
          (log) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: AdminColors.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AdminColors.border),
            ),
            child: ListTile(
              dense: true,
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: CircleAvatar(
                radius: 19,
                backgroundColor:
                    (log.success ? AdminColors.emerald : AdminColors.danger)
                        .withValues(alpha: 0.16),
                child: Icon(
                  log.success
                      ? Icons.check_circle_rounded
                      : Icons.cancel_rounded,
                  size: 19,
                  color: log.success ? AdminColors.emerald : AdminColors.danger,
                ),
              ),
              title: Text(
                '${log.nama} (${log.noreg})',
                style: const TextStyle(
                    fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              subtitle: Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  '${log.via} • ${log.device}'
                  '${log.ipAddress.isNotEmpty ? '\nIP: ${log.ipAddress}' : ''}'
                  '\n${formatDateDdMmYyyy(log.createdAt)}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AdminColors.textSecondary,
                    height: 1.35,
                  ),
                ),
              ),
              isThreeLine: true,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildControlTab(AdminDashboardData? dash) {
    if (dash == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        SegmentedButton<int>(
          segments: const [
            ButtonSegment<int>(
              value: 0,
              label: Text('Kontrol Web'),
              icon: Icon(Icons.public_rounded, size: 17),
            ),
            ButtonSegment<int>(
              value: 1,
              label: Text('Menu Aplikasi'),
              icon: Icon(Icons.apps_rounded, size: 17),
            ),
          ],
          selected: {_controlSubTab},
          onSelectionChanged: (sel) {
            setState(() => _controlSubTab = sel.first);
          },
        ),
        const SizedBox(height: 14),
        if (_controlSubTab == 0) ...[
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AdminColors.sky.withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.cloud_done_rounded,
                          color: AdminColors.sky, size: 22),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Login Microsoft SSO',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                            ),
                          ),
                          SizedBox(height: 2),
                          Text(
                            'Kontrol tombol SSO pada Web & Flutter',
                            style: TextStyle(
                              fontSize: 12,
                              color: AdminColors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Switch(
                      value: dash.ssoEnabled,
                      activeTrackColor: AdminColors.emerald,
                      onChanged: _busyAction
                          ? null
                          : (val) => _runAction(() async {
                                final r = await _api.toggleSso(
                                  token: widget.session.token,
                                  enabled: val,
                                );
                                return r.message;
                              }),
                    ),
                  ],
                ),
                const Divider(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Protokoler Global Layanan',
                      style:
                          TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                    ),
                    _ModeBadge(mode: dash.globalMode),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: AdminColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AdminColors.border),
                  ),
                  child: Row(
                    children: [
                      _GlobalSegmentBtn(
                        label: 'ONLINE',
                        active: dash.globalMode == 'online',
                        color: AdminColors.emerald,
                        onTap: _busyAction
                            ? null
                            : () => _changeGlobalMode('online'),
                      ),
                      _GlobalSegmentBtn(
                        label: 'MAINT',
                        active: dash.globalMode == 'maintenance',
                        color: AdminColors.gold,
                        onTap: _busyAction
                            ? null
                            : () => _changeGlobalMode('maintenance'),
                      ),
                      _GlobalSegmentBtn(
                        label: 'OFF',
                        active: dash.globalMode == 'shutdown',
                        color: AdminColors.danger,
                        onTap: _busyAction
                            ? null
                            : () => _changeGlobalMode('shutdown'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 18),
        const _SectionHeader(
          title: 'Layanan Web & API',
          subtitle: 'Ubah status per modul layanan web',
        ),
        const SizedBox(height: 6),
        ...dash.services.map(
          (svc) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              leading: _ModeDot(mode: svc.mode),
              title: Text(
                svc.name,
                style:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: Text(
                svc.group,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AdminColors.textSecondary,
                ),
              ),
              trailing: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: AdminColors.surface,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AdminColors.border),
                ),
                child: DropdownButton<String>(
                  value: ['online', 'maintenance', 'shutdown'].contains(svc.mode)
                      ? svc.mode
                      : 'online',
                  underline: const SizedBox.shrink(),
                  dropdownColor: AdminColors.cardElevated,
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                    color: AdminColors.textPrimary,
                  ),
                  items: const [
                    DropdownMenuItem(value: 'online', child: Text('ONLINE')),
                    DropdownMenuItem(
                        value: 'maintenance', child: Text('MAINT')),
                    DropdownMenuItem(value: 'shutdown', child: Text('OFF')),
                  ],
                  onChanged: _busyAction
                      ? null
                      : (val) {
                          if (val != null && val != svc.mode) {
                            _changeServiceMode(svc, val);
                          }
                        },
                ),
              ),
            ),
          ),
        ),
        ] else ...[
          const _SectionHeader(
            title: 'Menu Aplikasi Flutter',
            subtitle: 'Kontrol ON / Maintenance / OFF menu aplikasi member',
          ),
          const SizedBox(height: 6),
          ...dash.appMenus.map(
            (m) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
                leading: _ModeDot(mode: m.mode),
                title: Text(
                  m.label,
                  style: const TextStyle(
                      fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: Text(
                  '${m.route} • ${m.group}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AdminColors.textSecondary,
                  ),
                ),
                trailing: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: AdminColors.surface,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AdminColors.border),
                  ),
                  child: DropdownButton<String>(
                    value: ['online', 'maintenance', 'off'].contains(m.mode)
                        ? m.mode
                        : 'online',
                    underline: const SizedBox.shrink(),
                    dropdownColor: AdminColors.cardElevated,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      color: AdminColors.textPrimary,
                    ),
                    items: const [
                      DropdownMenuItem(value: 'online', child: Text('ONLINE')),
                      DropdownMenuItem(
                          value: 'maintenance', child: Text('MAINT')),
                      DropdownMenuItem(value: 'off', child: Text('OFF')),
                    ],
                    onChanged: _busyAction
                        ? null
                        : (val) {
                            if (val != null && val != m.mode) {
                              _changeAppMenuMode(m, val);
                            }
                          },
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildWaTab(AdminDashboardData? dash) {
    if (dash == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: 'Antrean Total',
                value: '${dash.waQueueTotal}',
                icon: Icons.mark_chat_unread_rounded,
                color: AdminColors.gold,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Antrean KTA',
                value: '${dash.waQueueKta}',
                icon: Icons.badge_rounded,
                color: AdminColors.sky,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _StatCard(
                label: 'Non-KTA',
                value: '${dash.waQueueNonKta}',
                icon: Icons.notifications_active_rounded,
                color: AdminColors.emerald,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Card(
          child: Column(
            children: [
              SwitchListTile(
                title: const Text(
                  'Pause Semua Pengiriman WA',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
                subtitle: const Text(
                  'Hentikan sementara seluruh worker Baileys 1 & 2',
                  style: TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                ),
                value: dash.waPauseAll,
                activeTrackColor: AdminColors.danger,
                onChanged: _busyAction
                    ? null
                    : (_) => _runAction(() async {
                          final r = await _api.toggleWanotif(
                            token: widget.session.token,
                            field: 'pause_all',
                          );
                          return r.message;
                        }),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: const Text(
                  'Pause Antrean Kirim KTA',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5),
                ),
                subtitle: const Text(
                  'Tahan pengiriman kartu KTA massal, OTP tetap jalan',
                  style: TextStyle(fontSize: 12, color: AdminColors.textSecondary),
                ),
                value: dash.waPauseKta,
                activeTrackColor: AdminColors.gold,
                onChanged: _busyAction
                    ? null
                    : (_) => _runAction(() async {
                          final r = await _api.toggleWanotif(
                            token: widget.session.token,
                            field: 'pause_kta',
                          );
                          return r.message;
                        }),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ElevatedButton.icon(
          onPressed: () => _openModuleByKey('wanotif'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AdminColors.emerald,
            foregroundColor: AdminColors.bg,
            minimumSize: const Size.fromHeight(50),
          ),
          icon: const Icon(Icons.campaign_rounded),
          label: const Text('Buka Broadcast Center (WA & FCM)'),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _openModuleByKey('wanotif_antrean'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(50),
          ),
          icon: const Icon(Icons.playlist_add_check_circle_rounded),
          label: const Text('Kelola Antrean, Retry & Bersihkan'),
        ),
      ],
    );
  }

  Widget _buildModulesTab(AdminDashboardData? dash) {
    final all = dash?.modules ?? AdminModuleItem.defaults;
    final categories = <String>{'Semua', ...all.map((m) => m.category)}.toList();
    final q = _searchCtrl.text.trim().toLowerCase();
    final filtered = all.where((m) {
      final catOk = _selectedCategory == 'Semua' || m.category == _selectedCategory;
      final qOk = q.isEmpty ||
          m.title.toLowerCase().contains(q) ||
          m.desc.toLowerCase().contains(q) ||
          m.path.toLowerCase().contains(q);
      return catOk && qOk;
    }).toList();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
          child: TextField(
            controller: _searchCtrl,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              hintText: 'Cari modul adminpanel (contoh: users, ssh, berita)...',
              prefixIcon: const Icon(Icons.search_rounded),
              suffixIcon: q.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded),
                      onPressed: () {
                        _searchCtrl.clear();
                        setState(() {});
                      },
                    )
                  : null,
            ),
          ),
        ),
        SizedBox(
          height: 40,
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: categories.length,
            separatorBuilder: (_, __) => const SizedBox(width: 8),
            itemBuilder: (_, idx) {
              final cat = categories[idx];
              final selected = cat == _selectedCategory;
              return ChoiceChip(
                label: Text(cat),
                selected: selected,
                onSelected: (_) => setState(() => _selectedCategory = cat),
              );
            },
          ),
        ),
        const SizedBox(height: 10),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 12,
              mainAxisSpacing: 12,
              childAspectRatio: 1.08,
            ),
            itemCount: filtered.length,
            itemBuilder: (_, idx) {
              final mod = filtered[idx];
              final isNative = _nativeKeys.contains(mod.key);
              final accent = isNative ? AdminColors.emerald : AdminColors.sky;
              return Material(
                color: AdminColors.card,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                  side: const BorderSide(color: AdminColors.border),
                ),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () => _openModule(mod),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(9),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: accent.withValues(alpha: 0.3),
                                ),
                              ),
                              child: Icon(
                                mod.iconData,
                                color: accent,
                                size: 22,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                color: accent.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                isNative ? 'NATIVE' : 'WEB',
                                style: TextStyle(
                                  fontSize: 9.5,
                                  fontWeight: FontWeight.w900,
                                  letterSpacing: 0.5,
                                  color: accent,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Text(
                          mod.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 13.5,
                            color: AdminColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          mod.desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
                            height: 1.3,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.subtitle});
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 15.5,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 1),
        Text(
          subtitle,
          style: const TextStyle(
            fontSize: 11.5,
            color: AdminColors.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _StatusHeroCard extends StatelessWidget {
  const _StatusHeroCard({required this.dash});
  final AdminDashboardData dash;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AdminColors.heroGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AdminColors.gold.withValues(alpha: 0.35)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: AdminColors.gold.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: AdminColors.gold.withValues(alpha: 0.4),
              ),
            ),
            child: const Icon(
              Icons.admin_panel_settings_rounded,
              color: AdminColors.gold,
              size: 28,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  dash.adminJob.isNotEmpty ? dash.adminJob : 'Administrator',
                  style: const TextStyle(
                    fontWeight: FontWeight.w900,
                    fontSize: 15.5,
                    color: AdminColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'PHP ${dash.phpVersion} • SSO ${dash.ssoEnabled ? "AKTIF" : "NONAKTIF"}',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          _ModeBadge(mode: dash.globalMode),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AdminColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AdminColors.border),
      ),
      padding: const EdgeInsets.all(13),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(7),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(9),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w900,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              fontSize: 11,
              color: AdminColors.textSecondary,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AdminColors.card,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AdminColors.border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 10),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 20),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AdminColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }


}

class _GlobalSegmentBtn extends StatelessWidget {
  const _GlobalSegmentBtn({
    required this.label,
    required this.active,
    required this.color,
    required this.onTap,
  });

  final String label;
  final bool active;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: active ? color.withValues(alpha: 0.2) : Colors.transparent,
            borderRadius: BorderRadius.circular(9),
            border: active ? Border.all(color: color.withValues(alpha: 0.7)) : null,
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w800,
              color: active ? color : AdminColors.textSecondary,
            ),
          ),
        ),
      ),
    );
  }


}

class _ModeDot extends StatelessWidget {
  const _ModeDot({required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context) {
    final m = mode.toLowerCase();
    final Color c = m == 'online'
        ? AdminColors.emerald
        : (m == 'maintenance' ? AdminColors.gold : AdminColors.danger);
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: c,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: c.withValues(alpha: 0.5), blurRadius: 6),
        ],
      ),
    );
  }
}

class _ModeBadge extends StatelessWidget {
  const _ModeBadge({required this.mode});
  final String mode;

  @override
  Widget build(BuildContext context) {
    final m = mode.toLowerCase();
    final Color c;
    if (m == 'online') {
      c = AdminColors.emerald;
    } else if (m == 'maintenance') {
      c = AdminColors.gold;
    } else {
      c = AdminColors.danger;
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c.withValues(alpha: 0.7)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(color: c, shape: BoxShape.circle),
          ),
          const SizedBox(width: 6),
          Text(
            mode.toUpperCase(),
            style: TextStyle(
              color: c,
              fontWeight: FontWeight.w900,
              fontSize: 10.5,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}
