import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/admin_theme.dart';
import '../../services/bt_admin_api.dart';

class _KvRow {
  _KvRow([String k = '', String v = ''])
      : keyCtrl = TextEditingController(text: k),
        valCtrl = TextEditingController(text: v);
  final TextEditingController keyCtrl;
  final TextEditingController valCtrl;
  void dispose() {
    keyCtrl.dispose();
    valCtrl.dispose();
  }
}

/// Native API Tester (ala Postman Mobile) dengan 2 konsep eksekusi:
/// 1) Direct Device (simulasi client langsung dari HP)
/// 2) NUDB Node.js Virtual Server Sandbox (via /btapi/AdminApp/apitester_exec)
class NativeApiTesterScreen extends StatefulWidget {
  const NativeApiTesterScreen({super.key, required this.token, this.onOpenWeb});
  final String token;
  final VoidCallback? onOpenWeb;

  @override
  State<NativeApiTesterScreen> createState() => _NativeApiTesterScreenState();
}

class _NativeApiTesterScreenState extends State<NativeApiTesterScreen> {
  static const _accentOrange = Color(0xFFEA580C);
  static const _histKey = 'btadmin_apitester_hist';
  static const _saveKey = 'btadmin_apitester_saved';

  final _api = BtAdminApi();
  String _mode = 'nudb_sandbox'; // 'nudb_sandbox' | 'device'
  String _method = 'POST';
  final _urlCtrl = TextEditingController(text: 'https://bungtemin.net/btapi/AppControl/status');

  String _authType = 'none'; // none | bearer | apikey | basic
  final _authValCtrl = TextEditingController();
  final _authKeyCtrl = TextEditingController(text: 'X-Webhook-Token');
  final _authUserCtrl = TextEditingController();
  final _authPassCtrl = TextEditingController();

  final List<_KvRow> _headers = [_KvRow('Accept', 'application/json'), _KvRow()];
  String _bodyType = 'raw'; // raw | form | urlencoded | graphql
  final _bodyRawCtrl = TextEditingController();
  final List<_KvRow> _formRows = [_KvRow()];

  bool _sending = false;
  int _resStatus = 0;
  int _resDurationMs = 0;
  String _resEngine = '';
  String _resBody = '';
  Map<String, dynamic> _resHeaders = const {};

  List<Map<String, dynamic>> _history = const [];
  List<Map<String, dynamic>> _saved = const [];

  @override
  void initState() {
    super.initState();
    _loadStorage();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _authValCtrl.dispose();
    _authKeyCtrl.dispose();
    _authUserCtrl.dispose();
    _authPassCtrl.dispose();
    _bodyRawCtrl.dispose();
    for (final h in _headers) {
      h.dispose();
    }
    for (final f in _formRows) {
      f.dispose();
    }
    super.dispose();
  }

  Future<void> _loadStorage() async {
    try {
      final sp = await SharedPreferences.getInstance();
      final hRaw = sp.getString(_histKey);
      final sRaw = sp.getString(_saveKey);
      if (!mounted) return;
      setState(() {
        if (hRaw != null) {
          _history = (jsonDecode(hRaw) as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
        if (sRaw != null) {
          _saved = (jsonDecode(sRaw) as List).whereType<Map>().map((e) => Map<String, dynamic>.from(e)).toList();
        }
      });
    } catch (_) {}
  }

  Future<void> _pushHistory() async {
    final item = {
      'method': _method,
      'url': _urlCtrl.text.trim(),
      'body': _bodyRawCtrl.text,
      'mode': _mode,
      'ts': DateTime.now().toIso8601String().substring(11, 19),
    };
    final next = [item, ..._history].take(20).toList();
    setState(() => _history = next);
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_histKey, jsonEncode(next));
    } catch (_) {}
  }

  Future<void> _saveCurrent() async {
    final nameCtrl = TextEditingController(text: _urlCtrl.text.trim());
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Simpan Request'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(labelText: 'Nama Koleksi', isDense: true),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
        ],
      ),
    );
    if (ok != true || nameCtrl.text.trim().isEmpty) return;
    final item = {
      'name': nameCtrl.text.trim(),
      'method': _method,
      'url': _urlCtrl.text.trim(),
      'body': _bodyRawCtrl.text,
    };
    final next = [item, ..._saved].take(30).toList();
    setState(() => _saved = next);
    try {
      final sp = await SharedPreferences.getInstance();
      await sp.setString(_saveKey, jsonEncode(next));
    } catch (_) {}
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Request tersimpan!'), backgroundColor: AdminColors.success),
      );
    }
  }

  String _prettyJson(String raw) {
    try {
      const enc = JsonEncoder.withIndent('  ');
      return enc.convert(jsonDecode(raw));
    } catch (_) {
      return raw.isEmpty ? '(empty body)' : raw;
    }
  }

  Future<void> _send() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty || !url.startsWith('http')) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Masukkan URL yang diawali http:// atau https://'), backgroundColor: AdminColors.danger),
      );
      return;
    }
    setState(() => _sending = true);
    await _pushHistory();

    final hdrList = <Map<String, String>>[];
    final hdrMap = <String, String>{};
    for (final h in _headers) {
      final k = h.keyCtrl.text.trim();
      if (k.isNotEmpty) {
        hdrList.add({'key': k, 'value': h.valCtrl.text});
        hdrMap[k] = h.valCtrl.text;
      }
    }
    final formList = <Map<String, String>>[];
    final formMap = <String, String>{};
    for (final f in _formRows) {
      final k = f.keyCtrl.text.trim();
      if (k.isNotEmpty) {
        formList.add({'key': k, 'value': f.valCtrl.text});
        formMap[k] = f.valCtrl.text;
      }
    }

    try {
      if (_mode == 'device') {
        if (_authType == 'bearer' && _authValCtrl.text.trim().isNotEmpty) {
          hdrMap['Authorization'] = 'Bearer ${_authValCtrl.text.trim()}';
        } else if (_authType == 'apikey' && _authKeyCtrl.text.trim().isNotEmpty && _authValCtrl.text.trim().isNotEmpty) {
          hdrMap[_authKeyCtrl.text.trim()] = _authValCtrl.text.trim();
        } else if (_authType == 'basic' && (_authUserCtrl.text.isNotEmpty || _authPassCtrl.text.isNotEmpty)) {
          hdrMap['Authorization'] = 'Basic ${base64Encode(utf8.encode('${_authUserCtrl.text}:${_authPassCtrl.text}'))}';
        }

        final req = http.Request(_method, Uri.parse(url));
        req.headers.addAll(hdrMap);
        if (_method != 'GET' && _method != 'HEAD') {
          if (_bodyType == 'urlencoded' || _bodyType == 'form') {
            req.bodyFields = formMap;
          } else if (_bodyType == 'graphql') {
            req.headers.putIfAbsent('Content-Type', () => 'application/json');
            req.body = jsonEncode({'query': _bodyRawCtrl.text});
          } else if (_bodyRawCtrl.text.isNotEmpty) {
            final t = _bodyRawCtrl.text.trimLeft();
            if (t.startsWith('{') || t.startsWith('[')) {
              req.headers.putIfAbsent('Content-Type', () => 'application/json');
            }
            req.body = _bodyRawCtrl.text;
          }
        }
        final sw = Stopwatch()..start();
        final streamed = await req.send().timeout(const Duration(seconds: 30));
        final resp = await http.Response.fromStream(streamed);
        sw.stop();
        if (!mounted) return;
        setState(() {
          _resStatus = resp.statusCode;
          _resDurationMs = sw.elapsedMilliseconds;
          _resEngine = 'direct_device';
          _resHeaders = resp.headers;
          _resBody = _prettyJson(resp.body);
          _sending = false;
        });
      } else {
        final res = await _api.postJson(widget.token, 'apitester_exec', {
          'method': _method,
          'url': url,
          'headers': hdrList,
          'auth_type': _authType,
          'auth_value': _authValCtrl.text.trim(),
          'auth_key': _authKeyCtrl.text.trim(),
          'auth_user': _authUserCtrl.text,
          'auth_pass': _authPassCtrl.text,
          'body_type': _bodyType,
          'body': _bodyRawCtrl.text,
          'body_form': formList,
          'engine': 'nudb',
        });
        if (!mounted) return;
        setState(() {
          _resStatus = int.tryParse('${res['http_status'] ?? 0}') ?? 0;
          _resDurationMs = int.tryParse('${res['duration_ms'] ?? 0}') ?? 0;
          _resEngine = (res['engine'] ?? 'nudb_nodejs_sandbox').toString();
          _resHeaders = (res['response_headers'] is Map)
              ? Map<String, dynamic>.from(res['response_headers'] as Map)
              : const {};
          _resBody = _prettyJson((res['response_body'] ?? res['message'] ?? res['error'] ?? '').toString());
          _sending = false;
        });
      }
      if (mounted) _showResponseSheet();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _resStatus = 0;
        _resEngine = _mode;
        _resBody = 'ERROR: ${e.toString().replaceFirst('Exception: ', '')}';
        _sending = false;
      });
      _showResponseSheet();
    }
  }

  void _showResponseSheet() {
    final ok = _resStatus >= 200 && _resStatus < 300;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(18))),
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.94,
        builder: (_, sc) => DefaultTabController(
          length: 2,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 6),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: ok ? AdminColors.success : AdminColors.danger,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        _resStatus > 0 ? 'HTTP $_resStatus' : 'ERROR',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 12),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        '$_resDurationMs ms • $_resEngine',
                        style: const TextStyle(fontSize: 11.5, color: Colors.black54, fontFamily: 'monospace'),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.copy, size: 19),
                      tooltip: 'Copy Body',
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: _resBody));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Response disalin!')),
                        );
                      },
                    ),
                  ],
                ),
              ),
              const TabBar(
                labelColor: _accentOrange,
                indicatorColor: _accentOrange,
                tabs: [Tab(text: 'Body'), Tab(text: 'Headers')],
              ),
              Expanded(
                child: TabBarView(
                  children: [
                    Container(
                      color: const Color(0xFF0F172A),
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        controller: sc,
                        child: SelectableText(
                          _resBody,
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                    Container(
                      color: const Color(0xFF0F172A),
                      padding: const EdgeInsets.all(12),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          const JsonEncoder.withIndent('  ').convert(_resHeaders),
                          style: const TextStyle(fontFamily: 'monospace', fontSize: 12, color: Color(0xFFE2E8F0)),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showHistorySheet(bool savedMode) {
    final list = savedMode ? _saved : _history;
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => ListView(
        padding: const EdgeInsets.all(12),
        children: [
          Text(
            savedMode ? 'Koleksi Tersimpan (${list.length})' : 'Riwayat Request (${list.length})',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
          ),
          const SizedBox(height: 8),
          if (list.isEmpty)
            const Padding(padding: EdgeInsets.all(20), child: Center(child: Text('Belum ada data.')))
          else
            ...list.map((it) => ListTile(
                  dense: true,
                  leading: Chip(
                    label: Text((it['method'] ?? 'GET').toString(), style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w800)),
                    visualDensity: VisualDensity.compact,
                  ),
                  title: Text((it['name'] ?? it['url'] ?? '-').toString(), maxLines: 1, overflow: TextOverflow.ellipsis),
                  subtitle: Text((it['url'] ?? '').toString(), maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
                  onTap: () {
                    setState(() {
                      _method = (it['method'] ?? 'GET').toString();
                      _urlCtrl.text = (it['url'] ?? '').toString();
                      _bodyRawCtrl.text = (it['body'] ?? '').toString();
                    });
                    Navigator.pop(ctx);
                  },
                )),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isFormBody = _bodyType == 'form' || _bodyType == 'urlencoded';
    return Scaffold(
      appBar: AppBar(
        backgroundColor: _accentOrange,
        foregroundColor: Colors.white,
        title: const Text('API Tester', style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          IconButton(icon: const Icon(Icons.history), tooltip: 'Riwayat', onPressed: () => _showHistorySheet(false)),
          IconButton(icon: const Icon(Icons.save_outlined), tooltip: 'Simpan', onPressed: _saveCurrent),
          IconButton(icon: const Icon(Icons.bookmarks_outlined), tooltip: 'Tersimpan', onPressed: () => _showHistorySheet(true)),
          if (widget.onOpenWeb != null)
            IconButton(icon: const Icon(Icons.open_in_browser), tooltip: 'Buka Web', onPressed: widget.onOpenWeb),
        ],
      ),
      body: Column(
        children: [
          // Mode Toggle: NUDB Node.js Sandbox vs Direct Device
          Container(
            color: const Color(0xFFF8FAFC),
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            child: Row(
              children: [
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('NUDB Node.js Sandbox', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                    selected: _mode == 'nudb_sandbox',
                    selectedColor: _accentOrange.withValues(alpha: 0.18),
                    onSelected: (_) => setState(() => _mode = 'nudb_sandbox'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ChoiceChip(
                    label: const Center(child: Text('Direct Device', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700))),
                    selected: _mode == 'device',
                    selectedColor: AdminColors.success.withValues(alpha: 0.18),
                    onSelected: (_) => setState(() => _mode = 'device'),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(12),
              children: [
                // Method + URL
                Row(
                  children: [
                    SizedBox(
                      width: 102,
                      child: DropdownButtonFormField<String>(
                        value: _method,
                        isDense: true,
                        decoration: const InputDecoration(border: OutlineInputBorder(), contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 10)),
                        items: const ['GET', 'POST', 'PUT', 'PATCH', 'DELETE']
                            .map((m) => DropdownMenuItem(value: m, child: Text(m, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13))))
                            .toList(),
                        onChanged: (v) => setState(() => _method = v ?? 'POST'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: _urlCtrl,
                        style: const TextStyle(fontSize: 13, fontFamily: 'monospace'),
                        decoration: const InputDecoration(
                          hintText: 'Enter Request URL',
                          isDense: true,
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 10, vertical: 11),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // Auth section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Auth', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    SizedBox(
                      width: 175,
                      child: DropdownButton<String>(
                        value: _authType,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: const [
                          DropdownMenuItem(value: 'none', child: Text('No Auth')),
                          DropdownMenuItem(value: 'bearer', child: Text('Bearer Token')),
                          DropdownMenuItem(value: 'apikey', child: Text('API Key Header')),
                          DropdownMenuItem(value: 'basic', child: Text('Basic Auth')),
                        ],
                        onChanged: (v) => setState(() => _authType = v ?? 'none'),
                      ),
                    ),
                  ],
                ),
                if (_authType == 'bearer')
                  TextField(
                    controller: _authValCtrl,
                    decoration: const InputDecoration(hintText: 'Enter Bearer Token (JWT)', isDense: true, border: OutlineInputBorder()),
                  ),
                if (_authType == 'apikey')
                  Row(
                    children: [
                      Expanded(flex: 2, child: TextField(controller: _authKeyCtrl, decoration: const InputDecoration(hintText: 'Header Key', isDense: true, border: OutlineInputBorder()))),
                      const SizedBox(width: 6),
                      Expanded(flex: 3, child: TextField(controller: _authValCtrl, decoration: const InputDecoration(hintText: 'Value', isDense: true, border: OutlineInputBorder()))),
                    ],
                  ),
                if (_authType == 'basic')
                  Row(
                    children: [
                      Expanded(child: TextField(controller: _authUserCtrl, decoration: const InputDecoration(hintText: 'Username', isDense: true, border: OutlineInputBorder()))),
                      const SizedBox(width: 6),
                      Expanded(child: TextField(controller: _authPassCtrl, obscureText: true, decoration: const InputDecoration(hintText: 'Password', isDense: true, border: OutlineInputBorder()))),
                    ],
                  ),

                const SizedBox(height: 14),
                // Headers section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Headers', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                    IconButton(
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _headers.add(_KvRow())),
                      icon: const Icon(Icons.add_circle_outline, color: _accentOrange),
                    ),
                  ],
                ),
                ...List.generate(_headers.length, (i) {
                  final row = _headers[i];
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: TextField(controller: row.keyCtrl, decoration: const InputDecoration(hintText: 'Key', isDense: true, border: OutlineInputBorder()))),
                        const SizedBox(width: 6),
                        Expanded(flex: 3, child: TextField(controller: row.valCtrl, decoration: const InputDecoration(hintText: 'Value', isDense: true, border: OutlineInputBorder()))),
                        IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => setState(() {
                            row.dispose();
                            _headers.removeAt(i);
                          }),
                          icon: const Icon(Icons.remove_circle_outline, color: AdminColors.danger, size: 20),
                        ),
                      ],
                    ),
                  );
                }),

                const SizedBox(height: 12),
                // Body section
                const Text('Body', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
                Wrap(
                  spacing: 4,
                  children: [
                    for (final entry in const [
                      ('raw', 'Raw Data'),
                      ('form', 'FORM'),
                      ('urlencoded', 'UrlEncoded'),
                      ('graphql', 'GraphQL'),
                    ])
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Radio<String>(
                            value: entry.$1,
                            groupValue: _bodyType,
                            activeColor: _accentOrange,
                            visualDensity: VisualDensity.compact,
                            onChanged: (v) => setState(() => _bodyType = v ?? 'raw'),
                          ),
                          Text(entry.$2, style: const TextStyle(fontSize: 12)),
                        ],
                      ),
                  ],
                ),
                if (!isFormBody)
                  TextField(
                    controller: _bodyRawCtrl,
                    maxLines: 6,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 12.5),
                    decoration: const InputDecoration(
                      hintText: 'JSON / Text / JavaScript / HTML / XML',
                      border: OutlineInputBorder(),
                    ),
                  )
                else ...[
                  ...List.generate(_formRows.length, (i) {
                    final row = _formRows[i];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        children: [
                          Expanded(flex: 2, child: TextField(controller: row.keyCtrl, decoration: const InputDecoration(hintText: 'Field', isDense: true, border: OutlineInputBorder()))),
                          const SizedBox(width: 6),
                          Expanded(flex: 3, child: TextField(controller: row.valCtrl, decoration: const InputDecoration(hintText: 'Value', isDense: true, border: OutlineInputBorder()))),
                          IconButton(
                            visualDensity: VisualDensity.compact,
                            onPressed: () => setState(() {
                              row.dispose();
                              _formRows.removeAt(i);
                            }),
                            icon: const Icon(Icons.remove_circle_outline, color: AdminColors.danger, size: 20),
                          ),
                        ],
                      ),
                    );
                  }),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _formRows.add(_KvRow())),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Tambah Field'),
                    ),
                  ),
                ],
                if (_resBody.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    onPressed: _showResponseSheet,
                    icon: const Icon(Icons.visibility_outlined, size: 17),
                    label: Text('Lihat Response Terakhir (${_resStatus > 0 ? 'HTTP $_resStatus' : 'Error'})'),
                  ),
                ],
              ],
            ),
          ),
          // Bottom full-width SEND bar (matching Postman mobile screenshot)
          SafeArea(
            top: false,
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: _accentOrange,
                  foregroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
                ),
                onPressed: _sending ? null : _send,
                child: _sending
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2.2, color: Colors.white))
                    : const Text('SEND', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15, letterSpacing: 1)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
