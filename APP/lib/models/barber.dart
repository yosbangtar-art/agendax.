/// Barbero visible para el cliente.
///
/// El backend actual no guarda horario por barbero: todos atienden de
/// 09:00 a 18:00 (ver `consultar_disponibilidad` en main.py). Por eso los
/// valores por defecto.
class Barber {
  final String id;
  final String name;
  final String phone;
  final String specialty;
  final int startHour;
  final int endHour;

  const Barber({
    required this.id,
    required this.name,
    required this.phone,
    required this.specialty,
    this.startHour = 9,
    this.endHour = 18,
  });
}
