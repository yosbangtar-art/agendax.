import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:taller/models/app_user.dart';
import 'package:taller/models/appointment.dart';
import 'package:taller/models/barber.dart';
import 'package:taller/models/service.dart';
import 'package:taller/services/agenda_repository.dart';
import 'package:taller/services/http_agenda_repository.dart';
import 'package:taller/services/session.dart';

/// Estas pruebas simulan el servidor con respuestas que tienen EXACTAMENTE
/// la forma de BACKEND/main.py y schemas.py (llaves en español, estados en
/// minúsculas, fecha_hora "YYYY-MM-DD HH:MM", parámetros por query string).

http.Response jsonResponse(Object body, [int status = 200]) {
  return http.Response.bytes(
    utf8.encode(jsonEncode(body)),
    status,
    headers: {'content-type': 'application/json'},
  );
}

HttpAgendaRepository repoWith(
  Future<http.Response> Function(http.Request request) handler,
) {
  return HttpAgendaRepository(
    client: MockClient(handler),
    baseUrl: 'http://test',
  );
}

String two(int n) => n.toString().padLeft(2, '0');

String ymd(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

DateTime tomorrow() {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1);
}

const serviceJson = {
  'id': 9,
  'nombre': 'Corte clásico',
  'descripcion': 'Acabado tradicional',
  'precio': 25000.0,
  'duracion': 30,
};

const longServiceJson = {
  'id': 10,
  'nombre': 'Corte + barba',
  'descripcion': 'Completo',
  'precio': 40000.0,
  'duracion': 50,
};

const barberJson = {
  'id': 2,
  'nombre': 'Sandro Barber',
  'telefono': '300 123 4567',
  'especialidad': 'Cortes',
};

const juan = AppUser(
  id: '7',
  name: 'Juan Pérez',
  email: 'juan@email.com',
  phone: '',
  role: UserRole.client,
);

Appointment sampleAppointment({
  required DateTime startsAt,
  String status = AppointmentStatus.scheduled,
}) {
  return Appointment(
    id: '4',
    clientId: '7',
    clientName: 'Juan Pérez',
    serviceId: '9',
    serviceName: 'Corte clásico',
    barberId: '2',
    barberName: 'Sandro Barber',
    startsAt: startsAt,
    durationMinutes: 30,
    price: 25000,
    status: status,
  );
}

void main() {
  setUp(() {
    Session.user = null;
  });

  group('autenticación', () {
    test('login de cliente: usa /usuarios/login y respeta las tildes',
        () async {
      late http.Request seen;

      final repo = repoWith((request) async {
        seen = request;
        return jsonResponse({
          'mensaje': 'Login exitoso',
          'usuario': {
            'id': 7,
            'nombre': 'Juan Pérez',
            'correo': 'juan@email.com',
            'rol': 'cliente',
          },
        });
      });

      final user = await repo.login(' juan@email.com ', 'clave1234', UserRole.client);

      expect(seen.method, 'POST');
      expect(seen.url.path, '/usuarios/login');
      expect(jsonDecode(seen.body), {
        'correo': 'juan@email.com',
        'password': 'clave1234',
      });

      expect(user.id, '7');
      expect(user.name, 'Juan Pérez');
      expect(user.role, UserRole.client);
    });

    test('credenciales incorrectas muestran el detail del backend', () async {
      final repo = repoWith((request) async {
        return jsonResponse(
          {'detail': 'Correo o contraseña incorrectos'},
          401,
        );
      });

      expect(
        () => repo.login('a@b.com', 'mala', UserRole.client),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Correo o contraseña incorrectos',
          ),
        ),
      );
    });

    test('una cuenta de administrador no entra a la app', () async {
      final repo = repoWith((request) async {
        return jsonResponse({
          'mensaje': 'Login exitoso',
          'usuario': {
            'id': 1,
            'nombre': 'Admin',
            'correo': 'admin@delux.com',
            'rol': 'administrador',
          },
        });
      });

      expect(
        () => repo.login('admin@delux.com', '12345678', UserRole.client),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('web'),
          ),
        ),
      );
    });

    test('un cliente no puede entrar por el login de barberos', () async {
      final repo = repoWith((request) async {
        return jsonResponse({
          'mensaje': 'Login exitoso',
          'usuario': {
            'id': 7,
            'nombre': 'Juan Pérez',
            'correo': 'juan@email.com',
            'rol': 'cliente',
          },
        });
      });

      expect(
        () => repo.login('juan@email.com', '12345678', UserRole.barber),
        throwsA(isA<ApiException>()),
      );
    });

    test('el barbero se vincula a su perfil por nombre', () async {
      final repo = repoWith((request) async {
        if (request.url.path == '/usuarios/login') {
          return jsonResponse({
            'mensaje': 'Login exitoso',
            'usuario': {
              'id': 20,
              'nombre': 'sandro  barber',
              'correo': 'sandro@delux.com',
              'rol': 'barbero',
            },
          });
        }

        return jsonResponse([barberJson]); // GET /barberos/
      });

      final user = await repo.login('sandro@delux.com', 'x1234567', UserRole.barber);

      // el id de sesión es el del BARBERO (2), no el del usuario (20)
      expect(user.id, '2');
      expect(user.role, UserRole.barber);
    });

    test('barbero sin perfil vinculado: mensaje claro', () async {
      final repo = repoWith((request) async {
        if (request.url.path == '/usuarios/login') {
          return jsonResponse({
            'mensaje': 'Login exitoso',
            'usuario': {
              'id': 21,
              'nombre': 'Otro Barbero',
              'correo': 'otro@delux.com',
              'rol': 'barbero',
            },
          });
        }

        return jsonResponse([barberJson]);
      });

      expect(
        () => repo.login('otro@delux.com', 'x1234567', UserRole.barber),
        throwsA(isA<ApiException>()),
      );
    });

    test('el registro siempre envía rol cliente y no devuelve el hash',
        () async {
      late Map<String, dynamic> sent;

      final repo = repoWith((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;
        return jsonResponse({
          'nombre': 'Ana',
          'correo': 'ana@email.com',
          'telefono': '300',
          'password': r'$2b$12$hashquenodebeusarselaapp',
          'rol': 'cliente',
          'id': 11,
        }, 201);
      });

      final user = await repo.register(
        name: 'Ana',
        email: 'ana@email.com',
        phone: '300',
        password: 'clave1234',
      );

      expect(sent['rol'], 'cliente');
      expect(user.id, '11');
      expect(user.role, UserRole.client);
    });

    test('correo repetido en el registro', () async {
      final repo = repoWith((request) async {
        return jsonResponse(
          {'detail': 'El correo electrónico ya está registrado'},
          400,
        );
      });

      expect(
        () => repo.register(
          name: 'Ana',
          email: 'ana@email.com',
          phone: '300',
          password: 'clave1234',
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'El correo electrónico ya está registrado',
          ),
        ),
      );
    });

    test('sin conexión: mensaje para el usuario, no una excepción cruda',
        () async {
      final repo = repoWith((request) async {
        throw http.ClientException('Connection refused');
      });

      expect(
        () => repo.getServices(),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('No se pudo conectar'),
          ),
        ),
      );
    });
  });

  group('catálogo', () {
    test('servicios: mapea nombre/precio/duración del backend', () async {
      final repo = repoWith((request) async => jsonResponse([serviceJson]));

      final services = await repo.getServices();

      expect(services.single.name, 'Corte clásico');
      expect(services.single.price, 25000);
      expect(services.single.durationMinutes, 30);
    });

    test('barberos: usa el horario fijo del backend (9 a 18)', () async {
      final repo = repoWith((request) async => jsonResponse([barberJson]));

      final barbers = await repo.getBarbers();

      expect(barbers.single.id, '2');
      expect(barbers.single.startHour, kBackendOpenHour);
      expect(barbers.single.endHour, kBackendCloseHour);
    });
  });

  group('citas', () {
    http.Response catalogs(http.Request request, Object citas) {
      switch (request.url.path) {
        case '/citas/':
          return jsonResponse(citas);
        case '/servicios/':
          return jsonResponse([serviceJson, longServiceJson]);
        case '/barberos/':
          return jsonResponse([barberJson]);
      }
      return jsonResponse({'detail': 'ruta no simulada'}, 404);
    }

    test('mapea estado "no_asistió", fecha y datos del servicio', () async {
      final repo = repoWith((request) async {
        return catalogs(request, [
          {
            'id': 1,
            'cliente_id': 5,
            'barbero_id': 2,
            'servicio_id': 9,
            'fecha_hora': '2026-11-20 10:30',
            'estado': 'no_asistió',
          },
        ]);
      });

      final list = await repo.getAppointments();
      final cita = list.single;

      expect(cita.status, AppointmentStatus.noShow);
      expect(cita.startsAt, DateTime(2026, 11, 20, 10, 30));
      expect(cita.serviceName, 'Corte clásico');
      expect(cita.barberName, 'Sandro Barber');
      expect(cita.price, 25000);
      expect(cita.durationMinutes, 30);
      // el backend no expone nombres de usuarios
      expect(cita.clientName, 'Cliente #5');
    });

    test('envía los filtros cliente_id y barbero_id al backend', () async {
      late Uri seen;

      final repo = repoWith((request) async {
        if (request.url.path == '/citas/') seen = request.url;
        return catalogs(request, []);
      });

      await repo.getAppointments(clientId: '7', barberId: '2');

      expect(seen.queryParameters['cliente_id'], '7');
      expect(seen.queryParameters['barbero_id'], '2');
    });

    test('filtra por día en la app (el backend no lo hace)', () async {
      final day = tomorrow();

      final repo = repoWith((request) async {
        return catalogs(request, [
          {
            'id': 1,
            'cliente_id': 5,
            'barbero_id': 2,
            'servicio_id': 9,
            'fecha_hora': '${ymd(day)} 10:00',
            'estado': 'agendada',
          },
          {
            'id': 2,
            'cliente_id': 5,
            'barbero_id': 2,
            'servicio_id': 9,
            'fecha_hora': '2020-01-01 10:00',
            'estado': 'agendada',
          },
        ]);
      });

      final list = await repo.getAppointments(date: day);

      expect(list.length, 1);
      expect(list.single.id, '1');
    });

    test('crear cita: ids numéricos y fecha_hora "YYYY-MM-DD HH:MM"',
        () async {
      Session.user = juan;

      final day = tomorrow();
      late Map<String, dynamic> sent;

      final repo = repoWith((request) async {
        sent = jsonDecode(request.body) as Map<String, dynamic>;

        return jsonResponse({
          'cliente_id': 7,
          'barbero_id': 2,
          'servicio_id': 9,
          'fecha_hora': '${ymd(day)} 09:30',
          'id': 33,
          'estado': 'agendada',
        }, 201);
      });

      final created = await repo.createAppointment(
        service: const Service(
          id: '9',
          name: 'Corte clásico',
          description: '',
          durationMinutes: 30,
          price: 25000,
        ),
        barber: const Barber(
          id: '2',
          name: 'Sandro Barber',
          phone: '',
          specialty: '',
        ),
        startsAt: DateTime(day.year, day.month, day.day, 9, 30),
      );

      expect(sent['cliente_id'], 7);
      expect(sent['barbero_id'], 2);
      expect(sent['servicio_id'], 9);
      expect(sent['fecha_hora'], '${ymd(day)} 09:30');
      expect(created.status, AppointmentStatus.scheduled);
      expect(created.clientName, 'Juan Pérez');
    });

    test('doble reserva: se muestra el detail del backend', () async {
      Session.user = juan;

      final repo = repoWith((request) async {
        return jsonResponse({
          'detail':
              'El barbero ya tiene una cita reservada en este horario. Por favor elija otra hora.',
        }, 400);
      });

      expect(
        () => repo.createAppointment(
          service: const Service(
            id: '9',
            name: 'Corte',
            description: '',
            durationMinutes: 30,
            price: 1,
          ),
          barber: const Barber(id: '2', name: 'S', phone: '', specialty: ''),
          startsAt: tomorrow().add(const Duration(hours: 9)),
        ),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            contains('ya tiene una cita reservada'),
          ),
        ),
      );
    });

    test('cancelar usa /cancelar; otros estados usan /estado?nuevo_estado=',
        () async {
      final seen = <http.Request>[];

      final repo = repoWith((request) async {
        seen.add(request);
        return jsonResponse({'id': 4});
      });

      await repo.updateAppointmentStatus('4', AppointmentStatus.cancelled);
      await repo.updateAppointmentStatus('4', AppointmentStatus.completed);
      await repo.updateAppointmentStatus('4', AppointmentStatus.noShow);
      await repo.updateAppointmentStatus('4', AppointmentStatus.confirmed);

      expect(seen[0].method, 'PUT');
      expect(seen[0].url.path, '/citas/4/cancelar');

      expect(seen[1].url.path, '/citas/4/estado');
      expect(seen[1].url.queryParameters['nuevo_estado'], 'completada');
      expect(seen[2].url.queryParameters['nuevo_estado'], 'no_asistió');
      expect(seen[3].url.queryParameters['nuevo_estado'], 'confirmada');
    });

    test('reprogramar: PUT con nueva_fecha_hora y vuelve a Agendada',
        () async {
      final target = DateTime.now().add(const Duration(days: 5));
      final newStart = DateTime(target.year, target.month, target.day, 15, 0);
      late Uri seen;

      final repo = repoWith((request) async {
        seen = request.url;
        return jsonResponse({
          'cliente_id': 7,
          'barbero_id': 2,
          'servicio_id': 9,
          'fecha_hora': '${ymd(newStart)} 15:00',
          'id': 4,
          'estado': 'agendada',
        });
      });

      final original = sampleAppointment(
        startsAt: DateTime.now().add(const Duration(days: 3)),
        status: AppointmentStatus.confirmed,
      );

      final moved = await repo.rescheduleAppointment(
        original,
        startsAt: newStart,
      );

      expect(seen.path, '/citas/4/reprogramar');
      expect(seen.queryParameters['nueva_fecha_hora'], '${ymd(newStart)} 15:00');
      expect(moved.status, AppointmentStatus.scheduled);
      expect(moved.startsAt, newStart);
      expect(moved.barberId, '2'); // no cambia de barbero
    });

    test('RF-006: no se reprograma con menos de 2 horas (sin llamar al servidor)',
        () async {
      var calls = 0;

      final repo = repoWith((request) async {
        calls++;
        return jsonResponse({});
      });

      final soon = sampleAppointment(
        startsAt: DateTime.now().add(const Duration(minutes: 30)),
      );

      await expectLater(
        repo.rescheduleAppointment(
          soon,
          startsAt: DateTime.now().add(const Duration(days: 2)),
        ),
        throwsA(isA<ApiException>()),
      );

      expect(calls, 0);
    });
  });

  group('disponibilidad', () {
    // El backend solo quita la hora de inicio EXACTA de las citas. La app
    // además respeta la duración, el cierre y las horas pasadas.
    HttpAgendaRepository availabilityRepo(DateTime day) {
      return repoWith((request) async {
        switch (request.url.path) {
          case '/barberos/2/disponibilidad':
            expect(request.url.queryParameters['fecha'], ymd(day));
            return jsonResponse({
              'barbero_id': 2,
              'fecha': ymd(day),
              'horarios_disponibles': [
                '09:00', '09:30', '10:00', '10:30', '11:00', '17:00', '17:30',
              ],
            });
          case '/citas/':
            return jsonResponse([
              {
                'id': 1,
                'cliente_id': 5,
                'barbero_id': 2,
                'servicio_id': 10, // corte + barba: 50 min
                'fecha_hora': '${ymd(day)} 10:00',
                'estado': 'agendada',
              },
            ]);
          case '/servicios/':
            return jsonResponse([serviceJson, longServiceJson]);
          case '/barberos/':
            return jsonResponse([barberJson]);
        }
        return jsonResponse({'detail': 'ruta no simulada'}, 404);
      });
    }

    String label(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

    test('servicio de 30 min', () async {
      final day = tomorrow();
      final slots = await availabilityRepo(day).getAvailableSlots('2', day, 30);

      // 10:00 está ocupado (cita 10:00-10:50) y 10:30 también (la hora que el
      // backend por sí solo dejaría pasar).
      expect(slots.map(label), ['09:00', '09:30', '11:00', '17:00', '17:30']);
    });

    test('servicio de 50 min: respeta duración y cierre a las 18:00', () async {
      final day = tomorrow();
      final slots = await availabilityRepo(day).getAvailableSlots('2', day, 50);

      // 09:30 + 50 min choca con la cita de las 10:00; 17:30 + 50 min pasa de
      // las 18:00.
      expect(slots.map(label), ['09:00', '11:00', '17:00']);
    });

    test('nunca ofrece horas pasadas', () async {
      final today = DateTime.now();
      final day = DateTime(today.year, today.month, today.day);

      final repo = repoWith((request) async {
        if (request.url.path == '/barberos/2/disponibilidad') {
          return jsonResponse({
            'horarios_disponibles': ['09:00', '09:30'],
          });
        }
        return jsonResponse([]); // citas, servicios y barberos vacíos
      });

      final slots = await repo.getAvailableSlots('2', day, 30);

      expect(slots.every((s) => s.isAfter(DateTime.now())), isTrue);
    });
  });

  group('reseñas', () {
    test('solo se califican citas completadas', () async {
      final repo = repoWith((request) async => jsonResponse([]));

      await expectLater(
        repo.createReview(
          appointment: sampleAppointment(
            startsAt: DateTime.now(),
            status: AppointmentStatus.scheduled,
          ),
          rating: 5,
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('evita calificar dos veces la misma cita (el backend no lo valida)',
        () async {
      final repo = repoWith((request) async {
        return jsonResponse([
          {'id': 1, 'cita_id': 4, 'calificacion': 5, 'comentario': null},
        ]);
      });

      await expectLater(
        repo.createReview(
          appointment: sampleAppointment(
            startsAt: DateTime.now(),
            status: AppointmentStatus.completed,
          ),
          rating: 4,
        ),
        throwsA(isA<ApiException>()),
      );
    });

    test('envía cita_id, calificacion y comentario', () async {
      late Map<String, dynamic> sent;

      final repo = repoWith((request) async {
        if (request.method == 'GET') return jsonResponse([]);

        sent = jsonDecode(request.body) as Map<String, dynamic>;

        return jsonResponse({
          'cita_id': 4,
          'calificacion': 5,
          'comentario': 'Excelente',
          'id': 8,
        }, 201);
      });

      final review = await repo.createReview(
        appointment: sampleAppointment(
          startsAt: DateTime.now(),
          status: AppointmentStatus.completed,
        ),
        rating: 5,
        comment: 'Excelente',
      );

      expect(sent['cita_id'], 4);
      expect(sent['calificacion'], 5);
      expect(sent['comentario'], 'Excelente');
      expect(review.id, '8');
    });

    test('getReviews deja solo las reseñas de las citas del cliente',
        () async {
      final repo = repoWith((request) async {
        if (request.url.path == '/resenas/') {
          return jsonResponse([
            {'id': 1, 'cita_id': 4, 'calificacion': 5, 'comentario': 'ok'},
            {'id': 2, 'cita_id': 99, 'calificacion': 1, 'comentario': 'otra'},
          ]);
        }

        // /citas/?cliente_id=7 -> solo la cita 4 es de este cliente
        return jsonResponse([
          {
            'id': 4,
            'cliente_id': 7,
            'barbero_id': 2,
            'servicio_id': 9,
            'fecha_hora': '2026-11-01 10:00',
            'estado': 'completada',
          },
        ]);
      });

      final reviews = await repo.getReviews(clientId: '7');

      expect(reviews.length, 1);
      expect(reviews.single.appointmentId, '4');
    });
  });
}
