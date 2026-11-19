String formatDateDdMmYyyy(String raw, {bool withTime = true}) {
  final s = raw.trim();
  if (s.isEmpty) return '-';

  final dt = DateTime.tryParse(s);
  if (dt != null) {
    final local = s.endsWith('Z') || s.contains('+') ? dt.toLocal() : dt;
    final dd = local.day.toString().padLeft(2, '0');
    final mm = local.month.toString().padLeft(2, '0');
    final yyyy = local.year.toString().padLeft(4, '0');
    if (!withTime) return '$dd-$mm-$yyyy';
    final hh = local.hour.toString().padLeft(2, '0');
    final min = local.minute.toString().padLeft(2, '0');
    return '$dd-$mm-$yyyy $hh:$min';
  }

  final m = RegExp(r'^(\d{4})-(\d{2})-(\d{2})(?:[T ](\d{2}):(\d{2}))?').firstMatch(s);
  if (m != null) {
    final datePart = '${m.group(3)}-${m.group(2)}-${m.group(1)}';
    if (!withTime || m.group(4) == null) return datePart;
    return '$datePart ${m.group(4)}:${m.group(5)}';
  }
  return s;
}
