const lbPerKg = 2.20462;

String weightText(double kg, bool useKg, {int decimals = 1}) {
  final v = useKg ? kg : kg * lbPerKg;
  final s = v.toStringAsFixed(decimals);
  final trimmed = s.contains('.') ? s.replaceAll(RegExp(r'\.?0+$'), '') : s;
  return '$trimmed ${useKg ? 'kg' : 'lb'}';
}

double toKg(double value, bool useKg) => useKg ? value : value / lbPerKg;
double fromKg(double kg, bool useKg) => useKg ? kg : kg * lbPerKg;

const weekdayShort = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const weekdayLong = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
