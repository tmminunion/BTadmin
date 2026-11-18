import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AdminSession {
  const AdminSession({
    required this.noreg,
    required this.nama,
    required this.job,
    required this.token,
  });

  final String noreg;
  final String nama;
  final String job;
  final String token;

  bool get isValid => noreg.trim().isNotEmpty && token.trim().isNotEmpty;

  Map<String, dynamic> toJson() => {
        'noreg': noreg,
        'nama': nama,
        'job': job,
        'token': token,
      };

  factory AdminSession.fromJson(Map<String, dynamic> json) {
    return AdminSession(
      noreg: (json['noreg'] ?? '').toString(),
      nama: (json['nama'] ?? '').toString(),
      job: (json['job'] ?? '').toString(),
      token: (json['token'] ?? '').toString(),
    );
  }
}

class AdminSessionStore {
  static const _kSession = 'btadmin_session_v1';
  static const _kDashboardCache = 'btadmin_dashboard_cache_v1';

  Future<AdminSession?> load() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kSession);
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw);
      if (map is Map<String, dynamic>) {
        final s = AdminSession.fromJson(map);
        return s.isValid ? s : null;
      }
    } catch (_) {}
    return null;
  }

  Future<void> save(AdminSession session) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kSession, jsonEncode(session.toJson()));
  }

  Future<void> clear() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kSession);
    await prefs.remove(_kDashboardCache);
  }

  Future<void> saveDashboardCache(String rawJson) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kDashboardCache, rawJson);
  }

  Future<String?> loadDashboardCache() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kDashboardCache);
  }
}
