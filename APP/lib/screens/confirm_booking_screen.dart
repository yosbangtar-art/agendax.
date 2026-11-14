import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/appointment.dart';
import '../models/barber.dart';
import '../models/service.dart';
import '../services/agenda_repository.dart';
import 'appointments_screen.dart';

class ConfirmBookingScreen extends StatefulWidget {
  final Service service;
  final Barber barber;
  final DateTime startsAt;

  /// Si viene una cita, se reprograma en vez de crear una nueva.
  final Appointment? reschedule;

  const ConfirmBookingScreen({
    super.key,
    required this.service,
    required this.barber,
    required this.startsAt,
    this.reschedule,
  });

  @override
  State<ConfirmBookingScreen> createState() => _ConfirmBookingScreenState();
}

class _ConfirmBookingScreenState extends State<ConfirmBookingScreen> {
  bool loading = false;

  Widget infoRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.black54),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> confirm() async {
    setState(() {
      loading = true;
    });

    final repo = AgendaRepository.instance;
    final current = widget.reschedule;

    try {
      if (current == null) {
        await repo.createAppointment(
          service: widget.service,
          barber: widget.barber,
          startsAt: widget.startsAt,
        );
      } else {
        await repo.rescheduleAppointment(
          current,
          startsAt: widget.startsAt,
        );
      }

      if (!mounted) return;

      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return AlertDialog(
            title: Text(
              current == null ? '¡Cita confirmada!' : '¡Cita reprogramada!',
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.check_circle,
                  color: Colors.green,
                  size: 70,
                ),
                const SizedBox(height: 12),
                Text(
                  current == null
                      ? 'Tu cita fue agendada correctamente.'
                      : 'Tu cita fue movida a la nueva fecha.',
                  textAlign: TextAlign.center,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Ver mis citas'),
              ),
            ],
          );
        },
      );

      if (!mounted) return;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => const AppointmentsScreen(),
        ),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(error))),
      );
    } finally {
      if (mounted) {
        setState(() {
          loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final rescheduling = widget.reschedule != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          rescheduling ? 'Confirmar cambio' : 'Confirmar cita',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Revisa los detalles de tu reserva',
            style: TextStyle(fontSize: 16, color: Colors.black54),
          ),
          const SizedBox(height: 20),
          Card(
            color: lightBackground,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  infoRow('Servicio', widget.service.name),
                  infoRow('Barbero', widget.barber.name),
                  infoRow('Fecha', formatDate(widget.startsAt)),
                  infoRow('Hora', formatTime(widget.startsAt)),
                  infoRow(
                    'Duración',
                    formatDuration(widget.service.durationMinutes),
                  ),
                  const Divider(),
                  infoRow('Precio', formatPrice(widget.service.price)),
                ],
              ),
            ),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: loading ? null : confirm,
            child: loading
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : Text(rescheduling ? 'Confirmar cambio' : 'Confirmar cita'),
          ),
          const SizedBox(height: 10),
          OutlinedButton(
            onPressed: loading ? null : () => Navigator.pop(context),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            child: const Text('Volver'),
          ),
        ],
      ),
    );
  }
}
