import '../utils/format.dart';

/// Estados según el SRS: agendada, confirmada, completada, cancelada, no asistió.
class AppointmentStatus {
  static const scheduled = 'Agendada';
  static const confirmed = 'Confirmada';
  static const completed = 'Completada';
  static const cancelled = 'Cancelada';
  static const noShow = 'No asistió';
}

/// RF-006: la reprogramación se permite hasta X tiempo antes de la cita.
/// El SRS no fija el valor; 2 horas es provisional hasta que el equipo decida.
const Duration kRescheduleLimit = Duration(hours: 2);

class Appointment {
  final String id;
  final String clientId;
  final String clientName;
  final String serviceId;
  final String serviceName;
  final String barberId;
  final String barberName;
  final DateTime startsAt;
  final int durationMinutes;
  final int price;
  final String status;

  const Appointment({
    required this.id,
    required this.clientId,
    required this.clientName,
    required this.serviceId,
    required this.serviceName,
    required this.barberId,
    required this.barberName,
    required this.startsAt,
    required this.durationMinutes,
    required this.price,
    required this.status,
  });

  /// Cita vigente: agendada o confirmada.
  bool get isActive =>
      status == AppointmentStatus.scheduled ||
      status == AppointmentStatus.confirmed;

  DateTime get endsAt => startsAt.add(Duration(minutes: durationMinutes));

  bool get canReschedule =>
      isActive && startsAt.difference(DateTime.now()) >= kRescheduleLimit;

  String get dateLabel => formatDate(startsAt);
  String get timeLabel => formatTime(startsAt);
  String get priceLabel => formatPrice(price);

  Appointment copyWith({
    String? barberId,
    String? barberName,
    DateTime? startsAt,
    String? status,
  }) {
    return Appointment(
      id: id,
      clientId: clientId,
      clientName: clientName,
      serviceId: serviceId,
      serviceName: serviceName,
      barberId: barberId ?? this.barberId,
      barberName: barberName ?? this.barberName,
      startsAt: startsAt ?? this.startsAt,
      durationMinutes: durationMinutes,
      price: price,
      status: status ?? this.status,
    );
  }
}
