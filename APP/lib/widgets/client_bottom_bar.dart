import 'package:flutter/material.dart';

import '../app_theme.dart';
import '../screens/appointments_screen.dart';
import '../screens/services_screen.dart';
import '../services/session.dart';

class ClientBottomBar extends StatelessWidget {
  final int currentIndex;

  const ClientBottomBar({
    super.key,
    required this.currentIndex,
  });

  void showProfile(BuildContext context) {
    final user = Session.user;

    showDialog(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Mi perfil'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircleAvatar(
                radius: 35,
                backgroundColor: primaryColor,
                child: Icon(
                  Icons.person,
                  color: Colors.white,
                  size: 40,
                ),
              ),
              const SizedBox(height: 15),
              Text(
                user?.name ?? '',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
              Text(user?.email ?? ''),
              if ((user?.phone ?? '').isNotEmpty) Text(user!.phone),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cerrar'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                Session.logout(context);
              },
              child: const Text(
                'Cerrar sesión',
                style: TextStyle(color: Colors.red),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return BottomNavigationBar(
      currentIndex: currentIndex,
      selectedItemColor: primaryColor,
      onTap: (index) {
        if (index == currentIndex) {
          return;
        }

        if (index == 0) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const ServicesScreen(),
            ),
          );
        }

        if (index == 1) {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (_) => const AppointmentsScreen(),
            ),
          );
        }

        if (index == 2) {
          showProfile(context);
        }
      },
      items: const [
        BottomNavigationBarItem(
          icon: Icon(Icons.home),
          label: 'Inicio',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.calendar_month),
          label: 'Mis citas',
        ),
        BottomNavigationBarItem(
          icon: Icon(Icons.person),
          label: 'Perfil',
        ),
      ],
    );
  }
}
