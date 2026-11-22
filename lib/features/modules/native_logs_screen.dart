import 'package:flutter/material.dart';

import '../../core/admin_theme.dart';
import '../../core/date_format.dart';
import '../../services/bt_admin_api.dart';

class NativeLogsScreen extends StatefulWidget {
  const NativeLogsScreen({
    super.key,
    required this.token,
    required this.onOpenWeb,
  });

  final String token;
  final VoidCallback onOpenWeb;

  @override
  State<NativeLogsScreen> createState() => _NativeLogsScreenState();
}

class _NativeLogsScreenState extends State<NativeLogsScreen> {
  final _api = BtAdminApi();
  final _searchCtrl = TextEditingController();
  bool _loading = true;
  bool _acting = false;
  List<Map<String, dynamic>> _items = const [];
  List<Map<String, dynamic>> _blockedIps = const [];
  String _clientIp = '';
  Map<String, dynamic> _apiStats = const {};

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final q = Uri.encodeQueryComponent(_searchCtrl.text.trim());
      final data = await _api.getJson(widget.token, 'logs?search=$q');
      if (!mounted) return;
      setState(() {
        _items = (data['items'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];
        _blockedIps = (data['blocked_ips'] as List?)
                ?.whereType<Map<String, dynamic>>()
                .toList() ??
            [];
        _clientIp = (data['client_ip'] ?? '').toString();
        final st = data['login_api_stats'];
        _apiStats = st is Map<String, dynamic> ? st : const {};
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _showSnack('$e', isError: true);
    }
  }

  void _showSnack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AdminColors.danger : AdminColors.emerald,
      ),
    );
  }

  Future<void> _confirmBlockIp(String initialIp) async {
    final ipCtrl = TextEditingController(text: initialIp);
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.card,
        title: const Text('Blokir Alamat IP'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'IP yang diblokir tidak dapat mengakses web maupun API Bungtemin.',
              style: TextStyle(fontSize: 12.5, color: AdminColors.textSecondary),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: ipCtrl,
              readOnly: initialIp.isNotEmpty,
              decoration: const InputDecoration(
                labelText: 'Alamat IP',
                hintText: 'Contoh: 108.177.24.184',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              decoration: const InputDecoration(
                labelText: 'Alasan (opsional)',
                hintText: 'Contoh: Aktivitas mencurigakan',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Blokir IP'),
          ),
        ],
      ),
    );

    final targetIp = ipCtrl.text.trim();
    final reason = reasonCtrl.text.trim();
    ipCtrl.dispose();
    reasonCtrl.dispose();

    if (confirmed != true || targetIp.isEmpty) return;

    setState(() => _acting = true);
    try {
      final msg = await _api.postAction(widget.token, 'ip_block', {
        'ip': targetIp,
        'reason': reason,
      });
      _showSnack(msg);
      await _load();
    } catch (e) {
      _showSnack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _confirmUnblockIp(String ip) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AdminColors.card,
        title: const Text('Buka Blokir IP'),
        content: Text('Izinkan kembali akses dari IP $ip?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AdminColors.emerald),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Buka Blokir'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _acting = true);
    try {
      final msg = await _api.postAction(widget.token, 'ip_unblock', {'ip': ip});
      _showSnack(msg);
      await _load();
    } catch (e) {
      _showSnack('$e', isError: true);
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  void _openBlockedSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AdminColors.card,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.shield_rounded, color: AdminColors.danger),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'IP Diblokir (${_blockedIps.length})',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      _confirmBlockIp('');
                    },
                    icon: const Icon(Icons.add_rounded, size: 18),
                    label: const Text('Blokir IP'),
                  ),
                ],
              ),
              if (_clientIp.isNotEmpty) ...[
                const SizedBox(height: 6),
                Text(
                  'IP Anda saat ini: $_clientIp',
                  style: const TextStyle(
                    fontSize: 12,
                    color: AdminColors.textSecondary,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_blockedIps.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: Text(
                      'Belum ada IP yang diblokir.',
                      style: TextStyle(color: AdminColors.textSecondary),
                    ),
                  ),
                )
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 340),
                  child: ListView.separated(
                    shrinkWrap: true,
                    itemCount: _blockedIps.length,
                    separatorBuilder: (_, __) => const Divider(height: 1),
                    itemBuilder: (_, i) {
                      final b = _blockedIps[i];
                      final ip = (b['ip'] ?? '').toString();
                      final reason = (b['reason'] ?? '').toString();
                      final at = formatDateDdMmYyyy((b['blocked_at'] ?? '').toString());
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(
                          ip,
                          style: const TextStyle(
                            fontWeight: FontWeight.w700,
                            fontFamily: 'monospace',
                          ),
                        ),
                        subtitle: Text(
                          '$reason\nDiblokir: $at',
                          style: const TextStyle(
                            fontSize: 11.5,
                            color: AdminColors.textSecondary,
                          ),
                        ),
                        isThreeLine: true,
                        trailing: IconButton(
                          tooltip: 'Buka Blokir',
                          icon: const Icon(
                            Icons.lock_open_rounded,
                            color: AdminColors.emerald,
                          ),
                          onPressed: () {
                            Navigator.pop(ctx);
                            _confirmUnblockIp(ip);
                          },
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoginApiStatsCard() {
    final todayLegacy = int.tryParse('${_apiStats['today_legacy'] ?? 0}') ?? 0;
    final totalLegacy = int.tryParse('${_apiStats['total_legacy'] ?? 0}') ?? 0;
    final todayNew = int.tryParse('${_apiStats['today_loginapk'] ?? 0}') ?? 0;
    final totalNew = int.tryParse('${_apiStats['total_loginapk'] ?? 0}') ?? 0;
    final todayRej = int.tryParse('${_apiStats['today_ditolak'] ?? 0}') ?? 0;
    final totalRej = int.tryParse('${_apiStats['total_ditolak'] ?? 0}') ?? 0;

    Widget statBox(String label, int today, int total, Color color) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: color.withValues(alpha: 0.35)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: color),
              ),
              const SizedBox(height: 2),
              Text(
                '$today hari ini',
                style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800),
              ),
              Text(
                'Total: $total',
                style: const TextStyle(fontSize: 10.5, color: AdminColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Row(
        children: [
          statBox('Lama (/User/login)', todayLegacy, totalLegacy, AdminColors.gold),
          const SizedBox(width: 6),
          statBox('Baru (/loginapk)', todayNew, totalNew, AdminColors.emerald),
          const SizedBox(width: 6),
          statBox('Ditolak', todayRej, totalRej, AdminColors.danger),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Riwayat Log Login'),
        actions: [
          IconButton(
            tooltip: 'Daftar IP Diblokir (${_blockedIps.length})',
            onPressed: _openBlockedSheet,
            icon: Badge(
              isLabelVisible: _blockedIps.isNotEmpty,
              label: Text('${_blockedIps.length}'),
              backgroundColor: AdminColors.danger,
              child: const Icon(Icons.shield_rounded),
            ),
          ),
          IconButton(icon: const Icon(Icons.refresh_rounded), onPressed: _load),
          TextButton(
            onPressed: widget.onOpenWeb,
            child: const Text('Web', style: TextStyle(color: AdminColors.gold)),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildLoginApiStatsCard(),
          Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _searchCtrl,
              onSubmitted: (_) => _load(),
              decoration: InputDecoration(
                hintText: 'Cari noreg, nama, IP, via, atau device...',
                prefixIcon: const Icon(Icons.search_rounded),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.arrow_forward_rounded),
                  onPressed: _load,
                ),
              ),
            ),
          ),
          if (_acting) const LinearProgressIndicator(minHeight: 2),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _items.length,
                      itemBuilder: (_, idx) {
                        final log = _items[idx];
                        final ok = log['success'] == true;
                        final ip = (log['ip_address'] ?? '').toString().trim();
                        final ipBlocked = log['ip_blocked'] == true;
                        final formattedDate =
                            formatDateDdMmYyyy((log['created_at'] ?? '').toString());
                        final viaRaw = (log['via'] ?? '').toString().trim();
                        final viaLow = viaRaw.toLowerCase();
                        final devRaw = (log['device'] ?? '-').toString().trim();
                        final devLow = devRaw.toLowerCase();

                        // Parse label device & device ID badge
                        String devLabel = devRaw;
                        String devIdBadge = '';
                        final idMatch = RegExp(r'\[([^\]]+)\]\s*$').firstMatch(devRaw);
                        if (idMatch != null) {
                          devIdBadge = idMatch.group(1) ?? '';
                          devLabel = devRaw.substring(0, idMatch.start).trim();
                        } else if (devLow.startsWith('bt_')) {
                          devIdBadge = devRaw;
                          devLabel = 'Android App';
                        }

                        // Via badge styling
                        late final String viaLabel;
                        late final IconData viaIcon;
                        late final Color viaColor;
                        if (viaLow == 'ms_oauth' || viaLow == 'ms_oauth_app') {
                          viaLabel = viaLow == 'ms_oauth_app' ? 'MS App' : 'Microsoft';
                          viaIcon = Icons.window_rounded;
                          viaColor = AdminColors.sky;
                        } else if (viaLow.contains('android')) {
                          viaLabel = 'Android App';
                          viaIcon = Icons.android_rounded;
                          viaColor = AdminColors.emerald;
                        } else if (viaLow == 'web') {
                          viaLabel = 'Web';
                          viaIcon = Icons.language_rounded;
                          viaColor = AdminColors.indigo;
                        } else {
                          viaLabel = viaRaw.isEmpty ? 'Manual' : viaRaw;
                          viaIcon = Icons.login_rounded;
                          viaColor = AdminColors.gold;
                        }

                        // Device icon
                        late final IconData devIcon;
                        if (viaLow.contains('android') || devLow.startsWith('bt_')) {
                          devIcon = Icons.android_rounded;
                        } else if (devLow.contains('tablet') || devLow.contains('ipad')) {
                          devIcon = Icons.tablet_mac_rounded;
                        } else if (devLow.contains('mobile') ||
                            devLow.contains('android') ||
                            devLow.contains('iphone')) {
                          devIcon = Icons.smartphone_rounded;
                        } else {
                          devIcon = Icons.computer_rounded;
                        }

                        final rawNoreg = (log['noreg'] ?? '').toString().replaceAll(RegExp(r'\D+'), '');
                        final noreg8 = rawNoreg.isNotEmpty ? rawNoreg.padLeft(8, '0') : '';
                        final avatarUrl = noreg8.isNotEmpty
                            ? 'https://bungtemin.net/btapi/img/avatar/$noreg8'
                            : '';
                        final namaStr = (log['nama'] ?? '').toString().trim();
                        final initial = namaStr.isNotEmpty ? namaStr[0].toUpperCase() : 'A';

                        return Card(
                          margin: const EdgeInsets.only(bottom: 10),
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(12, 12, 8, 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Stack(
                                  clipBehavior: Clip.none,
                                  children: [
                                    CircleAvatar(
                                      radius: 22,
                                      backgroundColor: AdminColors.surface,
                                      child: ClipOval(
                                        child: avatarUrl.isNotEmpty
                                            ? Image.network(
                                                avatarUrl,
                                                width: 44,
                                                height: 44,
                                                fit: BoxFit.cover,
                                                errorBuilder: (_, __, ___) => Text(
                                                  initial,
                                                  style: const TextStyle(
                                                    fontWeight: FontWeight.w800,
                                                    color: AdminColors.textPrimary,
                                                  ),
                                                ),
                                              )
                                            : Text(
                                                initial,
                                                style: const TextStyle(
                                                  fontWeight: FontWeight.w800,
                                                  color: AdminColors.textPrimary,
                                                ),
                                              ),
                                      ),
                                    ),
                                    Positioned(
                                      right: -2,
                                      bottom: -2,
                                      child: Container(
                                        decoration: const BoxDecoration(
                                          color: AdminColors.card,
                                          shape: BoxShape.circle,
                                        ),
                                        child: Icon(
                                          ok
                                              ? Icons.check_circle_rounded
                                              : Icons.cancel_rounded,
                                          size: 15,
                                          color: ok
                                              ? AdminColors.emerald
                                              : AdminColors.danger,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              '$namaStr (${log['noreg']})',
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13.5,
                                                color: AdminColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 6),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: (ok ? AdminColors.emerald : AdminColors.danger)
                                                  .withValues(alpha: 0.16),
                                              borderRadius: BorderRadius.circular(20),
                                              border: Border.all(
                                                color: (ok ? AdminColors.emerald : AdminColors.danger)
                                                    .withValues(alpha: 0.45),
                                              ),
                                            ),
                                            child: Text(
                                              ok ? 'SUKSES' : 'GAGAL',
                                              style: TextStyle(
                                                fontSize: 10,
                                                fontWeight: FontWeight.w800,
                                                color: ok ? AdminColors.emerald : AdminColors.danger,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 6,
                                        runSpacing: 5,
                                        crossAxisAlignment: WrapCrossAlignment.center,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 7,
                                              vertical: 2.5,
                                            ),
                                            decoration: BoxDecoration(
                                              color: viaColor.withValues(alpha: 0.16),
                                              borderRadius: BorderRadius.circular(6),
                                              border: Border.all(
                                                color: viaColor.withValues(alpha: 0.45),
                                              ),
                                            ),
                                            child: Row(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                Icon(viaIcon, size: 12, color: viaColor),
                                                const SizedBox(width: 4),
                                                Text(
                                                  viaLabel,
                                                  style: TextStyle(
                                                    fontSize: 10.5,
                                                    fontWeight: FontWeight.w700,
                                                    color: viaColor,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          if (devIdBadge.isNotEmpty)
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2.5,
                                              ),
                                              decoration: BoxDecoration(
                                                color: AdminColors.surface,
                                                borderRadius: BorderRadius.circular(6),
                                                border: Border.all(
                                                  color: AdminColors.border,
                                                ),
                                              ),
                                              child: Text(
                                                devIdBadge,
                                                style: const TextStyle(
                                                  fontSize: 10,
                                                  fontFamily: 'monospace',
                                                  color: AdminColors.textSecondary,
                                                ),
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 5),
                                      Row(
                                        children: [
                                          Icon(
                                            devIcon,
                                            size: 13,
                                            color: AdminColors.textSecondary,
                                          ),
                                          const SizedBox(width: 5),
                                          Expanded(
                                            child: Text(
                                              devLabel.isEmpty ? '-' : devLabel,
                                              maxLines: 2,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11.5,
                                                color: AdminColors.textPrimary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          if (ip.isNotEmpty) ...[
                                            Icon(
                                              Icons.lan_rounded,
                                              size: 12,
                                              color: ipBlocked
                                                  ? AdminColors.danger
                                                  : AdminColors.textSecondary,
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              '$ip${ipBlocked ? ' [DIBLOKIR]' : ''}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontFamily: 'monospace',
                                                fontWeight: ipBlocked
                                                    ? FontWeight.w700
                                                    : FontWeight.w500,
                                                color: ipBlocked
                                                    ? AdminColors.danger
                                                    : AdminColors.textSecondary,
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                          ],
                                          Expanded(
                                            child: Text(
                                              formattedDate,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: AdminColors.textSecondary,
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                if (ip.isNotEmpty)
                                  IconButton(
                                    tooltip: ipBlocked
                                        ? 'Buka Blokir IP $ip'
                                        : 'Blokir IP $ip',
                                    icon: Icon(
                                      ipBlocked
                                          ? Icons.lock_open_rounded
                                          : Icons.block_rounded,
                                      color: ipBlocked
                                          ? AdminColors.emerald
                                          : AdminColors.danger,
                                    ),
                                    onPressed: _acting
                                        ? null
                                        : () => ipBlocked
                                            ? _confirmUnblockIp(ip)
                                            : _confirmBlockIp(ip),
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
