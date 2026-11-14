import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../models/appointment.dart';
import '../models/barber.dart';
import '../models/service.dart';
import '../services/agenda_repository.dart';
import '../widgets/async_body.dart';
import 'confirm_booking_screen.dart';

class BookingScreen extends StatefulWidget {
  final Service service;

  /// Si viene una cita, la pantalla funciona en modo "reprogramar".
  final Appointment? reschedule;

  const BookingScreen({
    super.key,
    required this.service,
    this.reschedule,
  });

  @override
  State<BookingScreen> createState() => _BookingScreenState();
}

class _BookingScreenState extends State<BookingScreen> {
  late final Future<List<Barber>> barbersFuture;

  Barber? selectedBarber;
  DateTime? selectedDate;
  DateTime? selectedSlot;

  List<DateTime> slots = [];
  bool loadingSlots = false;

  String? barberError;
  String? dateError;
  String? timeError;

  @override
  void initState() {
    super.initState();

    barbersFuture = AgendaRepository.instance.getBarbers().then((list) {
      final current = widget.reschedule;

      if (current == null) {
        return list;
      }

      // Al reprogramar solo cambia la fecha y la hora: el barbero se mantiene.
      final mine = list.where((b) => b.id == current.barberId).toList();

      if (mine.isNotEmpty) {
        selectedBarber = mine.first;
      }

      return mine;
    });
  }

  Future<void> selectDate() async {
    final now = DateTime.now();

    final result = await showDatePicker(
      context: context,
      initialDate: selectedDate ?? now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 1),
    );

    if (result != null) {
      setState(() {
        selectedDate = result;
        dateError = null;
      });

      loadSlots();
    }
  }

  Future<void> loadSlots() async {
    final barber = selectedBarber;
    final date = selectedDate;

    if (barber == null || date == null) {
      return;
    }

    setState(() {
      loadingSlots = true;
      selectedSlot = null;
    });

    try {
      final available = await AgendaRepository.instance.getAvailableSlots(
        barber.id,
        date,
        widget.service.durationMinutes,
        ignoreAppointmentId: widget.reschedule?.id,
      );

      if (!mounted || barber != selectedBarber || date != selectedDate) {
        return;
      }

      setState(() {
        slots = available;
        loadingSlots = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        loadingSlots = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage(error))),
      );
    }
  }

  void continueBooking() {
    setState(() {
      barberError = selectedBarber == null ? 'Selecciona un barbero' : null;
      dateError = selectedDate == null ? 'Selecciona una fecha' : null;
      timeError = selectedSlot == null ? 'Selecciona un horario' : null;
    });

    if (barberError != null || dateError != null || timeError != null) {
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ConfirmBookingScreen(
          service: widget.service,
          barber: selectedBarber!,
          startsAt: selectedSlot!,
          reschedule: widget.reschedule,
        ),
      ),
    );
  }

  Widget showError(String? message) {
    if (message == null) {
      return const SizedBox.shrink();
    }

    return Padding(
      padding: const EdgeInsets.only(top: 7),
      child: Text(
        message,
        style: const TextStyle(color: Colors.red, fontSize: 12),
      ),
    );
  }

  Widget sectionTitle(String text) {
    return Text(
      text,
      style: const TextStyle(
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget timeSlots() {
    final barber = selectedBarber;

    if (barber == null || selectedDate == null) {
      return const Text(
        'Elige un barbero y una fecha para ver los horarios',
        style: TextStyle(color: Colors.black54),
      );
    }

    if (loadingSlots) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (slots.isEmpty) {
      return const Text(
        'No hay horarios disponibles para esta fecha. Prueba con otro día u otro barbero.',
        style: TextStyle(color: Colors.black54),
      );
    }

    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final slot in slots)
          ChoiceChip(
            label: Text(formatTime(slot)),
            selected: selectedSlot == slot,
            selectedColor: primaryColor,
            labelStyle: TextStyle(
              color: selectedSlot == slot ? Colors.white : Colors.black,
            ),
            onSelected: (_) {
              setState(() {
                selectedSlot = slot;
                timeError = null;
              });
            },
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final rescheduling = widget.reschedule != null;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          rescheduling ? 'Reprogramar cita' : 'Agendar cita',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: lightBackground,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.service.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  '${formatDuration(widget.service.durationMinutes)} · '
                  '${formatPrice(widget.service.price)}',
                ),
              ],
            ),
          ),
          const SizedBox(height: 25),
          sectionTitle(
            widget.reschedule == null ? 'Selecciona tu barbero' : 'Tu barbero',
          ),
          const SizedBox(height: 12),
          SizedBox(
            child: AsyncBody<List<Barber>>(
              future: barbersFuture,
              builder: (context, barbers) {
                if (barbers.isEmpty) {
                  return const Text('No hay barberos disponibles');
                }

                return Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final barber in barbers)
                      ChoiceChip(
                        label: Text(barber.name),
                        selected: selectedBarber?.id == barber.id,
                        selectedColor: primaryColor,
                        labelStyle: TextStyle(
                          color: selectedBarber?.id == barber.id
                              ? Colors.white
                              : Colors.black,
                        ),
                        onSelected: (_) {
                          setState(() {
                            selectedBarber = barber;
                            barberError = null;
                          });

                          loadSlots();
                        },
                      ),
                  ],
                );
              },
            ),
          ),
          showError(barberError),
          const SizedBox(height: 25),
          sectionTitle('Selecciona una fecha'),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: selectDate,
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.calendar_month),
            label: Text(
              selectedDate == null
                  ? 'Abrir calendario'
                  : formatDate(selectedDate!),
            ),
          ),
          showError(dateError),
          const SizedBox(height: 25),
          sectionTitle('Horarios disponibles'),
          const SizedBox(height: 12),
          timeSlots(),
          showError(timeError),
          const SizedBox(height: 35),
          ElevatedButton(
            onPressed: continueBooking,
            child: const Text('Continuar'),
          ),
        ],
      ),
    );
  }
}
