import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../../core/admin_theme.dart';
import '../../services/bt_admin_api.dart';

class CdnCodeEditorScreen extends StatefulWidget {
  const CdnCodeEditorScreen({
    super.key,
    required this.token,
    this.fileId = 0,
    this.initialFilename = '',
    this.initialMimeType = 'text/plain',
  });

  final String token;
  final int fileId;
  final String initialFilename;
  final String initialMimeType;

  @override
  State<CdnCodeEditorScreen> createState() => _CdnCodeEditorScreenState();
}

class _CdnCodeEditorScreenState extends State<CdnCodeEditorScreen> {
  final _api = BtAdminApi();
  late final TextEditingController _nameCtrl =
      TextEditingController(text: widget.initialFilename);
  late final TextEditingController _mimeCtrl =
      TextEditingController(text: widget.initialMimeType);
  final _fallbackCtrl = TextEditingController();

  late final WebViewController _webCtrl;
  bool _editorReady = false;
  bool _loading = false;
  bool _saving = false;
  bool _wordWrap = false;
  bool _fallbackMode = false;
  String _currentContent = '';
  int _cursorLine = 1;
  int _cursorCol = 1;

  static const _quickSymbols = <String>[
    '  ',
    '{',
    '}',
    '(',
    ')',
    '[',
    ']',
    '<',
    '>',
    '/',
    '=',
    '"',
    "'",
    ';',
    ':',
    r'$',
  ];

  @override
  void initState() {
    super.initState();
    _initWebView();
    if (widget.fileId > 0) {
      _loadFile();
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _mimeCtrl.dispose();
    _fallbackCtrl.dispose();
    super.dispose();
  }

  void _initWebView() {
    _webCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setBackgroundColor(const Color(0xFF1E1E1E))
      ..addJavaScriptChannel(
        'BtEditor',
        onMessageReceived: (msg) {
          try {
            final data = jsonDecode(msg.message);
            if (data is Map) {
              final type = '${data['type'] ?? ''}';
              if (type == 'ready') {
                _editorReady = true;
                _pushContentToEditor();
              } else if (type == 'change') {
                _currentContent = '${data['value'] ?? ''}';
              } else if (type == 'cursor') {
                if (mounted) {
                  setState(() {
                    _cursorLine = int.tryParse('${data['line'] ?? 1}') ?? 1;
                    _cursorCol = int.tryParse('${data['ch'] ?? 1}') ?? 1;
                  });
                }
              }
            }
          } catch (_) {}
        },
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onWebResourceError: (_) {
            if (mounted && !_editorReady) {
              setState(() {
                _fallbackMode = true;
                _fallbackCtrl.text = _currentContent;
              });
            }
          },
        ),
      )
      ..loadHtmlString(_buildEditorHtml());
  }

  Future<void> _loadFile() async {
    setState(() => _loading = true);
    try {
      final res = await _api.getJson(widget.token, 'cdn_get?id=${widget.fileId}');
      final item = res['item'] is Map ? Map<String, dynamic>.from(res['item'] as Map) : res;
      if (!mounted) return;
      _nameCtrl.text = '${item['filename'] ?? widget.initialFilename}';
      _mimeCtrl.text = '${item['mime_type'] ?? widget.initialMimeType}';
      _currentContent = '${item['content'] ?? ''}';
      _fallbackCtrl.text = _currentContent;
      setState(() => _loading = false);
      _pushContentToEditor();
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _snack(e.toString(), isError: true);
    }
  }

  String _detectMode(String filename) {
    final lower = filename.trim().toLowerCase();
    if (lower.endsWith('.html') || lower.endsWith('.htm') || lower.endsWith('.php')) {
      return 'htmlmixed';
    }
    if (lower.endsWith('.css') || lower.endsWith('.scss')) return 'css';
    if (lower.endsWith('.js') || lower.endsWith('.ts') || lower.endsWith('.json')) {
      return 'javascript';
    }
    if (lower.endsWith('.xml') || lower.endsWith('.svg')) return 'xml';
    if (lower.endsWith('.md')) return 'markdown';
    if (lower.endsWith('.sql')) return 'sql';
    return 'null';
  }

  String _detectMime(String filename) {
    final lower = filename.trim().toLowerCase();
    if (lower.endsWith('.html') || lower.endsWith('.htm')) return 'text/html';
    if (lower.endsWith('.css')) return 'text/css';
    if (lower.endsWith('.js')) return 'application/javascript';
    if (lower.endsWith('.json')) return 'application/json';
    if (lower.endsWith('.svg')) return 'image/svg+xml';
    if (lower.endsWith('.xml')) return 'application/xml';
    if (lower.endsWith('.md')) return 'text/markdown';
    return 'text/plain';
  }

  Future<void> _pushContentToEditor() async {
    if (!_editorReady || _fallbackMode) return;
    final payload = jsonEncode(_currentContent);
    final mode = jsonEncode(_detectMode(_nameCtrl.text));
    await _webCtrl.runJavaScript(
      'window.btSetContent && window.btSetContent($payload, $mode);',
    );
  }

  Future<String> _readEditorContent() async {
    if (_fallbackMode || !_editorReady) {
      return _fallbackMode ? _fallbackCtrl.text : _currentContent;
    }
    try {
      final raw = await _webCtrl.runJavaScriptReturningResult(
        'window.btGetContent ? window.btGetContent() : ""',
      );
      final s = raw.toString();
      if (s.startsWith('"') && s.endsWith('"')) {
        final decoded = jsonDecode(s);
        if (decoded is String) return decoded;
      }
    } catch (_) {}
    return _currentContent;
  }

  Future<void> _insertSymbol(String sym) async {
    if (_fallbackMode) {
      final sel = _fallbackCtrl.selection;
      final t = _fallbackCtrl.text;
      final start = sel.start >= 0 ? sel.start : t.length;
      final end = sel.end >= 0 ? sel.end : t.length;
      _fallbackCtrl.text = t.replaceRange(start, end, sym);
      _fallbackCtrl.selection = TextSelection.collapsed(offset: start + sym.length);
      return;
    }
    if (_editorReady) {
      await _webCtrl.runJavaScript('window.btInsert && window.btInsert(${jsonEncode(sym)});');
    }
  }

  Future<void> _toggleWrap() async {
    setState(() => _wordWrap = !_wordWrap);
    if (_editorReady && !_fallbackMode) {
      await _webCtrl.runJavaScript('window.btSetWrap && window.btSetWrap(${_wordWrap ? 'true' : 'false'});');
    }
  }

  Future<void> _undo() async {
    if (_editorReady && !_fallbackMode) {
      await _webCtrl.runJavaScript('window.btUndo && window.btUndo();');
    }
  }

  Future<void> _redo() async {
    if (_editorReady && !_fallbackMode) {
      await _webCtrl.runJavaScript('window.btRedo && window.btRedo();');
    }
  }

  Future<void> _openPreview() async {
    final code = await _readEditorContent();
    if (!mounted) return;
    final pvCtrl = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..loadHtmlString(code);
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => Scaffold(
          appBar: AppBar(title: Text('Preview: ${_nameCtrl.text.trim()}')),
          body: WebViewWidget(controller: pvCtrl),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final fname = _nameCtrl.text.trim();
    if (fname.isEmpty) {
      _snack('Nama file wajib diisi (contoh: new/text.txt).', isError: true);
      return;
    }
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final content = await _readEditorContent();
      final mime = _mimeCtrl.text.trim().isEmpty
          ? _detectMime(fname)
          : _mimeCtrl.text.trim();
      final msg = await _api.postAction(widget.token, 'cdn_save', {
        'id': widget.fileId,
        'filename': fname,
        'mime_type': mime,
        'content': content,
      });
      if (!mounted) return;
      _snack(msg);
      Navigator.of(context).pop(true);
    } catch (e) {
      _snack(e.toString().replaceFirst('Exception: ', ''), isError: true);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
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
      backgroundColor: const Color(0xFF1E1E1E),
      appBar: AppBar(
        backgroundColor: const Color(0xFF181818),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.fileId > 0 ? 'Code Editor' : 'File CDN Baru',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            Text(
              'Ln $_cursorLine, Col $_cursorCol • ${_detectMode(_nameCtrl.text).toUpperCase()}',
              style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
            ),
          ],
        ),
        actions: [
          IconButton(
            onPressed: _undo,
            icon: const Icon(Icons.undo_rounded, size: 20),
            tooltip: 'Undo',
          ),
          IconButton(
            onPressed: _redo,
            icon: const Icon(Icons.redo_rounded, size: 20),
            tooltip: 'Redo',
          ),
          IconButton(
            onPressed: _toggleWrap,
            icon: Icon(
              Icons.wrap_text_rounded,
              size: 20,
              color: _wordWrap ? AdminColors.accent : Colors.white70,
            ),
            tooltip: 'Word Wrap',
          ),
          IconButton(
            onPressed: _openPreview,
            icon: const Icon(Icons.play_circle_outline_rounded, size: 21),
            tooltip: 'Live Preview HTML',
          ),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: _saving
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.save_rounded, size: 17),
              label: const Text('Simpan'),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          // Bar Metadata File (Nama & MIME)
          Container(
            color: const Color(0xFF252526),
            padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: TextField(
                    controller: _nameCtrl,
                    style: const TextStyle(
                      fontSize: 13,
                      fontFamily: 'monospace',
                      color: Colors.white,
                    ),
                    onChanged: (v) {
                      if (widget.fileId == 0) {
                        _mimeCtrl.text = _detectMime(v);
                      }
                      if (_editorReady && !_fallbackMode) {
                        _webCtrl.runJavaScript(
                          'window.btSetMode && window.btSetMode(${jsonEncode(_detectMode(v))});',
                        );
                      }
                    },
                    decoration: const InputDecoration(
                      labelText: 'Path / Nama File',
                      hintText: 'contoh: new/text.txt',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
                  child: TextField(
                    controller: _mimeCtrl,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontFamily: 'monospace',
                      color: Colors.white70,
                    ),
                    decoration: const InputDecoration(
                      labelText: 'MIME',
                      isDense: true,
                      border: OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Area Editor ala Acode / VS Code
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _fallbackMode
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: TextField(
                          controller: _fallbackCtrl,
                          maxLines: null,
                          expands: true,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontSize: 13.5,
                            color: Color(0xFFD4D4D4),
                          ),
                          decoration: const InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Tulis kode di sini...',
                          ),
                        ),
                      )
                    : WebViewWidget(controller: _webCtrl),
          ),
          // Toolbar Simbol Cepat ala Acode
          SafeArea(
            top: false,
            child: Container(
              height: 40,
              color: const Color(0xFF252526),
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                itemCount: _quickSymbols.length,
                itemBuilder: (_, idx) {
                  final sym = _quickSymbols[idx];
                  final label = sym == '  ' ? 'TAB' : sym;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
                    child: InkWell(
                      onTap: () => _insertSymbol(sym),
                      borderRadius: BorderRadius.circular(6),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 11),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: const Color(0xFF333333),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          label,
                          style: const TextStyle(
                            fontFamily: 'monospace',
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                            color: Colors.white,
                          ),
                        ),
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

  String _buildEditorHtml() {
    return r'''<!DOCTYPE html>
<html>
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width,initial-scale=1,maximum-scale=1,user-scalable=no">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.css">
<link rel="stylesheet" href="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/theme/material-darker.min.css">
<style>
  html, body { margin:0; padding:0; height:100%; background:#1E1E1E; overflow:hidden; }
  .CodeMirror {
    height: 100vh !important;
    font-family: 'Fira Code', 'JetBrains Mono', ui-monospace, Menlo, Consolas, monospace;
    font-size: 13.5px;
    line-height: 1.5;
    background: #1E1E1E !important;
  }
  .CodeMirror-gutters { background: #1E1E1E !important; border-right: 1px solid #2D2D2D !important; }
  .CodeMirror-linenumber { color: #6E7681 !important; }
</style>
</head>
<body>
<textarea id="code"></textarea>
<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/codemirror.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/xml/xml.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/javascript/javascript.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/css/css.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/htmlmixed/htmlmixed.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/markdown/markdown.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/mode/sql/sql.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/addon/edit/closebrackets.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/addon/edit/matchbrackets.min.js"></script>
<script src="https://cdnjs.cloudflare.com/ajax/libs/codemirror/5.65.16/addon/selection/active-line.min.js"></script>
<script>
  var cm = CodeMirror.fromTextArea(document.getElementById('code'), {
    theme: 'material-darker',
    lineNumbers: true,
    matchBrackets: true,
    autoCloseBrackets: true,
    styleActiveLine: true,
    indentUnit: 2,
    tabSize: 2,
    lineWrapping: false
  });
  cm.on('change', function() {
    BtEditor.postMessage(JSON.stringify({ type: 'change', value: cm.getValue() }));
  });
  cm.on('cursorActivity', function() {
    var c = cm.getCursor();
    BtEditor.postMessage(JSON.stringify({ type: 'cursor', line: c.line + 1, ch: c.ch + 1 }));
  });
  window.btSetContent = function(val, mode) {
    cm.setOption('mode', mode === 'null' ? null : mode);
    cm.setValue(val || '');
    cm.clearHistory();
  };
  window.btSetMode = function(mode) {
    cm.setOption('mode', mode === 'null' ? null : mode);
  };
  window.btGetContent = function() {
    return cm.getValue();
  };
  window.btInsert = function(str) {
    cm.replaceSelection(str);
    cm.focus();
  };
  window.btSetWrap = function(flag) {
    cm.setOption('lineWrapping', !!flag);
  };
  window.btUndo = function() { cm.undo(); };
  window.btRedo = function() { cm.redo(); };
  BtEditor.postMessage(JSON.stringify({ type: 'ready' }));
</script>
</body>
</html>''';
  }
}
