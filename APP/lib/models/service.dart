/// Servicio del catálogo (se administra desde la web).
class Service {
  final String id;
  final String name;
  final String description;
  final int durationMinutes;
  final int price;

  const Service({
    required this.id,
    required this.name,
    required this.description,
    required this.durationMinutes,
    required this.price,
  });
}
