import 'package:flutter/material.dart';

import '../models/app_user.dart';
import '../screens/login_screen.dart';

/// Usuario que inició sesión. Cuando exista el backend aquí se guardaría
/// también el token.
class Session {
  static AppUser? user;

  static void logout(BuildContext context) {
    user = null;

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const LoginScreen(),
      ),
      (_) => false,
    );
  }
}
