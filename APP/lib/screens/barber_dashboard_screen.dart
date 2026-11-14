import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/appointment.dart';
import '../services/agenda_repository.dart';
import '../services/session.dart';

class _DayData {
  final List<Appointment> appointments;
  final List<DateTime> freeSlots;

  const _DayData({
    required this.appointments,
    required this.freeSlots,
  });
}

class BarberDashboardScreen extends StatefulWidget {
  const BarberDashboardScreen({super.key});

  @override
  State<BarberDashboardScreen> createState() =>
      _BarberDashboardScreenState();
}

class _BarberDashboardScreenState extends State<BarberDashboardScreen> {
  DateTime selectedDate = DateTime.now();

  late Future<_DayData> future;

  String get barberId => Session.user?.id ?? '';

  @override
  void initState() {
    super.initState();
    future = load();
  }

  Future<_DayData> load() async {
    final repo = AgendaRepository.instance;

    final appointments = await repo.getAppointments(
      barberId: barberId,
      date: selectedDate,
    );

    final freeSlots = await repo.getAvailableSlots(
      barberId,
      selectedDate,
      kSlotStepMinutes,
    );

    return _DayData(appointments: appointments, freeSlots: freeSlots);
  }

  void reload() {
    setState(() {
      future = load();
    });
  }

  Future<void> changeStatus(Appointment appointment, String status) async {
    try {
      await AgendaRepository.instance.updateAppointmentStatus(
        appointment.id,
        status,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Cita marcada como $status')),
      );
      reload();
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(error))),
      );
    }
  }

  Widget appointmentCard(Appointment appointment) {
    return Card(
      color: lightBackground,
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    appointment.clientName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                statusChip(appointment.status),
              ],
            ),
            const SizedBox(height: 10),
            Text('Servicio: ${appointment.serviceName}'),
            Text('Hora: ${appointment.timeLabel}'),
            if (appointment.isActive) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                children: [
                  if (appointment.status == AppointmentStatus.scheduled)
                    OutlinedButton(
                      onPressed: () => changeStatus(
                        appointment,
                        AppointmentStatus.confirmed,
                      ),
                      child: const Text('Confirmar'),
                    ),
                  ElevatedButton(
                    onPressed: () => changeStatus(
                      appointment,
                      AppointmentStatus.completed,
                    ),
                    child: const Text('Completada'),
                  ),
                  OutlinedButton(
                    onPressed: () => changeStatus(
                      appointment,
                      AppointmentStatus.noShow,
                    ),
                    child: const Text('No asistió'),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final name = Session.user?.firstName ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Mi Agenda',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Cerrar sesión',
            onPressed: () => Session.logout(context),
            icon: const Icon(Icons.logout),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            name.isEmpty ? 'Hola 👋' : 'Hola, $name 👋',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.w900,
            ),
          ),
          const Text(
            'Tus clientes y horarios del día',
            style: TextStyle(color: Colors.black54),
          ),
          const SizedBox(height: 20),
          Card(
            color: lightBackground,
            elevation: 0,
            child: CalendarDatePicker(
              initialDate: selectedDate,
              firstDate: DateTime(2025),
              lastDate: DateTime(2030),
              onDateChanged: (date) {
                selectedDate = date;
                reload();
              },
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Citas - ${formatDate(selectedDate)}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          FutureBuilder<_DayData>(
            future: future,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                );
              }

              if (snapshot.hasError) {
                return Column(
                  children: [
                    Text(errorMessage(snapshot.error)),
                    TextButton(
                      onPressed: reload,
                      child: const Text('Reintentar'),
                    ),
                  ],
                );
              }

              final data = snapshot.data!;

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data.appointments.isEmpty)
                    const Text('No tienes citas programadas.'),
                  for (final appointment in data.appointments)
                    appointmentCard(appointment),
                  const SizedBox(height: 20),
                  const Text(
                    'Tiempos libres',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  if (data.freeSlots.isEmpty)
                    const Text('No quedan horarios libres este día.'),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final slot in data.freeSlots)
                        Chip(label: Text(formatTime(slot))),
                    ],
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}
