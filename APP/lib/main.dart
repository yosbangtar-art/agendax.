import 'package:flutter/material.dart';

import 'app_theme.dart';
import 'screens/login_screen.dart';
import 'services/agenda_repository.dart';
import 'services/http_agenda_repository.dart';
import 'services/mock_agenda_repository.dart';

/// Datos de prueba sin servidor:
///   flutter run --dart-define=USE_MOCK=true
const bool kUseMock = bool.fromEnvironment('USE_MOCK');

void main() {
  AgendaRepository.instance =
      kUseMock ? MockAgendaRepository() : HttpAgendaRepository();

  runApp(const AgendaXApp());
}

class AgendaXApp extends StatelessWidget {
  const AgendaXApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'AgendaX',
      debugShowCheckedModeBanner: false,
      theme: appTheme,
      // RNF-005: en pantallas grandes (navegador) el contenido se limita a
      // un ancho de celular y se centra.
      builder: (context, child) {
        return ColoredBox(
          color: const Color(0xFFEDEDF0),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 520),
              child: child,
            ),
          ),
        );
      },
      home: const LoginScreen(),
    );
  }
}
