import 'package:flutter_test/flutter_test.dart';
import 'package:taller/models/app_user.dart';
import 'package:taller/models/appointment.dart';
import 'package:taller/services/agenda_repository.dart';
import 'package:taller/services/mock_agenda_repository.dart';
import 'package:taller/services/session.dart';
import 'package:taller/utils/format.dart';

DateTime tomorrowAt(int hour, [int minute = 0]) {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1, hour, minute);
}

/// Pruebas del repositorio de datos de prueba (sin servidor).
void main() {
  group('formatos', () {
    test('formatPrice agrega puntos de miles', () {
      expect(formatPrice(25000), '\$25.000');
      expect(formatPrice(900), '\$900');
      expect(formatPrice(1250000), '\$1.250.000');
    });

    test('formatTime usa formato 12 horas', () {
      expect(formatTime(DateTime(2026, 1, 1, 0, 0)), '12:00 AM');
      expect(formatTime(DateTime(2026, 1, 1, 9, 5)), '9:05 AM');
      expect(formatTime(DateTime(2026, 1, 1, 15, 30)), '3:30 PM');
    });
  });

  group('MockAgendaRepository', () {
    late MockAgendaRepository repo;

    setUp(() {
      repo = MockAgendaRepository();
      Session.user = null;
    });

    Future<void> loginJuan() async {
      Session.user = await repo.login(
        'juan@email.com',
        '12345678',
        UserRole.client,
      );
    }

    test('login correcto e incorrecto', () async {
      final user = await repo.login(
        'juan@email.com',
        '12345678',
        UserRole.client,
      );
      expect(user.name, 'Juan Pérez');

      expect(
        () => repo.login('juan@email.com', 'otra-clave', UserRole.client),
        throwsA(isA<ApiException>()),
      );

      // una cuenta de cliente no entra por el login de barberos
      expect(
        () => repo.login('juan@email.com', '12345678', UserRole.barber),
        throwsA(isA<ApiException>()),
      );
    });

    test('la cita nueva nace en estado Agendada', () async {
      await loginJuan();

      final services = await repo.getServices();
      final barbers = await repo.getBarbers();

      final created = await repo.createAppointment(
        service: services.first,
        barber: barbers.firstWhere((b) => b.id == 'b2'),
        startsAt: tomorrowAt(9),
      );

      expect(created.status, AppointmentStatus.scheduled);
      expect(created.clientId, 'u1');
    });

    test('no se puede reservar un horario ocupado', () async {
      await loginJuan();

      final services = await repo.getServices();
      final barbers = await repo.getBarbers();
      final sandro = barbers.firstWhere((b) => b.id == 'b1');

      // Sandro ya tiene una cita mañana a las 11:00 en los datos de prueba
      expect(
        () => repo.createAppointment(
          service: services.first,
          barber: sandro,
          startsAt: tomorrowAt(11),
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('la duración del servicio evita traslapes', () async {
      await loginJuan();

      final services = await repo.getServices();
      final barbers = await repo.getBarbers();
      final sandro = barbers.firstWhere((b) => b.id == 'b1');

      final corteBarba = services.firstWhere((s) => s.id == 's2'); // 50 min
      final corte = services.firstWhere((s) => s.id == 's1'); // 30 min

      // 10:30 + 50 min = 11:20 -> choca con la cita de las 11:00
      expect(
        () => repo.createAppointment(
          service: corteBarba,
          barber: sandro,
          startsAt: tomorrowAt(10, 30),
        ),
        throwsA(isA<ApiException>()),
      );

      // 10:30 + 30 min = 11:00 -> justo antes de la cita, sí cabe
      final ok = await repo.createAppointment(
        service: corte,
        barber: sandro,
        startsAt: tomorrowAt(10, 30),
      );
      expect(ok.endsAt, tomorrowAt(11));
    });

    test('la disponibilidad depende de la duración', () async {
      final day = tomorrowAt(0);

      final corto = await repo.getAvailableSlots('b1', day, 30);
      final largo = await repo.getAvailableSlots('b1', day, 50);

      bool has(List<DateTime> slots, int h, int m) =>
          slots.any((s) => s.hour == h && s.minute == m);

      // 30 min: 10:30 cabe (termina 11:00); 50 min: 10:30 no cabe
      expect(has(corto, 10, 30), isTrue);
      expect(has(largo, 10, 30), isFalse);

      // 11:00 está ocupado en ambos casos
      expect(has(corto, 11, 0), isFalse);
      expect(has(largo, 11, 0), isFalse);

      // Nunca se ofrece un horario que termine después de la salida (17:00)
      expect(has(largo, 16, 30), isFalse);
      expect(has(corto, 16, 30), isTrue);
    });

    test('cancelar libera el horario', () async {
      final day = tomorrowAt(0);

      var slots = await repo.getAvailableSlots('b1', day, 30);
      expect(slots.any((s) => s.hour == 11 && s.minute == 0), isFalse);

      await repo.updateAppointmentStatus('p1', AppointmentStatus.cancelled);

      slots = await repo.getAvailableSlots('b1', day, 30);
      expect(slots.any((s) => s.hour == 11 && s.minute == 0), isTrue);
    });

    test('reprogramar libera el horario anterior y vuelve a Agendada',
        () async {
      await repo.updateAppointmentStatus('p1', AppointmentStatus.confirmed);

      final all = await repo.getAppointments(clientId: 'u1');
      final p1 = all.firstWhere((a) => a.id == 'p1');

      final moved = await repo.rescheduleAppointment(
        p1,
        startsAt: tomorrowAt(15),
      );

      expect(moved.status, AppointmentStatus.scheduled);
      expect(moved.startsAt, tomorrowAt(15));
      expect(moved.barberId, p1.barberId); // el barbero se mantiene

      final slots = await repo.getAvailableSlots('b1', tomorrowAt(0), 30);
      expect(slots.any((s) => s.hour == 11 && s.minute == 0), isTrue);
      expect(slots.any((s) => s.hour == 15 && s.minute == 0), isFalse);
    });

    test('un cliente solo ve sus propias citas', () async {
      final mine = await repo.getAppointments(clientId: 'u1');

      expect(mine.isNotEmpty, isTrue);
      expect(mine.every((a) => a.clientId == 'u1'), isTrue);
    });

    test('reseñas: solo citas completadas, una por cita, 1 a 5 estrellas',
        () async {
      await loginJuan();

      final mine = await repo.getAppointments(clientId: 'u1');
      final completed =
          mine.firstWhere((a) => a.status == AppointmentStatus.completed);
      final scheduled =
          mine.firstWhere((a) => a.status == AppointmentStatus.scheduled);

      expect(
        () => repo.createReview(appointment: scheduled, rating: 5),
        throwsA(isA<ApiException>()),
      );

      expect(
        () => repo.createReview(appointment: completed, rating: 0),
        throwsA(isA<ApiException>()),
      );

      final review = await repo.createReview(
        appointment: completed,
        rating: 5,
        comment: 'Excelente',
      );
      expect(review.rating, 5);

      expect(
        () => repo.createReview(appointment: completed, rating: 4),
        throwsA(isA<ApiException>()),
      );

      final reviews = await repo.getReviews(clientId: 'u1');
      expect(reviews.length, 1);
    });
  });
}
