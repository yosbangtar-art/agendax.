import '../models/app_user.dart';
import '../models/appointment.dart';
import '../models/barber.dart';
import '../models/review.dart';
import '../models/service.dart';
import '../utils/format.dart';
import 'agenda_repository.dart';
import 'session.dart';

/// Implementación en memoria para desarrollar sin backend.
///
/// Cuentas de prueba (clave 12345678):
///   cliente:  juan@email.com
///   barberos: sandro@delux.com, carlos@delux.com, mateo@delux.com
class MockAgendaRepository implements AgendaRepository {
  MockAgendaRepository() {
    _seed();
  }

  int _nextId = 100;

  final List<Service> _services = [];
  final List<Barber> _barbers = [];
  final List<Appointment> _appointments = [];
  final List<Review> _reviews = [];
  final Map<String, AppUser> _users = {};
  final Map<String, String> _passwords = {};

  Future<void> _delay() {
    return Future.delayed(const Duration(milliseconds: 250));
  }

  String _newId(String prefix) => '$prefix${_nextId++}';

  void _addUser(AppUser user, String password) {
    final key = user.email.trim().toLowerCase();
    _users[key] = user;
    _passwords[key] = password;
  }

  void _seed() {
    _services.addAll(const [
      Service(
        id: 's1',
        name: 'Corte clásico',
        description: 'Acabado tradicional a tijera o máquina',
        durationMinutes: 30,
        price: 25000,
      ),
      Service(
        id: 's2',
        name: 'Corte + barba',
        description: 'El servicio completo Delux',
        durationMinutes: 50,
        price: 40000,
      ),
      Service(
        id: 's3',
        name: 'Afeitado',
        description: 'Toalla caliente y navaja premium',
        durationMinutes: 20,
        price: 18000,
      ),
    ]);

    const barbers = [
      Barber(
        id: 'b1',
        name: 'Sandro Barber',
        phone: '300 123 4567',
        specialty: 'Corte clásico',
        startHour: 8,
        endHour: 17,
      ),
      Barber(
        id: 'b2',
        name: 'Carlos King',
        phone: '300 222 3344',
        specialty: 'Barba y afeitado',
        startHour: 9,
        endHour: 18,
      ),
      Barber(
        id: 'b3',
        name: 'Mateo Delux',
        phone: '300 555 6677',
        specialty: 'Cortes modernos',
        startHour: 10,
        endHour: 19,
      ),
    ];

    const barberEmails = [
      'sandro@delux.com',
      'carlos@delux.com',
      'mateo@delux.com',
    ];

    for (var i = 0; i < barbers.length; i++) {
      _barbers.add(barbers[i]);
      _addUser(
        AppUser(
          id: barbers[i].id,
          name: barbers[i].name,
          email: barberEmails[i],
          phone: barbers[i].phone,
          role: UserRole.barber,
        ),
        '12345678',
      );
    }

    _addUser(
      const AppUser(
        id: 'u1',
        name: 'Juan Pérez',
        email: 'juan@email.com',
        phone: '+57 300 000 0000',
        role: UserRole.client,
      ),
      '12345678',
    );

    final today = dateOnly(DateTime.now());

    DateTime at(int dayOffset, int hour) {
      final day = today.add(Duration(days: dayOffset));
      return DateTime(day.year, day.month, day.day, hour);
    }

    Appointment appointment(
      String id,
      String clientId,
      String clientName,
      Service service,
      Barber barber,
      DateTime startsAt,
      String status,
    ) {
      return Appointment(
        id: id,
        clientId: clientId,
        clientName: clientName,
        serviceId: service.id,
        serviceName: service.name,
        barberId: barber.id,
        barberName: barber.name,
        startsAt: startsAt,
        durationMinutes: service.durationMinutes,
        price: service.price,
        status: status,
      );
    }

    final s1 = _services[0];
    final s2 = _services[1];
    final s3 = _services[2];

    _appointments.addAll([
      appointment('p1', 'u1', 'Juan Pérez', s1, barbers[0], at(1, 11),
          AppointmentStatus.scheduled),
      appointment('p2', 'u2', 'Carlos Ruiz', s2, barbers[1], at(0, 14),
          AppointmentStatus.scheduled),
      appointment('p3', 'u3', 'Andrés Silva', s3, barbers[2], at(0, 16),
          AppointmentStatus.confirmed),
      appointment('p4', 'u4', 'Pedro Gómez', s1, barbers[0], at(0, 9),
          AppointmentStatus.confirmed),
      appointment('p5', 'u1', 'Juan Pérez', s2, barbers[2], at(-2, 16),
          AppointmentStatus.completed),
      appointment('p6', 'u1', 'Juan Pérez', s3, barbers[1], at(-5, 17),
          AppointmentStatus.noShow),
      appointment('p7', 'u3', 'Andrés Silva', s1, barbers[0], at(-3, 10),
          AppointmentStatus.completed),
    ]);

    _reviews.add(
      const Review(
        id: 'r1',
        appointmentId: 'p7',
        rating: 4,
        comment: 'Muy buen corte, llegué y me atendieron rápido.',
      ),
    );
  }

  // ---- Autenticación ----

  @override
  Future<AppUser> login(String email, String password, UserRole role) async {
    await _delay();

    final key = email.trim().toLowerCase();
    final user = _users[key];

    if (user == null || _passwords[key] != password) {
      throw const ApiException('Correo o contraseña incorrectos');
    }

    if (user.role != role) {
      throw ApiException(
        role == UserRole.client
            ? 'Esta cuenta es de barbero. Usa "Entrar como barbero".'
            : 'Esta cuenta es de cliente. Usa el inicio de sesión de clientes.',
      );
    }

    return user;
  }

  @override
  Future<AppUser> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  }) async {
    await _delay();

    final key = email.trim().toLowerCase();

    if (_users.containsKey(key)) {
      throw const ApiException('El correo electrónico ya está registrado');
    }

    final user = AppUser(
      id: _newId('u'),
      name: name.trim(),
      email: key,
      phone: phone.trim(),
      role: UserRole.client,
    );

    _addUser(user, password);

    return user;
  }

  // ---- Catálogo ----

  @override
  Future<List<Service>> getServices() async {
    await _delay();

    return List.of(_services);
  }

  @override
  Future<List<Barber>> getBarbers() async {
    await _delay();

    return List.of(_barbers);
  }

  // ---- Citas ----

  @override
  Future<List<Appointment>> getAppointments({
    String? clientId,
    String? barberId,
    DateTime? date,
  }) async {
    await _delay();

    final result = _appointments.where((a) {
      if (clientId != null && a.clientId != clientId) return false;
      if (barberId != null && a.barberId != barberId) return false;
      if (date != null && !sameDay(a.startsAt, date)) return false;
      return true;
    }).toList();

    result.sort((a, b) => a.startsAt.compareTo(b.startsAt));

    return result;
  }

  bool _overlaps(
    String barberId,
    DateTime start,
    DateTime end,
    String? ignoreAppointmentId,
  ) {
    return _appointments.any((a) =>
        a.barberId == barberId &&
        a.isActive &&
        a.id != ignoreAppointmentId &&
        start.isBefore(a.endsAt) &&
        end.isAfter(a.startsAt));
  }

  Barber _storedBarber(String id) {
    return _barbers.firstWhere(
      (b) => b.id == id,
      orElse: () => throw const ApiException('El barbero no existe'),
    );
  }

  @override
  Future<List<DateTime>> getAvailableSlots(
    String barberId,
    DateTime date,
    int durationMinutes, {
    String? ignoreAppointmentId,
  }) async {
    await _delay();

    final barber = _storedBarber(barberId);
    final now = DateTime.now();

    final dayStart = DateTime(date.year, date.month, date.day, barber.startHour);
    final dayEnd = DateTime(date.year, date.month, date.day, barber.endHour);
    final duration = Duration(minutes: durationMinutes);

    final slots = <DateTime>[];
    var slot = dayStart;

    while (!slot.add(duration).isAfter(dayEnd)) {
      if (slot.isAfter(now) &&
          !_overlaps(
            barberId,
            slot,
            slot.add(duration),
            ignoreAppointmentId,
          )) {
        slots.add(slot);
      }

      slot = slot.add(const Duration(minutes: kSlotStepMinutes));
    }

    return slots;
  }

  void _validateSlot(
    String barberId,
    DateTime startsAt,
    int durationMinutes,
    String? ignoreAppointmentId,
  ) {
    final barber = _storedBarber(barberId);

    if (startsAt.isBefore(DateTime.now())) {
      throw const ApiException('No puedes reservar en una fecha u hora pasada');
    }

    final endsAt = startsAt.add(Duration(minutes: durationMinutes));

    final dayStart = DateTime(
      startsAt.year,
      startsAt.month,
      startsAt.day,
      barber.startHour,
    );

    final dayEnd = DateTime(
      startsAt.year,
      startsAt.month,
      startsAt.day,
      barber.endHour,
    );

    if (startsAt.isBefore(dayStart) || endsAt.isAfter(dayEnd)) {
      throw const ApiException('Ese horario está fuera del turno del barbero');
    }

    if (_overlaps(barberId, startsAt, endsAt, ignoreAppointmentId)) {
      throw const ApiException('Ese horario ya fue reservado');
    }
  }

  @override
  Future<Appointment> createAppointment({
    required Service service,
    required Barber barber,
    required DateTime startsAt,
  }) async {
    await _delay();

    final client = Session.user;

    if (client == null) {
      throw const ApiException('Debes iniciar sesión');
    }

    _validateSlot(barber.id, startsAt, service.durationMinutes, null);

    final created = Appointment(
      id: _newId('p'),
      clientId: client.id,
      clientName: client.name,
      serviceId: service.id,
      serviceName: service.name,
      barberId: barber.id,
      barberName: barber.name,
      startsAt: startsAt,
      durationMinutes: service.durationMinutes,
      price: service.price,
      status: AppointmentStatus.scheduled,
    );

    _appointments.add(created);

    return created;
  }

  @override
  Future<void> updateAppointmentStatus(String id, String status) async {
    await _delay();

    final index = _appointments.indexWhere((a) => a.id == id);

    if (index == -1) {
      throw const ApiException('La cita no existe');
    }

    _appointments[index] = _appointments[index].copyWith(status: status);
  }

  @override
  Future<Appointment> rescheduleAppointment(
    Appointment appointment, {
    required DateTime startsAt,
  }) async {
    await _delay();

    final index = _appointments.indexWhere((a) => a.id == appointment.id);

    if (index == -1) {
      throw const ApiException('La cita no existe');
    }

    final current = _appointments[index];

    if (!current.isActive) {
      throw const ApiException('Solo se pueden reprogramar citas vigentes');
    }

    if (!current.canReschedule) {
      throw ApiException(
        'Solo puedes reprogramar hasta '
        '${kRescheduleLimit.inHours} horas antes de la cita',
      );
    }

    _validateSlot(current.barberId, startsAt, current.durationMinutes, current.id);

    final updated = current.copyWith(
      startsAt: startsAt,
      status: AppointmentStatus.scheduled,
    );

    _appointments[index] = updated;

    return updated;
  }

  // ---- Reseñas ----

  @override
  Future<Review> createReview({
    required Appointment appointment,
    required int rating,
    String comment = '',
  }) async {
    await _delay();

    final client = Session.user;

    if (client == null) {
      throw const ApiException('Debes iniciar sesión');
    }

    if (rating < 1 || rating > 5) {
      throw const ApiException('La calificación debe ser de 1 a 5 estrellas');
    }

    final stored = _appointments.firstWhere(
      (a) => a.id == appointment.id,
      orElse: () => throw const ApiException('La cita no existe'),
    );

    if (stored.clientId != client.id) {
      throw const ApiException('Solo puedes calificar tus propias citas');
    }

    if (stored.status != AppointmentStatus.completed) {
      throw const ApiException('Solo puedes calificar citas completadas');
    }

    if (_reviews.any((r) => r.appointmentId == stored.id)) {
      throw const ApiException('Ya calificaste esta cita');
    }

    final review = Review(
      id: _newId('r'),
      appointmentId: stored.id,
      rating: rating,
      comment: comment.trim(),
    );

    _reviews.add(review);

    return review;
  }

  @override
  Future<List<Review>> getReviews({String? clientId}) async {
    await _delay();

    final myAppointments = _appointments
        .where((a) => clientId == null || a.clientId == clientId)
        .map((a) => a.id)
        .toSet();

    return _reviews
        .where((r) => myAppointments.contains(r.appointmentId))
        .toList();
  }
}
