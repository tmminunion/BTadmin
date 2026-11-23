import 'dart:convert';
import 'dart:math';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

import '../core/admin_session.dart';
import '../core/app_login_proof.dart';
import '../models/admin_models.dart';

class BtAdminApiException implements Exception {
  BtAdminApiException(this.message, {this.statusCode});
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class BtAdminApi {
  static const String baseUrl = 'https://bungtemin.net';
  static const Duration _timeout = Duration(seconds: 20);
  static const _kUidKey = 'btadmin_device_uid';

  static String formatNoreg8(String raw) {
    final clean = raw.trim().replaceFirst(RegExp(r'^0+'), '');
    if (clean.isEmpty) return '';
    return clean.padLeft(8, '0');
  }

  Future<String> _getOrCreateUid() async {
    final prefs = await SharedPreferences.getInstance();
    final existing = prefs.getString(_kUidKey);
    if (existing != null && existing.trim().isNotEmpty) return existing;
    final rnd = Random.secure();
    final bytes = List<int>.generate(12, (_) => rnd.nextInt(256));
    final generated =
        'btadmin-${bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join()}';
    await prefs.setString(_kUidKey, generated);
    return generated;
  }

  Map<String, String> _authHeaders(String token) => {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        'Authorization': 'Bearer ${token.trim()}',
      };

  Map<String, dynamic> _decodeResponse(http.Response res, String fallbackErr) {
    dynamic decoded;
    try {
      decoded = jsonDecode(res.body);
    } catch (_) {
      throw BtAdminApiException(
        '$fallbackErr (HTTP ${res.statusCode})',
        statusCode: res.statusCode,
      );
    }
    if (decoded is! Map<String, dynamic>) {
      throw BtAdminApiException(fallbackErr, statusCode: res.statusCode);
    }
    final statusStr = (decoded['status'] ?? '').toString().toLowerCase();
    if (res.statusCode >= 400 || statusStr == 'error' || decoded['success'] == false) {
      final msg = decoded['pesan'] ?? decoded['message'] ?? fallbackErr;
      throw BtAdminApiException(msg.toString(), statusCode: res.statusCode);
    }
    return decoded;
  }

  /// Login admin memakai endpoint `/btapi/User/login/`, lalu memverifikasi hak akses ke `/btapi/AdminApp/home`.
  Future<({AdminSession session, AdminDashboardData dashboard})> login({
    required String noreg,
    required String secret,
  }) async {
    final cleanNoreg = formatNoreg8(noreg);
    if (cleanNoreg.isEmpty) {
      throw BtAdminApiException('Noreg wajib diisi.');
    }
    final uid = await _getOrCreateUid();
    final proof = AppLoginProof.buildHeader(noreg: cleanNoreg, uid: uid);
    final loginUrl = proof != null
        ? '$baseUrl/btapi/loginapk'
        : '$baseUrl/btapi/User/login/';
    final res = await http
        .post(
          Uri.parse(loginUrl),
          headers: {
            'Content-Type': 'application/json',
            if (proof != null) 'api-key': proof,
          },
          body: jsonEncode({
            'id': cleanNoreg,
            'noreg': cleanNoreg,
            'password': secret,
            'pin': secret,
            'uid': uid,
          }),
        )
        .timeout(_timeout);

    final decoded = jsonDecode(res.body);
    if (decoded is! Map<String, dynamic>) {
      throw BtAdminApiException('Respons login tidak valid.');
    }
    final nested = decoded['data'];
    final payload = nested is Map<String, dynamic> ? nested : decoded;
    final statusStr =
        (decoded['status'] ?? payload['status'] ?? '').toString().toLowerCase();
    final token = (payload['token_login'] ??
            payload['token'] ??
            decoded['token_login'] ??
            decoded['token'] ??
            '')
        .toString()
        .trim();

    if (statusStr == 'error' ||
        statusStr == 'fail' ||
        decoded['success'] == false ||
        token.isEmpty) {
      final msg = payload['pesan'] ??
          decoded['message'] ??
          decoded['pesan'] ??
          'Login gagal.';
      throw BtAdminApiException(msg.toString());
    }

    // Verifikasi hak akses Admin Panel langsung ke /btapi/AdminApp/home
    final dashboard = await fetchHome(token);
    final session = AdminSession(
      noreg: dashboard.adminNoreg.isNotEmpty
          ? dashboard.adminNoreg
          : formatNoreg8((payload['noreg'] ?? cleanNoreg).toString()),
      nama: dashboard.adminNama.isNotEmpty
          ? dashboard.adminNama
          : (payload['nama'] ?? payload['name'] ?? 'Admin').toString(),
      job: dashboard.adminJob.isNotEmpty
          ? dashboard.adminJob
          : (payload['job'] ?? 'Admin').toString(),
      token: token,
    );
    return (session: session, dashboard: dashboard);
  }

  Future<({bool waOnline, String message})> fetchWaOtpStatus() async {
    try {
      final res = await http
          .get(Uri.parse('$baseUrl/btapi/User/wa_otp_status'))
          .timeout(const Duration(seconds: 4));
      if (res.statusCode == 200) {
        final decoded = jsonDecode(res.body);
        if (decoded is Map<String, dynamic>) {
          final online = decoded['wa_online'] != false;
          final msg = (decoded['message'] ?? '').toString();
          return (waOnline: online, message: msg);
        }
      }
    } catch (_) {}
    return (waOnline: true, message: '');
  }

  Future<String> requestOtpWa({required String noreg}) async {
    final cleanNoreg = formatNoreg8(noreg);
    if (cleanNoreg.isEmpty) {
      throw BtAdminApiException('Masukkan Noreg terlebih dahulu.');
    }
    final uid = await _getOrCreateUid();
    final res = await http
        .post(
          Uri.parse('$baseUrl/btapi/User/request_otp'),
          headers: const {'Content-Type': 'application/json'},
          body: jsonEncode({'id': cleanNoreg, 'uid': uid}),
        )
        .timeout(const Duration(seconds: 25));

    final decoded = _decodeResponse(res, 'Gagal mengirim OTP WhatsApp.');
    return (decoded['message'] ?? 'Kode OTP 6 digit telah dikirim ke WhatsApp.')
        .toString();
  }

  Future<AdminDashboardData> fetchHome(String token) async {
    final res = await http
        .get(
          Uri.parse('$baseUrl/btapi/AdminApp/home'),
          headers: _authHeaders(token),
        )
        .timeout(_timeout);
    final decoded = _decodeResponse(res, 'Gagal memuat dashboard admin.');
    final data = (decoded['data'] as Map<String, dynamic>?) ?? const {};
    await AdminSessionStore().saveDashboardCache(jsonEncode(data));
    return AdminDashboardData.fromJson(data);
  }

  Future<AdminDashboardData?> loadCachedHome() async {
    final raw = await AdminSessionStore().loadDashboardCache();
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) {
        return AdminDashboardData.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }

  Future<String> updateService({
    required String token,
    required String serviceKey,
    required String mode,
    String reason = '',
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/btapi/AdminApp/update_service'),
          headers: _authHeaders(token),
          body: jsonEncode({
            'service_key': serviceKey,
            'mode': mode,
            'reason': reason,
          }),
        )
        .timeout(_timeout);
    final decoded = _decodeResponse(res, 'Gagal mengubah mode layanan.');
    return (decoded['message'] ?? 'Mode layanan diperbarui.').toString();
  }

  Future<String> updateGlobal({
    required String token,
    required String mode,
    String reason = '',
    bool applyAll = false,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/btapi/AdminApp/update_global'),
          headers: _authHeaders(token),
          body: jsonEncode({
            'mode': mode,
            'reason': reason,
            'apply_all': applyAll,
          }),
        )
        .timeout(_timeout);
    final decoded = _decodeResponse(res, 'Gagal mengubah protokoler global.');
    return (decoded['message'] ?? 'Mode global diperbarui.').toString();
  }

  Future<({bool ssoEnabled, String message})> toggleSso({
    required String token,
    bool? enabled,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/btapi/AdminApp/toggle_sso'),
          headers: _authHeaders(token),
          body: jsonEncode({
            if (enabled != null) 'enabled': enabled,
          }),
        )
        .timeout(_timeout);
    final decoded = _decodeResponse(res, 'Gagal mengubah status SSO.');
    final data = (decoded['data'] as Map<String, dynamic>?) ?? const {};
    return (
      ssoEnabled: data['sso_enabled'] == true,
      message: (decoded['message'] ?? 'Status SSO diperbarui.').toString(),
    );
  }

  Future<({bool pauseAll, bool pauseKta, String message})> toggleWanotif({
    required String token,
    required String field,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/btapi/AdminApp/toggle_wanotif'),
          headers: _authHeaders(token),
          body: jsonEncode({'field': field}),
        )
        .timeout(_timeout);
    final decoded = _decodeResponse(res, 'Gagal mengubah kontrol WA.');
    final data = (decoded['data'] as Map<String, dynamic>?) ?? const {};
    return (
      pauseAll: data['pause_all'] == true,
      pauseKta: data['pause_kta'] == true,
      message: (decoded['message'] ?? 'Kontrol WA diperbarui.').toString(),
    );
  }

  Future<String> updateAppMenu({
    required String token,
    required String key,
    required String mode,
    String maintenanceMessage = '',
    String group = '',
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/btapi/AdminApp/update_appmenu'),
          headers: _authHeaders(token),
          body: jsonEncode({
            'key': key,
            'mode': mode,
            'maintenance_message': maintenanceMessage,
            'group': group,
          }),
        )
        .timeout(_timeout);
    final decoded = _decodeResponse(res, 'Gagal mengubah menu aplikasi.');
    return (decoded['message'] ?? 'Menu aplikasi diperbarui.').toString();
  }

  /// Membuat tiket 1x pakai (60 detik) untuk membuka halaman adminpanel di WebView tanpa login ulang.
  Future<({String url, int expiresIn})> requestWebTicket({
    required String token,
    required String path,
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/btapi/AdminApp/web_ticket'),
          headers: _authHeaders(token),
          body: jsonEncode({'path': path}),
        )
        .timeout(_timeout);
    final decoded = _decodeResponse(res, 'Gagal membuat tiket WebView.');
    final data = (decoded['data'] as Map<String, dynamic>?) ?? const {};
    final url = (data['url'] ?? '').toString().trim();
    if (url.isEmpty) {
      throw BtAdminApiException('URL tiket WebView kosong.');
    }
    return (
      url: url,
      expiresIn: int.tryParse((data['expires_in'] ?? '60').toString()) ?? 60,
    );
  }

  Future<String> uploadBroadcastImage(
    String token,
    List<int> bytes,
    String filename,
  ) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/btapi/AdminApp/upload_broadcast_image'),
          headers: {
            'Authorization': 'Bearer $token',
            'Content-Type': 'application/json',
          },
          body: jsonEncode({
            'filename': filename,
            'image_base64': base64Encode(bytes),
          }),
        )
        .timeout(const Duration(seconds: 30));
    final body = jsonDecode(res.body) as Map<String, dynamic>;
    if (res.statusCode >= 200 && res.statusCode < 300 && body['status'] == 'success') {
      return (body['url'] ?? '').toString();
    }
    throw BtAdminApiException(
      (body['message'] ?? 'Gagal upload gambar').toString(),
      statusCode: res.statusCode,
    );
  }

  Future<Map<String, dynamic>> getJson(String token, String endpoint) async {
    final res = await http
        .get(
          Uri.parse('$baseUrl/btapi/AdminApp/$endpoint'),
          headers: _authHeaders(token),
        )
        .timeout(_timeout);
    final decoded = _decodeResponse(res, 'Gagal memuat data.');
    final inner = decoded['data'];
    if (inner is Map<String, dynamic>) return inner;
    return decoded;
  }

  Future<Map<String, dynamic>> postJson(
    String token,
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/btapi/AdminApp/$endpoint'),
          headers: _authHeaders(token),
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 35));
    final decoded = _decodeResponse(res, 'Aksi gagal.');
    final inner = decoded['data'];
    if (inner is Map<String, dynamic>) return inner;
    return decoded;
  }

  Future<String> postAction(
    String token,
    String endpoint,
    Map<String, dynamic> body, {
    Duration timeout = const Duration(seconds: 35),
  }) async {
    final res = await http
        .post(
          Uri.parse('$baseUrl/btapi/AdminApp/$endpoint'),
          headers: _authHeaders(token),
          body: jsonEncode(body),
        )
        .timeout(timeout);
    final decoded = _decodeResponse(res, 'Aksi gagal.');
    return (decoded['message'] ?? 'Berhasil.').toString();
  }
}
