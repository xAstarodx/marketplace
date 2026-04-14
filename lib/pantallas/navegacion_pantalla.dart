import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'conversaciones_pantalla.dart';
import 'inicio_pantalla.dart';
import 'publicar_producto_pantalla.dart';
import 'perfil_pantalla.dart';
import 'login_pantalla.dart';
import 'chatia_pantalla.dart';

class PantallaNavegacion extends StatefulWidget {
  const PantallaNavegacion({super.key});

  @override
  State<PantallaNavegacion> createState() => _PantallaNavegacionState();
}

class _PantallaNavegacionState extends State<PantallaNavegacion> {
  int index = 0;

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      Future.microtask(() {
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const PantallaLogin()),
        );
      });

      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    void changeTab(int newIndex) {
      setState(() => index = newIndex);
    }

    final pantallas = [
      PantallaInicio(),
      PantallaPublicarProducto(onProductPublished: () => changeTab(0)),
      const PantallaChatIA(),
      PantallaConversaciones(),
      PantallaPerfil(usuarioActual: user),
    ];

    return PopScope(
      canPop: false,
      child: Scaffold(
        body: IndexedStack(index: index, children: pantallas),
        bottomNavigationBar: NavigationBar(
          selectedIndex: index,
          onDestinationSelected: (i) => setState(() => index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.home_outlined),
              selectedIcon: Icon(Icons.home),
              label: "Inicio",
            ),
            NavigationDestination(
              icon: Icon(Icons.add_circle_outline),
              selectedIcon: Icon(Icons.add_circle),
              label: "Publicar",
            ),
            NavigationDestination(
              icon: Icon(Icons.smart_toy_outlined),
              selectedIcon: Icon(Icons.smart_toy),
              label: "Asistente",
            ),
            NavigationDestination(
              icon: Icon(Icons.chat_outlined),
              selectedIcon: Icon(Icons.chat),
              label: "Chats",
            ),
            NavigationDestination(
              icon: Icon(Icons.person_outline),
              selectedIcon: Icon(Icons.person),
              label: "Perfil",
            ),
          ],
        ),
      ),
    );
  }
}
