import 'package:flutter/material.dart';

import '../../core/admin_session.dart';
import '../../core/admin_theme.dart';
import '../../models/admin_models.dart';
import '../../services/bt_admin_api.dart';
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

  int _tabIndex = 0;
  AdminDashboardData? _dash;
  bool _loading = true;
  bool _busyAction = false;
  String? _error;
  String _selectedCategory = 'Semua';

  @override
  void initState() {
    super.initState();
    _dash = widget.initialDashboard;
    _loading = _dash == null;
    _loadDashboard();
  }

  @override
  void dispose() {
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
        content: Text(msg),
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

  void _openModuleByKey(String key) {
    final all = _dash?.modules ?? AdminModuleItem.defaults;
    final found = all.firstWhere(
      (m) => m.key == key,
      orElse: () => all.first,
    );
    _openWebModule(found);
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
          title: Text('Ubah Mode Global -> ${mode.toUpperCase()}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: reasonCtrl,
                decoration: const InputDecoration(
                  labelText: 'Alasan / Pesan ke User',
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

  @override
  Widget build(BuildContext context) {
    final dash = _dash;
    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'BTadmin',
              style: TextStyle(
                fontWeight: FontWeight.w900,
                fontSize: 18,
                color: AdminColors.gold,
              ),
            ),
            Text(
              '${widget.session.nama} • ${widget.session.noreg}',
              style: const TextStyle(
                fontSize: 11.5,
                color: AdminColors.textSecondary,
              ),
            ),
          ],
        ),
        actions: [
          if (_busyAction)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 12),
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
            icon: const Icon(Icons.refresh_rounded),
            onPressed: _loadDashboard,
          ),
          IconButton(
            tooltip: 'Keluar',
            icon: const Icon(Icons.logout_rounded),
            onPressed: widget.onLogout,
          ),
        ],
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
      bottomNavigationBar: NavigationBar(
        backgroundColor: AdminColors.surface,
        indicatorColor: AdminColors.gold.withValues(alpha: 0.2),
        selectedIndex: _tabIndex,
        onDestinationSelected: (i) => setState(() => _tabIndex = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AdminColors.gold),
            label: 'Beranda',
          ),
          NavigationDestination(
            icon: Icon(Icons.tune_outlined),
            selectedIcon: Icon(Icons.tune_rounded, color: AdminColors.gold),
            label: 'Layanan',
          ),
          NavigationDestination(
            icon: Icon(Icons.chat_outlined),
            selectedIcon: Icon(Icons.chat_rounded, color: AdminColors.gold),
            label: 'WA & Notif',
          ),
          NavigationDestination(
            icon: Icon(Icons.apps_outlined),
            selectedIcon: Icon(Icons.apps_rounded, color: AdminColors.gold),
            label: '23 Modul',
          ),
        ],
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
      padding: const EdgeInsets.all(16),
      children: [
        if (_error != null)
          Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AdminColors.danger.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(_error!, style: const TextStyle(fontSize: 12)),
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
        const SizedBox(height: 18),
        const Text(
          'Akses Cepat Admin Panel',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _QuickChip(
              icon: Icons.space_dashboard_rounded,
              label: 'Dashboard Web',
              onTap: () => _openModuleByKey('home'),
            ),
            _QuickChip(
              icon: Icons.people_alt_rounded,
              label: 'Pengguna',
              onTap: () => _openModuleByKey('users'),
            ),
            _QuickChip(
              icon: Icons.newspaper_rounded,
              label: 'Berita & FCM',
              onTap: () => _openModuleByKey('berita'),
            ),
            _QuickChip(
              icon: Icons.auto_stories_rounded,
              label: 'Moderasi Cerita',
              onTap: () => _openModuleByKey('cerita'),
            ),
            _QuickChip(
              icon: Icons.campaign_rounded,
              label: 'Promo & APK',
              onTap: () => _openModuleByKey('promo'),
            ),
            _QuickChip(
              icon: Icons.calendar_month_rounded,
              label: 'Kalender Kerja',
              onTap: () => _openModuleByKey('kalender'),
            ),
            _QuickChip(
              icon: Icons.terminal_rounded,
              label: 'Server SSH',
              onTap: () => _openModuleByKey('ssh'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Riwayat Login Terakhir',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            TextButton(
              onPressed: () => _openModuleByKey('logs'),
              child: const Text('Lihat Semua'),
            ),
          ],
        ),
        ...dash.latestLogins.map(
          (log) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              dense: true,
              leading: Icon(
                log.success ? Icons.check_circle_rounded : Icons.cancel_rounded,
                color: log.success ? AdminColors.emerald : AdminColors.danger,
              ),
              title: Text(
                '${log.nama} (${log.noreg})',
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13.5),
              ),
              subtitle: Text(
                '${log.via} • ${log.device}\n${log.createdAt}',
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AdminColors.textSecondary,
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
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
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
                            'Aktifkan / nonaktifkan tombol SSO di Web & Flutter',
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
                const Divider(height: 22),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Protokoler Global Layanan',
                      style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                    ),
                    _ModeBadge(mode: dash.globalMode),
                  ],
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed:
                            _busyAction ? null : () => _changeGlobalMode('online'),
                        child: const Text('ONLINE'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        onPressed: _busyAction
                            ? null
                            : () => _changeGlobalMode('maintenance'),
                        child: const Text('MAINT'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AdminColors.danger,
                        ),
                        onPressed: _busyAction
                            ? null
                            : () => _changeGlobalMode('shutdown'),
                        child: const Text('OFF'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Text(
              'Kontrol Layanan Web & API',
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            TextButton(
              onPressed: () => _openModuleByKey('control'),
              child: const Text('Buka WebView'),
            ),
          ],
        ),
        ...dash.services.map(
          (svc) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              title: Text(
                svc.name,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
              ),
              subtitle: Text(
                svc.group,
                style: const TextStyle(
                  fontSize: 11.5,
                  color: AdminColors.textSecondary,
                ),
              ),
              trailing: DropdownButton<String>(
                value: ['online', 'maintenance', 'shutdown'].contains(svc.mode)
                    ? svc.mode
                    : 'online',
                underline: const SizedBox.shrink(),
                dropdownColor: AdminColors.card,
                items: const [
                  DropdownMenuItem(value: 'online', child: Text('ONLINE')),
                  DropdownMenuItem(value: 'maintenance', child: Text('MAINT')),
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
        if (dash.appMenus.isNotEmpty) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Menu Aplikasi Flutter',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
              TextButton(
                onPressed: () => _openModuleByKey('appmenus'),
                child: const Text('Atur Lengkap'),
              ),
            ],
          ),
          ...dash.appMenus.map(
            (m) => Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                title: Text(
                  m.label,
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                ),
                subtitle: Text(
                  '${m.route} • ${m.group}',
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: AdminColors.textSecondary,
                  ),
                ),
                trailing: DropdownButton<String>(
                  value: ['online', 'maintenance', 'off'].contains(m.mode)
                      ? m.mode
                      : 'online',
                  underline: const SizedBox.shrink(),
                  dropdownColor: AdminColors.card,
                  items: const [
                    DropdownMenuItem(value: 'online', child: Text('ONLINE')),
                    DropdownMenuItem(value: 'maintenance', child: Text('MAINT')),
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
        ],
      ],
    );
  }

  Widget _buildWaTab(AdminDashboardData? dash) {
    if (dash == null) return const SizedBox.shrink();
    return ListView(
      padding: const EdgeInsets.all(16),
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
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Hentikan sementara seluruh worker Baileys',
                  style: TextStyle(fontSize: 12),
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
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: const Text(
                  'Tahan pengiriman kartu KTA massal, OTP tetap jalan',
                  style: TextStyle(fontSize: 12),
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
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.campaign_rounded),
          label: const Text(
            'Buka Broadcast Center (WA & Push FCM)',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
        ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: () => _openModuleByKey('wanotif_antrean'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(48),
          ),
          icon: const Icon(Icons.playlist_add_check_circle_rounded),
          label: const Text('Kelola Antrean, Balance Bailey 1/2 & Dedup'),
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
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
          height: 42,
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
                selectedColor: AdminColors.gold.withValues(alpha: 0.25),
                onSelected: (_) => setState(() => _selectedCategory = cat),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              crossAxisSpacing: 10,
              mainAxisSpacing: 10,
              childAspectRatio: 1.15,
            ),
            itemCount: filtered.length,
            itemBuilder: (_, idx) {
              final mod = filtered[idx];
              return InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () => _openWebModule(mod),
                child: Card(
                  margin: EdgeInsets.zero,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: AdminColors.gold.withValues(alpha: 0.14),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                mod.iconData,
                                color: AdminColors.gold,
                                size: 22,
                              ),
                            ),
                            const Icon(
                              Icons.open_in_new_rounded,
                              size: 16,
                              color: AdminColors.textSecondary,
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
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          mod.desc,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 11,
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

class _StatusHeroCard extends StatelessWidget {
  const _StatusHeroCard({required this.dash});
  final AdminDashboardData dash;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AdminColors.gold.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(
                Icons.admin_panel_settings_rounded,
                color: AdminColors.gold,
                size: 28,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    dash.adminJob.isNotEmpty ? dash.adminJob : 'Administrator',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'PHP ${dash.phpVersion} • SSO ${dash.ssoEnabled ? "ON" : "OFF"}',
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
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900),
            ),
            Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 11,
                color: AdminColors.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: Icon(icon, size: 16, color: AdminColors.gold),
      label: Text(label, style: const TextStyle(fontSize: 12.5)),
      backgroundColor: AdminColors.card,
      side: const BorderSide(color: AdminColors.border),
      onPressed: onTap,
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: c),
      ),
      child: Text(
        mode.toUpperCase(),
        style: TextStyle(
          color: c,
          fontWeight: FontWeight.w800,
          fontSize: 11,
        ),
      ),
    );
  }
}
