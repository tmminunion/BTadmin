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
                        final subtitleParts = <String>[
                          '${log['via']} • ${log['device']}',
                          if (ip.isNotEmpty)
                            'IP: $ip${ipBlocked ? ' [DIBLOKIR]' : ''}',
                          formattedDate,
                        ];

                        return Card(
                          margin: const EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            leading: Icon(
                              ok
                                  ? Icons.check_circle_rounded
                                  : Icons.cancel_rounded,
                              color:
                                  ok ? AdminColors.emerald : AdminColors.danger,
                            ),
                            title: Text(
                              '${log['nama']} (${log['noreg']})',
                              style: const TextStyle(
                                  fontWeight: FontWeight.w700, fontSize: 13.5),
                            ),
                            subtitle: Text(
                              subtitleParts.join('\n'),
                              style: TextStyle(
                                fontSize: 11.5,
                                color: ipBlocked
                                    ? AdminColors.danger
                                    : AdminColors.textSecondary,
                                height: 1.35,
                              ),
                            ),
                            isThreeLine: true,
                            trailing: ip.isEmpty
                                ? null
                                : IconButton(
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
