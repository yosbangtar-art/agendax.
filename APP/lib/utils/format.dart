String formatDate(DateTime date) {
  const days = [
    'Lunes',
    'Martes',
    'Miércoles',
    'Jueves',
    'Viernes',
    'Sábado',
    'Domingo',
  ];

  const months = [
    'Enero',
    'Febrero',
    'Marzo',
    'Abril',
    'Mayo',
    'Junio',
    'Julio',
    'Agosto',
    'Septiembre',
    'Octubre',
    'Noviembre',
    'Diciembre',
  ];

  return '${days[date.weekday - 1]}, ${date.day} de ${months[date.month - 1]}';
}

/// 25000 -> $25.000
String formatPrice(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) {
      buffer.write('.');
    }
    buffer.write(digits[i]);
  }

  return '${value < 0 ? '-' : ''}\$$buffer';
}

String formatDuration(int minutes) => '$minutes min';

/// 14:30 -> 2:30 PM
String formatTime(DateTime date) {
  final hour = date.hour % 12 == 0 ? 12 : date.hour % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final suffix = date.hour < 12 ? 'AM' : 'PM';

  return '$hour:$minute $suffix';
}

String formatHour(int hour) => formatTime(DateTime(2000, 1, 1, hour));

bool sameDay(DateTime a, DateTime b) {
  return a.year == b.year && a.month == b.month && a.day == b.day;
}

DateTime dateOnly(DateTime date) {
  return DateTime(date.year, date.month, date.day);
}
