import 'package:flutter/material.dart';

void main() {
  runApp(const AppEquipo());
}

class AppEquipo extends StatelessWidget {
  const AppEquipo({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,

      home: Scaffold(
        backgroundColor: const Color(0xFFF4F7FB),

        appBar: AppBar(
          title: const Text('Nuestro Equipo'),
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),

        body: ListView(
          padding: const EdgeInsets.all(16),

          children: [

            // PRIMERA TARJETA
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),

                child: Row(
                  children: [

                    // Foto por ahora con inicial
                    const CircleAvatar(
                      radius: 30,
                      backgroundImage: AssetImage('assets/yosmith.jpeg'),
                    ),

                    const SizedBox(width: 12),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        // Nombre
                        const Text(
                          'Yosmith Diaz',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Cargo soñado
                        const Text(
                          'CEO',
                          style: TextStyle(
                            color: Colors.blue,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Descripción
                        const Text(
                          'Me gusta crear aplicaciones y diseñar soluciones.',
                          style: TextStyle(
                            color: Colors.grey, fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),

            // Espacio entre las dos tarjetas
            const SizedBox(height: 12),

            // SEGUNDA TARJETA
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),

                child: Row(
                  children: [

                    // Foto por ahora con inicial
                    const CircleAvatar(
                      radius: 30,
                      backgroundImage: AssetImage('assets/samuel.jpeg'),
                    ),

                    const SizedBox(width: 12),

                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,

                      children: [

                        // Nombre
                        const Text(
                          'Samuel castellar',
                          style: TextStyle(
                            fontSize: 16, fontWeight: FontWeight.bold,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Cargo soñado
                        const Text(
                          'CEO',
                          style: TextStyle(
                            color: Colors.blue,
                          ),
                        ),

                        const SizedBox(height: 4),

                        // Descripción
                        const Text(
                          'Me encanta programar y crear aplicaciones.',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}