import 'package:flutter/material.dart';

import 'mapa_exploracion_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, this.avisoRevision});

  final String? avisoRevision;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          const MapaExploracionScreen(),
          if (avisoRevision != null)
            SafeArea(
              child: Align(
                alignment: Alignment.topCenter,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 86, 18, 0),
                  child: Material(
                    color: Colors.white,
                    elevation: 4,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(avisoRevision!),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
