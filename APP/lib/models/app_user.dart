/// En la app solo existen clientes y barberos. El administrador trabaja
/// desde la web.
enum UserRole { client, barber }

class AppUser {
  /// Cliente: id del usuario. Barbero: id del barbero (el de /barberos/).
  final String id;
  final String name;
  final String email;
  final String phone;
  final UserRole role;

  const AppUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
  });

  String get firstName {
    final parts = name.trim().split(' ');
    return parts.isEmpty ? name : parts.first;
  }
}
