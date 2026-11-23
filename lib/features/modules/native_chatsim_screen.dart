import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;

import '../../core/admin_theme.dart';
import '../../services/bt_admin_api.dart';

class NativeChatSimScreen extends StatefulWidget {
  const NativeChatSimScreen({super.key, required this.token});
  final String token;

  @override
  State<NativeChatSimScreen> createState() => _NativeChatSimScreenState();
}

class _NativeChatSimScreenState extends State<NativeChatSimScreen>
    with SingleTickerProviderStateMixin {
  final _api = BtAdminApi();
  late final TabController _tabCtrl = TabController(length: 2, vsync: this);

  final _msgCtrl = TextEditingController();
  final _scrollCtrl = ScrollController();
  final _noregCtrl = TextEditingController(text: '00415024');
  final _namaCtrl = TextEditingController(text: 'Admin Simulasi');

  final _outgoingUrlCtrl = TextEditingController();
  final _outgoingAuthCtrl = TextEditingController();
  final _timeoutCtrl = TextEditingController(text: '25');

  String _incomingUrl = 'https://bungtemin.net/adminpanel/chatsim/incoming';
  String _incomingToken = '';
  bool _syncToCdn = false;
  bool _forwardToFlutter = false;

  bool _loading = true;
  bool _sending = false;
  bool _savingCfg = false;
  bool _testingIncoming = false;
  String? _error;

  List<Map<String, dynamic>> _messages = [];
  int _lastId = 0;
  Timer? _pollTimer;

  @override
  void initState() {
    super.initState();
    _loadState(initial: true);
    _pollTimer = Timer.periodic(
      const Duration(seconds: 3),
      (_) => _loadState(initial: false),
    );
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    _tabCtrl.dispose();
    _msgCtrl.dispose();
    _scrollCtrl.dispose();
    _noregCtrl.dispose();
    _namaCtrl.dispose();
    _outgoingUrlCtrl.dispose();
    _outgoingAuthCtrl.dispose();
    _timeoutCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadState({required bool initial}) async {
    if (initial) {
      setState(() {
        _loading = true;
        _error = null;
      });
    }
    try {
      final afterId = initial ? 0 : _lastId;
      final res = await _api.getJson(
        widget.token,
        'chatsim_state?session_key=default&after_id=$afterId',
      );
      if (!mounted) return;
      final cfg = res['config'];
      if (initial && cfg is Map) {
        _outgoingUrlCtrl.text = '${cfg['outgoing_url'] ?? ''}';
        _outgoingAuthCtrl.text = '${cfg['outgoing_auth_header'] ?? ''}';
        _timeoutCtrl.text = '${cfg['outgoing_timeout'] ?? 25}';
        _incomingUrl = '${cfg['incoming_url'] ?? _incomingUrl}';
        _incomingToken = '${cfg['incoming_token'] ?? ''}';
        _syncToCdn = cfg['sync_to_cdn'] == true;
        _forwardToFlutter = cfg['forward_to_flutter'] == true;
      }
      final incomingMsgs = (res['messages'] as List<dynamic>? ?? [])
          .whereType<Map>()
          .map((e) => Map<String, dynamic>.from(e))
          .toList();

      setState(() {
        if (initial) {
          _messages = incomingMsgs;
          _lastId = _messages.isNotEmpty
              ? int.tryParse('${_messages.last['id']}') ?? 0
              : 0;
        } else if (incomingMsgs.isNotEmpty) {
          final existing = _messages.map((m) => m['id']).toSet();
          for (final m in incomingMsgs) {
            if (!existing.contains(m['id'])) {
              _messages.add(m);
            }
            final idVal = int.tryParse('${m['id']}') ?? 0;
            if (idVal > _lastId) _lastId = idVal;
          }
        }
        _loading = false;
      });
      if (initial || incomingMsgs.isNotEmpty) {
        _scrollToBottom();
      }
    } catch (e) {
      if (!mounted) return;
      if (initial) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollCtrl.hasClients) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _send([String? preset]) async {
    final text = (preset ?? _msgCtrl.text).trim();
    if (text.isEmpty || _sending) return;
    if (preset == null) _msgCtrl.clear();
    setState(() => _sending = true);
    try {
      await _api.postAction(
        widget.token,
        'chatsim_send',
        {
          'session_key': 'default',
          'noreg': _noregCtrl.text.trim(),
          'nama': _namaCtrl.text.trim(),
          'message': text,
        },
        timeout: const Duration(seconds: 180),
      );
      await _loadState(initial: false);
    } catch (e) {
      _snack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _saveConfig({bool regenerate = false}) async {
    if (_savingCfg) return;
    setState(() => _savingCfg = true);
    try {
      final res = await _api.postJson(widget.token, 'chatsim_save_config', {
        'outgoing_url': _outgoingUrlCtrl.text.trim(),
        'outgoing_auth_header': _outgoingAuthCtrl.text.trim(),
        'outgoing_timeout': int.tryParse(_timeoutCtrl.text.trim()) ?? 25,
        'sync_to_cdn': _syncToCdn ? 1 : 0,
        'forward_to_flutter': _forwardToFlutter ? 1 : 0,
        'regenerate_token': regenerate ? 1 : 0,
      });
      if (!mounted) return;
      final newTok = '${res['incoming_token'] ?? ''}';
      if (newTok.isNotEmpty) {
        setState(() => _incomingToken = newTok);
      }
      _snack('${res['message'] ?? 'Konfigurasi disimpan.'}');
    } catch (e) {
      _snack(e.toString(), isError: true);
    } finally {
      if (mounted) setState(() => _savingCfg = false);
    }
  }

  Future<void> _testIncoming() async {
    if (_testingIncoming || _incomingToken.isEmpty) return;
    setState(() => _testingIncoming = true);
    try {
      final res = await http
          .post(
            Uri.parse(_incomingUrl),
            headers: {
              'Content-Type': 'application/json',
              'X-Webhook-Token': _incomingToken,
            },
            body: jsonEncode({
              'session_key': 'default',
              'noreg': _noregCtrl.text.trim().isEmpty ? '00415024' : _noregCtrl.text.trim(),
              'sender_name': 'Copilot Studio (BTadmin Test)',
              'reply': 'Halo! Incoming Webhook berhasil terhubung ke BTadmin & Adminpanel.',
            }),
          )
          .timeout(const Duration(seconds: 12));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        await _loadState(initial: false);
        _snack('Incoming Webhook berhasil masuk.');
      } else {
        _snack('Incoming gagal (HTTP ${res.statusCode})', isError: true);
      }
    } catch (e) {
      _snack('Error incoming: $e', isError: true);
    } finally {
      if (mounted) setState(() => _testingIncoming = false);
    }
  }

  Future<void> _clearChat() async {
    try {
      await _api.postAction(widget.token, 'chatsim_clear', {'session_key': 'default'});
      if (!mounted) return;
      setState(() {
        _messages = [];
        _lastId = 0;
      });
      _snack('Riwayat simulasi dibersihkan.');
    } catch (e) {
      _snack(e.toString(), isError: true);
    }
  }

  void _copy(String val, String label) {
    Clipboard.setData(ClipboardData(text: val));
    _snack('$label disalin.');
  }

  void _snack(String msg, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: isError ? AdminColors.danger : AdminColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Simulasi Chat & Copilot'),
        actions: [
          IconButton(
            onPressed: _clearChat,
            icon: const Icon(Icons.delete_sweep_rounded),
            tooltip: 'Bersihkan Chat',
          ),
          IconButton(
            onPressed: () => _loadState(initial: true),
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Muat Ulang',
          ),
        ],
        bottom: TabBar(
          controller: _tabCtrl,
          indicatorColor: AdminColors.accent,
          tabs: const [
            Tab(icon: Icon(Icons.forum_rounded, size: 18), text: 'Simulasi Chat'),
            Tab(icon: Icon(Icons.hub_rounded, size: 18), text: 'Konektor Webhook'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(_error!, textAlign: TextAlign.center),
                        const SizedBox(height: 12),
                        FilledButton(
                          onPressed: () => _loadState(initial: true),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                )
              : TabBarView(
                  controller: _tabCtrl,
                  children: [
                    _buildChatTab(),
                    _buildConnectorTab(),
                  ],
                ),
    );
  }

  Widget _buildChatTab() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: TextField(
                  controller: _noregCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Noreg Uji',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                flex: 3,
                child: TextField(
                  controller: _namaCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Nama Uji',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                ),
              ),
            ],
          ),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
          child: Row(
            children: [
              for (final q in const [
                'Cek status KTA saya',
                'Jadwal meeting PUK?',
                'Cara aktivasi PIN',
                'Ping workflow',
              ])
                Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: ActionChip(
                    label: Text(q, style: const TextStyle(fontSize: 12)),
                    onPressed: () => _send(q),
                  ),
                ),
            ],
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: _messages.isEmpty
              ? const Center(
                  child: Text(
                    'Belum ada pesan simulasi.\nKirim pesan di bawah atau tes Incoming Webhook.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: AdminColors.muted),
                  ),
                )
              : ListView.builder(
                  controller: _scrollCtrl,
                  padding: const EdgeInsets.all(12),
                  itemCount: _messages.length,
                  itemBuilder: (_, idx) {
                    final m = _messages[idx];
                    final role = '${m['sender_role'] ?? 'bot'}';
                    final isUser = role == 'user';
                    final isSys = role == 'system';
                    final isIncoming = m['direction'] == 'incoming';
                    return Align(
                      alignment: isSys
                          ? Alignment.center
                          : (isUser ? Alignment.centerRight : Alignment.centerLeft),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(11),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.82,
                        ),
                        decoration: BoxDecoration(
                          color: isSys
                              ? AdminColors.warning.withValues(alpha: 0.16)
                              : isUser
                                  ? AdminColors.accent.withValues(alpha: 0.22)
                                  : isIncoming
                                      ? Colors.deepPurple.withValues(alpha: 0.22)
                                      : AdminColors.surface,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isIncoming
                                ? Colors.purpleAccent.withValues(alpha: 0.4)
                                : AdminColors.border,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isSys)
                              Text(
                                '${m['sender_name'] ?? role}${isIncoming ? ' • INCOMING' : ''}',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: AdminColors.accent,
                                ),
                              ),
                            if (!isSys) const SizedBox(height: 3),
                            Text('${m['message'] ?? ''}'),
                            const SizedBox(height: 4),
                            Text(
                              '${m['created_at'] ?? ''}${(m['http_code'] ?? 0) != 0 ? ' • HTTP ${m['http_code']}' : ''}',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AdminColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _msgCtrl,
                    minLines: 1,
                    maxLines: 3,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _send(),
                    decoration: const InputDecoration(
                      hintText: 'Ketik pesan ke Outgoing Webhook...',
                      border: OutlineInputBorder(),
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: _sending ? null : () => _send(),
                  icon: _sending
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.send_rounded, size: 18),
                  label: const Text('Kirim'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildConnectorTab() {
    return ListView(
      padding: const EdgeInsets.all(14),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '1. Outgoing Webhook (Admin → Copilot Studio)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _outgoingUrlCtrl,
                  decoration: const InputDecoration(
                    labelText: 'URL HTTP Trigger Workflow',
                    hintText: 'https://...logic.azure.com:443/workflows/...',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextField(
                        controller: _outgoingAuthCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Header Auth (Opsional)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _timeoutCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          labelText: 'Timeout (s)',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Sinkronkan URL ke B.A.I.M Flutter (/new/text.txt)', style: TextStyle(fontSize: 13)),
                  value: _syncToCdn,
                  onChanged: (v) => setState(() => _syncToCdn = v),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Teruskan Incoming ke Room B.A.I.M Flutter', style: TextStyle(fontSize: 13)),
                  value: _forwardToFlutter,
                  onChanged: (v) => setState(() => _forwardToFlutter = v),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _savingCfg ? null : () => _saveConfig(),
                    icon: const Icon(Icons.save_rounded),
                    label: Text(_savingCfg ? 'Menyimpan...' : 'Simpan Konfigurasi'),
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '2. Incoming Webhook (Copilot Studio → Admin)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                ),
                const SizedBox(height: 10),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Endpoint Incoming URL', style: TextStyle(fontSize: 12, color: AdminColors.muted)),
                  subtitle: SelectableText(_incomingUrl, style: const TextStyle(fontSize: 12)),
                  trailing: IconButton(
                    icon: const Icon(Icons.copy_rounded),
                    onPressed: () => _copy(_incomingUrl, 'Incoming URL'),
                  ),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Header X-Webhook-Token', style: TextStyle(fontSize: 12, color: AdminColors.muted)),
                  subtitle: SelectableText(_incomingToken, style: const TextStyle(fontSize: 12)),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.copy_rounded),
                        onPressed: () => _copy(_incomingToken, 'Token'),
                      ),
                      IconButton(
                        icon: const Icon(Icons.sync_rounded),
                        onPressed: () => _saveConfig(regenerate: true),
                        tooltip: 'Buat Token Baru',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _testingIncoming ? null : _testIncoming,
                    icon: const Icon(Icons.bolt_rounded),
                    label: Text(_testingIncoming ? 'Mengirim...' : 'Simulasi Kirim Incoming Sekarang'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
