import 'package:flutter/material.dart';

export 'utils/format.dart';

const Color primaryColor = Color(0xFFE91E63);
const Color lightBackground = Color(0xFFF5F5F7);

final ThemeData appTheme = ThemeData(
  useMaterial3: true,
  scaffoldBackgroundColor: Colors.white,

  colorScheme: ColorScheme.fromSeed(
    seedColor: primaryColor,
    primary: primaryColor,
  ),

  appBarTheme: const AppBarTheme(
    backgroundColor: Colors.white,
    foregroundColor: Colors.black,
    elevation: 0,
    centerTitle: false,
  ),

  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: lightBackground,

    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide.none,
    ),

    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: BorderSide.none,
    ),

    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15),
      borderSide: const BorderSide(
        color: primaryColor,
        width: 2,
      ),
    ),
  ),

  elevatedButtonTheme: ElevatedButtonThemeData(
    style: ElevatedButton.styleFrom(
      backgroundColor: primaryColor,
      foregroundColor: Colors.white,
      minimumSize: const Size.fromHeight(52),

      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
    ),
  ),
);

Widget statusChip(String status) {
  Color color;

  switch (status) {
    case 'Confirmada':
      color = Colors.green;
      break;

    case 'Agendada':
      color = Colors.orange;
      break;

    case 'Completada':
      color = Colors.blue;
      break;

    case 'Cancelada':
      color = Colors.red;
      break;

    case 'No asistió':
      color = Colors.blueGrey;
      break;

    default:
      color = Colors.grey;
  }

  return Container(
    padding: const EdgeInsets.symmetric(
      horizontal: 10,
      vertical: 5,
    ),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(20),
    ),
    child: Text(
      status,
      style: TextStyle(
        color: color,
        fontWeight: FontWeight.bold,
        fontSize: 12,
      ),
    ),
  );
}