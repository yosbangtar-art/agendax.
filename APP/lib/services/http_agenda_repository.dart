import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/app_user.dart';
import '../models/appointment.dart';
import '../models/barber.dart';
import '../models/review.dart';
import '../models/service.dart';
import '../utils/format.dart';
import 'agenda_repository.dart';
import 'api_config.dart';
import 'session.dart';

/// Horario fijo del backend (main.py -> consultar_disponibilidad: slots de
/// 09:00 a 17:30, cada 30 min). El backend aún no guarda horario por barbero.
const int kBackendOpenHour = 9;
const int kBackendCloseHour = 18;

const Duration _requestTimeout = Duration(seconds: 12);

const Map<String, String> _jsonHeaders = {'Content-Type': 'application/json'};

/// Estados del backend (minúsculas, "no_asistió") <-> estados de la app.
const Map<String, String> _statusFromApi = {
  'agendada': AppointmentStatus.scheduled,
  'confirmada': AppointmentStatus.confirmed,
  'completada': AppointmentStatus.completed,
  'cancelada': AppointmentStatus.cancelled,
  'no_asistió': AppointmentStatus.noShow,
};

const Map<String, String> _statusToApi = {
  AppointmentStatus.scheduled: 'agendada',
  AppointmentStatus.confirmed: 'confirmada',
  AppointmentStatus.completed: 'completada',
  AppointmentStatus.cancelled: 'cancelada',
  AppointmentStatus.noShow: 'no_asistió',
};

/// Implementación que habla con la API FastAPI de BACKEND/main.py.
///
/// El backend se usa tal como está. Lo que le falta (ver
/// INTEGRACION_BACKEND.md) se resuelve aquí en la app cuando es posible.
class HttpAgendaRepository implements AgendaRepository {
  HttpAgendaRepository({http.Client? client, String? baseUrl})
      : _client = client ?? http.Client(),
        _baseUrl = baseUrl ?? kApiBaseUrl;

  final http.Client _client;
  final String _baseUrl;

  // ---------------------------------------------------------------------
  // Utilidades
  // ---------------------------------------------------------------------

  Uri _uri(String path, [Map<String, String>? query]) {
    final uri = Uri.parse('$_baseUrl$path');
    return query == null ? uri : uri.replace(queryParameters: query);
  }

  /// Ejecuta la petición y devuelve el JSON decodificado.
  /// Convierte cualquier fallo en un [ApiException] con mensaje para el usuario.
  Future<dynamic> _send(Future<http.Response> Function() request) async {
    http.Response response;

    try {
      response = await request().timeout(_requestTimeout);
    } catch (_) {
      throw const ApiException(
        'No se pudo conectar con el servidor. '
        'Revisa tu conexión e intenta de nuevo.',
      );
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (response.bodyBytes.isEmpty) return null;

      // El backend responde JSON en UTF-8; se decodifica a mano para que
      // las tildes y la ñ no se dañen.
      return jsonDecode(utf8.decode(response.bodyBytes));
    }

    throw ApiException(_errorDetail(response));
  }

  String _errorDetail(http.Response response) {
    try {
      final body = jsonDecode(utf8.decode(response.bodyBytes));

      if (body is Map && body['detail'] is String) {
        return body['detail'] as String;
      }
    } catch (_) {
      // cuerpo que no es JSON: se usa el mensaje genérico de abajo
    }

    if (response.statusCode == 422) {
      return 'Revisa los datos ingresados e intenta de nuevo.';
    }

    if (response.statusCode >= 500) {
      return 'El servidor tuvo un problema. Intenta de nuevo en un momento.';
    }

    return 'No se pudo completar la solicitud (${response.statusCode}).';
  }

  int _id(String value) {
    final id = int.tryParse(value);

    if (id == null) {
      throw ApiException('Identificador inválido: $value');
    }

    return id;
  }

  String _two(int n) => n.toString().padLeft(2, '0');

  /// "YYYY-MM-DD"
  String _apiDate(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

  /// "YYYY-MM-DD HH:MM" (formato que guarda y compara el backend)
  String _apiDateTime(DateTime d) =>
      '${_apiDate(d)} ${_two(d.hour)}:${_two(d.minute)}';

  DateTime _parseDateTime(String value) {
    return DateTime.parse(value.trim().replaceFirst(' ', 'T'));
  }

  String _text(Object? value) => value == null ? '' : '$value';

  // ---------------------------------------------------------------------
  // Autenticación
  // ---------------------------------------------------------------------

  UserRole? _roleFromApi(String? rol) {
    switch (rol) {
      case 'cliente':
        return UserRole.client;
      case 'barbero':
        return UserRole.barber;
      default:
        return null; // "administrador": ingresa por la web
    }
  }

  String _normalize(String text) {
    return text.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  @override
  Future<AppUser> login(String email, String password, UserRole role) async {
    final data = await _send(
      () => _client.post(
        _uri('/usuarios/login'),
        headers: _jsonHeaders,
        // La app de registro también recorta la contraseña; se mantiene igual
        // para no romper cuentas ya creadas.
        body: jsonEncode({
          'correo': email.trim(),
          'password': password.trim(),
        }),
      ),
    ) as Map<String, dynamic>;

    final user = data['usuario'] as Map<String, dynamic>;
    final apiRole = _roleFromApi(user['rol'] as String?);

    if (apiRole == null) {
      throw const ApiException(
        'Las cuentas de administrador ingresan desde la web.',
      );
    }

    if (apiRole != role) {
      throw ApiException(
        role == UserRole.client
            ? 'Esta cuenta es de barbero. Usa "Entrar como barbero".'
            : 'Esta cuenta es de cliente. Usa el inicio de sesión de clientes.',
      );
    }

    final name = _text(user['nombre']);

    if (role == UserRole.barber) {
      // El backend aún no relaciona usuario <-> barbero (ver INTEGRACION).
      // Mientras tanto se vincula por nombre.
      final barber = await _barberNamed(name);

      return AppUser(
        id: barber.id,
        name: name,
        email: _text(user['correo']),
        phone: barber.phone,
        role: UserRole.barber,
      );
    }

    return AppUser(
      id: _text(user['id']),
      name: name,
      email: _text(user['correo']),
      phone: '',
      role: UserRole.client,
    );
  }

  Future<Barber> _barberNamed(String userName) async {
    final wanted = _normalize(userName);

    for (final barber in await getBarbers()) {
      if (_normalize(barber.name) == wanted) {
        return barber;
      }
    }

    throw const ApiException(
      'Tu cuenta de barbero aún no está vinculada a un perfil de barbero. '
      'Avisa al administrador.',
    );
  }

  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    final data = await _send(
      () => _client.post(
        _uri('/usuarios/registro'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'nombre': name.trim(),
          'correo': email.trim(),
          'telefono': phone.trim(),
          'password': password.trim(),
          // Siempre cliente: el backend acepta cualquier rol que se le envíe.
          'rol': 'cliente',
        }),
      ),
    ) as Map<String, dynamic>;

    // La respuesta del backend incluye el hash de la contraseña; se ignora.
    return AppUser(
      id: _text(data['id']),
      name: _text(data['nombre']),
      email: _text(data['correo']),
      phone: _text(data['telefono']),
      role: UserRole.client,
    );
  }

  // ---------------------------------------------------------------------
  // Catálogo
  // ---------------------------------------------------------------------

  Service _serviceFrom(Map<String, dynamic> json) {
    return Service(
      id: _text(json['id']),
      name: _text(json['nombre']),
      description: _text(json['descripcion']),
      durationMinutes: (json['duracion'] as num?)?.toInt() ?? kSlotStepMinutes,
      price: (json['precio'] as num?)?.round() ?? 0,
    );
  }

  Barber _barberFrom(Map<String, dynamic> json) {
    return Barber(
      id: _text(json['id']),
      name: _text(json['nombre']),
      phone: _text(json['telefono']),
      specialty: _text(json['especialidad']),
      startHour: kBackendOpenHour,
      endHour: kBackendCloseHour,
    );
  }

  @override
  Future<List<Service>> getServices() async {
    final rows = await _send(() => _client.get(_uri('/servicios/')))
        as List<dynamic>;

    return [
      for (final row in rows) _serviceFrom(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<List<Barber>> getBarbers() async {
    final rows = await _send(() => _client.get(_uri('/barberos/')))
        as List<dynamic>;

    return [
      for (final row in rows) _barberFrom(row as Map<String, dynamic>),
    ];
  }

  // ---------------------------------------------------------------------
  // Citas
  // ---------------------------------------------------------------------

  /// La cita del backend solo trae ids. Nombres, duración y precio se
  /// completan con los catálogos de servicios y barberos.
  Appointment _appointmentFrom(
    Map<String, dynamic> json,
    Map<String, Service> services,
    Map<String, Barber> barbers,
  ) {
    final serviceId = _text(json['servicio_id']);
    final barberId = _text(json['barbero_id']);
    final clientId = _text(json['cliente_id']);

    final service = services[serviceId];
    final barber = barbers[barberId];

    // El backend no tiene endpoint para consultar usuarios, así que el nombre
    // del cliente solo se conoce cuando es el usuario de la sesión.
    final me = Session.user;
    final clientName =
        (me != null && me.role == UserRole.client && me.id == clientId)
            ? me.name
            : 'Cliente #$clientId';

    final estado = _text(json['estado']);

    return Appointment(
      id: _text(json['id']),
      clientId: clientId,
      clientName: clientName,
      serviceId: serviceId,
      serviceName: service?.name ?? 'Servicio no disponible',
      barberId: barberId,
      barberName: barber?.name ?? 'Barbero #$barberId',
      startsAt: _parseDateTime(_text(json['fecha_hora'])),
      durationMinutes: service?.durationMinutes ?? kSlotStepMinutes,
      price: service?.price ?? 0,
      status: _statusFromApi[estado] ?? estado,
    );
  }

  Future<List<Appointment>> _loadAppointments({
    String? clientId,
    String? barberId,
  }) async {
    final query = <String, String>{
      if (clientId != null) 'cliente_id': clientId,
      if (barberId != null) 'barbero_id': barberId,
    };

    final rows = await _send(
      () => _client.get(_uri('/citas/', query.isEmpty ? null : query)),
    ) as List<dynamic>;

    final services = {
      for (final service in await getServices()) service.id: service,
    };

    final barbers = {
      for (final barber in await getBarbers()) barber.id: barber,
    };

    return [
      for (final row in rows)
        _appointmentFrom(row as Map<String, dynamic>, services, barbers),
    ];
  }

  @override
  Future<List<Appointment>> getAppointments({
    String? clientId,
    String? barberId,
    DateTime? date,
  }) async {
    final all = await _loadAppointments(
      clientId: clientId,
      barberId: barberId,
    );

    // El backend no filtra por día: se hace aquí.
    final result = date == null
        ? all
        : all.where((a) => sameDay(a.startsAt, date)).toList();

    result.sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return result;
  }

  /// Parte de /barberos/{id}/disponibilidad (horas libres cada 30 min) y
  /// además descarta, aquí en la app, lo que el backend no revisa:
  /// horas pasadas, servicios que terminan después del cierre y choques con
  /// citas vigentes según la duración (el backend solo compara la hora de
  /// inicio exacta).
  @override
  Future<List<DateTime>> getAvailableSlots(
    String barberId,
    DateTime date,
    int durationMinutes, {
    String? ignoreAppointmentId,
  }) async {
    final data = await _send(
      () => _client.get(
        _uri('/barberos/${_id(barberId)}/disponibilidad', {
          'fecha': _apiDate(date),
        }),
      ),
    ) as Map<String, dynamic>;

    final free = (data['horarios_disponibles'] as List<dynamic>? ?? [])
        .map((value) => '$value')
        .toList();

    final busy = (await getAppointments(barberId: barberId, date: date))
        .where((a) => a.isActive && a.id != ignoreAppointmentId)
        .toList();

    final now = DateTime.now();
    final close = DateTime(date.year, date.month, date.day, kBackendCloseHour);
    final duration = Duration(minutes: durationMinutes);

    final slots = <DateTime>[];

    for (final label in free) {
      final parts = label.split(':');

      if (parts.length != 2) continue;

      final hour = int.tryParse(parts[0]);
      final minute = int.tryParse(parts[1]);

      if (hour == null || minute == null) continue;

      final start = DateTime(date.year, date.month, date.day, hour, minute);
      final end = start.add(duration);

      if (!start.isAfter(now)) continue;
      if (end.isAfter(close)) continue;

      final overlaps = busy.any(
        (a) => start.isBefore(a.endsAt) && end.isAfter(a.startsAt),
      );

      if (!overlaps) {
        slots.add(start);
      }
    }

    slots.sort((a, b) => a.compareTo(b));

    return slots;
  }

  @override
  Future<Appointment> createAppointment({
    required Service service,
    required Barber barber,
    required DateTime startsAt,
  }) async {
    final clientId = int.tryParse(Session.user?.id ?? '');

    if (clientId == null) {
      throw const ApiException('Debes iniciar sesión');
    }

    final data = await _send(
      () => _client.post(
        _uri('/citas/'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'cliente_id': clientId,
          'barbero_id': _id(barber.id),
          'servicio_id': _id(service.id),
          'fecha_hora': _apiDateTime(startsAt),
        }),
      ),
    ) as Map<String, dynamic>;

    return _appointmentFrom(
      data,
      {service.id: service},
      {barber.id: barber},
    );
  }

  @override
  Future<void> updateAppointmentStatus(String id, String status) async {
    final apiStatus = _statusToApi[status];

    if (apiStatus == null) {
      throw ApiException('Estado inválido: $status');
    }

    if (status == AppointmentStatus.cancelled) {
      await _send(() => _client.put(_uri('/citas/${_id(id)}/cancelar')));
      return;
    }

    await _send(
      () => _client.put(
        _uri('/citas/${_id(id)}/estado', {'nuevo_estado': apiStatus}),
      ),
    );
  }

  @override
  Future<Appointment> rescheduleAppointment(
    Appointment appointment, {
    required DateTime startsAt,
  }) async {
    if (!appointment.isActive) {
      throw const ApiException('Solo se pueden reprogramar citas vigentes');
    }

    // Regla RF-006: el backend no la valida, se hace respetar desde la app.
    if (!appointment.canReschedule) {
      throw ApiException(
        'Solo puedes reprogramar hasta '
        '${kRescheduleLimit.inHours} horas antes de la cita',
      );
    }

    final data = await _send(
      () => _client.put(
        _uri('/citas/${_id(appointment.id)}/reprogramar', {
          'nueva_fecha_hora': _apiDateTime(startsAt),
        }),
      ),
    ) as Map<String, dynamic>;

    final estado = _text(data['estado']);

    return appointment.copyWith(
      startsAt: _parseDateTime(_text(data['fecha_hora'])),
      status: _statusFromApi[estado] ?? estado,
    );
  }

  // ---------------------------------------------------------------------
  // Reseñas
  // ---------------------------------------------------------------------

  Review _reviewFrom(Map<String, dynamic> json) {
    return Review(
      id: _text(json['id']),
      appointmentId: _text(json['cita_id']),
      rating: (json['calificacion'] as num?)?.toInt() ?? 0,
      comment: _text(json['comentario']),
    );
  }

  Future<List<Review>> _fetchReviews() async {
    final rows = await _send(() => _client.get(_uri('/resenas/')))
        as List<dynamic>;

    return [
      for (final row in rows) _reviewFrom(row as Map<String, dynamic>),
    ];
  }

  @override
  Future<Review> createReview({
    required Appointment appointment,
    required int rating,
    String comment = '',
  }) async {
    // El backend no valida nada de esto, así que se revisa antes de enviar.
    if (rating < 1 || rating > 5) {
      throw const ApiException('La calificación debe ser de 1 a 5 estrellas');
    }

    if (appointment.status != AppointmentStatus.completed) {
      throw const ApiException('Solo puedes calificar citas completadas');
    }

    final existing = await _fetchReviews();

    if (existing.any((r) => r.appointmentId == appointment.id)) {
      throw const ApiException('Ya calificaste esta cita');
    }

    final text = comment.trim();

    final data = await _send(
      () => _client.post(
        _uri('/resenas/'),
        headers: _jsonHeaders,
        body: jsonEncode({
          'cita_id': _id(appointment.id),
          'calificacion': rating,
          'comentario': text.isEmpty ? null : text,
        }),
      ),
    ) as Map<String, dynamic>;

    return _reviewFrom(data);
  }

  @override
  Future<List<Review>> getReviews({String? clientId}) async {
    final reviews = await _fetchReviews();

    if (clientId == null) {
      return reviews;
    }

    // /resenas/ devuelve todas; se dejan las de las citas de este cliente.
    final rows = await _send(
      () => _client.get(_uri('/citas/', {'cliente_id': clientId})),
    ) as List<dynamic>;

    final mine = {
      for (final row in rows) _text((row as Map<String, dynamic>)['id']),
    };

    return reviews.where((r) => mine.contains(r.appointmentId)).toList();
  }
}
