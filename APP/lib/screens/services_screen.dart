import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/service.dart';
import '../services/agenda_repository.dart';
import '../services/session.dart';
import '../widgets/async_body.dart';
import '../widgets/client_bottom_bar.dart';
import 'booking_screen.dart';

class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key});

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen> {
  late Future<List<Service>> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<List<Service>> load() {
    return AgendaRepository.instance.getServices();
  }

  void reload() {
    setState(() {
      future = load();
    });
  }

  Widget serviceCard(Service service) {
    return Card(
      color: lightBackground,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 15),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const CircleAvatar(
                  backgroundColor: primaryColor,
                  child: Icon(
                    Icons.content_cut,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    service.name,
                    style: const TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              service.description,
              style: const TextStyle(color: Colors.black54),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                const Icon(Icons.schedule, size: 18),
                const SizedBox(width: 5),
                Text(formatDuration(service.durationMinutes)),
                const Spacer(),
                Text(
                  formatPrice(service.price),
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 17,
                    color: primaryColor,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),
            ElevatedButton(
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (_) => BookingScreen(service: service),
                  ),
                );
              },
              child: const Text('Reservar'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = Session.user?.firstName ?? '';

    return Scaffold(
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name.isEmpty ? 'Hola 👋' : 'Hola, $name 👋',
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const Text(
                          'Selecciona un servicio para agendar',
                          style: TextStyle(color: Colors.black54),
                        ),
                      ],
                    ),
                  ),
                  const CircleAvatar(
                    backgroundColor: primaryColor,
                    child: Icon(Icons.person, color: Colors.white),
                  ),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 25, 20, 12),
              child: Text(
                'Servicios',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(
              child: AsyncBody<List<Service>>(
                future: future,
                onRetry: reload,
                builder: (context, services) {
                  if (services.isEmpty) {
                    return const EmptyState(
                      icon: Icons.content_cut,
                      message: 'Aún no hay servicios disponibles',
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async => reload(),
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                      children: [
                        for (final service in services) serviceCard(service),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: const ClientBottomBar(currentIndex: 0),
    );
  }
}
