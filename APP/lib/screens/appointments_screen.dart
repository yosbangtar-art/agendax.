import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/appointment.dart';
import '../models/review.dart';
import '../models/service.dart';
import '../services/agenda_repository.dart';
import '../services/session.dart';
import '../widgets/async_body.dart';
import '../widgets/client_bottom_bar.dart';
import '../widgets/review_dialog.dart';
import 'booking_screen.dart';
import 'services_screen.dart';

class _ClientData {
  final List<Appointment> appointments;
  final Map<String, Review> reviewsByAppointment;

  const _ClientData({
    required this.appointments,
    required this.reviewsByAppointment,
  });
}

class AppointmentsScreen extends StatefulWidget {
  const AppointmentsScreen({super.key});

  @override
  State<AppointmentsScreen> createState() => _AppointmentsScreenState();
}

class _AppointmentsScreenState extends State<AppointmentsScreen> {
  late Future<_ClientData> future;

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_ClientData> load() async {
    final repo = AgendaRepository.instance;
    final clientId = Session.user?.id;

    final appointments = await repo.getAppointments(clientId: clientId);
    final reviews = await repo.getReviews(clientId: clientId);

    return _ClientData(
      appointments: appointments,
      reviewsByAppointment: {
        for (final review in reviews) review.appointmentId: review,
      },
    );
  }

  void reload() {
    setState(() {
      future = load();
    });
  }

  void snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> confirmAttendance(Appointment appointment) async {
    try {
      await AgendaRepository.instance.updateAppointmentStatus(
        appointment.id,
        AppointmentStatus.confirmed,
      );

      if (!mounted) return;

      snack('¡Asistencia confirmada!');
      reload();
    } catch (error) {
      if (!mounted) return;
      snack(errorMessage(error));
    }
  }

  Future<void> cancelAppointment(Appointment appointment) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Cancelar cita'),
          content: const Text(
            '¿Estás seguro de que deseas cancelar esta cita?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('No'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text(
                'Sí, cancelar',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );

    if (confirmed != true) return;

    try {
      await AgendaRepository.instance.updateAppointmentStatus(
        appointment.id,
        AppointmentStatus.cancelled,
      );

      if (!mounted) return;

      snack('Cita cancelada correctamente');
      reload();
    } catch (error) {
      if (!mounted) return;
      snack(errorMessage(error));
    }
  }

  Future<void> rescheduleAppointment(Appointment appointment) async {
    try {
      final services = await AgendaRepository.instance.getServices();

      final service = services.firstWhere(
        (s) => s.id == appointment.serviceId,
        orElse: () => Service(
          id: appointment.serviceId,
          name: appointment.serviceName,
          description: '',
          durationMinutes: appointment.durationMinutes,
          price: appointment.price,
        ),
      );

      if (!mounted) return;

      await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => BookingScreen(
            service: service,
            reschedule: appointment,
          ),
        ),
      );

      if (!mounted) return;
      reload();
    } catch (error) {
      if (!mounted) return;
      snack(errorMessage(error));
    }
  }

  Future<void> reviewAppointment(Appointment appointment) async {
    final result = await showReviewDialog(context);

    if (result == null) return;

    try {
      await AgendaRepository.instance.createReview(
        appointment: appointment,
        rating: result.rating,
        comment: result.comment,
      );

      if (!mounted) return;

      snack('¡Gracias por tu calificación!');
      reload();
    } catch (error) {
      if (!mounted) return;
      snack(errorMessage(error));
    }
  }

  Widget appointmentCard(
    Appointment appointment, {
    bool upcoming = false,
    Review? review,
  }) {
    final canReview =
        !upcoming &&
        appointment.status == AppointmentStatus.completed &&
        review == null;

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
                Expanded(
                  child: Text(
                    appointment.serviceName,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                    ),
                  ),
                ),
                statusChip(appointment.status),
              ],
            ),
            const SizedBox(height: 12),
            Text('Barbero: ${appointment.barberName}'),
            const SizedBox(height: 5),
            Text('Fecha: ${appointment.dateLabel}'),
            const SizedBox(height: 5),
            Text('Hora: ${appointment.timeLabel}'),
            const SizedBox(height: 5),
            Text('Precio: ${appointment.priceLabel}'),
            if (upcoming) ...[
              const SizedBox(height: 12),
              Wrap(
                children: [
                  if (appointment.status == AppointmentStatus.scheduled)
                    TextButton(
                      onPressed: () => confirmAttendance(appointment),
                      child: const Text('Confirmar asistencia'),
                    ),
                  TextButton(
                    onPressed: appointment.canReschedule
                        ? () => rescheduleAppointment(appointment)
                        : null,
                    child: const Text('Reprogramar'),
                  ),
                  TextButton(
                    onPressed: () => cancelAppointment(appointment),
                    child: const Text(
                      'Cancelar',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                ],
              ),
              if (!appointment.canReschedule)
                Text(
                  'Ya no puedes reprogramar: faltan menos de '
                  '${kRescheduleLimit.inHours} horas para tu cita.',
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 12,
                  ),
                ),
            ],
            if (review != null) ...[
              const SizedBox(height: 10),
              Row(
                children: [
                  const Text('Tu calificación: '),
                  StarRating(rating: review.rating),
                ],
              ),
              if (review.comment.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    review.comment,
                    style: const TextStyle(color: Colors.black54),
                  ),
                ),
            ],
            if (canReview)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: () => reviewAppointment(appointment),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                  ),
                  icon: const Icon(Icons.star_border),
                  label: const Text('Calificar servicio'),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget upcomingTab(List<Appointment> upcoming) {
    if (upcoming.isEmpty) {
      return EmptyState(
        icon: Icons.event_busy,
        message: 'No tienes citas programadas',
        action: SizedBox(
          width: 220,
          child: ElevatedButton(
            onPressed: () {
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(
                  builder: (_) => const ServicesScreen(),
                ),
              );
            },
            child: const Text('Agendar una cita'),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final appointment in upcoming)
          appointmentCard(appointment, upcoming: true),
      ],
    );
  }

  Widget historyTab(
    List<Appointment> history,
    Map<String, Review> reviews,
  ) {
    if (history.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        message: 'Aún no tienes historial',
      );
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (final appointment in history)
          appointmentCard(appointment, review: reviews[appointment.id]),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text(
            'Mis citas',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          bottom: const TabBar(
            indicatorColor: primaryColor,
            labelColor: primaryColor,
            tabs: [
              Tab(text: 'Próximas'),
              Tab(text: 'Historial'),
            ],
          ),
        ),
        body: AsyncBody<_ClientData>(
          future: future,
          onRetry: reload,
          builder: (context, data) {
            final now = DateTime.now();

            final upcoming = data.appointments
                .where((a) => a.isActive && a.startsAt.isAfter(now))
                .toList();

            final history = data.appointments
                .where((a) => !(a.isActive && a.startsAt.isAfter(now)))
                .toList()
              ..sort((a, b) => b.startsAt.compareTo(a.startsAt));

            return TabBarView(
              children: [
                upcomingTab(upcoming),
                historyTab(history, data.reviewsByAppointment),
              ],
            );
          },
        ),
        bottomNavigationBar: const ClientBottomBar(currentIndex: 1),
      ),
    );
  }
}
