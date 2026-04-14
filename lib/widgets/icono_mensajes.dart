import 'package:flutter/material.dart';

class IconoMensajes extends StatelessWidget {
  final bool tieneNuevos;
  final VoidCallback alPresionar;

  const IconoMensajes({
    super.key,
    required this.tieneNuevos,
    required this.alPresionar,
  });

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.message),
          onPressed: alPresionar,
        ),
        if (tieneNuevos)
          Positioned(
            right: 6,
            top: 6,
            child: Container(
              width: 12,
              height: 12,
              decoration: const BoxDecoration(
                color: Colors.red,
                shape: BoxShape.circle,
              ),
            ),
          ),
      ],
    );
  }
}
