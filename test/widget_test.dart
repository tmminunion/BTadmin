import 'package:btadmin/models/admin_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Katalog default memuat seluruh 27 modul adminpanel', () {
    expect(AdminModuleItem.defaults.length, 27);
    final paths = AdminModuleItem.defaults.map((m) => m.path).toSet();
    expect(paths.contains('/adminpanel/home'), isTrue);
    expect(paths.contains('/adminpanel/control'), isTrue);
    expect(paths.contains('/adminpanel/wanotif'), isTrue);
    expect(paths.contains('/adminpanel/wanotif/antrean'), isTrue);
    expect(paths.contains('/adminpanel/users'), isTrue);
    expect(paths.contains('/adminpanel/ssh'), isTrue);
  });

  test('AdminDashboardData mem-parsing payload API dengan aman', () {
    final dash = AdminDashboardData.fromJson({
      'admin': {'noreg': '00415024', 'nama': 'Aa Baim', 'job': 'Superadmin'},
      'stats': {'total_anggota': 5200, 'user_terhubung': 4100, 'login_hari_ini': 88},
      'sso_enabled': true,
      'service_global': {'mode': 'online', 'reason': ''},
      'wanotif': {'pause_all': false, 'pause_kta': true, 'queue_total': 12, 'queue_kta': 5, 'queue_non_kta': 7},
      'server': {'php': '8.2.15', 'time': '2026-11-19T04:40:00+07:00'},
    });

    expect(dash.adminNama, 'Aa Baim');
    expect(dash.totalAnggota, 5200);
    expect(dash.ssoEnabled, isTrue);
    expect(dash.waPauseKta, isTrue);
    expect(dash.waQueueTotal, 12);
    expect(dash.modules.length, AdminModuleItem.defaults.length);
  });
}
