import '../models/app_user.dart';
import '../models/appointment.dart';
import '../models/barber.dart';
import '../models/review.dart';
import '../models/service.dart';
import 'mock_agenda_repository.dart';

/// Cada cuántos minutos se ofrece un horario de inicio (09:00, 09:30, ...).
/// Es el mismo paso que usa el backend en /barberos/{id}/disponibilidad.
const int kSlotStepMinutes = 30;

class ApiException implements Exception {
  final String message;

  const ApiException(this.message);

  @override
  String toString() => message;
}

String errorMessage(Object? error) {
  if (error is ApiException) {
    return error.message;
  }

  return 'Ocurrió un error inesperado. Intenta de nuevo.';
}

/// Contrato entre las pantallas y el backend.
///
/// - [HttpAgendaRepository]: habla con la API FastAPI (BACKEND/main.py).
/// - [MockAgendaRepository]: datos en memoria para trabajar sin servidor
///   (`flutter run --dart-define=USE_MOCK=true`) y para las pruebas.
///
/// La administración (servicios, barberos, cuentas, reportes, reseñas) se
/// hace desde la web, por eso no aparece aquí.
abstract class AgendaRepository {
  static AgendaRepository instance = MockAgendaRepository();

  // ---- Autenticación ----
  /// POST /usuarios/login. Falla si la cuenta no es del [role] pedido.
  Future<AppUser> login(String email, String password, UserRole role);

  /// POST /usuarios/registro (siempre con rol "cliente").
  Future<AppUser> register({
    required String name,
    required String email,
    required String phone,
    required String password,
  });

  // ---- Catálogo ----
  /// GET /servicios/
  Future<List<Service>> getServices();

  /// GET /barberos/
  Future<List<Barber>> getBarbers();

  // ---- Citas ----
  /// GET /citas/?cliente_id=&barbero_id=  (el filtro por día se hace en la app)
  Future<List<Appointment>> getAppointments({
    String? clientId,
    String? barberId,
    DateTime? date,
  });

  /// Horas de inicio posibles ese día para un servicio de [durationMinutes].
  /// Base: GET /barberos/{id}/disponibilidad?fecha=YYYY-MM-DD
  Future<List<DateTime>> getAvailableSlots(
    String barberId,
    DateTime date,
    int durationMinutes, {
    String? ignoreAppointmentId,
  });

  /// POST /citas/  (nace "Agendada")
  Future<Appointment> createAppointment({
    required Service service,
    required Barber barber,
    required DateTime startsAt,
  });

  /// Cancelar: PUT /citas/{id}/cancelar.
  /// Otros estados: PUT /citas/{id}/estado?nuevo_estado=
  Future<void> updateAppointmentStatus(String id, String status);

  /// PUT /citas/{id}/reprogramar?nueva_fecha_hora=
  /// Solo cambia fecha y hora: el barbero de la cita no se puede cambiar.
  Future<Appointment> rescheduleAppointment(
    Appointment appointment, {
    required DateTime startsAt,
  });

  // ---- Reseñas ----
  /// POST /resenas/  (solo citas completadas, una por cita: lo valida la app)
  Future<Review> createReview({
    required Appointment appointment,
    required int rating,
    String comment = '',
  });

  /// GET /resenas/ filtrado por las citas del cliente.
  Future<List<Review>> getReviews({String? clientId});
}
